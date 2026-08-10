-- Thrift money-path guards (doc vs impl):
-- A. Soft-delete on thrift_stocks + archive RPC + desk list excludes archived
-- B. Qty-stable compute_thrift_landed_unit_cost (SOLD qty=0 still costs as 1)
-- C. record_thrift_cod_remittance requires COD_PENDING
-- D. create_thrift_sales_invoice: Online name/phone/address + skip archived stock
-- E. get_thrift_shipment_sales_report: thrift_reports/view
-- F. Dashboard stock counts exclude soft-deleted

BEGIN;

-- =========================================================
-- A. Soft-delete columns
-- =========================================================
ALTER TABLE public.thrift_stocks
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS deleted_by TEXT NULL;

CREATE INDEX IF NOT EXISTS thrift_stocks_tenant_deleted_at_idx
  ON public.thrift_stocks (tenant_id, deleted_at)
  WHERE deleted_at IS NULL;

CREATE OR REPLACE FUNCTION public.delete_thrift_stocks(
  p_tenant_id BIGINT,
  p_stock_ids BIGINT[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_blocked BIGINT;
  v_deleted INT;
  v_actor TEXT;
BEGIN
  IF p_stock_ids IS NULL OR cardinality(p_stock_ids) = 0 THEN
    RETURN jsonb_build_object('deleted', 0);
  END IF;

  SELECT si.stock_id
  INTO v_blocked
  FROM public.thrift_sales_invoice_items si
  INNER JOIN public.thrift_sales_invoices inv
    ON inv.id = si.invoice_id
   AND inv.tenant_id = si.tenant_id
  WHERE si.tenant_id = p_tenant_id
    AND si.stock_id = ANY (p_stock_ids)
    AND coalesce(inv.status, 'ACTIVE') = 'ACTIVE'
  LIMIT 1;

  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot delete stock %: it is on an active sales invoice. Return or mark staff mistake first.',
      v_blocked;
  END IF;

  v_actor := COALESCE(NULLIF(trim(public.current_user_email()), ''), 'system');

  UPDATE public.thrift_stocks
  SET
    deleted_at = NOW(),
    deleted_by = v_actor,
    updated_at = NOW()
  WHERE tenant_id = p_tenant_id
    AND id = ANY (p_stock_ids)
    AND deleted_at IS NULL;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_deleted);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_thrift_stocks(BIGINT, BIGINT[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.delete_thrift_stocks(BIGINT, BIGINT[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_thrift_stocks(BIGINT, BIGINT[]) TO service_role;

-- Desk list: hide soft-deleted stocks
CREATE OR REPLACE FUNCTION public.list_thrift_stocks_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_status text default null,
  p_condition text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 20), 1);
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_condition text := nullif(trim(coalesce(p_condition, '')), '');
begin
  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  with filtered as materialized (
    select s.*
    from public.thrift_stocks s
    where s.tenant_id = p_tenant_id
      and s.deleted_at is null
      and (v_status is null or s.status::text = v_status)
      and (v_condition is null or s.condition::text = v_condition)
      and (
        v_search is null
        or s.name ilike '%' || v_search || '%'
        or s.brand_name ilike '%' || v_search || '%'
        or s.barcode ilike '%' || v_search || '%'
      )
  ),
  counts as (
    select count(*)::bigint as total
    from filtered
  ),
  paged as (
    select s.*
    from filtered s
    order by s.created_at desc
    offset (v_page - 1) * v_page_size
    limit v_page_size
  ),
  rows as (
    select
      jsonb_build_object(
        'id', s.id,
        'tenant_id', s.tenant_id,
        'shipment_id', s.shipment_id,
        'box_id', s.box_id,
        'name', s.name,
        'brand_name', s.brand_name,
        'category_id', s.category_id,
        'type_id', s.type_id,
        'section', s.section,
        'shelf_id', s.shelf_id,
        'color', s.color,
        'size', s.size,
        'condition', s.condition,
        'barcode', s.barcode,
        'stock_type', s.stock_type,
        'quantity', s.quantity,
        'product_weight', s.product_weight,
        'extra_weight', s.extra_weight,
        'status', s.status,
        'note', s.note,
        'origin_unit_price', s.origin_unit_price,
        'extra_origin_unit_price', s.extra_origin_unit_price,
        'additional_charges_cost', s.additional_charges_cost,
        'held_for_name', s.held_for_name,
        'held_for_phone', s.held_for_phone,
        'held_for_phone_normalized', s.held_for_phone_normalized,
        'hold_note', s.hold_note,
        'held_by', s.held_by,
        'held_at', s.held_at,
        'hold_expires_at', s.hold_expires_at,
        'inserted_by', s.inserted_by,
        'created_at', s.created_at,
        'updated_at', s.updated_at,
        'pricing', case
          when p.stock_id is not null then jsonb_build_object(
            'cost_of_goods_sold', p.cost_of_goods_sold,
            'target_price', p.target_price,
            'listed_unit_price', p.listed_unit_price,
            'is_listed_price_manual', p.is_listed_price_manual,
            'markup_rate_override', p.markup_rate_override,
            'extra_expense_cost', p.extra_expense_cost
          )
          else '{}'::jsonb
        end,
        'image_url', img.image_url,
        'drive_file_id', img.drive_file_id,
        'measurements', case
          when m.stock_id is not null then jsonb_build_object(
            'stock_id', m.stock_id,
            'tenant_id', m.tenant_id,
            'bust_in', m.bust_in,
            'waist_in', m.waist_in,
            'hips_in', m.hips_in,
            'length_in', m.length_in,
            'shoulder_width_in', m.shoulder_width_in,
            'sleeve_length_in', m.sleeve_length_in,
            'arm_circumference_in', m.arm_circumference_in,
            'hem_width_in', m.hem_width_in,
            'neck_opening_in', m.neck_opening_in,
            'sleeve_type', m.sleeve_type,
            'neckline', m.neckline,
            'dress_style', m.dress_style,
            'fabric_stretch', m.fabric_stretch,
            'lining', m.lining,
            'closure_type', m.closure_type,
            'measurement_notes', m.measurement_notes
          )
          else null
        end
      ) as row_data,
      s.created_at as sort_created_at
    from paged s
    left join public.thrift_pricings p on p.stock_id = s.id
    left join public.thrift_stock_measurements m on m.stock_id = s.id
    left join lateral (
      select i.image_url, i.drive_file_id
      from public.thrift_stock_images i
      where i.stock_id = s.id
        and i.is_primary = true
      limit 1
    ) img on true
  )
  select
    (select total from counts),
    coalesce(
      (select jsonb_agg(r.row_data order by r.sort_created_at desc) from rows r),
      '[]'::jsonb
    )
  into v_total_count, v_data;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

-- =========================================================
-- B. Qty-stable landed unit cost (includes soft-deleted rows by id)
-- =========================================================
CREATE OR REPLACE FUNCTION public.compute_thrift_landed_unit_cost(p_stock_id bigint)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_shipment public.thrift_shipments%ROWTYPE;
  v_settings public.thrift_settings%ROWTYPE;
  v_sum_qty numeric;
  v_u numeric;
  v_total_weight_kg numeric;
  v_line_weight_kg numeric;
  v_costing_qty numeric;
  v_product_unit_cost numeric;
  v_shipment_cargo_cost numeric;
  v_shipment_ops_cost numeric;
  v_cargo_share_per_unit numeric;
  v_ops_share_per_unit numeric;
  v_landed_unit_cost numeric;
BEGIN
  SELECT * INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id;

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  SELECT * INTO v_shipment
  FROM public.thrift_shipments
  WHERE id = v_stock.shipment_id;

  SELECT * INTO v_settings
  FROM public.thrift_settings
  WHERE tenant_id = v_stock.tenant_id;

  -- Costing qty: SOLD with remaining 0 still counts as 1 unit for allocation.
  v_costing_qty := CASE
    WHEN v_stock.status = 'SOLD'::public.thrift_stock_status
         AND COALESCE(v_stock.quantity, 0) = 0 THEN 1::numeric
    ELSE GREATEST(COALESCE(v_stock.quantity, 0), 0)::numeric
  END;

  SELECT COALESCE(SUM(
    CASE
      WHEN s.status = 'SOLD'::public.thrift_stock_status
           AND COALESCE(s.quantity, 0) = 0 THEN 1::numeric
      ELSE GREATEST(COALESCE(s.quantity, 0), 0)::numeric
    END
  ), 0) INTO v_sum_qty
  FROM public.thrift_stocks s
  WHERE s.shipment_id = v_stock.shipment_id;

  v_u := GREATEST(v_sum_qty, 1.0);

  SELECT COALESCE(SUM(
    (
      (COALESCE(s.product_weight, 0.0) + COALESCE(s.extra_weight, 0.0))
      / 1000.0
    ) * CASE
      WHEN s.status = 'SOLD'::public.thrift_stock_status
           AND COALESCE(s.quantity, 0) = 0 THEN 1::numeric
      ELSE GREATEST(COALESCE(s.quantity, 0), 0)::numeric
    END
  ), 0.0) INTO v_total_weight_kg
  FROM public.thrift_stocks s
  WHERE s.shipment_id = v_stock.shipment_id;

  v_line_weight_kg :=
    (COALESCE(v_stock.product_weight, 0.0) + COALESCE(v_stock.extra_weight, 0.0))
    / 1000.0
    * v_costing_qty;

  v_product_unit_cost :=
    (COALESCE(v_stock.origin_unit_price, 0.0) + COALESCE(v_stock.extra_origin_unit_price, 0.0))
    * COALESCE(v_shipment.product_conversion_rate, 1.0);

  v_shipment_cargo_cost :=
    COALESCE(v_shipment.total_cargo_weight_kg, 0.0)
    * COALESCE(v_shipment.cargo_rate, 0.0)
    * COALESCE(v_shipment.cargo_conversion_rate, 0.0);

  v_shipment_ops_cost :=
    (COALESCE(v_settings.hand_tag_unit_cost, 0.0) * v_u)
    + (COALESCE(v_settings.sticker_unit_cost, 0.0) * v_u)
    + COALESCE(v_shipment.labor_total_cost, 0.0)
    + COALESCE(v_shipment.transportation_total_cost, 0.0)
    + COALESCE(v_shipment.washing_total_cost, 0.0);

  IF v_total_weight_kg > 0 AND v_costing_qty > 0 THEN
    v_cargo_share_per_unit :=
      ((v_line_weight_kg / v_total_weight_kg) * v_shipment_cargo_cost)
      / v_costing_qty;
  ELSE
    v_cargo_share_per_unit := v_shipment_cargo_cost / v_u;
  END IF;

  v_ops_share_per_unit := v_shipment_ops_cost / v_u;

  v_landed_unit_cost :=
    v_product_unit_cost
    + v_cargo_share_per_unit
    + v_ops_share_per_unit
    + COALESCE(v_stock.additional_charges_cost, 0.0);

  RETURN COALESCE(v_landed_unit_cost, 0.0);
END;
$$;

-- =========================================================
-- C. Remittance: COD_PENDING only
-- =========================================================
CREATE OR REPLACE FUNCTION public.record_thrift_cod_remittance(
  p_tenant_id BIGINT,
  p_invoice_id BIGINT,
  p_remitted_amount NUMERIC(12,2),
  p_actor TEXT,
  p_remitted_at TIMESTAMPTZ DEFAULT NOW(),
  p_remittance_ref TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_outcome TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_remitted NUMERIC(12,2);
  v_outcome TEXT;
  v_payment_status TEXT;
  v_notes TEXT;
BEGIN
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'edit')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
  ) THEN
    RAISE EXCEPTION 'Recording COD remittance requires thrift_sales edit or create permission';
  END IF;

  v_remitted := ROUND(COALESCE(p_remitted_amount, 0.00), 2);
  IF v_remitted < 0 THEN
    RAISE EXCEPTION 'Remitted amount cannot be negative';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Invoice % is % — remittance only allowed on ACTIVE invoices', p_invoice_id, v_invoice.status;
  END IF;

  IF v_invoice.payment_status IS DISTINCT FROM 'COD_PENDING' THEN
    RAISE EXCEPTION
      'Invoice % payment_status is % — remittance only allowed when COD_PENDING',
      p_invoice_id,
      v_invoice.payment_status;
  END IF;

  v_outcome := upper(trim(COALESCE(p_outcome, '')));
  IF v_outcome = '' THEN
    IF v_invoice.cod_expected IS NULL OR v_remitted >= v_invoice.cod_expected THEN
      v_outcome := 'PAID';
    ELSE
      v_outcome := 'KEEP_PENDING';
    END IF;
  END IF;

  IF v_outcome NOT IN ('PAID', 'KEEP_PENDING', 'WRITTEN_OFF') THEN
    RAISE EXCEPTION 'Invalid outcome % (expected PAID, KEEP_PENDING, or WRITTEN_OFF)', p_outcome;
  END IF;

  IF v_outcome = 'PAID' THEN
    v_payment_status := 'PAID';
  ELSIF v_outcome = 'WRITTEN_OFF' THEN
    v_payment_status := 'WRITTEN_OFF';
  ELSE
    v_payment_status := 'COD_PENDING';
  END IF;

  v_notes := v_invoice.notes;
  IF NULLIF(trim(p_notes), '') IS NOT NULL THEN
    v_notes := CASE
      WHEN NULLIF(trim(v_notes), '') IS NULL THEN trim(p_notes)
      ELSE trim(v_notes) || E'\n' || trim(p_notes)
    END;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    cod_remitted_amount = v_remitted,
    cod_remitted_at = COALESCE(p_remitted_at, NOW()),
    cod_remittance_ref = COALESCE(NULLIF(trim(p_remittance_ref), ''), cod_remittance_ref),
    payment_status = v_payment_status,
    notes = v_notes,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'invoice_id', p_invoice_id,
    'payment_status', v_payment_status,
    'cod_expected', v_invoice.cod_expected,
    'cod_remitted_amount', v_remitted,
    'outcome', v_outcome
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.record_thrift_cod_remittance(
  BIGINT, BIGINT, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.record_thrift_cod_remittance(
  BIGINT, BIGINT, NUMERIC, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT
) TO service_role;

-- =========================================================
-- D. create invoice: Online fields + reject archived stock
-- =========================================================
CREATE OR REPLACE FUNCTION public.create_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_number TEXT DEFAULT NULL,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_date TIMESTAMPTZ DEFAULT NOW(),
  p_payment_method TEXT DEFAULT NULL,
  p_payment_status TEXT DEFAULT NULL,
  p_notes TEXT DEFAULT NULL,
  p_created_by TEXT DEFAULT 'cashier',
  p_total_invoice_amount NUMERIC(12,2) DEFAULT 0.00,
  p_items JSONB DEFAULT '[]'::jsonb,
  p_sale_channel TEXT DEFAULT 'IN_STORE',
  p_customer_address TEXT DEFAULT NULL,
  p_customer_notes TEXT DEFAULT NULL,
  p_courier_amount NUMERIC(12,2) DEFAULT 0.00,
  p_courier_paid_by TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_invoice_id BIGINT;
  v_invoice_number TEXT;
  v_item JSONB;
  v_line JSONB;
  v_prepared_items JSONB := '[]'::jsonb;
  v_stock_id BIGINT;
  v_sell_price NUMERIC(12,2);
  v_discount_amount NUMERIC(12,2);
  v_final_price NUMERIC(12,2);
  v_quantity INT;
  v_total_invoice_amount NUMERIC(12,2) := 0.00;
  v_stock public.thrift_stocks%ROWTYPE;
  v_updated INT;
  v_sale_channel TEXT;
  v_phone_normalized TEXT;
  v_customer_id BIGINT := NULL;
  v_customer_display_name TEXT;
  v_courier_amount NUMERIC(12,2);
  v_courier_paid_by TEXT;
  v_payment_method TEXT;
  v_payment_status TEXT;
  v_cod_expected NUMERIC(12,2) := NULL;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create') THEN
    RAISE EXCEPTION 'Creating a thrift sales invoice requires thrift_sales create permission';
  END IF;

  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, COALESCE(p_date, NOW()));

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
  END IF;

  v_courier_amount := ROUND(COALESCE(p_courier_amount, 0.00), 2);
  v_courier_paid_by := NULLIF(upper(trim(COALESCE(p_courier_paid_by, ''))), '');

  IF v_sale_channel = 'IN_STORE' THEN
    v_courier_amount := 0.00;
    v_courier_paid_by := NULL;
    v_payment_method := COALESCE(NULLIF(trim(p_payment_method), ''), 'CASH');
    v_payment_status := 'PAID';
    v_cod_expected := NULL;
  ELSE
    IF NULLIF(trim(p_customer_name), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires customer name';
    END IF;
    IF NULLIF(trim(p_customer_phone), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires customer phone';
    END IF;
    IF NULLIF(trim(p_customer_address), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires delivery address';
    END IF;

    IF v_courier_amount < 0 THEN
      RAISE EXCEPTION 'Courier amount cannot be negative';
    END IF;

    IF v_courier_amount > 0 THEN
      IF v_courier_paid_by IS NULL OR v_courier_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'courier_paid_by is required when courier_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_courier_paid_by := NULL;
    END IF;

    v_payment_method := COALESCE(NULLIF(trim(p_payment_method), ''), 'COD');
    v_payment_status := COALESCE(NULLIF(upper(trim(p_payment_status)), ''), 'COD_PENDING');
    IF v_payment_status NOT IN ('PAID', 'COD_PENDING', 'UNPAID', 'WRITTEN_OFF', 'REFUNDED') THEN
      RAISE EXCEPTION 'Invalid payment_status: %', v_payment_status;
    END IF;
  END IF;

  v_phone_normalized := public.normalize_thrift_phone(p_customer_phone);
  IF v_phone_normalized <> '' THEN
    v_customer_display_name := COALESCE(NULLIF(trim(p_customer_name), ''), 'Customer');

    INSERT INTO public.thrift_customers (
      tenant_id,
      name,
      phone,
      phone_normalized,
      address,
      notes,
      inserted_by
    ) VALUES (
      p_tenant_id,
      v_customer_display_name,
      COALESCE(NULLIF(trim(p_customer_phone), ''), v_phone_normalized),
      v_phone_normalized,
      p_customer_address,
      p_customer_notes,
      COALESCE(NULLIF(trim(p_created_by), ''), 'cashier')
    )
    ON CONFLICT (tenant_id, phone_normalized) DO UPDATE SET
      phone = EXCLUDED.phone,
      name = CASE
        WHEN NULLIF(trim(p_customer_name), '') IS NOT NULL THEN trim(p_customer_name)
        ELSE public.thrift_customers.name
      END,
      address = CASE
        WHEN p_customer_address IS NOT NULL THEN p_customer_address
        ELSE public.thrift_customers.address
      END,
      notes = CASE
        WHEN p_customer_notes IS NOT NULL THEN p_customer_notes
        ELSE public.thrift_customers.notes
      END,
      updated_at = NOW()
    RETURNING id INTO v_customer_id;
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    v_stock_id := (v_item->>'stock_id')::BIGINT;
    v_sell_price := COALESCE((v_item->>'sell_price')::NUMERIC(12,2), 0.00);
    v_quantity := COALESCE((v_item->>'quantity')::INT, 1);

    IF v_stock_id IS NULL THEN
      RAISE EXCEPTION 'Each line item requires stock_id';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM jsonb_array_elements(v_prepared_items) AS x(line)
      WHERE (x.line->>'stock_id')::BIGINT = v_stock_id
    ) THEN
      RAISE EXCEPTION 'Duplicate stock item % in invoice', v_stock_id;
    END IF;

    IF v_quantity IS NULL OR v_quantity <= 0 THEN
      RAISE EXCEPTION 'Quantity must be positive for stock item %', v_stock_id;
    END IF;

    IF v_sell_price < 0 THEN
      RAISE EXCEPTION 'Sell price cannot be negative for stock item %', v_stock_id;
    END IF;

    v_discount_amount := COALESCE((v_item->>'discount_amount')::NUMERIC(12,2), 0.00);
    v_discount_amount := GREATEST(0.00, LEAST(v_discount_amount, v_sell_price));
    v_final_price := v_sell_price - v_discount_amount;

    SELECT *
    INTO v_stock
    FROM public.thrift_stocks
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
      AND deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Stock item % not found for tenant %', v_stock_id, p_tenant_id;
    END IF;

    IF v_stock.status = 'AVAILABLE'::public.thrift_stock_status THEN
      NULL;
    ELSIF v_stock.status = 'RESERVED'::public.thrift_stock_status THEN
      IF v_phone_normalized = ''
         OR COALESCE(v_stock.held_for_phone_normalized, '') = ''
         OR v_stock.held_for_phone_normalized IS DISTINCT FROM v_phone_normalized
      THEN
        RAISE EXCEPTION
          'Stock item % is on hold; sell requires matching customer phone (same hold) or release first',
          v_stock_id;
      END IF;
    ELSE
      RAISE EXCEPTION
        'Stock item % is not AVAILABLE (status=%)',
        v_stock_id,
        v_stock.status;
    END IF;

    IF COALESCE(v_stock.quantity, 0) < v_quantity THEN
      RAISE EXCEPTION
        'Insufficient quantity for stock item % (have %, need %)',
        v_stock_id,
        COALESCE(v_stock.quantity, 0),
        v_quantity;
    END IF;

    v_prepared_items := v_prepared_items || jsonb_build_array(
      jsonb_build_object(
        'stock_id', v_stock_id,
        'sell_price', v_sell_price,
        'discount_amount', v_discount_amount,
        'final_price', v_final_price,
        'quantity', v_quantity
      )
    );

    v_total_invoice_amount := v_total_invoice_amount + (v_final_price * v_quantity);
  END LOOP;

  IF jsonb_array_length(v_prepared_items) = 0 THEN
    RAISE EXCEPTION 'Invoice requires at least one line item';
  END IF;

  IF v_sale_channel = 'ONLINE' AND v_payment_status = 'COD_PENDING' THEN
    IF v_courier_paid_by = 'CUSTOMER' THEN
      v_cod_expected := ROUND(v_total_invoice_amount + v_courier_amount, 2);
    ELSE
      v_cod_expected := ROUND(v_total_invoice_amount, 2);
    END IF;
  END IF;

  INSERT INTO public.thrift_sales_invoices (
    tenant_id,
    invoice_number,
    customer_name,
    customer_phone,
    customer_address,
    customer_id,
    sale_channel,
    date,
    payment_method,
    payment_status,
    notes,
    created_by,
    total_invoice_amount,
    courier_amount,
    courier_paid_by,
    courier_cod_amount,
    other_expense_amount,
    cod_expected,
    status
  ) VALUES (
    p_tenant_id,
    v_invoice_number,
    p_customer_name,
    p_customer_phone,
    p_customer_address,
    v_customer_id,
    v_sale_channel,
    p_date,
    v_payment_method,
    v_payment_status,
    p_notes,
    p_created_by,
    v_total_invoice_amount,
    v_courier_amount,
    v_courier_paid_by,
    v_courier_amount,
    0.00,
    v_cod_expected,
    'ACTIVE'
  )
  RETURNING id INTO v_invoice_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(v_prepared_items)
  LOOP
    v_stock_id := (v_line->>'stock_id')::BIGINT;
    v_sell_price := (v_line->>'sell_price')::NUMERIC(12,2);
    v_discount_amount := (v_line->>'discount_amount')::NUMERIC(12,2);
    v_final_price := (v_line->>'final_price')::NUMERIC(12,2);
    v_quantity := (v_line->>'quantity')::INT;

    INSERT INTO public.thrift_sales_invoice_items (
      tenant_id,
      invoice_id,
      stock_id,
      sell_price,
      discount_amount,
      final_price,
      landed_unit_cost_at_sale,
      quantity,
      net_profit
    ) VALUES (
      p_tenant_id,
      v_invoice_id,
      v_stock_id,
      v_sell_price,
      v_discount_amount,
      v_final_price,
      0.00,
      v_quantity,
      0.00
    );

    UPDATE public.thrift_stocks
    SET
      quantity = quantity - v_quantity,
      status = 'SOLD'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
      AND deleted_at IS NULL
      AND quantity >= v_quantity
      AND (
        status = 'AVAILABLE'::public.thrift_stock_status
        OR (
          status = 'RESERVED'::public.thrift_stock_status
          AND held_for_phone_normalized IS NOT DISTINCT FROM v_phone_normalized
          AND COALESCE(v_phone_normalized, '') <> ''
        )
      );

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    IF v_updated = 0 THEN
      RAISE EXCEPTION
        'Stock item % became unavailable during sale (tenant %)',
        v_stock_id,
        p_tenant_id;
    END IF;
  END LOOP;

  INSERT INTO public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    note,
    inserted_by,
    date
  ) VALUES (
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    v_total_invoice_amount,
    'Sales Invoice #' || v_invoice_number,
    p_created_by,
    p_date
  );

  IF v_courier_amount > 0 AND v_courier_paid_by = 'SHOP' THEN
    INSERT INTO public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      note,
      inserted_by,
      date
    ) VALUES (
      p_tenant_id,
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_courier_amount,
      'Shop courier for Sales Invoice #' || v_invoice_number,
      p_created_by,
      p_date
    );
  END IF;

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'payment_status', v_payment_status,
    'cod_expected', v_cod_expected,
    'status', 'success'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice(
  BIGINT, TEXT, TEXT, TEXT, TIMESTAMPTZ, TEXT, TEXT, TEXT, TEXT, NUMERIC, JSONB, TEXT, TEXT, TEXT, NUMERIC, TEXT
) TO service_role;

-- =========================================================
-- E. Shipment sales report auth
-- =========================================================
CREATE OR REPLACE FUNCTION public.get_thrift_shipment_sales_report(
  p_tenant_id BIGINT,
  p_shipment_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  v_shipment JSONB;
  v_summary JSONB;
  v_lines JSONB;
  v_units_sold BIGINT := 0;
  v_gross_sales NUMERIC(14, 2) := 0;
  v_discounts NUMERIC(14, 2) := 0;
  v_net_revenue NUMERIC(14, 2) := 0;
  v_cogs NUMERIC(14, 2) := 0;
  v_net_profit NUMERIC(14, 2) := 0;
  v_margin_pct NUMERIC(8, 2) := 0;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift shipment sales report requires thrift_reports view permission';
  END IF;

  SELECT jsonb_build_object(
    'id', s.id,
    'name', s.name,
    'created_at', s.created_at,
    'updated_at', s.updated_at
  )
  INTO v_shipment
  FROM public.thrift_shipments s
  WHERE s.id = p_shipment_id
    AND s.tenant_id = p_tenant_id;

  IF v_shipment IS NULL THEN
    RAISE EXCEPTION 'Shipment % not found for tenant %', p_shipment_id, p_tenant_id;
  END IF;

  SELECT
    COALESCE(SUM(i.quantity), 0),
    COALESCE(SUM(i.sell_price * i.quantity), 0),
    COALESCE(SUM(i.discount_amount * i.quantity), 0),
    COALESCE(SUM(i.final_price * i.quantity), 0),
    COALESCE(
      SUM(
        ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        * i.quantity
      ),
      0
    ),
    COALESCE(
      SUM(
        (
          i.final_price
          - ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        ) * i.quantity
      ),
      0
    )
  INTO
    v_units_sold,
    v_gross_sales,
    v_discounts,
    v_net_revenue,
    v_cogs,
    v_net_profit
  FROM public.thrift_sales_invoice_items i
  INNER JOIN public.thrift_stocks st
    ON st.id = i.stock_id
   AND st.tenant_id = i.tenant_id
  INNER JOIN public.thrift_sales_invoices inv
    ON inv.id = i.invoice_id
   AND inv.tenant_id = i.tenant_id
  WHERE i.tenant_id = p_tenant_id
    AND st.shipment_id = p_shipment_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE';

  IF v_net_revenue > 0 THEN
    v_margin_pct := ROUND((v_net_profit / v_net_revenue) * 100, 2);
  ELSE
    v_margin_pct := 0;
  END IF;

  v_summary := jsonb_build_object(
    'units_sold', v_units_sold,
    'gross_sales', v_gross_sales,
    'discounts', v_discounts,
    'net_revenue', v_net_revenue,
    'cogs', v_cogs,
    'net_profit', v_net_profit,
    'margin_pct', v_margin_pct
  );

  SELECT COALESCE(jsonb_agg(row_to_json(r)::jsonb ORDER BY r.invoice_date DESC, r.id), '[]'::jsonb)
  INTO v_lines
  FROM (
    SELECT
      i.id,
      i.invoice_id,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.stock_id,
      st.name AS stock_name,
      st.barcode,
      i.quantity,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        AS landed_unit_cost_at_sale,
      (
        (
          i.final_price
          - ROUND(COALESCE(public.compute_thrift_landed_unit_cost(i.stock_id), 0.00), 2)
        ) * i.quantity
      ) AS net_profit
    FROM public.thrift_sales_invoice_items i
    INNER JOIN public.thrift_stocks st
      ON st.id = i.stock_id
     AND st.tenant_id = i.tenant_id
    INNER JOIN public.thrift_sales_invoices inv
      ON inv.id = i.invoice_id
     AND inv.tenant_id = i.tenant_id
    WHERE i.tenant_id = p_tenant_id
      AND st.shipment_id = p_shipment_id
      AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
  ) r;

  RETURN jsonb_build_object(
    'shipment', v_shipment,
    'summary', v_summary,
    'lines', v_lines
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_thrift_shipment_sales_report(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_shipment_sales_report(BIGINT, BIGINT) TO service_role;

-- =========================================================
-- F. Dashboard metrics exclude soft-deleted stocks
-- =========================================================
CREATE OR REPLACE FUNCTION public.get_thrift_dashboard_metrics(p_tenant_id BIGINT)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_items_added_today BIGINT;
  v_total_items BIGINT;
  v_available_items BIGINT;
  v_sold_items BIGINT;
  v_cod_pending_count BIGINT;
  v_cod_expected_total NUMERIC(14,2);
  v_active_invoices_today BIGINT;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift dashboard metrics require thrift_reports view permission';
  END IF;

  SELECT COUNT(*)
  INTO v_items_added_today
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND created_at >= date_trunc('day', NOW());

  SELECT COUNT(*)
  INTO v_total_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL;

  SELECT COUNT(*)
  INTO v_available_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND status = 'AVAILABLE'::public.thrift_stock_status;

  SELECT COUNT(*)
  INTO v_sold_items
  FROM public.thrift_stocks
  WHERE tenant_id = p_tenant_id
    AND deleted_at IS NULL
    AND status = 'SOLD'::public.thrift_stock_status;

  SELECT
    COUNT(*)::BIGINT,
    COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2)
  INTO v_cod_pending_count, v_cod_expected_total
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.payment_status = 'COD_PENDING';

  SELECT COUNT(*)
  INTO v_active_invoices_today
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') = 'ACTIVE'
    AND inv.date >= date_trunc('day', NOW());

  RETURN jsonb_build_object(
    'items_added_today', v_items_added_today,
    'total_items', v_total_items,
    'available_items', v_available_items,
    'sold_items', v_sold_items,
    'cod_pending_count', v_cod_pending_count,
    'cod_expected_total', v_cod_expected_total,
    'active_invoices_today', v_active_invoices_today
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_thrift_dashboard_metrics(BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_thrift_dashboard_metrics(BIGINT) TO service_role;

COMMIT;
