CREATE FUNCTION public.reorder_shipment_sections (
  p_shipment_id bigint,
  p_section_ids bigint[]
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments;
  v_idx integer;
  v_section_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_section_ids is null or array_length(p_section_ids, 1) is null then
    return;
  end if;

  for v_idx in 1..array_length(p_section_ids, 1) loop
    v_section_id := p_section_ids[v_idx];

    update public.global_shipment_sections
    set sort_order = v_idx - 1,
        updated_at = now()
    where id = v_section_id
      and shipment_id = p_shipment_id;
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public.reorder_shipment_sections(bigint, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.reorder_shipment_sections(bigint, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.reorder_shipment_sections(bigint, bigint[]) TO service_role;