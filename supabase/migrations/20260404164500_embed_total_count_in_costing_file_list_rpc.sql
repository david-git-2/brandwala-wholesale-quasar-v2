-- Return total row count from the list RPC so admin pagination does not need
-- a separate count RPC call.

drop function if exists public.list_costing_files_for_actor(bigint, bigint, integer, integer);

create or replace function public.list_costing_files_for_actor(
  p_tenant_id bigint default null,
  p_customer_group_id bigint default null,
  p_limit integer default null,
  p_offset integer default 0
)
returns table(
  id bigint,
  name text,
  market text,
  status public.costing_file_status,
  customer_group_id bigint,
  tenant_id bigint,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz,
  total_count bigint
)
language sql
security definer
set search_path = public
stable
as $$
  with filtered as (
    select
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.created_at,
      cf.updated_at
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
    )
  )
  select
    f.id,
    f.name,
    f.market,
    f.status,
    f.customer_group_id,
    f.tenant_id,
    f.created_by_email,
    f.created_at,
    f.updated_at,
    count(*) over()::bigint as total_count
  from filtered f
  order by f.id desc
  limit p_limit
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_costing_files_for_actor(bigint, bigint, integer, integer)
to authenticated;
