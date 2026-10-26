-- Migration: Fix Commerce Accounting Shipment and Invoice Linking
begin;

-- 1. Redefine trg_fn_commerce_accounting_instead_of trigger function
create or replace function public.trg_fn_commerce_accounting_instead_of()
returns trigger
language plpgsql
security definer
as $$
declare
  v_quantity integer;
  v_product_id bigint;
  v_invoice_id bigint;
  v_shipment_id bigint;
begin
  if tg_op = 'INSERT' then
    -- Resolve quantity and parent product id/invoice/shipment
    select quantity, invoice_id into v_quantity, v_invoice_id
    from public.commerce_order_items
    where id = new.order_item_id;

    v_quantity := coalesce(v_quantity, 1);

    select product_id into v_product_id
    from public.inventory_items
    where id = new.inventory_item_id;

    if new.shipment_item_id is not null then
      select shipment_id into v_shipment_id
      from public.shipment_items
      where id = new.shipment_item_id;
    end if;

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
      gross_profit_amount,
      created_at,
      updated_at
    )
    values (
      'commerce',
      new.order_item_id,
      v_invoice_id,
      new.cost_bdt,
      v_shipment_id,
      new.shipment_item_id,
      new.sell_price_bdt,
      new.recipient_sell_price_bdt,
      new.customer_group_id,
      new.billing_profile_id,
      case when new.is_customer_group_paid then 'paid'::text else 'due'::text end,
      new.tenant_id,
      new.inventory_item_id,
      v_product_id,
      v_quantity,
      (new.cost_bdt * v_quantity),
      (new.sell_price_bdt * v_quantity),
      ((new.sell_price_bdt - new.cost_bdt) * v_quantity),
      coalesce(new.created_at, now()),
      coalesce(new.updated_at, now())
    )
    returning id into new.id;
    return new;

  elsif tg_op = 'UPDATE' then
    select quantity, invoice_id into v_quantity, v_invoice_id
    from public.commerce_order_items
    where id = new.order_item_id;

    v_quantity := coalesce(v_quantity, 1);

    select product_id into v_product_id
    from public.inventory_items
    where id = new.inventory_item_id;

    if new.shipment_item_id is not null then
      select shipment_id into v_shipment_id
      from public.shipment_items
      where id = new.shipment_item_id;
    end if;

    update public.inventory_accounting_entries
    set
      commerce_order_item_id = new.order_item_id,
      commerce_invoice_id = v_invoice_id,
      cost_amount = new.cost_bdt,
      shipment_id = v_shipment_id,
      shipment_item_id = new.shipment_item_id,
      sell_price_amount = new.sell_price_bdt,
      recipient_sell_price_amount = new.recipient_sell_price_bdt,
      customer_group_id = new.customer_group_id,
      billing_profile_id = new.billing_profile_id,
      status = case when new.is_customer_group_paid then 'paid'::text else 'due'::text end,
      tenant_id = new.tenant_id,
      inventory_item_id = new.inventory_item_id,
      product_id = v_product_id,
      quantity = v_quantity,
      total_cost_amount = (new.cost_bdt * v_quantity),
      total_sell_amount = (new.sell_price_bdt * v_quantity),
      gross_profit_amount = ((new.sell_price_bdt - new.cost_bdt) * v_quantity),
      updated_at = now()
    where id = old.id;
    return new;

  elsif tg_op = 'DELETE' then
    delete from public.inventory_accounting_entries
    where id = old.id;
    return old;
  end if;
end;
$$;

-- 2. Redefine create_commerce_invoice RPC
create or replace function public.create_commerce_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_delivery_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_total_amount numeric,
  p_amount_paid numeric,
  p_delivered_by text,
  p_billing_profile_id bigint default null,
  p_invoice_date date default current_date
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_id bigint;
  v_cust_group_id bigint;
  v_item record;
  v_is_paid boolean;
  v_product_id bigint;
  v_quantity integer;
  v_shipment_id bigint;
begin
  select tenant_id, customer_group_id into p_tenant_id, v_cust_group_id
  from public.commerce_orders
  where id = p_order_id;

  if p_tenant_id is null then
    raise exception 'Commerce order % not found.', p_order_id;
  end if;

  v_is_paid := coalesce(p_amount_paid, 0) >= coalesce(p_total_amount, 0);

  insert into public.commerce_invoices (
    order_id,
    delivery_charge,
    wrapping_charge,
    cod,
    total_amount,
    amount_paid,
    amount_due,
    is_customer_group_paid,
    delivered_by,
    tenant_id,
    billing_profile_id,
    invoice_date
  )
  values (
    p_order_id,
    coalesce(p_delivery_charge, 0),
    coalesce(p_wrapping_charge, 0),
    coalesce(p_cod, 0),
    coalesce(p_total_amount, 0),
    coalesce(p_amount_paid, 0),
    greatest(coalesce(p_total_amount, 0) - coalesce(p_amount_paid, 0), 0),
    v_is_paid,
    p_delivered_by,
    p_tenant_id,
    p_billing_profile_id,
    coalesce(p_invoice_date, current_date)
  )
  returning id into v_invoice_id;

  update public.commerce_orders
  set
    status = 'reviewing'::public.commerce_order_status,
    invoice_ids = array_append(coalesce(invoice_ids, '{}'::bigint[]), v_invoice_id)
  where id = p_order_id;

  update public.commerce_order_items
  set invoice_id = v_invoice_id
  where order_id = p_order_id;

  for v_item in (
    select
      coi.id,
      coi.cost_bdt,
      coi.sell_price_bdt,
      coi.recipient_price_bdt,
      coi.inventory_item_id,
      coi.shipment_item_id,
      coi.quantity,
      ii.tenant_id as inventory_tenant_id
    from public.commerce_order_items coi
    left join public.inventory_items ii on ii.id = coi.inventory_item_id
    where coi.order_id = p_order_id
  ) loop
    select product_id into v_product_id
    from public.inventory_items
    where id = v_item.inventory_item_id;

    v_quantity := coalesce(v_item.quantity, 1);

    v_shipment_id := null;
    if v_item.shipment_item_id is not null then
      select shipment_id into v_shipment_id
      from public.shipment_items
      where id = v_item.shipment_item_id;
    end if;

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
      v_item.id,
      v_invoice_id,
      coalesce(v_item.cost_bdt, 0),
      v_shipment_id,
      v_item.shipment_item_id,
      coalesce(v_item.sell_price_bdt, 0),
      coalesce(v_item.recipient_price_bdt, 0),
      v_cust_group_id,
      p_billing_profile_id,
      case when v_is_paid then 'paid'::text else 'due'::text end,
      coalesce(v_item.inventory_tenant_id, p_tenant_id),
      v_item.inventory_item_id,
      v_product_id,
      v_quantity,
      (coalesce(v_item.cost_bdt, 0) * v_quantity),
      (coalesce(v_item.sell_price_bdt, 0) * v_quantity),
      ((coalesce(v_item.sell_price_bdt, 0) - coalesce(v_item.cost_bdt, 0)) * v_quantity)
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
  end loop;

  return v_invoice_id;
end;
$$;

-- 3. Redefine add_commerce_invoice_item RPC
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
  v_shipment_id bigint;
  
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
begin
  -- Fetch commerce order context
  select tenant_id, customer_group_id, is_delivery_charge_inclusive
  into v_tenant_id, v_cust_group_id, v_is_delivery_charge_inclusive
  from public.commerce_orders
  where id = p_order_id;
  
  if v_tenant_id is null then
    raise exception 'Order not found.';
  end if;

  -- Fetch commerce invoice details
  select is_customer_group_paid, billing_profile_id, delivery_charge, wrapping_charge, cod, discount_amount, amount_paid
  into v_invoice_is_paid, v_billing_profile_id, v_delivery_charge, v_wrapping_charge, v_cod, v_discount_amount, v_amount_paid
  from public.commerce_invoices
  where id = p_invoice_id;

  if v_invoice_is_paid is null then
    raise exception 'Invoice not found.';
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

  -- Check if item already exists in commerce_order_items
  if p_inventory_item_id is not null then
    select id, quantity
    into v_existing_id, v_existing_qty
    from public.commerce_order_items
    where order_id = p_order_id
      and product_id = p_product_id
      and invoice_id = p_invoice_id
      and inventory_item_id = p_inventory_item_id
    limit 1;
  else
    select id, quantity
    into v_existing_id, v_existing_qty
    from public.commerce_order_items
    where order_id = p_order_id
      and product_id = p_product_id
      and invoice_id = p_invoice_id
      and inventory_item_id is null
    limit 1;
  end if;

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

  update public.commerce_orders
  set delivery_charge = v_delivery_charge,
      wrapping_charge = v_wrapping_charge,
      cod = v_cod,
      shipment_payment = v_total_amount
  where id = p_order_id;
end;
$$;

-- 4. Backfill existing commerce accounting records
update public.inventory_accounting_entries iae
set
  commerce_invoice_id = coi.invoice_id,
  shipment_id = si.shipment_id
from public.commerce_order_items coi
left join public.shipment_items si on si.id = coi.shipment_item_id
where iae.type = 'commerce'
  and iae.commerce_order_item_id = coi.id
  and (iae.commerce_invoice_id is null or iae.shipment_id is null);

commit;
