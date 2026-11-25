-- Batch desk bill detail bundles (same payload as get_bill_detail_bundle per id).

CREATE OR REPLACE FUNCTION public.get_bill_detail_bundles(
  p_tenant_id bigint,
  p_bill_ids bigint[]
)
RETURNS jsonb
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent_id bigint;
  v_id bigint;
  v_bundles jsonb := '[]'::jsonb;
  v_missing bigint[] := '{}';
  v_seen bigint[] := '{}';
  v_count int := 0;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant is required.';
  END IF;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.user_can_manage_books_tenant(v_parent_id)
    OR public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'Access denied';
  END IF;

  IF p_bill_ids IS NULL OR cardinality(p_bill_ids) = 0 THEN
    RETURN jsonb_build_object('success', true, 'bundles', '[]'::jsonb, 'missing_ids', '[]'::jsonb);
  END IF;

  FOREACH v_id IN ARRAY p_bill_ids
  LOOP
  IF v_id IS NULL OR v_id <= 0 THEN
    CONTINUE;
  END IF;
  IF v_id = ANY(v_seen) THEN
    CONTINUE;
  END IF;
  v_seen := array_append(v_seen, v_id);
  v_count := v_count + 1;
  IF v_count > 50 THEN
    RAISE EXCEPTION 'At most 50 bill ids per request';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM money_kernel.bills b
    WHERE b.id = v_id AND b.tenant_id = v_parent_id
  ) THEN
    v_bundles := v_bundles || jsonb_build_array(
      public._get_bill_detail_bundle_from_kernel(p_tenant_id, v_id)
    );
  ELSE
    v_missing := array_append(v_missing, v_id);
  END IF;
  END LOOP;

  RETURN jsonb_build_object(
    'success', true,
    'bundles', v_bundles,
    'missing_ids', to_jsonb(v_missing)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_bill_detail_bundles(bigint, bigint[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_bill_detail_bundles(bigint, bigint[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_bill_detail_bundles(bigint, bigint[]) TO service_role;