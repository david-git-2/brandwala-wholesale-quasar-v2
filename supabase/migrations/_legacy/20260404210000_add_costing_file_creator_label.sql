-- Add a normalized creator label for costing files:
-- - admin
-- - staff
-- - customer group name (for customer-created files)

create or replace function public.resolve_costing_file_creator_label(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_created_by_email text
)
returns text
language sql
security definer
set search_path = public
stable
as $$
  select case
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and (
          (m.tenant_id = p_tenant_id and m.role = 'admin')
          or (m.tenant_id is null and m.role = 'superadmin')
        )
    ) then 'admin'
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and m.tenant_id = p_tenant_id
        and m.role = 'staff'
    ) then 'staff'
    else coalesce(
      (
        select cg.name
        from public.customer_group_members cgm
        inner join public.customer_groups cg
          on cg.id = cgm.customer_group_id
        where lower(trim(cgm.email)) = lower(trim(coalesce(p_created_by_email, '')))
          and cgm.is_active = true
          and cg.is_active = true
          and cgm.customer_group_id = p_customer_group_id
        limit 1
      ),
      'Unknown'
    )
  end;
$$;

grant execute on function public.resolve_costing_file_creator_label(bigint, bigint, text)
to authenticated;

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
  created_by_label text,
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
      public.resolve_costing_file_creator_label(
        cf.tenant_id,
        cf.customer_group_id,
        cf.created_by_email
      ) as created_by_label,
      cf.created_at,
      cf.updated_at
    from public.costing_files cf
    where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
      and public.can_view_costing_file(cf.id)
  )
  select
    f.id,
    f.name,
    f.market,
    f.status,
    f.customer_group_id,
    f.tenant_id,
    f.created_by_email,
    f.created_by_label,
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
