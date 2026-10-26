-- Visibility model:
-- 1) Admin: all admin/staff-created files in any state; customer-created files only in customer_submitted.
-- 2) Staff: only files in customer_submitted.
-- 3) Customer: own files in any state; offered files created by admin/staff.

create or replace function public.is_internal_costing_file_creator(
  p_tenant_id bigint,
  p_email text
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, '')))
      and m.is_active = true
      and (
        (m.tenant_id = p_tenant_id and m.role in ('admin', 'staff'))
        or (m.tenant_id is null and m.role = 'superadmin')
      )
  );
$$;

grant execute on function public.is_internal_costing_file_creator(bigint, text)
to authenticated;

create or replace function public.can_view_costing_file(
  p_costing_file_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        (
          public.can_admin_manage_costing_file(cf.tenant_id)
          and (
            public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            or cf.status = 'customer_submitted'
          )
        )
        or (
          public.can_staff_access_costing_file(cf.tenant_id)
          and cf.status = 'customer_submitted'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$$;

grant execute on function public.can_view_costing_file(bigint)
to authenticated;

drop policy if exists "costing_files_select" on public.costing_files;
create policy "costing_files_select"
on public.costing_files
for select
to authenticated
using (
  public.can_view_costing_file(id)
);

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
