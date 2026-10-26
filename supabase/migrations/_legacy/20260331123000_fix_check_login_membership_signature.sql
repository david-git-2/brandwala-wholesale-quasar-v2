-- =========================================================
-- Fix login access RPC signature
-- Ensure PostgREST sees the email + scope version only
-- =========================================================

drop function if exists public.check_login_membership(text);
drop function if exists public.check_login_membership(text, text);

create or replace function public.check_login_membership(
  p_email text,
  p_scope text
)
returns table(
  has_match boolean,
  matched_role app_role,
  member_id bigint,
  member_email text,
  member_tenant_id bigint,
  member_is_active boolean,
  member_created_at timestamptz,
  member_updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_roles app_role[];
  v_email text;
begin
  case lower(coalesce(p_scope, ''))
    when 'platform' then
      v_roles := array['superadmin'::app_role];
    when 'app' then
      v_roles := array['admin'::app_role, 'staff'::app_role];
    when 'shop' then
      v_roles := array['customer'::app_role, 'viewer'::app_role];
    else
      v_roles := array[]::app_role[];
  end case;

  v_email := lower(trim(coalesce(p_email, auth.jwt() ->> 'email', '')));

  select m.role
       , m.id
       , m.email
       , m.tenant_id
       , m.is_active
       , m.created_at
       , m.updated_at
  into matched_role
      , member_id
      , member_email
      , member_tenant_id
      , member_is_active
      , member_created_at
      , member_updated_at
  from public.memberships m
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role = any(v_roles)
  order by case m.role
    when 'superadmin' then 1
    when 'admin' then 2
    when 'staff' then 3
    when 'customer' then 4
    when 'viewer' then 5
    else 99
  end
  limit 1;

  has_match := matched_role is not null;
  return next;
end;
$$;
