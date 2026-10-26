-- BP3 renamed dropship_order_settlements.billing_profile_id → profile_id; redeploy stale settlement RPCs.
CREATE OR REPLACE FUNCTION "public"."save_dropship_settlement_draft"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_detail jsonb;
  v_settlement public.dropship_order_settlements;
  v_has_settlement boolean := false;
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_items_resell_total numeric(15,2);
  v_order_discount_amount numeric(15,2);
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_company_procurement_cost numeric(15,2);
  v_discount_company_pay numeric(15,2);
  v_return_reason_note text;
  v_charge_lines jsonb;
  v_line jsonb;
  v_totals record;
  v_currency_id bigint;
  v_payload_unit numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  v_collected_cod := coalesce((p_payload->>'collected_cod_amount')::numeric, 0);
  v_discount_company_pay := coalesce((p_payload->>'discount_company_pay')::numeric, 0);
  v_return_reason_note := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');
  v_charge_lines := coalesce(p_payload->'charge_lines', '[]'::jsonb);

  if jsonb_typeof(v_charge_lines) <> 'array' then
    raise exception 'charge_lines must be a JSON array';
  end if;

  perform public.apply_dropship_order_charge_lines(p_order_id, v_charge_lines);

  v_payload_unit := (p_payload->>'reseller_unit_purchase_cost')::numeric;
  if v_payload_unit is not null then
    perform public.apply_dropship_reseller_unit_purchase(p_order_id, v_payload_unit);
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);
  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );
  v_items_resell_total := coalesce((v_detail->'computed'->>'items_resell_total')::numeric, 0);
  v_order_discount_amount := coalesce(
    (v_detail->'order'->>'discount_amount')::numeric,
    v_order.discount_amount,
    0
  );

  select s.sell_currency_id into v_currency_id
  from public.shops s where s.id = v_order.shop_id;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  if v_has_settlement and v_settlement.status = 'confirmed' then
    raise exception 'settlement is confirmed and cannot be edited';
  end if;

  select * into v_totals
  from public.compute_dropship_settlement_totals(
    v_items_resell_total,
    v_order_discount_amount,
    v_reseller_purchase_cost,
    v_company_procurement_cost,
    v_discount_company_pay,
    v_charge_lines
  );

  if not v_has_settlement then
    insert into public.dropship_order_settlements (
      tenant_id,
      shop_order_id,
      profile_id,
      currency_id,
      calculated_cod_amount,
      collected_cod_amount,
      reseller_unit_purchase_cost,
      reseller_purchase_cost,
      discount_company_pay,
      return_reason_note,
      total_cost,
      reseller_profit,
      company_profit,
      status
    ) values (
      v_order.tenant_id,
      p_order_id,
      v_order.profile_id,
      v_currency_id,
      v_calculated_cod,
      v_collected_cod,
      v_reseller_unit_purchase_cost,
      v_reseller_purchase_cost,
      v_discount_company_pay,
      v_return_reason_note,
      v_totals.total_cost,
      v_totals.reseller_profit,
      v_totals.company_profit,
      'draft'
    )
    returning * into v_settlement;
  else
    update public.dropship_order_settlements
    set
      profile_id = coalesce(v_order.profile_id, profile_id),
      currency_id = coalesce(v_currency_id, currency_id),
      calculated_cod_amount = v_calculated_cod,
      collected_cod_amount = v_collected_cod,
      reseller_unit_purchase_cost = v_reseller_unit_purchase_cost,
      reseller_purchase_cost = v_reseller_purchase_cost,
      discount_company_pay = v_discount_company_pay,
      return_reason_note = v_return_reason_note,
      total_cost = v_totals.total_cost,
      reseller_profit = v_totals.reseller_profit,
      company_profit = v_totals.company_profit,
      updated_at = now()
    where id = v_settlement.id
    returning * into v_settlement;
  end if;

  if v_settlement.id is null then
    raise exception 'settlement row missing after upsert';
  end if;

  delete from public.dropship_settlement_charge_lines
  where settlement_id = v_settlement.id;

  for v_line in select value from jsonb_array_elements(v_charge_lines)
  loop
    insert into public.dropship_settlement_charge_lines (
      settlement_id,
      charge_type,
      amount,
      payer
    ) values (
      v_settlement.id,
      (v_line->>'charge_type')::public.dropship_settlement_charge_type,
      coalesce((v_line->>'amount')::numeric, 0),
      (v_line->>'payer')::public.dropship_settlement_charge_payer
    );
  end loop;

  return jsonb_build_object(
    'success', true,
    'settlement_id', v_settlement.id,
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', v_settlement.status,
      'calculated_cod_amount', v_calculated_cod,
      'collected_cod_amount', v_settlement.collected_cod_amount,
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
      'discount_company_pay', v_settlement.discount_company_pay,
      'return_reason_note', v_settlement.return_reason_note,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at
    )
  );
end;
$$;
CREATE OR REPLACE FUNCTION "public"."transfer_dropship_reseller_profit"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_save jsonb;
  v_profile_id bigint;
  v_amount numeric(15,2);
  v_parent_tenant_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement draft is required before crediting reseller profit';
  end if;

  if v_order.status = 'reseller_paid'::public.shop_order_status
     or v_settlement.merchant_payout_at is not null
     or v_settlement.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'status', coalesce(v_order.status::text, 'reseller_paid')
    );
  end if;

  if v_order.courier_remittance_ref is null
     and v_settlement.remittance_at is null
     and v_order.status <> 'payment_received'::public.shop_order_status then
    raise exception 'Courier remittance must be recorded before crediting reseller profit (current: %)', v_order.status;
  end if;

  if p_payload is not null and p_payload <> '{}'::jsonb then
    v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
    if coalesce(v_save->>'success', 'false') <> 'true' then
      return v_save;
    end if;

    select * into v_settlement
    from public.dropship_order_settlements
    where shop_order_id = p_order_id;
  end if;

  v_profile_id := coalesce(v_order.profile_id, v_settlement.profile_id);
  if v_profile_id is null then
    raise exception 'billing profile is required for reseller profit credit';
  end if;

  v_amount := coalesce(v_settlement.reseller_profit, 0);
  if v_amount <= 0 then
    return jsonb_build_object(
      'success', true,
      'skipped', true,
      'message', 'No reseller profit to credit',
      'order_id', p_order_id,
      'amount', 0
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if exists (
    select 1
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = v_profile_id
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
  ) then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'amount', v_amount
    );
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => v_order.tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_profile_id,
    p_type => 'credit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'transaction_type', 'dropship_profit',
      'label', 'Dropship profit earned',
      'order_no', v_order.order_no,
      'order_id', p_order_id,
      'shop_order_id', p_order_id::text,
      'invoice_id', v_order.global_invoice_id,
      'notes', coalesce(
        nullif(trim(p_payload->>'reference_notes'), ''),
        'Dropship reseller profit for order #' || v_order.order_no
      )
    )
  );

  update public.dropship_order_settlements
  set
    status = 'confirmed',
    confirmed_at = now(),
    confirmed_by = auth.uid(),
    merchant_payout_at = now(),
    updated_at = now()
  where id = v_settlement.id;

  update public.shop_orders
  set
    status = 'reseller_paid'::public.shop_order_status,
    payout_settlement_status = 'paid',
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Reseller profit credited to merchant wallet',
    'order_id', p_order_id,
    'amount', v_amount,
    'status', 'reseller_paid',
    'profile_id', v_profile_id
  );
end;
$$;

DROP FUNCTION IF EXISTS public.get_my_dropship_wallet_summary();

CREATE OR REPLACE FUNCTION "public"."get_my_dropship_wallet_summary"() RETURNS TABLE("profile_id" bigint, "available_balance" numeric, "pending_balance" numeric, "locked_balance" numeric, "currency" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text := public.current_user_email();
  v_tenant_id bigint;
  v_group_id bigint;
  v_bp_id bigint;
  v_available numeric := 0;
  v_pending numeric := 0;
  v_locked numeric := 0;
begin
  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'Not authenticated';
  end if;

  select cg.tenant_id, cgm.customer_group_id
  into v_tenant_id, v_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = lower(trim(v_email))
    and cgm.is_active = true
    and cg.is_active = true
  order by cgm.id
  limit 1;

  if v_tenant_id is null or v_group_id is null then
    raise exception 'No active customer group membership';
  end if;

  v_bp_id := public.resolve_customer_profile_for_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  select coalesce(w.available_balance, 0)
  into v_available
  from public.cashbook_accounts w
  where w.parent_tenant_id = public.resolve_parent_tenant_id(v_tenant_id)
    and w.entity_type = 'customer'
    and w.entity_id = v_bp_id
    and w.currency_code = 'BDT';

  select coalesce(sum(s.reseller_profit), 0)
  into v_pending
  from public.shop_orders o
  join public.dropship_order_settlements s on s.shop_order_id = o.id
  where o.tenant_id = v_tenant_id
    and o.profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'::public.shop_order_status
    and coalesce(s.reseller_profit, 0) > 0
    and s.merchant_payout_at is null;

  select coalesce(sum(greatest(coalesce(o.cod_collect_amount, 0), 0)), 0)
  into v_locked
  from public.shop_orders o
  where o.tenant_id = v_tenant_id
    and o.profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'delivered'
    and o.courier_remittance_ref is null
    and coalesce(o.collection_source, 'recipient') = 'recipient';

  return query select
    v_bp_id,
    v_available,
    v_pending,
    v_locked,
    'BDT'::text;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text" DEFAULT NULL::"text", "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return public.record_dropship_courier_remittance(
    p_order_id,
    p_net_amount,
    p_remittance_ref,
    p_bank_trx_id,
    p_payment_date,
    p_method,
    p_note,
    0.00
  );
end;
$$;
CREATE OR REPLACE FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text" DEFAULT NULL::"text", "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_note" "text" DEFAULT NULL::"text", "p_courier_charge" numeric DEFAULT 0.00) RETURNS "jsonb"
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

  select exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_already_remitted;

  if v_already_remitted then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'invoice_id', v_order.global_invoice_id,
      'order_id', p_order_id,
      'status', v_order.status
    );
  end if;

  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  end if;

  v_net := coalesce(p_net_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);

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

  v_invoice_due := greatest(coalesce(v_invoice.due_amount, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_remainder := greatest(v_net - v_invoice_pay, 0.00);

  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  update public.cashbook_entries
  set metadata = metadata || jsonb_build_object(
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_remainder
  )
  where parent_tenant_id = v_parent_tenant_id
    and entity_type = 'tenant'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received';

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
    p_source => 'courier_remittance',
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
          'reference', nullif(trim(coalesce(p_bank_trx_id, '')), '')
        )
      )
    ),
    p_allocations => case
      when v_invoice_pay > 0 then jsonb_build_array(jsonb_build_object('bill_id', v_invoice.id, 'amount', v_invoice_pay))
      else '[]'::jsonb
    end,
    p_shop_order_id => p_order_id
  );
  v_payment_id := v_pay.id;

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
    'merchant_remainder', v_remainder
  );
end;
$$;
