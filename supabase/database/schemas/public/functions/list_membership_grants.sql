CREATE FUNCTION public.list_membership_grants (
  p_membership_id bigint
)
  RETURNS TABLE (
    id               bigint,
    membership_id    bigint,
    module_key       text,
    action           text,
    effect           text,
    created_by_email text,
    created_at       timestamp with time zone,
    updated_at       timestamp with time zone
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  select m.tenant_id into v_tenant_id
  from public.memberships m
  where m.id = p_membership_id;

  if v_tenant_id is null then
    raise exception 'Membership not found';
  end if;

  if not public.is_superadmin() and not exists (
    select 1 from public.memberships m
    where m.tenant_id = v_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Access denied';
  end if;

  return query
  select mg.id, mg.membership_id, mg.module_key, mg.action, mg.effect, mg.created_by_email, mg.created_at, mg.updated_at
  from public.membership_grants mg
  where mg.membership_id = p_membership_id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_membership_grants(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_membership_grants(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_membership_grants(bigint) TO service_role;