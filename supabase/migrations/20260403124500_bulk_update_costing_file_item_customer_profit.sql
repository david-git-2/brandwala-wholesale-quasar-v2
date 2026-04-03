create or replace function public.update_costing_file_items_customer_profit(
  p_costing_file_id bigint,
  p_customer_profit_rate numeric
)
returns table(
  id bigint,
  customer_profit_rate numeric,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
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
$$;

grant execute on function public.update_costing_file_items_customer_profit(bigint, numeric)
to authenticated;
