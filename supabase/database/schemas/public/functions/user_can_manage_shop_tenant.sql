CREATE FUNCTION public.user_can_manage_shop_tenant (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  );
$function$;

GRANT ALL ON FUNCTION public.user_can_manage_shop_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.user_can_manage_shop_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.user_can_manage_shop_tenant(bigint) TO service_role;