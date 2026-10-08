-- Per-reseller customer gift stock (name + qty) on shop settings Gifts tab

alter table public.shop_customer_stocks
  add column if not exists customer_group_id bigint references public.customer_groups (id) on delete cascade,
  add column if not exists item_label text;

alter table public.shop_customer_stocks
  drop constraint if exists shop_customer_stocks_shop_product_key;

alter table public.shop_customer_stocks
  alter column product_id drop not null;

alter table public.shop_customer_stocks
  drop constraint if exists shop_customer_stocks_product_or_label_check;

alter table public.shop_customer_stocks
  add constraint shop_customer_stocks_product_or_label_check
  check (
    product_id is not null
    or (item_label is not null and length(trim(item_label)) > 0)
  );

create unique index if not exists shop_customer_stocks_shop_group_product_key
  on public.shop_customer_stocks (shop_id, customer_group_id, product_id)
  where product_id is not null;

create unique index if not exists shop_customer_stocks_shop_group_label_key
  on public.shop_customer_stocks (shop_id, customer_group_id, lower(trim(item_label)))
  where product_id is null and item_label is not null;

create index if not exists idx_shop_customer_stocks_shop_group
  on public.shop_customer_stocks (shop_id, customer_group_id);

alter table public.shop_order_items
  alter column product_id drop not null;

alter table public.shop_order_items
  drop constraint if exists shop_order_items_product_id_gift_check;

alter table public.shop_order_items
  add constraint shop_order_items_product_id_gift_check
  check (
    product_id is not null
    or (is_gift = true and gift_source = 'customer_stock')
  );

drop function if exists public.list_shop_customer_stocks(bigint);

create or replace function public.list_shop_customer_stocks(
  p_shop_id bigint,
  p_customer_group_id bigint default null
)
returns table (
  id bigint,
  shop_id bigint,
  customer_group_id bigint,
  product_id bigint,
  product_name text,
  product_code text,
  item_label text,
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
    scs.customer_group_id,
    scs.product_id,
    coalesce(p.name, scs.item_label) as product_name,
    p.product_code,
    scs.item_label,
    scs.quantity_on_hand,
    scs.updated_at
  from public.shop_customer_stocks scs
  left join public.products p on p.id = scs.product_id
  where scs.shop_id = p_shop_id
    and (
      p_customer_group_id is null
      or scs.customer_group_id = p_customer_group_id
    )
  order by coalesce(p.name, scs.item_label), scs.id;
end;
$$;

drop function if exists public.receive_shop_customer_stock(bigint, bigint, integer);

create or replace function public.receive_shop_customer_stock(
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_quantity integer,
  p_product_id bigint default null,
  p_item_label text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops%rowtype;
  v_row public.shop_customer_stocks%rowtype;
  v_label text;
  v_product_id bigint;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('success', false, 'error', 'quantity must be positive');
  end if;

  if p_customer_group_id is null then
    return jsonb_build_object('success', false, 'error', 'customer_group_id required');
  end if;

  if p_product_id is null and (p_item_label is null or length(trim(p_item_label)) = 0) then
    return jsonb_build_object('success', false, 'error', 'product or item name required');
  end if;

  select * into v_shop from public.shops where id = p_shop_id for update;
  if v_shop.id is null then
    return jsonb_build_object('success', false, 'error', 'shop not found');
  end if;

  if not public.is_tenant_staff(v_shop.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if not exists (
    select 1
    from public.shop_customer_group_access scga
    where scga.shop_id = p_shop_id
      and scga.customer_group_id = p_customer_group_id
  ) then
    return jsonb_build_object('success', false, 'error', 'customer does not have shop access');
  end if;

  v_product_id := p_product_id;
  v_label := nullif(trim(p_item_label), '');

  if v_product_id is not null then
    if not exists (select 1 from public.products where id = v_product_id) then
      return jsonb_build_object('success', false, 'error', 'product not found');
    end if;

    select * into v_row
    from public.shop_customer_stocks
    where shop_id = p_shop_id
      and customer_group_id = p_customer_group_id
      and product_id = v_product_id
    for update;

    if v_row.id is null then
      insert into public.shop_customer_stocks (
        tenant_id, shop_id, customer_group_id, product_id, item_label, quantity_on_hand
      )
      values (v_shop.tenant_id, p_shop_id, p_customer_group_id, v_product_id, null, p_quantity)
      returning * into v_row;
    else
      update public.shop_customer_stocks
      set
        quantity_on_hand = v_row.quantity_on_hand + p_quantity,
        updated_at = now()
      where id = v_row.id
      returning * into v_row;
    end if;
  else
    select * into v_row
    from public.shop_customer_stocks
    where shop_id = p_shop_id
      and customer_group_id = p_customer_group_id
      and product_id is null
      and lower(trim(item_label)) = lower(v_label)
    for update;

    if v_row.id is null then
      insert into public.shop_customer_stocks (
        tenant_id, shop_id, customer_group_id, product_id, item_label, quantity_on_hand
      )
      values (v_shop.tenant_id, p_shop_id, p_customer_group_id, null, v_label, p_quantity)
      returning * into v_row;
    else
      update public.shop_customer_stocks
      set
        quantity_on_hand = v_row.quantity_on_hand + p_quantity,
        updated_at = now()
      where id = v_row.id
      returning * into v_row;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'row', jsonb_build_object(
      'id', v_row.id,
      'product_id', v_row.product_id,
      'item_label', v_row.item_label,
      'quantity_on_hand', v_row.quantity_on_hand
    )
  );
end;
$$;

drop function if exists public.add_dropship_order_gift_item(bigint, bigint, integer, text, numeric, text, text);

create or replace function public.add_dropship_order_gift_item(
  p_order_id bigint,
  p_product_id bigint,
  p_quantity integer,
  p_gift_source text,
  p_gift_cost_amount numeric default 0,
  p_gift_cost_charged_to text default null,
  p_gift_added_by text default 'manual',
  p_shop_customer_stock_id bigint default null
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
  v_item_name text;
  v_item_image text;
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

  v_cost := coalesce(p_gift_cost_amount, 0);
  v_charged_to := p_gift_cost_charged_to;

  if p_gift_source = 'customer_stock' then
    v_cost := 0;
    v_charged_to := null;

    if p_shop_customer_stock_id is not null then
      select * into v_cust_stock
      from public.shop_customer_stocks
      where id = p_shop_customer_stock_id
        and shop_id = v_order.shop_id
      for update;
    else
      if p_product_id is null then
        return jsonb_build_object('success', false, 'error', 'product_id or shop_customer_stock_id required');
      end if;

      select * into v_product from public.products where id = p_product_id;
      if v_product.id is null then
        return jsonb_build_object('success', false, 'error', 'product not found');
      end if;

      select * into v_cust_stock
      from public.shop_customer_stocks
      where shop_id = v_order.shop_id
        and customer_group_id = v_order.customer_group_id
        and product_id = p_product_id
      for update;
    end if;

    if v_cust_stock.id is null or v_cust_stock.quantity_on_hand < p_quantity then
      return jsonb_build_object('success', false, 'error', 'insufficient customer stock for this product');
    end if;

    if v_cust_stock.customer_group_id is distinct from v_order.customer_group_id then
      return jsonb_build_object('success', false, 'error', 'customer stock does not belong to this order reseller');
    end if;

    update public.shop_customer_stocks
    set quantity_on_hand = quantity_on_hand - p_quantity, updated_at = now()
    where id = v_cust_stock.id;

    if v_cust_stock.product_id is not null then
      select * into v_product from public.products where id = v_cust_stock.product_id;
      v_item_name := v_product.name;
      v_item_image := v_product.image_url;
    else
      v_item_name := coalesce(v_cust_stock.item_label, 'Gift item');
      v_item_image := null;
    end if;

    insert into public.shop_order_items (
      order_id, product_id, name, image_url, quantity,
      unit_sell_price_amount, final_price_amount, customer_sell_price_amount,
      is_gift, gift_source, gift_cost_amount, gift_cost_charged_to,
      shop_customer_stock_id, gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, v_cust_stock.product_id, v_item_name, v_item_image, p_quantity,
      0, 0, 0,
      true, 'customer_stock', 0, null,
      v_cust_stock.id, coalesce(p_gift_added_by, 'manual'), p_quantity
    )
    returning id into v_item_id;

  else
    select * into v_product from public.products where id = p_product_id;
    if v_product.id is null then
      return jsonb_build_object('success', false, 'error', 'product not found');
    end if;

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
      shop_customer_stock_id, gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, p_product_id, v_product.name, v_product.image_url, p_quantity,
      0, 0, 0,
      true, 'stock', v_cost, v_charged_to,
      null, coalesce(p_gift_added_by, 'manual'), 0
    )
    returning id into v_item_id;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true, 'order_item_id', v_item_id);
end;
$$;

grant execute on function public.list_shop_customer_stocks(bigint, bigint) to authenticated;
grant execute on function public.receive_shop_customer_stock(bigint, bigint, integer, bigint, text) to authenticated;
grant execute on function public.add_dropship_order_gift_item(bigint, bigint, integer, text, numeric, text, text, bigint) to authenticated;
