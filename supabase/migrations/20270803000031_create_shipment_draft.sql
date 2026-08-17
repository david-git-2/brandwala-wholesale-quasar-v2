-- Phase 2: restore global_shipments.vendor_id (+ cargo_company_id) and create_shipment_draft RPC
-- Depends on Phase 1: every parent tenant has a default vendor via ensure_default_vendor.

begin;

-- ---------------------------------------------------------------------------
-- 1. Columns
-- ---------------------------------------------------------------------------

alter table public.global_shipments
  add column if not exists vendor_id bigint references public.vendors(id) on delete restrict;

alter table public.global_shipments
  add column if not exists cargo_company_id bigint references public.cargo_companies(id) on delete set null;

create index if not exists global_shipments_vendor_idx
  on public.global_shipments (vendor_id);

create index if not exists global_shipments_cargo_company_idx
  on public.global_shipments (cargo_company_id);

-- ---------------------------------------------------------------------------
-- 2. Backfill vendor_id
--    Prefer majority of item vendor_id; else tenant default vendor.
-- ---------------------------------------------------------------------------

with item_vendor_counts as (
  select
    i.shipment_id,
    i.vendor_id,
    count(*)::bigint as cnt
  from public.global_shipment_items i
  where i.vendor_id is not null
  group by i.shipment_id, i.vendor_id
),
ranked as (
  select
    ivc.shipment_id,
    ivc.vendor_id,
    row_number() over (
      partition by ivc.shipment_id
      order by ivc.cnt desc, ivc.vendor_id asc
    ) as rn
  from item_vendor_counts ivc
  inner join public.global_shipments gs on gs.id = ivc.shipment_id
  inner join public.tenants t on t.id = gs.parent_tenant_id
  inner join public.vendors v on v.id = ivc.vendor_id
  where coalesce(v.parent_tenant_id, v.tenant_id) = coalesce(t.parent_id, t.id)
)
update public.global_shipments gs
set vendor_id = r.vendor_id
from ranked r
where gs.id = r.shipment_id
  and r.rn = 1
  and gs.vendor_id is null;

-- Remaining nulls → stock-owning parent’s default vendor
-- (some legacy rows store a child id in parent_tenant_id)
do $$
declare
  r record;
  v_stock_parent bigint;
  v_default bigint;
begin
  for r in
    select distinct
      gs.parent_tenant_id as shipment_scope_id,
      coalesce(t.parent_id, t.id) as stock_parent_id
    from public.global_shipments gs
    inner join public.tenants t on t.id = gs.parent_tenant_id
    where gs.vendor_id is null
  loop
    v_stock_parent := r.stock_parent_id;
    v_default := public.ensure_default_vendor(v_stock_parent);

    update public.global_shipments
    set vendor_id = v_default
    where parent_tenant_id = r.shipment_scope_id
      and vendor_id is null;
  end loop;
end
$$;

-- Enforce NOT NULL after backfill
alter table public.global_shipments
  alter column vendor_id set not null;

-- ---------------------------------------------------------------------------
-- 3. create_shipment_draft
-- ---------------------------------------------------------------------------

create or replace function public.create_shipment_draft(
  p_parent_tenant_id bigint,
  p_name text,
  p_type public.global_shipment_type,
  p_vendor_id bigint default null,
  p_cargo_company_id bigint default null
)
returns public.global_shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_stock_parent bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_row public.global_shipments%rowtype;
begin
  if p_parent_tenant_id is null then
    raise exception 'p_parent_tenant_id is required';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if p_type is null then
    raise exception 'type is required';
  end if;

  v_stock_parent := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not public.user_can_manage_parent_tenant(v_stock_parent) then
    raise exception 'not allowed';
  end if;

  -- Vendor: explicit or tenant default
  v_vendor_id := p_vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_stock_parent);
  else
    if not exists (
      select 1
      from public.vendors v
      where v.id = v_vendor_id
        and coalesce(v.parent_tenant_id, v.tenant_id) = v_stock_parent
    ) then
      raise exception 'vendor % does not belong to parent tenant %', v_vendor_id, v_stock_parent;
    end if;
  end if;

  -- Optional cargo company (same parent scope)
  v_cargo_id := p_cargo_company_id;
  if v_cargo_id is not null then
    if not exists (
      select 1
      from public.cargo_companies c
      where c.id = v_cargo_id
        and coalesce(c.parent_tenant_id, c.tenant_id) = v_stock_parent
    ) then
      raise exception 'cargo company % does not belong to parent tenant %', v_cargo_id, v_stock_parent;
    end if;
  end if;

  insert into public.global_shipments (
    parent_tenant_id,
    name,
    type,
    vendor_id,
    cargo_company_id,
    status
  )
  values (
    v_stock_parent,
    trim(p_name),
    p_type,
    v_vendor_id,
    v_cargo_id,
    'Draft'
  )
  returning * into v_row;

  -- Intentionally no cost entries on draft create
  return v_row;
end;
$$;

revoke all on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) from public;
grant execute on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) to authenticated;
grant execute on function public.create_shipment_draft(
  bigint, text, public.global_shipment_type, bigint, bigint
) to service_role;

commit;
