-- Migration to add accessibility to notes and update get_effective_item_role
begin;

-- 1. Add accessibility column to items table
alter table public.items
  add column if not exists accessibility text not null default 'public';

-- 2. Add constraint restricting private/restricted accessibility to notes
alter table public.items
  drop constraint if exists items_accessibility_check,
  add constraint items_accessibility_check check (
    (type = 'note' and accessibility in ('public', 'private', 'restricted'))
    or (type <> 'note' and accessibility = 'public')
  );

-- 3. Refactor get_effective_item_role
create or replace function public.get_effective_item_role(
  p_item_id bigint,
  p_user_email text
)
returns text
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_role text;
  v_parent_id bigint;
  v_tenant_id bigint;
  v_created_by_email text;
  v_user_role_in_tenant text;
  v_is_superadmin boolean;
  v_email text;
  v_accessibility text;
  v_type text;
begin
  v_email := lower(trim(p_user_email));

  -- 1. Check if user is superadmin
  select exists (
    select 1 from public.memberships m
    where lower(trim(m.email)) = v_email
      and m.role = 'superadmin'
      and m.is_active = true
  ) into v_is_superadmin;

  if v_is_superadmin then
    return 'owner';
  end if;

  -- Get item info
  select parent_id, tenant_id, created_by_email, accessibility, type
  into v_parent_id, v_tenant_id, v_created_by_email, v_accessibility, v_type
  from public.items
  where id = p_item_id;

  if not found then
    return null;
  end if;

  -- PRIVATE accessibility checks (ONLY creator/superadmin)
  if v_accessibility = 'private' then
    if lower(trim(v_created_by_email)) = v_email then
      return 'owner';
    else
      return null;
    end if;
  end if;

  -- RESTRICTED accessibility checks (ONLY creator/superadmin, explicit permissions, or assignees)
  if v_accessibility = 'restricted' then
    -- Check creator
    if lower(trim(v_created_by_email)) = v_email then
      return 'owner';
    end if;

    -- Check explicit permissions on this specific item
    select role into v_role
    from public.item_permissions
    where item_id = p_item_id and lower(trim(user_email)) = v_email;

    if v_role is not null then
      return v_role;
    end if;

    -- Check if user is an assignee
    if exists (
      select 1 from public.item_assignees
      where item_id = p_item_id and lower(trim(user_email)) = v_email
    ) then
      return 'viewer';
    end if;

    -- Restricted notes do not inherit parent visibility nor do they fallback to tenant memberships
    return null;
  end if;

  -- STANDARD PUBLIC accessibility checks
  -- Check creator
  if lower(trim(v_created_by_email)) = v_email then
    return 'owner';
  end if;

  -- Check explicit permissions on this item
  select role into v_role
  from public.item_permissions
  where item_id = p_item_id and lower(trim(user_email)) = v_email;

  if v_role is not null then
    return v_role;
  end if;

  -- Check recursive parent permissions
  if v_parent_id is not null then
    v_role := public.get_effective_item_role(v_parent_id, v_email);
    if v_role is not null then
      return v_role;
    end if;
  end if;

  -- Fallback to tenant memberships
  if v_tenant_id is not null then
    select m.role::text into v_user_role_in_tenant
    from public.memberships m
    where lower(trim(m.email)) = v_email
      and m.tenant_id = v_tenant_id
      and m.is_active = true;

    if v_user_role_in_tenant = 'admin' then
      return 'owner';
    elsif v_user_role_in_tenant = 'staff' then
      return 'editor';
    elsif v_user_role_in_tenant = 'viewer' then
      return 'viewer';
    end if;
  end if;

  return null;
end;
$$;

commit;

-- Reload schema cache
do $$
begin
  perform pg_notify('pgrst', 'reload schema');
exception
  when others then
    null;
end;
$$;
