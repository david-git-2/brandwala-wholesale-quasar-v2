CREATE FUNCTION public.can_view_costing_file_items (
  p_costing_file_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status::text in ('po_placed', 'completed')
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or cf.status = 'draft'
            or public.is_customer_group_admin_or_negotiator(cf.customer_group_id)
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$function$;

GRANT ALL ON FUNCTION public.can_view_costing_file_items(bigint) TO anon;

GRANT ALL ON FUNCTION public.can_view_costing_file_items(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.can_view_costing_file_items(bigint) TO service_role;