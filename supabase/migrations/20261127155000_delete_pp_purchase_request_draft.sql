CREATE OR REPLACE FUNCTION "public"."delete_pp_purchase_request_draft"(
    "p_tenant_id" bigint,
    "p_request_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_status text;
BEGIN
  SELECT a.request_status INTO v_status
  FROM public._pp_assert_customer_request_access(p_tenant_id, p_request_id) a
  LIMIT 1;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft requests can be deleted' USING ERRCODE = '22023';
  END IF;

  UPDATE public.pp_order_lines l
  SET deleted_at = now(),
      updated_at = now()
  WHERE l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL;

  UPDATE public.pp_purchase_requests r
  SET deleted_at = now(),
      updated_at = now()
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL
    AND r.status = 'draft';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase request not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('id', p_request_id, 'deleted', true);
END;
$$;

ALTER FUNCTION "public"."delete_pp_purchase_request_draft"("p_tenant_id" bigint, "p_request_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION public.delete_pp_purchase_request_draft(bigint, bigint) TO anon, authenticated, service_role;