-- Proxy purchase: order line enrich + split lifecycle/placement + customer list RPC

ALTER TABLE "public"."pp_order_lines"
    ADD COLUMN IF NOT EXISTS "product_name" "text",
    ADD COLUMN IF NOT EXISTS "image_url" "text",
    ADD COLUMN IF NOT EXISTS "unit_price" numeric,
    ADD COLUMN IF NOT EXISTS "pp_customer_group_id" bigint,
    ADD COLUMN IF NOT EXISTS "pp_supplier_group_id" bigint,
    ADD COLUMN IF NOT EXISTS "shipment_id" bigint,
    ADD COLUMN IF NOT EXISTS "is_added_to_cart" boolean DEFAULT false,
    ADD COLUMN IF NOT EXISTS "added_to_cart_at" timestamp with time zone,
    ADD COLUMN IF NOT EXISTS "placement_status" "text" DEFAULT 'none'::"text",
    ADD COLUMN IF NOT EXISTS "placed_qty" numeric;

UPDATE "public"."pp_order_lines" l
SET pp_customer_group_id = r.people_group_id
FROM "public"."pp_purchase_requests" r
WHERE r.id = l.purchase_request_id
  AND l.pp_customer_group_id IS NULL;

UPDATE "public"."pp_order_lines"
SET is_added_to_cart = false
WHERE is_added_to_cart IS NULL;

UPDATE "public"."pp_order_lines"
SET placement_status = 'none'
WHERE placement_status IS NULL;

ALTER TABLE "public"."pp_order_lines"
    DROP CONSTRAINT IF EXISTS "pp_order_lines_status_check";

UPDATE "public"."pp_order_lines"
SET status = 'requested'
WHERE status = 'pending_review';

ALTER TABLE "public"."pp_order_lines"
    ALTER COLUMN "is_added_to_cart" SET DEFAULT false,
    ALTER COLUMN "is_added_to_cart" SET NOT NULL,
    ALTER COLUMN "placement_status" SET DEFAULT 'none'::"text",
    ALTER COLUMN "placement_status" SET NOT NULL,
    ALTER COLUMN "pp_customer_group_id" SET NOT NULL;

ALTER TABLE "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_status_check" CHECK (
        ("status" = ANY (ARRAY['draft'::"text", 'requested'::"text", 'processing'::"text", 'done'::"text", 'cancelled'::"text"]))
    );

ALTER TABLE "public"."pp_order_lines"
    DROP CONSTRAINT IF EXISTS "pp_order_lines_placement_status_check";

ALTER TABLE "public"."pp_order_lines"
    ADD CONSTRAINT "pp_order_lines_placement_status_check" CHECK (
        ("placement_status" = ANY (ARRAY['none'::"text", 'order_placed'::"text", 'not_available'::"text"]))
    );

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pp_order_lines_pp_customer_group_id_fkey'
  ) THEN
    ALTER TABLE ONLY "public"."pp_order_lines"
      ADD CONSTRAINT "pp_order_lines_pp_customer_group_id_fkey"
      FOREIGN KEY ("pp_customer_group_id") REFERENCES "public"."pp_people_group"("id") ON DELETE RESTRICT;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pp_order_lines_pp_supplier_group_id_fkey'
  ) THEN
    ALTER TABLE ONLY "public"."pp_order_lines"
      ADD CONSTRAINT "pp_order_lines_pp_supplier_group_id_fkey"
      FOREIGN KEY ("pp_supplier_group_id") REFERENCES "public"."pp_people_group"("id") ON DELETE SET NULL;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'pp_order_lines_shipment_id_fkey'
  ) THEN
    ALTER TABLE ONLY "public"."pp_order_lines"
      ADD CONSTRAINT "pp_order_lines_shipment_id_fkey"
      FOREIGN KEY ("shipment_id") REFERENCES "public"."pp_shipment"("id") ON DELETE SET NULL;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS "pp_order_lines_customer_group_active_idx"
    ON "public"."pp_order_lines" ("pp_customer_group_id", "created_at" DESC)
    WHERE ("deleted_at" IS NULL);CREATE OR REPLACE FUNCTION "public"."_pp_order_line_to_json"(
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
  SET status = 'post',
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

GRANT ALL ON FUNCTION "public"."list_pp_order_lines_for_customer"(bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."_pp_order_line_to_json"("public"."pp_order_lines", text) TO "anon", "authenticated", "service_role";

