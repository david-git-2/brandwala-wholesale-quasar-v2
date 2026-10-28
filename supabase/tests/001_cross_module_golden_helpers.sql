-- Cross-module pgTAP helpers for golden scenarios A (dropship) and B (shipment AP).

CREATE OR REPLACE FUNCTION public._test_ensure_global_currency(
  p_code text,
  p_name text DEFAULT NULL,
  p_symbol text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_id bigint;
  v_code text := upper(trim(p_code));
BEGIN
  SELECT gc.id INTO v_id FROM public.global_currencies gc WHERE gc.code = v_code LIMIT 1;
  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  INSERT INTO public.global_currencies (name, country, code, symbol, is_active, is_system)
  VALUES (
    coalesce(nullif(trim(p_name), ''), v_code),
    v_code,
    v_code,
    coalesce(nullif(trim(p_symbol), ''), v_code),
    true,
    true
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public._test_enable_tenant_module(p_tenant_id bigint, p_module_key text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.modules m WHERE m.key = p_module_key) THEN
    INSERT INTO public.modules (key, name, is_active)
    VALUES (p_module_key, initcap(replace(p_module_key, '_', ' ')), true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.module_actions ma
    WHERE ma.module_key = p_module_key
      AND ma.action = 'view'
      AND ma.scope = 'app'
  ) THEN
    INSERT INTO public.module_actions (module_key, action, scope, is_active)
    VALUES (p_module_key, 'view', 'app', true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.module_actions ma
    WHERE ma.module_key = p_module_key
      AND ma.action = 'edit'
      AND ma.scope = 'app'
  ) THEN
    INSERT INTO public.module_actions (module_key, action, scope, is_active)
    VALUES (p_module_key, 'edit', 'app', true);
  END IF;

  INSERT INTO public.tenant_modules (tenant_id, module_key, is_active)
  VALUES (p_tenant_id, p_module_key, true)
  ON CONFLICT (tenant_id, module_key)
  DO UPDATE SET is_active = true, updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public._test_bootstrap_dropship_golden_a(p_ctx jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_tenant bigint := (p_ctx ->> 'tenant_id')::bigint;
  v_merchant_profile bigint := (p_ctx ->> 'customer_profile_id')::bigint;
  v_point bigint := (p_ctx ->> 'cashbook_point_id')::bigint;
  v_bdt bigint;
  v_shop_id bigint;
  v_courier_id uuid;
  v_product_id bigint;
  v_order_id bigint;
  v_bill public.bills;
  v_ap jsonb;
  v_deliver jsonb;
  v_order_no text := 'PGTAP-A-' || substr(md5(random()::text), 1, 8);
BEGIN
  PERFORM public._test_pgtap_auth();

  PERFORM public._test_enable_tenant_module(v_tenant, 'shop_order_mgmt');
  PERFORM public._test_enable_tenant_module(v_tenant, 'global_invoice');

  PERFORM public.upsert_membership_grant(
    (
      SELECT m.id
      FROM public.memberships m
      WHERE m.tenant_id = v_tenant
        AND lower(trim(m.email)) = 'pgtap+money@kernel.test'
      LIMIT 1
    ),
    'shop_order_mgmt',
    'view',
    'allow'
  );

  PERFORM public.upsert_membership_grant(
    (
      SELECT m.id
      FROM public.memberships m
      WHERE m.tenant_id = v_tenant
        AND lower(trim(m.email)) = 'pgtap+money@kernel.test'
      LIMIT 1
    ),
    'shop_order_mgmt',
    'edit',
    'allow'
  );

  v_bdt := public._test_ensure_global_currency('BDT', 'Bangladesh Taka', '৳');

  INSERT INTO public.shops (
    tenant_id,
    parent_tenant_id,
    name,
    slug,
    shop_type,
    order_mode,
    is_negotiable,
    buy_currency_id,
    sell_currency_id,
    default_currency_id,
    pricing_method,
    quantity_display_mode,
    is_active
  )
  VALUES (
    v_tenant,
    v_tenant,
    'pgTAP Dropship',
    'pgtap-ds-' || substr(md5(random()::text), 1, 8),
    'dropship'::public.shop_type_enum,
    'checkout_fixed'::public.shop_order_mode_enum,
    false,
    v_bdt,
    v_bdt,
    v_bdt,
    'direct_cost',
    'original',
    true
  )
  RETURNING id INTO v_shop_id;

  INSERT INTO public.courier_services (
    tenant_id,
    code,
    name,
    is_active,
    cod_fee_mode,
    inside_dhaka_fee,
    outside_dhaka_fee
  )
  VALUES (
    v_tenant,
    'PGTAP-C-' || substr(md5(random()::text), 1, 6),
    'pgTAP Courier',
    true,
    'none',
    80.00,
    120.00
  )
  RETURNING id INTO v_courier_id;

  INSERT INTO public.products (
    name,
    parent_tenant_id,
    inserted_by_tenant_id,
    source,
    is_available
  )
  VALUES (
    'pgTAP Dropship SKU',
    v_tenant,
    v_tenant,
    'website',
    true
  )
  RETURNING id INTO v_product_id;

  INSERT INTO public.shop_orders (
    tenant_id,
    parent_tenant_id,
    shop_id,
    order_no,
    name,
    shop_type_snapshot,
    order_mode_snapshot,
    status,
    profile_id,
    created_by_email,
    collection_source,
    cod_collect_amount,
    delivery_charge_amount,
    cod_charge_amount,
    sender_name,
    pickup_phone,
    pickup_address,
    recipient_name,
    recipient_phone,
    shipping_address,
    delivery_zone,
    courier_service_id,
    courier_name
  )
  VALUES (
    v_tenant,
    v_tenant,
    v_shop_id,
    v_order_no,
    'Golden A order',
    'dropship'::public.shop_type_enum,
    'checkout_fixed'::public.shop_order_mode_enum,
    'ready_for_pickup'::public.shop_order_status,
    v_merchant_profile,
    'pgtap+money@kernel.test',
    'recipient'::public.collection_source_type,
    2200.00,
    80.00,
    0.00,
    'pgTAP Sender',
    '+8801700000000',
    'Dhaka pickup',
    'Recipient',
    '+8801800000000',
    'Dhaka ship',
    'inside_dhaka',
    v_courier_id,
    'pgTAP Courier'
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.shop_order_items (
    order_id,
    product_id,
    name,
    quantity,
    confirmed_quantity,
    customer_sell_price_amount,
    customer_sell_price_currency_id,
    final_price_amount,
    final_price_currency_id,
    cost_price_amount,
    cost_price_currency_id
  )
  VALUES (
    v_order_id,
    v_product_id,
    'pgTAP line',
    1,
    1,
    1500.0000,
    v_bdt,
    1500.0000,
    v_bdt,
    900.0000,
    v_bdt
  );

  v_bill := public.create_sales_invoice(
    v_tenant,
    'INV-DS-' || v_order_no,
    'dropship'::public.global_invoice_type,
    v_merchant_profile
  );

  INSERT INTO public.bill_lines (
    parent_tenant_id,
    invoice_id,
    line_kind,
    name_snapshot,
    quantity,
    sell_price_amount,
    line_discount_amount,
    line_total_amount
  )
  VALUES (
    v_bill.parent_tenant_id,
    v_bill.id,
    'description',
    'pgTAP dropship sales',
    1,
    1500.00,
    0,
    1500.00
  );

  UPDATE public.bills
  SET
    subtotal_amount = 1500.00,
    total_amount = 1500.00,
    due_amount = 1500.00,
    shop_order_id = v_order_id,
    collection_source = 'profile'::public.collection_source_type,
    updated_at = now()
  WHERE id = v_bill.id;

  PERFORM public.stamp_bill_kernel_fields(v_bill.id);
  PERFORM public.issue_bill(v_bill.id);

  UPDATE public.shop_orders
  SET
    global_invoice_id = v_bill.id,
    status = 'shipped'::public.shop_order_status,
    updated_at = now()
  WHERE id = v_order_id;

  v_ap := public.upsert_dropship_courier_ap_bill(v_order_id, false);
  IF coalesce(v_ap ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'golden A courier AP failed: %', v_ap;
  END IF;

  v_deliver := public.mark_dropship_order_delivered(
    v_tenant,
    v_order_id,
    jsonb_build_object(
      'collected_cod_amount', 2200,
      'charge_lines', '[]'::jsonb
    )
  );
  IF coalesce(v_deliver ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'golden A deliver failed: %', v_deliver;
  END IF;

  RETURN p_ctx
    || jsonb_build_object(
      'dropship_order_id', v_order_id,
      'dropship_merchant_profile_id', v_merchant_profile,
      'dropship_courier_id', v_courier_id
    );
END;
$$;

CREATE OR REPLACE FUNCTION public._test_bootstrap_shipment_ap_fx(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent bigint := public.resolve_parent_tenant_id(p_tenant_id);
  v_usd bigint;
  v_gbp bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_shipment_id bigint;
  v_sync jsonb;
  v_material_bill bigint;
  v_freight_bill bigint;
  v_cargo_profile bigint;
BEGIN
  PERFORM public._test_pgtap_auth();

  v_usd := public._test_ensure_global_currency('USD', 'US Dollar', '$');
  v_gbp := public._test_ensure_global_currency('GBP', 'British Pound', '£');

  IF NOT EXISTS (SELECT 1 FROM public.markets mk WHERE mk.code = 'US') THEN
    INSERT INTO public.markets (name, code, region, is_active, is_system)
    VALUES ('United States', 'US', 'Americas', true, true);
  END IF;

  INSERT INTO public.vendors (name, code, market_code, parent_tenant_id)
  VALUES ('pgTAP Vendor', 'PGV-' || substr(md5(random()::text), 1, 6), 'US', v_parent)
  RETURNING id INTO v_vendor_id;

  INSERT INTO public.cargo_companies (parent_tenant_id, name, code, is_active)
  VALUES (v_parent, 'pgTAP Cargo', 'PGC-' || substr(md5(random()::text), 1, 6), true)
  RETURNING id INTO v_cargo_id;

  INSERT INTO public.global_shipments (
    parent_tenant_id,
    name,
    status,
    vendor_id,
    cargo_company_id,
    stock_ready,
    costs_locked
  )
  VALUES (
    v_parent,
    'S-42 pgTAP',
    'received',
    v_vendor_id,
    v_cargo_id,
    true,
    false
  )
  RETURNING id INTO v_shipment_id;

  INSERT INTO public.global_shipment_cost_entries (
    parent_tenant_id,
    shipment_id,
    amount,
    currency_id,
    cost_bucket,
    cost_component,
    description
  )
  VALUES
    (v_parent, v_shipment_id, 100.00, v_usd, 'material', 'subtotal', 'Material USD'),
    (v_parent, v_shipment_id, 50.00, v_gbp, 'freight', 'subtotal', 'Freight GBP');

  PERFORM set_config('app.allow_costs_lock', '1', true);
  UPDATE public.global_shipments
  SET
    costs_locked = true,
    costs_locked_at = now(),
    updated_at = now()
  WHERE id = v_shipment_id;

  v_sync := public.sync_shipment_ap_bills(v_shipment_id);
  IF coalesce(v_sync ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'golden B sync_shipment_ap_bills failed: %', v_sync;
  END IF;

  PERFORM public.issue_shipment_ap_bills(v_shipment_id);

  v_sync := jsonb_build_object('success', true);

  SELECT b.id INTO v_material_bill
  FROM public.bills b
  WHERE b.parent_tenant_id = v_parent
    AND b.source_type = 'shipment_cost'
    AND b.source_id = v_shipment_id::text
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.source_key = 'material'
  ORDER BY b.id DESC
  LIMIT 1;

  SELECT b.id INTO v_freight_bill
  FROM public.bills b
  WHERE b.parent_tenant_id = v_parent
    AND b.source_type = 'shipment_cost'
    AND b.source_id = v_shipment_id::text
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.source_key = 'freight'
  ORDER BY b.id DESC
  LIMIT 1;

  IF v_material_bill IS NULL OR v_freight_bill IS NULL THEN
    RAISE EXCEPTION 'golden B: expected material and freight AP bills';
  END IF;

  SELECT p.id INTO v_cargo_profile
  FROM public.profiles p
  WHERE p.parent_tenant_id = v_parent
    AND p.profile_type = 'cargo'::public.profile_party_type
    AND p.subject_id = v_cargo_id
  LIMIT 1;

  IF v_cargo_profile IS NULL THEN
    RAISE EXCEPTION 'golden B: cargo profile missing after sync';
  END IF;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'parent_tenant_id', v_parent,
    'shipment_id', v_shipment_id,
    'material_bill_id', v_material_bill,
    'freight_bill_id', v_freight_bill,
    'cargo_profile_id', v_cargo_profile
  );
END;
$$;

BEGIN;
SELECT plan(2);

SELECT has_function('public', '_test_bootstrap_dropship_golden_a', ARRAY['jsonb']);
SELECT has_function('public', '_test_bootstrap_shipment_ap_fx', ARRAY['bigint']);

SELECT finish();
ROLLBACK;
