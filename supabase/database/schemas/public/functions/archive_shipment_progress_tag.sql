CREATE FUNCTION public.archive_shipment_progress_tag (
  p_tag_id  bigint,
  p_archive boolean DEFAULT true
)
  RETURNS public.tags
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tag public.tags;
  v_result public.tags;
begin
  select * into v_tag
  from public.tags
  where id = p_tag_id
  for update;

  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag is not a shipment_progress tag';
  end if;

  if not public.has_active_tenant_membership(v_tag.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_archive = true then
    if exists (
      select 1
      from public.global_shipments gs
      where gs.progress_tag_id = p_tag_id
    ) then
      raise exception 'tag is in use by one or more shipments and cannot be archived';
    end if;
  end if;

  update public.tags
  set is_active = not p_archive
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.archive_shipment_progress_tag(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.archive_shipment_progress_tag(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.archive_shipment_progress_tag(bigint, boolean) TO service_role;