-- Proxy purchase people group RPCs

CREATE OR REPLACE FUNCTION "public"."list_pp_people_groups"(
    "p_tenant_id" bigint,
    "p_type" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_type text := lower(trim(coalesce(p_type, '')));
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF v_type NOT IN ('customer', 'supplier') THEN
    RAISE EXCEPTION 'Invalid people group type: %', p_type USING ERRCODE = '22023';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', g.id,
          'tenant_id', g.tenant_id,
          'name', g.name,
          'type', g.type,
          'member_count', (
            SELECT count(*)::bigint
            FROM public.pp_people_group_member m
            WHERE m.people_group_id = g.id
              AND m.deleted_at IS NULL
          ),
          'created_at', g.created_at
        )
        ORDER BY g.name ASC, g.id ASC
      ),
      '[]'::jsonb
    )
    FROM public.pp_people_group g
    WHERE g.tenant_id = p_tenant_id
      AND g.type = v_type
      AND g.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_people_groups"("p_tenant_id" bigint, "p_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_pp_people_group"(
    "p_tenant_id" bigint,
    "p_name" "text",
    "p_type" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_name text := trim(coalesce(p_name, ''));
  v_type text := lower(trim(coalesce(p_type, '')));
  v_row public.pp_people_group%ROWTYPE;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF length(v_name) = 0 THEN
    RAISE EXCEPTION 'Group name is required' USING ERRCODE = '22023';
  END IF;

  IF v_type NOT IN ('customer', 'supplier') THEN
    RAISE EXCEPTION 'Invalid people group type: %', p_type USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.pp_people_group (tenant_id, name, type)
  VALUES (p_tenant_id, v_name, v_type)
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'tenant_id', v_row.tenant_id,
    'name', v_row.name,
    'type', v_row.type,
    'member_count', 0::bigint,
    'created_at', v_row.created_at
  );
END;
$$;

ALTER FUNCTION "public"."create_pp_people_group"("p_tenant_id" bigint, "p_name" "text", "p_type" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_people_group_members"(
    "p_tenant_id" bigint,
    "p_people_group_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.pp_people_group g
    WHERE g.id = p_people_group_id
      AND g.tenant_id = p_tenant_id
      AND g.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'People group not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', m.id,
          'people_group_id', m.people_group_id,
          'name', m.name,
          'email', m.email,
          'role', m.role,
          'is_active', m.is_active,
          'created_at', m.created_at
        )
        ORDER BY m.name ASC, m.id ASC
      ),
      '[]'::jsonb
    )
    FROM public.pp_people_group_member m
    WHERE m.tenant_id = p_tenant_id
      AND m.people_group_id = p_people_group_id
      AND m.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_people_group_members"("p_tenant_id" bigint, "p_people_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_pp_people_group_member"(
    "p_tenant_id" bigint,
    "p_people_group_id" bigint,
    "p_name" "text",
    "p_email" "text",
    "p_role" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_name text := trim(coalesce(p_name, ''));
  v_email text := lower(trim(coalesce(p_email, '')));
  v_role text := lower(trim(coalesce(p_role, '')));
  v_group public.pp_people_group%ROWTYPE;
  v_row public.pp_people_group_member%ROWTYPE;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_group
  FROM public.pp_people_group g
  WHERE g.id = p_people_group_id
    AND g.tenant_id = p_tenant_id
    AND g.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'People group not found' USING ERRCODE = 'P0002';
  END IF;

  IF length(v_name) = 0 THEN
    RAISE EXCEPTION 'Member name is required' USING ERRCODE = '22023';
  END IF;

  IF length(v_email) = 0 THEN
    RAISE EXCEPTION 'Member email is required' USING ERRCODE = '22023';
  END IF;

  IF v_role NOT IN ('admin', 'staff') THEN
    RAISE EXCEPTION 'Invalid member role: %', p_role USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.pp_people_group_member m
    WHERE m.people_group_id = p_people_group_id
      AND lower(trim(m.email)) = v_email
      AND m.deleted_at IS NULL
  ) THEN
    RAISE EXCEPTION 'A member with this email already exists in the group' USING ERRCODE = '23505';
  END IF;

  INSERT INTO public.pp_people_group_member (
    tenant_id,
    people_group_id,
    name,
    email,
    role
  )
  VALUES (
    v_group.tenant_id,
    p_people_group_id,
    v_name,
    v_email,
    v_role
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'people_group_id', v_row.people_group_id,
    'name', v_row.name,
    'email', v_row.email,
    'role', v_row.role,
    'is_active', v_row.is_active,
    'created_at', v_row.created_at
  );
END;
$$;

ALTER FUNCTION "public"."create_pp_people_group_member"("p_tenant_id" bigint, "p_people_group_id" bigint, "p_name" "text", "p_email" "text", "p_role" "text") OWNER TO "postgres";

-- Proxy purchase shipment RPCs

CREATE OR REPLACE FUNCTION "public"."list_pp_shipments"(
    "p_tenant_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'tenant_id', s.tenant_id,
          'name', s.name,
          'shipment_code', s.shipment_code,
          'status', s.status,
          'created_at', s.created_at
        )
        ORDER BY s.created_at DESC, s.id DESC
      ),
      '[]'::jsonb
    )
    FROM public.pp_shipment s
    WHERE s.tenant_id = p_tenant_id
      AND s.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_shipments"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_pp_shipment"(
    "p_tenant_id" bigint,
    "p_name" "text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_name text := trim(coalesce(p_name, ''));
  v_code text;
  v_row public.pp_shipment%ROWTYPE;
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF length(v_name) = 0 THEN
    RAISE EXCEPTION 'Shipment name is required' USING ERRCODE = '22023';
  END IF;

  v_code := public.next_document_number(p_tenant_id, 'proxy_shipment');

  INSERT INTO public.pp_shipment (tenant_id, name, shipment_code, status)
  VALUES (p_tenant_id, v_name, v_code, 'draft')
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'tenant_id', v_row.tenant_id,
    'name', v_row.name,
    'shipment_code', v_row.shipment_code,
    'status', v_row.status,
    'created_at', v_row.created_at
  );
END;
$$;

ALTER FUNCTION "public"."create_pp_shipment"("p_tenant_id" bigint, "p_name" "text") OWNER TO "postgres";

-- Proxy portal login

CREATE OR REPLACE FUNCTION "public"."check_proxy_login_access"(
    "p_email" "text",
    "p_tenant_id" bigint DEFAULT NULL::bigint
) RETURNS TABLE(
    "has_match" boolean,
    "matched_role" "text",
    "member_id" bigint,
    "member_name" "text",
    "member_email" "text",
    "member_tenant_id" bigint,
    "people_group_id" bigint,
    "people_group_name" "text",
    "people_group_type" "text",
    "member_is_active" boolean,
    "people_group_is_active" boolean,
    "member_created_at" timestamp with time zone,
    "member_updated_at" timestamp with time zone
)
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_email text;
BEGIN
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  IF length(v_email) = 0 THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    true,
    m.role,
    m.id,
    coalesce(nullif(trim(m.name), ''), ''),
    lower(trim(m.email)),
    m.tenant_id,
    g.id,
    g.name,
    g.type,
    m.is_active,
    (g.deleted_at IS NULL),
    m.created_at,
    m.updated_at
  FROM public.pp_people_group_member m
  INNER JOIN public.pp_people_group g
    ON g.id = m.people_group_id
  INNER JOIN public.tenants t
    ON t.id = m.tenant_id
  WHERE lower(trim(m.email)) = v_email
    AND m.is_active = true
    AND m.deleted_at IS NULL
    AND g.deleted_at IS NULL
    AND t.is_active = true
    AND (p_tenant_id IS NULL OR m.tenant_id = p_tenant_id)
    AND EXISTS (
      SELECT 1
      FROM public.tenant_modules tm
      WHERE tm.tenant_id = m.tenant_id
        AND tm.module_key = 'proxy_purchase'
        AND tm.is_active = true
    )
  ORDER BY
    g.name ASC,
    g.id ASC,
    CASE m.role WHEN 'admin' THEN 1 WHEN 'staff' THEN 2 ELSE 99 END ASC,
    m.id ASC;
END;
$$;

ALTER FUNCTION "public"."check_proxy_login_access"("p_email" "text", "p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_proxy_bootstrap_context"(
    "p_email" "text" DEFAULT NULL::"text",
    "p_tenant_id" bigint DEFAULT NULL::bigint,
    "p_people_group_member_id" bigint DEFAULT NULL::bigint
) RETURNS TABLE(
    "member_id" bigint,
    "member_name" "text",
    "member_email" "text",
    "member_role" "text",
    "member_is_active" boolean,
    "people_group_id" bigint,
    "people_group_name" "text",
    "people_group_type" "text",
    "people_group_is_active" boolean,
    "tenant_id" bigint,
    "tenant_name" "text",
    "tenant_slug" "text",
    "tenant_is_active" boolean,
    "active_module_keys" "text"[],
    "effective_grants" "jsonb",
    "tenant_role_id" bigint,
    "is_admin" boolean,
    "permission_version" bigint
)
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_email text;
  v_perm_version bigint;
BEGIN
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  IF length(v_email) = 0 OR p_tenant_id IS NULL OR p_people_group_member_id IS NULL THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.tenant_modules tm
    WHERE tm.tenant_id = p_tenant_id
      AND tm.module_key = 'proxy_purchase'
      AND tm.is_active = true
  ) THEN
    RETURN;
  END IF;

  SELECT tpv.version INTO v_perm_version
  FROM public.tenant_permission_versions tpv
  WHERE tpv.tenant_id = p_tenant_id;

  IF v_perm_version IS NULL THEN
    PERFORM public.bump_tenant_permission_version(p_tenant_id);
    v_perm_version := 1;
  END IF;

  RETURN QUERY
  SELECT
    m.id,
    coalesce(nullif(trim(m.name), ''), ''),
    lower(trim(m.email)),
    m.role,
    m.is_active,
    g.id,
    g.name,
    g.type,
    (g.deleted_at IS NULL),
    t.id,
    t.name,
    t.slug,
    t.is_active,
    ARRAY['proxy_purchase']::text[],
    jsonb_build_array(jsonb_build_object('module_key', 'proxy_purchase', 'action', 'view')),
    NULL::bigint,
    false,
    v_perm_version
  FROM public.pp_people_group_member m
  INNER JOIN public.pp_people_group g ON g.id = m.people_group_id
  INNER JOIN public.tenants t ON t.id = m.tenant_id
  WHERE m.id = p_people_group_member_id
    AND m.tenant_id = p_tenant_id
    AND lower(trim(m.email)) = v_email
    AND m.is_active = true
    AND m.deleted_at IS NULL
    AND g.deleted_at IS NULL
    AND t.is_active = true
  LIMIT 1;
END;
$$;

ALTER FUNCTION "public"."get_proxy_bootstrap_context"("p_email" "text", "p_tenant_id" bigint, "p_people_group_member_id" bigint) OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."list_pp_purchase_requests_for_customer"("p_tenant_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_group_id bigint;
BEGIN
  SELECT r.people_group_id INTO v_group_id
  FROM public._pp_resolve_proxy_customer_member(p_tenant_id) r
  LIMIT 1;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Proxy customer membership required' USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', req.id,
          'request_number', req.request_number,
          'status', req.status,
          'created_at', req.created_at,
          'updated_at', req.updated_at,
          'line_count', (
            SELECT count(*)::bigint
            FROM public.pp_order_lines l
            WHERE l.tenant_id = p_tenant_id
              AND l.purchase_request_id = req.id
              AND l.deleted_at IS NULL
          )
        )
        ORDER BY req.created_at DESC, req.id DESC
      ),
      '[]'::jsonb
    )
    FROM public.pp_purchase_requests req
    WHERE req.tenant_id = p_tenant_id
      AND req.people_group_id = v_group_id
      AND req.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_purchase_requests_for_customer"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_purchase_requests"("p_tenant_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        jsonb_build_object(
          'id', req.id,
          'request_number', req.request_number,
          'status', req.status,
          'created_at', req.created_at,
          'updated_at', req.updated_at,
          'people_group_id', req.people_group_id,
          'people_group_name', g.name,
          'line_count', (
            SELECT count(*)::bigint
            FROM public.pp_order_lines l
            WHERE l.tenant_id = p_tenant_id
              AND l.purchase_request_id = req.id
              AND l.deleted_at IS NULL
          )
        )
        ORDER BY req.created_at DESC, req.id DESC
      ),
      '[]'::jsonb
    )
    FROM public.pp_purchase_requests req
    INNER JOIN public.pp_people_group g ON g.id = req.people_group_id AND g.deleted_at IS NULL
    WHERE req.tenant_id = p_tenant_id
      AND req.deleted_at IS NULL
      AND req.status = 'requested'
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_purchase_requests"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_pp_order_line_to_json"(
    "l" "public"."pp_order_lines",
    "p_shipment_status" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
    LANGUAGE "sql"
    IMMUTABLE
    AS $$
  SELECT jsonb_build_object(
    'id', l.id,
    'purchase_request_id', l.purchase_request_id,
    'pp_customer_group_id', l.pp_customer_group_id,
    'url', l.url,
    'needed_qty', l.needed_qty,
    'description', l.description,
    'product_name', l.product_name,
    'image_url', l.image_url,
    'unit_price', l.unit_price,
    'pp_supplier_group_id', l.pp_supplier_group_id,
    'shipment_id', l.shipment_id,
    'shipment_status', p_shipment_status,
    'is_added_to_cart', l.is_added_to_cart,
    'added_to_cart_at', l.added_to_cart_at,
    'placement_status', l.placement_status,
    'placed_qty', l.placed_qty,
    'status', l.status,
    'created_at', l.created_at
  );
$$;

ALTER FUNCTION "public"."_pp_order_line_to_json"("public"."pp_order_lines", "text") OWNER TO "postgres";

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
        public._pp_order_line_to_json(l, s.status)
        ORDER BY l.created_at ASC, l.id ASC
      ),
      '[]'::jsonb
    )
    FROM public.pp_order_lines l
    LEFT JOIN public.pp_shipment s ON s.id = l.shipment_id AND s.deleted_at IS NULL
    WHERE l.tenant_id = p_tenant_id
      AND l.purchase_request_id = p_request_id
      AND l.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_order_lines_for_request"("p_tenant_id" bigint, "p_request_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_order_lines_for_customer"("p_tenant_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_group_id bigint;
BEGIN
  SELECT r.people_group_id INTO v_group_id
  FROM public._pp_resolve_proxy_customer_member(p_tenant_id) r
  LIMIT 1;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Proxy customer membership required' USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        public._pp_order_line_to_json(l, s.status)
        ORDER BY l.created_at DESC, l.id DESC
      ),
      '[]'::jsonb
    )
    FROM public.pp_order_lines l
    LEFT JOIN public.pp_shipment s ON s.id = l.shipment_id AND s.deleted_at IS NULL
    WHERE l.tenant_id = p_tenant_id
      AND l.pp_customer_group_id = v_group_id
      AND l.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_order_lines_for_customer"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_order_lines"("p_tenant_id" bigint)
RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        public._pp_order_line_to_json(l, s.status)
        || jsonb_build_object(
          'customer_group_name', cg.name,
          'supplier_group_name', sg.name,
          'request_number', req.request_number,
          'request_bucket_description', req.bucket_description
        )
        ORDER BY l.created_at DESC, l.id DESC
      ),
      '[]'::jsonb
    )
    FROM public.pp_order_lines l
    LEFT JOIN public.pp_shipment s ON s.id = l.shipment_id AND s.deleted_at IS NULL
    LEFT JOIN public.pp_people_group cg ON cg.id = l.pp_customer_group_id AND cg.deleted_at IS NULL
    LEFT JOIN public.pp_people_group sg ON sg.id = l.pp_supplier_group_id AND sg.deleted_at IS NULL
    LEFT JOIN public.pp_purchase_requests req
      ON req.id = l.purchase_request_id
      AND req.tenant_id = p_tenant_id
      AND req.deleted_at IS NULL
    WHERE l.tenant_id = p_tenant_id
      AND l.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_order_lines"("p_tenant_id" bigint) OWNER TO "postgres";

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
  v_group_id bigint;
  v_url text := trim(coalesce(p_url, ''));
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
BEGIN
  SELECT a.request_status, a.people_group_id INTO v_status, v_group_id
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
    tenant_id,
    purchase_request_id,
    pp_customer_group_id,
    url,
    needed_qty,
    description,
    status,
    placement_status
  ) VALUES (
    p_tenant_id, p_request_id, v_group_id, v_url, v_qty, v_desc, 'draft', 'none'
  )
  RETURNING * INTO v_row;

  RETURN public._pp_order_line_to_json(v_row, NULL);
END;
$$;

ALTER FUNCTION "public"."add_pp_order_line"("p_tenant_id" bigint, "p_request_id" bigint, "p_url" "text", "p_needed_qty" numeric, "p_description" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_pp_order_line"(
    "p_tenant_id" bigint,
    "p_request_id" bigint,
    "p_line_id" bigint,
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

  UPDATE public.pp_order_lines l
  SET url = v_url,
      needed_qty = v_qty,
      description = v_desc,
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN public._pp_order_line_to_json(v_row, NULL);
END;
$$;

ALTER FUNCTION "public"."update_pp_order_line"("p_tenant_id" bigint, "p_request_id" bigint, "p_line_id" bigint, "p_url" "text", "p_needed_qty" numeric, "p_description" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."delete_pp_order_line"(
    "p_tenant_id" bigint,
    "p_request_id" bigint,
    "p_line_id" bigint
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
    RAISE EXCEPTION 'Only draft requests can be edited' USING ERRCODE = '22023';
  END IF;

  UPDATE public.pp_order_lines l
  SET deleted_at = now(),
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.purchase_request_id = p_request_id
    AND l.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('id', p_line_id, 'deleted', true);
END;
$$;

ALTER FUNCTION "public"."delete_pp_order_line"("p_tenant_id" bigint, "p_request_id" bigint, "p_line_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_pp_order_line_staff"(
    "p_tenant_id" bigint,
    "p_line_id" bigint,
    "p_url" "text",
    "p_needed_qty" numeric,
    "p_description" "text" DEFAULT NULL::"text",
    "p_product_name" "text" DEFAULT NULL::"text",
    "p_image_url" "text" DEFAULT NULL::"text",
    "p_unit_price" numeric DEFAULT NULL::numeric,
    "p_pp_supplier_group_id" bigint DEFAULT NULL::bigint,
    "p_shipment_id" bigint DEFAULT NULL::bigint,
    "p_is_added_to_cart" boolean DEFAULT NULL::boolean,
    "p_placement_status" "text" DEFAULT NULL::"text",
    "p_placed_qty" numeric DEFAULT NULL::numeric,
    "p_status" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_url text := trim(coalesce(p_url, ''));
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_product_name text := nullif(trim(coalesce(p_product_name, '')), '');
  v_image_url text := nullif(trim(coalesce(p_image_url, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
  v_shipment_status text;
  v_placement text := lower(trim(coalesce(p_placement_status, '')));
  v_status text := lower(trim(coalesce(p_status, '')));
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  IF length(v_url) = 0 THEN
    RAISE EXCEPTION 'URL is required' USING ERRCODE = '22023';
  END IF;

  IF v_qty IS NULL OR v_qty <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE = '22023';
  END IF;

  IF v_placement <> '' AND v_placement NOT IN (
    'none', 'added_to_cart', 'order_placed', 'cargo_warehouse',
    'in_flight', 'local_warehouse', 'delivered', 'lost'
  ) THEN
    RAISE EXCEPTION 'Invalid placement status: %', p_placement_status USING ERRCODE = '22023';
  END IF;

  IF v_status <> '' AND v_status NOT IN ('draft', 'requested', 'processing', 'done', 'cancelled') THEN
    RAISE EXCEPTION 'Invalid line status: %', p_status USING ERRCODE = '22023';
  END IF;

  IF p_pp_supplier_group_id IS NOT NULL THEN
    PERFORM 1
    FROM public.pp_people_group g
    WHERE g.id = p_pp_supplier_group_id
      AND g.tenant_id = p_tenant_id
      AND g.type = 'supplier'
      AND g.deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid supplier group' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_shipment_id IS NOT NULL THEN
    PERFORM 1
    FROM public.pp_shipment sh
    WHERE sh.id = p_shipment_id
      AND sh.tenant_id = p_tenant_id
      AND sh.deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid shipment' USING ERRCODE = '22023';
    END IF;
  END IF;

  UPDATE public.pp_order_lines l
  SET url = v_url,
      needed_qty = v_qty,
      description = v_desc,
      product_name = v_product_name,
      image_url = v_image_url,
      unit_price = p_unit_price,
      pp_supplier_group_id = p_pp_supplier_group_id,
      shipment_id = p_shipment_id,
      placement_status = CASE WHEN v_placement = '' THEN l.placement_status ELSE v_placement END,
      is_added_to_cart = CASE
        WHEN v_placement <> '' THEN v_placement <> 'none'
        ELSE coalesce(p_is_added_to_cart, l.is_added_to_cart)
      END,
      added_to_cart_at = CASE
        WHEN v_placement = 'none' THEN NULL
        WHEN v_placement <> '' AND v_placement <> 'none' AND NOT l.is_added_to_cart THEN now()
        WHEN v_placement <> '' AND v_placement <> 'none' THEN l.added_to_cart_at
        WHEN p_is_added_to_cart IS TRUE AND NOT l.is_added_to_cart THEN now()
        WHEN p_is_added_to_cart IS FALSE THEN NULL
        ELSE l.added_to_cart_at
      END,
      placed_qty = p_placed_qty,
      status = CASE WHEN v_status = '' THEN l.status ELSE v_status END,
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.deleted_at IS NULL
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT s.status INTO v_shipment_status
  FROM public.pp_shipment s
  WHERE s.id = v_row.shipment_id
    AND s.deleted_at IS NULL;

  RETURN public._pp_order_line_to_json(v_row, v_shipment_status);
END;
$$;

ALTER FUNCTION "public"."update_pp_order_line_staff"("p_tenant_id" bigint, "p_line_id" bigint, "p_url" "text", "p_needed_qty" numeric, "p_description" "text", "p_product_name" "text", "p_image_url" "text", "p_unit_price" numeric, "p_pp_supplier_group_id" bigint, "p_shipment_id" bigint, "p_is_added_to_cart" boolean, "p_placement_status" "text", "p_placed_qty" numeric, "p_status" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."delete_pp_order_line_staff"(
    "p_tenant_id" bigint,
    "p_line_id" bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT "public"."has_active_tenant_membership"("p_tenant_id") THEN
    RAISE EXCEPTION 'Not allowed for tenant %', "p_tenant_id" USING ERRCODE = '42501';
  END IF;

  UPDATE public.pp_order_lines l
  SET deleted_at = now(),
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  RETURN jsonb_build_object('id', p_line_id, 'deleted', true);
END;
$$;

ALTER FUNCTION "public"."delete_pp_order_line_staff"("p_tenant_id" bigint, "p_line_id" bigint) OWNER TO "postgres";

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

ALTER FUNCTION "public"."post_pp_purchase_request"("p_tenant_id" bigint, "p_request_id" bigint) OWNER TO "postgres";

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