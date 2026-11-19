-- Cross-module pgTAP helpers for golden scenario A (dropship) and shipment 54 money golden.

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
    tenant_id,
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
    tenant_id,
    invoice_id,
    line_kind,
    name_snapshot,
    quantity,
    sell_price_amount,
    line_discount_amount,
    line_total_amount
  )
  VALUES (
    v_bill.tenant_id,
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

DROP FUNCTION IF EXISTS public._test_bootstrap_shipment_ap_fx(bigint);

CREATE OR REPLACE FUNCTION public._test_bootstrap_shipment_s54(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_workspace bigint := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_shipment_id bigint;
  v_material jsonb;
  v_freight jsonb;
  v_material_bill_id bigint;
  v_freight_bill_id bigint;
BEGIN
  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_workspace);

  PERFORM public._test_ensure_global_currency('GBP', 'British Pound Sterling', '£');

  IF NOT EXISTS (SELECT 1 FROM public.markets mk WHERE mk.code = 'GB') THEN
    INSERT INTO public.markets (name, code, region, is_active, is_system)
    VALUES ('United Kingdom', 'GB', 'Europe', true, true);
  END IF;

  ALTER TABLE public.vendors DISABLE TRIGGER USER;
  INSERT INTO public.vendors (name, code, market_code, tenant_id)
  VALUES ('pgTAP S54 Vendor', 'PGS54V-' || substr(md5(random()::text), 1, 6), 'GB', v_workspace)
  RETURNING id INTO v_vendor_id;
  ALTER TABLE public.vendors ENABLE TRIGGER USER;

  PERFORM public.upsert_profile_for_party(
    v_workspace,
    'vendor'::public.profile_party_type,
    v_vendor_id,
    'pgTAP S54 Vendor',
    NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );

  ALTER TABLE public.cargo_companies DISABLE TRIGGER USER;
  INSERT INTO public.cargo_companies (tenant_id, name, code, is_active)
  VALUES (v_workspace, 'pgTAP S54 Cargo', 'PGS54C-' || substr(md5(random()::text), 1, 6), true)
  RETURNING id INTO v_cargo_id;
  ALTER TABLE public.cargo_companies ENABLE TRIGGER USER;

  PERFORM public.upsert_profile_for_party(
    v_workspace,
    'cargo'::public.profile_party_type,
    v_cargo_id,
    'pgTAP S54 Cargo',
    NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );

  INSERT INTO public.global_shipments (
    tenant_id,
    name,
    type,
    status,
    vendor_id,
    cargo_company_id,
    stock_ready,
    costs_locked,
    total_weight_kg,
    received_weight
  )
  VALUES (
    v_workspace,
    'Golden Shipment S54',
    'international'::public.global_shipment_type,
    'received',
    v_vendor_id,
    v_cargo_id,
    true,
    false,
    304,
    304
  )
  RETURNING id INTO v_shipment_id;

  INSERT INTO public.global_shipment_items (
    shipment_id, name, ordered_quantity, purchase_price,
    product_weight, package_weight, add_method
  )
  VALUES
    (
      v_shipment_id, 'Astral Cream 50ML', 300, 1.25,
      50, 24.98, 'manual'::public.global_shipment_item_add_method
    ),
    (
      v_shipment_id, 'Astral Cream 200ML', 1200, 3.6,
      200, 34.588, 'manual'::public.global_shipment_item_add_method
    );

  v_material := public.create_shipment_ap_bill_v2(
    v_shipment_id,
    'material',
    jsonb_build_object(
      'currency_code', 'GBP',
      'source_key_suffix', 'golden',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'amount', 4695,
          'cost_component', 'subtotal',
          'description', 'Material GBP'
        )
      )
    )
  );
  v_material_bill_id := NULLIF(v_material ->> 'bill_id', '')::bigint;

  v_freight := public.create_shipment_ap_bill_v2(
    v_shipment_id,
    'freight',
    jsonb_build_object(
      'currency_code', 'GBP',
      'source_key_suffix', 'golden',
      'lines', jsonb_build_array(
        jsonb_build_object(
          'amount', 2050.78,
          'cost_component', 'subtotal',
          'description', 'Freight GBP'
        )
      )
    )
  );
  v_freight_bill_id := NULLIF(v_freight ->> 'bill_id', '')::bigint;

  IF v_material_bill_id IS NULL OR v_freight_bill_id IS NULL THEN
    RAISE EXCEPTION 's54 bootstrap: AP bill create failed';
  END IF;

  PERFORM public.issue_shipment_ap_bill_v2(v_shipment_id, v_material_bill_id);
  PERFORM public.issue_shipment_ap_bill_v2(v_shipment_id, v_freight_bill_id);

  RETURN jsonb_build_object(
    'tenant_id', v_workspace,
    'shipment_id', v_shipment_id,
    'material_bill_id', v_material_bill_id,
    'freight_bill_id', v_freight_bill_id,
    'vendor_id', v_vendor_id,
    'cargo_company_id', v_cargo_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._test_flush_kernel_pays()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
BEGIN
  SET CONSTRAINTS money_kernel.trg_pays_apply IMMEDIATE;
  SET CONSTRAINTS money_kernel.trg_pays_apply DEFERRED;
END;
$$;

CREATE OR REPLACE FUNCTION public._test_shipment_s54_fund_and_pay(p_ctx jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_tenant bigint := (p_ctx ->> 'tenant_id')::bigint;
  v_shipment bigint := (p_ctx ->> 'shipment_id')::bigint;
  v_material_bill bigint := (p_ctx ->> 'material_bill_id')::bigint;
  v_freight_bill bigint := (p_ctx ->> 'freight_bill_id')::bigint;
  v_payer bigint;
  v_mat_pot bigint;
  v_fre_pot bigint;
  v_dep jsonb;
  v_mat_bal numeric;
BEGIN
  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_tenant);
  PERFORM public._test_enable_tenant_module(v_tenant, 'payments');
  PERFORM public._test_enable_tenant_module(v_tenant, 'global_invoice');

  v_payer := NULLIF(p_ctx ->> 'tenant_profile_id', '')::bigint;
  IF v_payer IS NULL THEN
    SELECT p.id INTO v_payer
    FROM public.profiles p
    WHERE p.tenant_id = v_tenant
      AND p.profile_type = 'tenant'::public.profile_party_type
      AND p.subject_id = v_tenant
    LIMIT 1;
  END IF;
  IF v_payer IS NULL THEN
    RAISE EXCEPTION 's54 fund: tenant payer profile missing';
  END IF;

  v_dep := public.rpc_deposit(
    v_tenant, v_payer, 5000, 'GBP', NULL, '{}'::jsonb,
    'pgtap-s54-mat-' || v_shipment::text, 168::numeric, 'main'
  );
  v_mat_pot := NULLIF(v_dep ->> 'cash_bundle_id', '')::bigint;

  v_dep := public.rpc_deposit(
    v_tenant, v_payer, 3000, 'GBP', NULL, '{}'::jsonb,
    'pgtap-s54-fre-' || v_shipment::text, 166::numeric, 'main'
  );
  v_fre_pot := NULLIF(v_dep ->> 'cash_bundle_id', '')::bigint;

  PERFORM public._test_flush_kernel_pays();

  IF v_mat_pot IS NULL OR v_fre_pot IS NULL THEN
    RAISE EXCEPTION 's54 fund: deposit failed';
  END IF;

  SELECT cb.amount INTO v_mat_bal
    FROM money_kernel.cash_bundles cb
   WHERE cb.id = v_mat_pot;
  IF coalesce(v_mat_bal, 0) < 4695 THEN
    RAISE EXCEPTION 's54 fund: material bundle balance % (deposit %)', v_mat_bal, v_dep;
  END IF;

  PERFORM public.rpc_pay_bills(
    v_tenant,
    v_payer,
    v_mat_pot,
    4695,
    jsonb_build_array(jsonb_build_object('bill_id', v_material_bill, 'amount', 4695)),
    NULL,
    NULL,
    '{}'::jsonb,
    'pgtap-s54-pay-mat-' || v_shipment::text
  );

  PERFORM public.rpc_pay_bills(
    v_tenant,
    v_payer,
    v_fre_pot,
    2050.78,
    jsonb_build_array(jsonb_build_object('bill_id', v_freight_bill, 'amount', 2050.78)),
    NULL,
    NULL,
    '{}'::jsonb,
    'pgtap-s54-pay-fre-' || v_shipment::text
  );

  PERFORM public._test_flush_kernel_pays();

  -- Avoid kernel + legacy double-count in shipment_ap_bucket_paid_totals (mirror on public.bills ids).
  DELETE FROM public.pay_allocations pa
  USING public.bills b
  WHERE pa.global_invoice_id = b.id
    AND b.source_type = 'shipment_cost'
    AND b.source_id = v_shipment::text;

  PERFORM public.refresh_global_shipment_fx_from_ap_payments(v_shipment);
  PERFORM public.stamp_global_shipment_landed_costs(v_shipment);

  RETURN p_ctx || jsonb_build_object(
    'material_pot_id', v_mat_pot,
    'freight_pot_id', v_fre_pot
  );
END;
$$;

-- Golden Shipment 45 scenario: twin material AP + freight (GBP), vendor credit note + refund (tenant 15 / shipment 45 shape).
CREATE OR REPLACE FUNCTION public._test_bootstrap_shipment_s45(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_workspace bigint := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_shipment_id bigint;
  v_lost_item_id bigint;
  v_mat_a jsonb;
  v_mat_b jsonb;
  v_freight jsonb;
  v_material_bill_a bigint;
  v_material_bill_b bigint;
  v_freight_bill_id bigint;
BEGIN
  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_workspace);

  PERFORM public._test_ensure_global_currency('GBP', 'British Pound Sterling', '£');

  IF NOT EXISTS (SELECT 1 FROM public.markets mk WHERE mk.code = 'GB') THEN
    INSERT INTO public.markets (name, code, region, is_active, is_system)
    VALUES ('United Kingdom', 'GB', 'Europe', true, true);
  END IF;

  ALTER TABLE public.vendors DISABLE TRIGGER USER;
  INSERT INTO public.vendors (name, code, market_code, tenant_id)
  VALUES ('pgTAP S45 Vendor', 'PGS45V-' || substr(md5(random()::text), 1, 6), 'GB', v_workspace)
  RETURNING id INTO v_vendor_id;
  ALTER TABLE public.vendors ENABLE TRIGGER USER;

  PERFORM public.upsert_profile_for_party(
    v_workspace, 'vendor'::public.profile_party_type, v_vendor_id,
    'pgTAP S45 Vendor', NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );

  ALTER TABLE public.cargo_companies DISABLE TRIGGER USER;
  INSERT INTO public.cargo_companies (tenant_id, name, code, is_active)
  VALUES (v_workspace, 'pgTAP S45 Cargo', 'PGS45C-' || substr(md5(random()::text), 1, 6), true)
  RETURNING id INTO v_cargo_id;
  ALTER TABLE public.cargo_companies ENABLE TRIGGER USER;

  PERFORM public.upsert_profile_for_party(
    v_workspace, 'cargo'::public.profile_party_type, v_cargo_id,
    'pgTAP S45 Cargo', NULL, NULL, '+880', NULL, false, NULL, true, NULL
  );

  INSERT INTO public.global_shipments (
    tenant_id, name, type, status, vendor_id, cargo_company_id,
    stock_ready, costs_locked, total_weight_kg, received_weight
  )
  VALUES (
    v_workspace, 'Golden Shipment 45', 'international'::public.global_shipment_type,
    'received', v_vendor_id, v_cargo_id, true, false, 145, 145
  )
  RETURNING id INTO v_shipment_id;

  INSERT INTO public.global_shipment_items (
    shipment_id, name, ordered_quantity, purchase_price,
    product_weight, package_weight, add_method
  )
  VALUES
    (
      v_shipment_id, 'Vaseline Lip Therapy Emily In Paris', 12, 0.91,
      12, 1, 'manual'::public.global_shipment_item_add_method
    ),
    (
      v_shipment_id, 'Assorted wholesale SKU mix', 1089, 1.05,
      100, 50, 'manual'::public.global_shipment_item_add_method
    );

  SELECT gsi.id INTO v_lost_item_id
  FROM public.global_shipment_items gsi
  WHERE gsi.shipment_id = v_shipment_id
    AND gsi.name = 'Vaseline Lip Therapy Emily In Paris'
  LIMIT 1;

  v_mat_a := public.create_shipment_ap_bill_v2(
    v_shipment_id, 'material',
    jsonb_build_object(
      'currency_code', 'GBP',
      'source_key_suffix', 'golden-a',
      'lines', jsonb_build_array(
        jsonb_build_object('amount', 797.64, 'cost_component', 'subtotal', 'description', 'Section A material')
      )
    )
  );
  v_material_bill_a := NULLIF(v_mat_a ->> 'bill_id', '')::bigint;

  v_mat_b := public.create_shipment_ap_bill_v2(
    v_shipment_id, 'material',
    jsonb_build_object(
      'currency_code', 'GBP',
      'source_key_suffix', 'golden-b',
      'lines', jsonb_build_array(
        jsonb_build_object('amount', 764.16, 'cost_component', 'subtotal', 'description', 'Section B material')
      )
    )
  );
  v_material_bill_b := NULLIF(v_mat_b ->> 'bill_id', '')::bigint;

  v_freight := public.create_shipment_ap_bill_v2(
    v_shipment_id, 'freight',
    jsonb_build_object(
      'currency_code', 'GBP',
      'source_key_suffix', 'golden',
      'lines', jsonb_build_array(
        jsonb_build_object('amount', 977.50, 'cost_component', 'subtotal', 'description', 'Freight GBP')
      )
    )
  );
  v_freight_bill_id := NULLIF(v_freight ->> 'bill_id', '')::bigint;

  IF v_material_bill_a IS NULL OR v_material_bill_b IS NULL OR v_freight_bill_id IS NULL THEN
    RAISE EXCEPTION 's45 bootstrap: AP bill create failed';
  END IF;

  PERFORM public.issue_shipment_ap_bill_v2(v_shipment_id, v_material_bill_a);
  PERFORM public.issue_shipment_ap_bill_v2(v_shipment_id, v_material_bill_b);
  PERFORM public.issue_shipment_ap_bill_v2(v_shipment_id, v_freight_bill_id);

  RETURN jsonb_build_object(
    'tenant_id', v_workspace,
    'shipment_id', v_shipment_id,
    'material_bill_a_id', v_material_bill_a,
    'material_bill_b_id', v_material_bill_b,
    'freight_bill_id', v_freight_bill_id,
    'lost_item_id', v_lost_item_id,
    'vendor_id', v_vendor_id,
    'cargo_company_id', v_cargo_id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._test_shipment_s45_fund_pay_and_credit(p_ctx jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_tenant bigint := (p_ctx ->> 'tenant_id')::bigint;
  v_shipment bigint := (p_ctx ->> 'shipment_id')::bigint;
  v_mat_a bigint := (p_ctx ->> 'material_bill_a_id')::bigint;
  v_mat_b bigint := (p_ctx ->> 'material_bill_b_id')::bigint;
  v_freight_bill bigint := (p_ctx ->> 'freight_bill_id')::bigint;
  v_lost_item_id bigint := NULLIF(p_ctx ->> 'lost_item_id', '')::bigint;
  v_payer bigint;
  v_point_id bigint;
  v_mat_pot bigint;
  v_fre_pot bigint;
  v_dep jsonb;
  v_cn jsonb;
  v_cn_id bigint;
  v_landed numeric;
  v_cash_loc bigint;
BEGIN
  PERFORM public._test_pgtap_auth();
  PERFORM public._test_set_workspace_tenant(v_tenant);
  PERFORM public._test_enable_tenant_module(v_tenant, 'payments');
  PERFORM public._test_enable_tenant_module(v_tenant, 'global_invoice');
  PERFORM public._test_enable_tenant_module(v_tenant, 'bills_pays');
  PERFORM public._test_enable_tenant_module(v_tenant, 'reporting_treasury');

  v_payer := NULLIF(p_ctx ->> 'tenant_profile_id', '')::bigint;
  IF v_payer IS NULL THEN
    SELECT p.id INTO v_payer
    FROM public.profiles p
    WHERE p.tenant_id = v_tenant
      AND p.profile_type = 'tenant'::public.profile_party_type
      AND p.subject_id = v_tenant
    LIMIT 1;
  END IF;
  IF v_payer IS NULL THEN
    RAISE EXCEPTION 's45 fund: tenant payer profile missing';
  END IF;

  v_point_id := NULLIF(p_ctx ->> 'cashbook_point_id', '')::bigint;
  IF v_point_id IS NULL THEN
    RAISE EXCEPTION 's45 fund: cashbook_point_id required on context';
  END IF;

  v_dep := public.rpc_deposit(
    v_tenant, v_payer, 2500, 'GBP', NULL, '{}'::jsonb,
    'pgtap-s45-mat-' || v_shipment::text, 168::numeric, 'main'
  );
  v_mat_pot := NULLIF(v_dep ->> 'cash_bundle_id', '')::bigint;

  v_dep := public.rpc_deposit(
    v_tenant, v_payer, 1200, 'GBP', NULL, '{}'::jsonb,
    'pgtap-s45-fre-' || v_shipment::text, 166::numeric, 'main'
  );
  v_fre_pot := NULLIF(v_dep ->> 'cash_bundle_id', '')::bigint;

  PERFORM public._test_flush_kernel_pays();

  PERFORM public.rpc_pay_bills(
    v_tenant, v_payer, v_mat_pot, 797.64,
    jsonb_build_array(jsonb_build_object('bill_id', v_mat_a, 'amount', 797.64)),
    NULL, NULL, '{}'::jsonb, 'pgtap-s45-pay-mat-a-' || v_shipment::text
  );
  PERFORM public.rpc_pay_bills(
    v_tenant, v_payer, v_mat_pot, 764.16,
    jsonb_build_array(jsonb_build_object('bill_id', v_mat_b, 'amount', 764.16)),
    NULL, NULL, '{}'::jsonb, 'pgtap-s45-pay-mat-b-' || v_shipment::text
  );
  PERFORM public.rpc_pay_bills(
    v_tenant, v_payer, v_fre_pot, 977.50,
    jsonb_build_array(jsonb_build_object('bill_id', v_freight_bill, 'amount', 977.50)),
    NULL, NULL, '{}'::jsonb, 'pgtap-s45-pay-fre-' || v_shipment::text
  );

  PERFORM public._test_flush_kernel_pays();

  DELETE FROM public.pay_allocations pa
  USING public.bills b
  WHERE pa.global_invoice_id = b.id
    AND b.source_type = 'shipment_cost'
    AND b.source_id = v_shipment::text;

  PERFORM public.refresh_global_shipment_fx_from_ap_payments(v_shipment);
  PERFORM public.stamp_global_shipment_landed_costs(v_shipment);

  IF v_lost_item_id IS NOT NULL THEN
    SELECT coalesce(gsi.landed_cost_bdt, 0) INTO v_landed
    FROM public.global_shipment_items gsi
    WHERE gsi.id = v_lost_item_id;

    INSERT INTO public.global_shipment_item_outcomes (
      tenant_id, shipment_item_id, kind, reason, quantity, purchase_price, cost
    )
    VALUES (
      v_tenant,
      v_lost_item_id,
      'unsellable'::public.global_shipment_outcome_kind,
      'missing'::public.global_shipment_outcome_reason,
      12,
      0.91,
      v_landed
    );
  END IF;

  v_cn := public.rpc_create_bill(jsonb_build_object(
    'tenant_id', v_tenant,
    'kind', 'credit_note',
    'parent_bill_id', v_mat_a,
    'auto_issue', true,
    'note', 'Agreed to refund',
    'meta', jsonb_build_object('reason', 'Agreed to refund'),
    'lines', jsonb_build_array(
      jsonb_build_object(
        'item_kind', 'charge',
        'description', 'Head & Shoulders Supreme Repair 250ML',
        'quantity', 6,
        'unit_price', 1.65,
        'line_total', 9.90
      ),
      jsonb_build_object(
        'item_kind', 'charge',
        'description', 'Head & Shoulders Menthol 400ML',
        'quantity', 6,
        'unit_price', 2.49,
        'line_total', 14.94
      )
    ),
    'idempotency_key', 'pgtap-s45-cn-' || v_shipment::text
  ));

  v_cn_id := NULLIF(v_cn ->> 'bill_id', '')::bigint;
  IF v_cn_id IS NULL THEN
    RAISE EXCEPTION 's45 credit note create failed: %', v_cn;
  END IF;

  PERFORM public.ensure_cashbook_account_for_profile(v_payer, 'BDT');
  PERFORM public.ensure_cashbook_account_for_profile(v_payer, 'GBP');
  PERFORM public.fn_provision_kernel_cashbook_for_profile_row(v_tenant, v_payer);

  SELECT cl.id INTO v_cash_loc
  FROM money_kernel.cash_locations cl
  JOIN money_kernel.cashbooks cb ON cb.id = cl.cashbook_id
  WHERE cb.tenant_id = v_tenant
    AND cb.profile_id = v_payer
    AND cl.location_code = 'main'
    AND cl.is_active = true
  LIMIT 1;

  IF v_cash_loc IS NULL THEN
    RAISE EXCEPTION 's45 fund: kernel cash location missing for tenant profile';
  END IF;

  PERFORM public.post_vendor_credit_refund(
    v_cn_id,
    24.84,
    NULL,
    current_date,
    'Vendor credit refund',
    'BDT',
    NULL,
    NULL,
    NULL,
    1,
    NULL,
    v_cash_loc
  );

  RETURN p_ctx || jsonb_build_object(
    'credit_note_id', v_cn_id,
    'material_pot_id', v_mat_pot,
    'freight_pot_id', v_fre_pot,
    'cashbook_point_id', v_point_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public._test_ensure_global_currency(text, text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_ensure_global_currency(text, text, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_ensure_global_currency(text, text, text) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_enable_tenant_module(bigint, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_enable_tenant_module(bigint, text) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_enable_tenant_module(bigint, text) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_bootstrap_dropship_golden_a(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_bootstrap_dropship_golden_a(jsonb) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_bootstrap_dropship_golden_a(jsonb) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_bootstrap_shipment_s54(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_bootstrap_shipment_s54(bigint) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_bootstrap_shipment_s54(bigint) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_flush_kernel_pays() FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_flush_kernel_pays() FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_flush_kernel_pays() TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_shipment_s54_fund_and_pay(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_shipment_s54_fund_and_pay(jsonb) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_shipment_s54_fund_and_pay(jsonb) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_bootstrap_shipment_s45(bigint) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_bootstrap_shipment_s45(bigint) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_bootstrap_shipment_s45(bigint) TO postgres, service_role;

REVOKE ALL ON FUNCTION public._test_shipment_s45_fund_pay_and_credit(jsonb) FROM PUBLIC;
REVOKE ALL ON FUNCTION public._test_shipment_s45_fund_pay_and_credit(jsonb) FROM anon, authenticated;
GRANT EXECUTE ON FUNCTION public._test_shipment_s45_fund_pay_and_credit(jsonb) TO postgres, service_role;

BEGIN;
SELECT plan(5);

SELECT has_function('public', '_test_bootstrap_dropship_golden_a', ARRAY['jsonb']);
SELECT has_function('public', '_test_bootstrap_shipment_s54', ARRAY['bigint']);
SELECT has_function('public', '_test_shipment_s54_fund_and_pay', ARRAY['jsonb']);
SELECT has_function('public', '_test_bootstrap_shipment_s45', ARRAY['bigint']);
SELECT has_function('public', '_test_shipment_s45_fund_pay_and_credit', ARRAY['jsonb']);

SELECT finish();
ROLLBACK;
