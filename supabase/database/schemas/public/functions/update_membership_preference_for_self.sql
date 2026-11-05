CREATE FUNCTION public.update_membership_preference_for_self (
  p_membership_id bigint,
  p_preference    jsonb
)
  RETURNS TABLE (
    id         bigint,
    email      text,
    role       public.app_role,
    is_active  boolean,
    tenant_id  bigint,
    preference jsonb,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not exists (
    select 1
    from public.memberships m
    where m.id = p_membership_id
      and lower(trim(m.email)) = lower(trim(public.current_user_email()))
      and m.is_active = true
  ) then
    raise exception 'Unauthorized to update this membership preference';
  end if;

  if jsonb_typeof(p_preference) is distinct from 'object' then
    raise exception 'Membership preference must be a JSON object';
  end if;

  return query
  update public.memberships as m
  set preference = p_preference
  where m.id = p_membership_id
  returning
    m.id,
    m.email,
    m.role,
    m.is_active,
    m.tenant_id,
    m.preference,
    m.created_at,
    m.updated_at;
end;
$function$;

GRANT ALL ON FUNCTION public.update_membership_preference_for_self(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.update_membership_preference_for_self(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.update_membership_preference_for_self(bigint, jsonb) TO service_role;