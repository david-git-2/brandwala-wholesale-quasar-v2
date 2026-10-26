-- Dropship gifts: shop customer stock, auto gifts, order gift lines

alter table public.shop_orders
  add column if not exists auto_gifts_applied_at timestamptz,
  add column if not exists auto_gifts_apply_result jsonb;

alter table public.shop_order_items
  add column if not exists is_gift boolean not null default false,
  add column if not exists gift_source text,
  add column if not exists gift_cost_amount numeric(12,4) not null default 0,
  add column if not exists gift_cost_charged_to text,
  add column if not exists shop_customer_stock_id bigint,
  add column if not exists gift_added_by text;

alter table public.shop_order_items
  drop constraint if exists shop_order_items_gift_source_check;

alter table public.shop_order_items
  add constraint shop_order_items_gift_source_check
  check (
    gift_source is null
    or gift_source = any (array['stock'::text, 'customer_stock'::text])
  );

alter table public.shop_order_items
  drop constraint if exists shop_order_items_gift_charged_to_check;

alter table public.shop_order_items
  add constraint shop_order_items_gift_charged_to_check
  check (
    gift_cost_charged_to is null
    or gift_cost_charged_to = any (array['reseller'::text, 'tenant'::text])
  );

alter table public.shop_order_items
  drop constraint if exists shop_order_items_gift_added_by_check;

alter table public.shop_order_items
  add constraint shop_order_items_gift_added_by_check
  check (
    gift_added_by is null
    or gift_added_by = any (array['manual'::text, 'auto'::text])
  );

create table if not exists public.shop_customer_stocks (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants (id) on delete cascade,
  shop_id bigint not null references public.shops (id) on delete cascade,
  product_id bigint not null references public.products (id) on delete restrict,
  quantity_on_hand integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_customer_stocks_qty_non_negative check (quantity_on_hand >= 0),
  constraint shop_customer_stocks_shop_product_key unique (shop_id, product_id)
);

create index if not exists idx_shop_customer_stocks_shop_id
  on public.shop_customer_stocks (shop_id);

create table if not exists public.shop_auto_gift_items (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants (id) on delete cascade,
  shop_id bigint not null references public.shops (id) on delete cascade,
  product_id bigint not null references public.products (id) on delete restrict,
  quantity integer not null default 1,
  gift_source text not null,
  gift_cost_amount numeric(12,4) not null default 0,
  gift_cost_charged_to text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_auto_gift_items_qty_positive check (quantity > 0),
  constraint shop_auto_gift_items_gift_source_check
    check (gift_source = any (array['stock'::text, 'customer_stock'::text])),
  constraint shop_auto_gift_items_charged_to_check
    check (
      gift_cost_charged_to is null
      or gift_cost_charged_to = any (array['reseller'::text, 'tenant'::text])
    )
);

create index if not exists idx_shop_auto_gift_items_shop_id
  on public.shop_auto_gift_items (shop_id);

alter table public.shop_order_items
  drop constraint if exists shop_order_items_shop_customer_stock_id_fkey;

alter table public.shop_order_items
  add constraint shop_order_items_shop_customer_stock_id_fkey
  foreign key (shop_customer_stock_id) references public.shop_customer_stocks (id) on delete set null;

grant select, insert, update, delete on table public.shop_customer_stocks to authenticated;
grant select, insert, update, delete on table public.shop_auto_gift_items to authenticated;

create or replace function public._recompute_shop_order_item_fulfillment(p_order_item_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_pick_qty integer := 0;
  v_first_held bigint;
  v_weighted_cost numeric(12,4);
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    return;
  end if;

  if coalesce(v_item.is_gift, false) and v_item.gift_source = 'customer_stock' then
    return;
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    update public.shop_order_items
    set
      confirmed_quantity = 0,
      global_stock_id = null,
      cost_price_amount = null,
      updated_at = now()
    where id = p_order_item_id;
    return;
  end if;

  select coalesce(sum(sp.quantity), 0)
  into v_pick_qty
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  select sp.held_stock_id
  into v_first_held
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id
  order by sp.id asc
  limit 1;

  select case
    when v_pick_qty > 0 then
      coalesce(
        sum(
          coalesce(public.calculate_landed_unit_cost(sp.shipment_item_id), 0)
          * sp.quantity
        ) / nullif(v_pick_qty, 0),
        v_item.cost_price_amount
      )
    else null
  end
  into v_weighted_cost
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  update public.shop_order_items
  set
    confirmed_quantity = v_pick_qty,
    global_stock_id = v_first_held,
    cost_price_amount = v_weighted_cost,
    updated_at = now()
  where id = p_order_item_id;
end;
$$;

create or replace function public.list_shop_customer_stocks(p_shop_id bigint)
returns table (
  id bigint,
  shop_id bigint,
  product_id bigint,
  product_name text,
  product_code text,
  quantity_on_hand integer,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_shop public.shops%rowtype;
begin
  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then
    raise exception 'shop not found';
  end if;

  if not public.is_tenant_staff(v_shop.tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    scs.id,
    scs.shop_id,
    scs.product_id,
    p.name as product_name,
    p.product_code,
    scs.quantity_on_hand,
    scs.updated_at
  from public.shop_customer_stocks scs
  join public.products p on p.id = scs.product_id
  where scs.shop_id = p_shop_id
  order by p.name, scs.id;
end;
$$;

create or replace function public.receive_shop_customer_stock(
  p_shop_id bigint,
  p_product_id bigint,
  p_quantity integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops%rowtype;
  v_row public.shop_customer_stocks%rowtype;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('success', false, 'error', 'quantity must be positive');
  end if;

  select * into v_shop from public.shops where id = p_shop_id for update;
  if v_shop.id is null then
    return jsonb_build_object('success', false, 'error', 'shop not found');
  end if;

  if not public.is_tenant_staff(v_shop.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if not exists (select 1 from public.products where id = p_product_id) then
    return jsonb_build_object('success', false, 'error', 'product not found');
  end if;

  insert into public.shop_customer_stocks (tenant_id, shop_id, product_id, quantity_on_hand)
  values (v_shop.tenant_id, p_shop_id, p_product_id, p_quantity)
  on conflict (shop_id, product_id) do update
  set
    quantity_on_hand = public.shop_customer_stocks.quantity_on_hand + excluded.quantity_on_hand,
    updated_at = now()
  returning * into v_row;

  return jsonb_build_object(
    'success', true,
    'row', jsonb_build_object(
      'id', v_row.id,
      'product_id', v_row.product_id,
      'quantity_on_hand', v_row.quantity_on_hand
    )
  );
end;
$$;

create or replace function public.add_dropship_order_gift_item(
  p_order_id bigint,
  p_product_id bigint,
  p_quantity integer,
  p_gift_source text,
  p_gift_cost_amount numeric default 0,
  p_gift_cost_charged_to text default null,
  p_gift_added_by text default 'manual'
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_product public.products%rowtype;
  v_cust_stock public.shop_customer_stocks%rowtype;
  v_item_id bigint;
  v_cost numeric(12,4);
  v_charged_to text;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('success', false, 'error', 'quantity must be positive');
  end if;

  if p_gift_source not in ('stock', 'customer_stock') then
    return jsonb_build_object('success', false, 'error', 'invalid gift_source');
  end if;

  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    return jsonb_build_object('success', false, 'error', 'gifts can only be added while processing');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_product from public.products where id = p_product_id;
  if v_product.id is null then
    return jsonb_build_object('success', false, 'error', 'product not found');
  end if;

  v_cost := coalesce(p_gift_cost_amount, 0);
  v_charged_to := p_gift_cost_charged_to;

  if p_gift_source = 'customer_stock' then
    v_cost := 0;
    v_charged_to := null;

    select * into v_cust_stock
    from public.shop_customer_stocks
    where shop_id = v_order.shop_id
      and product_id = p_product_id
    for update;

    if v_cust_stock.id is null or v_cust_stock.quantity_on_hand < p_quantity then
      return jsonb_build_object('success', false, 'error', 'insufficient customer stock for this product');
    end if;

    update public.shop_customer_stocks
    set quantity_on_hand = quantity_on_hand - p_quantity, updated_at = now()
    where id = v_cust_stock.id;

    insert into public.shop_order_items (
      order_id, product_id, name, image_url, quantity,
      unit_sell_price_amount, final_price_amount, customer_sell_price_amount,
      is_gift, gift_source, gift_cost_amount, gift_cost_charged_to,
      shop_customer_stock_id, gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, p_product_id, v_product.name, v_product.image_url, p_quantity,
      0, 0, 0,
      true, 'customer_stock', 0, null,
      v_cust_stock.id, coalesce(p_gift_added_by, 'manual'), p_quantity
    )
    returning id into v_item_id;

  else
    if v_cost > 0 and v_charged_to is null then
      return jsonb_build_object('success', false, 'error', 'gift_cost_charged_to required when cost > 0');
    end if;
    if v_cost <= 0 then
      v_charged_to := null;
    end if;
    if v_charged_to is not null and v_charged_to not in ('reseller', 'tenant') then
      return jsonb_build_object('success', false, 'error', 'invalid gift_cost_charged_to');
    end if;

    insert into public.shop_order_items (
      order_id, product_id, name, image_url, quantity,
      unit_sell_price_amount, final_price_amount, customer_sell_price_amount,
      is_gift, gift_source, gift_cost_amount, gift_cost_charged_to,
      gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, p_product_id, v_product.name, v_product.image_url, p_quantity,
      0, 0, 0,
      true, 'stock', v_cost, v_charged_to,
      coalesce(p_gift_added_by, 'manual'), 0
    )
    returning id into v_item_id;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true, 'order_item_id', v_item_id);
end;
$$;

create or replace function public.remove_dropship_order_gift_item(p_order_item_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_pick record;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    return jsonb_build_object('success', false, 'error', 'order item not found');
  end if;

  if not coalesce(v_item.is_gift, false) then
    return jsonb_build_object('success', false, 'error', 'not a gift line');
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if v_order.status <> 'processing'::public.shop_order_status then
    return jsonb_build_object('success', false, 'error', 'can only remove gifts while processing');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  for v_pick in
    select * from public.shop_order_item_stock_picks where order_item_id = p_order_item_id
  loop
    if v_pick.held_stock_id is not null then
      select * into v_stock from public.global_stocks where id = v_pick.held_stock_id for update;
      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= v_pick.quantity then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => v_pick.quantity,
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Undo dropship gift pick',
          p_reference_type => 'shop_order',
          p_reference_id => v_order.id::text
        );
      end if;
    end if;
    delete from public.shop_order_item_stock_picks where id = v_pick.id;
  end loop;

  if v_item.gift_source = 'customer_stock' and v_item.shop_customer_stock_id is not null then
    update public.shop_customer_stocks
    set quantity_on_hand = quantity_on_hand + v_item.quantity, updated_at = now()
    where id = v_item.shop_customer_stock_id;
  end if;

  delete from public.shop_order_items where id = p_order_item_id;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.list_shop_auto_gift_items(p_shop_id bigint)
returns setof public.shop_auto_gift_items
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_shop public.shops%rowtype;
begin
  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then
    raise exception 'shop not found';
  end if;
  if not public.is_tenant_staff(v_shop.tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select *
  from public.shop_auto_gift_items ag
  where ag.shop_id = p_shop_id
  order by ag.id;
end;
$$;

create or replace function public.upsert_shop_auto_gift_item(p_shop_id bigint, p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops%rowtype;
  v_id bigint;
  v_row public.shop_auto_gift_items%rowtype;
  v_source text;
  v_cost numeric(12,4);
  v_charged_to text;
begin
  select * into v_shop from public.shops where id = p_shop_id;
  if v_shop.id is null then
    return jsonb_build_object('success', false, 'error', 'shop not found');
  end if;
  if not public.is_tenant_staff(v_shop.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_source := p_payload->>'gift_source';
  if v_source not in ('stock', 'customer_stock') then
    return jsonb_build_object('success', false, 'error', 'invalid gift_source');
  end if;

  v_cost := coalesce((p_payload->>'gift_cost_amount')::numeric, 0);
  v_charged_to := p_payload->>'gift_cost_charged_to';

  if v_source = 'customer_stock' then
    v_cost := 0;
    v_charged_to := null;
  elsif v_cost > 0 and v_charged_to is null then
    return jsonb_build_object('success', false, 'error', 'gift_cost_charged_to required when cost > 0');
  elsif v_cost <= 0 then
    v_charged_to := null;
  end if;

  v_id := (p_payload->>'id')::bigint;

  if v_id is not null then
    update public.shop_auto_gift_items
    set
      product_id = coalesce((p_payload->>'product_id')::bigint, product_id),
      quantity = greatest(1, coalesce((p_payload->>'quantity')::integer, quantity)),
      gift_source = v_source,
      gift_cost_amount = v_cost,
      gift_cost_charged_to = v_charged_to,
      is_active = coalesce((p_payload->>'is_active')::boolean, is_active),
      updated_at = now()
    where id = v_id and shop_id = p_shop_id
    returning * into v_row;
  else
    insert into public.shop_auto_gift_items (
      tenant_id, shop_id, product_id, quantity, gift_source,
      gift_cost_amount, gift_cost_charged_to, is_active
    )
    values (
      v_shop.tenant_id,
      p_shop_id,
      (p_payload->>'product_id')::bigint,
      greatest(1, coalesce((p_payload->>'quantity')::integer, 1)),
      v_source,
      v_cost,
      v_charged_to,
      coalesce((p_payload->>'is_active')::boolean, true)
    )
    returning * into v_row;
  end if;

  if v_row.id is null then
    return jsonb_build_object('success', false, 'error', 'failed to save auto gift');
  end if;

  return jsonb_build_object('success', true, 'row', to_jsonb(v_row));
end;
$$;

create or replace function public.delete_shop_auto_gift_item(p_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shop_auto_gift_items%rowtype;
begin
  select * into v_row from public.shop_auto_gift_items where id = p_id;
  if v_row.id is null then
    return jsonb_build_object('success', false, 'error', 'not found');
  end if;
  if not public.is_tenant_staff(v_row.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  delete from public.shop_auto_gift_items where id = p_id;
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.apply_shop_auto_gift_items(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_cfg public.shop_auto_gift_items%rowtype;
  v_result jsonb;
  v_applied integer := 0;
  v_skipped jsonb := '[]'::jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.auto_gifts_applied_at is not null then
    return jsonb_build_object('success', true, 'already_applied', true, 'applied', 0, 'skipped', coalesce(v_order.auto_gifts_apply_result->'skipped', '[]'::jsonb));
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not dropship');
  end if;

  for v_cfg in
    select *
    from public.shop_auto_gift_items
    where shop_id = v_order.shop_id
      and is_active = true
    order by id
  loop
    v_result := public.add_dropship_order_gift_item(
      p_order_id,
      v_cfg.product_id,
      v_cfg.quantity,
      v_cfg.gift_source,
      v_cfg.gift_cost_amount,
      v_cfg.gift_cost_charged_to,
      'auto'
    );

    if coalesce(v_result->>'success', 'false') = 'true' then
      v_applied := v_applied + 1;
    else
      v_skipped := v_skipped || jsonb_build_array(jsonb_build_object(
        'auto_gift_id', v_cfg.id,
        'product_id', v_cfg.product_id,
        'error', coalesce(v_result->>'error', 'failed')
      ));
    end if;
  end loop;

  update public.shop_orders
  set
    auto_gifts_applied_at = now(),
    auto_gifts_apply_result = jsonb_build_object('skipped', v_skipped, 'applied_count', v_applied),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object('success', true, 'applied', v_applied, 'skipped', v_skipped);
end;
$$;

grant execute on function public.list_shop_customer_stocks(bigint) to authenticated;
grant execute on function public.receive_shop_customer_stock(bigint, bigint, integer) to authenticated;
grant execute on function public.add_dropship_order_gift_item(bigint, bigint, integer, text, numeric, text, text) to authenticated;
grant execute on function public.remove_dropship_order_gift_item(bigint) to authenticated;
grant execute on function public.list_shop_auto_gift_items(bigint) to authenticated;
grant execute on function public.upsert_shop_auto_gift_item(bigint, jsonb) to authenticated;
grant execute on function public.delete_shop_auto_gift_item(bigint) to authenticated;
grant execute on function public.apply_shop_auto_gift_items(bigint) to authenticated;
