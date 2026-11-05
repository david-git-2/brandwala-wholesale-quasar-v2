CREATE FUNCTION public.update_shipment_progress_tag (
  p_tag_id     bigint,
  p_name       text    DEFAULT NULL::text,
  p_color      text    DEFAULT NULL::text,
  p_sort_order integer DEFAULT NULL::integer
)
  RETURNS public.tags
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tag public.tags;
  v_result public.tags;
  v_new_slug text;
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

  if v_tag.is_system then
    raise exception 'system tags cannot be updated via this RPC';
  end if;

  if p_name is not null and trim(p_name) <> '' then
    v_new_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));
    if exists (
      select 1 from public.tags t
      where t.tenant_id = v_tag.tenant_id
        and t.group_name = 'shipment_progress'
        and t.slug = v_new_slug
        and t.id <> p_tag_id
    ) then
      raise exception 'a progress tag with this name already exists';
    end if;
  else
    v_new_slug := v_tag.slug;
  end if;

  update public.tags
  set
    name       = coalesce(nullif(trim(p_name), ''), name),
    slug       = v_new_slug,
    color      = coalesce(p_color, color),
    sort_order = coalesce(p_sort_order, sort_order)
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.update_shipment_progress_tag(bigint, text, text, integer) TO anon;

GRANT ALL ON FUNCTION public.update_shipment_progress_tag(bigint, text, text, integer) TO authenticated;

GRANT ALL ON FUNCTION public.update_shipment_progress_tag(bigint, text, text, integer) TO service_role;