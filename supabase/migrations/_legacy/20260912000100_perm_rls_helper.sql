begin;

-- =========================================================
-- Shared grant check for app-scope membership RLS / RPCs
-- =========================================================
create or replace function public.membership_has_module_action(
  p_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'admin'::public.app_role
        or public.has_module_action(p_tenant_id, p_module_key, p_action)
      )
  );
$$;

grant execute on function public.membership_has_module_action(bigint, text, text) to authenticated;

-- Parent-tenant operations (procurement, investor capital on parent tenants)
create or replace function public.parent_tenant_has_module_action(
  p_parent_tenant_id bigint,
  p_module_key text,
  p_action text
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.membership_has_module_action(p_parent_tenant_id, p_module_key, p_action);
$$;

grant execute on function public.parent_tenant_has_module_action(bigint, text, text) to authenticated;

-- Investor portal read access for parent-tenant staff
create or replace function public.investor_tenant_can_view(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.membership_has_module_action(p_tenant_id, 'investor_profiles', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_shipment_share', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_reports', 'view');
$$;

grant execute on function public.investor_tenant_can_view(bigint) to authenticated;

commit;
