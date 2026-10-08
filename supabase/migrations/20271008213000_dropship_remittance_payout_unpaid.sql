-- Remittance leftover credits shop cashbook; payout_settlement_status stays unpaid until dispense.
-- Backfill orders incorrectly marked paid at remittance.

update public.shop_orders o
set
  payout_settlement_status = 'unpaid',
  updated_at = now()
where o.shop_type_snapshot = 'dropship'
  and o.status in ('payment_received', 'reseller_paid')
  and coalesce(o.payout_settlement_status, 'unpaid') = 'paid'
  and exists (
    select 1
    from public.cashbook_entries u
    where u.source_type = 'shop_order'
      and u.source_id = o.id::text
      and u.type = 'credit'
      and coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
  )
  and not exists (
    select 1
    from public.cashbook_entries u
    where u.entity_type in ('middleman', 'customer')
      and u.entity_id = o.billing_profile_id
      and u.type = 'debit'
      and coalesce(u.metadata ->> 'transaction_type', '') = 'profit_paid_out'
      and coalesce(u.metadata ->> 'shop_order_id', u.metadata ->> 'order_id', '') = o.id::text
  );

CREATE OR REPLACE FUNCTION "public"."apply_dropship_payout_settlement_fifo"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  v_parent_tenant_id bigint;
  r record;
  v_hold numeric;
  v_paid numeric;
  v_outstanding numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  for r in
    select o.id
    from public.shop_orders o
    where o.billing_profile_id = p_billing_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
      and (
        o.tenant_id = p_tenant_id
        or o.parent_tenant_id = v_parent_tenant_id
        or o.tenant_id = v_parent_tenant_id
      )
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0)
    into v_hold
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

    select coalesce(sum(u.amount), 0)
    into v_paid
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_billing_profile_id
      and u.type = 'debit'
      and coalesce(u.metadata->>'transaction_type', '') = 'profit_paid_out'
      and coalesce(u.metadata->>'shop_order_id', u.metadata->>'order_id', '') = r.id::text;

    v_outstanding := greatest(v_hold - v_paid, 0);

    if v_outstanding <= 0 then
      continue;
    end if;

    if v_remaining >= v_outstanding then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      v_remaining := v_remaining - v_outstanding;
    else
      update public.shop_orders
      set payout_settlement_status = 'partial',
          updated_at = now()
      where id = r.id;
      v_remaining := 0;
    end if;
  end loop;
end;
$$;;


CREATE OR REPLACE FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_summary jsonb;
  v_orders jsonb;
  v_merchants jsonb;
  v_parent_tenant_id bigint;
  v_is_parent_scope boolean;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent_scope := (p_tenant_id = v_parent_tenant_id);

  v_summary := public.get_wallet_dashboard_summary(p_tenant_id);

  with finance_orders as (
    select
      o.id,
      o.order_no,
      o.recipient_name,
      o.status,
      o.cod_collect_amount,
      o.delivery_charge_amount,
      o.cod_charge_amount,
      o.driver_notes,
      o.courier_name,
      o.courier_remittance_ref,
      o.courier_bank_trx_id,
      o.billing_profile_id,
      o.created_at,
      o.collection_source,
      o.payout_settlement_status,
      o.is_prepaid_snapshot,
      o.global_invoice_id,
      s.name as shop_name,
      bp.name as billing_profile_name,
      inv.collection_source as invoice_collection_source,
      inv.total_amount as invoice_total_amount,
      inv.paid_amount as invoice_paid_amount
    from public.shop_orders o
    left join public.shops s on s.id = o.shop_id
    left join public.billing_profiles bp on bp.id = o.billing_profile_id
    left join public.bills inv on inv.id = o.global_invoice_id
    where (
        (v_is_parent_scope and (o.parent_tenant_id = p_tenant_id or o.tenant_id = p_tenant_id))
        or (not v_is_parent_scope and o.tenant_id = p_tenant_id)
      )
      and o.shop_type_snapshot = 'dropship'
      and o.status in ('delivered', 'payment_received')
  ),
  ledger_flags as (
    select
      l.source_id,
      max(case when coalesce(l.metadata->>'purpose', '') in ('delivered_costing', 'courier_cod_receivable') then 1 else 0 end) as has_delivered_costing,
      max(case when coalesce(l.metadata->>'purpose', '') in ('courier_remittance', 'tenant_remittance_received') then 1 else 0 end) as has_remittance
    from public.cashbook_entries l
    where l.parent_tenant_id = v_parent_tenant_id
      and l.source_type = 'shop_order'
      and l.source_id in (select fo.id::text from finance_orders fo)
    group by l.source_id
  ),
  order_rows as (
    select
      fo.id,
      fo.order_no as "orderNo",
      fo.recipient_name as "customerName",
      fo.shop_name as "shopName",
      fo.courier_name as "courierName",
      fo.status::text as status,
      case
        when fo.global_invoice_id is not null then coalesce(fo.invoice_total_amount, 0)
        else coalesce(fo.cod_collect_amount, 0)
      end as "totalAmount",
      coalesce(fo.cod_collect_amount, 0) as "codCollectAmount",
      coalesce(fo.delivery_charge_amount, 0) as "deliveryChargeAmount",
      coalesce(fo.cod_charge_amount, 0) as "codChargeAmount",
      fo.driver_notes as "courierNotes",
      fo.courier_remittance_ref as "courierRemittanceRef",
      fo.courier_bank_trx_id as "courierBankTrxId",
      fo.billing_profile_id as "billingProfileId",
      fo.billing_profile_name as "billingProfileName",
      fo.created_at as "createdAt",
      case
        when fo.status::text = 'delivered'
          and coalesce(lf.has_remittance, 0) = 0
          and fo.courier_remittance_ref is null
          and coalesce(fo.cod_collect_amount, 0) > 0
          and coalesce(
            fo.collection_source,
            fo.invoice_collection_source,
            case when fo.is_prepaid_snapshot then 'billing_profile' else 'recipient' end
          ) <> 'billing_profile'
          then 'courier_remittance'
        when coalesce(lf.has_delivered_costing, 0) = 0 and fo.status::text = 'delivered' then 'delivered_costing'
        when fo.status::text = 'delivered'
          or (coalesce(lf.has_remittance, 0) = 0 and fo.status::text <> 'payment_received')
          then 'courier_remittance'
        when fo.status::text = 'payment_received'
          and coalesce(fo.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
          then 'middleman_payout'
        else 'completed'
      end as "nextStep",
      coalesce(
        fo.collection_source,
        fo.invoice_collection_source,
        case when fo.is_prepaid_snapshot then 'billing_profile' else null end
      ) as "collectionSource",
      coalesce(fo.payout_settlement_status, 'unpaid') as "payoutSettlementStatus",
      case
        when fo.global_invoice_id is not null then greatest(coalesce(fo.invoice_total_amount, 0) - coalesce(fo.invoice_paid_amount, 0), 0)
        else null
      end as "invoiceOutstanding"
    from finance_orders fo
    left join ledger_flags lf on lf.source_id = fo.id::text
    order by fo.created_at desc
  )
  select coalesce(jsonb_agg(to_jsonb(order_rows)), '[]'::jsonb)
  into v_orders
  from order_rows;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bp.id,
        'name', bp.name,
        'payableBalance', coalesce(wa.available_balance, 0)
      )
      order by bp.name
    ),
    '[]'::jsonb
  )
  into v_merchants
  from public.billing_profiles bp
  left join public.cashbook_accounts wa
    on wa.parent_tenant_id = v_parent_tenant_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
   and wa.currency_code = 'BDT'
  where bp.tenant_id = p_tenant_id
     or bp.tenant_id = v_parent_tenant_id;

  return jsonb_build_object(
    'kpis', jsonb_build_object(
      'courierOwedTotal', coalesce((v_summary->>'courier_cod_holding_total')::numeric, 0),
      'tenantCashTotal', coalesce((v_summary->>'tenant_cash_total')::numeric, 0),
      'middlemanPayableTotal', coalesce((v_summary->>'merchant_available_total')::numeric, 0)
    ),
    'orders', coalesce(v_orders, '[]'::jsonb),
    'merchants', coalesce(v_merchants, '[]'::jsonb)
  );
end;
$$;;


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
    p_billing_profile_id => v_invoice.profile_id,
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
$$;;
