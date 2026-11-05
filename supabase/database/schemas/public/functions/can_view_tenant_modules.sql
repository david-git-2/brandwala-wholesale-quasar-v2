CREATE FUNCTION public.can_view_tenant_modules (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or public.current_customer_group_id(p_tenant_id) is not null;
$function$;

GRANT ALL ON FUNCTION public.can_view_tenant_modules(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_view_tenant_modules(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_view_tenant_modules(bigint) TO service_role;