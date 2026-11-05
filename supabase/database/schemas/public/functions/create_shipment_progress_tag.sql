CREATE FUNCTION public.create_shipment_progress_tag (
  p_tenant_id  bigint,
  p_name       text,
  p_color      text    DEFAULT '#64748b'::text,
  p_sort_order integer DEFAULT NULL::integer
)
  RETURNS public.tags
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_slug text;
  v_max_sort integer;
  v_result public.tags;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  -- Slugify name
  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  -- Guard duplicate slug within tenant progress group
  if exists (
    select 1 from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
      and t.slug = v_slug
  ) then
    raise exception 'a progress tag with this name already exists';
  end if;

  -- Default sort_order to end of list
  if p_sort_order is null then
    select coalesce(max(t.sort_order), 0) + 1
    into v_max_sort
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress';
  else
    v_max_sort := p_sort_order;
  end if;

  insert into public.tags (
    tenant_id, name, slug, color, type, group_name, sort_order, is_active, is_system, created_by_email
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_slug,
    coalesce(p_color, '#64748b'),
    'shipment_progress',
    'shipment_progress',
    v_max_sort,
    true,
    false,
    'tenant-settings'
  )
  returning * into v_result;

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.create_shipment_progress_tag(bigint, text, text, integer) TO anon;

GRANT ALL ON FUNCTION public.create_shipment_progress_tag(bigint, text, text, integer) TO authenticated;

GRANT ALL ON FUNCTION public.create_shipment_progress_tag(bigint, text, text, integer) TO service_role;