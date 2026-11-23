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

  INSERT INTO public.vendors (tenant_id, name, code, market_code, is_default)
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
  PERFORM public._test_set_workspace_tenant(v_tenant);

  DECLARE
    v_books bigint;
    v_self bigint;
    v_rpc jsonb;
  BEGIN
    v_books := public.resolve_books_tenant_id(v_tenant);
    v_self := public._kernel_tenant_mirror_profile_id(v_books);

    v_rpc := public.rpc_create_bill(jsonb_build_object(
      'tenant_id', v_books,
      'kind', 'dropship_courier_ap',
      'currency_code', 'BDT',
      'from_profile_id', v_vendor_profile,
      'to_profile_id', v_self,
      'counterparty_profile_id', v_vendor_profile,
      'note', 'AP-BDT-PGTAP',
      'auto_issue', true,
      'meta', jsonb_build_object(
        'delivery_kind', 'take',
        'subtotal_amount', 12000.00
      ),
      'lines', jsonb_build_array(jsonb_build_object(
        'item_kind', 'charge',
        'description', 'Freight',
        'quantity', 1,
        'unit_price', 12000.00,
        'line_total', 12000.00
      ))
    ));

    v_bill_id := nullif(v_rpc->>'bill_id', '')::bigint;
    IF v_bill_id IS NULL THEN
      RAISE EXCEPTION 'T4-1 AP create failed: %', v_rpc;
    END IF;

    SELECT * INTO v_bill FROM public.bills WHERE id = v_bill_id;
  END;

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
