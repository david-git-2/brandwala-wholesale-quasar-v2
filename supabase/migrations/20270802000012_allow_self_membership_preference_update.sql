-- Allow members to update their own preference without being tenant admin.
-- update_membership_preference_for_self already authorizes by email, but
-- guard_membership_update blocked non-admin UPDATEs on memberships.

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

  -- Preference-only self-update (e.g. update_membership_preference_for_self)
  if lower(trim(old.email)) = lower(trim(public.current_user_email()))
    and old.email is not distinct from new.email
    and old.role is not distinct from new.role
    and old.is_active is not distinct from new.is_active
    and old.investor_id is not distinct from new.investor_id
    and old.tenant_role_id is not distinct from new.tenant_role_id
    and old.accent_color is not distinct from new.accent_color
    and old.preference is distinct from new.preference
  then
    return new;
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
