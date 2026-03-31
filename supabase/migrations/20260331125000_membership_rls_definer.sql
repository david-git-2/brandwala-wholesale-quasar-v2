-- =========================================================
-- Membership RLS helper fix
-- Let helper functions read memberships without RLS recursion
-- =========================================================

create or replace function public.is_superadmin()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.role = 'superadmin'
      and m.is_active = true
      and m.tenant_id is null
  )
$$;

create or replace function public.is_tenant_admin(p_tenant_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = p_tenant_id
      and m.role = 'admin'
      and m.is_active = true
  )
$$;

create or replace function public.can_manage_membership(
  p_target_tenant_id bigint,
  p_target_role app_role
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer', 'customer')
    )
$$;
