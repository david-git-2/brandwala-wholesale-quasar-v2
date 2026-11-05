CREATE FUNCTION public.resolve_tenant_for_entry (
  p_slug     text DEFAULT NULL::text,
  p_hostname text DEFAULT NULL::text
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
  with domain_match as (
    select *
    from public.find_active_tenant_by_public_domain(p_hostname)
  ),
  slug_match as (
    select *
    from public.find_active_tenant_by_slug(p_slug)
  )
  select *
  from domain_match
  union all
  select *
  from slug_match
  where not exists (select 1 from domain_match)
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.resolve_tenant_for_entry(text, text) TO anon;

GRANT ALL ON FUNCTION public.resolve_tenant_for_entry(text, text) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_tenant_for_entry(text, text) TO service_role;