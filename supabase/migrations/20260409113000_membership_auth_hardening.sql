-- =========================================================
-- Membership auth hardening
-- - Keep membership management scoped to internal roles
-- - Normalize membership emails on write
-- - Ensure core memberships CRUD policies exist
-- =========================================================

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
  select
    public.is_superadmin()
    or (
      public.is_tenant_admin(p_target_tenant_id)
      and p_target_role in ('staff', 'viewer')
    )
$$;

grant execute on function public.can_manage_membership(bigint, public.app_role)
to authenticated;

create or replace function public.normalize_membership_email()
returns trigger
language plpgsql
as $$
begin
  new.email := lower(trim(coalesce(new.email, '')));

  if new.email = '' then
    raise exception 'membership email cannot be empty';
  end if;

  return new;
end;
$$;

update public.memberships
set email = lower(trim(email))
where email <> lower(trim(email));

drop trigger if exists trg_memberships_normalize_email on public.memberships;
create trigger trg_memberships_normalize_email
before insert or update of email on public.memberships
for each row
execute function public.normalize_membership_email();

create index if not exists memberships_email_idx
on public.memberships (lower(trim(email)));

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'memberships'
      and policyname = 'memberships_insert'
  ) then
    execute $policy$
      create policy "memberships_insert"
      on public.memberships
      for insert
      to authenticated
      with check (
        public.is_superadmin()
        or public.can_manage_membership(tenant_id, role)
      )
    $policy$;
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'memberships'
      and policyname = 'memberships_update'
  ) then
    execute $policy$
      create policy "memberships_update"
      on public.memberships
      for update
      to authenticated
      using (
        public.is_superadmin()
        or public.can_manage_membership(tenant_id, role)
      )
      with check (
        public.is_superadmin()
        or public.can_manage_membership(tenant_id, role)
      )
    $policy$;
  end if;

  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'memberships'
      and policyname = 'memberships_delete'
  ) then
    execute $policy$
      create policy "memberships_delete"
      on public.memberships
      for delete
      to authenticated
      using (
        public.is_superadmin()
        or public.can_manage_membership(tenant_id, role)
      )
    $policy$;
  end if;
end
$$;
