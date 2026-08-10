-- Phase 24: Stock holds (RESERVED) — additive cols, hold/release RPCs, sell convert, list fields
-- Prerequisite: 20270802000029_thrift_stock_status_reserved.sql

BEGIN;

-- =========================================================
-- 1. Hold metadata on thrift_stocks (nullable; existing rows unchanged)
-- =========================================================
ALTER TABLE public.thrift_stocks
  ADD COLUMN IF NOT EXISTS held_for_name TEXT NULL,
  ADD COLUMN IF NOT EXISTS held_for_phone TEXT NULL,
  ADD COLUMN IF NOT EXISTS held_for_phone_normalized TEXT NULL,
  ADD COLUMN IF NOT EXISTS hold_note TEXT NULL,
  ADD COLUMN IF NOT EXISTS held_by TEXT NULL,
  ADD COLUMN IF NOT EXISTS held_at TIMESTAMPTZ NULL,
  ADD COLUMN IF NOT EXISTS hold_expires_at TIMESTAMPTZ NULL;

COMMENT ON COLUMN public.thrift_stocks.held_for_phone_normalized IS
  'Digits-only hold key (normalize_thrift_phone). Required when status=RESERVED; sale convert requires invoice phone match.';
COMMENT ON COLUMN public.thrift_stocks.hold_expires_at IS
  'Optional advisory expiry (v1). No auto-release job.';

CREATE INDEX IF NOT EXISTS thrift_stocks_tenant_reserved_phone_idx
  ON public.thrift_stocks (tenant_id, held_for_phone_normalized)
  WHERE status = 'RESERVED'::public.thrift_stock_status;

-- =========================================================
-- 2. Guard: RESERVED requires phone; leaving RESERVED clears hold cols
-- =========================================================
CREATE OR REPLACE FUNCTION public.thrift_stocks_enforce_hold_metadata()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.status = 'RESERVED'::public.thrift_stock_status THEN
    IF COALESCE(NEW.held_for_phone_normalized, '') = '' THEN
      RAISE EXCEPTION 'RESERVED stock requires held_for_phone_normalized';
    END IF;
    NEW.held_for_phone_normalized := public.normalize_thrift_phone(
      COALESCE(NEW.held_for_phone_normalized, NEW.held_for_phone)
    );
    IF COALESCE(NEW.held_for_phone_normalized, '') = '' THEN
      RAISE EXCEPTION 'RESERVED stock requires a non-empty customer phone';
    END IF;
    IF NEW.held_at IS NULL THEN
      NEW.held_at := NOW();
    END IF;
  ELSIF TG_OP = 'UPDATE'
    AND OLD.status = 'RESERVED'::public.thrift_stock_status
  THEN
    NEW.held_for_name := NULL;
    NEW.held_for_phone := NULL;
    NEW.held_for_phone_normalized := NULL;
    NEW.hold_note := NULL;
    NEW.held_by := NULL;
    NEW.held_at := NULL;
    NEW.hold_expires_at := NULL;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS thrift_stocks_enforce_hold_metadata_trg ON public.thrift_stocks;
CREATE TRIGGER thrift_stocks_enforce_hold_metadata_trg
  BEFORE INSERT OR UPDATE OF status, held_for_phone, held_for_phone_normalized, held_at
  ON public.thrift_stocks
  FOR EACH ROW
  EXECUTE FUNCTION public.thrift_stocks_enforce_hold_metadata();

-- =========================================================
-- 3. hold_thrift_stock
-- =========================================================
CREATE OR REPLACE FUNCTION public.hold_thrift_stock(
  p_tenant_id BIGINT,
  p_stock_id BIGINT,
  p_held_for_phone TEXT,
  p_held_for_name TEXT DEFAULT NULL,
  p_hold_note TEXT DEFAULT NULL,
  p_held_by TEXT DEFAULT NULL,
  p_hold_expires_at TIMESTAMPTZ DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_phone_normalized TEXT;
  v_updated INT;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  v_phone_normalized := public.normalize_thrift_phone(p_held_for_phone);
  IF v_phone_normalized = '' THEN
    RAISE EXCEPTION 'Hold requires a customer phone';
  END IF;

  SELECT *
  INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock item % not found for tenant %', p_stock_id, p_tenant_id;
  END IF;

  IF v_stock.status IS DISTINCT FROM 'AVAILABLE'::public.thrift_stock_status THEN
    RAISE EXCEPTION
      'Stock item % cannot be held (status=%); only AVAILABLE units can be held',
      p_stock_id,
      v_stock.status;
  END IF;

  UPDATE public.thrift_stocks
  SET
    status = 'RESERVED'::public.thrift_stock_status,
    held_for_name = NULLIF(trim(p_held_for_name), ''),
    held_for_phone = COALESCE(NULLIF(trim(p_held_for_phone), ''), v_phone_normalized),
    held_for_phone_normalized = v_phone_normalized,
    hold_note = NULLIF(trim(p_hold_note), ''),
    held_by = COALESCE(NULLIF(trim(p_held_by), ''), public.current_user_email()),
    held_at = NOW(),
    hold_expires_at = p_hold_expires_at,
    updated_at = NOW()
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
    AND status = 'AVAILABLE'::public.thrift_stock_status;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'Stock item % became unavailable during hold', p_stock_id;
  END IF;

  RETURN jsonb_build_object(
    'id', p_stock_id,
    'status', 'RESERVED',
    'held_for_phone_normalized', v_phone_normalized
  );
END;
$$;

COMMENT ON FUNCTION public.hold_thrift_stock(
  BIGINT, BIGINT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) IS 'Place AVAILABLE thrift stock on RESERVED hold for a customer phone (FB/online).';

REVOKE ALL ON FUNCTION public.hold_thrift_stock(
  BIGINT, BIGINT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.hold_thrift_stock(
  BIGINT, BIGINT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.hold_thrift_stock(
  BIGINT, BIGINT, TEXT, TEXT, TEXT, TEXT, TIMESTAMPTZ
) TO service_role;

-- =========================================================
-- 4. release_thrift_stock_hold
-- =========================================================
CREATE OR REPLACE FUNCTION public.release_thrift_stock_hold(
  p_tenant_id BIGINT,
  p_stock_id BIGINT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_updated INT;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  SELECT *
  INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock item % not found for tenant %', p_stock_id, p_tenant_id;
  END IF;

  IF v_stock.status IS DISTINCT FROM 'RESERVED'::public.thrift_stock_status THEN
    RAISE EXCEPTION
      'Stock item % is not on hold (status=%)',
      p_stock_id,
      v_stock.status;
  END IF;

  UPDATE public.thrift_stocks
  SET
    status = 'AVAILABLE'::public.thrift_stock_status,
    updated_at = NOW()
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
    AND status = 'RESERVED'::public.thrift_stock_status;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'Stock item % hold could not be released', p_stock_id;
  END IF;

  RETURN jsonb_build_object(
    'id', p_stock_id,
    'status', 'AVAILABLE'
  );
END;
$$;

COMMENT ON FUNCTION public.release_thrift_stock_hold(BIGINT, BIGINT) IS
  'Release RESERVED thrift stock back to AVAILABLE; clears hold metadata via trigger.';

REVOKE ALL ON FUNCTION public.release_thrift_stock_hold(BIGINT, BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.release_thrift_stock_hold(BIGINT, BIGINT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.release_thrift_stock_hold(BIGINT, BIGINT) TO service_role;

-- =========================================================
-- 5. bulk_update_thrift_stock_statuses — block RESERVED (use hold RPC)
-- =========================================================
CREATE OR REPLACE FUNCTION public.bulk_update_thrift_stock_statuses(
  p_tenant_id bigint,
  p_stock_ids bigint[],
  p_status text
) RETURNS void
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF upper(trim(coalesce(p_status, ''))) = 'RESERVED' THEN
    RAISE EXCEPTION 'Use hold_thrift_stock to place holds (RESERVED)';
  END IF;

  UPDATE public.thrift_stocks
  SET status = p_status::public.thrift_stock_status,
      updated_at = now()
  WHERE tenant_id = p_tenant_id
    AND id = ANY(p_stock_ids);
END;
$$;

-- =========================================================
-- 6. create_thrift_sales_invoice — AVAILABLE or matching RESERVED hold
-- =========================================================
CREATE OR REPLACE FUNCTION public.create_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_number TEXT DEFAULT NULL,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_date TIMESTAMPTZ DEFAULT NOW(),
  p_payment_method TEXT DEFAULT 'CASH',
  p_payment_status TEXT DEFAULT 'PAID',
  p_notes TEXT DEFAULT NULL,
  p_created_by TEXT DEFAULT 'cashier',
  p_total_invoice_amount NUMERIC(12,2) DEFAULT 0.00,
  p_items JSONB DEFAULT '[]'::jsonb,
  p_sale_channel TEXT DEFAULT 'IN_STORE',
  p_customer_address TEXT DEFAULT NULL,
  p_customer_notes TEXT DEFAULT NULL
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
  v_landed_unit_cost NUMERIC(12,2);
  v_quantity INT;
  v_net_profit NUMERIC(12,2);
  v_total_invoice_amount NUMERIC(12,2) := 0.00;
  v_stock public.thrift_stocks%ROWTYPE;
  v_updated INT;
  v_sale_channel TEXT;
  v_phone_normalized TEXT;
  v_customer_id BIGINT := NULL;
  v_customer_display_name TEXT;
BEGIN
  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, COALESCE(p_date, NOW()));

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
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

    v_landed_unit_cost := ROUND(
      COALESCE(public.compute_thrift_landed_unit_cost(v_stock_id), 0.00),
      2
    )::NUMERIC(12,2);
    v_net_profit := (v_final_price - v_landed_unit_cost) * v_quantity;

    v_prepared_items := v_prepared_items || jsonb_build_array(
      jsonb_build_object(
        'stock_id', v_stock_id,
        'sell_price', v_sell_price,
        'discount_amount', v_discount_amount,
        'final_price', v_final_price,
        'landed_unit_cost', v_landed_unit_cost,
        'quantity', v_quantity,
        'net_profit', v_net_profit
      )
    );

    v_total_invoice_amount := v_total_invoice_amount + (v_final_price * v_quantity);
  END LOOP;

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
    p_payment_method,
    p_payment_status,
    p_notes,
    p_created_by,
    v_total_invoice_amount,
    'ACTIVE'
  )
  RETURNING id INTO v_invoice_id;

  FOR v_line IN SELECT * FROM jsonb_array_elements(v_prepared_items)
  LOOP
    v_stock_id := (v_line->>'stock_id')::BIGINT;
    v_sell_price := (v_line->>'sell_price')::NUMERIC(12,2);
    v_discount_amount := (v_line->>'discount_amount')::NUMERIC(12,2);
    v_final_price := (v_line->>'final_price')::NUMERIC(12,2);
    v_landed_unit_cost := (v_line->>'landed_unit_cost')::NUMERIC(12,2);
    v_quantity := (v_line->>'quantity')::INT;
    v_net_profit := (v_line->>'net_profit')::NUMERIC(12,2);

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
      v_landed_unit_cost,
      v_quantity,
      v_net_profit
    );

    UPDATE public.thrift_stocks
    SET
      quantity = quantity - v_quantity,
      status = 'SOLD'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_stock_id
      AND tenant_id = p_tenant_id
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

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'success'
  );
END;
$$;

-- =========================================================
-- 7. list_thrift_stocks_paginated — include hold fields
-- =========================================================
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

COMMIT;
