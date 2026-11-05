CREATE FUNCTION public.delete_membership_grant (
  p_membership_id bigint,
  p_module_key    text,
  p_action        text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select m.tenant_id into v_tenant_id
  from public.memberships m
  where m.id = p_membership_id;

  if v_tenant_id is null then
    raise exception 'Membership not found';
  end if;

  if not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  delete from public.membership_grants
  where membership_id = p_membership_id
    and module_key = p_module_key
    and action = p_action;

  perform public.bump_tenant_permission_version(v_tenant_id);
end;
$function$;

GRANT ALL ON FUNCTION public.delete_membership_grant(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.delete_membership_grant(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.delete_membership_grant(bigint, text, text) TO service_role;