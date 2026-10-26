-- Migration: Decouple Invoices from Orders
begin;

-- 1. Drop NOT NULL constraint on order_id in commerce_invoices
alter table public.commerce_invoices alter column order_id drop not null;

-- 2. Add recipient detail columns directly to commerce_invoices
alter table public.commerce_invoices
  add column if not exists recipient_name text null,
  add column if not exists recipient_phone text null,
  add column if not exists shipping_address text null;

-- 3. Drop NOT NULL constraint on order_id in commerce_order_items
alter table public.commerce_order_items alter column order_id drop not null;

-- 4. Add constraint to ensure either order_id or invoice_id is present in commerce_order_items
alter table public.commerce_order_items
  drop constraint if exists check_order_or_invoice_not_null,
  add constraint check_order_or_invoice_not_null check (order_id is not null or invoice_id is not null);

-- 5. Update add_commerce_invoice_item RPC to handle null order_id
create or replace function public.add_commerce_invoice_item(
  p_invoice_id bigint,
  p_order_id bigint,
  p_product_id bigint,
  p_quantity integer,
  p_cost_bdt numeric,
  p_sell_price_bdt numeric,
  p_recipient_price_bdt numeric,
  p_image_url text,
  p_inventory_item_id bigint
)
returns void
language plpgsql
security definer
as $$
declare
  v_tenant_id bigint;
  v_cust_group_id bigint;
  v_is_delivery_charge_inclusive boolean;
  v_invoice_is_paid boolean;
  v_billing_profile_id bigint;
  v_delivery_charge numeric;
  v_wrapping_charge numeric;
  v_cod numeric;
  v_discount_amount numeric;
  v_amount_paid numeric;
  
  v_resolved_cost numeric;
  v_resolved_shipment_item_id bigint;
  v_resolved_tenant_id bigint;
  
  v_stock_id bigint;
  v_available_qty integer;
  v_reserved_qty integer;
  v_damaged_qty integer;
  v_stolen_qty integer;
  v_usable_qty integer;
  v_next_available integer;
  v_source_type text;
  v_source_id bigint;
  v_item_name text;
  
  v_existing_id bigint;
  v_existing_qty integer;
  v_order_item_id bigint;
  
  v_subtotal numeric;
  v_total_amount numeric;
  v_amount_due numeric;
  v_new_is_paid boolean;
  v_shipment_id bigint;
begin
  -- Fetch commerce order context if order_id is provided
  if p_order_id is not null then
    select tenant_id, customer_group_id, is_delivery_charge_inclusive
    into v_tenant_id, v_cust_group_id, v_is_delivery_charge_inclusive
    from public.commerce_orders
    where id = p_order_id;
  else
    v_is_delivery_charge_inclusive := false;
  end if;

  -- Fetch commerce invoice details (and fallback tenant_id)
  select is_customer_group_paid, billing_profile_id, delivery_charge, wrapping_charge, cod, discount_amount, amount_paid, tenant_id
  into v_invoice_is_paid, v_billing_profile_id, v_delivery_charge, v_wrapping_charge, v_cod, v_discount_amount, v_amount_paid, v_tenant_id
  from public.commerce_invoices
  where id = p_invoice_id;

  if v_invoice_is_paid is null then
    raise exception 'Invoice not found.';
  end if;

  if v_cust_group_id is null and v_billing_profile_id is not null then
    select customer_group_id into v_cust_group_id
    from public.billing_profiles
    where id = v_billing_profile_id;
  end if;

  v_resolved_cost := coalesce(p_cost_bdt, 0);
  v_resolved_tenant_id := v_tenant_id;
  v_resolved_shipment_item_id := null;

  -- Adjust inventory stock if p_inventory_item_id is provided
  if p_inventory_item_id is not null then
    select tenant_id, cost, source_type, source_id, name
    into v_resolved_tenant_id, v_resolved_cost, v_source_type, v_source_id, v_item_name
    from public.inventory_items
    where id = p_inventory_item_id;

    if v_resolved_tenant_id is null then
      raise exception 'Inventory item not found.';
    end if;

    if v_source_type = 'shipment' then
      v_resolved_shipment_item_id := v_source_id;
    end if;

    select id, available_quantity, reserved_quantity, damaged_quantity, stolen_quantity
    into v_stock_id, v_available_qty, v_reserved_qty, v_damaged_qty, v_stolen_qty
    from public.inventory_stocks
    where inventory_item_id = p_inventory_item_id;

    if v_stock_id is null then
      raise exception 'Inventory stock not found for selected item.';
    end if;

    v_available_qty := coalesce(v_available_qty, 0);
    v_reserved_qty := coalesce(v_reserved_qty, 0);
    v_damaged_qty := coalesce(v_damaged_qty, 0);
    v_stolen_qty := coalesce(v_stolen_qty, 0);

    v_usable_qty := greatest(0, v_available_qty - v_reserved_qty - v_damaged_qty - v_stolen_qty);

    if p_quantity > v_usable_qty or p_quantity > v_available_qty then
      raise exception 'Not enough usable stock for selected inventory item.';
    end if;

    v_next_available := v_available_qty - p_quantity;

    update public.inventory_stocks
    set available_quantity = v_next_available
    where id = v_stock_id;

    insert into public.inventory_movements (
      inventory_item_id,
      type,
      quantity,
      previous_quantity,
      new_quantity,
      note,
      created_by
    )
    values (
      p_inventory_item_id,
      'sold',
      p_quantity,
      v_available_qty,
      v_next_available,
      'Assigned to commerce invoice #' || p_invoice_id,
      null
    );
  end if;

  -- Check if item already exists in commerce_order_items (linked to this invoice)
  select id, quantity
  into v_existing_id, v_existing_qty
  from public.commerce_order_items
  where (order_id = p_order_id or (p_order_id is null and order_id is null))
    and product_id = p_product_id
    and invoice_id = p_invoice_id
    and (
      (p_inventory_item_id is not null and inventory_item_id = p_inventory_item_id)
      or (p_inventory_item_id is null and inventory_item_id is null)
    )
  limit 1;

  -- Insert or update commerce_order_items
  if v_existing_id is not null then
    update public.commerce_order_items
    set quantity = v_existing_qty + p_quantity,
        cost_bdt = v_resolved_cost,
        sell_price_bdt = p_sell_price_bdt,
        recipient_price_bdt = p_recipient_price_bdt,
        inventory_item_id = p_inventory_item_id,
        shipment_item_id = v_resolved_shipment_item_id
    where id = v_existing_id
    returning id into v_order_item_id;
  else
    insert into public.commerce_order_items (
      order_id,
      invoice_id,
      product_id,
      quantity,
      cost_bdt,
      sell_price_bdt,
      recipient_price_bdt,
      image_url,
      inventory_item_id,
      shipment_item_id,
      unit
    )
    values (
      p_order_id,
      p_invoice_id,
      p_product_id,
      p_quantity,
      v_resolved_cost,
      p_sell_price_bdt,
      p_recipient_price_bdt,
      p_image_url,
      p_inventory_item_id,
      v_resolved_shipment_item_id,
      'pcs'
    )
    returning id into v_order_item_id;
  end if;

  v_shipment_id := null;
  if v_resolved_shipment_item_id is not null then
    select shipment_id into v_shipment_id
    from public.shipment_items
    where id = v_resolved_shipment_item_id;
  end if;

  -- Maintain Accounting Entry
  insert into public.inventory_accounting_entries (
    type,
    commerce_order_item_id,
    commerce_invoice_id,
    cost_amount,
    shipment_id,
    shipment_item_id,
    sell_price_amount,
    recipient_sell_price_amount,
    customer_group_id,
    billing_profile_id,
    status,
    tenant_id,
    inventory_item_id,
    product_id,
    quantity,
    total_cost_amount,
    total_sell_amount,
    gross_profit_amount
  )
  values (
    'commerce',
    v_order_item_id,
    p_invoice_id,
    v_resolved_cost,
    v_shipment_id,
    v_resolved_shipment_item_id,
    p_sell_price_bdt,
    p_recipient_price_bdt,
    v_cust_group_id,
    v_billing_profile_id,
    case when v_invoice_is_paid then 'paid'::text else 'due'::text end,
    v_resolved_tenant_id,
    p_inventory_item_id,
    p_product_id,
    (case when v_existing_id is not null then v_existing_qty + p_quantity else p_quantity end),
    (v_resolved_cost * (case when v_existing_id is not null then v_existing_qty + p_quantity else p_quantity end)),
    (p_sell_price_bdt * (case when v_existing_id is not null then v_existing_qty + p_quantity else p_quantity end)),
    ((p_sell_price_bdt - v_resolved_cost) * (case when v_existing_id is not null then v_existing_qty + p_quantity else p_quantity end))
  )
  on conflict (commerce_order_item_id) where (type = 'commerce')
  do update set
    cost_amount = excluded.cost_amount,
    inventory_item_id = excluded.inventory_item_id,
    shipment_id = excluded.shipment_id,
    shipment_item_id = excluded.shipment_item_id,
    commerce_invoice_id = excluded.commerce_invoice_id,
    sell_price_amount = excluded.sell_price_amount,
    recipient_sell_price_amount = excluded.recipient_sell_price_amount,
    customer_group_id = excluded.customer_group_id,
    billing_profile_id = excluded.billing_profile_id,
    status = excluded.status,
    tenant_id = excluded.tenant_id,
    product_id = excluded.product_id,
    quantity = excluded.quantity,
    total_cost_amount = excluded.total_cost_amount,
    total_sell_amount = excluded.total_sell_amount,
    gross_profit_amount = excluded.gross_profit_amount,
    updated_at = now();

  -- Sync Invoice Totals
  select coalesce(sum(quantity * recipient_price_bdt), 0)
  into v_subtotal
  from public.commerce_order_items
  where invoice_id = p_invoice_id;

  v_delivery_charge := coalesce(v_delivery_charge, 0);
  v_wrapping_charge := coalesce(v_wrapping_charge, 0);
  v_cod := coalesce(v_cod, 0);
  v_discount_amount := coalesce(v_discount_amount, 0);
  v_amount_paid := coalesce(v_amount_paid, 0);

  if v_is_delivery_charge_inclusive then
    v_total_amount := greatest(0, v_subtotal - v_discount_amount);
  else
    v_total_amount := greatest(0, v_subtotal + v_delivery_charge - v_discount_amount);
  end if;

  v_amount_due := greatest(0, v_total_amount - v_amount_paid);
  v_new_is_paid := v_amount_paid >= v_total_amount;

  update public.commerce_invoices
  set total_amount = v_total_amount,
      amount_due = v_amount_due,
      is_customer_group_paid = v_new_is_paid
  where id = p_invoice_id;

  if p_order_id is not null then
    update public.commerce_orders
    set delivery_charge = v_delivery_charge,
        wrapping_charge = v_wrapping_charge,
        cod = v_cod,
        shipment_payment = v_total_amount
    where id = p_order_id;
  end if;
end;
$$;

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
