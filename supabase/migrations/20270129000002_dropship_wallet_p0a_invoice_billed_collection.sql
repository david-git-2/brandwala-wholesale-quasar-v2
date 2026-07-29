-- Migration: Dropship Wallet P0A — Invoice billed debit & collection_source fix
-- Goal: Fix collection_source logic in auto-invoicing and ensure idempotent invoice_billed ledger entry.

begin;

-- ============================================================================
-- 1. Helper function: ensure_dropship_invoice_billed_entry
-- ============================================================================
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
begin
  select * into v_invoice
  from public.global_invoices
  where id = p_invoice_id;

  if v_invoice.id is null then
    return;
  end if;

  -- Only applies to posted dropship invoices with a valid billing profile and total > 0
  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
     and v_invoice.invoice_status = 'posted'::public.global_invoice_status
     and v_invoice.billing_profile_id is not null
     and v_invoice.total_amount > 0
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
        and (metadata->>'invoice_id' = p_invoice_id::text or source_id = v_invoice.invoice_no)
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_invoice.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_source_type => 'shop_order',
        p_source_id => v_invoice.invoice_no,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', p_invoice_id
        )
      );
    end if;
  end if;
end;
$$;

grant execute on function public.ensure_dropship_invoice_billed_entry(bigint) to authenticated;
grant execute on function public.ensure_dropship_invoice_billed_entry(bigint) to service_role;


-- ============================================================================
-- 2. Update create_dual_invoice_from_dropship_order (fix collection_source)
-- ============================================================================
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
  v_invoice record;
  v_item record;
  v_subtotal numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    raise exception 'Invoice can only be created for orders ready for pickup or later (current status: %)', v_order.status;
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

  -- Create B2B dropship invoice; collection_source per is_prepaid_snapshot
  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    invoice_no,
    invoice_type,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    note,
    due_amount,
    invoice_status
  )
  values (
    v_order.tenant_id,
    v_parent_tenant_id,
    v_invoice_no,
    'dropship',
    v_billing_profile_id,
    v_order.recipient_profile_id,
    coalesce(v_order.recipient_name, v_order.name),
    v_order.recipient_phone,
    v_order.shipping_address,
    case when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type else 'recipient'::public.collection_source_type end,
    coalesce(p_note, 'B2B Wholesale invoice created from dropship order #' || v_order.order_no),
    0,
    'posted'::public.global_invoice_status
  )
  returning * into v_invoice;

  for v_item in (
    select
      soi.*,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where soi.order_id = v_order.id
  ) loop
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);
    v_item_line_total := v_item.quantity * v_item_sell_price;

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
      line_total_amount
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
      v_item_line_total
    );

    v_subtotal := v_subtotal + v_item_line_total;

    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  -- B2B Invoice charges: packing and print charges only (exclude delivery and COD)
  v_charges_total := coalesce(v_order.print_charge_amount, 0) + coalesce(v_order.packing_charge_amount, 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    shipping_charge = 0,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    total_amount = greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0),
    due_amount = greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0),
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders
  set
    global_invoice_id = v_invoice.id,
    updated_at = now()
  where id = v_order.id;

  -- Ensure invoice_billed debit entry is created
  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'subtotal_amount', v_subtotal,
    'total_amount', v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0)
  );
end;
$$;

grant execute on function public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text) to authenticated;


-- ============================================================================
-- 3. Update post_global_invoice (call helper)
-- ============================================================================
create or replace function public.post_global_invoice(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft invoices can be posted';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  -- Validate required fields per invoice type
  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if v_invoice.cod_charge > 0 or v_invoice.wrapping_charge > 0 or v_invoice.print_charge > 0 then
      raise exception 'wholesale invoices only support shipping charges';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  -- Snapshot unit costs on line items
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  -- Mark invoice as posted
  update public.global_invoices
  set invoice_status = 'posted'::public.global_invoice_status
  where id = p_invoice_id;

  -- Ensure invoice_billed debit entry is created
  perform public.ensure_dropship_invoice_billed_entry(p_invoice_id);
end;
$$;

grant execute on function public.post_global_invoice(bigint) to authenticated;


-- ============================================================================
-- 4. Update advance_dropship_order_status (call helper)
-- ============================================================================
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
  v_billing_profile_id bigint;
  v_profit numeric(12,2) := 0.00;

  v_recipient_subtotal numeric(12,2) := 0;
  v_accounting_subtotal numeric(12,2) := 0;
  v_middleman_cost numeric(12,2) := 0;
  v_tenant_revenue numeric(12,2) := 0;
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

  -- Status transition rules
  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed') and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled') then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format('Invalid status transition for dropship order from %s to %s', v_current_status, p_target_status)
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

  if p_target_status in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    if v_order.global_invoice_id is null then
      perform public.create_dual_invoice_from_dropship_order(p_order_id);
    else
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
        perform public.post_global_invoice(v_order.global_invoice_id);
      end if;
    end if;

    -- Ensure invoice_billed UWL debit entry is created/confirmed
    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      perform public.ensure_dropship_invoice_billed_entry(v_order.global_invoice_id);
    end if;

    -- Resolve billing profile
    v_billing_profile_id := v_order.billing_profile_id;
    if v_billing_profile_id is null and v_order.customer_group_id is not null then
      select id into v_billing_profile_id
      from public.billing_profiles
      where tenant_id = v_order.tenant_id
        and customer_group_id = v_order.customer_group_id
      order by created_at asc
      limit 1;
    end if;

    -- Refresh order + invoice after invoice creation
    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    end if;

    -- Calculate profit using dynamic item query
    select
      coalesce(sum(coalesce(customer_sell_price_amount, 0) * quantity), 0),
      coalesce(sum(coalesce(unit_sell_price_amount, unit_list_price_amount, 0) * quantity), 0)
    into v_recipient_subtotal, v_accounting_subtotal
    from public.shop_order_items
    where order_id = p_order_id;

    v_middleman_cost := v_accounting_subtotal
      + coalesce(v_order.print_charge_amount, 0)
      + coalesce(v_order.packing_charge_amount, 0)
      + case when coalesce(v_order.deduct_delivery_from_margin, false) then coalesce(v_order.delivery_charge_amount, 0) else 0 end
      + case when coalesce(v_order.deduct_cod_from_margin, false) then coalesce(v_order.cod_charge_amount, 0) else 0 end;

    v_profit := v_recipient_subtotal - coalesce(v_order.discount_amount, 0) - v_middleman_cost;

    -- Tenant net revenue = total invoiced minus reseller profit payout
    v_tenant_revenue := coalesce(v_invoice.total_amount, 0) - greatest(v_profit, 0);

    -- Universal wallet: reseller dropship_profit credit
    if v_billing_profile_id is not null and v_profit > 0 then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order'
          and source_id = v_order.order_no
          and entity_type = 'customer'
          and entity_id = v_billing_profile_id
          and metadata->>'transaction_type' = 'dropship_profit'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_billing_profile_id,
          p_type => 'credit',
          p_amount => v_profit,
          p_source_type => 'shop_order',
          p_source_id => v_order.order_no,
          p_metadata => jsonb_build_object(
            'section', 'payout_earned',
            'transaction_type', 'dropship_profit',
            'label', 'Profit Earned',
            'order_no', v_order.order_no,
            'invoice_id', v_order.global_invoice_id
          )
        );
      end if;
    end if;

    -- Universal wallet: tenant revenue credit
    if v_tenant_revenue > 0 then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order'
          and source_id = v_order.order_no
          and entity_type = 'tenant'
          and entity_id = v_order.tenant_id
          and metadata->>'transaction_type' = 'revenue'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'tenant',
          p_entity_id => v_order.tenant_id,
          p_type => 'credit',
          p_amount => v_tenant_revenue,
          p_source_type => 'shop_order',
          p_source_id => v_order.order_no,
          p_metadata => jsonb_build_object(
            'section', 'revenue',
            'transaction_type', 'revenue',
            'label', 'Revenue',
            'order_no', v_order.order_no,
            'invoice_id', v_order.global_invoice_id
          )
        );
      end if;
    end if;

  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      -- Remove universal_wallet_ledger entries for this order on rollback
      delete from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and source_id = v_order.order_no
        and tenant_id = v_order.tenant_id;

      -- Disconnect from order
      update public.shop_orders
      set global_invoice_id = null
      where id = p_order_id;

      -- Hard delete draft invoice and lines
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

grant execute on function public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) to authenticated;

commit;
