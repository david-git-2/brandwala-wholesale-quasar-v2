CREATE FUNCTION public.update_costing_file_item_status (
  p_id     bigint,
  p_status public.costing_file_item_status
)
  RETURNS TABLE (
    id         bigint,
    status     public.costing_file_item_status,
    updated_at timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with updated as (
    update public.costing_file_items cfi
    set status = p_status
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          cf.status = 'offered'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
    returning
      cfi.id,
      cfi.status,
      cfi.updated_at
  )
  select *
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_costing_file_item_status(bigint, public.costing_file_item_status) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file_item_status(bigint, public.costing_file_item_status) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file_item_status(bigint, public.costing_file_item_status) TO service_role;