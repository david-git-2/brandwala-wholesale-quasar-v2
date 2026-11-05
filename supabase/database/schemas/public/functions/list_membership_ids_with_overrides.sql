CREATE FUNCTION public.list_membership_ids_with_overrides (
  p_tenant_id bigint
)
  RETURNS TABLE (
    membership_id bigint
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.is_superadmin() and not public.user_is_tenant_admin(p_tenant_id) then
    raise exception 'Unauthorized';
  end if;

  return query
  select distinct mg.membership_id
  from public.membership_grants mg
  join public.memberships m on m.id = mg.membership_id
  where m.tenant_id = p_tenant_id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_membership_ids_with_overrides(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_membership_ids_with_overrides(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_membership_ids_with_overrides(bigint) TO service_role;