-- Dropship desk: tenant B2B invoice at delivered only (DROPSHIP_MANAGEMENT.md §7 step ①, §10)
-- invoice_status = issued, payment_status = due until step ② remittance

begin;

-- ---------------------------------------------------------------------------
-- 1. Sync existing tenant B2B invoice totals from shop_orders + items
-- ---------------------------------------------------------------------------
create or replace function public.sync_dropship_tenant_b2b_invoice_from_order(
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
    updated_at = now()
  where id = v_invoice.id;

  perform public.recompute_global_invoice_totals(v_invoice.id);
  perform public.recompute_global_invoice_payment_status(v_invoice.id);

  select * into v_invoice from public.global_invoices where id = v_invoice.id;

  if v_invoice.invoice_status in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    perform public.post_global_invoice(v_invoice.id);
    select * into v_invoice from public.global_invoices where id = v_invoice.id;
  end if;

  if v_invoice.invoice_status not in (
    'issued'::public.global_invoice_status,
    'voided'::public.global_invoice_status
  ) then
    update public.global_invoices
    set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
    where id = v_invoice.id;

    select * into v_invoice from public.global_invoices where id = v_invoice.id;
  end if;

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

-- ---------------------------------------------------------------------------
-- 2. Create or refresh tenant B2B invoice at delivered (issued + due)
-- ---------------------------------------------------------------------------
create or replace function public.ensure_dropship_tenant_b2b_invoice_at_delivered(
  p_order_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_result jsonb;
  v_invoice public.global_invoices;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  if v_order.status not in ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Tenant B2B invoice requires delivered status (current: %)',
        v_order.status
      )
    );
  end if;

  if v_order.global_invoice_id is null then
    v_result := public.create_dual_invoice_from_dropship_order(p_order_id);
  else
    v_result := public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id);
    if coalesce(v_result->>'success', 'false') = 'true' then
      perform public.ensure_dropship_invoice_billed_entry(v_order.global_invoice_id);
    end if;
  end if;

  if coalesce(v_result->>'success', 'false') <> 'true' then
    return v_result;
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'total_amount', v_invoice.total_amount,
    'due_amount', v_invoice.due_amount
  );
end;
$$;

grant execute on function public.ensure_dropship_tenant_b2b_invoice_at_delivered(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. create_dual_invoice_from_dropship_order — delivered+ only, explicit due
-- ---------------------------------------------------------------------------
create or replace function public.create_dual_invoice_from_dropship_order(
  p_order_id bigint,
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
  v_order record;
  v_billing_profile_id bigint;
  v_profile record;
  v_parent_tenant_id bigint;
  v_invoice_no text;
  v_invoice public.global_invoices;
  v_item record;
  v_subtotal numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_assigned_child bigint;
  v_total numeric(12,2);
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'Tenant B2B invoice can only be created at delivered (current status: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is not null then
    raise exception 'Invoice already created for this order (invoice_id: %)', v_order.global_invoice_id;
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
    raise exception 'Billing profile is required for creating invoice';
  end if;

  select * into v_profile from public.billing_profiles where id = v_billing_profile_id;
  if v_profile.id is null then
    raise exception 'Billing profile not found';
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => 'dropship'::public.global_invoice_type,
    p_billing_profile_id => v_billing_profile_id,
    p_recipient_profile_id => v_order.recipient_profile_id,
    p_recipient_name => coalesce(v_order.recipient_name, v_order.name),
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_note => coalesce(p_note, 'B2B Wholesale invoice created from dropship order #' || v_order.order_no)
  );

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
    v_item_line_total := v_item.quantity * v_item_sell_price;
    v_assigned_child := v_item.stock_assigned_child;

    insert into public.global_invoice_items (
      tenant_id,
      parent_tenant_id,
      invoice_id,
      global_stock_id,
      shipment_item_id,
      product_id,
      name_snapshot,
      barcode_snapshot,
      product_code_snapshot,
      quantity,
      unit_cost_price,
      sell_price_amount,
      line_discount_amount,
      line_total_amount,
      assigned_child_tenant_id
    )
    values (
      v_invoice.tenant_id,
      v_invoice.parent_tenant_id,
      v_invoice.id,
      v_item.global_stock_id,
      v_item.stock_shipment_item_id,
      v_item.product_id,
      coalesce(v_item.stock_name, v_item.name),
      v_item.stock_barcode,
      v_item.stock_product_code,
      v_item.quantity,
      coalesce(v_item.stock_cost, 0),
      v_item_sell_price,
      0,
      v_item_line_total,
      v_assigned_child
    );

    v_subtotal := v_subtotal + v_item_line_total;
  end loop;

  v_charges_total := coalesce(v_order.print_charge_amount, 0) + coalesce(v_order.packing_charge_amount, 0);
  v_total := greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    shipping_charge = 0,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    total_amount = v_total,
    paid_amount = 0,
    due_amount = v_total,
    payment_status = 'due',
    collection_source = case
      when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end,
    invoice_status = 'issued'::public.global_invoice_status,
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders
  set
    global_invoice_id = v_invoice.id,
    updated_at = now()
  where id = v_order.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'invoice_status', 'issued',
    'payment_status', 'due',
    'subtotal_amount', v_subtotal,
    'total_amount', v_total
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. advance_dropship_order_status — status only; no early B2B invoice
-- ---------------------------------------------------------------------------
create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  end if;

  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed')
     and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in (
      'processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled'
    ) then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Invalid status transition for dropship order from %s to %s',
        v_current_status,
        p_target_status
      )
    );
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.universal_wallet_ledger
    where source_type = 'shop_order'
      and (source_id = p_order_id::text or source_id = v_order.order_no)
      and tenant_id = v_order.tenant_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoices where id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. mark_dropship_order_delivered — explicit tenant B2B invoice at step ①
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
  v_invoice jsonb;
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

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  v_advance := public.advance_dropship_order_status(p_order_id, 'delivered'::public.shop_order_status);
  if coalesce(v_advance->>'success', 'false') <> 'true' then
    return v_advance;
  end if;

  v_invoice := public.ensure_dropship_tenant_b2b_invoice_at_delivered(p_order_id);
  if coalesce(v_invoice->>'success', 'false') <> 'true' then
    return v_invoice;
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
    'order_id', p_order_id,
    'invoice', v_invoice
  );
end;
$$;

grant execute on function public.mark_dropship_order_delivered(bigint, bigint, jsonb) to authenticated;

-- Remove stale posted enum reference from invoice_billed helper
create or replace function public.ensure_dropship_invoice_billed_entry(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_order_id bigint;
begin
  select * into v_invoice
  from public.global_invoices
  where id = p_invoice_id;

  if v_invoice.id is null then
    return;
  end if;

  select o.id into v_order_id
  from public.shop_orders o
  where o.global_invoice_id = p_invoice_id
  order by o.id
  limit 1;

  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
     and v_invoice.invoice_status = 'issued'::public.global_invoice_status
     and v_invoice.billing_profile_id is not null
     and v_invoice.total_amount > 0
     and v_order_id is not null
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
          or source_id = v_invoice.invoice_no
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

commit;
