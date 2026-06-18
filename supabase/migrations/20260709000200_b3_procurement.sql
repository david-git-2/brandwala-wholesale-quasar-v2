-- B3: cross-tenant procurement — shipment_items metadata, orders.parent_tenant_id, RPCs
begin;

-- =========================================================
-- 1. orders.parent_tenant_id
-- =========================================================

alter table public.orders
  add column if not exists parent_tenant_id bigint null references public.tenants(id) on delete set null;

create index if not exists orders_parent_tenant_id_idx on public.orders (parent_tenant_id);

update public.orders o
set parent_tenant_id = t.parent_id
from public.tenants t
where o.tenant_id = t.id
  and o.parent_tenant_id is null
  and t.parent_id is not null;

update public.orders o
set parent_tenant_id = o.tenant_id
from public.tenants t
where o.tenant_id = t.id
  and o.parent_tenant_id is null
  and t.parent_id is null;

create or replace function public.set_order_parent_tenant_id()
returns trigger
language plpgsql
as $$
declare
  v_parent_id bigint;
begin
  select parent_id into v_parent_id
  from public.tenants
  where id = new.tenant_id;

  new.parent_tenant_id := coalesce(v_parent_id, new.tenant_id);
  return new;
end;
$$;

drop trigger if exists trg_orders_set_parent_tenant_id on public.orders;
create trigger trg_orders_set_parent_tenant_id
before insert or update of tenant_id on public.orders
for each row
execute function public.set_order_parent_tenant_id();

-- =========================================================
-- 2. shipment_items source metadata
-- =========================================================

alter table public.shipment_items
  add column if not exists source_child_tenant_id bigint null references public.tenants(id) on delete set null,
  add column if not exists source_type text null check (source_type in ('order_item', 'costing_item', 'manual')),
  add column if not exists source_id bigint null;

create index if not exists shipment_items_source_idx
  on public.shipment_items (source_type, source_id);

-- =========================================================
-- 3. list_child_procurement_lines
-- =========================================================

create or replace function public.list_child_procurement_lines(
  p_parent_tenant_id bigint,
  p_child_tenant_id bigint default null,
  p_search text default null,
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  source_type text,
  source_id bigint,
  child_tenant_id bigint,
  child_tenant_name text,
  name text,
  product_id bigint,
  quantity integer,
  cost_bdt numeric,
  price_gbp numeric,
  image_url text,
  barcode text,
  product_code text,
  reference_label text
)
language plpgsql
security definer
set search_path = public
stable
as $$
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  (
    select
      'order_item'::text as source_type,
      oi.id as source_id,
      o.tenant_id as child_tenant_id,
      t.name as child_tenant_name,
      oi.name,
      oi.product_id,
      greatest(coalesce(oi.ordered_quantity, 0), 0)::integer as quantity,
      oi.cost_bdt,
      oi.price_gbp,
      oi.image_url,
      null::text as barcode,
      null::text as product_code,
      ('Order #' || o.id::text || ' — ' || o.name) as reference_label
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    where o.parent_tenant_id = p_parent_tenant_id
      and t.parent_id = p_parent_tenant_id
      and (p_child_tenant_id is null or o.tenant_id = p_child_tenant_id)
      and oi.shipment_id is null
      and coalesce(oi.ordered_quantity, 0) > 0
      and (
        p_search is null or trim(p_search) = ''
        or oi.name ilike '%' || trim(p_search) || '%'
        or o.name ilike '%' || trim(p_search) || '%'
      )
  )
  union all
  (
    select
      'costing_item'::text as source_type,
      pci.id as source_id,
      pcf.tenant_id as child_tenant_id,
      t.name as child_tenant_name,
      pci.name,
      pci.product_id,
      greatest(coalesce(pci.quantity, 0), 0)::integer as quantity,
      pci.offer_price as cost_bdt,
      pci.price_gbp,
      pci.image_url,
      pci.barcode,
      pci.product_code,
      ('Costing #' || pcf.id::text || ' — ' || coalesce(pcf.name, 'Untitled')) as reference_label
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where t.parent_id = p_parent_tenant_id
      and (p_child_tenant_id is null or pcf.tenant_id = p_child_tenant_id)
      and pci.assigned_shipment_id is null
      and coalesce(pci.quantity, 0) > 0
      and (
        p_search is null or trim(p_search) = ''
        or pci.name ilike '%' || trim(p_search) || '%'
        or pcf.name ilike '%' || trim(p_search) || '%'
      )
  )
  order by child_tenant_name, source_type, source_id
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

grant execute on function public.list_child_procurement_lines(bigint, bigint, text, integer, integer) to authenticated;

-- =========================================================
-- 4. add_child_line_to_parent_shipment
-- =========================================================

create or replace function public.add_child_line_to_parent_shipment(
  p_parent_shipment_id bigint,
  p_source_type text,
  p_source_id bigint
)
returns public.shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment public.shipments;
  v_row public.shipment_items;
  v_source_type text;
  v_child_tenant_id bigint;
begin
  v_source_type := lower(trim(coalesce(p_source_type, '')));

  if v_source_type not in ('order_item', 'costing_item') then
    raise exception 'invalid source_type: %', p_source_type;
  end if;

  select * into v_shipment
  from public.shipments
  where id = p_parent_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_source_type = 'order_item' then
    select o.tenant_id into v_child_tenant_id
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.parent_tenant_id = v_shipment.tenant_id
      and oi.shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'order item not available for procurement';
    end if;

    insert into public.shipment_items (
      shipment_id,
      name,
      quantity,
      product_id,
      image_url,
      price_gbp,
      cost_bdt,
      product_weight,
      package_weight,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.name,
      greatest(coalesce(oi.ordered_quantity, 0), 0),
      oi.product_id,
      oi.image_url,
      oi.price_gbp,
      oi.cost_bdt,
      oi.product_weight,
      oi.package_weight,
      v_child_tenant_id,
      'order_item',
      oi.id
    from public.order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.order_items
    set shipment_id = p_parent_shipment_id
    where id = p_source_id;
  else
    select pcf.tenant_id into v_child_tenant_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where pci.id = p_source_id
      and t.parent_id = v_shipment.tenant_id
      and pci.assigned_shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'costing item not available for procurement';
    end if;

    insert into public.shipment_items (
      shipment_id,
      name,
      quantity,
      barcode,
      product_code,
      product_id,
      image_url,
      price_gbp,
      cost_bdt,
      product_weight,
      package_weight,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      pci.name,
      greatest(coalesce(pci.quantity, 0), 0)::integer,
      pci.barcode,
      pci.product_code,
      pci.product_id,
      pci.image_url,
      pci.price_gbp,
      pci.offer_price,
      pci.product_weight,
      pci.package_weight,
      v_child_tenant_id,
      'costing_item',
      pci.id
    from public.product_based_costing_items pci
    where pci.id = p_source_id
    returning * into v_row;

    update public.product_based_costing_items
    set assigned_shipment_id = p_parent_shipment_id
    where id = p_source_id;
  end if;

  return v_row;
end;
$$;

grant execute on function public.add_child_line_to_parent_shipment(bigint, text, bigint) to authenticated;

commit;
