CREATE FUNCTION public.find_active_tenant_by_public_domain (
  p_public_domain text
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
    and lower(trim(coalesce(t.public_domain, ''))) = nullif(
      regexp_replace(
        lower(
          trim(
            split_part(
              regexp_replace(coalesce(p_public_domain, ''), '^https?://', '', 'i'),
              '/',
              1
            )
          )
        ),
        ':\d+$',
        ''
      ),
      ''
    )
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.find_active_tenant_by_public_domain(text) TO anon;

GRANT ALL ON FUNCTION public.find_active_tenant_by_public_domain(text) TO authenticated;

GRANT ALL ON FUNCTION public.find_active_tenant_by_public_domain(text) TO service_role;