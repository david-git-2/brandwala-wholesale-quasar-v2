-- Payments desk uses cashbook list/detail RPCs; staff with payments.view must see profile picker rows.

CREATE OR REPLACE FUNCTION public.cashbook_staff_can_view(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'cashbook', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'cashbook', 'view')
    OR public.membership_has_module_action(public.resolve_parent_tenant_id(p_tenant_id), 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id));
$$;
