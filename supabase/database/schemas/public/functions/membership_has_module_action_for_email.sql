CREATE FUNCTION public.membership_has_module_action_for_email (
  p_email      text,
  p_tenant_id  bigint,
  p_module_key text,
  p_action     text
)
  RETURNS boolean
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_email text := lower(trim(coalesce(p_email, '')));
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_member_role public.app_role;
  v_override_effect text;
  v_role_allowed boolean;
begin
  if v_email = '' or p_tenant_id is null or p_module_key is null then
    return false;
  end if;

  if public.is_network_owner_for_email(p_email, p_tenant_id) then
    return true;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(p_tenant_id))) then
    return false;
  end if;

  select m.id, m.tenant_role_id, tr.is_admin, m.role
  into v_member_id, v_tenant_role_id, v_role_is_admin, v_member_role
  from public.memberships m
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = v_email
    and m.is_active = true;

  if v_member_id is null then
    return false;
  end if;

  if v_member_role in ('owner'::public.app_role, 'manager'::public.app_role)
     or coalesce(v_role_is_admin, false) = true then
    return true;
  end if;

  select effect
  into v_override_effect
  from public.membership_grants
  where membership_id = v_member_id
    and module_key = p_module_key
    and action = p_action;

  if v_override_effect = 'deny' then
    return false;
  elsif v_override_effect = 'allow' then
    return true;
  end if;

  select allowed
  into v_role_allowed
  from public.tenant_role_grants
  where tenant_role_id = v_tenant_role_id
    and module_key = p_module_key
    and action = p_action;

  return coalesce(v_role_allowed, false);
end;
$function$;

GRANT ALL ON FUNCTION public.membership_has_module_action_for_email(text, bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.membership_has_module_action_for_email(text, bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.membership_has_module_action_for_email(text, bigint, text, text) TO service_role;