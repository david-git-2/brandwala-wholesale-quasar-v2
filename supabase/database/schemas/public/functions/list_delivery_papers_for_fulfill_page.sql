CREATE FUNCTION public.list_delivery_papers_for_fulfill_page (
  p_tenant_id          bigint,
  p_procurement_status text    DEFAULT 'procuring'::text,
  p_search             text    DEFAULT NULL::text,
  p_limit              integer DEFAULT 50,
  p_offset             integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_papers jsonb := '[]'::jsonb;
  v_total integer := 0;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  SELECT (t.parent_id IS NULL) INTO v_is_parent FROM public.tenants t WHERE t.id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'tenant not found: %', p_tenant_id;
  END IF;

  IF v_is_parent THEN
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  ELSE
    v_allowed := public.is_tenant_staff(p_tenant_id);
  END IF;
  IF NOT coalesce(v_allowed, false) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_status NOT IN ('procuring', 'dispatch', 'delivered', 'closed', 'all') THEN
    RAISE EXCEPTION 'invalid procurement status: %', v_status;
  END IF;

  WITH tenant_scope AS (
    SELECT t.id AS tenant_id
    FROM public.tenants t
    WHERE (
      (v_is_parent AND (t.parent_id = p_tenant_id OR t.id = p_tenant_id))
      OR (NOT v_is_parent AND t.id = p_tenant_id)
    )
  ),
  scoped_papers AS (
    SELECT
      dp.id,
      dp.status,
      dp.source_type,
      dp.source_id,
      dp.profile_id,
      pr.name AS profile_name,
      dp.created_at,
      dp.updated_at,
      dp.delivery_date,
      dp.note,
      CASE
        WHEN dp.source_type = 'shop_order'::public.delivery_paper_source_type THEN
          nullif(trim(o.order_no), '')
        ELSE NULL::text
      END AS shop_order_no,
      CASE
        WHEN dp.source_type = 'pbc_costing_file'::public.delivery_paper_source_type THEN
          nullif(trim(coalesce(f.name, '')), '')
        ELSE NULL::text
      END AS document_name,
      (
        SELECT coalesce(sum(jsonb_array_length(dpl.splits)), 0)::integer
        FROM public.delivery_paper_line dpl
        WHERE dpl.delivery_paper_id = dp.id
      ) AS line_count
    FROM public.delivery_paper dp
    LEFT JOIN public.profiles pr ON pr.id = dp.profile_id
    LEFT JOIN public.shop_orders o
      ON dp.source_type = 'shop_order'::public.delivery_paper_source_type
      AND o.id = dp.source_id
    LEFT JOIN public.product_based_costing_files f
      ON dp.source_type = 'pbc_costing_file'::public.delivery_paper_source_type
      AND f.id = dp.source_id
    WHERE dp.status <> 'cancelled'::public.delivery_paper_status
      AND (
        (
          dp.source_type = 'shop_order'::public.delivery_paper_source_type
          AND o.id IS NOT NULL
          AND o.shop_type_snapshot = 'vendor_catalog'
          AND o.tenant_id IN (SELECT tenant_id FROM tenant_scope)
          AND (
            v_status = 'all'
            OR public.normalize_shop_order_procurement_status(o.status) = v_status
          )
        )
        OR (
          dp.source_type = 'pbc_costing_file'::public.delivery_paper_source_type
          AND f.id IS NOT NULL
          AND f.profile_id IS NOT NULL
          AND f.tenant_id IN (SELECT tenant_id FROM tenant_scope)
          AND (
            v_status = 'all'
            OR public.normalize_pbc_procurement_status(f.status) = v_status
          )
        )
      )
      AND (
        v_search IS NULL
        OR dp.id::text ILIKE '%' || v_search || '%'
        OR coalesce(o.order_no, '') ILIKE '%' || v_search || '%'
        OR o.id::text ILIKE '%' || v_search || '%'
        OR coalesce(f.name, '') ILIKE '%' || v_search || '%'
        OR f.id::text ILIKE '%' || v_search || '%'
        OR coalesce(pr.name, '') ILIKE '%' || v_search || '%'
      )
  ),
  counted AS (
    SELECT count(*)::integer AS total FROM scoped_papers
  ),
  paged AS (
    SELECT sp.*
    FROM scoped_papers sp
    ORDER BY sp.updated_at DESC, sp.id DESC
    LIMIT v_limit
    OFFSET v_offset
  )
  SELECT
    (SELECT total FROM counted),
    coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', p.id,
            'status', p.status,
            'source_type', p.source_type,
            'source_id', p.source_id,
            'shop_order_no', p.shop_order_no,
            'document_name', p.document_name,
            'profile_id', p.profile_id,
            'profile_name', p.profile_name,
            'created_at', p.created_at,
            'updated_at', p.updated_at,
            'delivery_date', p.delivery_date,
            'note', p.note,
            'line_count', p.line_count
          )
          ORDER BY p.updated_at DESC, p.id DESC
        )
        FROM paged p
      ),
      '[]'::jsonb
    )
  INTO v_total, v_papers;

  RETURN jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'total_count', v_total,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_total > (v_offset + v_limit)
    ),
    'papers', v_papers
  );
END;
$function$;

GRANT ALL ON FUNCTION public.list_delivery_papers_for_fulfill_page(bigint, text, text, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_delivery_papers_for_fulfill_page(bigint, text, text, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_delivery_papers_for_fulfill_page(bigint, text, text, integer, integer) TO service_role;
