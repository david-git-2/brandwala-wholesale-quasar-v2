-- Vendor and notes are optional on procurement placements.
begin;

alter table public.procurement_placements
  drop constraint if exists procurement_placements_vendor_present_check;

create or replace function public.record_procurement_placement(
  p_tenant_id bigint,
  p_source_type public.procurement_placement_source_type,
  p_source_id bigint,
  p_quantity integer,
  p_vendor_id bigint default null,
  p_vendor_code text default null,
  p_notes text default null
)
returns public.procurement_placements
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.procurement_placements;
  v_line_tenant_id bigint;
  v_open_qty integer;
  v_doc_status text;
  v_placed integer;
  v_vendor_code text;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if p_source_id is null then
    raise exception 'source_id is required';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be positive';
  end if;

  select g.tenant_id, g.open_qty, g.document_status
  into v_line_tenant_id, v_open_qty, v_doc_status
  from public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  if v_line_tenant_id is null then
    raise exception 'demand line not found';
  end if;

  if not public.can_access_procurement_placement_tenant(p_tenant_id)
    and not public.can_access_procurement_placement_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1 from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand line';
    end if;
  end if;
  if v_doc_status not in ('procuring', 'ready_for_shipment') then
    raise exception 'document is not open for placements';
  end if;

  select coalesce(sum(pp.quantity), 0)::integer into v_placed
  from public.procurement_placements pp
  where pp.source_type = p_source_type
    and pp.source_id = p_source_id
    and pp.status = 'active';

  if v_placed + p_quantity > v_open_qty then
    raise exception 'placement exceeds remaining demand (open %, already placed %, requested %)',
      v_open_qty, v_placed, p_quantity;
  end if;

  v_vendor_code := nullif(trim(coalesce(p_vendor_code, '')), '');
  if p_vendor_id is not null and v_vendor_code is null then
    select v.code into v_vendor_code from public.vendors v where v.id = p_vendor_id;
  end if;

  insert into public.procurement_placements (
    tenant_id,
    source_type,
    source_id,
    vendor_id,
    vendor_code,
    quantity,
    notes,
    placed_by_user_id
  ) values (
    v_line_tenant_id,
    p_source_type,
    p_source_id,
    p_vendor_id,
    v_vendor_code,
    p_quantity,
    nullif(trim(coalesce(p_notes, '')), ''),
    auth.uid()
  )
  returning * into v_row;

  return v_row;
end;
$$;

commit;
