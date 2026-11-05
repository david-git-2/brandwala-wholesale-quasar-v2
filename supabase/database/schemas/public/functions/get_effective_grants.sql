CREATE FUNCTION public.get_effective_grants (
  p_tenant_id bigint
)
  RETURNS TABLE (
    module_key text,
    action     text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_member_id bigint;
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_member_role public.app_role;
begin
  select m.id, m.tenant_role_id, tr.is_admin, m.role
  into v_member_id, v_tenant_role_id, v_role_is_admin, v_member_role
  from public.memberships m
  left join public.tenant_roles tr on tr.id = m.tenant_role_id
  where m.tenant_id = p_tenant_id
    and public.membership_email_matches_current_user(m.email)
    and m.is_active = true;

  if public.is_superadmin()
     or public.is_network_owner(p_tenant_id)
     or v_member_role = 'manager'::public.app_role
     or coalesce(v_role_is_admin, false) = true then
    return query
    select ma.module_key, ma.action
    from public.module_actions ma
    join public.tenant_modules tm on tm.module_key = ma.module_key
    where tm.tenant_id = p_tenant_id
      and tm.is_active = true
      and ma.is_active = true
      and (ma.scope <> 'platform' or public.is_superadmin())
      and not (
        exists (
          select 1
          from public.tenants
          where id = p_tenant_id
            and parent_id is not null
        ) and ma.module_key in (
          'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
          'shipment_reports', 'parent_dashboard', 'investor_reports',
          'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
        )
      );
    return;
  end if;

  return query
  with role_allowed as (
    select rg.module_key, rg.action
    from public.tenant_role_grants rg
    where rg.tenant_role_id = v_tenant_role_id
      and rg.allowed = true
  ),
  with_overrides as (
    select ra.module_key, ra.action from role_allowed ra
    union
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'allow'
  ),
  effective as (
    select wo.module_key, wo.action from with_overrides wo
    except
    select mg.module_key, mg.action
    from public.membership_grants mg
    where mg.membership_id = v_member_id
      and mg.effect = 'deny'
  )
  select e.module_key, e.action
  from effective e
  join public.module_actions ma on ma.module_key = e.module_key and ma.action = e.action
  join public.tenant_modules tm on tm.module_key = e.module_key
  where tm.tenant_id = p_tenant_id
    and tm.is_active = true
    and ma.is_active = true
    and (ma.scope <> 'platform' or public.is_superadmin())
    and not (
      exists (
        select 1
        from public.tenants
        where id = p_tenant_id
          and parent_id is not null
      ) and ma.module_key in (
        'global_shipment', 'global_stock', 'global_stock_type', 'procurement_stock',
        'shipment_reports', 'parent_dashboard', 'investor_reports',
        'investor_profiles', 'investor_capital_ledger', 'investor_shipment_share', 'investor_portal'
      )
    );
end;
$function$;

GRANT ALL ON FUNCTION public.get_effective_grants(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_effective_grants(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_effective_grants(bigint) TO service_role;