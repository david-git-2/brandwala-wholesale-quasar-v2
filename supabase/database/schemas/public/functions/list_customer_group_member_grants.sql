CREATE FUNCTION public.list_customer_group_member_grants (
  p_cgm_id bigint
)
  RETURNS TABLE (
    id                       bigint,
    customer_group_member_id bigint,
    module_key               text,
    action                   text,
    effect                   text
  )
  LANGUAGE plpgsql
  STABLE
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

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select cgmg.id, cgmg.customer_group_member_id, cgmg.module_key, cgmg.action, cgmg.effect
  from public.customer_group_member_grants cgmg
  where cgmg.customer_group_member_id = p_cgm_id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_customer_group_member_grants(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_customer_group_member_grants(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_customer_group_member_grants(bigint) TO service_role;