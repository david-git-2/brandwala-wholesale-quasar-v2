CREATE FUNCTION public.list_cgm_ids_with_overrides (
  p_customer_group_id bigint
)
  RETURNS TABLE (
    customer_group_member_id bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.customer_groups
  where id = p_customer_group_id;

  if v_tenant_id is null then
    raise exception 'Customer group not found';
  end if;

  if not public.is_superadmin() and not public.user_is_tenant_admin(v_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  return query
  select distinct cgmg.customer_group_member_id
  from public.customer_group_member_grants cgmg
  join public.customer_group_members cgm on cgm.id = cgmg.customer_group_member_id
  where cgm.customer_group_id = p_customer_group_id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_cgm_ids_with_overrides(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_cgm_ids_with_overrides(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_cgm_ids_with_overrides(bigint) TO service_role;