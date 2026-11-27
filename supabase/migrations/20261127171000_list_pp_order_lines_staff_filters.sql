DROP FUNCTION IF EXISTS public.list_pp_order_lines(bigint);

CREATE OR REPLACE FUNCTION "public"."_pp_order_line_url_host"("p_url" "text")
RETURNS "text"
    LANGUAGE "sql"
    IMMUTABLE
    AS $$
  SELECT CASE
    WHEN length(trim(coalesce(p_url, ''))) = 0 THEN ''
    ELSE lower(
      split_part(
        regexp_replace(
          CASE
            WHEN trim(p_url) ~* '^https?://' THEN trim(p_url)
            ELSE 'https://' || trim(p_url)
          END,
          '^https?://(?:www\.)?',
          '',
          'i'
        ),
        '/',
        1
      )
    )
  END;
$$;

ALTER FUNCTION "public"."_pp_order_line_url_host"("p_url" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_order_lines"(
    "p_tenant_id" bigint,
    "p_pp_customer_group_id" bigint DEFAULT NULL::bigint,
    "p_pp_supplier_group_id" bigint DEFAULT NULL::bigint,
    "p_shipment_id" bigint DEFAULT NULL::bigint,
    "p_placement_status" "text" DEFAULT NULL::"text",
    "p_url_host" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_placement text := lower(trim(coalesce(p_placement_status, '')));
  v_url_host text := lower(trim(coalesce(p_url_host, '')));
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
      AND (p_pp_customer_group_id IS NULL OR l.pp_customer_group_id = p_pp_customer_group_id)
      AND (p_pp_supplier_group_id IS NULL OR l.pp_supplier_group_id = p_pp_supplier_group_id)
      AND (p_shipment_id IS NULL OR l.shipment_id = p_shipment_id)
      AND (v_placement = '' OR l.placement_status = v_placement)
      AND (v_url_host = '' OR public._pp_order_line_url_host(l.url) = v_url_host)
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_order_lines"("p_tenant_id" bigint, "p_pp_customer_group_id" bigint, "p_pp_supplier_group_id" bigint, "p_shipment_id" bigint, "p_placement_status" "text", "p_url_host" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_order_lines_staff_filter_options"("p_tenant_id" bigint)
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

  RETURN jsonb_build_object(
    'url_hosts', (
      SELECT COALESCE(
        jsonb_agg(host ORDER BY host),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT public._pp_order_line_url_host(l.url) AS host
        FROM public.pp_order_lines l
        WHERE l.tenant_id = p_tenant_id
          AND l.deleted_at IS NULL
          AND length(public._pp_order_line_url_host(l.url)) > 0
      ) hosts
    ),
    'placement_statuses', (
      SELECT COALESCE(
        jsonb_agg(ps.placement_status ORDER BY ps.placement_status),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT l.placement_status
        FROM public.pp_order_lines l
        WHERE l.tenant_id = p_tenant_id
          AND l.deleted_at IS NULL
      ) ps
    ),
    'customer_groups', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object('id', g.id, 'name', g.name)
          ORDER BY g.name, g.id
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT l.pp_customer_group_id AS id
        FROM public.pp_order_lines l
        WHERE l.tenant_id = p_tenant_id
          AND l.deleted_at IS NULL
          AND l.pp_customer_group_id IS NOT NULL
      ) cids
      INNER JOIN public.pp_people_group g ON g.id = cids.id AND g.deleted_at IS NULL
    ),
    'supplier_groups', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object('id', g.id, 'name', g.name)
          ORDER BY g.name, g.id
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT l.pp_supplier_group_id AS id
        FROM public.pp_order_lines l
        WHERE l.tenant_id = p_tenant_id
          AND l.deleted_at IS NULL
          AND l.pp_supplier_group_id IS NOT NULL
      ) sids
      INNER JOIN public.pp_people_group g ON g.id = sids.id AND g.deleted_at IS NULL
    ),
    'shipments', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', sh.id,
            'name', sh.name,
            'shipment_code', sh.shipment_code
          )
          ORDER BY sh.created_at DESC, sh.id DESC
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT l.shipment_id AS id
        FROM public.pp_order_lines l
        WHERE l.tenant_id = p_tenant_id
          AND l.deleted_at IS NULL
          AND l.shipment_id IS NOT NULL
      ) shids
      INNER JOIN public.pp_shipment sh
        ON sh.id = shids.id
        AND sh.tenant_id = p_tenant_id
        AND sh.deleted_at IS NULL
    )
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_order_lines_staff_filter_options"("p_tenant_id" bigint) OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."list_pp_order_lines"(bigint, bigint, bigint, bigint, text, text) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."list_pp_order_lines_staff_filter_options"(bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."_pp_order_line_url_host"(text) TO "anon", "authenticated", "service_role";