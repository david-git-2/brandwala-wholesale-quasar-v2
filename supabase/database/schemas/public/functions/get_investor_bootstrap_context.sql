CREATE FUNCTION public.get_investor_bootstrap_context (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_membership public.memberships;
  v_tenant public.tenants;
  v_perm_version bigint;
begin
  select * into v_tenant from public.tenants where id = p_tenant_id;
  if v_tenant.id is null then raise exception 'tenant not found'; end if;

  select m.* into v_membership
  from public.memberships m
  inner join public.investors i
    on i.id = m.investor_id
    and i.tenant_id = p_tenant_id
    and i.is_active = true
  where m.tenant_id = p_tenant_id
    and public.membership_email_matches_current_user(m.email)
    and m.is_active = true
  limit 1;

  if v_membership.id is null or v_membership.investor_id is null then
    return jsonb_build_object('authenticated', false, 'tenant', row_to_json(v_tenant));
  end if;

  select version into v_perm_version
  from public.tenant_permission_versions
  where tenant_id = p_tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(p_tenant_id);
    v_perm_version := 1;
  end if;

  return jsonb_build_object(
    'authenticated', true,
    'tenant', row_to_json(v_tenant),
    'investor_account', row_to_json(v_membership),
    'portfolio', public.get_investor_portfolio_summary(v_membership.investor_id),
    'module_keys', (
      select coalesce(jsonb_agg(tm.module_key), '[]'::jsonb)
      from public.tenant_modules tm
      where tm.tenant_id = p_tenant_id
        and tm.is_active = true
        and tm.module_key = 'investor_portal'
    ),
    'permission_version', v_perm_version
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_investor_bootstrap_context(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_investor_bootstrap_context(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_investor_bootstrap_context(bigint) TO service_role;