-- Restore the costing file list RPC signature expected by the frontend.
-- This keeps the paged admin query available without changing the earlier migration.

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
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
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
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  )
  order by cf.id desc
  limit p_limit
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_costing_files_for_actor(bigint, bigint, integer, integer)
to authenticated;

create or replace function public.count_costing_files_for_actor(
  p_tenant_id bigint default null,
  p_customer_group_id bigint default null
)
returns bigint
language sql
security definer
set search_path = public
stable
as $$
  select count(*)
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  );
$$;

grant execute on function public.count_costing_files_for_actor(bigint, bigint)
to authenticated;
