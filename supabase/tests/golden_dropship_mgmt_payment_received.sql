-- Golden — courier AR cleared on remittance via courier→tenant pay into courier_bdt
BEGIN;

SELECT plan(5);

DO $$
DECLARE
  v_ctx jsonb;
  v_tenant bigint;
  v_bdt bigint;
  v_shop_id bigint;
  v_courier_id uuid;
  v_courier_entity bigint;
  v_product_id bigint;
  v_order_id bigint;
  v_order_no text := 'PGTAP-PR-' || substr(md5(random()::text), 1, 8);
  v_courier_ar bigint;
  v_tenant_profile_id bigint;
  v_courier_profile_id bigint;
  v_settled numeric;
  v_due numeric;
  v_courier jsonb;
  v_settle_count int;
BEGIN
  v_ctx := public._test_money_kernel_bootstrap();
  PERFORM public._test_pgtap_auth();
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;

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
    'edit',
    'allow'
  );
  v_bdt := public._test_ensure_global_currency('BDT', 'Bangladesh Taka', '৳');

  v_courier_entity := v_tenant * 1000 + 31;

  INSERT INTO public.shops (
    tenant_id, name, slug, shop_type, order_mode, is_negotiable,
    buy_currency_id, sell_currency_id, default_currency_id, pricing_method,
    quantity_display_mode, is_active
  )
  VALUES (
    v_tenant, 'pgTAP PR', 'pgtap-pr-' || substr(md5(random()::text), 1, 8),
    'dropship'::public.shop_type_enum, 'checkout_fixed'::public.shop_order_mode_enum, false,
    v_bdt, v_bdt, v_bdt, 'direct_cost', 'original', true
  )
  RETURNING id INTO v_shop_id;

  INSERT INTO public.courier_services (
    tenant_id, code, name, is_active, cod_fee_mode, inside_dhaka_fee, outside_dhaka_fee,
    wallet_entity_id
  )
  VALUES (v_tenant, 'PGT-C-' || substr(md5(random()::text), 1, 6), 'pgTAP Courier', true, 'none', 80, 120, v_courier_entity)
  RETURNING id INTO v_courier_id;

  INSERT INTO public.products (name, tenant_id, inserted_by_tenant_id, source, is_available)
  VALUES ('SKU', v_tenant, v_tenant, 'website', true)
  RETURNING id INTO v_product_id;

  INSERT INTO public.shop_orders (
    tenant_id, shop_id, order_no, name, shop_type_snapshot, order_mode_snapshot,
    status, profile_id, created_by_email, collection_source,
    cod_collect_amount, delivery_charge_amount, cod_charge_amount,
    sender_name, pickup_phone, pickup_address,
    recipient_name, recipient_phone, shipping_address, delivery_zone,
    courier_service_id, courier_name
  )
  VALUES (
    v_tenant, v_shop_id, v_order_no, 'PR', 'dropship'::public.shop_type_enum,
    'checkout_fixed'::public.shop_order_mode_enum, 'delivered'::public.shop_order_status,
    (v_ctx ->> 'customer_profile_id')::bigint, 'pgtap+money@kernel.test',
    'recipient'::public.collection_source_type, 1500, 80, 0,
    'Sender', '+8801700000000', 'Dhaka', 'Recipient', '+8801800000000', 'Dhaka',
    'inside_dhaka', v_courier_id, 'pgTAP Courier'
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.shop_order_items (
    order_id, product_id, name, quantity, confirmed_quantity,
    customer_sell_price_amount, customer_sell_price_currency_id,
    final_price_amount, final_price_currency_id, cost_price_amount, cost_price_currency_id
  )
  VALUES (v_order_id, v_product_id, 'Line', 1, 1, 1500, v_bdt, 1500, v_bdt, 900, v_bdt);

  v_courier := public.upsert_dropship_courier_ar_bill(v_order_id, true);
  IF coalesce(v_courier ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'courier AR upsert failed: %', v_courier;
  END IF;

  v_courier := public.issue_dropship_courier_ar_for_order(v_tenant, v_order_id);
  IF coalesce(v_courier ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'courier AR issue failed: %', v_courier;
  END IF;

  SELECT public.resolve_dropship_courier_ap_bill_id(v_order_id, v_tenant) INTO v_courier_ar;

  SELECT p.id INTO v_tenant_profile_id
  FROM public.profiles p
  WHERE p.tenant_id = v_tenant
    AND p.profile_type = 'tenant'::public.profile_party_type
    AND p.subject_id = v_tenant
  LIMIT 1;

  IF v_tenant_profile_id IS NULL THEN
    RAISE EXCEPTION 'tenant profile missing for golden';
  END IF;

  PERFORM public.ensure_tenant_courier_bdt_bundle(v_tenant, v_tenant_profile_id);

  SELECT kb.from_profile_id INTO v_courier_profile_id
  FROM money_kernel.bills kb
  WHERE kb.id = v_courier_ar;

  IF v_courier_profile_id IS NULL THEN
    RAISE EXCEPTION 'courier AR missing from_profile';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bills b
    WHERE b.id = v_courier_ar
      AND public.is_dropship_courier_ar_bill(b)
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND b.total_amount BETWEEN 1499.00 AND 1501.00
  ) THEN
    RAISE EXCEPTION 'expected issued courier AR ~1500';
  END IF;

  PERFORM public._test_set_workspace_tenant(v_tenant);

  v_settled := public.settle_dropship_courier_ar_from_remittance(
    v_courier_ar, v_order_id, v_order_no, 'REMIT-TEST', NULL
  );

  IF v_settled <= 0 THEN
    RAISE EXCEPTION 'expected positive settle amount, got %', v_settled;
  END IF;

  SELECT kb.due_amount INTO v_due
  FROM money_kernel.bills kb
  WHERE kb.id = v_courier_ar;

  IF coalesce(v_due, 0) > 0.01 THEN
    RAISE EXCEPTION 'courier AR due expected 0, got %', v_due;
  END IF;

  SELECT count(*) INTO v_settle_count
  FROM money_kernel.bill_settlements bs
  WHERE bs.bill_id = v_courier_ar
    AND bs.settlement_kind = 'pay';

  IF v_settle_count < 1 THEN
    RAISE EXCEPTION 'expected kernel pay settlement on courier AR';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM money_kernel.cash_locations cl
    JOIN money_kernel.cashbooks ca ON ca.id = cl.cashbook_id
    WHERE ca.tenant_id = v_tenant
      AND ca.profile_id = v_tenant_profile_id
      AND cl.location_code = 'courier_bdt'
  ) THEN
    RAISE EXCEPTION 'tenant missing courier_bdt location';
  END IF;
END;
$$;

SELECT ok(true, 'courier AR settled from remittance');
SELECT ok(true, 'courier AR due cleared');
SELECT ok(true, 'kernel pay settlement on courier AR');
SELECT ok(true, 'tenant courier_bdt location');
SELECT ok(true, 'dropship courier AR bill detected');

SELECT finish();
ROLLBACK;