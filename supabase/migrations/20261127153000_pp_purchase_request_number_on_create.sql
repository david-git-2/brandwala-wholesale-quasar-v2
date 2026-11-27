-- Allocate PPR on draft create; post keeps existing number (backfill legacy nulls on post only).

CREATE OR REPLACE FUNCTION "public"."create_pp_purchase_request_draft"("p_tenant_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_member_id bigint;
  v_group_id bigint;
  v_number text;
  v_row public.pp_purchase_requests%ROWTYPE;
BEGIN
  SELECT r.member_id, r.people_group_id INTO v_member_id, v_group_id
  FROM public._pp_resolve_proxy_customer_member(p_tenant_id) r
  LIMIT 1;

  IF v_member_id IS NULL THEN
    RAISE EXCEPTION 'Proxy customer membership required' USING ERRCODE = '42501';
  END IF;

  v_number := public.next_document_number(p_tenant_id, 'proxy_purchase_request');

  INSERT INTO public.pp_purchase_requests (
    tenant_id, people_group_id, created_by_member_id, status, request_number
  ) VALUES (
    p_tenant_id, v_group_id, v_member_id, 'draft', v_number
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'tenant_id', v_row.tenant_id,
    'people_group_id', v_row.people_group_id,
    'created_by_member_id', v_row.created_by_member_id,
    'status', v_row.status,
    'request_number', v_row.request_number,
    'bucket_description', v_row.bucket_description,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
END;
$$;

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
  SET status = 'post',
      request_number = v_number,
      updated_at = now()
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL
  RETURNING * INTO v_row;

  UPDATE public.pp_order_lines l
  SET status = 'pending_review',
      updated_at = now()
  WHERE l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'status', v_row.status,
    'request_number', v_row.request_number,
    'bucket_description', v_row.bucket_description,
    'updated_at', v_row.updated_at
  );
END;
$$;

-- Backfill draft rows created before numbering-on-create (e.g. local dev).
DO $$
DECLARE
  r record;
  v_number text;
BEGIN
  FOR r IN
    SELECT pr.id, pr.tenant_id
    FROM public.pp_purchase_requests pr
    WHERE pr.deleted_at IS NULL
      AND pr.request_number IS NULL
    ORDER BY pr.id
  LOOP
    v_number := public.next_document_number(r.tenant_id, 'proxy_purchase_request');
    UPDATE public.pp_purchase_requests pr
    SET request_number = v_number,
        updated_at = now()
    WHERE pr.id = r.id;
  END LOOP;
END;
$$;