CREATE FUNCTION public.delete_customer_group_member_grant (
  p_cgm_id     bigint,
  p_module_key text,
  p_action     text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select cg.tenant_id into v_tenant_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where cgm.id = p_cgm_id;

  if v_tenant_id is null then
    raise exception 'Customer group member not found';
  end if;

  if not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  delete from public.customer_group_member_grants
  where customer_group_member_id = p_cgm_id
    and module_key = p_module_key
    and action = p_action;

  perform public.bump_tenant_permission_version(v_tenant_id);
end;
$function$;

GRANT ALL ON FUNCTION public.delete_customer_group_member_grant(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.delete_customer_group_member_grant(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.delete_customer_group_member_grant(bigint, text, text) TO service_role;