CREATE FUNCTION public.list_tenants_by_membership (
  p_tenant_id bigint          DEFAULT NULL::bigint,
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
  with direct as (
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
    inner join public.memberships m on m.tenant_id = t.id
    where m.is_active = true
      and (p_tenant_id is null or t.id = p_tenant_id)
      and (p_email is null or lower(trim(m.email)) = lower(trim(p_email)))
      and (p_role is null or m.role = p_role)
  ),
  inherited_children as (
    select distinct
      child.id,
      child.name,
      child.slug,
      child.public_domain,
      child.is_active,
      child.parent_id,
      child.preference,
      child.created_at,
      child.updated_at
    from public.memberships owner_m
    inner join public.tenants child on child.parent_id = owner_m.tenant_id
    where owner_m.is_active = true
      and owner_m.role = 'owner'::public.app_role
      and (p_email is null or lower(trim(owner_m.email)) = lower(trim(p_email)))
      and (p_tenant_id is null or child.id = p_tenant_id)
  )
  select * from direct
  union
  select * from inherited_children
  order by id asc;
$function$;

GRANT ALL ON FUNCTION public.list_tenants_by_membership(bigint, text, public.app_role) TO anon;

GRANT ALL ON FUNCTION public.list_tenants_by_membership(bigint, text, public.app_role) TO authenticated;

GRANT ALL ON FUNCTION public.list_tenants_by_membership(bigint, text, public.app_role) TO service_role;