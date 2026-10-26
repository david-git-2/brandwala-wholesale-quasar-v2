-- Dedicated dropship B2B invoice RPC + wallet source_id canonicalize.
-- mark_dropship_order_delivered no longer creates invoices.

begin;

-- ---------------------------------------------------------------------------
-- 1. Backfill legacy INV-DS-* / invoice_no wallet source_ids
-- ---------------------------------------------------------------------------
update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb)
    || jsonb_build_object('order_id', o.id, 'invoice_no', u.source_id)
from public.shop_orders o
where u.source_type = 'shop_order'
  and u.source_id = 'INV-DS-' || o.order_no
  and o.shop_type_snapshot = 'dropship';

update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb)
    || jsonb_build_object('order_id', o.id, 'invoice_id', i.id, 'invoice_no', i.invoice_no)
from public.shop_orders o
join public.global_invoices i on i.id = o.global_invoice_id
where u.source_type = 'shop_order'
  and u.source_id = i.invoice_no
  and o.shop_type_snapshot = 'dropship';

update public.universal_wallet_ledger u
set
  source_id = o.id::text,
  metadata = coalesce(u.metadata, '{}'::jsonb) || jsonb_build_object('order_id', o.id)
from public.shop_orders o
join public.global_invoices i
  on i.invoice_no = 'INV-DS-' || o.order_no
 and i.tenant_id = o.tenant_id
where u.source_type = 'shop_order'
  and u.source_id = i.invoice_no
  and o.shop_type_snapshot = 'dropship'
  and i.invoice_type = 'dropship'::public.global_invoice_type;

-- ---------------------------------------------------------------------------
-- 2. Canonicalize helper
-- ---------------------------------------------------------------------------
create or replace function public.canonicalize_dropship_order_wallet_source_ids(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice_no text;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null or v_order.shop_type_snapshot <> 'dropship' then
    return;
  end if;

  v_invoice_no := 'INV-DS-' || v_order.order_no;

  update public.universal_wallet_ledger u
  set
    source_id = p_order_id::text,
    metadata = coalesce(u.metadata, '{}'::jsonb)
      || jsonb_build_object('order_id', p_order_id, 'invoice_no', v_invoice_no)
  where u.source_type = 'shop_order'
    and u.tenant_id = v_order.tenant_id
    and u.source_id in (v_invoice_no, v_order.order_no);

  if v_order.global_invoice_id is not null then
    update public.universal_wallet_ledger u
    set
      source_id = p_order_id::text,
      metadata = coalesce(u.metadata, '{}'::jsonb)
        || jsonb_build_object('order_id', p_order_id, 'invoice_id', v_order.global_invoice_id)
    from public.global_invoices i
    where i.id = v_order.global_invoice_id
      and u.source_type = 'shop_order'
      and u.tenant_id = v_order.tenant_id
      and u.source_id = i.invoice_no;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. invoice_billed wallet row uses order id only
-- ---------------------------------------------------------------------------
create or replace function public.ensure_dropship_invoice_billed_entry(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_order_id bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then
    return;
  end if;

  select o.id into v_order_id
  from public.shop_orders o
  where o.global_invoice_id = p_invoice_id
  order by o.id
  limit 1;

  if v_order_id is null and v_invoice.invoice_no like 'INV-DS-%' then
    select o.id into v_order_id
    from public.shop_orders o
    where o.tenant_id = v_invoice.tenant_id
      and o.shop_type_snapshot = 'dropship'
      and o.order_no = replace(v_invoice.invoice_no, 'INV-DS-', '')
    order by o.id desc
    limit 1;
  end if;

  if v_order_id is null then
    return;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(v_order_id);

  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
     and v_invoice.invoice_status in (
       'issued'::public.global_invoice_status,
       'posted'::public.global_invoice_status
     )
     and v_invoice.billing_profile_id is not null
     and v_invoice.total_amount > 0
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
        and (
          metadata->>'invoice_id' = p_invoice_id::text
          or source_id = v_order_id::text
        )
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_invoice.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_source_type => 'shop_order',
        p_source_id => v_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', p_invoice_id,
          'order_id', v_order_id
        )
      );
    end if;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Sync must not call wholesale post_sales_invoice
-- ---------------------------------------------------------------------------
create or replace function public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_item record;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'No tenant B2B invoice linked to order');
  end if;

  select * into v_invoice
  from public.global_invoices
  where id = v_order.global_invoice_id
  for update;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'Linked invoice not found');
  end if;

  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    return jsonb_build_object('success', false, 'error', 'Linked invoice is not a dropship B2B invoice');
  end if;

  if v_invoice.invoice_status = 'voided'::public.global_invoice_status then
    return jsonb_build_object('success', false, 'error', 'Cannot sync a voided invoice');
  end if;

  for v_item in (
    select
      soi.*,
      gs.shipment_item_id as stock_shipment_item_id
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    where soi.order_id = v_order.id
  ) loop
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);
    v_item_line_total := v_item.quantity * v_item_sell_price;

    update public.global_invoice_items gii
    set
      quantity = v_item.quantity,
      sell_price_amount = v_item_sell_price,
      line_total_amount = v_item_line_total,
      unit_cost_price = coalesce(public.calculate_landed_unit_cost(v_item.stock_shipment_item_id), gii.unit_cost_price),
      updated_at = now()
    where gii.invoice_id = v_invoice.id
      and (
        (gii.global_stock_id is not null and gii.global_stock_id = v_item.global_stock_id)
        or (gii.global_stock_id is null and gii.product_id = v_item.product_id)
      );
  end loop;

  update public.global_invoices
  set
    shipping_charge = 0,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = case
      when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end,
    invoice_status = case
      when invoice_status in (
        'draft'::public.global_invoice_status,
        'proforma_generated'::public.global_invoice_status
      ) then 'issued'::public.global_invoice_status
      else invoice_status
    end,
    updated_at = now()
  where id = v_invoice.id;

  perform public.recompute_global_invoice_totals(v_invoice.id);
  perform public.recompute_global_invoice_payment_status(v_invoice.id);

  select * into v_invoice from public.global_invoices where id = v_invoice.id;

  if v_invoice.payment_status not in ('paid', 'partially_paid') then
    update public.global_invoices
    set
      payment_status = 'due',
      due_amount = greatest(coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0), 0),
      updated_at = now()
    where id = v_invoice.id;

    select * into v_invoice from public.global_invoices where id = v_invoice.id;
  end if;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'total_amount', v_invoice.total_amount,
    'due_amount', v_invoice.due_amount
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. Dedicated desk RPC
-- ---------------------------------------------------------------------------
create or replace function public.issue_dropship_tenant_b2b_invoice(
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
  v_invoice public.global_invoices;
  v_result jsonb;
  v_created boolean := false;
  v_billed boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format('tenant B2B invoice requires delivered status (current: %s)', v_order.status)
    );
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  if v_order.global_invoice_id is not null then
    v_result := public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id);
    if coalesce(v_result->>'success', 'false') <> 'true' then
      return v_result;
    end if;
    perform public.ensure_dropship_invoice_billed_entry(v_order.global_invoice_id);
    v_created := false;
  else
    begin
      v_result := public.create_dual_invoice_from_dropship_order(p_order_id);
    exception
      when others then
        return jsonb_build_object('success', false, 'error', sqlerrm);
    end;
    if coalesce(v_result->>'success', 'false') <> 'true' then
      return coalesce(
        v_result,
        jsonb_build_object('success', false, 'error', 'failed to create invoice')
      );
    end if;
    v_created := true;
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice was not created');
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_billed := exists (
    select 1 from public.universal_wallet_ledger
    where source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  return jsonb_build_object(
    'success', true,
    'created', v_created,
    'order_id', p_order_id,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'invoice_no', v_invoice.invoice_no,
      'invoice_type', v_invoice.invoice_type,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'subtotal_amount', v_invoice.subtotal_amount,
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'discount_amount', v_invoice.discount_amount,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'billing_profile_id', v_invoice.billing_profile_id,
      'collection_source', v_invoice.collection_source
    ),
    'wallet', jsonb_build_object(
      'invoice_billed', v_billed,
      'source_type', 'shop_order',
      'source_id', p_order_id::text
    )
  );
end;
$$;

create or replace function public.ensure_dropship_tenant_b2b_invoice_at_delivered(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Mark delivered: status + courier COD only
-- ---------------------------------------------------------------------------
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
  v_save jsonb;
  v_advance jsonb;
  v_costing jsonb;
  v_delivery_amount numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then raise exception 'order not found'; end if;
  if v_order.status <> 'shipped' then
    raise exception 'mark as delivered requires shipped status (current: %)', v_order.status;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  v_advance := public.advance_dropship_order_status(p_order_id, 'delivered'::public.shop_order_status);
  if coalesce(v_advance->>'success', 'false') <> 'true' then
    return v_advance;
  end if;

  select coalesce(cl.amount, 0) into v_delivery_amount
  from public.dropship_order_settlements s
  join public.dropship_settlement_charge_lines cl
    on cl.settlement_id = s.id and cl.charge_type = 'delivery'
  where s.shop_order_id = p_order_id;

  v_costing := public.confirm_dropship_delivered_costing(
    p_order_id,
    coalesce((p_payload->>'collected_cod_amount')::numeric, 0),
    v_delivery_amount,
    null
  );

  if coalesce(v_costing->>'success', 'false') <> 'true' then
    return v_costing;
  end if;

  update public.dropship_order_settlements
  set courier_cod_booked_at = now(), updated_at = now()
  where shop_order_id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. Load payload: invoice + can_issue_invoice
-- ---------------------------------------------------------------------------
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
        v_order.status = 'delivered'
        and (not v_has_settlement or v_settlement.remittance_at is null),
      'can_transfer_to_reseller',
        v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.status is distinct from 'confirmed')
        and (not v_has_settlement or v_settlement.merchant_payout_at is null)
    )
  );
end;
$$;

grant execute on function public.canonicalize_dropship_order_wallet_source_ids(bigint) to authenticated;
grant execute on function public.issue_dropship_tenant_b2b_invoice(bigint, bigint) to authenticated;
grant execute on function public.ensure_dropship_tenant_b2b_invoice_at_delivered(bigint) to authenticated;
grant execute on function public.mark_dropship_order_delivered(bigint, bigint, jsonb) to authenticated;
grant execute on function public.get_dropship_management_order(bigint, bigint) to authenticated;

commit;
