-- Single round-trip for app admin dashboard metrics + child tenant refs.

CREATE OR REPLACE FUNCTION public.get_app_dashboard_bundle(
  p_tenant_id bigint,
  p_parent_tenant_ids bigint[] DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_proc jsonb := NULL;
  v_shop jsonb := NULL;
  v_tasks jsonb := NULL;
  v_investor jsonb := NULL;
  v_children jsonb := '[]'::jsonb;
  v_parent_ids bigint[];
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'p_tenant_id is required';
  END IF;

  IF NOT (
    public.is_superadmin()
    OR public.has_active_tenant_membership(p_tenant_id)
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'global_stock', 'view') THEN
    v_proc := public.get_procurement_dashboard_metrics(p_tenant_id);
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'shop_order', 'view') THEN
    v_shop := public.get_shop_order_dashboard_metrics(p_tenant_id);
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'tasks', 'view') THEN
    v_tasks := public.get_tasks_dashboard_metrics(p_tenant_id);
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view') THEN
    v_investor := public.get_staff_investor_capital_metrics(p_tenant_id);
  END IF;

  v_parent_ids := coalesce(p_parent_tenant_ids, ARRAY[]::bigint[]);
  IF cardinality(v_parent_ids) > 0 THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object('id', c.id, 'parent_id', c.parent_id, 'name', c.name)
        ORDER BY c.parent_id, c.id
      ),
      '[]'::jsonb
    )
    INTO v_children
    FROM public.list_child_tenant_refs(v_parent_ids) AS c;
  END IF;

  RETURN jsonb_build_object(
    'refreshed_at', to_jsonb(now() AT TIME ZONE 'utc'),
    'procurement', v_proc,
    'shop_order', v_shop,
    'tasks', v_tasks,
    'investor_capital', v_investor,
    'child_tenant_refs', v_children
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_app_dashboard_bundle(bigint, bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_app_dashboard_bundle(bigint, bigint[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_app_dashboard_bundle(bigint, bigint[]) TO service_role;
