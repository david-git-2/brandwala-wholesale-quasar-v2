CREATE FUNCTION public.has_shop_notification_access (
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
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and public.resolve_parent_tenant_id(cg.tenant_id) = public.resolve_parent_tenant_id(p_tenant_id)
  );
$function$;

GRANT ALL ON FUNCTION public.has_shop_notification_access(bigint) TO anon;

GRANT ALL ON FUNCTION public.has_shop_notification_access(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.has_shop_notification_access(bigint) TO service_role;