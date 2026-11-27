ALTER TABLE public.pp_purchase_requests
  ADD COLUMN IF NOT EXISTS bucket_instructions jsonb NOT NULL DEFAULT '[]'::jsonb;

UPDATE public.pp_purchase_requests r
SET bucket_instructions = jsonb_build_array(
    jsonb_build_object('store', 'general', 'description', trim(r.bucket_description))
  )
WHERE r.bucket_description IS NOT NULL
  AND length(trim(r.bucket_description)) > 0;

ALTER TABLE public.pp_purchase_requests
  DROP COLUMN IF EXISTS bucket_description;

CREATE OR REPLACE FUNCTION public._pp_normalize_bucket_instructions(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_item jsonb;
  v_store text;
  v_desc text;
  v_map jsonb := '{}'::jsonb;
  v_key text;
BEGIN
  IF p_payload IS NULL OR jsonb_typeof(p_payload) <> 'array' THEN
    RETURN '[]'::jsonb;
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_payload)
  LOOP
  IF jsonb_typeof(v_item) <> 'object' THEN
    CONTINUE;
  END IF;

  v_store := lower(trim(coalesce(v_item ->> 'store', '')));
  v_desc := trim(coalesce(v_item ->> 'description', ''));

  IF v_store = '' OR v_desc = '' THEN
    CONTINUE;
  END IF;

  IF v_store <> 'general'
    AND NOT (v_store ~ '^[a-z0-9]([a-z0-9.-]*[a-z0-9])?$')
  THEN
    CONTINUE;
  END IF;

  v_map := v_map || jsonb_build_object(v_store, v_desc);
  END LOOP;

  RETURN COALESCE(
    (
      SELECT jsonb_agg(
        jsonb_build_object('store', key, 'description', value)
        ORDER BY
          CASE WHEN key = 'general' THEN 0 ELSE 1 END,
          key
      )
      FROM jsonb_each_text(v_map)
    ),
    '[]'::jsonb
  );
END;
$$;

ALTER FUNCTION public._pp_normalize_bucket_instructions(jsonb) OWNER TO postgres;

DROP FUNCTION IF EXISTS public.update_pp_purchase_request_instructions(bigint, bigint, text);

CREATE OR REPLACE FUNCTION public.update_pp_purchase_request_instructions(
    p_tenant_id bigint,
    p_request_id bigint,
    p_bucket_instructions jsonb
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_status text;
  v_row public.pp_purchase_requests%ROWTYPE;
  v_instructions jsonb;
BEGIN
  SELECT a.request_status INTO v_status
  FROM public._pp_assert_customer_request_access(p_tenant_id, p_request_id) a
  LIMIT 1;

  IF v_status <> 'draft' THEN
    RAISE EXCEPTION 'Only draft requests can be edited' USING ERRCODE = '22023';
  END IF;

  v_instructions := public._pp_normalize_bucket_instructions(p_bucket_instructions);

  UPDATE public.pp_purchase_requests r
  SET bucket_instructions = v_instructions,
      updated_at = now()
  WHERE r.id = p_request_id
    AND r.tenant_id = p_tenant_id
    AND r.deleted_at IS NULL
  RETURNING * INTO v_row;

  RETURN jsonb_build_object(
    'id', v_row.id,
    'bucket_instructions', v_row.bucket_instructions,
    'status', v_row.status,
    'updated_at', v_row.updated_at
  );
END;
$$;

ALTER FUNCTION public.update_pp_purchase_request_instructions(bigint, bigint, jsonb) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.create_pp_purchase_request_draft(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
    'bucket_instructions', v_row.bucket_instructions,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_pp_purchase_request(p_tenant_id bigint, p_request_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO 'public'
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
    'bucket_instructions', v_row.bucket_instructions,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.post_pp_purchase_request(p_tenant_id bigint, p_request_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
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
    'bucket_instructions', v_row.bucket_instructions,
    'updated_at', v_row.updated_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_pp_order_lines(
    p_tenant_id bigint,
    p_pp_customer_group_id bigint DEFAULT NULL::bigint,
    p_pp_supplier_group_id bigint DEFAULT NULL::bigint,
    p_shipment_id bigint DEFAULT NULL::bigint,
    p_placement_statuses text[] DEFAULT NULL::text[],
    p_url_hosts text[] DEFAULT NULL::text[]
) RETURNS jsonb
    LANGUAGE plpgsql
    STABLE
    SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id) THEN
    RAISE EXCEPTION 'Not allowed for tenant %', p_tenant_id USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        public._pp_order_line_to_json(l, s.status)
        || jsonb_build_object(
          'customer_group_name', cg.name,
          'supplier_group_name', sg.name,
          'request_number', req.request_number,
          'request_bucket_instructions', req.bucket_instructions
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
      AND (p_pp_customer_group_id IS NULL OR l.pp_customer_group_id = p_pp_customer_group_id)
      AND (p_pp_supplier_group_id IS NULL OR l.pp_supplier_group_id = p_pp_supplier_group_id)
      AND (p_shipment_id IS NULL OR l.shipment_id = p_shipment_id)
      AND (
        p_placement_statuses IS NULL
        OR cardinality(p_placement_statuses) = 0
        OR l.placement_status = ANY(p_placement_statuses)
      )
      AND (
        p_url_hosts IS NULL
        OR cardinality(p_url_hosts) = 0
        OR public._pp_order_line_url_host(l.url) = ANY(p_url_hosts)
      )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.list_pp_order_lines_for_supplier(
    p_tenant_id bigint,
    p_people_group_member_id bigint DEFAULT NULL::bigint
) RETURNS jsonb
    LANGUAGE plpgsql
    STABLE
    SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  v_group_id bigint;
BEGIN
  SELECT r.people_group_id INTO v_group_id
  FROM public._pp_resolve_proxy_supplier_member(p_tenant_id, p_people_group_member_id) r
  LIMIT 1;

  IF v_group_id IS NULL THEN
    RAISE EXCEPTION 'Proxy supplier membership required' USING ERRCODE = '42501';
  END IF;

  RETURN (
    SELECT COALESCE(
      jsonb_agg(
        public._pp_order_line_to_json(l, s.status)
        || jsonb_build_object(
          'customer_group_name', cg.name,
          'supplier_group_name', sg.name,
          'request_number', req.request_number,
          'request_bucket_instructions', req.bucket_instructions
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
      AND l.pp_supplier_group_id IS NOT NULL
      AND l.pp_supplier_group_id = v_group_id
      AND l.deleted_at IS NULL
  );
END;
$$;

GRANT ALL ON FUNCTION public._pp_normalize_bucket_instructions(jsonb) TO anon, authenticated, service_role;
GRANT ALL ON FUNCTION public.update_pp_purchase_request_instructions(bigint, bigint, jsonb) TO anon, authenticated, service_role;