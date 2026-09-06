-- Dropship B2B invoice: bill only merchant-paid settlement charges.
-- Aligns invoice total with remittance merchant_funds_held vs reseller_profit.

begin;

-- ---------------------------------------------------------------------------
-- 1. get_dropship_merchant_billable_charges
-- ---------------------------------------------------------------------------
create or replace function public.get_dropship_merchant_billable_charges(p_order_id bigint)
returns table (
  delivery numeric,
  print numeric,
  packing numeric,
  cod numeric
)
language plpgsql
stable
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_settlement_id bigint;
  v_lines jsonb;
  v_line jsonb;
  v_delivery numeric := 0;
  v_print numeric := 0;
  v_packing numeric := 0;
  v_cod numeric := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    delivery := 0;
    print := 0;
    packing := 0;
    cod := 0;
    return next;
    return;
  end if;

  select s.id into v_settlement_id
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if v_settlement_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'charge_type', cl.charge_type,
          'amount', cl.amount,
          'payer', cl.payer
        )
      ),
      '[]'::jsonb
    )
    into v_lines
    from public.dropship_settlement_charge_lines cl
    where cl.settlement_id = v_settlement_id
      and cl.charge_type in ('delivery', 'print', 'packing', 'cod');
  else
    v_lines := public.build_default_dropship_settlement_charge_lines(v_order);
  end if;

  for v_line in
    select value from jsonb_array_elements(coalesce(v_lines, '[]'::jsonb))
  loop
    if coalesce(v_line->>'payer', '') = 'merchant' then
      case v_line->>'charge_type'
        when 'delivery' then
          v_delivery := coalesce((v_line->>'amount')::numeric, 0);
        when 'print' then
          v_print := coalesce((v_line->>'amount')::numeric, 0);
        when 'packing' then
          v_packing := coalesce((v_line->>'amount')::numeric, 0);
        when 'cod' then
          v_cod := coalesce((v_line->>'amount')::numeric, 0);
        else
          null;
      end case;
    end if;
  end loop;

  delivery := v_delivery;
  print := v_print;
  packing := v_packing;
  cod := v_cod;
  return next;
end;
$$;

grant execute on function public.get_dropship_merchant_billable_charges(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. build_dropship_tenant_b2b_invoice_payload — payer-aware header charges
-- ---------------------------------------------------------------------------
create or replace function public.build_dropship_tenant_b2b_invoice_payload(
  p_order_id bigint,
  p_invoice_id bigint default null,
  p_invoice_no text default null,
  p_billing_profile_id bigint default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_billing_profile_id bigint;
  v_invoice_no text;
  v_item record;
  v_items jsonb := '[]'::jsonb;
  v_item_json jsonb;
  v_item_sell_price numeric(12,2);
  v_unit_cost numeric(12,2);
  v_line_id bigint;
  v_collection_source public.collection_source_type;
  v_charges record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    return jsonb_build_object(
      'success', false,
      'error', format('tenant B2B invoice requires delivered status (current: %s)', v_order.status)
    );
  end if;

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and customer_group_id = v_order.customer_group_id
    order by created_at asc
    limit 1;
  end if;

  if v_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required for creating invoice');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_collection_source := case
    when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
    else 'recipient'::public.collection_source_type
  end;

  select * into v_charges
  from public.get_dropship_merchant_billable_charges(p_order_id);

  for v_item in (
    select
      soi.*,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) loop
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);
    v_unit_cost := coalesce(v_item.stock_cost, 0);
    v_line_id := null;

    if p_invoice_id is not null then
      select sii.id into v_line_id
      from public.sales_invoice_items sii
      where sii.invoice_id = p_invoice_id
        and (
          (sii.global_stock_id is not null and sii.global_stock_id = v_item.global_stock_id)
          or (sii.global_stock_id is null and sii.product_id = v_item.product_id)
        )
      order by sii.id
      limit 1;
    end if;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'id', v_line_id,
      'global_stock_id', v_item.global_stock_id,
      'product_id', v_item.product_id,
      'shipment_item_id', v_item.stock_shipment_item_id,
      'name_snapshot', coalesce(v_item.stock_name, v_item.name),
      'barcode_snapshot', v_item.stock_barcode,
      'product_code_snapshot', v_item.stock_product_code,
      'quantity', v_item.quantity,
      'unit_cost_price', v_unit_cost,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_item.stock_assigned_child
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  return jsonb_build_object(
    'success', true,
    'payload', jsonb_build_object(
      'invoice', jsonb_strip_nulls(jsonb_build_object(
        'invoice_type', 'dropship',
        'invoice_no', v_invoice_no,
        'billing_profile_id', v_billing_profile_id,
        'recipient_profile_id', v_order.recipient_profile_id,
        'recipient_name', coalesce(v_order.recipient_name, v_order.name),
        'recipient_phone', v_order.recipient_phone,
        'recipient_address', v_order.shipping_address,
        'note', coalesce(p_note, 'B2B Wholesale invoice created from dropship order #' || v_order.order_no),
        'discount_amount', coalesce(v_order.discount_amount, 0),
        'shipping_charge', coalesce(v_charges.delivery, 0),
        'cod_charge_amount', coalesce(v_charges.cod, 0),
        'print_charge', coalesce(v_charges.print, 0),
        'wrapping_charge', coalesce(v_charges.packing, 0),
        'collection_source', v_collection_source
      )),
      'items', v_items
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. transfer_dropship_reseller_profit — guard payout vs merchant_funds_held
-- ---------------------------------------------------------------------------
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
  v_payout jsonb;
  v_billing_profile_id bigint;
  v_amount numeric(15,2);
  v_parent_tenant_id bigint;
  v_merchant_funds_held numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id for update;

  if not found then raise exception 'order not found'; end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement draft is required before reseller payout';
  end if;

  if v_order.status = 'reseller_paid'::public.shop_order_status
     or v_settlement.merchant_payout_at is not null
     or v_settlement.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already transferred',
      'order_id', p_order_id,
      'status', coalesce(v_order.status::text, 'reseller_paid')
    );
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'reseller payout requires delivered or payment_received (current: %)', v_order.status;
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
    raise exception 'billing profile is required for reseller payout';
  end if;

  v_amount := coalesce(v_settlement.reseller_profit, 0);
  if v_amount <= 0 then
    raise exception 'reseller profit must be positive';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  select (u.metadata->>'merchant_funds_held')::numeric
  into v_merchant_funds_held
  from public.universal_wallet_ledger u
  where u.parent_tenant_id = v_parent_tenant_id
    and u.entity_type = 'tenant'
    and u.source_type = 'shop_order'
    and u.source_id = p_order_id::text
    and u.metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  if v_merchant_funds_held is not null
     and v_amount > v_merchant_funds_held + 0.01 then
    raise exception
      'Payout amount % exceeds merchant funds held % from courier remittance for order %. Re-save settlement or fix B2B invoice (recipient-paid charges must not be on invoice).',
      v_amount,
      v_merchant_funds_held,
      v_order.order_no;
  end if;

  v_payout := public.dispense_middleman_payout_from_tenant(
    p_tenant_id,
    v_billing_profile_id,
    v_amount,
    coalesce(nullif(trim(p_payload->>'payout_method'), ''), 'bank_transfer'),
    coalesce(nullif(trim(p_payload->>'reference_notes'), ''), 'Dropship management desk payout for order #' || v_order.order_no)
  );

  if coalesce(v_payout->>'success', 'false') <> 'true' then
    return v_payout;
  end if;

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
    'message', 'Reseller profit transferred',
    'order_id', p_order_id,
    'amount', v_amount,
    'status', 'reseller_paid',
    'payout', v_payout
  );
end;
$$;

grant execute on function public.build_dropship_tenant_b2b_invoice_payload(bigint, bigint, text, bigint, text) to authenticated;
grant execute on function public.transfer_dropship_reseller_profit(bigint, bigint, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. sync_dropship_tenant_b2b_invoice_from_order — payer-aware + paid guard
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
  v_charges record;
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

  if v_invoice.payment_status in ('paid', 'partially_paid') then
    raise exception
      'Cannot sync dropship B2B invoice after payment (invoice %). Use scripts/sql/backfill_dropship_invoice_charge_payer_mismatch.sql',
      v_invoice.id;
  end if;

  select * into v_charges
  from public.get_dropship_merchant_billable_charges(p_order_id);

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
    shipping_charge = coalesce(v_charges.delivery, 0),
    print_charge = coalesce(v_charges.print, 0),
    wrapping_charge = coalesce(v_charges.packing, 0),
    cod_charge_amount = coalesce(v_charges.cod, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = case
      when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end,
    updated_at = now()
  where id = v_invoice.id;

  update public.global_invoices
  set
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

grant execute on function public.sync_dropship_tenant_b2b_invoice_from_order(bigint) to authenticated;

commit;
