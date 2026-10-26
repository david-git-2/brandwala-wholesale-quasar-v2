-- Step 2: Refactor Dropship Invoice & Return RPCs to B2B Format
begin;

-- Drop existing functions to prevent parameter name mismatch errors (SQLSTATE 42P13)
drop function if exists public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text);
drop function if exists public.create_dropship_invoice(bigint, text, bigint, text);
drop function if exists public.recompute_global_invoice_totals(bigint);
drop function if exists public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric, numeric);
drop function if exists public.update_global_invoice_item(bigint, numeric, numeric, numeric);
drop function if exists public.create_global_invoice(bigint, text, bigint, public.global_invoice_type, public.global_source_module, text, text, text, bigint, numeric, text);
drop function if exists public.add_global_return_item(bigint, bigint, numeric, numeric, text);
drop function if exists public.advance_dropship_order_status(bigint, public.shop_order_status, text, text);
drop function if exists public.fulfill_shop_order_to_invoice(bigint);
drop function if exists public.apply_global_invoice_target_total(bigint, numeric, boolean);
drop function if exists public.list_global_invoice_items(bigint);

-- ============================================================================
-- 1. create_dual_invoice_from_dropship_order & create_dropship_invoice
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
      and (customer_group_id = v_order.customer_group_id or is_default = true)
    order by is_default desc, created_at asc
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

  -- Create B2B dropship invoice billed strictly to billing_profile
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
    'billing_profile'::public.collection_source_type,
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

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'subtotal_amount', v_subtotal,
    'total_amount', v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0)
  );
end;
$$;

create or replace function public.create_dropship_invoice(
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
begin
  return public.create_dual_invoice_from_dropship_order(p_order_id, p_invoice_no, p_billing_profile_id, p_note);
end;
$$;

grant execute on function public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text) to authenticated;
grant execute on function public.create_dropship_invoice(bigint, text, bigint, text) to authenticated;

-- ============================================================================
-- 2. recompute_global_invoice_totals
-- ============================================================================
create or replace function public.recompute_global_invoice_totals(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_subtotal numeric(12,2) := 0;
  v_charges numeric(12,2) := 0;
  v_charge_lines_sum numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then return; end if;

  select coalesce(sum(line_total_amount), 0)
  into v_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  v_charges := coalesce(v_invoice.shipping_charge, 0) 
             + coalesce(v_invoice.wrapping_charge, 0) 
             + coalesce(v_invoice.print_charge, 0);

  v_discount := coalesce(v_invoice.discount_amount, 0);
  v_paid := coalesce(v_invoice.paid_amount, 0);

  v_total := greatest(v_subtotal + v_charges - v_discount, 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    total_amount = v_total,
    due_amount = greatest(v_total - v_paid, 0),
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

-- ============================================================================
-- 3. add_global_invoice_item & update_global_invoice_item
-- ============================================================================
create or replace function public.add_global_invoice_item(
  p_invoice_id bigint,
  p_global_stock_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_line_discount_amount numeric default 0,
  p_recipient_price_amount numeric default null
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_stock public.global_stocks;
  v_row public.global_invoice_items;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_line_total numeric;
  v_product_id bigint;
  v_unit_cost numeric;
  v_qty_remaining numeric;
  v_avail integer;
  v_take numeric;
  v_existing_qty numeric;
  v_curr_stock_id bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot add items to a non-draft invoice';
  end if;

  select * into v_stock from public.global_stocks where id = p_global_stock_id;
  if v_stock.id is null then raise exception 'stock not found'; end if;
  if v_stock.parent_tenant_id <> v_invoice.parent_tenant_id then
    raise exception 'stock must belong to the same parent tenant group';
  end if;

  select product_id into v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  v_qty_remaining := p_quantity;
  v_curr_stock_id := p_global_stock_id;

  v_avail := public.get_available_stock(v_curr_stock_id, v_invoice.tenant_id);
  select coalesce(sum(quantity), 0) into v_existing_qty
  from public.global_invoice_items
  where invoice_id = p_invoice_id and global_stock_id = v_curr_stock_id;

  v_avail := greatest(v_avail - v_existing_qty, 0);

  if v_avail > 0 then
    v_take := least(v_qty_remaining, v_avail);
    
    select name, barcode, product_code
    into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot
    from public.global_shipment_items
    where id = (select shipment_item_id from public.global_stocks where id = v_curr_stock_id);

    v_line_total := greatest((v_take * p_sell_price_amount) - coalesce(p_line_discount_amount, 0.00), 0.00);
    v_unit_cost := coalesce(public.calculate_landed_unit_cost(
      (select shipment_item_id from public.global_stocks where id = v_curr_stock_id)
    ), 0.00);

    insert into public.global_invoice_items (
      tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity, unit_cost_price,
      sell_price_amount, line_discount_amount, line_total_amount, return_quantity
    )
    values (
      v_invoice.tenant_id, v_invoice.parent_tenant_id, p_invoice_id, v_curr_stock_id,
      (select shipment_item_id from public.global_stocks where id = v_curr_stock_id), v_product_id,
      v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_take, v_unit_cost,
      p_sell_price_amount, coalesce(p_line_discount_amount, 0.00), v_line_total, 0.00
    )
    returning * into v_row;

    v_qty_remaining := v_qty_remaining - v_take;
  end if;

  if v_qty_remaining > 0 then
    raise exception 'insufficient stock: requested %, available %', p_quantity, (p_quantity - v_qty_remaining);
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

create or replace function public.update_global_invoice_item(
  p_item_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_recipient_price_amount numeric default null
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.global_invoice_items;
  v_invoice public.global_invoices;
  v_line_total numeric;
begin
  select * into v_item from public.global_invoice_items where id = p_item_id;
  if v_item.id is null then raise exception 'Invoice item not found'; end if;

  select * into v_invoice from public.global_invoices where id = v_item.invoice_id;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'Cannot edit items on a non-draft invoice';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than 0';
  end if;

  if p_sell_price_amount < 0 then
    raise exception 'Sell price cannot be negative';
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(v_item.line_discount_amount, 0.00), 0.00);

  update public.global_invoice_items
  set
    quantity = p_quantity,
    sell_price_amount = p_sell_price_amount,
    line_total_amount = v_line_total
  where id = p_item_id
  returning * into v_item;

  perform public.recompute_global_invoice_totals(v_item.invoice_id);

  return v_item;
end;
$$;

grant execute on function public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric, numeric) to authenticated;
grant execute on function public.update_global_invoice_item(bigint, numeric, numeric, numeric) to authenticated;

-- ============================================================================
-- 4. create_global_invoice
-- ============================================================================
create or replace function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_billing_profile_id bigint,
  p_invoice_type public.global_invoice_type default 'wholesale',
  p_source_module public.global_source_module default 'wholesale',
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_recipient_party_id bigint default null,
  p_middle_man_payout_amount numeric default null,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_profile public.billing_profiles;
  v_invoice_type public.global_invoice_type;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_collection_source text;
begin
  if p_billing_profile_id is null then
    raise exception 'Billing profile is required.';
  end if;

  v_invoice_type := coalesce(p_invoice_type, 'wholesale');
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'not allowed';
  end if;

  select * into v_profile from public.billing_profiles where id = p_billing_profile_id;
  if v_profile.id is null then raise exception 'Billing profile not found.'; end if;
  if v_profile.tenant_id <> p_tenant_id then
    raise exception 'Billing profile does not belong to issuing tenant.';
  end if;

  if v_invoice_type = 'wholesale' then
    v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_profile.name);
    v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_profile.phone);
    v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_profile.address);
    v_collection_source := 'billing_profile';
  elsif v_invoice_type = 'retail' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for retail.'; end if;
    v_collection_source := 'billing_profile';
  elsif v_invoice_type = 'dropship' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for dropship.'; end if;
    v_collection_source := 'billing_profile';
  else
    raise exception 'Invalid invoice type.';
  end if;

  insert into public.global_invoices (
    tenant_id, parent_tenant_id, invoice_no, invoice_type,
    billing_profile_id,
    recipient_name, recipient_phone, recipient_address,
    collection_source, note, due_amount
  )
  values (
    p_tenant_id, v_parent_id, trim(p_invoice_no), v_invoice_type,
    p_billing_profile_id,
    v_recipient_name, v_recipient_phone, v_recipient_address,
    v_collection_source, nullif(trim(coalesce(p_note, '')), ''), 0
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_global_invoice(
  bigint, text, bigint, public.global_invoice_type, public.global_source_module,
  text, text, text, bigint, numeric, text
) to authenticated;

-- ============================================================================
-- 5. add_global_return_item
-- ============================================================================
create or replace function public.add_global_return_item(
  p_invoice_id bigint,
  p_invoice_item_id bigint,
  p_quantity numeric,
  p_return_charge_amount numeric default 0,
  p_note text default null
)
returns public.global_return_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_unit_price numeric(12,2);
  v_return_amount numeric(12,2);
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  select * into v_item from public.global_invoice_items where id = p_invoice_item_id and invoice_id = p_invoice_id;
  if v_item.id is null then raise exception 'invoice item not found'; end if;
  if p_quantity <= 0 or p_quantity > v_item.quantity then
    raise exception 'invalid return quantity';
  end if;

  v_unit_price := case when v_item.quantity > 0 then v_item.line_total_amount / v_item.quantity else 0 end;
  v_return_amount := round(v_unit_price * p_quantity, 2);

  insert into public.global_return_items (
    tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
    quantity, return_amount, return_charge_amount, note
  )
  values (
    v_invoice.tenant_id, v_invoice.parent_tenant_id, p_invoice_id, p_invoice_item_id, v_item.global_stock_id,
    p_quantity, v_return_amount,
    greatest(coalesce(p_return_charge_amount, 0), 0), nullif(trim(coalesce(p_note, '')), '')
  )
  returning * into v_row;

  update public.global_stock_quantities
  set quantity = quantity + ceil(p_quantity)::integer
  where stock_id = v_item.global_stock_id and status = 'excellent';

  update public.global_invoices
  set
    subtotal_amount = greatest(subtotal_amount - v_return_amount, 0),
    total_amount = greatest(total_amount - v_return_amount - greatest(coalesce(p_return_charge_amount, 0), 0), 0),
    due_amount = greatest(total_amount - paid_amount, 0),
    updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.add_global_return_item(bigint, bigint, numeric, numeric, text) to authenticated;

-- ============================================================================
-- 6. advance_dropship_order_status
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
  v_current_status public.shop_order_status;
  v_shop_type public.shop_type_enum;
  v_is_valid boolean := false;
  v_global_invoice_id bigint;
  v_invoice record;
  v_order record;
begin
  select status, shop_type_snapshot, global_invoice_id into v_current_status, v_shop_type, v_global_invoice_id
  from public.shop_orders where id = p_order_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
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
  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

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

-- ============================================================================
-- 7. fulfill_shop_order_to_invoice
-- ============================================================================
create or replace function public.fulfill_shop_order_to_invoice(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  if v_order.shop_type_snapshot = 'dropship' then
    v_invoice_type := 'dropship'::public.global_invoice_type;
    v_retail_billing_mode := null;
  else
    if v_order.order_mode_snapshot = 'checkout_wholesale' then
      v_invoice_type := 'wholesale'::public.global_invoice_type;
      v_retail_billing_mode := null;
    else
      v_invoice_type := 'retail'::public.global_invoice_type;
      if v_order.billing_profile_id is not null then
        v_retail_billing_mode := 'account'::public.retail_billing_mode;
      else
        v_retail_billing_mode := 'direct'::public.retail_billing_mode;
      end if;
    end if;
  end if;

  v_invoice_no := 'INV-SO-' || v_order.order_no;

  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => v_invoice_type,
    p_billing_profile_id => v_order.billing_profile_id,
    p_recipient_party_id => null,
    p_recipient_name => v_order.recipient_name,
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_note => coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
  );

  update public.global_invoices
  set
    shipping_charge = case when v_invoice_type = 'dropship' then 0 else coalesce(v_order.delivery_charge_amount, 0) end,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = 'billing_profile'::public.collection_source_type
  where id = v_invoice.id;

  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    perform public.add_global_invoice_item(
      p_invoice_id => v_invoice.id,
      p_global_stock_id => v_item.global_stock_id,
      p_quantity => v_item.quantity::numeric,
      p_sell_price_amount => coalesce(v_item.final_price_amount, v_item.unit_sell_price_amount, v_item.unit_list_price_amount),
      p_line_discount_amount => 0.00
    );

    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  perform public.recompute_global_invoice_totals(v_invoice.id);
  perform public.post_global_invoice(v_invoice.id);

  update public.shop_orders
  set status = 'fulfilled',
      global_invoice_id = v_invoice.id,
      fulfilled_at = now(),
      updated_at = now()
  where id = p_order_id;
end;
$$;

grant execute on function public.fulfill_shop_order_to_invoice(bigint) to authenticated;

-- ============================================================================
-- 8. apply_global_invoice_target_total & list_global_invoice_items
-- ============================================================================
create or replace function public.apply_global_invoice_target_total(
  p_invoice_id bigint,
  p_target_total numeric,
  p_dry_run boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_charges_sum numeric(12,2);
  v_target_line_subtotal numeric(12,2);
  v_current_subtotal numeric(12,2);
  v_current_total numeric(12,2);
  v_count integer;
  v_index integer := 0;
  v_running numeric(12,2) := 0.00;
  v_share numeric(12,2);
  v_base numeric(12,2);
  v_old_price numeric(12,2);
  v_new_price numeric(12,2);
  v_item record;
  v_lines jsonb := '[]'::jsonb;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot adjust totals on a non-draft invoice';
  end if;
  if p_target_total is null or p_target_total < 0 then
    raise exception 'target total must be 0 or greater';
  end if;

  v_charges_sum := coalesce(v_invoice.shipping_charge, 0.00)
    + coalesce(v_invoice.wrapping_charge, 0.00)
    + coalesce(v_invoice.print_charge, 0.00);

  v_target_line_subtotal := round(p_target_total - v_charges_sum + coalesce(v_invoice.discount_amount, 0.00), 2);
  if v_target_line_subtotal < 0 then
    raise exception 'target total too low: charges and discount leave no room for item prices';
  end if;

  select
    count(*),
    coalesce(sum(line_total_amount), 0.00)
  into v_count, v_current_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  if v_count = 0 then raise exception 'invoice has no items to adjust'; end if;
  if v_current_subtotal <= 0 then
    raise exception 'current item subtotal is zero; cannot spread proportionally';
  end if;

  v_current_total := round(coalesce(v_invoice.subtotal_amount, 0.00) + v_charges_sum - coalesce(v_invoice.discount_amount, 0.00), 2);

  for v_item in
    select id, name_snapshot, quantity, sell_price_amount, line_total_amount, line_discount_amount
    from public.global_invoice_items
    where invoice_id = p_invoice_id
    order by id asc
  loop
    v_index := v_index + 1;
    v_base := v_item.line_total_amount;
    v_old_price := v_item.sell_price_amount;

    if v_index = v_count then
      v_share := round(v_target_line_subtotal - v_running, 2);
    else
      v_share := round(v_target_line_subtotal * (v_base / v_current_subtotal), 2);
      v_running := v_running + v_share;
    end if;

    if v_share < 0 then
      raise exception 'target total too low: item "%" would need a negative line total', v_item.name_snapshot;
    end if;

    v_new_price := round((v_share + coalesce(v_item.line_discount_amount, 0.00)) / v_item.quantity, 2);
    if v_new_price < 0 then
      raise exception 'target total too low: item "%" would need a negative price', v_item.name_snapshot;
    end if;

    v_lines := v_lines || jsonb_build_object(
      'item_id', v_item.id,
      'name', v_item.name_snapshot,
      'quantity', v_item.quantity,
      'old_price', v_old_price,
      'new_price', v_new_price,
      'unit_delta', round(v_new_price - v_old_price, 2),
      'line_delta', round(v_share - v_base, 2)
    );

    if not p_dry_run then
      update public.global_invoice_items
      set sell_price_amount = v_new_price,
          line_total_amount = v_share
      where id = v_item.id;
    end if;
  end loop;

  if not p_dry_run then
    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  return jsonb_build_object(
    'current_total', v_current_total,
    'target_total', round(p_target_total, 2),
    'adjustment', round(p_target_total - v_current_total, 2),
    'lines', v_lines
  );
end;
$$;

create or replace function public.list_global_invoice_items(p_invoice_id bigint)
returns table (
  id bigint,
  invoice_id bigint,
  global_stock_id bigint,
  name_snapshot text,
  quantity numeric,
  sell_price_amount numeric,
  recipient_price_amount numeric,
  line_face_total_amount numeric,
  line_discount_amount numeric,
  line_total_amount numeric,
  return_quantity numeric,
  image_url text,
  shipment_id bigint,
  shipment_item_id bigint,
  purchase_price numeric,
  product_weight numeric,
  package_weight numeric,
  ordered_quantity integer,
  shipment_type text,
  product_conversion_rate numeric,
  cargo_conversion_rate numeric,
  cargo_rate numeric,
  received_weight numeric,
  transaction_rate numeric
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_parent_tenant_id bigint;
  v_tenant_id bigint;
begin
  select parent_tenant_id, tenant_id
  into v_parent_tenant_id, v_tenant_id
  from public.global_invoices
  where public.global_invoices.id = p_invoice_id;

  if not found then
    raise exception 'Invoice with ID % not found', p_invoice_id;
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or public.membership_has_module_action(v_tenant_id, 'global_invoice', 'view')
  ) then
    raise exception 'Access denied for invoice with ID %', p_invoice_id;
  end if;

  return query
  select
    gii.id,
    gii.invoice_id,
    gii.global_stock_id,
    gii.name_snapshot,
    gii.quantity,
    gii.sell_price_amount,
    gii.sell_price_amount as recipient_price_amount,
    gii.line_total_amount as line_face_total_amount,
    gii.line_discount_amount,
    gii.line_total_amount,
    gii.return_quantity,
    coalesce(gsi.image_url, p.image_url) as image_url,
    gsi.shipment_id,
    gsi.id as shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text as shipment_type,
    gship.product_conversion_rate,
    gship.cargo_conversion_rate,
    gship.cargo_rate,
    gship.received_weight,
    gship.transaction_rate
  from public.global_invoice_items gii
  left join public.global_stocks gs on gs.id = gii.global_stock_id
  left join public.global_shipment_items gsi
    on gsi.id = coalesce(gii.shipment_item_id, gs.shipment_item_id)
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.products p on p.id = gii.product_id
  where gii.invoice_id = p_invoice_id
  order by gii.id;
end;
$$;

grant execute on function public.apply_global_invoice_target_total(bigint, numeric, boolean) to authenticated;
grant execute on function public.list_global_invoice_items(bigint) to authenticated;

commit;
