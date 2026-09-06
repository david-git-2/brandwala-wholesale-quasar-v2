-- Dropship processing desk: stock picks, unavailable lines, cancel, invoice/COD alignment, checkout Option A

begin;

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------

alter table public.shop_order_items
  add column if not exists is_fulfillment_unavailable boolean not null default false,
  add column if not exists unavailable_reason text,
  add column if not exists unavailable_at timestamptz,
  add column if not exists unavailable_by_email text,
  add column if not exists shortfall_quantity integer not null default 0;

alter table public.shop_order_items
  drop constraint if exists shop_order_items_shortfall_non_negative;

alter table public.shop_order_items
  add constraint shop_order_items_shortfall_non_negative
  check (shortfall_quantity >= 0);

create table if not exists public.shop_order_item_stock_picks (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  order_id bigint not null references public.shop_orders(id) on delete cascade,
  order_item_id bigint not null references public.shop_order_items(id) on delete cascade,
  global_stock_id bigint not null references public.global_stocks(id),
  shipment_item_id bigint not null references public.global_shipment_items(id),
  shipment_id bigint not null references public.global_shipments(id),
  quantity integer not null check (quantity > 0),
  held_stock_id bigint references public.global_stocks(id),
  created_by_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (order_item_id, global_stock_id)
);

create index if not exists idx_shop_order_item_stock_picks_order_id
  on public.shop_order_item_stock_picks(order_id);
create index if not exists idx_shop_order_item_stock_picks_order_item_id
  on public.shop_order_item_stock_picks(order_item_id);
create index if not exists idx_shop_order_item_stock_picks_tenant_id
  on public.shop_order_item_stock_picks(tenant_id);
create index if not exists idx_shop_order_item_stock_picks_global_stock_id
  on public.shop_order_item_stock_picks(global_stock_id);

alter table public.shop_order_item_stock_picks enable row level security;

drop policy if exists shop_order_item_stock_picks_staff_all on public.shop_order_item_stock_picks;
create policy shop_order_item_stock_picks_staff_all
  on public.shop_order_item_stock_picks
  using (public.is_tenant_staff(tenant_id))
  with check (public.is_tenant_staff(tenant_id));

grant select, insert, update, delete on public.shop_order_item_stock_picks to authenticated;

-- Backfill in-flight orders with legacy single-stock lines
insert into public.shop_order_item_stock_picks (
  tenant_id,
  order_id,
  order_item_id,
  global_stock_id,
  shipment_item_id,
  shipment_id,
  quantity,
  held_stock_id,
  created_by_email
)
select
  o.tenant_id,
  o.id,
  soi.id,
  gs.id,
  gs.shipment_item_id,
  gsi.shipment_id,
  coalesce(soi.confirmed_quantity, soi.quantity),
  soi.global_stock_id,
  o.created_by_email
from public.shop_order_items soi
join public.shop_orders o on o.id = soi.order_id
join public.global_stocks gs on gs.id = soi.global_stock_id
join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
where o.shop_type_snapshot = 'dropship'
  and o.status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'payment_received', 'returned')
  and soi.global_stock_id is not null
  and coalesce(soi.is_fulfillment_unavailable, false) = false
  and not exists (
    select 1 from public.shop_order_item_stock_picks sp where sp.order_item_id = soi.id
  );

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

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

create or replace function public.recompute_dropship_cod_collect_amount(p_order_id bigint)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_items_resell_delivered numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_cod_collect_amount numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  select coalesce(
    sum(
      coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)
      * coalesce(soi.confirmed_quantity, 0)
    ),
    0
  )
  into v_items_resell_delivered
  from public.shop_order_items soi
  where soi.order_id = p_order_id;

  v_recipient_charge_total :=
    case when not coalesce(v_order.deduct_delivery_from_margin, false)
      then coalesce(v_order.delivery_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_cod_from_margin, false)
      then coalesce(v_order.cod_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_print_from_margin, false)
      then coalesce(v_order.print_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_packing_from_margin, false)
      then coalesce(v_order.packing_charge_amount, 0) else 0 end;

  v_cod_collect_amount :=
    v_items_resell_delivered + v_recipient_charge_total - coalesce(v_order.discount_amount, 0);

  update public.shop_orders
  set cod_collect_amount = v_cod_collect_amount, updated_at = now()
  where id = p_order_id;

  return v_cod_collect_amount;
end;
$$;

-- ---------------------------------------------------------------------------
-- Pick RPCs
-- ---------------------------------------------------------------------------

create or replace function public.list_stock_for_order_item_pick(
  p_order_item_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
  v_limit integer;
  v_offset integer;
  v_grade_tag_id bigint;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'stock pick is only allowed while order is processing';
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is marked unavailable';
  end if;

  v_shop_id := v_order.shop_id;
  v_shop_tenant_id := v_order.tenant_id;
  v_grade_tag_id := coalesce(v_item.grade_tag_id, public.default_stock_grade_tag_id());
  v_limit := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  left join public.tags tg on tg.id = gs.grade_tag_id
  where gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    and gsi.product_id = v_item.product_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
    and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and (
      p_search is null or p_search = ''
      or gsi.name ilike '%' || p_search || '%'
      or gsi.product_code ilike '%' || p_search || '%'
      or gsi.barcode ilike '%' || p_search || '%'
      or gship.name ilike '%' || p_search || '%'
      or tg.name ilike '%' || p_search || '%'
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id as sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'already_picked', coalesce((
          select sp.quantity from public.shop_order_item_stock_picks sp
          where sp.order_item_id = p_order_item_id and sp.global_stock_id = gs.id
        ), 0),
        'stock_grade', case
          when tg.slug is not null then jsonb_build_object('slug', tg.slug, 'label', tg.name, 'color', tg.color)
          else null
        end
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      and gsi.product_id = v_item.product_id
      and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and (
        p_search is null or p_search = ''
        or gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
        or tg.name ilike '%' || p_search || '%'
      )
    order by gs.id desc
    limit v_limit offset v_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil(v_total_count::numeric / v_limit::numeric)),
      'already_picked_total', coalesce((
        select sum(sp.quantity) from public.shop_order_item_stock_picks sp
        where sp.order_item_id = p_order_item_id
      ), 0),
      'ordered_quantity', v_item.quantity,
      'remaining_to_pick', greatest(
        v_item.quantity - coalesce((
          select sum(sp.quantity) from public.shop_order_item_stock_picks sp
          where sp.order_item_id = p_order_item_id
        ), 0),
        0
      )
    )
  );
end;
$$;

create or replace function public.add_shop_order_item_stock_pick(
  p_order_item_id bigint,
  p_global_stock_id bigint,
  p_quantity integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_held_stock_id bigint;
  v_parent_tenant_id bigint;
  v_existing_qty integer := 0;
  v_total_picked integer := 0;
  v_pick_id bigint;
  v_grade_tag_id bigint;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'stock pick is only allowed while order is processing';
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is marked unavailable';
  end if;

  v_grade_tag_id := coalesce(v_item.grade_tag_id, public.default_stock_grade_tag_id());

  select * into v_stock
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = p_global_stock_id
    and gsi.product_id = v_item.product_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
  for update of gs;

  if v_stock.id is null then
    raise exception 'stock not found or does not match line product/grade';
  end if;

  if v_stock.availability <> 'sellable'::public.stock_availability then
    raise exception 'stock is not sellable';
  end if;

  if public.global_stock_atp_qty(v_stock.id) < p_quantity then
    raise exception 'insufficient ATP (requested %, available %)', p_quantity, public.global_stock_atp_qty(v_stock.id);
  end if;

  select coalesce(sum(sp.quantity), 0)
  into v_total_picked
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  select coalesce(sp.quantity, 0)
  into v_existing_qty
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id
    and sp.global_stock_id = p_global_stock_id;

  if v_total_picked - v_existing_qty + p_quantity > v_item.quantity then
    raise exception 'pick quantity exceeds ordered qty (ordered %, would pick %)',
      v_item.quantity, v_total_picked - v_existing_qty + p_quantity;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  perform public.create_and_post_stock_movement(
    p_tenant_id => v_parent_tenant_id,
    p_stock_id => v_stock.id,
    p_quantity => p_quantity,
    p_to_location_id => v_stock.location_id,
    p_to_availability => 'held'::public.stock_availability,
    p_to_grade_tag_id => v_stock.grade_tag_id,
    p_movement_type => 'availability_transfer'::public.stock_movement_type,
    p_notes => 'Dropship processing pick',
    p_reference_type => 'shop_order',
    p_reference_id => v_order.id::text
  );

  select gs.id into v_held_stock_id
  from public.global_stocks gs
  where gs.shipment_item_id = v_stock.shipment_item_id
    and gs.parent_tenant_id = v_parent_tenant_id
    and gs.availability = 'held'::public.stock_availability
    and gs.location_id is not distinct from v_stock.location_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  order by gs.id desc
  limit 1;

  insert into public.shop_order_item_stock_picks (
    tenant_id, order_id, order_item_id, global_stock_id,
    shipment_item_id, shipment_id, quantity, held_stock_id, created_by_email
  )
  values (
    v_order.tenant_id, v_order.id, v_item.id, v_stock.id,
    v_stock.shipment_item_id,
    (select shipment_id from public.global_shipment_items where id = v_stock.shipment_item_id),
    p_quantity, v_held_stock_id, public.current_user_email()
  )
  on conflict (order_item_id, global_stock_id) do update
  set
    quantity = public.shop_order_item_stock_picks.quantity + excluded.quantity,
    held_stock_id = excluded.held_stock_id,
    updated_at = now()
  returning id into v_pick_id;

  perform public._recompute_shop_order_item_fulfillment(p_order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object(
    'success', true,
    'pick_id', v_pick_id,
    'confirmed_quantity', (select confirmed_quantity from public.shop_order_items where id = p_order_item_id),
    'cod_collect_amount', (select cod_collect_amount from public.shop_orders where id = v_order.id)
  );
end;
$$;

create or replace function public.remove_shop_order_item_stock_pick(p_pick_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pick public.shop_order_item_stock_picks%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_parent_tenant_id bigint;
begin
  select * into v_pick from public.shop_order_item_stock_picks where id = p_pick_id for update;
  if v_pick.id is null then
    raise exception 'pick not found';
  end if;

  select * into v_order from public.shop_orders where id = v_pick.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'pick removal is only allowed while order is processing';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

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
        p_notes => 'Undo dropship processing pick',
        p_reference_type => 'shop_order',
        p_reference_id => v_order.id::text
      );
    end if;
  end if;

  delete from public.shop_order_item_stock_picks where id = p_pick_id;

  perform public._recompute_shop_order_item_fulfillment(v_pick.order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.mark_shop_order_item_unavailable(
  p_order_item_id bigint,
  p_reason text default null,
  p_add_to_demand_bucket boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_pick_count integer := 0;
  v_billing_profile_id bigint;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'unavailable is only allowed while order is processing';
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  if v_pick_count > 0 then
    raise exception 'cannot mark unavailable while picks exist — remove picks first';
  end if;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = true,
    unavailable_reason = nullif(trim(p_reason), ''),
    unavailable_at = now(),
    unavailable_by_email = public.current_user_email(),
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_billing_profile_id := coalesce(
      v_order.billing_profile_id,
      public.resolve_billing_profile_for_customer_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_billing_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id,
        v_billing_profile_id,
        v_item.product_id,
        'shop_order'::public.demand_bucket_source_type,
        v_order.id,
        jsonb_build_object(
          'order_item_id', v_item.id,
          'name', v_item.name,
          'reason', coalesce(nullif(trim(p_reason), ''), 'fulfillment_unavailable')
        ),
        v_item.quantity
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.clear_shop_order_item_unavailable(p_order_item_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'clear unavailable is only allowed while order is processing';
  end if;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = false,
    unavailable_reason = null,
    unavailable_at = null,
    unavailable_by_email = null,
    updated_at = now()
  where id = p_order_item_id;

  perform public._recompute_shop_order_item_fulfillment(p_order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Release + cancel
-- ---------------------------------------------------------------------------

create or replace function public.release_dropship_order_stock(
  p_order_id bigint,
  p_restore_display boolean default true
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_item record;
  v_pick record;
  v_skip_stock_release boolean := false;
  v_invoice_status public.global_invoice_status;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
  v_new_override_qty integer;
  v_new_sellable_qty integer;
  v_grade_tag_id bigint;
  v_released_qty integer := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then return; end if;

  if coalesce(v_order.shop_type_snapshot, (
    select shop_type from public.shops where id = v_order.shop_id
  )) <> 'dropship' then
    return;
  end if;

  if v_order.global_invoice_id is not null then
    select invoice_status into v_invoice_status
    from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice_status = 'issued'::public.global_invoice_status then
      v_skip_stock_release := true;
    end if;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if not v_skip_stock_release then
    for v_pick in
      select * from public.shop_order_item_stock_picks where order_id = p_order_id
    loop
      if v_pick.held_stock_id is null then continue; end if;
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
          p_notes => 'Dropship order release (pick)',
          p_reference_type => 'shop_order',
          p_reference_id => p_order_id::text
        );
        v_released_qty := v_released_qty + v_pick.quantity;
      end if;
    end loop;
  end if;

  for v_item in select * from public.shop_order_items where order_id = p_order_id
  loop
    v_grade_tag_id := coalesce(
      v_item.grade_tag_id,
      (select gs.grade_tag_id from public.global_stocks gs where gs.id = v_item.global_stock_id),
      public.default_stock_grade_tag_id()
    );

    if p_restore_display then
      if v_item.listing_id is not null then
        update public.shop_product_listings
        set display_quantity_override = display_quantity_override + v_item.quantity
        where id = v_item.listing_id and display_quantity_override is not null;
      end if;
    end if;

    if not v_skip_stock_release
       and v_item.global_stock_id is not null
       and not exists (
         select 1 from public.shop_order_item_stock_picks sp
         where sp.order_item_id = v_item.id
       ) then
      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= coalesce(v_item.confirmed_quantity, v_item.quantity) then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => coalesce(v_item.confirmed_quantity, v_item.quantity),
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Dropship order release (legacy line)',
          p_reference_type => 'shop_order',
          p_reference_id => p_order_id::text
        );
      end if;
    end if;

    if v_item.listing_id is not null then
      v_new_sellable_qty := public.shop_product_grade_available_units(
        v_order.tenant_id, v_item.product_id, v_grade_tag_id
      );
      select display_quantity_override into v_new_override_qty
      from public.shop_product_listings where id = v_item.listing_id;
      if coalesce(v_new_override_qty, v_new_sellable_qty, 0) > 0 then
        update public.shop_product_listings set is_active = true where id = v_item.listing_id;
      end if;
    end if;
  end loop;
end;
$$;

create or replace function public.cancel_shop_order_dropship(
  p_order_id bigint,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_invoice public.global_invoices%rowtype;
  v_allowed boolean := false;
  v_pick_count integer := 0;
  v_released_picks integer := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_allowed := v_order.status in (
    'submitted', 'draft', 'placed', 'confirmed', 'processing', 'ready_for_pickup'
  );

  if not v_allowed then
    return jsonb_build_object(
      'success', false,
      'error', format('cannot cancel order in status %s', v_order.status)
    );
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks where order_id = p_order_id;

  if v_order.status = 'ready_for_pickup' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.universal_wallet_ledger
    where source_type = 'shop_order'
      and (
        source_id = p_order_id::text
        or source_id = v_order.order_no
        or source_id = v_invoice.invoice_no
      )
      and tenant_id = v_order.tenant_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoices where id = v_order.global_invoice_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;
  elsif v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice.invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
      update public.shop_orders set global_invoice_id = null, updated_at = now() where id = p_order_id;
    end if;
  end if;

  perform public.release_dropship_order_stock(p_order_id, true);
  v_released_picks := v_pick_count;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = false,
    unavailable_reason = null,
    unavailable_at = null,
    unavailable_by_email = null,
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set status = 'cancelled'::public.shop_order_status, updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'new_status', 'cancelled',
    'restock_summary', jsonb_build_object(
      'pick_rows_released', v_released_picks,
      'reason', nullif(trim(p_reason), '')
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Detail RPC (picks payload + gates + cancel permissions)
-- ---------------------------------------------------------------------------

create or replace function public.get_dropship_order_detail_v2(p_tenant_id bigint, p_order_id bigint)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_customer_group_name text;
  v_sell_symbol text;
  v_buy_currency_id bigint;
  v_items jsonb;
  v_courier_services jsonb;
  v_items_resell_total numeric := 0;
  v_items_resell_delivered numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_recipient_grand_total numeric := 0;
  v_total_delivered_qty integer := 0;
  v_all_lines_resolved boolean := true;
  v_can_mark_ready boolean := false;
  v_can_cancel boolean := false;
  v_cancel_blocked_reason text := null;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select o.* into v_order from public.shop_orders o where o.id = p_order_id;
  if not found then raise exception 'order not found'; end if;
  if v_order.tenant_id is distinct from p_tenant_id then raise exception 'tenant mismatch'; end if;
  if v_order.shop_type_snapshot <> 'dropship' then raise exception 'not a dropship order'; end if;

  select s.name, gc.symbol, s.buy_currency_id
  into v_shop_name, v_sell_symbol, v_buy_currency_id
  from public.shops s
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where s.id = v_order.shop_id;

  select cg.name into v_customer_group_name
  from public.customer_groups cg where cg.id = v_order.customer_group_id;

  select coalesce(jsonb_agg(item_json order by sort_created_at, sort_id), '[]'::jsonb)
  into v_items
  from (
    select
      soi.created_at as sort_created_at,
      soi.id as sort_id,
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'cost_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'cost_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_list_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'unit_list_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount', coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount),
        'customer_sell_price_currency_id', coalesce(soi.customer_sell_price_currency_id, soi.final_price_currency_id, soi.unit_sell_price_currency_id),
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'returned_quantity', coalesce(soi.returned_quantity, 0),
        'confirmed_quantity', soi.confirmed_quantity,
        'shortfall_quantity', coalesce(soi.shortfall_quantity, 0),
        'is_fulfillment_unavailable', coalesce(soi.is_fulfillment_unavailable, false),
        'unavailable_reason', soi.unavailable_reason,
        'fulfillment_resolved', (
          coalesce(soi.is_fulfillment_unavailable, false)
          or coalesce(soi.confirmed_quantity, 0) + coalesce(soi.shortfall_quantity, 0) >= soi.quantity
        ),
        'sku', p.product_code,
        'barcode', p.barcode,
        'brand', p.brand,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at,
        'stock_picks', coalesce((
          select jsonb_agg(
            jsonb_build_object(
              'id', sp.id,
              'global_stock_id', sp.global_stock_id,
              'held_stock_id', sp.held_stock_id,
              'shipment_id', sp.shipment_id,
              'shipment_name', gship.name,
              'shipment_item_id', sp.shipment_item_id,
              'quantity', sp.quantity,
              'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(sp.shipment_item_id), 0)
            )
            order by sp.id
          )
          from public.shop_order_item_stock_picks sp
          left join public.global_shipments gship on gship.id = sp.shipment_id
          where sp.order_item_id = soi.id
        ), '[]'::jsonb)
      ) as item_json
    from public.shop_order_items soi
    left join public.products p on p.id = soi.product_id
    where soi.order_id = v_order.id
  ) q;

  select coalesce(sum(soi.quantity * coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)), 0)
  into v_items_resell_total
  from public.shop_order_items soi where soi.order_id = v_order.id;

  select coalesce(sum(coalesce(soi.confirmed_quantity, 0) * coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)), 0)
  into v_items_resell_delivered
  from public.shop_order_items soi where soi.order_id = v_order.id;

  select coalesce(sum(coalesce(soi.confirmed_quantity, 0)), 0)::integer
  into v_total_delivered_qty
  from public.shop_order_items soi where soi.order_id = v_order.id;

  select coalesce(bool_and(
    coalesce(soi.is_fulfillment_unavailable, false)
    or coalesce(soi.confirmed_quantity, 0) + coalesce(soi.shortfall_quantity, 0) >= soi.quantity
  ), false)
  into v_all_lines_resolved
  from public.shop_order_items soi
  where soi.order_id = v_order.id and soi.quantity > 0;

  v_can_mark_ready :=
    v_order.status = 'processing'::public.shop_order_status
    and v_all_lines_resolved
    and v_total_delivered_qty > 0;

  if v_order.status in ('submitted', 'draft', 'placed', 'confirmed', 'processing', 'ready_for_pickup') then
    v_can_cancel := true;
  elsif v_order.status = 'cancelled'::public.shop_order_status then
    v_can_cancel := false;
  else
    v_can_cancel := false;
    v_cancel_blocked_reason := 'Use return flow for shipped or delivered orders';
  end if;

  v_recipient_charge_total :=
    case when not coalesce(v_order.deduct_delivery_from_margin, false) then coalesce(v_order.delivery_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_cod_from_margin, false) then coalesce(v_order.cod_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_print_from_margin, false) then coalesce(v_order.print_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_packing_from_margin, false) then coalesce(v_order.packing_charge_amount, 0) else 0 end;

  v_recipient_grand_total := v_items_resell_delivered + v_recipient_charge_total - coalesce(v_order.discount_amount, 0);

  select coalesce(jsonb_agg(to_jsonb(cs.*) order by cs.created_at, cs.id), '[]'::jsonb)
  into v_courier_services
  from public.courier_services cs
  where cs.is_active = true and (cs.tenant_id is null or cs.tenant_id = v_order.tenant_id);

  return jsonb_build_object(
    'success', true,
    'order', jsonb_build_object(
      'id', v_order.id,
      'tenant_id', v_order.tenant_id,
      'shop_id', v_order.shop_id,
      'shop_name', v_shop_name,
      'customer_group_id', v_order.customer_group_id,
      'customer_group_name', v_customer_group_name,
      'cart_id', v_order.cart_id,
      'order_no', v_order.order_no,
      'name', v_order.name,
      'shop_type_snapshot', v_order.shop_type_snapshot,
      'order_mode_snapshot', v_order.order_mode_snapshot,
      'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
      'status', v_order.status,
      'negotiate_round', v_order.negotiate_round,
      'placed_at', v_order.placed_at,
      'fulfilled_at', v_order.fulfilled_at,
      'global_invoice_id', v_order.global_invoice_id,
      'created_by_email', v_order.created_by_email,
      'created_at', v_order.created_at,
      'updated_at', v_order.updated_at,
      'shop_sell_currency_symbol', v_sell_symbol,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_phone_secondary', v_order.recipient_phone_secondary,
      'shipping_address', v_order.shipping_address,
      'shipping_thana', v_order.shipping_thana,
      'shipping_district', v_order.shipping_district,
      'shipping_post_code', null,
      'recipient_profile_id', v_order.recipient_profile_id,
      'billing_profile_id', v_order.billing_profile_id,
      'delivery_instructions', v_order.delivery_instructions,
      'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
      'cod_charge_amount', v_order.cod_charge_amount,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'print_charge_amount', v_order.print_charge_amount,
      'packing_charge_amount', v_order.packing_charge_amount,
      'discount_amount', v_order.discount_amount,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total),
      'item_count', jsonb_array_length(v_items),
      'delivery_zone', v_order.delivery_zone,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url
    ),
    'items', v_items,
    'summary', jsonb_build_object(
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'cod_charge_amount', v_order.cod_charge_amount,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'print_charge_amount', v_order.print_charge_amount,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'packing_charge_amount', v_order.packing_charge_amount,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'discount_amount', v_order.discount_amount,
      'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total)
    ),
    'computed', jsonb_build_object(
      'items_resell_total', v_items_resell_total,
      'items_resell_delivered_total', v_items_resell_delivered,
      'total_delivered_qty', v_total_delivered_qty,
      'all_lines_resolved', v_all_lines_resolved,
      'recipient_charge_total', v_recipient_charge_total,
      'recipient_grand_total', v_recipient_grand_total,
      'delivery_zone_label',
        case v_order.delivery_zone
          when 'inside_dhaka' then 'Inside Dhaka'
          when 'outside_dhaka' then 'Outside Dhaka'
          else null
        end
    ),
    'fulfillment', jsonb_build_object(
      'pickup', jsonb_build_object(
        'merchant_id', null,
        'sender_name', coalesce(v_order.sender_name, v_order.default_sender_name),
        'pickup_phone', coalesce(v_order.pickup_phone, v_order.default_pickup_phone),
        'pickup_address', coalesce(v_order.pickup_address, v_order.default_pickup_address)
      ),
      'courier', jsonb_build_object(
        'courier_service_id', v_order.courier_service_id,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'allow_open_box', coalesce(v_order.allow_open_box, false),
        'cod_charge', v_order.cod_charge_amount
      )
    ),
    'lookups', jsonb_build_object('courier_services', v_courier_services),
    'permissions', jsonb_build_object(
      'can_show_invoice_paper', v_order.status = 'confirmed',
      'can_start_processing', v_order.status = 'confirmed',
      'can_mark_ready_for_pickup', v_can_mark_ready,
      'can_mark_shipped', v_order.status = 'ready_for_pickup',
      'can_print_customer_invoice', v_order.status in ('ready_for_pickup', 'shipped', 'delivered'),
      'can_cancel_order', v_can_cancel,
      'cancel_blocked_reason', v_cancel_blocked_reason
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Invoice from picks (ready_for_pickup auto-create path)
-- ---------------------------------------------------------------------------

create or replace function public.create_dual_invoice_from_dropship_order(
  p_order_id bigint,
  p_invoice_no text default null,
  p_billing_profile_id bigint default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_billing_profile_id bigint;
  v_profile record;
  v_parent_tenant_id bigint;
  v_invoice_no text;
  v_invoice public.global_invoices;
  v_invoice_id bigint;
  v_orphan_invoice_id bigint;
  v_pick record;
  v_subtotal numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_assigned_child bigint;
  v_total numeric(12,2);
  v_stock_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then raise exception 'Order not found'; end if;
  if v_order.shop_type_snapshot <> 'dropship' then raise exception 'Order is not a dropship order'; end if;
  if v_order.status not in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    raise exception 'Invoice can only be created for orders ready for pickup or later (current: %)', v_order.status;
  end if;
  if v_order.global_invoice_id is not null then
    raise exception 'Invoice already created for this order (invoice_id: %)', v_order.global_invoice_id;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    select id into v_billing_profile_id from public.billing_profiles
    where tenant_id = v_order.tenant_id and customer_group_id = v_order.customer_group_id
    order by created_at asc limit 1;
  end if;
  if v_billing_profile_id is null then raise exception 'Billing profile is required'; end if;

  select * into v_profile from public.billing_profiles where id = v_billing_profile_id;
  if v_profile.id is null then raise exception 'Billing profile not found'; end if;

  v_invoice_no := coalesce(nullif(trim(p_invoice_no), ''), 'INV-DS-' || v_order.order_no);

  select i.id into v_orphan_invoice_id from public.global_invoices i
  where i.invoice_no = v_invoice_no and i.invoice_type = 'dropship'::public.global_invoice_type
    and (i.issued_by_tenant_id = v_order.tenant_id or i.parent_tenant_id = v_parent_tenant_id)
    and not exists (select 1 from public.shop_orders o2 where o2.global_invoice_id = i.id)
  limit 1;

  if v_orphan_invoice_id is not null then
    delete from public.global_return_items where invoice_id = v_orphan_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_orphan_invoice_id;
    delete from public.global_invoices where id = v_orphan_invoice_id;
  end if;

  select ci.id into v_invoice_id from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => 'dropship'::public.global_invoice_type,
    p_billing_profile_id => v_billing_profile_id,
    p_recipient_profile_id => v_order.recipient_profile_id,
    p_recipient_name => coalesce(v_order.recipient_name, v_order.name),
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_note => coalesce(p_note, 'B2B invoice from dropship order #' || v_order.order_no)
  ) ci;

  select * into v_invoice from public.global_invoices where id = v_invoice_id;

  for v_pick in (
    select
      sp.*,
      soi.product_id,
      soi.name as order_item_name,
      soi.unit_sell_price_amount,
      soi.final_price_amount,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      coalesce(public.calculate_landed_unit_cost(sp.shipment_item_id), 0) as stock_cost,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_item_stock_picks sp
    join public.shop_order_items soi on soi.id = sp.order_item_id
    join public.global_shipment_items gsi on gsi.id = sp.shipment_item_id
    join public.global_shipments sh on sh.id = sp.shipment_id
    where sp.order_id = v_order.id
      and coalesce(soi.is_fulfillment_unavailable, false) = false
  ) loop
    v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
    v_item_line_total := v_pick.quantity * v_item_sell_price;
    v_assigned_child := v_pick.stock_assigned_child;
    v_stock_id := coalesce(v_pick.held_stock_id, v_pick.global_stock_id);

    insert into public.global_invoice_items (
      tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
      unit_cost_price, sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id
    ) values (
      v_invoice.tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_stock_id, v_pick.shipment_item_id,
      v_pick.product_id, coalesce(v_pick.stock_name, v_pick.order_item_name), v_pick.stock_barcode,
      v_pick.stock_product_code, v_pick.quantity, v_pick.stock_cost, v_item_sell_price, 0,
      v_item_line_total, v_assigned_child
    );
    v_subtotal := v_subtotal + v_item_line_total;
  end loop;

  if v_subtotal <= 0 then
    raise exception 'cannot create invoice with no picked lines';
  end if;

  v_charges_total := coalesce(v_order.print_charge_amount, 0) + coalesce(v_order.packing_charge_amount, 0);
  v_total := greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0);

  update public.global_invoices set
    subtotal_amount = v_subtotal,
    shipping_charge = 0,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    total_amount = v_total,
    paid_amount = 0,
    due_amount = v_total,
    payment_status = 'due',
    collection_source = case when coalesce(v_order.is_prepaid_snapshot, false)
      then 'billing_profile'::public.collection_source_type else 'recipient'::public.collection_source_type end,
    invoice_status = 'issued'::public.global_invoice_status,
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders set global_invoice_id = v_invoice.id, updated_at = now() where id = v_order.id;
  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'invoice_status', 'issued',
    'subtotal_amount', v_subtotal,
    'total_amount', v_total
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Phase 4: checkout Option A — listing soft reserve only; no sellable→held at place order
-- ---------------------------------------------------------------------------

create or replace function public.submit_dropship_order_from_cart(
  p_shop_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text default null,
  p_shipping_district text default null,
  p_shipping_thana text default null,
  p_shipping_post_code text default null,
  p_billing_profile_id bigint default null,
  p_is_prepaid boolean default false,
  p_delivery_instructions text default null,
  p_cod_charge_amount numeric default 0,
  p_delivery_charge_amount numeric default 0,
  p_print_charge_amount numeric default 0,
  p_packing_charge_amount numeric default 0,
  p_discount_amount numeric default 0,
  p_recipient_pays_delivery boolean default true,
  p_recipient_pays_cod boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_customer_group_id bigint;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
begin
  select * into v_shop from public.shops where id = p_shop_id and is_active = true;
  if v_shop.id is null then raise exception 'shop not found or inactive'; end if;
  if v_shop.shop_type <> 'dropship' then raise exception 'shop is not dropship'; end if;
  if not public.can_customer_access_shop(p_shop_id) then raise exception 'access denied'; end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id and access.status = true and cg.is_active = true
    and cgm.is_active = true and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc limit 1;

  if v_customer_group_id is null then raise exception 'no customer group access found'; end if;

  select * into v_cart from public.shop_carts c
  where c.tenant_id = v_shop.tenant_id and c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id and c.status = 'active'
  order by c.id desc limit 1;

  if v_cart.id is null then raise exception 'active cart not found'; end if;
  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then raise exception 'access denied'; end if;

  select can_place_order into v_can_place_order from public.get_shop_permissions_for_customer(p_shop_id);
  if coalesce(v_can_place_order, false) is not true then raise exception 'checkout not allowed for this customer group'; end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = v_cart.id;
  if v_item_count = 0 then raise exception 'cart is empty'; end if;

  if nullif(trim(coalesce(p_recipient_name, '')), '') is null then raise exception 'recipient name is required'; end if;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is null then raise exception 'recipient phone is required'; end if;
  if nullif(trim(coalesce(p_shipping_address, '')), '') is null then raise exception 'shipping address is required'; end if;
  if nullif(trim(coalesce(p_shipping_district, '')), '') is null then raise exception 'shipping district is required'; end if;
  if nullif(trim(coalesce(p_shipping_thana, '')), '') is null then raise exception 'shipping thana is required'; end if;

  if exists (
    select 1 from public.shop_cart_items ci
    where ci.cart_id = v_cart.id
      and coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0) < ci.unit_minimum_sell_price_amount
  ) then
    raise exception 'price floor violation: some items are priced below the minimum sell price';
  end if;

  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.order_mode = 'checkout_fixed' then v_order_status := 'confirmed';
  else v_order_status := 'submitted'; end if;

  v_deduct_delivery_from_margin := not coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := not coalesce(p_recipient_pays_cod, true);

  select public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) into v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_cart.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, billing_profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id, v_order_no,
    'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable, v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id, public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin, v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  ) returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id, confirmed_quantity
  )
  select
    v_order_id, ci.product_id, ci.listing_id,
    coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
    null, null, ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount) else null end,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id) else null end,
    coalesce(ci.unit_list_price_amount, public.shop_product_grade_avg_landed_cost(
      v_cart.tenant_id, ci.product_id,
      coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
    )),
    v_shop.buy_currency_id, 0
  from public.shop_cart_items ci
  left join public.shop_product_listings l on l.id = ci.listing_id
  left join public.global_stocks gs on gs.id = ci.global_stock_id
  where ci.cart_id = v_cart.id;

  for v_ci in select * from public.shop_cart_items where cart_id = v_cart.id loop
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (select l.grade_tag_id from public.shop_product_listings l where l.id = v_ci.listing_id),
      (select gs.grade_tag_id from public.global_stocks gs where gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id order by l.id asc limit 1),
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and l.global_stock_id = v_ci.global_stock_id limit 1)
    );

    if v_listing_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where id = v_listing_id and display_quantity_override is not null;
    elsif v_ci.global_stock_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id
        and display_quantity_override is not null;
    end if;

    select soi.id into v_order_item_id from public.shop_order_items soi
    where soi.order_id = v_order_id and soi.product_id = v_ci.product_id
      and soi.listing_id is not distinct from v_ci.listing_id order by soi.id asc limit 1;
    if v_order_item_id is null then
      select soi.id into v_order_item_id from public.shop_order_items soi
      where soi.order_id = v_order_id and soi.product_id = v_ci.product_id order by soi.id asc limit 1;
    end if;
    if v_order_item_id is not null then
      update public.shop_order_items
      set listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
      where id = v_order_item_id;
    end if;

    if v_listing_id is not null then
      v_available_after := public.shop_product_grade_available_units(v_cart.tenant_id, v_ci.product_id, v_grade_tag_id);
      if coalesce((select display_quantity_override from public.shop_product_listings where id = v_listing_id), v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false where id = v_listing_id;
      end if;
    elsif v_ci.global_stock_id is not null then
      select coalesce(sum(gs.quantity), 0) into v_available_after from public.global_stocks gs
      where gs.shipment_item_id = (select shipment_item_id from public.global_stocks where id = v_ci.global_stock_id)
        and gs.availability = 'sellable'::public.stock_availability;
      if coalesce((select display_quantity_override from public.shop_product_listings
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id),
        v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id;
      end if;
    end if;
  end loop;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = v_cart.id);
  update public.shop_carts set status = 'converted', updated_at = now() where id = v_cart.id;

  perform public.recompute_dropship_cod_collect_amount(v_order_id);

  select jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'cart_id', v_cart.id, 'shop_id', v_shop.id
  ) into v_result;
  return v_result;
end;
$$;

-- Phase 5: partial shortfall on unavailable-style RPC
create or replace function public.mark_shop_order_item_shortfall(
  p_order_item_id bigint,
  p_shortfall_qty integer,
  p_reason text default null,
  p_add_to_demand_bucket boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_picked integer := 0;
  v_billing_profile_id bigint;
begin
  if p_shortfall_qty is null or p_shortfall_qty <= 0 then
    raise exception 'shortfall quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  select * into v_order from public.shop_orders where id = v_item.order_id for update;

  if not public.is_tenant_staff(v_order.tenant_id) then raise exception 'access denied'; end if;
  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'shortfall only allowed while processing';
  end if;
  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is fully unavailable';
  end if;

  select coalesce(sum(sp.quantity), 0) into v_picked
  from public.shop_order_item_stock_picks sp where sp.order_item_id = p_order_item_id;

  if v_picked + p_shortfall_qty > v_item.quantity then
    raise exception 'shortfall exceeds remaining qty';
  end if;

  update public.shop_order_items
  set shortfall_quantity = p_shortfall_qty, updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_billing_profile_id := coalesce(
      v_order.billing_profile_id,
      public.resolve_billing_profile_for_customer_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_billing_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id, v_billing_profile_id, v_item.product_id,
        'shop_order'::public.demand_bucket_source_type, v_order.id,
        jsonb_build_object('order_item_id', v_item.id, 'reason', coalesce(p_reason, 'partial_shortfall')),
        p_shortfall_qty
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);
  return jsonb_build_object('success', true);
end;
$$;

grant execute on function public.list_stock_for_order_item_pick(bigint, text, integer, integer) to authenticated;
grant execute on function public.add_shop_order_item_stock_pick(bigint, bigint, integer) to authenticated;
grant execute on function public.remove_shop_order_item_stock_pick(bigint) to authenticated;
grant execute on function public.mark_shop_order_item_unavailable(bigint, text, boolean) to authenticated;
grant execute on function public.clear_shop_order_item_unavailable(bigint) to authenticated;
grant execute on function public.cancel_shop_order_dropship(bigint, text) to authenticated;
grant execute on function public.recompute_dropship_cod_collect_amount(bigint) to authenticated;
grant execute on function public.mark_shop_order_item_shortfall(bigint, integer, text, boolean) to authenticated;

commit;
