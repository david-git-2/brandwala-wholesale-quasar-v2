CREATE OR REPLACE FUNCTION "public"."settle_dropship_courier_ap_via_cod_retention"(
  "p_ap_bill_id" bigint,
  "p_amount" numeric,
  "p_order_id" bigint,
  "p_remittance_ref" "text",
  "p_receipt_payment_id" bigint DEFAULT NULL::bigint
) RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ap public.bills;
  v_bal jsonb;
  v_family_due numeric(12, 2);
  v_remaining numeric(12, 2);
  v_chunk numeric(12, 2);
  v_total_settled numeric(12, 2) := 0;
  v_bill record;
  v_operating_tenant_id bigint;
  v_note text;
begin
  if p_ap_bill_id is null then
    return 0;
  end if;

  select * into v_ap from public.bills where id = p_ap_bill_id for update;
  if v_ap.id is null then
    raise exception 'courier AP bill not found';
  end if;

  if v_ap.invoice_type <> 'ap'::public.global_invoice_type then
    raise exception 'bill is not an AP bill';
  end if;

  if v_ap.invoice_status <> 'issued'::public.global_invoice_status then
    return 0;
  end if;

  v_bal := public.get_bill_net_balances(p_ap_bill_id);
  v_family_due := greatest(coalesce((v_bal->>'due_amount')::numeric, 0), 0);
  v_remaining := least(
    round(greatest(coalesce(p_amount, 0), 0), 2),
    v_family_due
  );

  if v_remaining <= 0 then
    return 0;
  end if;

  v_note := format(
    'Courier COD retention — order #%s — remittance %s',
    p_order_id,
    coalesce(nullif(trim(p_remittance_ref), ''), '—')
  );

  for v_bill in
    select
      b.id,
      b.due_amount,
      b.issued_by_tenant_id,
      b.parent_tenant_id
    from public.bills b
    where (
        b.id = p_ap_bill_id
        or b.parent_bill_id = p_ap_bill_id
      )
      and b.invoice_status = 'issued'::public.global_invoice_status
      and greatest(coalesce(b.due_amount, 0), 0) > 0
    order by
      case when b.id = p_ap_bill_id then 0 else 1 end,
      b.id
    for update
  loop
    v_chunk := least(v_remaining, greatest(coalesce(v_bill.due_amount, 0), 0));
    if v_chunk <= 0 then
      continue;
    end if;

    v_operating_tenant_id := coalesce(v_bill.issued_by_tenant_id, v_bill.parent_tenant_id);

    insert into public.invoice_write_offs (
      tenant_id,
      parent_tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    values (
      v_operating_tenant_id,
      v_bill.parent_tenant_id,
      v_bill.id,
      p_receipt_payment_id,
      v_chunk,
      'dispute_settlement',
      v_note,
      auth.uid()
    );

    perform public.recompute_global_invoice_payment_status(v_bill.id);

    v_total_settled := v_total_settled + v_chunk;
    v_remaining := v_remaining - v_chunk;

    if v_remaining <= 0 then
      exit;
    end if;
  end loop;

  perform public.recompute_global_invoice_payment_status(p_ap_bill_id);

  return round(v_total_settled, 2);
end;
$$;

ALTER FUNCTION "public"."settle_dropship_courier_ap_via_cod_retention"("p_ap_bill_id" bigint, "p_amount" numeric, "p_order_id" bigint, "p_remittance_ref" "text", "p_receipt_payment_id" bigint) OWNER TO "postgres";
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

  v_invoice_due := greatest(coalesce(v_invoice.due_amount, 0.00), 0.00);
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
    p_shop_order_id => p_order_id
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
CREATE OR REPLACE FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_detail jsonb;
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_charge_lines jsonb;
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_order_item_quantity integer;
  v_company_procurement_cost numeric(15,2);
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_courier_name text;
  v_has_settlement boolean := false;
  v_invoice jsonb;
  v_is_returned boolean := false;
  v_gift_cost_merchant_total numeric(15,2) := 0;
  v_gift_cost_tenant_total numeric(15,2) := 0;
  v_parent_tenant_id bigint;
  v_courier_ap_bill_id bigint;
  v_courier_ap_due numeric(15,2) := 0;
  v_dropship_profit_credited numeric(15,2) := 0;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
    and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id);

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select coalesce(sum(ce.amount), 0)
  into v_dropship_profit_credited
  from public.cashbook_entries ce
  where ce.parent_tenant_id = v_parent_tenant_id
    and ce.source_type = 'shop_order'
    and ce.source_id = p_order_id::text
    and ce.type = 'credit'
    and coalesce(ce.metadata->>'transaction_type', '') = 'dropship_profit';

  v_courier_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_courier_ap_bill_id is not null then
    v_courier_ap_due := greatest(
      coalesce((public.get_bill_net_balances(v_courier_ap_bill_id)->>'due_amount')::numeric, 0),
      0
    );
  end if;

  select
    coalesce(sum(soi.gift_cost_amount) filter (
      where coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
        and soi.gift_cost_charged_to = 'reseller'
        and coalesce(soi.gift_cost_amount, 0) > 0
    ), 0),
    coalesce(sum(soi.gift_cost_amount) filter (
      where coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
        and soi.gift_cost_charged_to = 'tenant'
        and coalesce(soi.gift_cost_amount, 0) > 0
    ), 0)
  into v_gift_cost_merchant_total, v_gift_cost_tenant_total
  from public.shop_order_items soi
  where soi.order_id = p_order_id;

  v_is_returned := v_order.status = 'returned'::public.shop_order_status;

  if v_order.status not in ('shipped', 'delivered', 'payment_received', 'reseller_paid', 'returned') then
    raise exception 'order status % is not eligible for dropship management desk', v_order.status;
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);

  select coalesce(cs.name, v_order.courier_name)
  into v_courier_name
  from public.courier_services cs
  where cs.id::text = v_order.courier_service_id::text;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost,
    rp.order_item_quantity
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost, v_order_item_quantity
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id
    and (o.tenant_id = p_tenant_id or o.parent_tenant_id = p_tenant_id);

  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  v_charge_lines := public.build_dropship_management_charge_lines(
    v_order,
    case when v_has_settlement then v_settlement.id else null end
  );

  if v_has_settlement then
    v_collected_cod := v_settlement.collected_cod_amount;
  else
    v_collected_cod := coalesce(v_order.cod_collect_amount, v_calculated_cod);
  end if;

  if v_order.global_invoice_id is null then
    v_invoice := null;
  else
    select jsonb_build_object(
      'id', i.id,
      'invoice_no', i.invoice_no,
      'invoice_status', i.invoice_status,
      'payment_status', i.payment_status,
      'total_amount', i.total_amount,
      'due_amount', i.due_amount
    )
    into v_invoice
    from public.bills i
    where i.id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'order', (v_detail->'order') || jsonb_build_object(
      'courier_name', v_courier_name,
      'payout_settlement_status', v_order.payout_settlement_status,
      'returned_at', v_order.returned_at,
      'return_charge_amount', coalesce(v_order.return_charge_amount, 0),
      'deduct_return_charge_from_middle_man', coalesce(v_order.deduct_return_charge_from_middle_man, false),
      'return_override_reason', v_order.return_override_reason,
      'courier_ap_bill_id', v_courier_ap_bill_id
    ),
    'items', coalesce(v_detail->'items', '[]'::jsonb),
    'fulfillment', v_detail->'fulfillment',
    'computed', (v_detail->'computed') || jsonb_build_object(
      'order_item_quantity', v_order_item_quantity
    ),
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', coalesce(v_settlement.status::text, 'draft'),
      'calculated_cod_amount', coalesce(v_calculated_cod, v_settlement.calculated_cod_amount),
      'collected_cod_amount', coalesce(v_settlement.collected_cod_amount, v_collected_cod),
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
      'discount_company_pay', coalesce(v_settlement.discount_company_pay, 0),
      'return_reason_note', coalesce(v_settlement.return_reason_note, ''),
      'charge_lines', v_charge_lines,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at,
      'gift_cost_merchant_total', v_gift_cost_merchant_total,
      'gift_cost_tenant_total', v_gift_cost_tenant_total,
      'dropship_profit_credited', v_dropship_profit_credited,
      'courier_ap_due', v_courier_ap_due
    ),
    'invoice', v_invoice,
    'step_state', jsonb_build_object(
      'can_mark_returned',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_mark_delivered',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_issue_invoice',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and v_order.global_invoice_id is null,
      'can_record_bank_transfer',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.remittance_at is null),
      'can_transfer_to_reseller',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.status is distinct from 'confirmed')
        and (not v_has_settlement or v_settlement.merchant_payout_at is null)
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";
