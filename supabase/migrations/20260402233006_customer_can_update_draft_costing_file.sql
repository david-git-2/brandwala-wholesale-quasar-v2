create or replace function public.update_costing_file(
  p_id bigint,
  p_name text default null,
  p_market text default null,
  p_customer_group_id bigint default null
)
returns table(
  id bigint,
  name text,
  cargo_rate_1kg numeric,
  cargo_rate_2kg numeric,
  conversion_rate numeric,
  admin_profit_rate numeric,
  status public.costing_file_status,
  market text,
  customer_group_id bigint,
  tenant_id bigint,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_files cf
    set
      name = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_name), cf.name)
        else cf.name
      end,
      market = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_market), cf.market)
        else cf.market
      end,
      customer_group_id = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
        then coalesce(p_customer_group_id, cf.customer_group_id)
        else cf.customer_group_id
      end
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
      )
    returning
      cf.id,
      cf.name,
      cf.cargo_rate_1kg,
      cf.cargo_rate_2kg,
      cf.conversion_rate,
      cf.admin_profit_rate,
      cf.status,
      cf.market,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.created_at,
      cf.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file(bigint, text, text, bigint)
to authenticated;
