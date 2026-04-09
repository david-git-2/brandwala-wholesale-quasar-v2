-- =========================================================
-- Membership production hardening
-- - Separate "who can update existing row" from
--   "what target role/tenant may be assigned"
-- - Recreate memberships policies using explicit helpers
-- - Enforce integrity/index guarantees in DB
-- =========================================================

create or replace function public.can_update_membership_row(
  p_existing_tenant_id bigint,
  p_existing_role public.app_role
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
      public.is_tenant_admin(p_existing_tenant_id)
      and p_existing_role in ('staff', 'viewer')
    )
$$;

create or replace function public.can_assign_membership_role(
  p_target_tenant_id bigint,
  p_target_role public.app_role
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
      and p_target_role in ('staff', 'viewer')
    )
$$;

create or replace function public.can_manage_membership(
  p_target_tenant_id bigint,
  p_target_role public.app_role
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.can_assign_membership_role(p_target_tenant_id, p_target_role)
$$;

grant execute on function public.can_update_membership_row(bigint, public.app_role)
to authenticated;
grant execute on function public.can_assign_membership_role(bigint, public.app_role)
to authenticated;
grant execute on function public.can_manage_membership(bigint, public.app_role)
to authenticated;

drop policy if exists "memberships_insert" on public.memberships;
create policy "memberships_insert"
on public.memberships
for insert
to authenticated
with check (
  public.can_assign_membership_role(tenant_id, role)
);

drop policy if exists "memberships_update" on public.memberships;
create policy "memberships_update"
on public.memberships
for update
to authenticated
using (
  public.can_update_membership_row(tenant_id, role)
)
with check (
  public.can_assign_membership_role(tenant_id, role)
);

drop policy if exists "memberships_delete" on public.memberships;
create policy "memberships_delete"
on public.memberships
for delete
to authenticated
using (
  public.can_update_membership_row(tenant_id, role)
);

create index if not exists memberships_email_idx
on public.memberships (lower(trim(email)));

create unique index if not exists memberships_email_tenant_unique
on public.memberships (lower(trim(email)), coalesce(tenant_id, -1));

create unique index if not exists memberships_superadmin_email_unique
on public.memberships (lower(trim(email)))
where role = 'superadmin' and tenant_id is null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint c
    join pg_class t on t.oid = c.conrelid
    join pg_namespace n on n.oid = t.relnamespace
    where n.nspname = 'public'
      and t.relname = 'memberships'
      and c.conname = 'memberships_role_tenant_check'
  ) then
    alter table public.memberships
      add constraint memberships_role_tenant_check check (
        (role = 'superadmin' and tenant_id is null)
        or
        (role <> 'superadmin' and tenant_id is not null)
      );
  end if;
end
$$;
