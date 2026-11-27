-- Rename purchase request header status post → requested

ALTER TABLE "public"."pp_purchase_requests"
    DROP CONSTRAINT IF EXISTS "pp_purchase_requests_status_check";

UPDATE "public"."pp_purchase_requests"
SET status = 'requested'
WHERE status = 'post';

ALTER TABLE "public"."pp_purchase_requests"
    ADD CONSTRAINT "pp_purchase_requests_status_check" CHECK (
        ("status" = ANY (ARRAY['draft'::"text", 'requested'::"text"]))
    );

CREATE OR REPLACE FUNCTION "public"."post_pp_purchase_request"("p_tenant_id" bigint, "p_request_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_status text;
  v_line_count bigint;
  v_number text;
  v_row public.pp_purchase_requests%ROWTYPE;
BEGIN
  SELECT a.request_status INTO v_status
  FROM public._pp_assert_customer_request_access(p_tenant_id, p_request_id) a
  LIMIT 1;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Request is already posted' USING ERRCODE = '22023';
  END IF;

  SELECT count(*)::bigint INTO v_line_count
  FROM public.pp_order_lines l
  WHERE l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL;

  IF v_line_count < 1 THEN
    RAISE EXCEPTION 'Add at least one item before posting' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_row
  FROM public.pp_purchase_requests r
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'Purchase request not found' USING ERRCODE = '22023';
  END IF;

  v_number := NULLIF(TRIM(BOTH FROM v_row.request_number), '');
  IF v_number IS NULL THEN
    v_number := public.next_document_number(p_tenant_id, 'proxy_purchase_request');
  END IF;

  UPDATE public.pp_purchase_requests r
  SET status = 'requested',
      request_number = v_number,
      updated_at = now()
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL
  RETURNING * INTO v_row;

  UPDATE public.pp_order_lines l
  SET status = 'requested',
      updated_at = now()
  WHERE l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL
    AND l.status = 'draft';

  RETURN jsonb_build_object(
    'id', v_row.id,
    'status', v_row.status,
    'request_number', v_row.request_number,
    'bucket_description', v_row.bucket_description,
    'updated_at', v_row.updated_at
  );
END;
$$;