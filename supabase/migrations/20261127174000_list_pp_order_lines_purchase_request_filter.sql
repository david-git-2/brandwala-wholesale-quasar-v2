DROP FUNCTION IF EXISTS public.list_pp_order_lines(bigint, bigint, bigint, bigint, text[], text[]);

CREATE OR REPLACE FUNCTION public.list_pp_order_lines(
    p_tenant_id bigint,
    p_pp_customer_group_id bigint DEFAULT NULL::bigint,
    p_pp_supplier_group_id bigint DEFAULT NULL::bigint,
    p_shipment_id bigint DEFAULT NULL::bigint,
    p_purchase_request_id bigint DEFAULT NULL::bigint,
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
      AND (p_purchase_request_id IS NULL OR l.purchase_request_id = p_purchase_request_id)
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

ALTER FUNCTION public.list_pp_order_lines(
  bigint,
  bigint,
  bigint,
  bigint,
  bigint,
  text[],
  text[]
) OWNER TO postgres;

GRANT ALL ON FUNCTION public.list_pp_order_lines(
  bigint,
  bigint,
  bigint,
  bigint,
  bigint,
  text[],
  text[]
) TO anon, authenticated, service_role;