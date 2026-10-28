-- T4-1 — AP payout with FX pot (books settlement + cross-currency pot)
BEGIN;

SELECT plan(1);

DO $$
DECLARE
  v_ctx jsonb;
  v_tenant bigint;
  v_point bigint;
  v_vendor_id bigint;
  v_vendor_profile bigint;
  v_bill public.bills;
  v_bill_id bigint;
  v_pay public.pays;
  v_open numeric;
BEGIN
  v_ctx := public._test_money_kernel_bootstrap();
  v_tenant := (v_ctx ->> 'tenant_id')::bigint;
  v_point := (v_ctx ->> 'cashbook_point_id')::bigint;

  INSERT INTO public.markets (code, name, is_active, is_system, region)
  VALUES ('BD', 'Bangladesh', true, false, 'Asia')
  ON CONFLICT (code) DO NOTHING;

  INSERT INTO public.vendors (parent_tenant_id, name, code, market_code, is_default)
  VALUES (v_tenant, 'pgTAP Vendor', 'PGTAPV', 'BD', true)
  RETURNING id INTO v_vendor_id;

  v_vendor_profile := public.upsert_profile_for_party(
    v_tenant,
    'vendor'::public.profile_party_type,
    v_vendor_id,
    'pgTAP Vendor',
    NULL,
    NULL,
    '+880',
    NULL,
    false,
    NULL,
    true,
    NULL
  );

  PERFORM public._test_pgtap_auth();

  v_bill := public.create_sales_invoice(
    v_tenant,
    'AP-BDT-PGTAP',
    'ap'::public.global_invoice_type,
    v_vendor_profile
  );
  v_bill_id := v_bill.id;

  INSERT INTO public.bill_lines (
    parent_tenant_id, invoice_id, line_kind, name_snapshot,
    quantity, sell_price_amount, line_discount_amount, line_total_amount
  )
  VALUES (
    v_bill.parent_tenant_id, v_bill_id, 'description', 'Freight',
    1, 12000.00, 0, 12000.00
  );

  UPDATE public.bills
  SET
    subtotal_amount = 12000.00,
    total_amount = 12000.00,
    due_amount = 12000.00,
    updated_at = now()
  WHERE id = v_bill_id;

  PERFORM public.stamp_bill_kernel_fields(v_bill_id);
  PERFORM public.issue_bill(v_bill_id);

  PERFORM public._test_fund_cashbook_pot(v_tenant, v_point, 500000.00, 'BDT');

  v_pay := public.post_ap_payout_with_allocations(
    v_tenant,
    v_vendor_profile,
    current_date,
    v_point,
    'T4-1 FX pot',
    null,
    jsonb_build_array(
      jsonb_build_object(
        'payment_method_code', 'BANK',
        'amount', 12000.00,
        'cashbook_point_id', v_point
      )
    ),
    jsonb_build_array(jsonb_build_object('bill_id', v_bill_id, 'amount', 12000.00)),
    'BDT',
    null,
    null,
    'BDT',
    1.000000,
    null,
    null
  );

  v_open := (public.get_bill_net_balances(v_bill_id) ->> 'open_books')::numeric;
  IF v_open <> 0 THEN
    RAISE EXCEPTION 'T4-1: expected open_books 0, got %', v_open;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.bill_settlements bs
    WHERE bs.bill_id = v_bill_id
      AND bs.allocator_kind = 'pay'
      AND bs.allocator_id = v_pay.id
  ) THEN
    RAISE EXCEPTION 'T4-1: missing pay settlement';
  END IF;
END;
$$;

SELECT ok(true, 'T4-1 AP payout from GBP pot clears bill');

SELECT finish();
ROLLBACK;
