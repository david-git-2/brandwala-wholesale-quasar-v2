-- =========================================================
-- Membership policy hardening
-- - Make tenant select policy explicitly superadmin-aware
-- - Add trigger-level guardrails for membership updates
-- =========================================================

drop policy if exists "members_can_view_tenants" on public.tenants;
create policy "members_can_view_tenants"
on public.tenants
for select
to authenticated
using (
  public.is_superadmin()
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.tenants.id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

create or replace function public.guard_membership_update()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if public.is_superadmin() then
    return new;
  end if;

  if old.tenant_id is distinct from new.tenant_id then
    raise exception 'Only superadmin can move memberships across tenants';
  end if;

  if not public.is_tenant_admin(old.tenant_id) then
    raise exception 'Only tenant admins can update tenant memberships';
  end if;

  if old.role not in ('staff', 'viewer') then
    raise exception 'Tenant admins can only update staff or viewer memberships';
  end if;

  if new.role not in ('staff', 'viewer') then
    raise exception 'Tenant admins cannot promote membership role beyond staff/viewer';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_memberships_guard_update on public.memberships;
create trigger trg_memberships_guard_update
before update on public.memberships
for each row
execute function public.guard_membership_update();
