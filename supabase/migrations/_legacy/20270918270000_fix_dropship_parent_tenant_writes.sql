-- Parent desk staff: dropship write RPCs must match get_dropship_order_detail_v2 access
-- (tenant_id OR parent_tenant_id), not strict tenant_id = p_tenant_id only.

-- Backfill parent_tenant_id on legacy rows where the trigger did not run.
update public.shop_orders o
set parent_tenant_id = t.parent_id
from public.tenants t
where o.tenant_id = t.id
  and o.parent_tenant_id is null
  and t.parent_id is not null;


create or replace function public.save_dropship_settlement_draft(
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
      billing_profile_id,
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
      v_order.billing_profile_id,
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
      billing_profile_id = coalesce(v_order.billing_profile_id, billing_profile_id),
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


-- transfer_dropship_reseller_profit: parent-aware order lock
create or replace function public.transfer_dropship_reseller_profit(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_save jsonb;
  v_billing_profile_id bigint;
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

  v_billing_profile_id := coalesce(v_order.billing_profile_id, v_settlement.billing_profile_id);
  if v_billing_profile_id is null then
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
    from public.universal_wallet_ledger u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = v_billing_profile_id
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
    p_entity_id => v_billing_profile_id,
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
    'billing_profile_id', v_billing_profile_id
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
  v_profit jsonb;
  v_net_amount numeric(15,2);
  v_courier_charge numeric(15,2);
  v_collected_cod numeric(15,2);
  v_remittance_ref text;
  v_bank_trx_id text;
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
    raise exception 'settlement is required before recording courier bank transfer';
  end if;

  if v_settlement.remittance_at is not null then
    v_profit := public.transfer_dropship_reseller_profit(p_tenant_id, p_order_id, '{}'::jsonb);
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Courier bank transfer already recorded',
      'order_id', p_order_id,
      'reseller_profit', v_profit
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

  v_profit := public.transfer_dropship_reseller_profit(p_tenant_id, p_order_id, '{}'::jsonb);

  if coalesce(v_profit->>'success', 'false') <> 'true'
     and coalesce(v_profit->>'skipped', 'false') <> 'true'
     and coalesce(v_profit->>'already_recorded', 'false') <> 'true' then
    return v_profit;
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Courier bank transfer recorded; invoice paid and merchant profit credited',
    'order_id', p_order_id,
    'net_amount', v_net_amount,
    'courier_charge', v_courier_charge,
    'collected_cod', v_collected_cod,
    'remittance', v_remit,
    'reseller_profit', v_profit
  );
end;
$$;


create or replace function public.mark_dropship_order_returned_from_settlement(
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
  v_save jsonb;
  v_finalize jsonb;
  v_return_items jsonb;
  v_return_fee numeric(15,2) := 0;
  v_line jsonb;
  v_deduct boolean := false;
  v_return_ref text;
  v_reason text;
  v_has_return_qty boolean := false;
  v_elem jsonb;
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

  if v_order.status <> 'shipped'::public.shop_order_status then
    raise exception 'mark as returned requires shipped status (current: %)', v_order.status;
  end if;

  v_return_items := coalesce(p_payload->'return_items', '[]'::jsonb);
  if jsonb_typeof(v_return_items) <> 'array' then
    raise exception 'return_items must be a JSON array';
  end if;

  for v_elem in select * from jsonb_array_elements(v_return_items) loop
    if coalesce((v_elem->>'returned_qty')::numeric, 0) > 0 then
      v_has_return_qty := true;
      exit;
    end if;
  end loop;

  if not v_has_return_qty then
    raise exception 'at least one return line with quantity > 0 is required';
  end if;

  v_deduct := coalesce((p_payload->>'deduct_from_middle_man')::boolean, false);
  v_return_ref := nullif(trim(coalesce(p_payload->>'return_ref', '')), '');
  if v_return_ref is null then
    v_return_ref := 'RET-' || p_order_id::text || '-' || extract(epoch from now())::bigint::text;
  end if;
  v_reason := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  for v_line in select * from jsonb_array_elements(coalesce(p_payload->'charge_lines', '[]'::jsonb)) loop
    if v_line->>'charge_type' = 'return' then
      v_return_fee := coalesce((v_line->>'amount')::numeric, 0);
      exit;
    end if;
  end loop;

  v_finalize := public.finalize_dropship_return(
    p_order_id => p_order_id,
    p_items => v_return_items,
    p_actual_return_charge => v_return_fee,
    p_deduct_from_middle_man => v_deduct,
    p_override_reason => v_reason,
    p_return_ref => v_return_ref
  );

  if coalesce(v_finalize->>'success', 'false') <> 'true' then
    return v_finalize;
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as returned',
    'order_id', p_order_id,
    'status', 'returned',
    'return_ref', v_return_ref
  );
end;
$$;


create or replace function public.ship_dropship_order_and_issue_merchant_bill(
  p_tenant_id bigint,
  p_order_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_issue jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'tenant mismatch');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status <> 'ready_for_pickup'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('ship requires ready_for_pickup (current: %s)', v_order.status)
    );
  end if;

  if v_order.billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required before ship');
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required before ship');
  end if;

  if nullif(trim(coalesce(v_order.sender_name, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_phone, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_address, '')), '') is null then
    return jsonb_build_object('success', false, 'error', 'pickup location name, phone, and address are required before ship');
  end if;

  if exists (
    select 1
    from public.shop_order_items soi
    where soi.order_id = p_order_id
      and soi.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
      and coalesce(soi.confirmed_quantity, 0) <= 0
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  ) then
    return jsonb_build_object('success', false, 'error', 'every line must be picked or marked unavailable before ship');
  end if;

  v_issue := public.issue_dropship_tenant_b2b_invoice(p_tenant_id, p_order_id);
  if coalesce(v_issue->>'success', 'false') <> 'true' then
    return v_issue;
  end if;

  update public.shop_orders
  set
    status = 'shipped'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'shipped',
    'invoice', v_issue->'invoice',
    'created', coalesce(v_issue->>'created', 'false')::boolean,
    'already_issued', coalesce(v_issue->>'already_issued', 'false')::boolean
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;


create or replace function public.mark_dropship_order_delivered(
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
  v_invoice public.global_invoices;
  v_save jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.status <> 'shipped'::public.shop_order_status then
    raise exception 'mark as delivered requires shipped status (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'merchant bill must be issued before deliver';
  end if;

  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
  if v_invoice.id is null then
    raise exception 'linked merchant bill not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'merchant bill must be issued before deliver (current: %)', v_invoice.invoice_status;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    delivered_at = coalesce(delivered_at, now()),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id,
    'invoice_id', v_order.global_invoice_id
  );
end;
$$;
