CREATE FUNCTION public.ensure_global_shipment_default_section (
  p_shipment_id bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
  v_section_id bigint;
  v_vendor_id bigint;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if not found then
    raise exception 'shipment not found';
  end if;

  select s.id into v_section_id
  from public.global_shipment_sections s
  where s.shipment_id = p_shipment_id
  order by s.sort_order asc, s.id asc
  limit 1;

  if v_section_id is not null then
    return v_section_id;
  end if;

  v_vendor_id := v_ship.vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_ship.parent_tenant_id);
  end if;

  insert into public.global_shipment_sections (
    parent_tenant_id,
    shipment_id,
    vendor_id,
    title,
    sort_order,
    metadata
  )
  values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    v_vendor_id,
    'Section 1',
    0,
    '{}'::jsonb
  )
  returning id into v_section_id;

  return v_section_id;
end;
$function$;

GRANT ALL ON FUNCTION public.ensure_global_shipment_default_section(bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_global_shipment_default_section(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_global_shipment_default_section(bigint) TO service_role;