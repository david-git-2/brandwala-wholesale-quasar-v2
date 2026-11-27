-- Proxy customer purchase request (draft / post)

CREATE OR REPLACE FUNCTION "public"."_pp_resolve_proxy_customer_member"("p_tenant_id" bigint)
RETURNS TABLE("member_id" bigint, "people_group_id" bigint)
    LANGUAGE "sql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT m.id, g.id
  FROM public.pp_people_group_member m
  INNER JOIN public.pp_people_group g ON g.id = m.people_group_id
  WHERE m.tenant_id = p_tenant_id
    AND lower(trim(m.email)) = lower(trim(public.current_user_email()))
    AND m.is_active = true
    AND m.deleted_at IS NULL
    AND g.type = 'customer'
    AND g.deleted_at IS NULL
  ORDER BY g.id ASC, m.id ASC
  LIMIT 1;
$$;

ALTER FUNCTION "public"."_pp_resolve_proxy_customer_member"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_pp_assert_customer_request_access"(
    "p_tenant_id" bigint,
    "p_request_id" bigint
) RETURNS TABLE("member_id" bigint, "people_group_id" bigint, "request_status" "text")
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_member_id bigint;
  v_group_id bigint;
  v_req public.pp_purchase_requests%ROWTYPE;
BEGIN
  SELECT r.member_id, r.people_group_id
  INTO v_member_id, v_group_id
  FROM public._pp_resolve_proxy_customer_member(p_tenant_id) r
  LIMIT 1;

  IF v_member_id IS NULL THEN
    RAISE EXCEPTION 'Proxy customer membership required' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_req
  FROM public.pp_purchase_requests req
  WHERE req.id = p_request_id
    AND req.tenant_id = p_tenant_id
    AND req.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Purchase request not found' USING ERRCODE = 'P0002';
  END IF;

  IF v_req.people_group_id <> v_group_id THEN
    RAISE EXCEPTION 'Not allowed for this purchase request' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY SELECT v_member_id, v_group_id, v_req.status;
END;
$$;

ALTER FUNCTION "public"."_pp_assert_customer_request_access"("p_tenant_id" bigint, "p_request_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_pp_purchase_request_draft"("p_tenant_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_member_id bigint;
  v_group_id bigint;
  v_row public.pp_purchase_requests%ROWTYPE;
BEGIN
  SELECT r.member_id, r.people_group_id INTO v_member_id, v_group_id
  FROM public._pp_resolve_proxy_customer_member(p_tenant_id) r
  LIMIT 1;

  IF v_member_id IS NULL THEN
    RAISE EXCEPTION 'Proxy customer membership required' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.pp_purchase_requests (
    tenant_id, people_group_id, created_by_member_id, status
  ) VALUES (
    p_tenant_id, v_group_id, v_member_id, 'draft'
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

ALTER FUNCTION "public"."create_pp_purchase_request_draft"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_pp_purchase_request"("p_tenant_id" bigint, "p_request_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_row public.pp_purchase_requests%ROWTYPE;
BEGIN
  PERFORM public._pp_assert_customer_request_access(p_tenant_id, p_request_id);

  SELECT * INTO v_row
  FROM public.pp_purchase_requests r
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL;

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

ALTER FUNCTION "public"."get_pp_purchase_request"("p_tenant_id" bigint, "p_request_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_order_lines_for_request"("p_tenant_id" bigint, "p_request_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  PERFORM public._pp_assert_customer_request_access(p_tenant_id, p_request_id);

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', l.id,
          'purchase_request_id', l.purchase_request_id,
          'url', l.url,
          'needed_qty', l.needed_qty,
          'description', l.description,
          'status', l.status,
          'created_at', l.created_at
        )
        ORDER BY l.created_at ASC, l.id ASC
      ),
      '[]'::jsonb
    )
    FROM public.pp_order_lines l
    WHERE l.tenant_id = p_tenant_id
      AND l.purchase_request_id = p_request_id
      AND l.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_order_lines_for_request"("p_tenant_id" bigint, "p_request_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."add_pp_order_line"(
    "p_tenant_id" bigint,
    "p_request_id" bigint,
    "p_url" "text",
    "p_needed_qty" numeric,
    "p_description" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_status text;
  v_url text := trim(coalesce(p_url, ''));
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
BEGIN
  SELECT a.request_status INTO v_status
  FROM public._pp_assert_customer_request_access(p_tenant_id, p_request_id) a
  LIMIT 1;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft requests can be edited' USING ERRCODE = '22023';
  END IF;

  IF length(v_url) = 0 THEN
    RAISE EXCEPTION 'URL is required' USING ERRCODE = '22023';
  END IF;

  IF v_qty IS NULL OR v_qty <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.pp_order_lines (
    tenant_id, purchase_request_id, url, needed_qty, description, status
  ) VALUES (
    p_tenant_id, p_request_id, v_url, v_qty, v_desc, 'draft'
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'purchase_request_id', v_row.purchase_request_id,
    'url', v_row.url,
    'needed_qty', v_row.needed_qty,
    'description', v_row.description,
    'status', v_row.status,
    'created_at', v_row.created_at
  );
END;
$$;

ALTER FUNCTION "public"."add_pp_order_line"("p_tenant_id" bigint, "p_request_id" bigint, "p_url" "text", "p_needed_qty" numeric, "p_description" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_pp_purchase_request_instructions"(
    "p_tenant_id" bigint,
    "p_request_id" bigint,
    "p_bucket_description" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_status text;
  v_row public.pp_purchase_requests%ROWTYPE;
  v_desc text := nullif(trim(coalesce(p_bucket_description, '')), '');
BEGIN
  SELECT a.request_status INTO v_status
  FROM public._pp_assert_customer_request_access(p_tenant_id, p_request_id) a
  LIMIT 1;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft requests can be edited' USING ERRCODE = '22023';
  END IF;

  UPDATE public.pp_purchase_requests r
  SET bucket_description = v_desc,
      updated_at = now()
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'bucket_description', v_row.bucket_description,
    'status', v_row.status,
    'updated_at', v_row.updated_at
  );
END;
$$;

ALTER FUNCTION "public"."update_pp_purchase_request_instructions"("p_tenant_id" bigint, "p_request_id" bigint, "p_bucket_description" "text") OWNER TO "postgres";

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

  v_number := public.next_document_number(p_tenant_id, 'proxy_purchase_request');

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

ALTER FUNCTION "public"."post_pp_purchase_request"("p_tenant_id" bigint, "p_request_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION public.create_pp_purchase_request_draft(bigint) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.get_pp_purchase_request(bigint, bigint) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.list_pp_order_lines_for_request(bigint, bigint) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.add_pp_order_line(bigint, bigint, text, numeric, text) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.update_pp_purchase_request_instructions(bigint, bigint, text) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.post_pp_purchase_request(bigint, bigint) TO anon, authenticated, service_role;
