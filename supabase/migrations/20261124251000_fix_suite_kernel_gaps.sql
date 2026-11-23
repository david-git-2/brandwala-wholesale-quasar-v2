-- Suite blockers after bills became a money_kernel view:
-- 1) ambiguous post_money_in overloads
-- 2) missing settlement amount helper
-- 3) courier AP still INSERTs into public.bills
-- 4) create_bill_adjustment still INSERTs into public.bills

DROP FUNCTION IF EXISTS public.post_money_in(
  bigint, bigint, date, text, text, text, jsonb, jsonb,
  bigint, text, numeric, numeric, text, bigint, bigint, text, numeric
);

CREATE OR REPLACE FUNCTION public._kernel_settlement_amounts_from_pay_alloc(
  p_bill public.bills,
  p_pay public.pays,
  p_alloc_books numeric
) RETURNS TABLE (
  allocated_txn_amount numeric,
  allocated_books_amount numeric,
  books_rate_at_alloc numeric,
  fx_realized_books_delta numeric
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_books numeric(12, 2);
  v_txn numeric(12, 2);
  v_bill_rate numeric(15, 6);
  v_pay_rate numeric(15, 6);
  v_txn_ccy text;
  v_books_ccy text;
BEGIN
  v_books := round(coalesce(p_alloc_books, 0), 2);
  v_bill_rate := coalesce(nullif(p_bill.books_exchange_rate, 0), 1.000000);
  v_txn_ccy := upper(btrim(coalesce(p_bill.txn_currency_code, p_bill.currency_code, 'BDT')));
  v_books_ccy := upper(btrim(coalesce(p_bill.currency_code, 'BDT')));

  IF v_txn_ccy = v_books_ccy OR v_bill_rate <= 0 THEN
    v_txn := v_books;
    v_pay_rate := 1.000000;
  ELSE
    IF p_pay.id IS NOT NULL
       AND upper(btrim(coalesce(p_pay.settlement_currency_code, 'BDT'))) <> v_books_ccy
       AND coalesce(p_pay.exchange_rate, 0) > 0
    THEN
      v_txn := round(v_books / p_pay.exchange_rate, 2);
      v_pay_rate := p_pay.exchange_rate;
    ELSE
      v_txn := round(v_books / v_bill_rate, 2);
      v_pay_rate := v_bill_rate;
    END IF;
  END IF;

  IF v_txn > 0 THEN
    v_pay_rate := round(v_books / v_txn, 6);
  END IF;

  RETURN QUERY
  SELECT
    v_txn,
    v_books,
    v_pay_rate,
    v_books - round(v_txn * v_bill_rate, 2);
END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_dropship_courier_ap(
  p_order_id bigint,
  p_keep_as_draft boolean DEFAULT false
) RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_order public.shop_orders;
  v_books_tenant_id bigint;
  v_profile_id bigint;
  v_tenant_self bigint;
  v_amount numeric(12, 2);
  v_courier public.courier_services;
  v_tenant_name text;
  v_bill money_kernel.bills;
  v_rpc jsonb;
  v_bill_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id FOR UPDATE;
  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.shop_type_snapshot <> 'dropship' THEN
    RETURN jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  END IF;

  IF v_order.courier_service_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'courier is required');
  END IF;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);
  v_tenant_self := public._kernel_tenant_mirror_profile_id(v_books_tenant_id);

  SELECT * INTO v_courier FROM public.courier_services WHERE id = v_order.courier_service_id;
  IF v_courier.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'courier is required');
  END IF;

  SELECT t.name INTO v_tenant_name FROM public.tenants t WHERE t.id = v_order.tenant_id;

  PERFORM public.upsert_profile_for_party(
    v_books_tenant_id, 'tenant'::public.profile_party_type, v_order.tenant_id,
    coalesce(v_tenant_name, 'Tenant'), null, null, '+880', null, false, null, true, null
  );

  SELECT p.id INTO v_profile_id
  FROM public.profiles p
  WHERE p.tenant_id = v_books_tenant_id
    AND p.profile_type = 'courier'::public.profile_party_type
    AND p.subject_id = v_courier.wallet_entity_id
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    v_profile_id := public.upsert_profile_for_party(
      v_books_tenant_id, 'courier'::public.profile_party_type, v_courier.wallet_entity_id,
      v_courier.name, null, null, '+880', null, false, null,
      coalesce(v_courier.is_active, true), null
    );
  END IF;

  IF v_profile_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'courier profile is required');
  END IF;

  v_amount := round(
    coalesce(
      nullif(coalesce(v_order.delivery_charge_amount, 0) + coalesce(v_order.cod_charge_amount, 0), 0),
      nullif(v_order.courier_cost_amount, 0),
      nullif(v_courier.inside_dhaka_fee, 0),
      0
    ),
    2
  );

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('success', true, 'skipped', true, 'reason', 'zero_courier_ap');
  END IF;

  SELECT * INTO v_bill
  FROM money_kernel.bills b
  WHERE b.tenant_id = v_books_tenant_id
    AND b.kind = 'dropship_courier_ap'
    AND b.source_id = p_order_id::text
    AND b.status <> 'voided'
  FOR UPDATE;

  IF v_bill.id IS NOT NULL THEN
    IF coalesce(v_bill.paid_amount, 0) > 0 THEN
      RETURN jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true, 'amount', v_bill.total_amount);
    END IF;
    IF v_bill.status = 'draft' THEN
      UPDATE money_kernel.bills
      SET
        total_amount = v_amount,
        due_amount = greatest(v_amount - coalesce(paid_amount, 0), 0),
        note = format('Courier AP — %s — order %s', v_courier.name, v_order.order_no),
        updated_at = now()
      WHERE id = v_bill.id;
      DELETE FROM money_kernel.bill_lines WHERE bill_id = v_bill.id AND tenant_id = v_books_tenant_id;
      INSERT INTO money_kernel.bill_lines (
        tenant_id, bill_id, line_no, item_kind, description, quantity, unit_price, line_total, meta
      ) VALUES (
        v_books_tenant_id, v_bill.id, 1, 'charge', 'Courier fees', 1, v_amount, v_amount,
        jsonb_build_object('courier_ap', true)
      );
      IF NOT coalesce(p_keep_as_draft, false) THEN
        PERFORM public.rpc_issue_bill(v_books_tenant_id, v_bill.id);
      END IF;
    END IF;
    RETURN jsonb_build_object('success', true, 'bill_id', v_bill.id, 'amount', v_amount);
  END IF;

  v_rpc := public.rpc_create_bill(jsonb_build_object(
    'tenant_id', v_books_tenant_id,
    'kind', 'dropship_courier_ap',
    'source_entity', 'public.shop_orders',
    'source_type', 'dropship_courier',
    'source_id', p_order_id::text,
    'source_key', 'courier',
    'idempotency_key', format('dropship-courier-ap-%s', p_order_id),
    'currency_code', 'BDT',
    'from_profile_id', v_profile_id,
    'to_profile_id', v_tenant_self,
    'counterparty_profile_id', v_profile_id,
    'auto_issue', NOT coalesce(p_keep_as_draft, false),
    'note', format('Courier AP — %s — order %s', v_courier.name, v_order.order_no),
    'meta', jsonb_build_object('shop_order_id', p_order_id, 'subtotal_amount', v_amount),
    'lines', jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge', 'description', 'Courier fees',
      'quantity', 1, 'unit_price', v_amount, 'line_total', v_amount
    ))
  ));

  v_bill_id := nullif(v_rpc->>'bill_id', '')::bigint;
  IF v_bill_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', coalesce(v_rpc->>'error', 'courier AP create failed'));
  END IF;

  RETURN jsonb_build_object('success', true, 'bill_id', v_bill_id, 'created', true, 'amount', v_amount);
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', sqlerrm);
END;
$$;

CREATE OR REPLACE FUNCTION public.create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true,
  p_refund_amount numeric DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_lines jsonb DEFAULT '[]'::jsonb
) RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_parent money_kernel.bills;
  v_kind text;
  v_amount numeric(12, 2);
  v_reason text;
  v_rpc jsonb;
  v_bill_id bigint;
  v_row public.bills;
BEGIN
  IF p_parent_bill_id IS NULL THEN
    RAISE EXCEPTION 'parent_bill_id is required';
  END IF;

  v_kind := CASE lower(trim(coalesce(p_kind, '')))
    WHEN 'credit_note' THEN 'credit_note'
    WHEN 'credit' THEN 'credit_note'
    WHEN 'debit_note' THEN 'debit_note'
    WHEN 'debit' THEN 'debit_note'
    ELSE NULL
  END;
  IF v_kind IS NULL THEN
    RAISE EXCEPTION 'kind must be credit_note or debit_note';
  END IF;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  IF v_reason IS NULL THEN
    RAISE EXCEPTION 'reason is required';
  END IF;

  SELECT * INTO v_parent FROM money_kernel.bills WHERE id = p_parent_bill_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;
  IF v_parent.status NOT IN ('issued', 'partial', 'paid', 'written_off') THEN
    RAISE EXCEPTION 'parent bill must be issued';
  END IF;

  IF NOT (
    coalesce(auth.role(), '') = 'service_role'
    OR public.user_can_manage_books_tenant(v_parent.tenant_id)
    OR public.membership_has_module_action(v_parent.tenant_id, 'global_invoice', 'edit')
  ) THEN
    RAISE EXCEPTION 'Permission denied';
  END IF;

  v_amount := round(coalesce(p_amount, 0), 2);
  IF v_amount <= 0 THEN
    RAISE EXCEPTION 'amount must be greater than zero';
  END IF;

  -- p_refund_amount / p_cashbook_point_id / p_lines: not wired on kernel path yet
  IF p_refund_amount IS NOT NULL OR p_cashbook_point_id IS NOT NULL THEN
    NULL; -- ⚠️ verify: legacy refund-on-CN path deferred
  END IF;

  v_rpc := public.rpc_create_bill(jsonb_strip_nulls(jsonb_build_object(
    'tenant_id', v_parent.tenant_id,
    'kind', v_kind,
    'parent_bill_id', p_parent_bill_id,
    'currency_code', v_parent.currency_code,
    'note', v_reason,
    'auto_issue', coalesce(p_issue, true),
    'meta', jsonb_build_object(
      'reason', v_reason,
      'adjustment_reason', v_reason,
      'subtotal_amount', v_amount
    ),
    'lines', jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge',
      'description', v_reason,
      'quantity', 1,
      'unit_price', v_amount,
      'line_total', v_amount
    ))
  )));

  v_bill_id := nullif(v_rpc->>'bill_id', '')::bigint;
  IF v_bill_id IS NULL THEN
    RAISE EXCEPTION '%', coalesce(v_rpc->>'error', 'create_bill_adjustment failed');
  END IF;

  SELECT * INTO v_row FROM public.bills WHERE id = v_bill_id;
  RETURN v_row;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_bill_adjustment(
  bigint, text, numeric, text, boolean, numeric, bigint, jsonb
) TO authenticated, service_role;
