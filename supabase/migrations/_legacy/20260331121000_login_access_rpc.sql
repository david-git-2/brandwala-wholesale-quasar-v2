-- =========================================================
-- Login access RPC
-- For Supabase / Postgres
-- =========================================================

create or replace function public.check_login_membership(
  p_email text,
  p_scope text
)
returns table(
  has_match boolean,
  matched_role app_role
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
  into matched_role
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
