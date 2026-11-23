-- Apply deferred kernel pays so deposit credits are visible before rpc_pay_bills in the same txn.
CREATE OR REPLACE FUNCTION money_kernel.flush_deferred_pays()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
BEGIN
  SET CONSTRAINTS money_kernel.trg_pays_apply IMMEDIATE;
END;
$$;

-- Courier AR settle: deposit and pay from the same courier main bundle (no empty fallback lot).
CREATE OR REPLACE FUNCTION public.settle_dropship_courier_ar_from_remittance(
  p_ar_bill_id bigint,
  p_order_id bigint,
  p_order_no text,
  p_remittance_ref text,
  p_receipt_payment_id bigint DEFAULT NULL
) RETURNS numeric
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
DECLARE
  v_ar public.bills;
  v_kb money_kernel.bills;
  v_books_tenant_id bigint;
  v_courier_profile_id bigint;
  v_tenant_profile_id bigint;
  v_clearing_pot bigint;
  v_courier_pot bigint;
  v_due numeric(12, 2);
  v_pay_chunk numeric(12, 2);
  v_dep jsonb;
  v_pay jsonb;
  v_idem text;
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

  SELECT * INTO v_kb FROM money_kernel.bills WHERE id = p_ar_bill_id FOR UPDATE;
  v_due := greatest(coalesce(v_kb.due_amount, 0), 0);
  IF v_due <= 0.01 THEN
    RETURN 0;
  END IF;

  v_books_tenant_id := v_kb.tenant_id;
  v_courier_profile_id := v_kb.from_profile_id;
  v_tenant_profile_id := v_kb.to_profile_id;

  IF v_courier_profile_id IS NULL OR v_tenant_profile_id IS NULL THEN
    PERFORM public.stamp_bill_kernel_fields(p_ar_bill_id);
    SELECT from_profile_id, to_profile_id, due_amount
      INTO v_courier_profile_id, v_tenant_profile_id, v_due
    FROM money_kernel.bills
    WHERE id = p_ar_bill_id;
    v_due := greatest(coalesce(v_due, 0), 0);
  END IF;

  IF v_courier_profile_id IS NULL OR v_tenant_profile_id IS NULL THEN
    RAISE EXCEPTION 'courier AR bill missing from/to profiles';
  END IF;

  v_clearing_pot := public.ensure_tenant_courier_bdt_bundle(v_books_tenant_id, v_tenant_profile_id);
  IF v_clearing_pot IS NULL THEN
    RAISE EXCEPTION 'tenant courier_bdt bundle is required';
  END IF;

  v_pay_chunk := round(v_due, 2);
  v_idem := format('dropship-courier-ar-%s-%s', p_order_id, coalesce(nullif(trim(p_remittance_ref), ''), p_order_id::text));

  v_courier_pot := public.fn_provision_kernel_cashbook_currency(
    v_books_tenant_id, v_courier_profile_id, 'BDT', 'main', 1
  );
  IF v_courier_pot IS NULL THEN
    RAISE EXCEPTION 'courier main cash bundle is required';
  END IF;

  v_dep := public.rpc_deposit(
    v_books_tenant_id,
    v_courier_profile_id,
    v_pay_chunk,
    'BDT',
    v_courier_pot,
    jsonb_build_object(
      'purpose', 'dropship_courier_remittance',
      'shop_order_id', p_order_id,
      'order_no', p_order_no,
      'remittance_ref', p_remittance_ref
    ),
    v_idem || '-fund',
    1::numeric(15, 6),
    'main'
  );

  v_courier_pot := coalesce(
    nullif(v_dep ->> 'cash_bundle_id', '')::bigint,
    nullif(v_dep ->> 'pot_id', '')::bigint,
    v_courier_pot
  );

  PERFORM money_kernel.flush_deferred_pays();

  v_pay := public.rpc_pay_bills(
    v_books_tenant_id,
    v_courier_profile_id,
    v_courier_pot,
    v_pay_chunk,
    jsonb_build_array(jsonb_build_object('bill_id', p_ar_bill_id, 'amount', v_pay_chunk)),
    v_clearing_pot,
    NULL,
    jsonb_build_object(
      'shop_order_id', p_order_id,
      'order_no', p_order_no,
      'remittance_ref', p_remittance_ref,
      'receipt_payment_id', p_receipt_payment_id
    ),
    v_idem || '-pay'
  );

  PERFORM money_kernel.flush_deferred_pays();

  PERFORM public.stamp_bill_kernel_fields(p_ar_bill_id);
  PERFORM public.recompute_global_invoice_payment_status(p_ar_bill_id);

  RETURN round(v_pay_chunk, 2);
END;
$$;

-- Dropship Payment received: issue bills + remittance clearing in one RPC.
CREATE OR REPLACE FUNCTION public.record_dropship_courier_remittance(
  p_order_id bigint,
  p_net_amount numeric,
  p_remittance_ref text,
  p_bank_trx_id text DEFAULT NULL,
  p_payment_date date DEFAULT NULL,
  p_method text DEFAULT 'cash',
  p_note text DEFAULT NULL,
  p_courier_charge numeric DEFAULT 0.00,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_delivery_charge numeric DEFAULT NULL,
  p_cod_charge numeric DEFAULT NULL
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO money_kernel, public, pg_temp
AS $$
declare
  v_order record;
  v_invoice public.bills;
  v_books_tenant_id bigint;
  v_tenant_profile_id bigint;
  v_payment_id bigint;
  v_kernel_pay_id bigint;
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
  v_merchant_pay jsonb;
  v_clearing bigint;
  v_customer_pot bigint;
  v_customer_pay_pot bigint;
  v_idem text;
  v_xfer jsonb;
  v_issue jsonb;
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

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);
  v_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_order.tenant_id);

  select (
    exists (
      select 1
      from public.pays py
      where py.shop_order_id = p_order_id
        and py.source = 'courier_remittance'
        and py.voided_at is null
    )
    or nullif(trim(coalesce(v_order.courier_remittance_ref, '')), '') is not null
  ) into v_already_remitted;

  if v_already_remitted then
    select greatest(coalesce(kb.due_amount, 0), 0) into v_invoice_due
    from money_kernel.bills kb
    where kb.id = v_order.global_invoice_id;

    v_ap_family_due := 0;
    if v_ap_bill_id is not null then
      select greatest(coalesce(kb.due_amount, 0), 0) into v_ap_family_due
      from money_kernel.bills kb
      where kb.id = v_ap_bill_id;
    end if;

    if v_invoice_due <= 0.01 and (v_ap_bill_id is null or v_ap_family_due <= 0.01) then
      select py.id into v_payment_id
      from public.pays py
      where py.shop_order_id = p_order_id
        and py.source = 'courier_remittance'
        and py.voided_at is null
      order by py.id desc
      limit 1;

      return jsonb_build_object(
        'success', true,
        'already_recorded', true,
        'invoice_id', v_order.global_invoice_id,
        'payment_id', v_payment_id,
        'order_id', p_order_id,
        'status', coalesce(v_order.status::text, 'payment_received')
      );
    end if;

    raise exception
      'Courier remittance marker exists but bills are not cleared (merchant due % BDT, courier due % BDT). Reset stale remittance and retry.',
      v_invoice_due,
      v_ap_family_due;
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
    public.user_can_manage_books_tenant(v_books_tenant_id)
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

  v_issue := public.issue_dropship_tenant_b2b_invoice(v_order.tenant_id, p_order_id, false);
  if coalesce(v_issue ->> 'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_issue ->> 'error', 'Failed to issue merchant bill');
  end if;

  v_issue := public.issue_dropship_courier_ar_for_order(v_order.tenant_id, p_order_id);
  if coalesce(v_issue ->> 'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_issue ->> 'error', 'Failed to issue courier AR bill');
  end if;

  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required after issue step';
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Merchant bill must be issued before remittance (current: %)', v_invoice.invoice_status;
  end if;

  if v_invoice.profile_id is null then
    raise exception 'Merchant profile is required on the bill';
  end if;

  select p.id into v_tenant_profile_id
  from public.profiles p
  where p.tenant_id = v_books_tenant_id
    and p.profile_type = 'tenant'::public.profile_party_type
    and p.subject_id = v_order.tenant_id
  limit 1;

  if v_tenant_profile_id is null then
    raise exception 'Tenant money profile is required';
  end if;

  perform public.ensure_tenant_courier_bdt_bundle(v_books_tenant_id, v_tenant_profile_id);

  v_notes := public.apply_dropship_issued_bill_notes_at_deliver(p_order_id);
  if coalesce(v_notes->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_notes->>'error', 'Failed to apply bill notes before courier pay in');
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;

  select greatest(coalesce(kb.due_amount, 0), 0) into v_invoice_due
  from money_kernel.bills kb
  where kb.id = v_invoice.id;

  v_invoice_pay := least(v_net, v_invoice_due);
  v_remainder := greatest(v_net - v_invoice_pay, 0.00);

  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  if v_ap_bill_id is not null then
    select * into v_courier_bill from public.bills where id = v_ap_bill_id for update;

    if v_courier_bill.invoice_status = 'draft'::public.global_invoice_status then
      perform public.rpc_issue_bill(v_books_tenant_id, v_ap_bill_id);
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
        NULL
      );
    elsif public.is_dropship_courier_ar_bill(v_courier_bill) then
      perform public.stamp_bill_kernel_fields(v_ap_bill_id);
      v_courier_ar_settled := public.settle_dropship_courier_ar_from_remittance(
        v_ap_bill_id,
        p_order_id,
        v_order.order_no,
        v_ref,
        NULL
      );
    end if;
  end if;

  perform money_kernel.flush_deferred_pays();

  if v_invoice_pay > 0 then
    v_clearing := public.ensure_tenant_courier_bdt_bundle(v_books_tenant_id, v_tenant_profile_id);
    v_customer_pot := public.fn_provision_kernel_cashbook_currency(
      v_books_tenant_id, v_invoice.profile_id, 'BDT', 'main', 1
    );
    v_idem := format('dropship-merchant-ar-%s-%s', p_order_id, coalesce(nullif(trim(v_ref), ''), p_order_id::text));
    v_xfer := public.rpc_transfer_p2p(
      v_books_tenant_id,
      v_clearing,
      v_customer_pot,
      v_invoice_pay,
      jsonb_build_object('purpose', 'merchant_ar_prefund', 'shop_order_id', p_order_id),
      v_idem || '-xfer'
    );
    v_customer_pay_pot := coalesce(
      nullif(v_xfer ->> 'to_cash_bundle_id', '')::bigint,
      v_customer_pot
    );
    v_merchant_pay := public.rpc_pay_bills(
      v_books_tenant_id,
      v_invoice.profile_id,
      v_customer_pay_pot,
      v_invoice_pay,
      jsonb_build_array(jsonb_build_object('bill_id', v_invoice.id, 'amount', v_invoice_pay)),
      NULL,
      NULL,
      jsonb_build_object('shop_order_id', p_order_id, 'remittance_ref', v_ref),
      v_idem || '-pay'
    );
    v_kernel_pay_id := nullif(v_merchant_pay ->> 'pays_id', '')::bigint;
    perform public.recompute_global_invoice_payment_status(v_invoice.id);
    perform money_kernel.flush_deferred_pays();
  end if;

  select greatest(coalesce(kb.due_amount, 0), 0) into v_invoice_due
  from money_kernel.bills kb
  where kb.id = v_invoice.id;

  if v_invoice_due > 0.01 then
    raise exception
      'Customer bill must be cleared from remittance before dropshipper profit (due % BDT)',
      v_invoice_due;
  end if;

  if v_ap_bill_id is not null and public.is_dropship_courier_ar_bill(v_courier_bill) then
    select greatest(coalesce(kb.due_amount, 0), 0) into v_ap_family_due
    from money_kernel.bills kb
    where kb.id = v_ap_bill_id;
    if v_ap_family_due > 0.01 then
      raise exception
        'Courier AR must be cleared from remittance before dropshipper profit (due % BDT, order %)',
        v_ap_family_due,
        v_order.order_no;
    end if;
  end if;

  if v_remainder > 0 then
    v_clearing := public.ensure_tenant_courier_bdt_bundle(v_books_tenant_id, v_tenant_profile_id);
    v_customer_pot := public.fn_provision_kernel_cashbook_currency(
      v_books_tenant_id, v_invoice.profile_id, 'BDT', 'main', 1
    );
    perform public.rpc_transfer_p2p(
      v_books_tenant_id,
      v_clearing,
      v_customer_pot,
      v_remainder,
      jsonb_build_object('purpose', 'dropship_profit', 'shop_order_id', p_order_id),
      format('dropship-profit-xfer-%s-%s', p_order_id, coalesce(nullif(trim(v_ref), ''), p_order_id::text))
    );
    perform public.credit_dropship_profit_from_courier_remittance(
      v_order.tenant_id,
      v_invoice.profile_id,
      p_order_id,
      coalesce(v_kernel_pay_id, v_payment_id),
      v_remainder,
      v_ref,
      v_net,
      v_invoice_pay
    );
    perform money_kernel.flush_deferred_pays();
  end if;

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code
  ) values (
    v_books_tenant_id, v_invoice.profile_id, 'courier_remittance', v_net, 0,
    coalesce(p_payment_date, current_date),
    coalesce(nullif(trim(p_method), ''), 'cash'),
    v_ref,
    coalesce(nullif(trim(p_note), ''), 'Courier remittance order #' || v_order.order_no),
    p_order_id,
    'BDT'
  )
  returning id into v_payment_id;

  -- settlement snapshot + order status (unchanged)
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
    'kernel_payment_id', v_kernel_pay_id,
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
