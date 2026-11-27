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