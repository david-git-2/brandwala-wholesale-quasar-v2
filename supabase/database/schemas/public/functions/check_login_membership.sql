CREATE FUNCTION public.check_login_membership (
  p_email text,
  p_scope text
)
  RETURNS TABLE (
    has_match         boolean,
    matched_role      public.app_role,
    member_id         bigint,
    member_email      text,
    member_tenant_id  bigint,
    member_is_active  boolean,
    member_created_at timestamp with time zone,
    member_updated_at timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_roles public.app_role[];
  v_email text;
begin
  case lower(coalesce(p_scope, ''))
    when 'platform' then
      v_roles := array['superadmin'::public.app_role];
    when 'app' then
      v_roles := array[
        'owner'::public.app_role,
        'manager'::public.app_role,
        'staff'::public.app_role,
        'viewer'::public.app_role
      ];
    else
      v_roles := array[]::public.app_role[];
  end case;

  v_email := lower(trim(coalesce(p_email, auth.jwt() ->> 'email', '')));

  select
    m.role,
    m.id,
    m.email,
    m.tenant_id,
    m.is_active,
    m.created_at,
    m.updated_at
  into
    matched_role,
    member_id,
    member_email,
    member_tenant_id,
    member_is_active,
    member_created_at,
    member_updated_at
  from public.memberships m
  where lower(trim(m.email)) = v_email
    and m.is_active = true
    and m.role = any(v_roles)
  order by
    case m.role
      when 'owner' then 1
      when 'manager' then 2
      when 'staff' then 3
      when 'viewer' then 4
      else 99
    end,
    m.id asc
  limit 1;

  has_match := matched_role is not null;
  return next;
end;
$function$;

GRANT ALL ON FUNCTION public.check_login_membership(text, text) TO anon;

GRANT ALL ON FUNCTION public.check_login_membership(text, text) TO authenticated;

GRANT ALL ON FUNCTION public.check_login_membership(text, text) TO service_role;