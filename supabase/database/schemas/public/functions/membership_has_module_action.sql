CREATE FUNCTION public.membership_has_module_action (
  p_tenant_id  bigint,
  p_module_key text,
  p_action     text
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
      and public.membership_email_matches_current_user(m.email)
      and m.is_active = true
      and (
        m.role in ('owner'::public.app_role, 'manager'::public.app_role)
        or public.has_module_action(p_tenant_id, p_module_key, p_action)
      )
  )
  or public.is_network_owner(p_tenant_id);
$function$;

GRANT ALL ON FUNCTION public.membership_has_module_action(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.membership_has_module_action(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.membership_has_module_action(bigint, text, text) TO service_role;