CREATE FUNCTION public.find_active_tenant_by_slug (
  p_slug text
)
  RETURNS TABLE (
    id            bigint,
    name          text,
    slug          text,
    public_domain text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    t.id,
    t.name,
    t.slug,
    t.public_domain
  from public.tenants t
  where t.is_active = true
    and lower(trim(t.slug)) = nullif(lower(trim(coalesce(p_slug, ''))), '')
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.find_active_tenant_by_slug(text) TO anon;

GRANT ALL ON FUNCTION public.find_active_tenant_by_slug(text) TO authenticated;

GRANT ALL ON FUNCTION public.find_active_tenant_by_slug(text) TO service_role;