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
GRANT ALL ON FUNCTION public.list_pp_purchase_requests_for_customer(bigint) TO anon, authenticated, service_role;