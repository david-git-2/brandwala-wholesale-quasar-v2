-- Payment received: clear dropship courier AR on remittance; order_no in notes.

CREATE OR REPLACE FUNCTION public.is_dropship_courier_ar_bill(p_bill public.bills)
  RETURNS boolean
  LANGUAGE sql
  STABLE
AS $$
  SELECT CASE
    WHEN p_bill.id IS NULL THEN false
    WHEN p_bill.source_type = 'dropship_courier_ar' THEN true
    WHEN coalesce(p_bill.channel_meta ->> 'dropship_courier_ar', '') = 'true' THEN true
    WHEN p_bill.source_key = 'courier_ar' THEN true
    WHEN p_bill.invoice_type = 'ap'::public.global_invoice_type
      AND (
        p_bill.source_type = 'dropship_courier'
        OR (p_bill.source_type = 'shop_order' AND coalesce(p_bill.source_key, '') = 'courier')
      ) THEN false
    ELSE p_bill.invoice_type = 'dropship'::public.global_invoice_type
      AND (
        p_bill.source_type IN ('dropship_courier_ar', 'shop_order')
        OR coalesce(p_bill.channel_meta ->> 'dropship_courier_ar', '') = 'true'
      )
  END;
$$;

CREATE OR REPLACE FUNCTION public.issue_dropship_courier_ar_for_order(
  p_tenant_id bigint,
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_order public.shop_orders;
  v_bill_id bigint;
  v_bill public.bills;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'order not found');
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant mismatch');
  END IF;

  v_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_order.tenant_id);

  IF v_bill_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'courier bill not found');
  END IF;

  SELECT * INTO v_bill FROM public.bills WHERE id = v_bill_id FOR UPDATE;
  IF v_bill.invoice_status = 'draft'::public.global_invoice_status THEN
    PERFORM public.post_sales_invoice(v_bill_id);
    PERFORM public.stamp_bill_kernel_fields(v_bill_id);
    SELECT * INTO v_bill FROM public.bills WHERE id = v_bill_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'bill_id', v_bill_id,
    'invoice_status', v_bill.invoice_status,
    'order_no', v_order.order_no
  );
EXCEPTION
  WHEN OTHERS THEN
    RETURN jsonb_build_object('success', false, 'error', sqlerrm);
END;
$$;

CREATE OR REPLACE FUNCTION public.settle_dropship_courier_ar_from_remittance(
  p_ar_bill_id bigint,
  p_order_id bigint,
  p_order_no text,
  p_remittance_ref text,
  p_receipt_payment_id bigint DEFAULT NULL
) RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
DECLARE
  v_ar public.bills;
  v_bal jsonb;
  v_family_due numeric(12, 2);
  v_remaining numeric(12, 2);
  v_chunk numeric(12, 2);
  v_total_settled numeric(12, 2) := 0;
  v_bill record;
  v_operating_tenant_id bigint;
  v_note text;
BEGIN
  IF p_ar_bill_id IS NULL THEN
    RETURN 0;
  END IF;

  SELECT * INTO v_ar FROM public.bills WHERE id = p_ar_bill_id FOR UPDATE;
  IF v_ar.id IS NULL THEN
    RAISE EXCEPTION 'courier AR bill not found';
  END IF;

  IF NOT public.is_dropship_courier_ar_bill(v_ar) THEN
    RAISE EXCEPTION 'bill is not a dropship courier AR bill';
  END IF;

  IF v_ar.invoice_status <> 'issued'::public.global_invoice_status THEN
    RETURN 0;
  END IF;

  v_bal := public.get_bill_net_balances(p_ar_bill_id);
  v_family_due := greatest(coalesce((v_bal->>'due_amount')::numeric, 0), 0);
  v_remaining := v_family_due;

  IF v_remaining <= 0 THEN
    RETURN 0;
  END IF;

  v_note := format(
    'Courier AR cleared from remittance — order #%s — ref %s',
    coalesce(nullif(trim(p_order_no), ''), p_order_id::text),
    coalesce(nullif(trim(p_remittance_ref), ''), '—')
  );

  FOR v_bill IN
    SELECT
      b.id,
      b.due_amount,
      b.issued_by_tenant_id,
      b.parent_tenant_id
    FROM public.bills b
    WHERE (
        b.id = p_ar_bill_id
        OR b.parent_bill_id = p_ar_bill_id
      )
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND greatest(coalesce(b.due_amount, 0), 0) > 0
    ORDER BY
      CASE WHEN b.id = p_ar_bill_id THEN 0 ELSE 1 END,
      b.id
    FOR UPDATE
  LOOP
    v_chunk := least(v_remaining, greatest(coalesce(v_bill.due_amount, 0), 0));
    IF v_chunk <= 0 THEN
      CONTINUE;
    END IF;

    v_operating_tenant_id := coalesce(v_bill.issued_by_tenant_id, v_bill.parent_tenant_id);

    INSERT INTO public.invoice_write_offs (
      tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    VALUES (
      v_bill.parent_tenant_id,
      v_bill.id,
      p_receipt_payment_id,
      v_chunk,
      'dispute_settlement',
      v_note,
      auth.uid()
    );

    PERFORM public.recompute_global_invoice_payment_status(v_bill.id);

    v_total_settled := v_total_settled + v_chunk;
    v_remaining := v_remaining - v_chunk;

    IF v_remaining <= 0 THEN
      EXIT;
    END IF;
  END LOOP;

  PERFORM public.recompute_global_invoice_payment_status(p_ar_bill_id);

  RETURN round(v_total_settled, 2);
END;
$$;

CREATE OR REPLACE FUNCTION public.credit_dropship_profit_from_courier_remittance(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_order_id bigint,
  p_payment_id bigint,
  p_amount numeric,
  p_reference text,
  p_net_remitted numeric,
  p_invoice_allocated numeric
) RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
DECLARE
  v_parent_id bigint;
  v_profit_already_credited boolean := false;
  v_amount numeric(12, 2);
  v_order_no text;
BEGIN
  v_amount := round(greatest(coalesce(p_amount, 0), 0), 2);
  IF v_amount <= 0 THEN
    RETURN;
  END IF;

  SELECT o.order_no INTO v_order_no
  FROM public.shop_orders o
  WHERE o.id = p_order_id;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  SELECT EXISTS (
    SELECT 1
    FROM public.cashbook_entries u
    WHERE u.tenant_id = v_parent_id
      AND u.source_type = 'shop_order'
      AND u.source_id = p_order_id::text
      AND u.entity_type IN ('middleman', 'customer')
      AND u.entity_id = p_profile_id
      AND u.type = 'credit'
      AND coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
  ) INTO v_profit_already_credited;

  IF v_profit_already_credited THEN
    RETURN;
  END IF;

  PERFORM public.record_ledger_transaction(
    p_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
    p_type => 'credit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'transaction_type', 'dropship_profit',
      'label', format(
        'Dropship profit from remittance — order #%s',
        coalesce(nullif(trim(v_order_no), ''), p_order_id::text)
      ),
      'order_id', p_order_id,
      'order_no', v_order_no,
      'shop_order_id', p_order_id::text,
      'payment_id', p_payment_id,
      'remittance_ref', p_reference,
      'net_remitted', p_net_remitted,
      'invoice_allocated', p_invoice_allocated
    )
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.is_dropship_courier_ar_bill(public.bills) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.issue_dropship_courier_ar_for_order(bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.settle_dropship_courier_ar_from_remittance(bigint, bigint, text, text, bigint) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text" DEFAULT NULL::"text", "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_note" "text" DEFAULT NULL::"text", "p_courier_charge" numeric DEFAULT 0.00, "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_delivery_charge" numeric DEFAULT NULL::numeric, "p_cod_charge" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_invoice public.bills;
  v_parent_tenant_id bigint;
  v_payment_id bigint;
  v_pay public.pays;
  v_ref text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_invoice_due numeric(12,2);
  v_invoice_pay numeric(12,2);
  v_remainder numeric(12,2);
  v_already_remitted boolean := false;
  v_notes jsonb;
  v_ap_bill_id bigint;
  v_ap_settled numeric(12,2) := 0;
  v_ap_bal jsonb;
  v_ar_bal jsonb;
  v_ap_family_due numeric(12,2) := 0;
  v_settlement public.dropship_order_settlements;
  v_sync_charge_lines jsonb;
  v_sync_detail jsonb;
  v_sync_items_resell numeric(15,2);
  v_sync_order_discount numeric(15,2);
  v_sync_reseller_purchase numeric(15,2);
  v_sync_company_procurement numeric(15,2);
  v_sync_discount_company_pay numeric(15,2);
  v_sync_totals record;
  v_courier_bill public.bills;
  v_courier_ar_settled numeric(12, 2) := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'Courier remittance requires order status delivered or payment_received (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select (
    exists (
      select 1
      from public.pays py
      where py.shop_order_id = p_order_id
        and py.source = 'courier_remittance'
    )
    or nullif(trim(coalesce(v_order.courier_remittance_ref, '')), '') is not null
  ) into v_already_remitted;

  if v_already_remitted then
    select py.id into v_payment_id
    from public.pays py
    where py.shop_order_id = p_order_id
      and py.source = 'courier_remittance'
    order by py.id desc
    limit 1;

    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'invoice_id', v_order.global_invoice_id,
      'payment_id', v_payment_id,
      'order_id', p_order_id,
      'status', v_order.status
    );
  end if;

  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  end if;

  v_net := coalesce(p_net_amount, 0.00);

  if p_delivery_charge is not null or p_cod_charge is not null then
    if p_delivery_charge is null or p_cod_charge is null then
      raise exception 'Both delivery and COD fees are required when overriding courier fees';
    end if;
    perform public.patch_dropship_courier_fees_for_remittance(
      p_order_id,
      p_delivery_charge,
      p_cod_charge
    );
    v_charge := round(coalesce(p_delivery_charge, 0) + coalesce(p_cod_charge, 0), 2);
  else
    v_charge := coalesce(p_courier_charge, 0.00);
  end if;

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  if v_net <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  end if;

  if v_charge < 0.00 then
    raise exception 'Courier charge cannot be negative';
  end if;

  if v_cod > 0 and (v_net + v_charge) > (v_cod + 0.01) then
    raise exception 'Remittance net (%) + charge (%) exceeds COD collect (%)', v_net, v_charge, v_cod;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Cashbook location is required for courier pay in';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Merchant bill must be issued before remittance (current: %)', v_invoice.invoice_status;
  end if;

  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    raise exception 'Remittance applies to dropship merchant bills only';
  end if;

  if v_invoice.profile_id is null then
    raise exception 'Merchant profile is required on the bill';
  end if;

  v_notes := public.apply_dropship_issued_bill_notes_at_deliver(p_order_id);
  if coalesce(v_notes->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_notes->>'error', 'Failed to apply bill notes before courier pay in');
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;

  v_ar_bal := public.get_bill_net_balances(v_invoice.id);
  v_invoice_due := greatest(coalesce((v_ar_bal->>'due_amount')::numeric, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_remainder := greatest(v_net - v_invoice_pay, 0.00);

  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id => v_order.tenant_id,
    p_profile_id => v_invoice.profile_id,
    p_received_on => coalesce(p_payment_date, current_date),
    p_note => coalesce(
      nullif(trim(p_note), ''),
      'Courier remittance order #' || v_order.order_no
        || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
    ),
    p_reference => v_ref,
    p_source => 'courier_remittance'::text,
    p_instruments => jsonb_build_array(
      jsonb_strip_nulls(
        jsonb_build_object(
          'payment_method_code',
            case upper(coalesce(nullif(trim(p_method), ''), 'CASH'))
              when 'BANK_TRANSFER' then 'BANK_TRANSFER'
              when 'BKASH' then 'BKASH'
              else 'CASH'
            end,
          'amount', v_net,
          'reference', nullif(trim(coalesce(p_bank_trx_id, '')), ''),
          'cashbook_point_id', p_cashbook_point_id
        )
      )
    ),
    p_allocations => case
      when v_invoice_pay > 0 then jsonb_build_array(jsonb_build_object('bill_id', v_invoice.id, 'amount', v_invoice_pay))
      else '[]'::jsonb
    end,
    p_shop_order_id => p_order_id,
    p_settlement_currency_code => 'BDT',
    p_foreign_amount => NULL::numeric,
    p_exchange_rate => NULL::numeric,
    p_credit_dropship_profit => false,
    p_idempotency_key => NULL::text
  );
  v_payment_id := v_pay.id;

  v_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_ap_bill_id is not null then
    select * into v_courier_bill from public.bills where id = v_ap_bill_id for update;

    if v_courier_bill.invoice_status = 'draft'::public.global_invoice_status then
      perform public.post_sales_invoice(v_ap_bill_id);
      perform public.stamp_bill_kernel_fields(v_ap_bill_id);
      select * into v_courier_bill from public.bills where id = v_ap_bill_id;
    end if;

    if v_courier_bill.invoice_type = 'ap'::public.global_invoice_type then
      v_ap_bal := public.get_bill_net_balances(v_ap_bill_id);
      v_ap_family_due := greatest(coalesce((v_ap_bal->>'due_amount')::numeric, 0), 0);
      v_ap_settled := public.settle_dropship_courier_ap_via_cod_retention(
        v_ap_bill_id,
        least(v_charge, v_ap_family_due),
        p_order_id,
        v_ref,
        v_payment_id
      );
    elsif public.is_dropship_courier_ar_bill(v_courier_bill) then
      v_courier_ar_settled := public.settle_dropship_courier_ar_from_remittance(
        v_ap_bill_id,
        p_order_id,
        v_order.order_no,
        v_ref,
        v_payment_id
      );
    end if;
  end if;

  v_ar_bal := public.get_bill_net_balances(v_invoice.id);
  if greatest(coalesce((v_ar_bal->>'due_amount')::numeric, 0.00), 0.00) > 0.01 then
    raise exception
      'Customer bill must be cleared from remittance before dropshipper profit (due % BDT)',
      (v_ar_bal->>'due_amount')::numeric;
  end if;

  if v_ap_bill_id is not null then
    select * into v_courier_bill from public.bills where id = v_ap_bill_id;
    v_ap_bal := public.get_bill_net_balances(v_ap_bill_id);
    if v_courier_bill.invoice_type = 'ap'::public.global_invoice_type then
      if greatest(coalesce((v_ap_bal->>'due_amount')::numeric, 0.00), 0.00) > 0.01 then
        raise exception
          'Courier AP must be settled from COD retention before dropshipper profit (due % BDT)',
          (v_ap_bal->>'due_amount')::numeric;
      end if;
    elsif public.is_dropship_courier_ar_bill(v_courier_bill) then
      if greatest(coalesce((v_ap_bal->>'due_amount')::numeric, 0.00), 0.00) > 0.01 then
        raise exception
          'Courier AR must be cleared from remittance before dropshipper profit (due % BDT, order %)',
          (v_ap_bal->>'due_amount')::numeric,
          v_order.order_no;
      end if;
    end if;
  end if;

  if v_remainder > 0 then
    perform public.credit_dropship_profit_from_courier_remittance(
      v_order.tenant_id,
      v_invoice.profile_id,
      p_order_id,
      v_payment_id,
      v_remainder,
      v_ref,
      v_net,
      v_invoice_pay
    );
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if found then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'charge_type', cl.charge_type::text,
          'amount', cl.amount,
          'payer', cl.payer::text
        )
        order by cl.id
      ),
      '[]'::jsonb
    )
    into v_sync_charge_lines
    from public.dropship_settlement_charge_lines cl
    where cl.settlement_id = v_settlement.id;

    v_sync_detail := public.get_dropship_order_detail_v2(v_order.tenant_id, p_order_id);
    v_sync_items_resell := coalesce((v_sync_detail->'computed'->>'items_resell_total')::numeric, 0);
    v_sync_order_discount := coalesce(
      (v_sync_detail->'order'->>'discount_amount')::numeric,
      v_order.discount_amount,
      0
    );
    v_sync_discount_company_pay := coalesce(v_settlement.discount_company_pay, 0);

    select rp.reseller_purchase_cost
    into v_sync_reseller_purchase
    from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

    select coalesce(
      sum(
        public.resolve_shop_order_item_landed_cost(
          soi.global_stock_id,
          soi.cost_price_amount,
          soi.unit_list_price_amount
        ) * soi.quantity
      ),
      0
    )
    into v_sync_company_procurement
    from public.shop_order_items soi
    where soi.order_id = p_order_id;

    select * into v_sync_totals
    from public.compute_dropship_settlement_totals(
      v_sync_items_resell,
      v_sync_order_discount,
      v_sync_reseller_purchase,
      v_sync_company_procurement,
      v_sync_discount_company_pay,
      v_sync_charge_lines
    );

    update public.dropship_order_settlements
    set
      remittance_at = coalesce(remittance_at, now()),
      status = 'confirmed'::public.dropship_settlement_status,
      total_cost = v_sync_totals.total_cost,
      reseller_profit = v_sync_totals.reseller_profit,
      company_profit = v_sync_totals.company_profit,
      updated_at = now()
    where shop_order_id = p_order_id;
  end if;

  if v_invoice_pay > 0 and nullif(trim(p_note), '') is not null then
    update public.bills
    set note = trim(p_note), updated_at = now()
    where id = v_invoice.id;
  end if;

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    cod_collect_amount = coalesce(
      (select s.collected_cod_amount from public.dropship_order_settlements s where s.shop_order_id = p_order_id),
      cod_collect_amount
    ),
    payout_settlement_status = case
      when v_remainder > 0 then 'unpaid'
      when v_remainder <= 0 then 'paid'
      else payout_settlement_status
    end,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received',
    'net_amount', v_net,
    'courier_charge', v_charge,
    'invoice_allocated', v_invoice_pay,
    'merchant_remainder', v_remainder,
    'merchant_remainder_credited', v_remainder,
    'courier_ap_bill_id', v_ap_bill_id,
    'courier_ap_settled', v_ap_settled,
    'courier_ar_settled', v_courier_ar_settled,
    'bill_notes', v_notes
  );
end;
$$;
