CREATE FUNCTION public.update_costing_file_status (
  p_id     bigint,
  p_status public.costing_file_status
)
  RETURNS TABLE (
    id         bigint,
    status     public.costing_file_status,
    updated_at timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with updated as (
    update public.costing_files cf
    set status = p_status
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          public.can_staff_access_costing_file(cf.tenant_id)
          and cf.status = 'customer_submitted'
          and p_status = 'in_review'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            (cf.status = 'draft' and p_status = 'customer_submitted')
            or (cf.status = 'offered' and p_status = 'accepted')
          )
        )
      )
    returning
      cf.id,
      cf.status,
      cf.updated_at
  )
  select *
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_costing_file_status(bigint, public.costing_file_status) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file_status(bigint, public.costing_file_status) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file_status(bigint, public.costing_file_status) TO service_role;