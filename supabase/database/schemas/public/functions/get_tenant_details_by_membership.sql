CREATE FUNCTION public.get_tenant_details_by_membership (
  p_tenant_id bigint,
  p_email     text            DEFAULT NULL::text,
  p_role      public.app_role DEFAULT NULL::public.app_role
)
  RETURNS TABLE (
    id            bigint,
    name          text,
    slug          text,
    public_domain text,
    is_active     boolean,
    parent_id     bigint,
    preference    jsonb,
    created_at    timestamp with time zone,
    updated_at    timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select distinct
    t.id,
    t.name,
    t.slug,
    t.public_domain,
    t.is_active,
    t.parent_id,
    t.preference,
    t.created_at,
    t.updated_at
  from public.tenants t
  inner join public.memberships m
    on m.tenant_id = t.id
  where t.id = p_tenant_id
    and m.is_active = true
    and (
      p_email is null
      or lower(trim(m.email)) = lower(trim(p_email))
    )
    and (p_role is null or m.role = p_role)
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.get_tenant_details_by_membership(bigint, text, public.app_role) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_details_by_membership(bigint, text, public.app_role) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_details_by_membership(bigint, text, public.app_role) TO service_role;