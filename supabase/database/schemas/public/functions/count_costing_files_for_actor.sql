CREATE FUNCTION public.count_costing_files_for_actor (
  p_tenant_id         bigint DEFAULT NULL::bigint,
  p_customer_group_id bigint DEFAULT NULL::bigint
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select count(*)
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      p_customer_group_id is null
      or cf.customer_group_id = p_customer_group_id
    )
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and p_tenant_id is null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  );
$function$;

GRANT ALL ON FUNCTION public.count_costing_files_for_actor(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.count_costing_files_for_actor(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.count_costing_files_for_actor(bigint, bigint) TO service_role;