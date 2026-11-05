CREATE FUNCTION public.upsert_customer_group_member_grant (
  p_cgm_id     bigint,
  p_module_key text,
  p_action     text,
  p_effect     text
)
  RETURNS public.customer_group_member_grants
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_member public.customer_group_members;
  v_group public.customer_groups;
  v_row public.customer_group_member_grants;
begin
  select * into v_member from public.customer_group_members where id = p_cgm_id;
  if v_member.id is null then
    raise exception 'Customer group member not found';
  end if;

  select * into v_group from public.customer_groups where id = v_member.customer_group_id;
  if v_group.id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.user_is_tenant_admin(v_group.tenant_id) then
    raise exception 'Unauthorized';
  end if;

  if p_effect not in ('allow', 'deny') then
    raise exception 'Invalid effect: %', p_effect;
  end if;

  if not (p_module_key = any(public.get_active_module_keys_for_tenant(v_group.tenant_id))) then
    raise exception 'Module is not active for this tenant';
  end if;

  if not exists (
    select 1 from public.module_actions
    where module_key = p_module_key and action = p_action and is_active = true
  ) then
    raise exception 'Invalid or inactive action: % for module %', p_action, p_module_key;
  end if;

  insert into public.customer_group_member_grants (
    customer_group_member_id,
    module_key,
    action,
    effect
  )
  values (
    p_cgm_id,
    p_module_key,
    p_action,
    p_effect
  )
  on conflict (customer_group_member_id, module_key, action) do update set
    effect = excluded.effect
  returning * into v_row;

  perform public.bump_tenant_permission_version(v_group.tenant_id);
  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_customer_group_member_grant(bigint, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.upsert_customer_group_member_grant(bigint, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_customer_group_member_grant(bigint, text, text, text) TO service_role;