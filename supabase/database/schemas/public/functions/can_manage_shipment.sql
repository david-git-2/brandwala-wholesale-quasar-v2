CREATE FUNCTION public.can_manage_shipment (
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
        and m.role in ('admin', 'staff')
    )
$function$;

GRANT ALL ON FUNCTION public.can_manage_shipment(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_manage_shipment(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_manage_shipment(bigint) TO service_role;