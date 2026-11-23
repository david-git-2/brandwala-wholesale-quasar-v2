-- Golden — courier AR cleared on remittance (settle + write-off note with order_no)
-- COD face is recomputed from lines (1500) + passthrough delivery (80) = 1580;
-- courier AR net = 1580 - 80 = 1500 (manual cod_collect_amount is overwritten).
BEGIN;

SELECT plan(4);

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
  v_settled numeric;
  v_due numeric;
  v_courier jsonb;
  v_wo_reason text;
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

  -- Draft upsert (sync lines), then issue — auto_issue upsert fails on immutable lines
  v_courier := public.upsert_dropship_courier_ar_bill(v_order_id, true);
  IF coalesce(v_courier ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'courier AR upsert failed: %', v_courier;
  END IF;

  v_courier := public.issue_dropship_courier_ar_for_order(v_tenant, v_order_id);
  IF coalesce(v_courier ->> 'success', 'false') <> 'true' THEN
    RAISE EXCEPTION 'courier AR issue failed: %', v_courier;
  END IF;

  SELECT public.resolve_dropship_courier_ap_bill_id(v_order_id, v_tenant) INTO v_courier_ar;

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

  SELECT kb.meta ->> 'last_write_off_reason' INTO v_wo_reason
  FROM money_kernel.bills kb
  WHERE kb.id = v_courier_ar;

  IF coalesce(v_wo_reason, '') NOT LIKE '%' || v_order_no || '%' THEN
    RAISE EXCEPTION 'write-off note missing order_no %; got %', v_order_no, v_wo_reason;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM money_kernel.bills kb
    WHERE kb.id = v_courier_ar
      AND coalesce(kb.written_off_amount, 0) >= v_settled - 0.01
  ) THEN
    RAISE EXCEPTION 'kernel bill missing write-off amount';
  END IF;
END;
$$;

SELECT ok(true, 'courier AR settled from remittance');
SELECT ok(true, 'courier AR due cleared');
SELECT ok(true, 'write-off note has order_no');
SELECT ok(true, 'dropship courier AR bill detected');

SELECT finish();
ROLLBACK;
