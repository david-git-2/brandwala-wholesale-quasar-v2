CREATE FUNCTION public.current_costing_item_actor_role (
  p_costing_file_id bigint
)
  RETURNS text
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select case
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_admin_manage_costing_file(cf.tenant_id)
    ) then 'admin'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_staff_access_costing_file(cf.tenant_id)
    ) then 'staff'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_customer_access_costing_file(cf.customer_group_id)
    ) then 'customer'
    else null
  end
$function$;

GRANT ALL ON FUNCTION public.current_costing_item_actor_role(bigint) TO anon;

GRANT ALL ON FUNCTION public.current_costing_item_actor_role(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.current_costing_item_actor_role(bigint) TO service_role;