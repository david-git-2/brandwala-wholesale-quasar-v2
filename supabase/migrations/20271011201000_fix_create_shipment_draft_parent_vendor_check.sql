-- create_shipment_draft regressed in 20271011180000 (v.tenant_id dropped in 20271001140000).

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

  v_vendor_id := p_vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_stock_parent);
  else
    if not exists (
      select 1
      from public.vendors v
      where v.id = v_vendor_id
        and v.parent_tenant_id = v_stock_parent
    ) then
      raise exception 'vendor % does not belong to parent tenant %', v_vendor_id, v_stock_parent;
    end if;
  end if;

  v_cargo_id := p_cargo_company_id;
  if v_cargo_id is null then
    v_cargo_id := public.ensure_default_cargo_company(v_stock_parent);
  else
    if not exists (
      select 1
      from public.cargo_companies c
      where c.id = v_cargo_id
        and c.parent_tenant_id = v_stock_parent
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
    'draft'
  )
  returning * into v_row;

  perform public.ensure_global_shipment_default_section(v_row.id);

  return v_row;
end;
$$;
