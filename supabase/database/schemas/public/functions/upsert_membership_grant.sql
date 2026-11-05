CREATE FUNCTION public.upsert_membership_grant (
  p_membership_id bigint,
  p_module_key    text,
  p_action        text,
  p_effect        text
)
  RETURNS public.membership_grants
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_member public.memberships;
  v_row public.membership_grants;
begin
  select * into v_member from public.memberships where id = p_membership_id;
  if v_member.id is null then
    raise exception 'Membership not found';
  end if;

  if not public.user_is_tenant_admin(v_member.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_member.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.membership_grants (
    membership_id,
    module_key,
    action,
    effect,
    created_by_email
  )
  values (
    p_membership_id,
    p_module_key,
    p_action,
    p_effect,
    public.current_user_email()
  )
  on conflict (membership_id, module_key, action) do update set
    effect = excluded.effect,
    created_by_email = excluded.created_by_email,
    updated_at = now()
  returning * into v_row;

  perform public.bump_tenant_permission_version(v_member.tenant_id);
  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_membership_grant(bigint, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.upsert_membership_grant(bigint, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_membership_grant(bigint, text, text, text) TO service_role;