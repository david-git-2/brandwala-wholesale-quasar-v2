-- Migration: Add transactional RPCs for Commerce and Normal Invoices
begin;

-- ====================================================================
-- COMMERCE INVOICES RPCS
-- ====================================================================

-- 1. update_commerce_invoice_item_transactional
create or replace function public.update_commerce_invoice_item_transactional(
  p_invoice_id bigint,
  p_order_item_id bigint,
  p_quantity integer,
  p_sell_price_bdt numeric,
  p_recipient_price_bdt numeric,
  p_unit text
)
returns void
language plpgsql
security definer
as $$
declare
  v_old_qty integer;
  v_inventory_item_id bigint;
  v_qty_delta integer;
  v_stock_id bigint;
  v_available_qty integer;
  v_reserved_qty integer;
  v_damaged_qty integer;
  v_stolen_qty integer;
  v_usable_qty integer;
  v_tenant_id bigint;
  v_cust_group_id bigint;
  v_billing_profile_id bigint;
  v_is_paid boolean;
  v_order_id bigint;
  v_cost_bdt numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
begin
  -- Fetch current item details
  select quantity, inventory_item_id, cost_bdt, shipment_item_id, product_id
  into v_old_qty, v_inventory_item_id, v_cost_bdt, v_shipment_item_id, v_product_id
  from public.commerce_order_items
  where id = p_order_item_id;

  if v_old_qty is null then
    raise exception 'Order item not found.';
  end if;

  v_qty_delta := p_quantity - v_old_qty;

  -- Fetch invoice context
  select tenant_id, billing_profile_id, order_id, is_customer_group_paid
  into v_tenant_id, v_billing_profile_id, v_order_id, v_is_paid
  from public.commerce_invoices
  where id = p_invoice_id;

  -- Adjust stock if inventory_item_id is linked and quantity changed
  if v_inventory_item_id is not null and v_qty_delta <> 0 then
    select id, available_quantity, reserved_quantity, damaged_quantity, stolen_quantity
    into v_stock_id, v_available_qty, v_reserved_qty, v_damaged_qty, v_stolen_qty
    from public.inventory_stocks
    where inventory_item_id = v_inventory_item_id;

    if v_stock_id is null then
      raise exception 'Stock record not found.';
    end if;

    v_available_qty := coalesce(v_available_qty, 0);
    v_reserved_qty := coalesce(v_reserved_qty, 0);
    v_damaged_qty := coalesce(v_damaged_qty, 0);
    v_stolen_qty := coalesce(v_stolen_qty, 0);

    v_usable_qty := greatest(0, v_available_qty - v_reserved_qty - v_damaged_qty - v_stolen_qty);

    if v_qty_delta > 0 and (v_qty_delta > v_usable_qty or v_qty_delta > v_available_qty) then
      raise exception 'Not enough usable stock.';
    end if;

    update public.inventory_stocks
    set available_quantity = available_quantity - v_qty_delta
    where id = v_stock_id;

    insert into public.inventory_movements (
      inventory_item_id, type, quantity, previous_quantity, new_quantity, note
    )
    values (
      v_inventory_item_id,
      case when v_qty_delta > 0 then 'sold'::text else 'adjustment'::text end,
      abs(v_qty_delta),
      v_available_qty,
      v_available_qty - v_qty_delta,
      'Adjusted quantity on commerce invoice #' || p_invoice_id
    );
  end if;

  -- Update order item
  update public.commerce_order_items
  set quantity = p_quantity,
      sell_price_bdt = p_sell_price_bdt,
      recipient_price_bdt = p_recipient_price_bdt,
      unit = coalesce(p_unit, unit, 'pcs')
  where id = p_order_item_id;

  -- Maintain accounting entry
  if v_order_id is not null then
    select customer_group_id into v_cust_group_id
    from public.commerce_orders
    where id = v_order_id;
  elsif v_billing_profile_id is not null then
    select customer_group_id into v_cust_group_id
    from public.billing_profiles
    where id = v_billing_profile_id;
  end if;

  insert into public.inventory_accounting_entries (
    type, commerce_order_item_id, commerce_invoice_id, cost_amount,
    shipment_item_id, sell_price_amount, recipient_sell_price_amount,
    customer_group_id, billing_profile_id, status, tenant_id,
    inventory_item_id, product_id, quantity, total_cost_amount,
    total_sell_amount, gross_profit_amount
  )
  values (
    'commerce', p_order_item_id, p_invoice_id, v_cost_bdt,
    v_shipment_item_id, p_sell_price_bdt, p_recipient_price_bdt,
    coalesce(v_cust_group_id, 0), v_billing_profile_id,
    case when v_is_paid then 'paid'::text else 'due'::text end,
    v_tenant_id, v_inventory_item_id, v_product_id, p_quantity,
    (v_cost_bdt * p_quantity), (p_sell_price_bdt * p_quantity),
    ((p_sell_price_bdt - v_cost_bdt) * p_quantity)
  )
  on conflict (commerce_order_item_id) where (type = 'commerce')
  do update set
    sell_price_amount = excluded.sell_price_amount,
    recipient_sell_price_amount = excluded.recipient_sell_price_amount,
    quantity = excluded.quantity,
    total_cost_amount = excluded.total_cost_amount,
    total_sell_amount = excluded.total_sell_amount,
    gross_profit_amount = excluded.gross_profit_amount,
    updated_at = now();

  -- Trigger totals recalculation
  update public.commerce_invoices
  set updated_at = now()
  where id = p_invoice_id;
end;
$$;

-- 2. assign_commerce_order_item_inventory_transactional
create or replace function public.assign_commerce_order_item_inventory_transactional(
  p_invoice_id bigint,
  p_order_item_id bigint,
  p_inventory_item_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_old_inventory_item_id bigint;
  v_quantity integer;
  v_stock_id bigint;
  v_available_qty integer;
  v_reserved_qty integer;
  v_damaged_qty integer;
  v_stolen_qty integer;
  v_usable_qty integer;
  v_tenant_id bigint;
  v_cust_group_id bigint;
  v_billing_profile_id bigint;
  v_is_paid boolean;
  v_order_id bigint;
  
  v_cost_bdt numeric;
  v_source_type text;
  v_source_id bigint;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_shipment_id bigint;
begin
  -- Fetch current item details
  select quantity, inventory_item_id
  into v_quantity, v_old_inventory_item_id
  from public.commerce_order_items
  where id = p_order_item_id;

  if v_quantity is null then
    raise exception 'Order item not found.';
  end if;

  -- Fetch invoice context
  select tenant_id, billing_profile_id, order_id, is_customer_group_paid
  into v_tenant_id, v_billing_profile_id, v_order_id, v_is_paid
  from public.commerce_invoices
  where id = p_invoice_id;

  -- Restock old inventory item if it was assigned
  if v_old_inventory_item_id is not null and v_old_inventory_item_id <> p_inventory_item_id then
    select id, available_quantity into v_stock_id, v_available_qty
    from public.inventory_stocks
    where inventory_item_id = v_old_inventory_item_id;

    if v_stock_id is not null then
      update public.inventory_stocks
      set available_quantity = available_quantity + v_quantity
      where id = v_stock_id;

      insert into public.inventory_movements (
        inventory_item_id, type, quantity, previous_quantity, new_quantity, note
      )
      values (
        v_old_inventory_item_id, 'adjustment', v_quantity,
        coalesce(v_available_qty, 0), coalesce(v_available_qty, 0) + v_quantity,
        'Reassigned from commerce invoice #' || p_invoice_id || ' order item #' || p_order_item_id
      );
    end if;
  end if;

  -- Deduct stock for new inventory item if changed
  if p_inventory_item_id is not null and (v_old_inventory_item_id is null or v_old_inventory_item_id <> p_inventory_item_id) then
    select tenant_id, cost, source_type, source_id, product_id
    into v_tenant_id, v_cost_bdt, v_source_type, v_source_id, v_product_id
    from public.inventory_items
    where id = p_inventory_item_id;

    if v_tenant_id is null then
      raise exception 'New inventory item not found.';
    end if;

    if v_source_type = 'shipment' then
      v_shipment_item_id := v_source_id;
    else
      v_shipment_item_id := null;
    end if;

    select id, available_quantity, reserved_quantity, damaged_quantity, stolen_quantity
    into v_stock_id, v_available_qty, v_reserved_qty, v_damaged_qty, v_stolen_qty
    from public.inventory_stocks
    where inventory_item_id = p_inventory_item_id;

    if v_stock_id is null then
      raise exception 'Stock record not found for new item.';
    end if;

    v_available_qty := coalesce(v_available_qty, 0);
    v_reserved_qty := coalesce(v_reserved_qty, 0);
    v_damaged_qty := coalesce(v_damaged_qty, 0);
    v_stolen_qty := coalesce(v_stolen_qty, 0);

    v_usable_qty := greatest(0, v_available_qty - v_reserved_qty - v_damaged_qty - v_stolen_qty);

    if v_quantity > v_usable_qty or v_quantity > v_available_qty then
      raise exception 'Not enough usable stock for new inventory item.';
    end if;

    update public.inventory_stocks
    set available_quantity = available_quantity - v_quantity
    where id = v_stock_id;

    insert into public.inventory_movements (
      inventory_item_id, type, quantity, previous_quantity, new_quantity, note
    )
    values (
      p_inventory_item_id, 'sold', v_quantity,
      v_available_qty, v_available_qty - v_quantity,
      'Assigned to commerce invoice #' || p_invoice_id || ' order item #' || p_order_item_id
    );

    update public.commerce_order_items
    set inventory_item_id = p_inventory_item_id,
        shipment_item_id = v_shipment_item_id,
        cost_bdt = coalesce(v_cost_bdt, 0)
    where id = p_order_item_id;
  end if;

  -- Maintain accounting entry
  if v_order_id is not null then
    select customer_group_id into v_cust_group_id
    from public.commerce_orders
    where id = v_order_id;
  elsif v_billing_profile_id is not null then
    select customer_group_id into v_cust_group_id
    from public.billing_profiles
    where id = v_billing_profile_id;
  end if;

  v_shipment_id := null;
  if v_shipment_item_id is not null then
    select shipment_id into v_shipment_id
    from public.shipment_items
    where id = v_shipment_item_id;
  end if;

  insert into public.inventory_accounting_entries (
    type, commerce_order_item_id, commerce_invoice_id, cost_amount,
    shipment_id, shipment_item_id, sell_price_amount, recipient_sell_price_amount,
    customer_group_id, billing_profile_id, status, tenant_id,
    inventory_item_id, product_id, quantity, total_cost_amount,
    total_sell_amount, gross_profit_amount
  )
  select
    'commerce', id, p_invoice_id, cost_bdt,
    v_shipment_id, v_shipment_item_id, sell_price_bdt, recipient_price_bdt,
    coalesce(v_cust_group_id, 0), v_billing_profile_id,
    case when v_is_paid then 'paid'::text else 'due'::text end,
    v_tenant_id, p_inventory_item_id, product_id, quantity,
    (cost_bdt * quantity), (sell_price_bdt * quantity),
    ((sell_price_bdt - cost_bdt) * quantity)
  from public.commerce_order_items
  where id = p_order_item_id
  on conflict (commerce_order_item_id) where (type = 'commerce')
  do update set
    inventory_item_id = excluded.inventory_item_id,
    shipment_id = excluded.shipment_id,
    shipment_item_id = excluded.shipment_item_id,
    cost_amount = excluded.cost_amount,
    total_cost_amount = excluded.total_cost_amount,
    gross_profit_amount = excluded.gross_profit_amount,
    updated_at = now();

  -- Trigger totals recalculation
  update public.commerce_invoices
  set updated_at = now()
  where id = p_invoice_id;
end;
$$;

-- 3. unassign_commerce_order_item_inventory_transactional
create or replace function public.unassign_commerce_order_item_inventory_transactional(
  p_invoice_id bigint,
  p_order_item_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_inventory_item_id bigint;
  v_quantity integer;
  v_stock_id bigint;
  v_available_qty integer;
  v_tenant_id bigint;
  v_cust_group_id bigint;
  v_billing_profile_id bigint;
  v_is_paid boolean;
  v_order_id bigint;
begin
  -- Fetch current item details
  select quantity, inventory_item_id
  into v_quantity, v_inventory_item_id
  from public.commerce_order_items
  where id = p_order_item_id;

  if v_quantity is null then
    raise exception 'Order item not found.';
  end if;

  -- Restock if inventory item was assigned
  if v_inventory_item_id is not null then
    select id, available_quantity into v_stock_id, v_available_qty
    from public.inventory_stocks
    where inventory_item_id = v_inventory_item_id;

    if v_stock_id is not null then
      update public.inventory_stocks
      set available_quantity = available_quantity + v_quantity
      where id = v_stock_id;

      insert into public.inventory_movements (
        inventory_item_id, type, quantity, previous_quantity, new_quantity, note
      )
      values (
        v_inventory_item_id, 'adjustment', v_quantity,
        coalesce(v_available_qty, 0), coalesce(v_available_qty, 0) + v_quantity,
        'Unassigned from commerce invoice #' || p_invoice_id || ' order item #' || p_order_item_id
      );
    end if;
  end if;

  -- Update order item
  update public.commerce_order_items
  set inventory_item_id = null,
      shipment_item_id = null
  where id = p_order_item_id;

  -- Fetch invoice context
  select tenant_id, billing_profile_id, order_id, is_customer_group_paid
  into v_tenant_id, v_billing_profile_id, v_order_id, v_is_paid
  from public.commerce_invoices
  where id = p_invoice_id;

  if v_order_id is not null then
    select customer_group_id into v_cust_group_id
    from public.commerce_orders
    where id = v_order_id;
  elsif v_billing_profile_id is not null then
    select customer_group_id into v_cust_group_id
    from public.billing_profiles
    where id = v_billing_profile_id;
  end if;

  -- Update accounting entry
  insert into public.inventory_accounting_entries (
    type, commerce_order_item_id, commerce_invoice_id, cost_amount,
    shipment_id, shipment_item_id, sell_price_amount, recipient_sell_price_amount,
    customer_group_id, billing_profile_id, status, tenant_id,
    inventory_item_id, product_id, quantity, total_cost_amount,
    total_sell_amount, gross_profit_amount
  )
  select
    'commerce', id, p_invoice_id, cost_bdt,
    null, null, sell_price_bdt, recipient_price_bdt,
    coalesce(v_cust_group_id, 0), v_billing_profile_id,
    case when v_is_paid then 'paid'::text else 'due'::text end,
    v_tenant_id, null, product_id, quantity,
    (cost_bdt * quantity), (sell_price_bdt * quantity),
    ((sell_price_bdt - cost_bdt) * quantity)
  from public.commerce_order_items
  where id = p_order_item_id
  on conflict (commerce_order_item_id) where (type = 'commerce')
  do update set
    inventory_item_id = null,
    shipment_id = null,
    shipment_item_id = null,
    updated_at = now();

  -- Trigger totals recalculation
  update public.commerce_invoices
  set updated_at = now()
  where id = p_invoice_id;
end;
$$;

-- 4. remove_commerce_invoice_item_transactional
create or replace function public.remove_commerce_invoice_item_transactional(
  p_invoice_id bigint,
  p_order_item_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_inventory_item_id bigint;
  v_quantity integer;
  v_stock_id bigint;
  v_available_qty integer;
begin
  -- Fetch current item details
  select quantity, inventory_item_id
  into v_quantity, v_inventory_item_id
  from public.commerce_order_items
  where id = p_order_item_id;

  if v_quantity is null then
    raise exception 'Order item not found.';
  end if;

  -- Restock if inventory item was assigned
  if v_inventory_item_id is not null then
    select id, available_quantity into v_stock_id, v_available_qty
    from public.inventory_stocks
    where inventory_item_id = v_inventory_item_id;

    if v_stock_id is not null then
      update public.inventory_stocks
      set available_quantity = available_quantity + v_quantity
      where id = v_stock_id;

      insert into public.inventory_movements (
        inventory_item_id, type, quantity, previous_quantity, new_quantity, note
      )
      values (
        v_inventory_item_id, 'adjustment', v_quantity,
        coalesce(v_available_qty, 0), coalesce(v_available_qty, 0) + v_quantity,
        'Unassigned from commerce invoice #' || p_invoice_id
      );
    end if;
  end if;

  -- Update order item to remove invoice association
  update public.commerce_order_items
  set invoice_id = null,
      inventory_item_id = null,
      shipment_item_id = null
  where id = p_order_item_id;

  -- Delete accounting entry
  delete from public.inventory_accounting_entries
  where commerce_order_item_id = p_order_item_id
    and type = 'commerce';

  -- Trigger totals recalculation
  update public.commerce_invoices
  set updated_at = now()
  where id = p_invoice_id;
end;
$$;

-- 5. delete_commerce_invoice_transactional
create or replace function public.delete_commerce_invoice_transactional(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_order_id bigint;
  v_item record;
  v_stock_id bigint;
  v_available_qty integer;
begin
  -- Fetch commerce invoice order_id
  select order_id into v_order_id
  from public.commerce_invoices
  where id = p_invoice_id;

  -- Restock all order items associated with the invoice
  for v_item in (
    select id, quantity, inventory_item_id
    from public.commerce_order_items
    where invoice_id = p_invoice_id
  ) loop
    if v_item.inventory_item_id is not null then
      select id, available_quantity into v_stock_id, v_available_qty
      from public.inventory_stocks
      where inventory_item_id = v_item.inventory_item_id;

      if v_stock_id is not null then
        update public.inventory_stocks
        set available_quantity = available_quantity + v_item.quantity
        where id = v_stock_id;

        insert into public.inventory_movements (
          inventory_item_id, type, quantity, previous_quantity, new_quantity, note
        )
        values (
          v_item.inventory_item_id, 'adjustment', v_item.quantity,
          coalesce(v_available_qty, 0), coalesce(v_available_qty, 0) + v_item.quantity,
          'Restocked after deleting commerce invoice #' || p_invoice_id
        );
      end if;
    end if;
  end loop;

  -- Delete accounting entries
  delete from public.inventory_accounting_entries
  where commerce_invoice_id = p_invoice_id
    and type = 'commerce';

  -- Update or delete order items
  if v_order_id is not null then
    update public.commerce_order_items
    set invoice_id = null,
        inventory_item_id = null,
        shipment_item_id = null
    where invoice_id = p_invoice_id;

    -- Update order to remove invoice ID
    update public.commerce_orders
    set invoice_ids = array_remove(invoice_ids, p_invoice_id)
    where id = v_order_id;
  else
    delete from public.commerce_order_items
    where invoice_id = p_invoice_id;
  end if;

  -- Delete invoice
  delete from public.commerce_invoices
  where id = p_invoice_id;
end;
$$;


-- ====================================================================
-- NORMAL INVOICES RPCS
-- ====================================================================

-- Helper to recalculate normal invoice totals and payment status
create or replace function public.fn_recalculate_normal_invoice_totals(p_invoice_id bigint)
returns void
language plpgsql
security definer
as $$
declare
  v_subtotal numeric;
  v_discount numeric;
  v_total numeric;
begin
  select coalesce(sum(line_total_amount), 0)
  into v_subtotal
  from public.invoice_items
  where invoice_id = p_invoice_id;

  select discount_amount
  into v_discount
  from public.invoices
  where id = p_invoice_id;

  v_discount := coalesce(v_discount, 0);
  v_total := greatest(0, v_subtotal - v_discount);

  update public.invoices
  set subtotal_amount = v_subtotal,
      total_amount = v_total
  where id = p_invoice_id;

  perform public.recompute_invoice_payment_status(p_invoice_id);
end;
$$;

-- 1. add_invoice_item_transactional
create or replace function public.add_invoice_item_transactional(
  p_tenant_id bigint,
  p_invoice_id bigint,
  p_inventory_item_id bigint,
  p_quantity numeric,
  p_cost_amount numeric,
  p_sell_price_amount numeric,
  p_name_snapshot text,
  p_barcode_snapshot text,
  p_product_code_snapshot text,
  p_source_item_type text,
  p_source_item_id bigint,
  p_line_discount_amount numeric,
  p_line_tax_amount numeric,
  p_created_by uuid
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_invoice_no text;
  v_subtype text;
  v_stock_id bigint;
  v_available_qty integer;
  v_open_box_qty integer;
  v_expired_qty integer;
  v_reserved_qty integer;
  v_damaged_qty integer;
  v_stolen_qty integer;
  v_usable_qty numeric;
  v_next_available integer;
  v_next_open_box integer;
  v_next_expired integer;
  
  v_line_total numeric;
  v_invoice_item_id bigint;
  v_shipment_item_id bigint;
  v_shipment_id bigint;
  v_product_id bigint;
  v_source_type text;
  v_source_id bigint;
  v_payment_status text;
  
  v_new_item record;
begin
  -- Fetch invoice metadata
  select invoice_no, payment_status into v_invoice_no, v_payment_status
  from public.invoices
  where id = p_invoice_id;

  if v_invoice_no is null then
    raise exception 'Invoice not found.';
  end if;

  -- Determine stock subtype
  v_subtype := 'standard';
  if p_name_snapshot like '%(Boxless)' then
    v_subtype := 'boxless';
  elsif p_name_snapshot like '%(Box Damage)' then
    v_subtype := 'box_damage';
  elsif p_name_snapshot like '%(Expired)' then
    v_subtype := 'expired';
  end if;

  -- Adjust stock if inventory_item_id is provided
  if p_inventory_item_id is not null then
    select id, available_quantity, open_box_quantity, expired_quantity, reserved_quantity, damaged_quantity, stolen_quantity
    into v_stock_id, v_available_qty, v_open_box_qty, v_expired_qty, v_reserved_qty, v_damaged_qty, v_stolen_qty
    from public.inventory_stocks
    where inventory_item_id = p_inventory_item_id;

    if v_stock_id is null then
      raise exception 'Stock record not found for inventory item.';
    end if;

    v_available_qty := coalesce(v_available_qty, 0);
    v_open_box_qty := coalesce(v_open_box_qty, 0);
    v_expired_qty := coalesce(v_expired_qty, 0);
    v_reserved_qty := coalesce(v_reserved_qty, 0);
    v_damaged_qty := coalesce(v_damaged_qty, 0);
    v_stolen_qty := coalesce(v_stolen_qty, 0);

    -- check availability
    v_usable_qty := 0;
    if v_subtype = 'standard' then
      v_usable_qty := greatest(0, v_available_qty - v_reserved_qty - v_damaged_qty - v_stolen_qty);
    elsif v_subtype = 'boxless' or v_subtype = 'box_damage' then
      v_usable_qty := v_open_box_qty;
    elsif v_subtype = 'expired' then
      v_usable_qty := v_expired_qty;
    end if;

    if p_quantity > v_usable_qty or p_quantity > v_available_qty then
      raise exception 'Not enough usable stock.';
    end if;

    -- Update stock
    v_next_available := v_available_qty - p_quantity;
    v_next_open_box := v_open_box_qty;
    v_next_expired := v_expired_qty;

    if v_subtype = 'boxless' or v_subtype = 'box_damage' then
      v_next_open_box := v_open_box_qty - p_quantity;
    elsif v_subtype = 'expired' then
      v_next_expired := v_expired_qty - p_quantity;
    end if;

    update public.inventory_stocks
    set available_quantity = v_next_available,
        open_box_quantity = v_next_open_box,
        expired_quantity = v_next_expired
    where id = v_stock_id;

    insert into public.inventory_movements (
      inventory_item_id, type, quantity, previous_quantity, new_quantity, note, created_by
    )
    values (
      p_inventory_item_id, 'sold', p_quantity, v_available_qty, v_next_available,
      'Auto-deducted from invoice #' || v_invoice_no, p_created_by
    );
  end if;

  v_line_total := round(p_sell_price_amount * p_quantity - coalesce(p_line_discount_amount, 0) + coalesce(p_line_tax_amount, 0), 2);

  -- Insert invoice item
  insert into public.invoice_items (
    tenant_id, invoice_id, source_item_type, source_item_id, inventory_item_id,
    product_id, name_snapshot, barcode_snapshot, product_code_snapshot,
    quantity, cost_amount, sell_price_amount, line_discount_amount,
    line_tax_amount, line_total_amount
  )
  values (
    p_tenant_id, p_invoice_id, p_source_item_type, p_source_item_id, p_inventory_item_id,
    p_product_id, p_name_snapshot, p_barcode_snapshot, p_product_code_snapshot,
    p_quantity, p_cost_amount, p_sell_price_amount, coalesce(p_line_discount_amount, 0),
    coalesce(p_line_tax_amount, 0), v_line_total
  )
  returning id into v_invoice_item_id;

  -- Create accounting entry
  if p_inventory_item_id is not null then
    select source_type, source_id into v_source_type, v_source_id
    from public.inventory_items
    where id = p_inventory_item_id;

    if v_source_type = 'shipment' then
      v_shipment_item_id := v_source_id;
      
      select shipment_id into v_shipment_id
      from public.shipment_items
      where id = v_shipment_item_id;
    end if;
  end if;

  insert into public.inventory_accounting_entries (
    tenant_id, invoice_id, invoice_item_id, inventory_item_id, shipment_id, shipment_item_id,
    product_id, quantity, return_quantity, return_amount, cost_amount, sell_price_amount,
    total_cost_amount, total_sell_amount, gross_profit_amount, status, entry_date, note, created_by
  )
  values (
    p_tenant_id, p_invoice_id, v_invoice_item_id, p_inventory_item_id, v_shipment_id, v_shipment_item_id,
    p_product_id, p_quantity, 0, 0, p_cost_amount, p_sell_price_amount,
    (p_cost_amount * p_quantity), (p_sell_price_amount * p_quantity),
    ((p_sell_price_amount - p_cost_amount) * p_quantity),
    case when v_payment_status = 'paid' then 'paid'::text else 'due'::text end,
    current_date, 'Created from invoice #' || v_invoice_no, p_created_by
  );

  -- Recalculate totals
  perform public.fn_recalculate_normal_invoice_totals(p_invoice_id);

  -- Return the created item details as JSON
  select * into v_new_item from public.invoice_items where id = v_invoice_item_id;
  return row_to_json(v_new_item)::jsonb;
end;
$$;

-- 2. update_invoice_item_transactional
create or replace function public.update_invoice_item_transactional(
  p_invoice_item_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_unit text
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_old_qty numeric;
  v_inventory_item_id bigint;
  v_invoice_id bigint;
  v_name_snapshot text;
  v_qty_delta numeric;
  v_subtype text;
  v_stock_id bigint;
  v_available_qty integer;
  v_open_box_qty integer;
  v_expired_qty integer;
  v_reserved_qty integer;
  v_damaged_qty integer;
  v_stolen_qty integer;
  v_usable_qty numeric;
  v_next_available integer;
  v_next_open_box integer;
  v_next_expired integer;
  
  v_cost_amount numeric;
  v_line_discount numeric;
  v_line_tax numeric;
  v_line_total numeric;
  v_accounting_id bigint;
  v_returned_qty numeric;
  v_return_amount numeric;
  
  v_updated_item record;
begin
  -- Fetch current item details
  select quantity, inventory_item_id, name_snapshot, invoice_id, cost_amount, line_discount_amount, line_tax_amount,
         coalesce(return_normal_quantity, 0) + coalesce(return_open_box_quantity, 0) + coalesce(return_damaged_quantity, 0),
         coalesce(return_amount, 0)
  into v_old_qty, v_inventory_item_id, v_name_snapshot, v_invoice_id, v_cost_amount, v_line_discount, v_line_tax,
       v_returned_qty, v_return_amount
  from public.invoice_items
  where id = p_invoice_item_id;

  if v_old_qty is null then
    raise exception 'Invoice item not found.';
  end if;

  if p_quantity < v_returned_qty then
    raise exception 'Quantity cannot be less than already returned quantity.';
  end if;

  v_qty_delta := p_quantity - v_old_qty;

  -- Determine stock subtype
  v_subtype := 'standard';
  if v_name_snapshot like '%(Boxless)' then
    v_subtype := 'boxless';
  elsif v_name_snapshot like '%(Box Damage)' then
    v_subtype := 'box_damage';
  elsif v_name_snapshot like '%(Expired)' then
    v_subtype := 'expired';
  end if;

  -- Adjust stock if inventory_item_id is linked and quantity changed
  if v_inventory_item_id is not null and v_qty_delta <> 0 then
    select id, available_quantity, open_box_quantity, expired_quantity, reserved_quantity, damaged_quantity, stolen_quantity
    into v_stock_id, v_available_qty, v_open_box_qty, v_expired_qty, v_reserved_qty, v_damaged_qty, v_stolen_qty
    from public.inventory_stocks
    where inventory_item_id = v_inventory_item_id;

    if v_stock_id is null then
      raise exception 'Stock record not found.';
    end if;

    v_available_qty := coalesce(v_available_qty, 0);
    v_open_box_qty := coalesce(v_open_box_qty, 0);
    v_expired_qty := coalesce(v_expired_qty, 0);
    v_reserved_qty := coalesce(v_reserved_qty, 0);
    v_damaged_qty := coalesce(v_damaged_qty, 0);
    v_stolen_qty := coalesce(v_stolen_qty, 0);

    -- check availability
    v_usable_qty := 0;
    if v_subtype = 'standard' then
      v_usable_qty := greatest(0, v_available_qty - v_reserved_qty - v_damaged_qty - v_stolen_qty);
    elsif v_subtype = 'boxless' or v_subtype = 'box_damage' then
      v_usable_qty := v_open_box_qty;
    elsif v_subtype = 'expired' then
      v_usable_qty := v_expired_qty;
    end if;

    if v_qty_delta > 0 and (v_qty_delta > v_usable_qty or v_qty_delta > v_available_qty) then
      raise exception 'Not enough usable stock.';
    end if;

    -- Update stock
    v_next_available := v_available_qty - v_qty_delta;
    v_next_open_box := v_open_box_qty;
    v_next_expired := v_expired_qty;

    if v_subtype = 'boxless' or v_subtype = 'box_damage' then
      v_next_open_box := v_open_box_qty - v_qty_delta;
    elsif v_subtype = 'expired' then
      v_next_expired := v_expired_qty - v_qty_delta;
    end if;

    update public.inventory_stocks
    set available_quantity = v_next_available,
        open_box_quantity = v_next_open_box,
        expired_quantity = v_next_expired
    where id = v_stock_id;

    insert into public.inventory_movements (
      inventory_item_id, type, quantity, previous_quantity, new_quantity, note
    )
    values (
      v_inventory_item_id,
      case when v_qty_delta > 0 then 'sold'::text else 'adjustment'::text end,
      abs(v_qty_delta),
      v_available_qty,
      v_next_available,
      'Invoice quantity changed from ' || v_old_qty || ' to ' || p_quantity
    );
  end if;

  v_line_total := round(p_sell_price_amount * p_quantity - coalesce(v_line_discount, 0) + coalesce(v_line_tax, 0), 2);

  -- Update invoice item
  update public.invoice_items
  set quantity = p_quantity,
      sell_price_amount = p_sell_price_amount,
      line_total_amount = v_line_total
  where id = p_invoice_item_id;

  -- Maintain accounting entry
  select id into v_accounting_id
  from public.inventory_accounting_entries
  where invoice_item_id = p_invoice_item_id;

  if v_accounting_id is not null then
    declare
      v_net_qty numeric;
      v_tot_sell numeric;
      v_tot_cost numeric;
    begin
      v_net_qty := greatest(0, p_quantity - v_returned_qty);
      v_tot_sell := round(greatest(0, p_sell_price_amount * p_quantity - v_return_amount), 2);
      v_tot_cost := round(v_cost_amount * v_net_qty, 2);

      update public.inventory_accounting_entries
      set quantity = v_net_qty,
          sell_price_amount = p_sell_price_amount,
          return_quantity = v_returned_qty,
          return_amount = v_return_amount,
          total_sell_amount = v_tot_sell,
          total_cost_amount = v_tot_cost,
          gross_profit_amount = round(v_tot_sell - v_tot_cost, 2),
          updated_at = now()
      where id = v_accounting_id;
    end;
  end if;

  -- Recalculate totals
  perform public.fn_recalculate_normal_invoice_totals(v_invoice_id);

  select * into v_updated_item from public.invoice_items where id = p_invoice_item_id;
  return row_to_json(v_updated_item)::jsonb;
end;
$$;

-- 3. delete_invoice_item_transactional
create or replace function public.delete_invoice_item_transactional(
  p_invoice_item_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_inventory_item_id bigint;
  v_quantity numeric;
  v_returned_qty numeric;
  v_net_qty numeric;
  v_invoice_id bigint;
  v_name_snapshot text;
  v_subtype text;
  v_stock_id bigint;
  v_available_qty integer;
  v_open_box_qty integer;
  v_expired_qty integer;
begin
  -- Fetch current item details
  select quantity, inventory_item_id, name_snapshot, invoice_id,
         coalesce(return_normal_quantity, 0) + coalesce(return_open_box_quantity, 0) + coalesce(return_damaged_quantity, 0)
  into v_quantity, v_inventory_item_id, v_name_snapshot, v_invoice_id, v_returned_qty
  from public.invoice_items
  where id = p_invoice_item_id;

  if v_quantity is null then
    raise exception 'Invoice item not found.';
  end if;

  v_net_qty := greatest(0, v_quantity - v_returned_qty);

  -- Determine stock subtype
  v_subtype := 'standard';
  if v_name_snapshot like '%(Boxless)' then
    v_subtype := 'boxless';
  elsif v_name_snapshot like '%(Box Damage)' then
    v_subtype := 'box_damage';
  elsif v_name_snapshot like '%(Expired)' then
    v_subtype := 'expired';
  end if;

  -- Restock if inventory item was assigned and net qty > 0
  if v_inventory_item_id is not null and v_net_qty > 0 then
    select id, available_quantity, open_box_quantity, expired_quantity
    into v_stock_id, v_available_qty, v_open_box_qty, v_expired_qty
    from public.inventory_stocks
    where inventory_item_id = v_inventory_item_id;

    if v_stock_id is not null then
      update public.inventory_stocks
      set available_quantity = available_quantity + v_net_qty,
          open_box_quantity = open_box_quantity + (case when v_subtype = 'boxless' or v_subtype = 'box_damage' then v_net_qty else 0 end),
          expired_quantity = expired_quantity + (case when v_subtype = 'expired' then v_net_qty else 0 end)
      where id = v_stock_id;

      insert into public.inventory_movements (
        inventory_item_id, type, quantity, previous_quantity, new_quantity, note
      )
      values (
        v_inventory_item_id, 'adjustment', v_net_qty,
        coalesce(v_available_qty, 0), coalesce(v_available_qty, 0) + v_net_qty,
        'Invoice item deleted'
      );
    end if;
  end if;

  -- Delete accounting entry
  delete from public.inventory_accounting_entries
  where invoice_item_id = p_invoice_item_id;

  -- Delete invoice item
  delete from public.invoice_items
  where id = p_invoice_item_id;

  -- Recalculate totals
  perform public.fn_recalculate_normal_invoice_totals(v_invoice_id);
end;
$$;

-- 4. delete_invoice_transactional
create or replace function public.delete_invoice_transactional(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_item record;
  v_subtype text;
  v_stock_id bigint;
  v_available_qty integer;
  v_open_box_qty integer;
  v_expired_qty integer;
  v_returned_qty numeric;
  v_net_qty numeric;
begin
  -- Restock all items
  for v_item in (
    select id, quantity, inventory_item_id, name_snapshot,
           coalesce(return_normal_quantity, 0) + coalesce(return_open_box_quantity, 0) + coalesce(return_damaged_quantity, 0) as returned_qty
    from public.invoice_items
    where invoice_id = p_invoice_id
  ) loop
    v_net_qty := greatest(0, v_item.quantity - v_item.returned_qty);

    if v_item.inventory_item_id is not null and v_net_qty > 0 then
      v_subtype := 'standard';
      if v_item.name_snapshot like '%(Boxless)' then
        v_subtype := 'boxless';
      elsif v_item.name_snapshot like '%(Box Damage)' then
        v_subtype := 'box_damage';
      elsif v_item.name_snapshot like '%(Expired)' then
        v_subtype := 'expired';
      end if;

      select id, available_quantity, open_box_quantity, expired_quantity
      into v_stock_id, v_available_qty, v_open_box_qty, v_expired_qty
      from public.inventory_stocks
      where inventory_item_id = v_item.inventory_item_id;

      if v_stock_id is not null then
        update public.inventory_stocks
        set available_quantity = available_quantity + v_net_qty,
            open_box_quantity = open_box_quantity + (case when v_subtype = 'boxless' or v_subtype = 'box_damage' then v_net_qty else 0 end),
            expired_quantity = expired_quantity + (case when v_subtype = 'expired' then v_net_qty else 0 end)
        where id = v_stock_id;

        insert into public.inventory_movements (
          inventory_item_id, type, quantity, previous_quantity, new_quantity, note
        )
        values (
          v_item.inventory_item_id, 'adjustment', v_net_qty,
          coalesce(v_available_qty, 0), coalesce(v_available_qty, 0) + v_net_qty,
          'Restocked after deleting invoice #' || p_invoice_id
        );
      end if;
    end if;
  end loop;

  -- Delete accounting entries
  delete from public.inventory_accounting_entries
  where invoice_id = p_invoice_id;

  -- Delete invoice (cascades to delete invoice_items)
  delete from public.invoices
  where id = p_invoice_id;
end;
$$;


-- ====================================================================
-- PERMISSIONS GRANTS
-- ====================================================================

grant execute on function public.update_commerce_invoice_item_transactional to authenticated;
grant execute on function public.assign_commerce_order_item_inventory_transactional to authenticated;
grant execute on function public.unassign_commerce_order_item_inventory_transactional to authenticated;
grant execute on function public.remove_commerce_invoice_item_transactional to authenticated;
grant execute on function public.delete_commerce_invoice_transactional to authenticated;

grant execute on function public.add_invoice_item_transactional to authenticated;
grant execute on function public.update_invoice_item_transactional to authenticated;
grant execute on function public.delete_invoice_item_transactional to authenticated;
grant execute on function public.delete_invoice_transactional to authenticated;

-- Reload PostgREST schema cache
do $$
begin
  perform pg_notify('pgrst', 'reload schema');
exception
  when others then
    null;
end;
$$;

commit;
