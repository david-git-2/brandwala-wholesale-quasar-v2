-- Thrift domain rpcs (extracted from public.sql)

CREATE OR REPLACE FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint DEFAULT NULL::bigint, "p_box_id" bigint DEFAULT NULL::bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
BEGIN
  UPDATE thrift_stocks
  SET shelf_id = p_shelf_id, box_id = p_box_id, updated_at = now()
  WHERE tenant_id = p_tenant_id AND id = ANY(p_stock_ids);
END; $$;

ALTER FUNCTION "public"."bulk_update_thrift_stock_locations"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_shelf_id" bigint, "p_box_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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

ALTER FUNCTION "public"."bulk_update_thrift_stock_statuses"("p_tenant_id" bigint, "p_stock_ids" bigint[], "p_status" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."calculate_thrift_invoice_total"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_invoice_id bigint;
begin
  if tg_op = 'DELETE' then
    v_invoice_id := old.invoice_id;
  else
    v_invoice_id := new.invoice_id;
  end if;

  update public.thrift_invoices
  set total_invoice_amount = coalesce((
    select sum(sold_price * quantity)
    from public.thrift_invoice_items
    where invoice_id = v_invoice_id
  ), 0.00) 
  + cod_charge 
  + packing_charge 
  + invoice_print_charge 
  + shipping_charge_customer
  where id = v_invoice_id;

  return null;
end;
$$;

ALTER FUNCTION "public"."calculate_thrift_invoice_total"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."calculate_thrift_item_net_profit"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_landed numeric(12, 2);
begin
  if tg_op = 'INSERT' or new.landed_unit_cost_at_sale is null or new.landed_unit_cost_at_sale = 0 then
    v_landed := coalesce(public.compute_thrift_landed_unit_cost(new.stock_id), 0.00);
    new.landed_unit_cost_at_sale := v_landed;
  else
    v_landed := new.landed_unit_cost_at_sale;
  end if;

  new.net_profit := (new.sold_price - v_landed) * new.quantity
                    - new.platform_fees
                    - new.shipping_cost_paid_by_shop;

  return new;
end;
$$;

ALTER FUNCTION "public"."calculate_thrift_item_net_profit"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE PARALLEL SAFE
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

ALTER FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."ceil_thrift_retail_price"("p_price" numeric) IS 'Ceil to next thrift retail ending (.50 / .90); matches web ceilThriftRetailPrice.';

CREATE OR REPLACE FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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

ALTER FUNCTION "public"."compute_thrift_landed_unit_cost"("p_stock_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text" DEFAULT NULL::"text", "p_customer_name" "text" DEFAULT NULL::"text", "p_customer_phone" "text" DEFAULT NULL::"text", "p_date" timestamp with time zone DEFAULT "now"(), "p_payment_method" "text" DEFAULT NULL::"text", "p_payment_status" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text", "p_created_by" "text" DEFAULT 'cashier'::"text", "p_total_invoice_amount" numeric DEFAULT 0.00, "p_items" "jsonb" DEFAULT '[]'::"jsonb", "p_sale_channel" "text" DEFAULT 'IN_STORE'::"text", "p_customer_address" "text" DEFAULT NULL::"text", "p_customer_notes" "text" DEFAULT NULL::"text", "p_courier_amount" numeric DEFAULT 0.00, "p_courier_paid_by" "text" DEFAULT NULL::"text", "p_packing_amount" numeric DEFAULT 0.00, "p_packing_paid_by" "text" DEFAULT NULL::"text", "p_cod_fee_amount" numeric DEFAULT 0.00, "p_cod_fee_paid_by" "text" DEFAULT NULL::"text", "p_courier_provider" "text" DEFAULT NULL::"text", "p_courier_provider_id" bigint DEFAULT NULL::bigint, "p_meta" "jsonb" DEFAULT '{}'::"jsonb", "p_customer_secondary_phone" "text" DEFAULT NULL::"text", "p_customer_address_parts" "jsonb" DEFAULT '{}'::"jsonb", "p_advance_amount" numeric DEFAULT 0.00, "p_advance_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
  v_packing_amount NUMERIC(12,2);
  v_packing_paid_by TEXT;
  v_cod_fee_amount NUMERIC(12,2);
  v_cod_fee_paid_by TEXT;
  v_courier_provider TEXT;
  v_courier_provider_id BIGINT := NULL;
  v_meta JSONB := '{}'::jsonb;
  v_address_parts JSONB := '{}'::jsonb;
  v_secondary_phone TEXT;
  v_provider public.thrift_courier_providers%ROWTYPE;
  v_payment_method TEXT;
  v_payment_status TEXT;
  v_cod_expected NUMERIC(12,2) := NULL;
  v_delivery_status TEXT := NULL;
  v_economics_closed_at TIMESTAMPTZ := NULL;
  v_event_at TIMESTAMPTZ;
  v_invoice_item_id BIGINT;
  v_inbound_shipment_id BIGINT;
  v_sell_amount NUMERIC(12,2);
  v_advance_amount NUMERIC(12,2);
  v_advance_note TEXT;
  v_gross_cod NUMERIC(12,2);
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create') THEN
    RAISE EXCEPTION 'Creating a thrift sales invoice requires thrift_sales create permission';
  END IF;

  v_event_at := COALESCE(p_date, NOW());
  v_invoice_number := public.generate_thrift_invoice_number(p_tenant_id, v_event_at);

  v_sale_channel := COALESCE(NULLIF(trim(p_sale_channel), ''), 'IN_STORE');
  IF v_sale_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE or ONLINE)', v_sale_channel;
  END IF;

  v_courier_amount := ROUND(COALESCE(p_courier_amount, 0.00), 2);
  v_courier_paid_by := NULLIF(upper(trim(COALESCE(p_courier_paid_by, ''))), '');
  v_packing_amount := ROUND(COALESCE(p_packing_amount, 0.00), 2);
  v_packing_paid_by := NULLIF(upper(trim(COALESCE(p_packing_paid_by, ''))), '');
  v_cod_fee_amount := ROUND(COALESCE(p_cod_fee_amount, 0.00), 2);
  v_cod_fee_paid_by := NULLIF(upper(trim(COALESCE(p_cod_fee_paid_by, ''))), '');
  v_courier_provider := NULLIF(trim(COALESCE(p_courier_provider, '')), '');
  v_courier_provider_id := p_courier_provider_id;
  v_meta := COALESCE(p_meta, '{}'::jsonb);
  IF jsonb_typeof(v_meta) <> 'object' THEN
    RAISE EXCEPTION 'p_meta must be a JSON object';
  END IF;

  v_advance_amount := ROUND(COALESCE(p_advance_amount, 0.00), 2);
  v_advance_note := NULLIF(trim(COALESCE(p_advance_note, '')), '');
  IF v_advance_amount < 0 THEN
    RAISE EXCEPTION 'Advance amount cannot be negative';
  END IF;

  v_address_parts := COALESCE(p_customer_address_parts, '{}'::jsonb);
  IF jsonb_typeof(v_address_parts) <> 'object' THEN
    RAISE EXCEPTION 'p_customer_address_parts must be a JSON object';
  END IF;
  -- Keep only known keys
  v_address_parts := jsonb_strip_nulls(
    jsonb_build_object(
      'district', NULLIF(trim(COALESCE(v_address_parts->>'district', '')), ''),
      'thana', NULLIF(trim(COALESCE(v_address_parts->>'thana', '')), ''),
      'post_code', NULLIF(trim(COALESCE(v_address_parts->>'post_code', '')), '')
    )
  );

  v_secondary_phone := NULLIF(trim(COALESCE(p_customer_secondary_phone, '')), '');

  IF NULLIF(trim(p_customer_name), '') IS NULL THEN
    RAISE EXCEPTION 'Customer name is required';
  END IF;
  IF NULLIF(trim(p_customer_phone), '') IS NULL THEN
    RAISE EXCEPTION 'Customer phone is required';
  END IF;

  IF v_sale_channel = 'IN_STORE' THEN
    IF v_advance_amount <> 0 THEN
      RAISE EXCEPTION 'Advance is only allowed for online COD sales';
    END IF;
    v_advance_amount := 0.00;
    v_advance_note := NULL;
    v_courier_amount := 0.00;
    v_courier_paid_by := NULL;
    v_packing_amount := 0.00;
    v_packing_paid_by := NULL;
    v_cod_fee_amount := 0.00;
    v_cod_fee_paid_by := NULL;
    v_courier_provider := NULL;
    v_courier_provider_id := NULL;
    v_meta := '{}'::jsonb;
    v_payment_method := 'CASH';
    v_payment_status := 'PAID';
    v_cod_expected := NULL;
    v_delivery_status := NULL;
    v_economics_closed_at := v_event_at;
  ELSE
    IF NULLIF(trim(p_customer_address), '') IS NULL THEN
      RAISE EXCEPTION 'Online sale requires delivery address';
    END IF;
    IF COALESCE(v_address_parts->>'district', '') = '' THEN
      RAISE EXCEPTION 'Online sale requires district';
    END IF;
    IF COALESCE(v_address_parts->>'thana', '') = '' THEN
      RAISE EXCEPTION 'Online sale requires thana / upazila';
    END IF;

    IF v_courier_amount < 0 OR v_packing_amount < 0 OR v_cod_fee_amount < 0 THEN
      RAISE EXCEPTION 'Fee amounts cannot be negative';
    END IF;

    IF v_courier_amount > 0 THEN
      IF v_courier_paid_by IS NULL OR v_courier_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'courier_paid_by is required when courier_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_courier_paid_by := NULL;
    END IF;

    IF v_packing_amount > 0 THEN
      IF v_packing_paid_by IS NULL OR v_packing_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'packing_paid_by is required when packing_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_packing_paid_by := NULL;
    END IF;

    IF v_cod_fee_amount > 0 THEN
      IF v_cod_fee_paid_by IS NULL OR v_cod_fee_paid_by NOT IN ('CUSTOMER', 'SHOP') THEN
        RAISE EXCEPTION 'cod_fee_paid_by is required when cod_fee_amount > 0 (CUSTOMER or SHOP)';
      END IF;
    ELSE
      v_cod_fee_paid_by := NULL;
    END IF;

    IF v_courier_provider_id IS NOT NULL THEN
      SELECT * INTO v_provider
      FROM public.thrift_courier_providers
      WHERE id = v_courier_provider_id
        AND is_active = TRUE
        AND (
          (is_system = TRUE AND tenant_id IS NULL)
          OR (is_system = FALSE AND tenant_id = p_tenant_id)
        );

      IF NOT FOUND THEN
        RAISE EXCEPTION 'Courier provider % is not available for this tenant', v_courier_provider_id;
      END IF;

      v_courier_provider := COALESCE(v_courier_provider, v_provider.name);
    END IF;

    v_payment_method := 'COD';
    v_payment_status := 'COD_PENDING';
    v_delivery_status := 'PENDING';
    v_economics_closed_at := NULL;
  END IF;

  v_phone_normalized := public.normalize_thrift_phone(p_customer_phone);
  IF v_phone_normalized = '' THEN
    RAISE EXCEPTION 'Customer phone is required';
  END IF;

  v_customer_display_name := trim(p_customer_name);

  INSERT INTO public.thrift_customers (
    tenant_id,
    name,
    phone,
    phone_normalized,
    secondary_phone,
    address,
    address_parts,
    notes,
    inserted_by
  ) VALUES (
    p_tenant_id,
    v_customer_display_name,
    COALESCE(NULLIF(trim(p_customer_phone), ''), v_phone_normalized),
    v_phone_normalized,
    v_secondary_phone,
    p_customer_address,
    v_address_parts,
    p_customer_notes,
    COALESCE(NULLIF(trim(p_created_by), ''), 'cashier')
  )
  ON CONFLICT (tenant_id, phone_normalized) DO UPDATE SET
    phone = EXCLUDED.phone,
    name = EXCLUDED.name,
    secondary_phone = CASE
      WHEN p_customer_secondary_phone IS NOT NULL THEN v_secondary_phone
      ELSE public.thrift_customers.secondary_phone
    END,
    address = CASE
      WHEN p_customer_address IS NOT NULL THEN p_customer_address
      ELSE public.thrift_customers.address
    END,
    address_parts = CASE
      WHEN p_customer_address_parts IS NOT NULL AND v_address_parts <> '{}'::jsonb
        THEN v_address_parts
      WHEN p_customer_address_parts IS NOT NULL AND v_sale_channel = 'ONLINE'
        THEN v_address_parts
      ELSE public.thrift_customers.address_parts
    END,
    notes = CASE
      WHEN p_customer_notes IS NOT NULL THEN p_customer_notes
      ELSE public.thrift_customers.notes
    END,
    updated_at = NOW()
  RETURNING id INTO v_customer_id;

  FOR v_item IN SELECT * FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    v_stock_id := NULLIF(trim(COALESCE(v_item->>'stock_id', '')), '')::BIGINT;
    IF v_stock_id IS NULL THEN
      RAISE EXCEPTION 'Each invoice item requires stock_id';
    END IF;

    v_sell_price := ROUND(COALESCE((v_item->>'sell_price')::NUMERIC, 0.00), 2);
    v_discount_amount := ROUND(COALESCE((v_item->>'discount_amount')::NUMERIC, 0.00), 2);
    v_quantity := GREATEST(COALESCE((v_item->>'quantity')::INT, 1), 1);
    v_final_price := ROUND(GREATEST(v_sell_price - v_discount_amount, 0.00), 2);

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

    IF v_stock.shipment_id IS NULL THEN
      RAISE EXCEPTION 'Stock item % has no inbound shipment; cannot create sales PnL later', v_stock_id;
    END IF;

    IF v_stock.status = 'AVAILABLE'::public.thrift_stock_status THEN
      NULL;
    ELSIF v_stock.status = 'RESERVED'::public.thrift_stock_status THEN
      IF COALESCE(v_stock.held_for_phone_normalized, '') = ''
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
        'quantity', v_quantity,
        'inbound_shipment_id', v_stock.shipment_id
      )
    );

    v_total_invoice_amount := v_total_invoice_amount + (v_final_price * v_quantity);
  END LOOP;

  IF jsonb_array_length(v_prepared_items) = 0 THEN
    RAISE EXCEPTION 'Invoice requires at least one line item';
  END IF;

  IF v_sale_channel = 'ONLINE' THEN
    v_gross_cod := ROUND(
      v_total_invoice_amount
      + CASE WHEN v_courier_paid_by = 'CUSTOMER' THEN v_courier_amount ELSE 0.00 END
      + CASE WHEN v_cod_fee_paid_by = 'CUSTOMER' THEN v_cod_fee_amount ELSE 0.00 END
      + CASE WHEN v_packing_paid_by = 'CUSTOMER' THEN v_packing_amount ELSE 0.00 END,
      2
    );
    v_cod_expected := GREATEST(0.00, ROUND(v_gross_cod - v_advance_amount, 2));
  END IF;

  INSERT INTO public.thrift_sales_invoices (
    tenant_id,
    invoice_number,
    customer_name,
    customer_phone,
    customer_secondary_phone,
    customer_address,
    customer_address_parts,
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
    courier_provider,
    courier_provider_id,
    packing_amount,
    packing_paid_by,
    cod_fee_amount,
    cod_fee_paid_by,
    return_courier_amount,
    other_expense_amount,
    advance_amount,
    advance_note,
    cod_expected,
    delivery_status,
    economics_closed_at,
    meta,
    status
  ) VALUES (
    p_tenant_id,
    v_invoice_number,
    p_customer_name,
    p_customer_phone,
    v_secondary_phone,
    p_customer_address,
    v_address_parts,
    v_customer_id,
    v_sale_channel,
    v_event_at,
    v_payment_method,
    v_payment_status,
    p_notes,
    p_created_by,
    v_total_invoice_amount,
    v_courier_amount,
    v_courier_paid_by,
    v_courier_amount,
    v_courier_provider,
    v_courier_provider_id,
    v_packing_amount,
    v_packing_paid_by,
    v_cod_fee_amount,
    v_cod_fee_paid_by,
    0.00,
    0.00,
    v_advance_amount,
    v_advance_note,
    v_cod_expected,
    v_delivery_status,
    v_economics_closed_at,
    v_meta,
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
    v_inbound_shipment_id := (v_line->>'inbound_shipment_id')::BIGINT;
    v_sell_amount := ROUND(v_final_price * v_quantity, 2);

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
    )
    RETURNING id INTO v_invoice_item_id;

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

    IF v_sale_channel = 'IN_STORE' THEN
      INSERT INTO public.thrift_sales_pnl_lines (
        tenant_id,
        invoice_id,
        invoice_item_id,
        stock_id,
        inbound_shipment_id,
        outcome,
        return_id,
        quantity,
        sell_amount,
        allocated_shop_delivery,
        allocated_shop_cod_fee,
        allocated_shop_packing,
        allocated_return_courier,
        allocated_fees_total,
        cogs_is_loss,
        event_at,
        event_date
      ) VALUES (
        p_tenant_id,
        v_invoice_id,
        v_invoice_item_id,
        v_stock_id,
        v_inbound_shipment_id,
        'DELIVERED',
        NULL,
        v_quantity,
        v_sell_amount,
        0.00,
        0.00,
        0.00,
        0.00,
        0.00,
        FALSE,
        v_event_at,
        (v_event_at AT TIME ZONE 'UTC')::DATE
      );
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
    'item_revenue',
    p_created_by,
    v_event_at
  );

  IF v_sale_channel = 'ONLINE' AND v_courier_amount > 0 AND v_courier_paid_by = 'SHOP' THEN
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
      'shop_delivery',
      p_created_by,
      v_event_at
    );
  END IF;

  IF v_sale_channel = 'ONLINE' AND v_packing_amount > 0 AND v_packing_paid_by = 'SHOP' THEN
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
      v_packing_amount,
      'shop_packing',
      p_created_by,
      v_event_at
    );
  END IF;

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', v_invoice_number,
    'payment_status', v_payment_status,
    'sale_channel', v_sale_channel,
    'cod_expected', v_cod_expected,
    'advance_amount', v_advance_amount,
    'delivery_status', v_delivery_status,
    'economics_closed_at', v_economics_closed_at,
    'status', 'success'
  );
END;
$$;

ALTER FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."create_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_number" "text", "p_customer_name" "text", "p_customer_phone" "text", "p_date" timestamp with time zone, "p_payment_method" "text", "p_payment_status" "text", "p_notes" "text", "p_created_by" "text", "p_total_invoice_amount" numeric, "p_items" "jsonb", "p_sale_channel" "text", "p_customer_address" "text", "p_customer_notes" "text", "p_courier_amount" numeric, "p_courier_paid_by" "text", "p_packing_amount" numeric, "p_packing_paid_by" "text", "p_cod_fee_amount" numeric, "p_cod_fee_paid_by" "text", "p_courier_provider" "text", "p_courier_provider_id" bigint, "p_meta" "jsonb", "p_customer_secondary_phone" "text", "p_customer_address_parts" "jsonb", "p_advance_amount" numeric, "p_advance_note" "text") IS 'Create thrift sales invoice. Online COD: optional advance_amount reduces cod_expected (floor 0). IN_STORE rejects non-zero advance. PnL sell lines unchanged.';

CREATE OR REPLACE FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric DEFAULT 0.00, "p_notes" "text" DEFAULT NULL::"text", "p_created_by" "text" DEFAULT 'cashier'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_return_courier NUMERIC(12,2);
  v_event_at TIMESTAMPTZ := NOW();
  v_is_online BOOLEAN;
  v_return_id BIGINT;
  v_return_number TEXT;
  v_refund_total NUMERIC(12,2) := 0.00;
  v_advance_amount NUMERIC(12,2) := 0.00;
  v_invoice_item_total NUMERIC(12,2) := 0.00;
  v_prior_line_refunds NUMERIC(12,2) := 0.00;
  v_advance_withheld NUMERIC(12,2) := 0.00;
  v_ledger_refund NUMERIC(12,2) := 0.00;
  v_item_count INT := 0;
  v_total_value NUMERIC(12,2) := 0.00;
  v_idx INT := 0;
  v_cum_return NUMERIC(12,2) := 0.00;
  v_alloc_return NUMERIC(12,2);
  v_share NUMERIC;
  v_line RECORD;
  v_remaining INT;
  v_new_status TEXT;
  v_new_payment TEXT;
  v_close_reason TEXT;
  v_actor TEXT := COALESCE(NULLIF(trim(p_created_by), ''), 'cashier');
BEGIN
  IF p_tenant_id IS NULL OR p_invoice_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and invoice_id are required';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return')
    OR public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'force_return')
  ) THEN
    RAISE EXCEPTION 'Post-pay return requires thrift_sales return (or force_return) permission';
  END IF;

  v_return_courier := ROUND(COALESCE(p_return_courier_amount, 0.00), 2);
  IF v_return_courier < 0 THEN
    RAISE EXCEPTION 'return_courier_amount cannot be negative';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) < 1 THEN
    RAISE EXCEPTION 'p_items must be a non-empty JSON array';
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF COALESCE(v_invoice.close_reason, '') = 'RTO' THEN
    RAISE EXCEPTION 'Invoice % is RTO-closed; cannot create post-pay return', p_invoice_id;
  END IF;

  IF v_invoice.status NOT IN ('ACTIVE', 'PARTIALLY_RETURNED') THEN
    RAISE EXCEPTION 'Invoice % status % cannot accept returns', p_invoice_id, v_invoice.status;
  END IF;

  v_is_online := COALESCE(v_invoice.sale_channel, 'IN_STORE') = 'ONLINE';

  IF v_is_online THEN
    IF COALESCE(v_invoice.delivery_status, '') IS DISTINCT FROM 'DELIVERED'
       AND v_invoice.status IS DISTINCT FROM 'PARTIALLY_RETURNED'
    THEN
      RAISE EXCEPTION
        'Online invoice % must be DELIVERED before Return items (use Mark RTO if refuse)',
        p_invoice_id;
    END IF;
  END IF;

  CREATE TEMP TABLE IF NOT EXISTS tmp_return_lines (
    invoice_item_id BIGINT PRIMARY KEY,
    stock_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    condition TEXT NOT NULL,
    refund_amount NUMERIC(12,2) NOT NULL,
    prior_delivery NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_cod_fee NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_packing NUMERIC(12,2) NOT NULL DEFAULT 0,
    prior_return_courier NUMERIC(12,2) NOT NULL DEFAULT 0
  ) ON COMMIT DROP;

  TRUNCATE tmp_return_lines;

  INSERT INTO tmp_return_lines (
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount,
    prior_delivery,
    prior_cod_fee,
    prior_packing,
    prior_return_courier
  )
  SELECT
    i.id,
    i.stock_id,
    GREATEST(req.qty, 1),
    req.condition,
    ROUND(i.final_price * GREATEST(req.qty, 1), 2),
    COALESCE(p.allocated_shop_delivery, 0),
    COALESCE(p.allocated_shop_cod_fee, 0),
    COALESCE(p.allocated_shop_packing, 0),
    COALESCE(p.allocated_return_courier, 0)
  FROM (
    SELECT DISTINCT ON (x.invoice_item_id)
      x.invoice_item_id,
      x.qty,
      x.condition
    FROM (
      SELECT
        (elem->>'invoice_item_id')::BIGINT AS invoice_item_id,
        GREATEST(COALESCE((elem->>'quantity')::INTEGER, 1), 1) AS qty,
        upper(trim(COALESCE(elem->>'condition', ''))) AS condition
      FROM jsonb_array_elements(p_items) AS elem
    ) x
    ORDER BY x.invoice_item_id
  ) req
  JOIN public.thrift_sales_invoice_items i
    ON i.id = req.invoice_item_id
   AND i.tenant_id = p_tenant_id
   AND i.invoice_id = p_invoice_id
  LEFT JOIN public.thrift_sales_pnl_lines p
    ON p.invoice_item_id = i.id
   AND p.tenant_id = p_tenant_id
  WHERE req.condition IN ('SELLABLE', 'DAMAGED')
    AND NOT EXISTS (
      SELECT 1
      FROM public.thrift_sales_return_items ri
      WHERE ri.invoice_item_id = i.id
    );

  GET DIAGNOSTICS v_item_count = ROW_COUNT;

  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'No valid returnable lines in p_items (already returned, wrong invoice, or bad condition)';
  END IF;

  IF v_item_count <> jsonb_array_length(p_items) THEN
    RAISE EXCEPTION 'One or more return lines are invalid, already returned, or not on invoice %', p_invoice_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    JOIN public.thrift_sales_invoice_items i
      ON i.id = t.invoice_item_id
    WHERE t.quantity > i.quantity
  ) THEN
    RAISE EXCEPTION 'Return quantity exceeds invoice line quantity';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    LEFT JOIN public.thrift_sales_pnl_lines p
      ON p.invoice_item_id = t.invoice_item_id
     AND p.tenant_id = p_tenant_id
    WHERE p.id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Invoice % has lines without PnL — deliver Online first (or recreate Offline sale)',
      p_invoice_id;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM tmp_return_lines t
    JOIN public.thrift_sales_pnl_lines p
      ON p.invoice_item_id = t.invoice_item_id
     AND p.tenant_id = p_tenant_id
    WHERE p.outcome IS DISTINCT FROM 'DELIVERED'
  ) THEN
    RAISE EXCEPTION 'Only DELIVERED PnL lines can be returned';
  END IF;

  SELECT COALESCE(SUM(refund_amount), 0)
  INTO v_refund_total
  FROM tmp_return_lines;

  v_total_value := v_refund_total;

  -- Advance is non-refundable: withhold proportional remaining advance from ledger REFUND.
  -- Return doc refund_amount stays line sell sum (PnL/stock). Cash/ledger refund excludes advance.
  v_advance_amount := ROUND(COALESCE(v_invoice.advance_amount, 0.00), 2);
  SELECT COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0)
  INTO v_invoice_item_total
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id;
  SELECT COALESCE(SUM(ri.refund_amount), 0)
  INTO v_prior_line_refunds
  FROM public.thrift_sales_return_items ri
  JOIN public.thrift_sales_returns r
    ON r.id = ri.return_id
   AND r.tenant_id = ri.tenant_id
  WHERE r.tenant_id = p_tenant_id
    AND r.invoice_id = p_invoice_id;
  IF v_invoice_item_total > 0 AND v_advance_amount > 0 THEN
    v_advance_withheld := ROUND(
      v_advance_amount * (v_refund_total / v_invoice_item_total),
      2
    );
    -- Clamp so cumulative withheld cannot exceed advance
    IF v_advance_withheld > GREATEST(0.00, v_advance_amount - ROUND(
      v_advance_amount * (v_prior_line_refunds / v_invoice_item_total), 2
    )) THEN
      v_advance_withheld := GREATEST(
        0.00,
        ROUND(v_advance_amount - ROUND(v_advance_amount * (v_prior_line_refunds / v_invoice_item_total), 2), 2)
      );
    END IF;
  ELSE
    v_advance_withheld := 0.00;
  END IF;
  v_ledger_refund := GREATEST(0.00, ROUND(v_refund_total - v_advance_withheld, 2));
  v_return_number := public.generate_thrift_return_number(p_tenant_id, v_event_at);

  INSERT INTO public.thrift_sales_returns (
    tenant_id,
    invoice_id,
    return_number,
    status,
    refund_amount,
    return_courier_amount,
    notes,
    created_by
  ) VALUES (
    p_tenant_id,
    p_invoice_id,
    v_return_number,
    'COMPLETED',
    v_refund_total,
    v_return_courier,
    NULLIF(trim(p_notes), ''),
    v_actor
  )
  RETURNING id INTO v_return_id;

  INSERT INTO public.thrift_sales_return_items (
    return_id,
    tenant_id,
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount
  )
  SELECT
    v_return_id,
    p_tenant_id,
    invoice_item_id,
    stock_id,
    quantity,
    condition,
    refund_amount
  FROM tmp_return_lines;

  -- Restore stock per condition
  UPDATE public.thrift_stocks s
  SET
    quantity = s.quantity + t.quantity,
    status = CASE
      WHEN t.condition = 'DAMAGED' THEN 'DAMAGED'::public.thrift_stock_status
      ELSE 'AVAILABLE'::public.thrift_stock_status
    END,
    updated_at = NOW()
  FROM tmp_return_lines t
  WHERE s.id = t.stock_id
    AND s.tenant_id = p_tenant_id;

  -- Ledger insert-only (REFUND excludes non-refundable advance share)
  IF v_ledger_refund > 0 THEN
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
      'REFUND'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_ledger_refund,
      'item_refund ' || v_return_number
        || CASE WHEN v_advance_withheld > 0
             THEN ' (advance retained ' || v_advance_withheld::TEXT || ')'
             ELSE ''
           END
        || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
      v_actor,
      v_event_at
    );
  END IF;

  IF v_return_courier > 0 THEN
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
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_return_courier,
      'return_courier ' || v_return_number,
      v_actor,
      v_event_at
    );
  END IF;

  -- PnL: only returned lines → CUSTOMER_RETURN; keep sunk shop fees; add return courier share
  FOR v_line IN
    SELECT *
    FROM tmp_return_lines
    ORDER BY invoice_item_id
  LOOP
    v_idx := v_idx + 1;

    IF v_total_value > 0 THEN
      v_share := v_line.refund_amount / v_total_value;
    ELSE
      v_share := 1.0 / v_item_count;
    END IF;

    IF v_idx = v_item_count THEN
      v_alloc_return := ROUND(v_return_courier - v_cum_return, 2);
    ELSE
      v_alloc_return := ROUND(v_return_courier * v_share, 2);
      v_cum_return := v_cum_return + v_alloc_return;
    END IF;

    UPDATE public.thrift_sales_pnl_lines
    SET
      outcome = 'CUSTOMER_RETURN',
      return_id = v_return_id,
      sell_amount = 0.00,
      allocated_shop_delivery = v_line.prior_delivery,
      allocated_shop_cod_fee = v_line.prior_cod_fee,
      allocated_shop_packing = v_line.prior_packing,
      allocated_return_courier = ROUND(v_line.prior_return_courier + v_alloc_return, 2),
      allocated_fees_total = ROUND(
        v_line.prior_delivery
        + v_line.prior_cod_fee
        + v_line.prior_packing
        + v_line.prior_return_courier
        + v_alloc_return,
        2
      ),
      cogs_is_loss = (v_line.condition = 'DAMAGED'),
      event_at = v_event_at,
      event_date = (v_event_at AT TIME ZONE 'UTC')::DATE,
      updated_at = NOW()
    WHERE tenant_id = p_tenant_id
      AND invoice_item_id = v_line.invoice_item_id;
  END LOOP;

  SELECT COUNT(*)::INT
  INTO v_remaining
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id
    AND NOT EXISTS (
      SELECT 1
      FROM public.thrift_sales_return_items ri
      WHERE ri.invoice_item_id = i.id
    );

  IF v_remaining > 0 THEN
    v_new_status := 'PARTIALLY_RETURNED';
    v_close_reason := NULL;
    IF upper(COALESCE(v_invoice.payment_status, '')) = 'PAID'
       OR upper(COALESCE(v_invoice.payment_status, '')) = 'PARTIALLY_REFUNDED'
    THEN
      v_new_payment := 'PARTIALLY_REFUNDED';
    ELSE
      v_new_payment := v_invoice.payment_status;
    END IF;

    UPDATE public.thrift_sales_invoices
    SET
      status = v_new_status,
      payment_status = v_new_payment,
      close_reason = NULL,
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;
  ELSE
    v_new_status := 'RETURNED';
    v_close_reason := 'CUSTOMER_RETURN';
    v_new_payment := 'REFUNDED';

    UPDATE public.thrift_sales_invoices
    SET
      status = v_new_status,
      payment_status = v_new_payment,
      close_reason = v_close_reason,
      reverted_at = v_event_at,
      reverted_by = v_actor,
      revert_reason = 'CUSTOMER_RETURN',
      revert_notes = NULLIF(trim(p_notes), ''),
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;
  END IF;

  RETURN jsonb_build_object(
    'return_id', v_return_id,
    'return_number', v_return_number,
    'invoice_id', p_invoice_id,
    'refund_amount', v_refund_total,
    'ledger_refund_amount', v_ledger_refund,
    'advance_retained', v_advance_withheld,
    'return_courier_amount', v_return_courier,
    'status', v_new_status,
    'payment_status', v_new_payment,
    'close_reason', v_close_reason
  );
END;
$$;

ALTER FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."create_thrift_sales_return"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_items" "jsonb", "p_return_courier_amount" numeric, "p_notes" "text", "p_created_by" "text") IS 'Post-pay return: docs + stock + PnL CUSTOMER_RETURN. Ledger REFUND excludes non-refundable advance share.';

CREATE OR REPLACE FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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

ALTER FUNCTION "public"."delete_thrift_stocks"("p_tenant_id" bigint, "p_stock_ids" bigint[]) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."generate_thrift_barcodes"("p_tenant_id" bigint, "p_quantity" integer, "p_inserted_by" "text") RETURNS "text"[]
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_current_year text;
  v_latest_barcode text;
  v_prefix text;
  v_max_seq integer := 0;
  v_barcode_id text;
  v_generated text[] := array[]::text[];
  v_tenant_prefix text;
  c1 integer;
  c2 integer;
  i integer;
begin
  -- Advisory lock to prevent race conditions on sequence generation for this tenant
  perform pg_advisory_xact_lock(p_tenant_id);

  -- Determine the current year (2 digits, e.g. '26')
  v_current_year := to_char(now(), 'YY');

  -- Format tenant prefix as 2 digits
  v_tenant_prefix := lpad(p_tenant_id::text, 2, '0');

  -- Validate quantity
  if p_quantity not in (50, 100, 150, 200, 300, 400, 500) then
    raise exception 'Quantity must be one of 50, 100, 150, 200, 300, 400, 500';
  end if;

  -- Find the latest barcode generated for the current year with the new tenant prefix format
  select barcode_id into v_latest_barcode
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id like v_tenant_prefix || '-__-' || v_current_year || '-%'
  order by barcode_id desc
  limit 1;

  if v_latest_barcode is null then
    -- Start from AA for the new year
    v_prefix := 'AA';
    v_max_seq := 0;
  else
    -- Extract prefix and last sequence number (e.g. "01-AA-26-000001")
    v_prefix := substring(v_latest_barcode from 4 for 2);
    v_max_seq := substring(v_latest_barcode from 10)::integer;

    -- If sequence has reached the maximum of 999999, rollover prefix
    if v_max_seq >= 999999 then
      c1 := ascii(substring(v_prefix from 1 for 1));
      c2 := ascii(substring(v_prefix from 2 for 1));
      
      c2 := c2 + 1;
      if c2 > 90 then -- ASCII for 'Z'
        c2 := 65; -- ASCII for 'A'
        c1 := c1 + 1;
        if c1 > 90 then
          raise exception 'Maximum barcode prefix ZZ-999999 reached!';
        end if;
      end if;
      
      v_prefix := chr(c1) || chr(c2);
      v_max_seq := 0;
    end if;
  end if;

  -- Loop and insert p_quantity barcodes
  for i in 1..p_quantity loop
    v_barcode_id := v_tenant_prefix || '-' || v_prefix || '-' || v_current_year || '-' || lpad((v_max_seq + i)::text, 6, '0');
    
    insert into public.thrift_barcodes (
      tenant_id,
      barcode_id,
      status,
      is_printed,
      inserted_by
    )
    values (
      p_tenant_id,
      v_barcode_id,
      'AVAILABLE',
      0,
      p_inserted_by
    );
    
    v_generated := array_append(v_generated, v_barcode_id);
  end loop;

  return v_generated;
end;
$$;

ALTER FUNCTION "public"."generate_thrift_barcodes"("p_tenant_id" bigint, "p_quantity" integer, "p_inserted_by" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone DEFAULT "now"()) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_year_month TEXT;
  v_next BIGINT;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_year_month := to_char(COALESCE(p_date, NOW()), 'YYYY-MM');

  INSERT INTO public.thrift_invoice_counters (tenant_id, year_month, last_value)
  VALUES (p_tenant_id, v_year_month, 1)
  ON CONFLICT (tenant_id, year_month)
  DO UPDATE
    SET last_value = public.thrift_invoice_counters.last_value + 1
  RETURNING last_value INTO v_next;

  RETURN 'INV-' || v_year_month || '-' || lpad(v_next::TEXT, 5, '0');
END;
$$;

ALTER FUNCTION "public"."generate_thrift_invoice_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone DEFAULT "now"()) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_year_month TEXT;
  v_next BIGINT;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  v_year_month := to_char(COALESCE(p_date, NOW()), 'YYYY-MM');

  INSERT INTO public.thrift_return_counters (tenant_id, year_month, last_value)
  VALUES (p_tenant_id, v_year_month, 1)
  ON CONFLICT (tenant_id, year_month)
  DO UPDATE
    SET last_value = public.thrift_return_counters.last_value + 1
  RETURNING last_value INTO v_next;

  RETURN 'RET-' || v_year_month || '-' || lpad(v_next::TEXT, 5, '0');
END;
$$;

ALTER FUNCTION "public"."generate_thrift_return_number"("p_tenant_id" bigint, "p_date" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_phone TEXT := public.normalize_thrift_phone(p_phone);
  v_customer_id BIGINT;
  v_rto_count BIGINT := 0;
  v_return_count BIGINT := 0;
  v_rtos JSONB := '[]'::jsonb;
  v_returns JSONB := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view') THEN
    RAISE EXCEPTION 'Get thrift customer sales risk requires thrift_sales view permission';
  END IF;

  IF v_phone = '' THEN
    RETURN jsonb_build_object(
      'customer_id', NULL,
      'rto_count', 0,
      'return_count', 0,
      'rtos', '[]'::jsonb,
      'returns', '[]'::jsonb
    );
  END IF;

  SELECT c.id
  INTO v_customer_id
  FROM public.thrift_customers c
  WHERE c.tenant_id = p_tenant_id
    AND c.phone_normalized = v_phone
  LIMIT 1;

  SELECT count(*)
  INTO v_rto_count
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND inv.close_reason = 'RTO'
    AND (
      (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
      OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_rtos
  FROM (
    SELECT
      jsonb_build_object(
        'kind', 'RTO',
        'invoice_id', inv.id,
        'invoice_number', inv.invoice_number,
        'at', COALESCE(inv.reverted_at, inv.economics_closed_at, inv.updated_at),
        'total_invoice_amount', inv.total_invoice_amount
      ) AS row_data,
      COALESCE(inv.reverted_at, inv.economics_closed_at, inv.updated_at) AS sort_at,
      inv.id AS sort_id
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND inv.close_reason = 'RTO'
      AND (
        (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
        OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
      )
    ORDER BY sort_at DESC, sort_id DESC
    LIMIT 20
  ) t;

  SELECT count(*)
  INTO v_return_count
  FROM public.thrift_sales_returns r
  JOIN public.thrift_sales_invoices inv
    ON inv.id = r.invoice_id
   AND inv.tenant_id = r.tenant_id
  WHERE r.tenant_id = p_tenant_id
    AND (
      (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
      OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_returns
  FROM (
    SELECT
      jsonb_build_object(
        'kind', 'CUSTOMER_RETURN',
        'return_id', r.id,
        'return_number', r.return_number,
        'invoice_id', r.invoice_id,
        'invoice_number', inv.invoice_number,
        'at', r.created_at,
        'refund_amount', r.refund_amount,
        'line_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
        ),
        'has_damaged', EXISTS (
          SELECT 1
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
            AND ri.condition = 'DAMAGED'
        )
      ) AS row_data,
      r.created_at AS sort_at,
      r.id AS sort_id
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (
        (v_customer_id IS NOT NULL AND inv.customer_id = v_customer_id)
        OR public.normalize_thrift_phone(inv.customer_phone) = v_phone
      )
    ORDER BY sort_at DESC, sort_id DESC
    LIMIT 20
  ) t;

  RETURN jsonb_build_object(
    'customer_id', v_customer_id,
    'rto_count', v_rto_count,
    'return_count', v_return_count,
    'rtos', v_rtos,
    'returns', v_returns
  );
END;
$$;

ALTER FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."get_thrift_customer_sales_risk"("p_tenant_id" bigint, "p_phone" "text") IS 'Customer RTO + post-pay return history by phone for create-sale risk panel. Separate lists, dated DESC, max 20 each.';

CREATE OR REPLACE FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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

ALTER FUNCTION "public"."get_thrift_dashboard_metrics"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text" DEFAULT NULL::"text", "p_outcome" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_channel TEXT;
  v_outcome TEXT;
  v_date_from DATE;
  v_date_to DATE;
  v_summary JSONB;
  v_by_channel JSONB;
  v_by_outcome JSONB;
  v_cod_outstanding JSONB;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift sales report requires thrift_reports view permission';
  END IF;

  IF p_date_from IS NULL OR p_date_to IS NULL THEN
    RAISE EXCEPTION 'p_date_from and p_date_to are required';
  END IF;

  IF p_date_from > p_date_to THEN
    RAISE EXCEPTION 'p_date_from must be <= p_date_to';
  END IF;

  v_date_from := (p_date_from AT TIME ZONE 'UTC')::DATE;
  v_date_to := (p_date_to AT TIME ZONE 'UTC')::DATE;

  v_channel := NULLIF(trim(COALESCE(p_sale_channel, '')), '');
  IF v_channel IS NOT NULL AND v_channel NOT IN ('IN_STORE', 'ONLINE') THEN
    RAISE EXCEPTION 'Invalid sale_channel: % (expected IN_STORE, ONLINE, or null)', v_channel;
  END IF;

  v_outcome := NULLIF(upper(trim(COALESCE(p_outcome, ''))), '');
  IF v_outcome IS NOT NULL AND v_outcome NOT IN ('DELIVERED', 'RTO', 'CUSTOMER_RETURN') THEN
    RAISE EXCEPTION 'Invalid outcome: % (expected DELIVERED, RTO, CUSTOMER_RETURN, or null)', p_outcome;
  END IF;

  WITH pnl AS (
    SELECT
      p.invoice_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      COALESCE(inv.sale_channel, 'IN_STORE') AS sale_channel,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.event_date >= v_date_from
      AND p.event_date <= v_date_to
      AND (v_channel IS NULL OR COALESCE(inv.sale_channel, 'IN_STORE') = v_channel)
      AND (v_outcome IS NULL OR p.outcome = v_outcome)
  ),
  summary_agg AS (
    SELECT
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units_sold,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_shop_delivery), 0)::NUMERIC(14,2) AS allocated_shop_delivery,
      COALESCE(SUM(allocated_shop_cod_fee), 0)::NUMERIC(14,2) AS allocated_shop_cod_fee,
      COALESCE(SUM(allocated_shop_packing), 0)::NUMERIC(14,2) AS allocated_shop_packing,
      COALESCE(SUM(allocated_return_courier), 0)::NUMERIC(14,2) AS allocated_return_courier,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2) AS net_profit,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_count,
      COALESCE(SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'), 0)::NUMERIC(14,2)
        AS rto_amount,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS customer_return_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS customer_return_amount,
      -- BC aliases used by existing UI
      COALESCE(SUM(sell_amount - cogs), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2)
        AS net_after_fees,
      COUNT(*) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN'))::BIGINT AS refund_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN')),
        0
      )::NUMERIC(14,2) AS refund_amount
    FROM pnl
  ),
  channel_rows AS (
    SELECT
      sale_channel,
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units_sold,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS total_fees,
      COALESCE(SUM(sell_amount - cogs), 0)::NUMERIC(14,2) AS line_profit,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2)
        AS net_after_fees,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_count,
      COALESCE(SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'), 0)::NUMERIC(14,2)
        AS rto_amount,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS customer_return_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS customer_return_amount,
      COUNT(*) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN'))::BIGINT AS refund_count,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome IN ('RTO', 'CUSTOMER_RETURN')),
        0
      )::NUMERIC(14,2) AS refund_amount
    FROM pnl
    GROUP BY sale_channel
  ),
  outcome_rows AS (
    SELECT
      outcome,
      COUNT(DISTINCT invoice_id)::BIGINT AS invoice_count,
      COALESCE(SUM(quantity), 0)::BIGINT AS units,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(sell_amount - cogs - allocated_fees_total), 0)::NUMERIC(14,2) AS net_profit
    FROM pnl
    GROUP BY outcome
  )
  SELECT
    jsonb_build_object(
      'invoice_count', s.invoice_count,
      'units_sold', s.units_sold,
      'units', s.units_sold,
      'net_revenue', s.net_revenue,
      'cogs', s.cogs,
      'line_profit', s.line_profit,
      'allocated_shop_delivery', s.allocated_shop_delivery,
      'allocated_shop_cod_fee', s.allocated_shop_cod_fee,
      'allocated_shop_packing', s.allocated_shop_packing,
      'allocated_return_courier', s.allocated_return_courier,
      'allocated_fees_total', s.allocated_fees_total,
      'net_profit', s.net_profit,
      'courier_cod_amount', s.allocated_shop_delivery + s.allocated_shop_cod_fee,
      'other_expense_amount', s.allocated_shop_packing + s.allocated_return_courier,
      'total_fees', s.total_fees,
      'net_after_fees', s.net_after_fees,
      'refund_count', s.refund_count,
      'refund_amount', s.refund_amount,
      'rto_count', s.rto_count,
      'rto_amount', s.rto_amount,
      'customer_return_count', s.customer_return_count,
      'customer_return_amount', s.customer_return_amount
    ),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'sale_channel', c.sale_channel,
            'invoice_count', c.invoice_count,
            'units_sold', c.units_sold,
            'net_revenue', c.net_revenue,
            'cogs', c.cogs,
            'line_profit', c.line_profit,
            'courier_cod_amount', c.total_fees,
            'other_expense_amount', 0::NUMERIC(14,2),
            'total_fees', c.total_fees,
            'net_after_fees', c.net_after_fees,
            'refund_count', c.refund_count,
            'refund_amount', c.refund_amount,
            'rto_count', c.rto_count,
            'rto_amount', c.rto_amount,
            'customer_return_count', c.customer_return_count,
            'customer_return_amount', c.customer_return_amount
          )
          ORDER BY c.sale_channel
        )
        FROM channel_rows c
      ),
      '[]'::jsonb
    ),
    COALESCE(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'outcome', o.outcome,
            'invoice_count', o.invoice_count,
            'units', o.units,
            'net_revenue', o.net_revenue,
            'cogs', o.cogs,
            'allocated_fees_total', o.allocated_fees_total,
            'net_profit', o.net_profit
          )
          ORDER BY o.outcome
        )
        FROM outcome_rows o
      ),
      '[]'::jsonb
    )
  INTO v_summary, v_by_channel, v_by_outcome
  FROM summary_agg s;

  SELECT jsonb_build_object(
    'invoice_count', COUNT(*)::BIGINT,
    'cod_expected_total', COALESCE(SUM(COALESCE(inv.cod_expected, 0)), 0)::NUMERIC(14,2),
    'cod_remitted_total', COALESCE(SUM(COALESCE(inv.cod_remitted_amount, 0)), 0)::NUMERIC(14,2)
  )
  INTO v_cod_outstanding
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND COALESCE(inv.status, 'ACTIVE') IN ('ACTIVE', 'PARTIALLY_RETURNED')
    AND inv.payment_status = 'COD_PENDING';

  RETURN jsonb_build_object(
    'date_from', p_date_from,
    'date_to', p_date_to,
    'sale_channel', v_channel,
    'outcome', v_outcome,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_channel', COALESCE(v_by_channel, '[]'::jsonb),
    'by_outcome', COALESCE(v_by_outcome, '[]'::jsonb),
    'cod_outstanding', COALESCE(v_cod_outstanding, jsonb_build_object(
      'invoice_count', 0,
      'cod_expected_total', 0,
      'cod_remitted_total', 0
    ))
  );
END;
$$;

ALTER FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."get_thrift_sales_report"("p_tenant_id" bigint, "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_sale_channel" "text", "p_outcome" "text") IS 'Period P&L from thrift_sales_pnl_lines + live COGS (cogs_is_loss). Includes RTO and customer-return cards.';

CREATE OR REPLACE FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shipment JSONB;
  v_summary JSONB;
  v_lines JSONB;
  v_by_outcome JSONB;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_reports', 'view') THEN
    RAISE EXCEPTION 'Thrift shipment report requires thrift_reports view permission';
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

  WITH pnl AS (
    SELECT
      p.id,
      p.invoice_id,
      p.invoice_item_id,
      p.stock_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs,
      ROUND(
        p.sell_amount
        - CASE
            WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
              ROUND(
                ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
                * p.quantity,
                2
              )
            ELSE 0.00
          END
        - p.allocated_fees_total,
        2
      ) AS net_profit,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      st.name AS stock_name,
      st.barcode
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.id = p.invoice_item_id
     AND i.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_stocks st
      ON st.id = p.stock_id
     AND st.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.inbound_shipment_id = p_shipment_id
  ),
  summary AS (
    SELECT
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::BIGINT AS units_sold,
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'RTO'), 0)::BIGINT AS units_rto,
      COALESCE(SUM(quantity) FILTER (WHERE outcome = 'CUSTOMER_RETURN'), 0)::BIGINT AS units_returned,
      COALESCE(SUM(sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(sell_amount) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS delivered_revenue,
      COALESCE(SUM(cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(net_profit), 0)::NUMERIC(14,2) AS net_profit,
      COALESCE(SUM(net_profit) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS delivered_net,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'RTO'),
        0
      )::NUMERIC(14,2) AS rto_fee_loss,
      COALESCE(
        SUM(allocated_fees_total) FILTER (WHERE outcome = 'CUSTOMER_RETURN'),
        0
      )::NUMERIC(14,2) AS return_fee_loss,
      COUNT(*) FILTER (WHERE outcome = 'DELIVERED')::BIGINT AS delivered_line_count,
      COUNT(*) FILTER (WHERE outcome = 'RTO')::BIGINT AS rto_line_count,
      COUNT(*) FILTER (WHERE outcome = 'CUSTOMER_RETURN')::BIGINT AS return_line_count,
      COALESCE(SUM(sell_price * quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS gross_sales,
      COALESCE(SUM(discount_amount * quantity) FILTER (WHERE outcome = 'DELIVERED'), 0)::NUMERIC(14,2)
        AS discounts
    FROM pnl
  )
  SELECT jsonb_build_object(
    'units_sold', s.units_sold,
    'units_rto', s.units_rto,
    'units_returned', s.units_returned,
    'gross_sales', s.gross_sales,
    'discounts', s.discounts,
    'net_revenue', s.net_revenue,
    'delivered_revenue', s.delivered_revenue,
    'cogs', s.cogs,
    'allocated_fees_total', s.allocated_fees_total,
    'net_profit', s.net_profit,
    'delivered_net', s.delivered_net,
    'rto_fee_loss', s.rto_fee_loss,
    'return_fee_loss', s.return_fee_loss,
    'delivered_line_count', s.delivered_line_count,
    'rto_line_count', s.rto_line_count,
    'return_line_count', s.return_line_count,
    'margin_pct', CASE
      WHEN s.net_revenue > 0 THEN ROUND((s.net_profit / s.net_revenue) * 100, 2)
      ELSE 0::NUMERIC(8,2)
    END
  )
  INTO v_summary
  FROM summary s;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'outcome', o.outcome,
        'line_count', o.line_count,
        'units', o.units,
        'net_revenue', o.net_revenue,
        'cogs', o.cogs,
        'allocated_fees_total', o.allocated_fees_total,
        'net_profit', o.net_profit
      )
      ORDER BY o.outcome
    ),
    '[]'::jsonb
  )
  INTO v_by_outcome
  FROM (
    SELECT
      p.outcome,
      COUNT(*)::BIGINT AS line_count,
      COALESCE(SUM(p.quantity), 0)::BIGINT AS units,
      COALESCE(SUM(p.sell_amount), 0)::NUMERIC(14,2) AS net_revenue,
      COALESCE(SUM(p.cogs), 0)::NUMERIC(14,2) AS cogs,
      COALESCE(SUM(p.allocated_fees_total), 0)::NUMERIC(14,2) AS allocated_fees_total,
      COALESCE(SUM(p.net_profit), 0)::NUMERIC(14,2) AS net_profit
    FROM (
      SELECT
        p2.outcome,
        p2.quantity,
        p2.sell_amount,
        p2.allocated_fees_total,
        CASE
          WHEN p2.sell_amount > 0 OR p2.cogs_is_loss THEN
            ROUND(
              ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p2.stock_id), 0.00), 2)
              * p2.quantity,
              2
            )
          ELSE 0.00
        END AS cogs,
        ROUND(
          p2.sell_amount
          - CASE
              WHEN p2.sell_amount > 0 OR p2.cogs_is_loss THEN
                ROUND(
                  ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p2.stock_id), 0.00), 2)
                  * p2.quantity,
                  2
                )
              ELSE 0.00
            END
          - p2.allocated_fees_total,
          2
        ) AS net_profit
      FROM public.thrift_sales_pnl_lines p2
      WHERE p2.tenant_id = p_tenant_id
        AND p2.inbound_shipment_id = p_shipment_id
    ) p
    GROUP BY p.outcome
  ) o;

  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'id', x.id,
        'invoice_id', x.invoice_id,
        'invoice_item_id', x.invoice_item_id,
        'invoice_number', x.invoice_number,
        'invoice_date', x.invoice_date,
        'event_date', x.event_date,
        'outcome', x.outcome,
        'stock_id', x.stock_id,
        'stock_name', x.stock_name,
        'barcode', x.barcode,
        'quantity', x.quantity,
        'sell_price', COALESCE(x.sell_price, 0),
        'discount_amount', COALESCE(x.discount_amount, 0),
        'final_price', COALESCE(x.final_price, x.sell_amount),
        'sell_amount', x.sell_amount,
        'landed_unit_cost_at_sale', x.landed_unit_cost,
        'cogs', x.cogs,
        'cogs_is_loss', x.cogs_is_loss,
        'allocated_shop_delivery', x.allocated_shop_delivery,
        'allocated_shop_cod_fee', x.allocated_shop_cod_fee,
        'allocated_shop_packing', x.allocated_shop_packing,
        'allocated_return_courier', x.allocated_return_courier,
        'allocated_fees_total', x.allocated_fees_total,
        'net_profit', x.net_profit
      )
      ORDER BY x.event_at DESC NULLS LAST, x.id DESC
    ),
    '[]'::jsonb
  )
  INTO v_lines
  FROM (
    SELECT
      p.id,
      p.invoice_id,
      p.invoice_item_id,
      p.stock_id,
      p.outcome,
      p.quantity,
      p.sell_amount,
      p.allocated_shop_delivery,
      p.allocated_shop_cod_fee,
      p.allocated_shop_packing,
      p.allocated_return_courier,
      p.allocated_fees_total,
      p.cogs_is_loss,
      p.event_at,
      p.event_date,
      ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2) AS landed_unit_cost,
      CASE
        WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
          ROUND(
            ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
            * p.quantity,
            2
          )
        ELSE 0.00
      END AS cogs,
      ROUND(
        p.sell_amount
        - CASE
            WHEN p.sell_amount > 0 OR p.cogs_is_loss THEN
              ROUND(
                ROUND(COALESCE(public.compute_thrift_landed_unit_cost(p.stock_id), 0.00), 2)
                * p.quantity,
                2
              )
            ELSE 0.00
          END
        - p.allocated_fees_total,
        2
      ) AS net_profit,
      inv.invoice_number,
      inv.date AS invoice_date,
      i.sell_price,
      i.discount_amount,
      i.final_price,
      st.name AS stock_name,
      st.barcode
    FROM public.thrift_sales_pnl_lines p
    JOIN public.thrift_sales_invoices inv
      ON inv.id = p.invoice_id
     AND inv.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_sales_invoice_items i
      ON i.id = p.invoice_item_id
     AND i.tenant_id = p.tenant_id
    LEFT JOIN public.thrift_stocks st
      ON st.id = p.stock_id
     AND st.tenant_id = p.tenant_id
    WHERE p.tenant_id = p_tenant_id
      AND p.inbound_shipment_id = p_shipment_id
  ) x;

  RETURN jsonb_build_object(
    'shipment', v_shipment,
    'summary', COALESCE(v_summary, '{}'::jsonb),
    'by_outcome', COALESCE(v_by_outcome, '[]'::jsonb),
    'lines', COALESCE(v_lines, '[]'::jsonb)
  );
END;
$$;

ALTER FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."get_thrift_shipment_sales_report"("p_tenant_id" bigint, "p_shipment_id" bigint) IS 'Inbound shipment P&L from thrift_sales_pnl_lines + live COGS (includes cogs_is_loss).';

CREATE OR REPLACE FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text" DEFAULT NULL::"text", "p_hold_note" "text" DEFAULT NULL::"text", "p_held_by" "text" DEFAULT NULL::"text", "p_hold_expires_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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

ALTER FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."hold_thrift_stock"("p_tenant_id" bigint, "p_stock_id" bigint, "p_held_for_phone" "text", "p_held_for_name" "text", "p_hold_note" "text", "p_held_by" "text", "p_hold_expires_at" timestamp with time zone) IS 'Place AVAILABLE thrift stock on RESERVED hold for a customer phone (FB/online).';

CREATE OR REPLACE FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_search" "text" DEFAULT NULL::"text", "p_is_printed" smallint DEFAULT NULL::smallint, "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 50), 1);
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_status text := nullif(trim(coalesce(p_status, '')), '');
  v_unprinted_total bigint;
  v_available_total bigint;
  v_printable_total bigint;
  v_latest_current_year text;
  v_current_year text := to_char(now(), 'YY');
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

  select count(*)
  into v_total_count
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and (p_is_printed is null or b.is_printed = p_is_printed)
    and (v_status is null or b.status = v_status)
    and (
      v_search is null
      or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
      or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
    );

  select count(*)
  into v_unprinted_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.is_printed = 0;

  select count(*)
  into v_available_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.status = 'AVAILABLE';

  select count(*)
  into v_printable_total
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.is_printed = 0
    and b.status = 'AVAILABLE';

  select b.barcode_id
  into v_latest_current_year
  from public.thrift_barcodes b
  cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
  where b.tenant_id = p_tenant_id
    and b.barcode_id like '%-' || v_current_year || '-%'
  order by sk.sort_prefix desc, sk.sort_year desc, sk.sort_seq desc, b.barcode_id desc
  limit 1;

  select coalesce(jsonb_agg(row_data order by sort_prefix asc, sort_year asc, sort_seq asc, sort_barcode_id asc), '[]'::jsonb)
  into v_data
  from (
    select
      jsonb_build_object(
        'id', b.id,
        'tenant_id', b.tenant_id,
        'barcode_id', b.barcode_id,
        'status', b.status,
        'is_printed', b.is_printed,
        'inserted_by', b.inserted_by,
        'created_at', b.created_at,
        'updated_at', b.updated_at
      ) as row_data,
      sk.sort_prefix,
      sk.sort_year,
      sk.sort_seq,
      b.barcode_id as sort_barcode_id
    from public.thrift_barcodes b
    cross join lateral public.thrift_barcode_sequence_sort_key(b.barcode_id) sk
    where b.tenant_id = p_tenant_id
      and (p_is_printed is null or b.is_printed = p_is_printed)
      and (v_status is null or b.status = v_status)
      and (
        v_search is null
        or coalesce(b.barcode_id, '') ilike '%' || v_search || '%'
        or coalesce(b.inserted_by, '') ilike '%' || v_search || '%'
      )
    order by sk.sort_prefix asc, sk.sort_year asc, sk.sort_seq asc, b.barcode_id asc
    offset (v_page - 1) * v_page_size
    limit v_page_size
  ) paged;

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
      'total_pages', v_total_pages,
      'unprinted_total', v_unprinted_total,
      'available_total', v_available_total,
      'printable_total', v_printable_total,
      'latest_current_year_barcode_id', v_latest_current_year
    )
  );
end;
$$;

ALTER FUNCTION "public"."list_thrift_barcodes_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_is_printed" smallint, "p_status" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_payment_status" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_delivery_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_page INTEGER := greatest(coalesce(p_page, 1), 1);
  v_page_size INTEGER := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search TEXT := nullif(trim(coalesce(p_search, '')), '');
  v_payment_status TEXT := nullif(upper(trim(coalesce(p_payment_status, ''))), '');
  v_status TEXT := nullif(upper(trim(coalesce(p_status, ''))), '');
  v_delivery_status TEXT := nullif(upper(trim(coalesce(p_delivery_status, ''))), '');
  v_total_count BIGINT;
  v_total_pages INTEGER;
  v_data JSONB;
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

  SELECT count(*)
  INTO v_total_count
  FROM public.thrift_sales_invoices inv
  WHERE inv.tenant_id = p_tenant_id
    AND (
      v_search IS NULL
      OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
      OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
    )
    AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
    AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
    AND (
      v_delivery_status IS NULL
      OR inv.delivery_status = v_delivery_status
    );

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', inv.id,
        'invoice_number', inv.invoice_number,
        'sale_channel', inv.sale_channel,
        'customer_id', inv.customer_id,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'customer_address', inv.customer_address,
        'date', inv.date,
        'payment_method', inv.payment_method,
        'payment_status', inv.payment_status,
        'delivery_status', inv.delivery_status,
        'total_invoice_amount', inv.total_invoice_amount,
        'courier_amount', inv.courier_amount,
        'courier_paid_by', inv.courier_paid_by,
        'cod_expected', inv.cod_expected,
        'cod_remitted_amount', inv.cod_remitted_amount,
        'cod_remitted_at', inv.cod_remitted_at,
        'created_by', inv.created_by,
        'notes', inv.notes,
        'created_at', inv.created_at,
        'status', inv.status,
        'reverted_at', inv.reverted_at,
        'reverted_by', inv.reverted_by,
        'revert_reason', inv.revert_reason,
        'revert_notes', inv.revert_notes,
        'item_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_invoice_items si
          WHERE si.invoice_id = inv.id
            AND si.tenant_id = inv.tenant_id
        )
      ) AS row_data,
      inv.created_at AS sort_created_at,
      inv.id AS sort_id
    FROM public.thrift_sales_invoices inv
    WHERE inv.tenant_id = p_tenant_id
      AND (
        v_search IS NULL
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (v_payment_status IS NULL OR inv.payment_status = v_payment_status)
      AND (v_status IS NULL OR coalesce(inv.status, 'ACTIVE') = v_status)
      AND (
        v_delivery_status IS NULL
        OR inv.delivery_status = v_delivery_status
      )
    ORDER BY inv.created_at DESC, inv.id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  ) paged;

  IF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::NUMERIC / v_page_size)::INTEGER;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'page', v_page,
      'total', v_total_count,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
END;
$$;

ALTER FUNCTION "public"."list_thrift_sales_invoices_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_payment_status" "text", "p_status" "text", "p_delivery_status" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_date_from" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_date_to" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_invoice_id" bigint DEFAULT NULL::bigint, "p_has_damaged" boolean DEFAULT NULL::boolean, "p_skip_count" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_page INTEGER := greatest(coalesce(p_page, 1), 1);
  v_page_size INTEGER := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_search TEXT := nullif(trim(coalesce(p_search, '')), '');
  v_total_count BIGINT := 0;
  v_total_pages INTEGER := 0;
  v_data JSONB;
  v_skip_count BOOLEAN := COALESCE(p_skip_count, false);
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'view') THEN
    RAISE EXCEPTION 'List thrift sales returns requires thrift_sales view permission';
  END IF;

  IF NOT v_skip_count THEN
    SELECT count(*)
    INTO v_total_count
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (p_invoice_id IS NULL OR r.invoice_id = p_invoice_id)
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to)
      AND (
        v_search IS NULL
        OR coalesce(r.return_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (
        p_has_damaged IS NULL
        OR (
          p_has_damaged = TRUE
          AND EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
        OR (
          p_has_damaged = FALSE
          AND NOT EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
      );
  END IF;

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created_at DESC, sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      jsonb_build_object(
        'id', r.id,
        'return_number', r.return_number,
        'invoice_id', r.invoice_id,
        'invoice_number', inv.invoice_number,
        'customer_name', inv.customer_name,
        'customer_phone', inv.customer_phone,
        'refund_amount', r.refund_amount,
        'return_courier_amount', r.return_courier_amount,
        'status', r.status,
        'notes', r.notes,
        'line_count', (
          SELECT count(*)::INT
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
        ),
        'has_damaged', EXISTS (
          SELECT 1
          FROM public.thrift_sales_return_items ri
          WHERE ri.return_id = r.id
            AND ri.condition = 'DAMAGED'
        ),
        'created_by', r.created_by,
        'created_at', r.created_at
      ) AS row_data,
      r.created_at AS sort_created_at,
      r.id AS sort_id
    FROM public.thrift_sales_returns r
    JOIN public.thrift_sales_invoices inv
      ON inv.id = r.invoice_id
     AND inv.tenant_id = r.tenant_id
    WHERE r.tenant_id = p_tenant_id
      AND (p_invoice_id IS NULL OR r.invoice_id = p_invoice_id)
      AND (p_date_from IS NULL OR r.created_at >= p_date_from)
      AND (p_date_to IS NULL OR r.created_at <= p_date_to)
      AND (
        v_search IS NULL
        OR coalesce(r.return_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.invoice_number, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_name, '') ILIKE '%' || v_search || '%'
        OR coalesce(inv.customer_phone, '') ILIKE '%' || v_search || '%'
      )
      AND (
        p_has_damaged IS NULL
        OR (
          p_has_damaged = TRUE
          AND EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
        OR (
          p_has_damaged = FALSE
          AND NOT EXISTS (
            SELECT 1
            FROM public.thrift_sales_return_items ri
            WHERE ri.return_id = r.id
              AND ri.condition = 'DAMAGED'
          )
        )
      )
    ORDER BY r.created_at DESC, r.id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  ) paged;

  IF v_skip_count THEN
    v_total_pages := 0;
  ELSIF v_total_count = 0 THEN
    v_total_pages := 0;
  ELSE
    v_total_pages := ceil(v_total_count::NUMERIC / v_page_size)::INTEGER;
  END IF;

  RETURN jsonb_build_object(
    'data', coalesce(v_data, '[]'::jsonb),
    'meta', jsonb_build_object(
      'page', v_page,
      'total', CASE WHEN v_skip_count THEN NULL ELSE v_total_count END,
      'page_size', v_page_size,
      'total_pages', CASE WHEN v_skip_count THEN NULL ELSE v_total_pages END,
      'skip_count', v_skip_count
    )
  );
END;
$$;

ALTER FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."list_thrift_sales_returns_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_date_from" timestamp with time zone, "p_date_to" timestamp with time zone, "p_invoice_id" bigint, "p_has_damaged" boolean, "p_skip_count" boolean) IS 'Paginated thrift post-pay returns list for hub + invoice history.';

CREATE OR REPLACE FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_condition" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

ALTER FUNCTION "public"."list_thrift_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_condition" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."log_thrift_stock_loss_ledger"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_landed numeric(12, 2);
begin
  if (new.status in ('DAMAGED'::public.thrift_stock_status, 'STOLEN'::public.thrift_stock_status))
     and (old.status is null or old.status <> new.status) then
     
    v_landed := coalesce(public.compute_thrift_landed_unit_cost(new.id), 0.00);

    if v_landed > 0 then
      insert into public.thrift_accounting_ledger (
        tenant_id,
        type,
        source,
        reference_id,
        amount,
        inserted_by,
        note
      )
      values (
        new.tenant_id,
        'LOSS'::public.thrift_ledger_type,
        'SHIPMENT'::public.thrift_ledger_source,
        new.shipment_id,
        v_landed * new.quantity,
        new.inserted_by,
        'Auto-logged loss for stock item status set to ' || new.status || ' (Barcode: ' || coalesce(new.barcode, '') || ')'
      );
    end if;
  end if;
  return new;
end;
$$;

ALTER FUNCTION "public"."log_thrift_stock_loss_ledger"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_invoice_id bigint;
  v_item jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_sold_price numeric(12,2);
  v_platform_fees numeric(12,2);
  v_ship_paid_by_shop numeric(12,2);
  v_available_qty integer;
  v_total_ship_paid_by_shop numeric(12,2) := 0.00;
begin
  -- 1. Insert Invoice
  insert into public.thrift_invoices (
    tenant_id,
    invoice_number,
    recipient_name,
    address,
    phone,
    transaction_method,
    cod_charge,
    packing_charge,
    invoice_print_charge,
    shipping_charge_customer,
    inserted_by
  )
  values (
    p_tenant_id,
    p_invoice_number,
    p_recipient_name,
    p_address,
    p_phone,
    p_transaction_method,
    p_cod_charge,
    p_packing_charge,
    p_invoice_print_charge,
    p_shipping_charge_customer,
    p_inserted_by
  )
  returning id into v_invoice_id;

  -- 2. Process items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_stock_id := (v_item->>'stock_id')::bigint;
    v_qty := (v_item->>'quantity')::integer;
    v_sold_price := (v_item->>'sold_price')::numeric;
    v_platform_fees := coalesce((v_item->>'platform_fees')::numeric, 0.00);
    v_ship_paid_by_shop := coalesce((v_item->>'shipping_cost_paid_by_shop')::numeric, 0.00);

    v_total_ship_paid_by_shop := v_total_ship_paid_by_shop + v_ship_paid_by_shop;

    -- Qty validation
    select quantity into v_available_qty
    from public.thrift_stocks
    where id = v_stock_id and tenant_id = p_tenant_id;

    if v_available_qty < v_qty then
      raise exception 'Insufficient stock for stock ID %', v_stock_id;
    end if;

    -- Add item to invoice
    insert into public.thrift_invoice_items (
      invoice_id,
      stock_id,
      quantity,
      sold_price,
      platform_fees,
      shipping_cost_paid_by_shop,
      item_status
    )
    values (
      v_invoice_id,
      v_stock_id,
      v_qty,
      v_sold_price,
      v_platform_fees,
      v_ship_paid_by_shop,
      'SOLD'::public.thrift_item_status
    );

    -- Deduct stock qty
    update public.thrift_stocks
    set 
      quantity = quantity - v_qty,
      status = case when (quantity - v_qty) = 0 then 'OUT_OF_STOCK'::public.thrift_stock_status else status end,
      updated_at = now()
    where id = v_stock_id;
  end loop;

  -- 3. Log Revenue (accrual basis)
  insert into public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    inserted_by,
    note
  )
  select 
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    total_invoice_amount,
    p_inserted_by,
    'Auto-logged revenue from Thrift Invoice #' || invoice_number
  from public.thrift_invoices
  where id = v_invoice_id;

  -- 4. Log Shipping Expense (if applicable)
  if v_total_ship_paid_by_shop > 0 then
    insert into public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      inserted_by,
      note
    )
    values (
      p_tenant_id,
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_total_ship_paid_by_shop,
      p_inserted_by,
      'Auto-logged shipping cost absorbed by shop for Invoice #' || p_invoice_number
    );
  end if;

  return v_invoice_id;
end;
$$;

ALTER FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."mark_thrift_items_as_sold"("p_tenant_id" bigint, "p_invoice_number" "text", "p_recipient_name" "text", "p_address" "text", "p_phone" "text", "p_transaction_method" "public"."thrift_transaction_method", "p_cod_charge" numeric, "p_packing_charge" numeric, "p_invoice_print_charge" numeric, "p_shipping_charge_customer" numeric, "p_inserted_by" "text", "p_items" "jsonb") IS 'LEGACY ARCHIVE — execute revoked (P21). Use create_thrift_sales_invoice.';

CREATE OR REPLACE FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE PARALLEL SAFE
    AS $$
  SELECT regexp_replace(coalesce(p_phone, ''), '[^0-9]', '', 'g');
$$;

ALTER FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."normalize_thrift_phone"("p_phone" "text") IS 'Digits-only thrift customer phone key; empty/null input → empty string.';

CREATE OR REPLACE FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone DEFAULT "now"(), "p_remittance_ref" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text", "p_outcome" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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

  IF upper(trim(COALESCE(v_invoice.sale_channel, ''))) IS DISTINCT FROM 'ONLINE' THEN
    RAISE EXCEPTION
      'Invoice % sale_channel is % — remittance only allowed on ONLINE invoices',
      p_invoice_id,
      v_invoice.sale_channel;
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

  IF v_outcome = 'WRITTEN_OFF' AND NULLIF(trim(COALESCE(p_notes, '')), '') IS NULL THEN
    RAISE EXCEPTION 'Notes are required when writing off COD remittance';
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

ALTER FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."record_thrift_cod_remittance"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_remitted_amount" numeric, "p_actor" "text", "p_remitted_at" timestamp with time zone, "p_remittance_ref" "text", "p_notes" "text", "p_outcome" "text") IS 'Record Online COD cash on invoice. Outcomes PAID/KEEP_PENDING/WRITTEN_OFF. No ledger/PnL. WRITTEN_OFF requires notes.';

CREATE OR REPLACE FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text" DEFAULT NULL::"text", "p_category_id" bigint DEFAULT NULL::bigint, "p_type_id" bigint DEFAULT NULL::bigint, "p_section" "text" DEFAULT NULL::"text", "p_shelf_id" bigint DEFAULT NULL::bigint, "p_color" "text" DEFAULT NULL::"text", "p_size" "text" DEFAULT NULL::"text", "p_condition" "text" DEFAULT NULL::"text", "p_box_id" bigint DEFAULT NULL::bigint, "p_product_weight" numeric DEFAULT NULL::numeric, "p_extra_weight" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text", "p_origin_purchase_price" numeric DEFAULT NULL::numeric, "p_extra_origin_purchase_expense" numeric DEFAULT NULL::numeric, "p_cost_of_goods_sold" numeric DEFAULT 0, "p_target_price" numeric DEFAULT 0, "p_listed_price" numeric DEFAULT 0, "p_extra_expense_cost" numeric DEFAULT 0, "p_inserted_by" "text" DEFAULT 'app-user'::"text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_section public.thrift_section;
  v_condition public.thrift_condition;
  v_canonical_barcode text;
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  end if;

  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  end if;

  v_section := nullif(trim(coalesce(p_section, '')), '')::public.thrift_section;
  v_condition := nullif(trim(coalesce(p_condition, '')), '')::public.thrift_condition;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  v_canonical_barcode := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_barcode);
  if v_canonical_barcode is null then
    raise exception 'Barcode not found in catalog';
  end if;

  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  end if;

  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = v_canonical_barcode
  limit 1;

  if v_stock_id is null then
    if v_barcode_row.status <> 'AVAILABLE' then
      raise exception 'Barcode is already used';
    end if;

    insert into public.thrift_stocks (
      tenant_id,
      shipment_id,
      brand_name,
      category_id,
      type_id,
      section,
      shelf_id,
      color,
      size,
      condition,
      barcode,
      stock_type,
      quantity,
      box_id,
      product_weight,
      extra_weight,
      status,
      note,
      inserted_by,
      origin_purchase_price,
      extra_origin_purchase_expense
    )
    values (
      p_tenant_id,
      p_shipment_id,
      nullif(trim(coalesce(p_brand_name, '')), ''),
      p_category_id,
      p_type_id,
      v_section,
      p_shelf_id,
      nullif(trim(coalesce(p_color, '')), ''),
      nullif(trim(coalesce(p_size, '')), ''),
      v_condition,
      v_canonical_barcode,
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      p_origin_purchase_price,
      p_extra_origin_purchase_expense
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = nullif(trim(coalesce(p_brand_name, '')), ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = v_section,
      shelf_id = p_shelf_id,
      color = nullif(trim(coalesce(p_color, '')), ''),
      size = nullif(trim(coalesce(p_size, '')), ''),
      condition = v_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_purchase_price = p_origin_purchase_price,
      extra_origin_purchase_expense = p_extra_origin_purchase_expense,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  end if;

  insert into public.thrift_pricings (
    stock_id,
    cost_of_goods_sold,
    target_price,
    listed_price,
    extra_expense_cost,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(p_cost_of_goods_sold, 0),
    coalesce(p_target_price, 0),
    coalesce(p_listed_price, 0),
    coalesce(p_extra_expense_cost, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    cost_of_goods_sold = excluded.cost_of_goods_sold,
    target_price = excluded.target_price,
    listed_price = excluded.listed_price,
    extra_expense_cost = excluded.extra_expense_cost,
    inserted_by = excluded.inserted_by;

  update public.thrift_stock_images
  set image_url = p_image_url,
      inserted_by = p_inserted_by
  where stock_id = v_stock_id
    and is_primary = true;

  if not found then
    insert into public.thrift_stock_images (
      stock_id,
      image_url,
      is_primary,
      inserted_by
    )
    values (
      v_stock_id,
      p_image_url,
      true,
      p_inserted_by
    );
  end if;

  update public.thrift_barcodes
  set status = 'USED'
  where tenant_id = p_tenant_id
    and barcode_id = v_canonical_barcode;

  return v_stock_id;
end;
$$;

ALTER FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_extra_origin_purchase_expense" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_extra_expense_cost" numeric, "p_inserted_by" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint DEFAULT NULL::bigint, "p_product_weight" numeric DEFAULT NULL::numeric, "p_extra_weight" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text", "p_origin_purchase_price" numeric DEFAULT NULL::numeric, "p_cost_of_goods_sold" numeric DEFAULT 0, "p_target_price" numeric DEFAULT 0, "p_listed_price" numeric DEFAULT 0, "p_inserted_by" "text" DEFAULT 'app-user'::"text", "p_origin_unit_price" numeric DEFAULT NULL::numeric, "p_extra_origin_unit_price" numeric DEFAULT NULL::numeric, "p_listed_unit_price" numeric DEFAULT NULL::numeric, "p_extra_origin_purchase_expense" numeric DEFAULT NULL::numeric) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_barcode_row public.thrift_barcodes%rowtype;
  v_stock_id bigint;
  v_origin_unit_price numeric := coalesce(p_origin_unit_price, p_origin_purchase_price);
  v_extra_origin_unit_price numeric := coalesce(p_extra_origin_unit_price, p_extra_origin_purchase_expense, 0);
  v_listed_unit_price numeric := coalesce(p_listed_unit_price, p_listed_price);
begin
  if trim(coalesce(p_barcode, '')) = '' then
    raise exception 'Barcode is required';
  end if;

  if trim(coalesce(p_image_url, '')) = '' then
    raise exception 'Image URL is required';
  end if;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized for this tenant';
  end if;

  select *
  into v_barcode_row
  from public.thrift_barcodes
  where tenant_id = p_tenant_id
    and barcode_id = trim(p_barcode)
  for update;

  if not found then
    raise exception 'Barcode not found in catalog';
  end if;

  select id
  into v_stock_id
  from public.thrift_stocks
  where tenant_id = p_tenant_id
    and barcode = trim(p_barcode)
  limit 1;

  if v_stock_id is null then
    if v_barcode_row.status <> 'AVAILABLE' then
      raise exception 'Barcode is already used';
    end if;

    insert into public.thrift_stocks (
      tenant_id,
      shipment_id,
      brand_name,
      category_id,
      type_id,
      section,
      shelf_id,
      color,
      size,
      condition,
      barcode,
      stock_type,
      quantity,
      box_id,
      product_weight,
      extra_weight,
      status,
      note,
      inserted_by,
      origin_unit_price,
      extra_origin_unit_price
    )
    values (
      p_tenant_id,
      p_shipment_id,
      coalesce(p_brand_name, ''),
      p_category_id,
      p_type_id,
      p_section::public.thrift_section,
      p_shelf_id,
      p_color,
      p_size,
      p_condition::public.thrift_condition,
      trim(p_barcode),
      'SINGLE',
      1,
      p_box_id,
      p_product_weight,
      p_extra_weight,
      'AVAILABLE',
      coalesce(p_note, ''),
      p_inserted_by,
      v_origin_unit_price,
      v_extra_origin_unit_price
    )
    returning id into v_stock_id;
  else
    update public.thrift_stocks
    set
      shipment_id = p_shipment_id,
      brand_name = coalesce(p_brand_name, ''),
      category_id = p_category_id,
      type_id = p_type_id,
      section = p_section::public.thrift_section,
      shelf_id = p_shelf_id,
      color = p_color,
      size = p_size,
      condition = p_condition::public.thrift_condition,
      box_id = p_box_id,
      product_weight = p_product_weight,
      extra_weight = p_extra_weight,
      note = coalesce(p_note, ''),
      origin_unit_price = v_origin_unit_price,
      extra_origin_unit_price = v_extra_origin_unit_price,
      inserted_by = p_inserted_by
    where id = v_stock_id;
  end if;

  insert into public.thrift_pricings (
    stock_id,
    listed_unit_price,
    inserted_by
  )
  values (
    v_stock_id,
    coalesce(v_listed_unit_price, 0),
    p_inserted_by
  )
  on conflict (stock_id) do update
  set
    listed_unit_price = excluded.listed_unit_price,
    inserted_by = excluded.inserted_by;

  update public.thrift_stock_images
  set image_url = p_image_url,
      inserted_by = p_inserted_by
  where stock_id = v_stock_id
    and is_primary = true;

  if not found then
    insert into public.thrift_stock_images (
      stock_id,
      image_url,
      is_primary,
      inserted_by
    )
    values (
      v_stock_id,
      p_image_url,
      true,
      p_inserted_by
    );
  end if;

  update public.thrift_barcodes
  set status = 'USED'
  where tenant_id = p_tenant_id
    and barcode_id = trim(p_barcode);

  return v_stock_id;
end;
$$;

ALTER FUNCTION "public"."register_thrift_stock_from_app"("p_tenant_id" bigint, "p_barcode" "text", "p_shipment_id" bigint, "p_image_url" "text", "p_brand_name" "text", "p_category_id" bigint, "p_type_id" bigint, "p_section" "text", "p_shelf_id" bigint, "p_color" "text", "p_size" "text", "p_condition" "text", "p_box_id" bigint, "p_product_weight" numeric, "p_extra_weight" numeric, "p_note" "text", "p_origin_purchase_price" numeric, "p_cost_of_goods_sold" numeric, "p_target_price" numeric, "p_listed_price" numeric, "p_inserted_by" "text", "p_origin_unit_price" numeric, "p_extra_origin_unit_price" numeric, "p_listed_unit_price" numeric, "p_extra_origin_purchase_expense" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."release_thrift_barcode_on_stock_delete"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if old.barcode is not null and trim(old.barcode) <> '' then
    update public.thrift_barcodes
    set status = 'AVAILABLE'
    where tenant_id = old.tenant_id
      and barcode_id = trim(old.barcode);
  end if;

  return old;
end;
$$;

ALTER FUNCTION "public"."release_thrift_barcode_on_stock_delete"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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

ALTER FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."release_thrift_stock_hold"("p_tenant_id" bigint, "p_stock_id" bigint) IS 'Release RESERVED thrift stock back to AVAILABLE; clears hold metadata via trigger.';

CREATE OR REPLACE FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") RETURNS TABLE("barcode_id" "text", "status" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_canonical text;
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

  v_canonical := public.resolve_thrift_barcode_id_internal(p_tenant_id, p_scanned_value);
  if v_canonical is null then
    return;
  end if;

  return query
  select b.barcode_id, b.status
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = v_canonical
  limit 1;
end;
$$;

ALTER FUNCTION "public"."resolve_thrift_barcode"("p_tenant_id" bigint, "p_scanned_value" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."resolve_thrift_barcode_id_internal"("p_tenant_id" bigint, "p_scanned_value" "text") RETURNS "text"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $_$
declare
  v_raw text;
  v_candidates text[] := array[]::text[];
  v_match text;
  v_tenant_prefix text;
  v_compact text[];
begin
  v_raw := upper(trim(regexp_replace(coalesce(p_scanned_value, ''), '[^A-Za-z0-9-]', '', 'g')));
  if v_raw = '' then
    return null;
  end if;

  v_tenant_prefix := lpad(p_tenant_id::text, 2, '0');
  v_candidates := array_append(v_candidates, v_raw);

  if v_raw ~ '^\d+-[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates,
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      split_part(v_raw, '-', 3) || '-' ||
      lpad(split_part(v_raw, '-', 4), 6, '0'));
  end if;

  if v_raw ~ '^[A-Z]{2}-\d{2}-\d+$' then
    v_candidates := array_append(v_candidates, v_tenant_prefix || '-' || v_raw);
    v_candidates := array_append(v_candidates,
      v_tenant_prefix || '-' ||
      split_part(v_raw, '-', 1) || '-' ||
      split_part(v_raw, '-', 2) || '-' ||
      lpad(split_part(v_raw, '-', 3), 6, '0'));
  end if;

  v_compact := regexp_match(v_raw, '^(\d+)([A-Z]{2})(\d{2})(\d+)$');
  if v_compact is not null then
    v_candidates := array_append(v_candidates,
      v_compact[1] || '-' || v_compact[2] || '-' || v_compact[3] || '-' || lpad(v_compact[4], 6, '0'));
  end if;

  select b.barcode_id
  into v_match
  from public.thrift_barcodes b
  where b.tenant_id = p_tenant_id
    and b.barcode_id = any (v_candidates)
  order by b.barcode_id
  limit 1;

  return v_match;
end;
$_$;

ALTER FUNCTION "public"."resolve_thrift_barcode_id_internal"("p_tenant_id" bigint, "p_scanned_value" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text" DEFAULT 'cashier'::"text", "p_notes" "text" DEFAULT NULL::"text", "p_force" boolean DEFAULT false, "p_return_courier_amount" numeric DEFAULT 0.00) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_item RECORD;
  v_reason TEXT;
  v_invoice_number TEXT;
  v_force BOOLEAN := COALESCE(p_force, false);
  v_has_returns BOOLEAN := FALSE;
  v_return_courier NUMERIC(12,2);
  v_event_at TIMESTAMPTZ := NOW();
  v_is_online BOOLEAN;
  v_uncollected_delivery NUMERIC(12,2) := 0.00;
  v_advance_amount NUMERIC(12,2) := 0.00;
  v_ledger_refund NUMERIC(12,2) := 0.00;
  v_pool_delivery NUMERIC(12,2) := 0.00;
  v_pool_packing NUMERIC(12,2) := 0.00;
  v_pool_return NUMERIC(12,2) := 0.00;
  v_total_value NUMERIC(12,2) := 0.00;
  v_line_count INT := 0;
  v_idx INT := 0;
  v_cum_delivery NUMERIC(12,2) := 0.00;
  v_cum_packing NUMERIC(12,2) := 0.00;
  v_cum_return NUMERIC(12,2) := 0.00;
  v_line RECORD;
  v_line_value NUMERIC(12,2);
  v_share NUMERIC;
  v_alloc_delivery NUMERIC(12,2);
  v_alloc_packing NUMERIC(12,2);
  v_alloc_return NUMERIC(12,2);
  v_inbound_shipment_id BIGINT;
BEGIN
  v_reason := upper(trim(COALESCE(p_reason, '')));
  -- Legacy RETURN → RTO (temporary compat)
  IF v_reason = 'RETURN' THEN
    v_reason := 'RTO';
  END IF;

  IF v_reason NOT IN ('RTO', 'STAFF_MISTAKE') THEN
    RAISE EXCEPTION 'Invalid revert reason %. Expected RTO or STAFF_MISTAKE', p_reason;
  END IF;

  v_return_courier := ROUND(COALESCE(p_return_courier_amount, 0.00), 2);
  IF v_return_courier < 0 THEN
    RAISE EXCEPTION 'return_courier_amount cannot be negative';
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
    RAISE EXCEPTION 'Invoice % is already % and cannot be reverted', p_invoice_id, v_invoice.status;
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.thrift_sales_returns r
    WHERE r.tenant_id = p_tenant_id
      AND r.invoice_id = p_invoice_id
  )
  INTO v_has_returns;

  IF v_has_returns THEN
    RAISE EXCEPTION
      'Invoice % already has return documents; use create_thrift_sales_return, not whole-invoice RTO/staff mistake.',
      p_invoice_id;
  END IF;

  v_is_online := COALESCE(v_invoice.sale_channel, 'IN_STORE') = 'ONLINE';

  IF v_reason = 'STAFF_MISTAKE' THEN
    IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'staff_mistake') THEN
      RAISE EXCEPTION 'Staff mistake revert requires thrift_sales staff_mistake permission';
    END IF;
  ELSE
    -- RTO
    IF COALESCE(v_invoice.delivery_status, '') = 'DELIVERED' THEN
      RAISE EXCEPTION
        'Invoice % is already DELIVERED — use post-accept return (Return items), not Mark RTO',
        p_invoice_id;
    END IF;

    IF v_force THEN
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'force_return') THEN
        RAISE EXCEPTION
          'Force RTO requires thrift_sales force_return permission for tenant %',
          p_tenant_id;
      END IF;
    ELSE
      IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return') THEN
        RAISE EXCEPTION 'Mark RTO requires thrift_sales return permission';
      END IF;
    END IF;

    IF NOT v_is_online THEN
      RAISE EXCEPTION 'Mark RTO applies to Online invoices only (use Return items for in-store)';
    END IF;
  END IF;

  v_invoice_number := v_invoice.invoice_number;

  -- Restore every sell line stock
  FOR v_item IN
    SELECT stock_id, quantity
    FROM public.thrift_sales_invoice_items
    WHERE invoice_id = p_invoice_id
      AND tenant_id = p_tenant_id
  LOOP
    UPDATE public.thrift_stocks
    SET
      quantity = quantity + GREATEST(v_item.quantity, 1),
      status = 'AVAILABLE'::public.thrift_stock_status,
      updated_at = NOW()
    WHERE id = v_item.stock_id
      AND tenant_id = p_tenant_id;
  END LOOP;

  IF v_reason = 'STAFF_MISTAKE' THEN
    DELETE FROM public.thrift_accounting_ledger
    WHERE tenant_id = p_tenant_id
      AND source = 'INVOICE'::public.thrift_ledger_source
      AND reference_id = p_invoice_id;

    DELETE FROM public.thrift_sales_pnl_lines
    WHERE tenant_id = p_tenant_id
      AND invoice_id = p_invoice_id;

    DELETE FROM public.thrift_sales_invoices
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;

    RETURN jsonb_build_object(
      'id', p_invoice_id,
      'invoice_number', v_invoice_number,
      'status', 'DELETED',
      'reason', 'STAFF_MISTAKE',
      'deleted', true,
      'counter_unchanged', true
    );
  END IF;

  -- ── RTO soft close ──────────────────────────────────────────────
  -- Ledger insert-only: REFUND item total minus non-refundable advance;
  -- LOSS uncollected customer delivery; LOSS return courier.
  -- Keep prior EXPENSE rows (shop packing / shop delivery). Advance is never paid back.

  v_advance_amount := ROUND(COALESCE(v_invoice.advance_amount, 0.00), 2);
  v_ledger_refund := GREATEST(
    0.00,
    ROUND(COALESCE(v_invoice.total_invoice_amount, 0.00) - v_advance_amount, 2)
  );

  IF v_ledger_refund > 0 THEN
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
      'REFUND'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_ledger_refund,
      'RTO refund for Sales Invoice #' || v_invoice_number
        || CASE WHEN v_advance_amount > 0
             THEN ' (advance retained ' || v_advance_amount::TEXT || ')'
             ELSE ''
           END
        || COALESCE(' — ' || NULLIF(trim(p_notes), ''), ''),
      p_reverted_by,
      v_event_at
    );
  END IF;

  IF upper(COALESCE(v_invoice.courier_paid_by, '')) = 'CUSTOMER'
     AND COALESCE(v_invoice.courier_amount, 0) > 0
  THEN
    v_uncollected_delivery := ROUND(v_invoice.courier_amount, 2);
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
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_uncollected_delivery,
      'uncollected_delivery',
      p_reverted_by,
      v_event_at
    );
  END IF;

  IF v_return_courier > 0 THEN
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
      'LOSS'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      p_invoice_id,
      v_return_courier,
      'return_courier',
      p_reverted_by,
      v_event_at
    );
  END IF;

  -- PnL: all lines → RTO; pool = full forward delivery + packing + return courier
  v_pool_delivery := ROUND(COALESCE(v_invoice.courier_amount, 0), 2);
  v_pool_packing := ROUND(COALESCE(v_invoice.packing_amount, 0), 2);
  v_pool_return := v_return_courier;

  SELECT
    COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0),
    COUNT(*)::INT
  INTO v_total_value, v_line_count
  FROM public.thrift_sales_invoice_items i
  WHERE i.tenant_id = p_tenant_id
    AND i.invoice_id = p_invoice_id;

  IF v_line_count = 0 THEN
    RAISE EXCEPTION 'Invoice % has no lines; cannot close RTO', p_invoice_id;
  END IF;

  FOR v_line IN
    SELECT
      i.id AS invoice_item_id,
      i.stock_id,
      i.quantity,
      ROUND(i.final_price * i.quantity, 2) AS sell_amount,
      s.shipment_id
    FROM public.thrift_sales_invoice_items i
    JOIN public.thrift_stocks s
      ON s.id = i.stock_id
     AND s.tenant_id = i.tenant_id
    WHERE i.tenant_id = p_tenant_id
      AND i.invoice_id = p_invoice_id
    ORDER BY i.id
  LOOP
    v_idx := v_idx + 1;
    v_inbound_shipment_id := v_line.shipment_id;
    IF v_inbound_shipment_id IS NULL THEN
      RAISE EXCEPTION
        'Stock item % has no inbound shipment; cannot write RTO PnL',
        v_line.stock_id;
    END IF;

    v_line_value := v_line.sell_amount;
    IF v_total_value > 0 THEN
      v_share := v_line_value / v_total_value;
    ELSE
      v_share := 1.0 / v_line_count;
    END IF;

    IF v_idx = v_line_count THEN
      v_alloc_delivery := ROUND(v_pool_delivery - v_cum_delivery, 2);
      v_alloc_packing := ROUND(v_pool_packing - v_cum_packing, 2);
      v_alloc_return := ROUND(v_pool_return - v_cum_return, 2);
    ELSE
      v_alloc_delivery := ROUND(v_pool_delivery * v_share, 2);
      v_alloc_packing := ROUND(v_pool_packing * v_share, 2);
      v_alloc_return := ROUND(v_pool_return * v_share, 2);
      v_cum_delivery := v_cum_delivery + v_alloc_delivery;
      v_cum_packing := v_cum_packing + v_alloc_packing;
      v_cum_return := v_cum_return + v_alloc_return;
    END IF;

    INSERT INTO public.thrift_sales_pnl_lines (
      tenant_id,
      invoice_id,
      invoice_item_id,
      stock_id,
      inbound_shipment_id,
      outcome,
      return_id,
      quantity,
      sell_amount,
      allocated_shop_delivery,
      allocated_shop_cod_fee,
      allocated_shop_packing,
      allocated_return_courier,
      allocated_fees_total,
      cogs_is_loss,
      event_at,
      event_date
    ) VALUES (
      p_tenant_id,
      p_invoice_id,
      v_line.invoice_item_id,
      v_line.stock_id,
      v_inbound_shipment_id,
      'RTO',
      NULL,
      v_line.quantity,
      0.00,
      v_alloc_delivery,
      0.00,
      v_alloc_packing,
      v_alloc_return,
      ROUND(v_alloc_delivery + v_alloc_packing + v_alloc_return, 2),
      FALSE,
      v_event_at,
      (v_event_at AT TIME ZONE 'UTC')::DATE
    )
    ON CONFLICT (invoice_item_id) DO UPDATE SET
      outcome = 'RTO',
      return_id = NULL,
      sell_amount = 0.00,
      allocated_shop_delivery = EXCLUDED.allocated_shop_delivery,
      allocated_shop_cod_fee = 0.00,
      allocated_shop_packing = EXCLUDED.allocated_shop_packing,
      allocated_return_courier = EXCLUDED.allocated_return_courier,
      allocated_fees_total = EXCLUDED.allocated_fees_total,
      cogs_is_loss = FALSE,
      event_at = EXCLUDED.event_at,
      event_date = EXCLUDED.event_date,
      updated_at = NOW();
  END LOOP;

  UPDATE public.thrift_sales_invoices
  SET
    status = 'RETURNED',
    payment_status = 'REFUNDED',
    close_reason = 'RTO',
    delivery_status = 'RETURNED',
    return_courier_amount = v_return_courier,
    economics_closed_at = v_event_at,
    cod_expected = NULL,
    cod_remitted_amount = NULL,
    cod_remitted_at = NULL,
    cod_remittance_ref = NULL,
    reverted_at = v_event_at,
    reverted_by = p_reverted_by,
    revert_reason = 'RTO',
    revert_notes = NULLIF(trim(p_notes), ''),
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'invoice_number', v_invoice_number,
    'status', 'RETURNED',
    'close_reason', 'RTO',
    'delivery_status', 'RETURNED',
    'payment_status', 'REFUNDED',
    'return_courier_amount', v_return_courier,
    'ledger_refund_amount', v_ledger_refund,
    'advance_retained', v_advance_amount,
    'reason', 'RTO',
    'deleted', false
  );
END;
$$;

ALTER FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."revert_thrift_sales_invoice"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_reason" "text", "p_reverted_by" "text", "p_notes" "text", "p_force" boolean, "p_return_courier_amount" numeric) IS 'RTO: soft-close; ledger REFUND excludes advance_amount (non-refundable). STAFF_MISTAKE: hard-delete. Legacy RETURN→RTO.';

CREATE OR REPLACE FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_customer_phone" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
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

ALTER FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) OWNER TO "postgres";

COMMENT ON FUNCTION "public"."search_thrift_available_stocks_for_sale"("p_tenant_id" bigint, "p_search" "text", "p_customer_phone" "text", "p_limit" integer) IS 'POS stock picker: default_sell_price = manual listed else ceil_thrift_retail_price(landed*(1+markup)); hold-aware.';

CREATE OR REPLACE FUNCTION "public"."thrift_barcode_sequence_sort_key"("p_barcode_id" "text") RETURNS TABLE("sort_prefix" "text", "sort_year" "text", "sort_seq" integer)
    LANGUAGE "sql" IMMUTABLE
    AS $_$
  select
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 1)
      else coalesce(p_barcode_id, '')
    end as sort_prefix,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 2)
      else ''
    end as sort_year,
    case
      when p_barcode_id ~ '^\d+-[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 4)::integer
      when p_barcode_id ~ '^[A-Z]{2}-\d{2}-\d+$'
        then split_part(p_barcode_id, '-', 3)::integer
      else 0
    end as sort_seq;
$_$;

ALTER FUNCTION "public"."thrift_barcode_sequence_sort_key"("p_barcode_id" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."thrift_courier_providers_guard_system"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be deleted';
    END IF;
    RETURN OLD;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    IF OLD.is_system THEN
      RAISE EXCEPTION 'System courier providers cannot be updated';
    END IF;
    IF NEW.is_system IS DISTINCT FROM FALSE OR NEW.tenant_id IS NULL THEN
      RAISE EXCEPTION 'Tenant courier providers must keep is_system=false and a tenant_id';
    END IF;
    IF NEW.tenant_id IS DISTINCT FROM OLD.tenant_id THEN
      RAISE EXCEPTION 'Cannot move courier provider across tenants';
    END IF;
    RETURN NEW;
  END IF;

  RETURN NEW;
END;
$$;

ALTER FUNCTION "public"."thrift_courier_providers_guard_system"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."thrift_stocks_enforce_hold_metadata"() RETURNS "trigger"
    LANGUAGE "plpgsql"
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

ALTER FUNCTION "public"."thrift_stocks_enforce_hold_metadata"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text" DEFAULT 'cashier'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_invoice public.thrift_sales_invoices%ROWTYPE;
  v_target TEXT;
  v_current TEXT;
  v_event_at TIMESTAMPTZ := NOW();
  v_pool_delivery NUMERIC(12,2) := 0.00;
  v_pool_cod NUMERIC(12,2) := 0.00;
  v_pool_packing NUMERIC(12,2) := 0.00;
  v_total_value NUMERIC(12,2) := 0.00;
  v_line_count INT := 0;
  v_idx INT := 0;
  v_cum_delivery NUMERIC(12,2) := 0.00;
  v_cum_cod NUMERIC(12,2) := 0.00;
  v_cum_packing NUMERIC(12,2) := 0.00;
  v_line RECORD;
  v_line_value NUMERIC(12,2);
  v_share NUMERIC;
  v_alloc_delivery NUMERIC(12,2);
  v_alloc_cod NUMERIC(12,2);
  v_alloc_packing NUMERIC(12,2);
  v_inbound_shipment_id BIGINT;
  v_pnl_exists BOOLEAN := FALSE;
  v_non_delivered_pnl INT := 0;
  v_deleted_pnl INT := 0;
  v_economics_closed_at TIMESTAMPTZ;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'create')
     AND NOT public.membership_has_module_action(p_tenant_id, 'thrift_sales', 'return')
  THEN
    RAISE EXCEPTION 'Updating delivery status requires thrift_sales create or return permission';
  END IF;

  v_target := upper(trim(COALESCE(p_delivery_status, '')));
  IF v_target NOT IN ('PENDING', 'READY', 'IN_TRANSIT', 'DELIVERED', 'RETURNED') THEN
    RAISE EXCEPTION 'Invalid delivery_status: %', p_delivery_status;
  END IF;

  SELECT * INTO v_invoice
  FROM public.thrift_sales_invoices
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice % not found for tenant %', p_invoice_id, p_tenant_id;
  END IF;

  IF COALESCE(v_invoice.sale_channel, 'IN_STORE') <> 'ONLINE' THEN
    RAISE EXCEPTION 'delivery_status applies to Online invoices only';
  END IF;

  IF v_invoice.status IS DISTINCT FROM 'ACTIVE' THEN
    RAISE EXCEPTION 'Cannot update delivery on invoice status %', v_invoice.status;
  END IF;

  IF v_target = 'RETURNED' THEN
    RAISE EXCEPTION
      'Set delivery RETURNED via revert_thrift_sales_invoice (RTO), not delivery advance';
  END IF;

  v_current := COALESCE(v_invoice.delivery_status, 'PENDING');
  v_economics_closed_at := v_invoice.economics_closed_at;

  IF v_current = v_target THEN
    RETURN jsonb_build_object(
      'id', v_invoice.id,
      'delivery_status', v_current,
      'unchanged', true,
      'economics_closed_at', v_invoice.economics_closed_at
    );
  END IF;

  -- Correction: undo mistaken deliver (only to IN_TRANSIT; reopen economics).
  IF v_current = 'DELIVERED' AND v_target = 'IN_TRANSIT' THEN
    SELECT COUNT(*)::INT
    INTO v_non_delivered_pnl
    FROM public.thrift_sales_pnl_lines p
    WHERE p.tenant_id = p_tenant_id
      AND p.invoice_id = p_invoice_id
      AND p.outcome IS DISTINCT FROM 'DELIVERED';

    IF v_non_delivered_pnl > 0 THEN
      RAISE EXCEPTION
        'Cannot move delivery from DELIVERED to IN_TRANSIT after return/RTO PnL exists';
    END IF;

    DELETE FROM public.thrift_sales_pnl_lines p
    WHERE p.tenant_id = p_tenant_id
      AND p.invoice_id = p_invoice_id
      AND p.outcome = 'DELIVERED';

    GET DIAGNOSTICS v_deleted_pnl = ROW_COUNT;

    UPDATE public.thrift_sales_invoices
    SET
      delivery_status = 'IN_TRANSIT',
      economics_closed_at = NULL,
      updated_at = NOW()
    WHERE id = p_invoice_id
      AND tenant_id = p_tenant_id;

    RETURN jsonb_build_object(
      'id', p_invoice_id,
      'delivery_status', 'IN_TRANSIT',
      'previous_delivery_status', v_current,
      'actor', COALESCE(NULLIF(trim(p_actor), ''), 'cashier'),
      'unchanged', false,
      'pnl_lines_deleted', v_deleted_pnl,
      'economics_closed_at', NULL
    );
  END IF;

  IF v_current = 'DELIVERED' AND v_target <> 'DELIVERED' THEN
    RAISE EXCEPTION 'Cannot move delivery from DELIVERED to %', v_target;
  END IF;

  UPDATE public.thrift_sales_invoices
  SET
    delivery_status = v_target,
    updated_at = NOW()
  WHERE id = p_invoice_id
    AND tenant_id = p_tenant_id;

  -- First DELIVERED: write PnL (shop-paid fee pools only). Never flip payment_status.
  IF v_target = 'DELIVERED' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.thrift_sales_pnl_lines p
      WHERE p.tenant_id = p_tenant_id
        AND p.invoice_id = p_invoice_id
    )
    INTO v_pnl_exists;

    IF NOT v_pnl_exists THEN
      v_pool_delivery := CASE
        WHEN upper(COALESCE(v_invoice.courier_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.courier_amount, 0), 2)
        ELSE 0.00
      END;
      v_pool_cod := CASE
        WHEN upper(COALESCE(v_invoice.cod_fee_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.cod_fee_amount, 0), 2)
        ELSE 0.00
      END;
      v_pool_packing := CASE
        WHEN upper(COALESCE(v_invoice.packing_paid_by, '')) = 'SHOP'
        THEN ROUND(COALESCE(v_invoice.packing_amount, 0), 2)
        ELSE 0.00
      END;

      SELECT
        COALESCE(SUM(ROUND(i.final_price * i.quantity, 2)), 0),
        COUNT(*)::INT
      INTO v_total_value, v_line_count
      FROM public.thrift_sales_invoice_items i
      WHERE i.tenant_id = p_tenant_id
        AND i.invoice_id = p_invoice_id;

      IF v_line_count = 0 THEN
        RAISE EXCEPTION 'Invoice % has no lines; cannot close economics', p_invoice_id;
      END IF;

      FOR v_line IN
        SELECT
          i.id AS invoice_item_id,
          i.stock_id,
          i.quantity,
          ROUND(i.final_price * i.quantity, 2) AS sell_amount,
          s.shipment_id
        FROM public.thrift_sales_invoice_items i
        JOIN public.thrift_stocks s
          ON s.id = i.stock_id
         AND s.tenant_id = i.tenant_id
        WHERE i.tenant_id = p_tenant_id
          AND i.invoice_id = p_invoice_id
        ORDER BY i.id
      LOOP
        v_idx := v_idx + 1;
        v_inbound_shipment_id := v_line.shipment_id;
        IF v_inbound_shipment_id IS NULL THEN
          RAISE EXCEPTION
            'Stock item % has no inbound shipment; cannot write PnL',
            v_line.stock_id;
        END IF;

        v_line_value := v_line.sell_amount;
        IF v_total_value > 0 THEN
          v_share := v_line_value / v_total_value;
        ELSE
          v_share := 1.0 / v_line_count;
        END IF;

        IF v_idx = v_line_count THEN
          v_alloc_delivery := ROUND(v_pool_delivery - v_cum_delivery, 2);
          v_alloc_cod := ROUND(v_pool_cod - v_cum_cod, 2);
          v_alloc_packing := ROUND(v_pool_packing - v_cum_packing, 2);
        ELSE
          v_alloc_delivery := ROUND(v_pool_delivery * v_share, 2);
          v_alloc_cod := ROUND(v_pool_cod * v_share, 2);
          v_alloc_packing := ROUND(v_pool_packing * v_share, 2);
          v_cum_delivery := v_cum_delivery + v_alloc_delivery;
          v_cum_cod := v_cum_cod + v_alloc_cod;
          v_cum_packing := v_cum_packing + v_alloc_packing;
        END IF;

        INSERT INTO public.thrift_sales_pnl_lines (
          tenant_id,
          invoice_id,
          invoice_item_id,
          stock_id,
          inbound_shipment_id,
          outcome,
          return_id,
          quantity,
          sell_amount,
          allocated_shop_delivery,
          allocated_shop_cod_fee,
          allocated_shop_packing,
          allocated_return_courier,
          allocated_fees_total,
          cogs_is_loss,
          event_at,
          event_date
        ) VALUES (
          p_tenant_id,
          p_invoice_id,
          v_line.invoice_item_id,
          v_line.stock_id,
          v_inbound_shipment_id,
          'DELIVERED',
          NULL,
          v_line.quantity,
          v_line_value,
          v_alloc_delivery,
          v_alloc_cod,
          v_alloc_packing,
          0.00,
          ROUND(v_alloc_delivery + v_alloc_cod + v_alloc_packing, 2),
          FALSE,
          v_event_at,
          (v_event_at AT TIME ZONE 'UTC')::DATE
        );
      END LOOP;

      UPDATE public.thrift_sales_invoices
      SET
        economics_closed_at = v_event_at,
        updated_at = NOW()
      WHERE id = p_invoice_id
        AND tenant_id = p_tenant_id;

      v_economics_closed_at := v_event_at;
    ELSIF v_invoice.economics_closed_at IS NULL THEN
      UPDATE public.thrift_sales_invoices
      SET
        economics_closed_at = v_event_at,
        updated_at = NOW()
      WHERE id = p_invoice_id
        AND tenant_id = p_tenant_id;

      v_economics_closed_at := v_event_at;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'id', p_invoice_id,
    'delivery_status', v_target,
    'previous_delivery_status', v_current,
    'actor', COALESCE(NULLIF(trim(p_actor), ''), 'cashier'),
    'unchanged', false,
    'economics_closed_at', CASE
      WHEN v_target = 'DELIVERED' THEN COALESCE(v_economics_closed_at, v_event_at)
      ELSE v_economics_closed_at
    END
  );
END;
$$;

ALTER FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") OWNER TO "postgres";

COMMENT ON FUNCTION "public"."update_thrift_sales_delivery_status"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_delivery_status" "text", "p_actor" "text") IS 'Advance Online parcel status. First DELIVERED inserts thrift_sales_pnl_lines (shop-paid fees) and sets economics_closed_at. DELIVERED→IN_TRANSIT deletes DELIVERED PnL and clears economics_closed_at. Never changes payment_status. RETURNED requires revert RTO.';

CREATE OR REPLACE TRIGGER "thrift_stocks_enforce_hold_metadata_trg" BEFORE INSERT OR UPDATE OF "status", "held_for_phone", "held_for_phone_normalized", "held_at" ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."thrift_stocks_enforce_hold_metadata"();

CREATE OR REPLACE TRIGGER "trg_release_thrift_barcode_on_stock_delete" AFTER DELETE ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."release_thrift_barcode_on_stock_delete"();

CREATE OR REPLACE TRIGGER "trg_thrift_accounting_ledger_updated_at" BEFORE UPDATE ON "public"."thrift_accounting_ledger" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_barcodes_updated_at" BEFORE UPDATE ON "public"."thrift_barcodes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_boxes_updated_at" BEFORE UPDATE ON "public"."thrift_boxes" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_categories_updated_at" BEFORE UPDATE ON "public"."thrift_categories" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_courier_providers_guard_system" BEFORE DELETE OR UPDATE ON "public"."thrift_courier_providers" FOR EACH ROW EXECUTE FUNCTION "public"."thrift_courier_providers_guard_system"();

CREATE OR REPLACE TRIGGER "trg_thrift_courier_providers_set_updated_at" BEFORE UPDATE ON "public"."thrift_courier_providers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_customers_updated_at" BEFORE UPDATE ON "public"."thrift_customers" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_invoice_counters_set_updated_at" BEFORE UPDATE ON "public"."thrift_invoice_counters" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_invoice_items_profit" BEFORE INSERT OR UPDATE ON "public"."thrift_invoice_items" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_thrift_item_net_profit"();

CREATE OR REPLACE TRIGGER "trg_thrift_invoice_items_total" AFTER INSERT OR DELETE OR UPDATE ON "public"."thrift_invoice_items" FOR EACH ROW EXECUTE FUNCTION "public"."calculate_thrift_invoice_total"();

CREATE OR REPLACE TRIGGER "trg_thrift_invoice_items_updated_at" BEFORE UPDATE ON "public"."thrift_invoice_items" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_invoices_updated_at" BEFORE UPDATE ON "public"."thrift_invoices" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_pricings_updated_at" BEFORE UPDATE ON "public"."thrift_pricings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_return_counters_set_updated_at" BEFORE UPDATE ON "public"."thrift_return_counters" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_sales_pnl_lines_set_updated_at" BEFORE UPDATE ON "public"."thrift_sales_pnl_lines" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_sales_returns_set_updated_at" BEFORE UPDATE ON "public"."thrift_sales_returns" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_settings_updated_at" BEFORE UPDATE ON "public"."thrift_settings" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_shelves_updated_at" BEFORE UPDATE ON "public"."thrift_shelves" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_shipments_updated_at" BEFORE UPDATE ON "public"."thrift_shipments" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_stock_images_updated_at" BEFORE UPDATE ON "public"."thrift_stock_images" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_stock_loss_ledger" AFTER UPDATE ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."log_thrift_stock_loss_ledger"();

CREATE OR REPLACE TRIGGER "trg_thrift_stock_measurements_updated_at" BEFORE UPDATE ON "public"."thrift_stock_measurements" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_stocks_updated_at" BEFORE UPDATE ON "public"."thrift_stocks" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();

CREATE OR REPLACE TRIGGER "trg_thrift_types_updated_at" BEFORE UPDATE ON "public"."thrift_types" FOR EACH ROW EXECUTE FUNCTION "public"."set_updated_at"();
