DROP FUNCTION IF EXISTS "public"."list_pp_order_lines_for_supplier"(bigint);

DROP FUNCTION IF EXISTS "public"."_pp_resolve_proxy_supplier_member"(bigint);

CREATE OR REPLACE FUNCTION "public"."_pp_resolve_proxy_supplier_member"(
    "p_tenant_id" bigint,
    "p_people_group_member_id" bigint DEFAULT NULL::bigint
) RETURNS TABLE("member_id" bigint, "people_group_id" bigint)
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
    AND g.type = 'supplier'
    AND g.deleted_at IS NULL
    AND (
      p_people_group_member_id IS NULL
      OR m.id = p_people_group_member_id
    )
  ORDER BY
    CASE WHEN p_people_group_member_id IS NOT NULL AND m.id = p_people_group_member_id THEN 0 ELSE 1 END,
    g.id ASC,
    m.id ASC
  LIMIT 1;
$$;

ALTER FUNCTION "public"."_pp_resolve_proxy_supplier_member"("p_tenant_id" bigint, "p_people_group_member_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_pp_order_lines_for_supplier"(
    "p_tenant_id" bigint,
    "p_people_group_member_id" bigint DEFAULT NULL::bigint
) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    STABLE
    SECURITY DEFINER
    SET "search_path" TO 'public'
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
      AND l.pp_supplier_group_id IS NOT NULL
      AND l.pp_supplier_group_id = v_group_id
      AND l.deleted_at IS NULL
  );
END;
$$;

ALTER FUNCTION "public"."list_pp_order_lines_for_supplier"("p_tenant_id" bigint, "p_people_group_member_id" bigint) OWNER TO "postgres";

GRANT ALL ON FUNCTION "public"."list_pp_order_lines_for_supplier"(bigint, bigint) TO "anon", "authenticated", "service_role";
GRANT ALL ON FUNCTION "public"."_pp_resolve_proxy_supplier_member"(bigint, bigint) TO "anon", "authenticated", "service_role";