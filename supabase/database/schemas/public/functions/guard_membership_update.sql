CREATE FUNCTION public.guard_membership_update()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if public.is_superadmin() then
    return new;
  end if;

  if coalesce(current_setting('app.sync_investor_profile_membership', true), '') = '1' then
    return new;
  end if;

  if old.tenant_id is distinct from new.tenant_id then
    raise exception 'Only superadmin can move memberships across tenants';
  end if;

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

  if exists (
    select 1
    from public.memberships m
    where m.tenant_id = public.resolve_parent_tenant_id(old.tenant_id)
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'owner'::public.app_role
      and m.is_active = true
  ) then
    if old.role = 'owner'::public.app_role and new.role is distinct from old.role then
      raise exception 'Use transfer_network_owner to change the network owner';
    end if;
    if new.role = 'owner'::public.app_role then
      raise exception 'Only transfer_network_owner can assign owner';
    end if;
    return new;
  end if;

  if exists (
    select 1
    from public.memberships m
    where m.tenant_id = old.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role = 'manager'::public.app_role
      and m.is_active = true
  ) then
    if old.role in ('owner'::public.app_role, 'manager'::public.app_role) then
      raise exception 'Managers cannot modify owner or manager memberships';
    end if;
    if new.role in ('owner'::public.app_role, 'manager'::public.app_role) then
      raise exception 'Managers cannot promote memberships to owner or manager';
    end if;
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
$function$;

GRANT ALL ON FUNCTION public.guard_membership_update() TO anon;

GRANT ALL ON FUNCTION public.guard_membership_update() TO authenticated;

GRANT ALL ON FUNCTION public.guard_membership_update() TO service_role;