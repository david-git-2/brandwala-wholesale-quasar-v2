-- Align POS search default_sell_price with shipment resolveListedSellPrice:
-- manual lock → listed_unit_price; else ceil_thrift_retail_price(landed * (1 + applied markup)).
-- Depends on: 20270802000045

BEGIN;

CREATE OR REPLACE FUNCTION public.ceil_thrift_retail_price(p_price numeric)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
AS $$
DECLARE
  n numeric;
  century numeric;
  ending numeric;
  candidate numeric;
BEGIN
  IF p_price IS NULL OR p_price <= 0 THEN
    RETURN 50;
  END IF;

  n := ceil(p_price);
  century := floor(n / 100) * 100;

  LOOP
    FOREACH ending IN ARRAY ARRAY[50, 90]::numeric[] LOOP
      candidate := century + ending;
      IF candidate >= n THEN
        RETURN candidate;
      END IF;
    END LOOP;
    century := century + 100;
  END LOOP;
END;
$$;

COMMENT ON FUNCTION public.ceil_thrift_retail_price(numeric) IS
  'Ceil to next thrift retail ending (.50 / .90); matches web ceilThriftRetailPrice.';

CREATE OR REPLACE FUNCTION public.search_thrift_available_stocks_for_sale(
  p_tenant_id BIGINT,
  p_search TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_limit INT DEFAULT 50
)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_search TEXT := NULLIF(trim(COALESCE(p_search, '')), '');
  v_phone TEXT := public.normalize_thrift_phone(p_customer_phone);
  v_limit INT := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
  v_result JSONB;
BEGIN
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_stock', 'view')
  ) THEN
    RAISE EXCEPTION 'Searching thrift stock for sale requires thrift_sales or thrift_stock access';
  END IF;

  IF v_search IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  WITH matched AS (
    SELECT s.*
    FROM public.thrift_stocks s
    WHERE s.tenant_id = p_tenant_id
      AND s.deleted_at IS NULL
      AND (
        s.name ILIKE '%' || v_search || '%'
        OR COALESCE(s.barcode, '') ILIKE '%' || v_search || '%'
        OR COALESCE(s.brand_name, '') ILIKE '%' || v_search || '%'
        OR COALESCE(s.color, '') ILIKE '%' || v_search || '%'
        OR COALESCE(s.size, '') ILIKE '%' || v_search || '%'
      )
      AND (
        s.status = 'AVAILABLE'::public.thrift_stock_status
        OR (
          v_phone <> ''
          AND s.status = 'RESERVED'::public.thrift_stock_status
          AND s.held_for_phone_normalized IS NOT DISTINCT FROM v_phone
        )
      )
    ORDER BY s.created_at DESC
    LIMIT v_limit
  ),
  enriched AS (
    SELECT
      b.id,
      b.created_at,
      b.name,
      b.barcode,
      b.available_quantity,
      b.landed_cost,
      b.category,
      b.status,
      b.brand_name,
      b.type_name,
      b.color,
      b.size,
      b.condition,
      b.section,
      b.shelf_code,
      b.box_name,
      b.image_url,
      b.shipment_id,
      b.shipment_name,
      b.held_for_phone,
      b.held_for_name,
      CASE
        WHEN b.is_listed_price_manual THEN b.listed_unit_price
        ELSE public.ceil_thrift_retail_price(
          b.landed_cost * (1 + b.applied_markup_rate)
        )
      END AS default_sell_price
    FROM (
      SELECT
        m.id,
        m.created_at,
        COALESCE(NULLIF(trim(m.name), ''), 'Unnamed Item') AS name,
        COALESCE(NULLIF(trim(m.barcode), ''), 'NO-BARCODE') AS barcode,
        GREATEST(COALESCE(m.quantity, 0), 0) AS available_quantity,
        ROUND(COALESCE(public.compute_thrift_landed_unit_cost(m.id), 0.00), 2) AS landed_cost,
        COALESCE(c.name, 'Uncategorized') AS category,
        m.status::text AS status,
        m.brand_name,
        t.name AS type_name,
        m.color,
        m.size,
        m.condition::text AS condition,
        m.section::text AS section,
        sh.shelf_code,
        b.name AS box_name,
        (
          SELECT i.image_url
          FROM public.thrift_stock_images i
          WHERE i.stock_id = m.id
          ORDER BY i.is_primary DESC NULLS LAST, i.id ASC
          LIMIT 1
        ) AS image_url,
        COALESCE(m.shipment_id, 0) AS shipment_id,
        ship.name AS shipment_name,
        m.held_for_phone,
        m.held_for_name,
        COALESCE(p.is_listed_price_manual, false) AS is_listed_price_manual,
        ROUND(COALESCE(p.listed_unit_price, 0), 2) AS listed_unit_price,
        COALESCE(p.markup_rate_override, ship.default_markup_rate, 0) AS applied_markup_rate
      FROM matched m
      LEFT JOIN public.thrift_categories c ON c.id = m.category_id
      LEFT JOIN public.thrift_types t ON t.id = m.type_id
      LEFT JOIN public.thrift_shelves sh ON sh.id = m.shelf_id
      LEFT JOIN public.thrift_boxes b ON b.id = m.box_id
      LEFT JOIN public.thrift_shipments ship ON ship.id = m.shipment_id
      LEFT JOIN LATERAL (
        SELECT
          pr.listed_unit_price,
          pr.is_listed_price_manual,
          pr.markup_rate_override
        FROM public.thrift_pricings pr
        WHERE pr.stock_id = m.id
        ORDER BY pr.id DESC
        LIMIT 1
      ) p ON TRUE
    ) b
  )
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', e.id,
        'name', e.name,
        'barcode', e.barcode,
        'available_quantity', e.available_quantity,
        'landed_cost', e.landed_cost,
        'default_sell_price', e.default_sell_price,
        'category', e.category,
        'status', e.status,
        'brand_name', e.brand_name,
        'type', e.type_name,
        'color', e.color,
        'size', e.size,
        'condition', e.condition,
        'section', e.section,
        'shelf_code', e.shelf_code,
        'box_name', e.box_name,
        'image_url', e.image_url,
        'shipment_id', e.shipment_id,
        'shipment_name', e.shipment_name,
        'held_for_phone', e.held_for_phone,
        'held_for_name', e.held_for_name
      )
      ORDER BY e.created_at DESC
    ),
    '[]'::jsonb
  )
  INTO v_result
  FROM enriched e;

  RETURN COALESCE(v_result, '[]'::jsonb);
END;
$$;

COMMENT ON FUNCTION public.search_thrift_available_stocks_for_sale(BIGINT, TEXT, TEXT, INT) IS
  'POS stock picker: default_sell_price = manual listed else ceil_thrift_retail_price(landed*(1+markup)); hold-aware.';

COMMIT;
