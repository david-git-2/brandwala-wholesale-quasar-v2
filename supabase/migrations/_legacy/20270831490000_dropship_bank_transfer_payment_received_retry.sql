-- Allow bank transfer retry when order is payment_received but settlement remittance_at is unset.
-- Align COD cap with settlement collected amount. Repair idempotent remittance paths.

begin;

create or replace function public.record_dropship_courier_remittance(
  p_order_id bigint,
  p_net_amount numeric,
  p_remittance_ref text,
  p_bank_trx_id text default null,
  p_payment_date date default null,
  p_method text default 'cash',
  p_note text default null,
  p_courier_charge numeric default 0.00
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_invoice public.global_invoices;
  v_parent_tenant_id bigint;
  v_payment_id bigint;
  v_ref text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_invoice_due numeric(12,2);
  v_invoice_pay numeric(12,2);
  v_profit_hold numeric(12,2);
  v_currency text := 'BDT';
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

  select exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
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

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
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

  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;

  v_invoice_due := greatest(coalesce(v_invoice.total_amount, 0.00) - coalesce(v_invoice.paid_amount, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_profit_hold := greatest(v_net - v_invoice_pay, 0.00);

  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  update public.universal_wallet_ledger
  set metadata = metadata || jsonb_build_object(
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_profit_hold
  )
  where tenant_id = v_order.tenant_id
    and entity_type = 'tenant'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received';

  if v_invoice_pay > 0 then
    insert into public.global_payments (
      tenant_id,
      billing_profile_id,
      collection_source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      reference,
      note
    )
    values (
      v_invoice.tenant_id,
      null,
      'recipient'::public.collection_source_type,
      v_invoice_pay,
      0.00,
      coalesce(p_payment_date, current_date),
      coalesce(nullif(trim(p_method), ''), 'cash'),
      v_ref,
      coalesce(
        nullif(trim(p_note), ''),
        'Courier remittance order #' || v_order.order_no
          || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
          || ' (invoice ' || v_invoice_pay::text || ' / held ' || v_profit_hold::text || ')'
      )
    )
    returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_invoice.tenant_id, v_payment_id, v_order.global_invoice_id, v_invoice_pay);

    update public.global_invoices
    set
      paid_amount = coalesce(paid_amount, 0.00) + v_invoice_pay,
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
    where id = v_order.global_invoice_id;

    perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

    if v_invoice.billing_profile_id is not null and not exists (
      select 1 from public.universal_wallet_ledger
      where tenant_id = v_order.tenant_id
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and source_type = 'shop_order'
        and source_id = p_order_id::text
        and metadata->>'transaction_type' = 'invoice_collection'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'credit',
        p_amount => v_invoice_pay,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_collection',
          'label', 'Invoice Cleared via COD Remittance',
          'order_no', v_order.order_no,
          'invoice_id', v_order.global_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'remittance_ref', v_ref
        )
      );
    end if;
  end if;

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
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
    'merchant_funds_held', v_profit_hold
  );
end;
$$;

create or replace function public.record_dropship_courier_bank_transfer(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_remit jsonb;
  v_net_amount numeric(15,2);
  v_courier_charge numeric(15,2);
  v_collected_cod numeric(15,2);
  v_remittance_ref text;
  v_bank_trx_id text;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then
    raise exception 'order not found';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement is required before recording courier bank transfer';
  end if;

  if v_settlement.remittance_at is not null then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Courier bank transfer already recorded',
      'order_id', p_order_id
    );
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'bank transfer requires delivered or payment_received status (current: %)', v_order.status;
  end if;

  v_remittance_ref := nullif(trim(coalesce(p_payload->>'remittance_ref', '')), '');
  v_bank_trx_id := nullif(trim(coalesce(p_payload->>'bank_trx_id', '')), '');

  if v_remittance_ref is null then
    raise exception 'remittance_ref is required';
  end if;

  v_collected_cod := coalesce(
    v_settlement.collected_cod_amount,
    v_order.cod_collect_amount,
    0
  );

  v_net_amount := coalesce((p_payload->>'net_amount')::numeric, 0);

  if v_net_amount <= 0 then
    raise exception 'net_amount must be positive';
  end if;

  if v_collected_cod > 0 and v_net_amount > (v_collected_cod + 0.01) then
    raise exception 'Net remittance (%) exceeds collected COD (%)', v_net_amount, v_collected_cod;
  end if;

  v_courier_charge := greatest(v_collected_cod - v_net_amount, 0);

  v_remit := public.record_dropship_courier_remittance(
    p_order_id,
    v_net_amount,
    v_remittance_ref,
    v_bank_trx_id,
    null,
    'bank_transfer',
    null,
    v_courier_charge
  );

  if coalesce(v_remit->>'success', 'false') <> 'true' then
    return v_remit;
  end if;

  update public.dropship_order_settlements
  set remittance_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  update public.shop_orders
  set
    courier_remittance_ref = coalesce(v_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(v_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Courier bank transfer recorded',
    'order_id', p_order_id,
    'net_amount', v_net_amount,
    'courier_charge', v_courier_charge,
    'collected_cod', v_collected_cod,
    'remittance', v_remit
  );
end;
$$;

-- Patch step_state: allow bank transfer when payment_received but remittance_at is still null.
create or replace function public.get_dropship_management_order(
  p_tenant_id bigint,
  p_order_id bigint
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if v_order.status not in ('shipped', 'delivered', 'payment_received') then
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
    and o.tenant_id = p_tenant_id;

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
    from public.global_invoices i
    where i.id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'order', (v_detail->'order') || jsonb_build_object(
      'courier_name', v_courier_name,
      'payout_settlement_status', v_order.payout_settlement_status
    ),
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
      'merchant_payout_at', v_settlement.merchant_payout_at
    ),
    'invoice', v_invoice,
    'step_state', jsonb_build_object(
      'can_mark_delivered',
        v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_issue_invoice',
        v_order.status in ('delivered', 'payment_received')
        and v_order.global_invoice_id is null,
      'can_record_bank_transfer',
        v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.remittance_at is null),
      'can_transfer_to_reseller',
        v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.status is distinct from 'confirmed')
        and (not v_has_settlement or v_settlement.merchant_payout_at is null)
    )
  );
end;
$$;

grant execute on function public.record_dropship_courier_remittance(
  bigint, numeric, text, text, date, text, text, numeric
) to authenticated;
grant execute on function public.record_dropship_courier_bank_transfer(bigint, bigint, jsonb) to authenticated;
grant execute on function public.get_dropship_management_order(bigint, bigint) to authenticated;

commit;
