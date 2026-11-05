CREATE FUNCTION public.ensure_shipment_progress_tags (
  p_tenant_id bigint
)
  RETURNS SETOF public.tags
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email constant text := 'system@brandwala.local';
  v_slug text;
  v_name text;
  v_sort integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  -- Seed defaults only if they don't already exist (never overwrite user customizations)
  for v_slug, v_name, v_sort in
    select *
    from (
      values
        ('uk-warehouse'::text, 'UK Warehouse'::text, 1),
        ('on-flight',          'On flight',          2),
        ('airport',            'Airport',            3),
        ('customs-clearance',  'Customs clearance',  4),
        ('bd-warehouse',       'BD Warehouse',       5)
    ) as s(slug, name, sort_order)
  loop
    if not exists (
      select 1 from public.tags t
      where t.tenant_id = p_tenant_id
        and t.slug = v_slug
        and t.group_name = 'shipment_progress'
    ) then
      insert into public.tags (
        tenant_id, name, slug, color, type, group_name, sort_order, created_by_email
      )
      values (
        p_tenant_id,
        v_name,
        v_slug,
        '#64748b',
        'shipment_progress',
        'shipment_progress',
        v_sort,
        v_email
      );
    end if;
  end loop;

  return query
    select t.*
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
    order by t.sort_order nulls last, t.name;
end;
$function$;

GRANT ALL ON FUNCTION public.ensure_shipment_progress_tags(bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_shipment_progress_tags(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_shipment_progress_tags(bigint) TO service_role;