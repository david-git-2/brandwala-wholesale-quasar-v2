CREATE FUNCTION public.user_is_tenant_admin (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if public.is_superadmin() then
    return true;
  end if;

  if public.is_network_owner(p_tenant_id) or public.is_tenant_manager(p_tenant_id) then
    return true;
  end if;

  return exists (
    select 1
    from public.memberships m
    left join public.tenant_roles tr on tr.id = m.tenant_role_id
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'owner'::public.app_role
        or tr.is_admin = true
      )
  );
end;
$function$;

GRANT ALL ON FUNCTION public.user_is_tenant_admin(bigint) TO anon;

GRANT ALL ON FUNCTION public.user_is_tenant_admin(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.user_is_tenant_admin(bigint) TO service_role;