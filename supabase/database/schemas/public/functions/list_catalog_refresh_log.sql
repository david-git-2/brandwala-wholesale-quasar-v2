CREATE FUNCTION public.list_catalog_refresh_log (
  p_parent_tenant_id bigint,
  p_limit            integer DEFAULT 50
)
  RETURNS TABLE (
    id               bigint,
    parent_tenant_id bigint,
    source           text,
    event_kind       text,
    source_url       text,
    file_name        text,
    ran_at           timestamp with time zone,
    products_updated integer,
    duration_seconds integer
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;
  if not public.can_view_products_for_parent(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.parent_tenant_id,
    l.source,
    l.event_kind,
    l.source_url,
    l.file_name,
    l.ran_at,
    l.products_updated,
    l.duration_seconds
  from public.catalog_refresh_log l
  where l.parent_tenant_id = p_parent_tenant_id
  order by l.ran_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$function$;

GRANT ALL ON FUNCTION public.list_catalog_refresh_log(bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.list_catalog_refresh_log(bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_catalog_refresh_log(bigint, integer) TO service_role;