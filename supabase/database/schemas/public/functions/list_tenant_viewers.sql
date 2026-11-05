CREATE FUNCTION public.list_tenant_viewers (
  p_tenant_id bigint
)
  RETURNS TABLE (
    membership_id bigint,
    tenant_id     bigint,
    name          text,
    email         text,
    role          public.app_role,
    is_active     boolean,
    created_at    timestamp with time zone,
    updated_at    timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    m.id as membership_id,
    m.tenant_id,
    m.email as name,
    m.email,
    m.role,
    m.is_active,
    m.created_at,
    m.updated_at
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and exists (
      select 1
      from public.tenants t
      where t.id = p_tenant_id
        and public.can_manage_costing_file_viewers(t.id)
    )
    and m.role = 'viewer'
  order by m.created_at asc, m.id asc;
$function$;

GRANT ALL ON FUNCTION public.list_tenant_viewers(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_tenant_viewers(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_tenant_viewers(bigint) TO service_role;