CREATE FUNCTION public.update_costing_file_items_customer_profit (
  p_costing_file_id      bigint,
  p_customer_profit_rate numeric
)
  RETURNS TABLE (
    id                   bigint,
    customer_profit_rate numeric,
    updated_at           timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with updated as (
    update public.costing_file_items cfi
    set customer_profit_rate = p_customer_profit_rate
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.costing_file_id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
    returning
      cfi.id,
      cfi.customer_profit_rate,
      cfi.updated_at
  )
  select *
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_costing_file_items_customer_profit(bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public.update_costing_file_items_customer_profit(bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.update_costing_file_items_customer_profit(bigint, numeric) TO service_role;