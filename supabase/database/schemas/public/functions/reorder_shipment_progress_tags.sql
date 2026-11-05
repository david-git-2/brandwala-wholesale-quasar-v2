CREATE FUNCTION public.reorder_shipment_progress_tags (
  p_tenant_id bigint,
  p_tag_ids   bigint[]
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_idx integer;
  v_id  bigint;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_idx in 1..array_length(p_tag_ids, 1) loop
    v_id := p_tag_ids[v_idx];

    update public.tags
    set sort_order = v_idx
    where id = v_id
      and tenant_id = p_tenant_id
      and group_name = 'shipment_progress';
  end loop;
end;
$function$;

GRANT ALL ON FUNCTION public.reorder_shipment_progress_tags(bigint, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.reorder_shipment_progress_tags(bigint, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.reorder_shipment_progress_tags(bigint, bigint[]) TO service_role;