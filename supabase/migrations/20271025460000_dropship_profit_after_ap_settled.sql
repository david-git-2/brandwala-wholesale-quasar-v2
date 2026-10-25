CREATE OR REPLACE FUNCTION "public"."credit_dropship_profit_from_courier_remittance"(
  "p_tenant_id" bigint,
  "p_profile_id" bigint,
  "p_order_id" bigint,
  "p_payment_id" bigint,
  "p_amount" numeric,
  "p_reference" "text",
  "p_net_remitted" numeric,
  "p_invoice_allocated" numeric
) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_profit_already_credited boolean := false;
  v_amount numeric(12, 2);
begin
  v_amount := round(greatest(coalesce(p_amount, 0), 0), 2);
  if v_amount <= 0 then
    return;
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select exists (
    select 1
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_profile_id
      and u.type = 'credit'
      and coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
  ) into v_profit_already_credited;

  if v_profit_already_credited then
    return;
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
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
      'label', 'Dropship profit from remittance remainder',
      'order_id', p_order_id,
      'shop_order_id', p_order_id::text,
      'payment_id', p_payment_id,
      'remittance_ref', p_reference,
      'net_remitted', p_net_remitted,
      'invoice_allocated', p_invoice_allocated
    )
  );
end;
$$;

ALTER FUNCTION "public"."credit_dropship_profit_from_courier_remittance"("p_tenant_id" bigint, "p_profile_id" bigint, "p_order_id" bigint, "p_payment_id" bigint, "p_amount" numeric, "p_reference" "text", "p_net_remitted" numeric, "p_invoice_allocated" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" "date", "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_source" "text" DEFAULT 'customer_cash'::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_credit_dropship_profit" boolean DEFAULT true) RETURNS "public"."pays"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_source text := lower(trim(coalesce(p_source, 'customer_cash')));
  v_received_on date := coalesce(p_received_on, current_date);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_reference text := nullif(trim(coalesce(p_reference, '')), '');
  v_pay public.pays;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int := 0;
  v_amount numeric(12, 2) := 0.00;
  v_header_method text;
  v_alloc jsonb;
  v_bill public.bills;
  v_bill_id bigint;
  v_alloc_amount numeric(12, 2);
  v_total_alloc numeric(12, 2) := 0.00;
  v_leftover numeric(12, 2);
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_cashbook_point_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;
  if v_source not in ('customer_cash', 'bank', 'store_credit', 'courier_remittance') then
    raise exception 'Invalid receipt source: %', p_source;
  end if;
  if v_source = 'courier_remittance' and p_shop_order_id is null then
    raise exception 'Courier remittance requires a shop order';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: cannot record receipts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.parent_tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_profile_id;
  end if;

  -- Instruments: validate and total (header amount = instrument sum).
  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then
        continue;
      end if;
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
      if v_line_count = 1 then
        v_header_method := lower(v_method_code);
      else
        v_header_method := 'split';
      end if;
    end loop;
  end if;

  if v_source = 'store_credit' then
    if v_line_count > 0 then
      raise exception 'Store credit receipts take no instrument lines';
    end if;
    v_header_method := 'store_credit';
  elsif v_line_count = 0 then
    raise exception 'Enter at least one payment line';
  end if;

  if v_header_method is not null and v_header_method not in (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split',
    'store_credit'
  ) then
    v_header_method := 'other';
  end if;

  if v_source <> 'store_credit' then
    select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
    into v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
    from public.normalize_pay_settlement_fx(
      v_amount,
      p_settlement_currency_code,
      p_foreign_amount,
      p_exchange_rate,
      public.resolve_tenant_base_currency_code(p_tenant_id)
    ) n;
  end if;

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code, foreign_amount, exchange_rate
  ) values (
    v_parent_id, p_profile_id, v_source, v_amount, v_amount,
    v_received_on, v_header_method, v_reference, v_note, p_shop_order_id,
    v_settle_currency, v_foreign_amt, v_fx_rate
  ) returning * into v_pay;

  if v_line_count > 0 then
    perform public.insert_global_payment_instruments(v_pay.id, p_instruments);
  end if;

  -- Allocations: open issued bills of this profile only.
  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    for v_alloc in select value from jsonb_array_elements(p_allocations)
    loop
      v_bill_id := coalesce(nullif(v_alloc ->> 'bill_id', '')::bigint, nullif(v_alloc ->> 'invoice_id', '')::bigint);
      v_alloc_amount := round(coalesce((v_alloc ->> 'amount')::numeric, 0.00), 2);
      if v_bill_id is null or v_alloc_amount <= 0 then
        continue;
      end if;

      select * into v_bill from public.bills where id = v_bill_id for update;
      if v_bill.id is null then
        raise exception 'Bill % not found', v_bill_id;
      end if;
      if v_bill.parent_tenant_id <> v_parent_id then
        raise exception 'Bill % belongs to other books', v_bill_id;
      end if;
      if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
        raise exception 'Bill % is not issued', v_bill.invoice_no;
      end if;
      if v_bill.profile_id is distinct from p_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;
      if v_alloc_amount > coalesce(v_bill.due_amount, 0.00) then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_bill.due_amount;
      end if;

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_bill_id, v_alloc_amount);

      perform public.recompute_global_invoice_payment_status(v_bill_id);
      v_total_alloc := v_total_alloc + v_alloc_amount;
    end loop;
  end if;

  if v_source = 'store_credit' then
    if v_total_alloc <= 0 then
      raise exception 'Store credit receipt needs at least one allocation';
    end if;
    v_amount := v_total_alloc;
  elsif v_total_alloc > v_amount then
    raise exception 'Allocations (%) exceed receipt amount (%)', v_total_alloc, v_amount;
  end if;

  v_leftover := v_amount - v_total_alloc;

  update public.pays
  set amount = v_amount, unallocated_amount = v_leftover
  where id = v_pay.id
  returning * into v_pay;

  v_cashbook_point_id := null;
  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      if nullif(v_line.value ->> 'cashbook_point_id', '') is not null then
        v_cashbook_point_id := (v_line.value ->> 'cashbook_point_id')::bigint;
        exit;
      end if;
    end loop;
  end if;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if v_source = 'courier_remittance' and v_cashbook_point_id is null then
      raise exception 'Courier remittance requires a cashbook location';
    end if;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => case when v_source = 'courier_remittance' then 'shop_order' else 'sales_invoice' end,
      p_source_id => case when v_source = 'courier_remittance' then p_shop_order_id::text else v_pay.id::text end,
      p_metadata => jsonb_build_object(
        'section', case when v_source = 'courier_remittance' then 'payment_received' else 'payments' end,
        'purpose', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'tenant_payment_received'
        end,
        'transaction_type', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'payment_received'
        end,
        'label', case when v_source = 'courier_remittance' then 'Courier remittance received' else 'Payment received' end,
        'payment_id', v_pay.id,
        'method', v_header_method,
        'instrument_count', v_line_count,
        'reference', v_reference,
        'shop_order_id', case when v_source = 'courier_remittance' then p_shop_order_id else null end
      ),
      p_cashbook_point_id => v_cashbook_point_id
    );
  elsif v_source = 'store_credit' then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => p_profile_id,
      p_type => 'debit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_pay.id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied store credit',
        'payment_id', v_pay.id
      )
    );
  end if;

  if v_leftover > 0 then
    if v_source = 'courier_remittance' then
      if coalesce(p_credit_dropship_profit, true) then
        perform public.credit_dropship_profit_from_courier_remittance(
          p_tenant_id,
          p_profile_id,
          p_shop_order_id,
          v_pay.id,
          v_leftover,
          v_reference,
          v_amount,
          v_total_alloc
        );
      end if;
    else
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => p_profile_id,
        p_type => 'credit',
        p_amount => v_leftover,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_pay.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'store_credit',
          'payment_id', v_pay.id,
          'reference', v_reference
        )
      );
    end if;
  end if;

  return v_pay;
end;
$$;

ALTER FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" "date", "p_note" "text", "p_reference" "text", "p_source" "text", "p_instruments" "jsonb", "p_allocations" "jsonb", "p_shop_order_id" bigint, "p_settlement_currency_code" "text", "p_foreign_amount" numeric, "p_exchange_rate" numeric, "p_credit_dropship_profit" boolean) OWNER TO "postgres";
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
    p_credit_dropship_profit => false
  );
  v_payment_id := v_pay.id;

  v_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_ap_bill_id is not null then
    v_ap_bal := public.get_bill_net_balances(v_ap_bill_id);
    v_ap_family_due := greatest(coalesce((v_ap_bal->>'due_amount')::numeric, 0), 0);
    v_ap_settled := public.settle_dropship_courier_ap_via_cod_retention(
      v_ap_bill_id,
      least(v_charge, v_ap_family_due),
      p_order_id,
      v_ref,
      v_payment_id
    );
  end if;

  v_ar_bal := public.get_bill_net_balances(v_invoice.id);
  if greatest(coalesce((v_ar_bal->>'due_amount')::numeric, 0.00), 0.00) > 0.01 then
    raise exception
      'Customer bill must be cleared from remittance before dropshipper profit (due % BDT)',
      (v_ar_bal->>'due_amount')::numeric;
  end if;

  if v_ap_bill_id is not null then
    v_ap_bal := public.get_bill_net_balances(v_ap_bill_id);
    if greatest(coalesce((v_ap_bal->>'due_amount')::numeric, 0.00), 0.00) > 0.01 then
      raise exception
        'Courier AP must be settled from COD retention before dropshipper profit (due % BDT)',
        (v_ap_bal->>'due_amount')::numeric;
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
    'bill_notes', v_notes
  );
end;
$$;

ALTER FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_method" "text", "p_note" "text", "p_courier_charge" numeric, "p_cashbook_point_id" bigint, "p_delivery_charge" numeric, "p_cod_charge" numeric) OWNER TO "postgres";

GRANT ALL ON FUNCTION public.credit_dropship_profit_from_courier_remittance(bigint, bigint, bigint, bigint, numeric, text, numeric, numeric) TO authenticated;
GRANT ALL ON FUNCTION public.credit_dropship_profit_from_courier_remittance(bigint, bigint, bigint, bigint, numeric, text, numeric, numeric) TO service_role;

