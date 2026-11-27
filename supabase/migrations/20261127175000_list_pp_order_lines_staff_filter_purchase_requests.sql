CREATE OR REPLACE FUNCTION public.list_pp_order_lines_staff_filter_options(p_tenant_id bigint)
RETURNS jsonb
    LANGUAGE plpgsql
    STABLE
    SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id) THEN
    RAISE EXCEPTION 'Not allowed for tenant %', p_tenant_id USING ERRCODE = '42501';
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
    ),
    'purchase_requests', (
      SELECT COALESCE(
        jsonb_agg(
          jsonb_build_object(
            'id', req.id,
            'request_number', req.request_number,
            'people_group_name', g.name
          )
          ORDER BY req.created_at DESC, req.id DESC
        ),
        '[]'::jsonb
      )
      FROM (
        SELECT DISTINCT l.purchase_request_id AS id
        FROM public.pp_order_lines l
        WHERE l.tenant_id = p_tenant_id
          AND l.deleted_at IS NULL
          AND l.purchase_request_id IS NOT NULL
      ) rids
      INNER JOIN public.pp_purchase_requests req
        ON req.id = rids.id
        AND req.tenant_id = p_tenant_id
        AND req.deleted_at IS NULL
      LEFT JOIN public.pp_people_group g
        ON g.id = req.people_group_id
        AND g.deleted_at IS NULL
    )
  );
END;
$$;

ALTER FUNCTION public.list_pp_order_lines_staff_filter_options(bigint) OWNER TO postgres;

GRANT ALL ON FUNCTION public.list_pp_order_lines_staff_filter_options(bigint) TO anon, authenticated, service_role;