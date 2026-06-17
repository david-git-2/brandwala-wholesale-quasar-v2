-- Migration: Fix add_invoice_item_transactional function product_id reference
begin;

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

  -- Retrieve product_id, source_type, and source_id from inventory_items
  if p_inventory_item_id is not null then
    select source_type, source_id, product_id into v_source_type, v_source_id, v_product_id
    from public.inventory_items
    where id = p_inventory_item_id;

    if v_source_type = 'shipment' then
      v_shipment_item_id := v_source_id;
      
      select shipment_id into v_shipment_id
      from public.shipment_items
      where id = v_shipment_item_id;
    end if;
  end if;

  -- Insert invoice item using v_product_id
  insert into public.invoice_items (
    tenant_id, invoice_id, source_item_type, source_item_id, inventory_item_id,
    product_id, name_snapshot, barcode_snapshot, product_code_snapshot,
    quantity, cost_amount, sell_price_amount, line_discount_amount,
    line_tax_amount, line_total_amount
  )
  values (
    p_tenant_id, p_invoice_id, p_source_item_type, p_source_item_id, p_inventory_item_id,
    v_product_id, p_name_snapshot, p_barcode_snapshot, p_product_code_snapshot,
    p_quantity, p_cost_amount, p_sell_price_amount, coalesce(p_line_discount_amount, 0),
    coalesce(p_line_tax_amount, 0), v_line_total
  )
  returning id into v_invoice_item_id;

  insert into public.inventory_accounting_entries (
    tenant_id, invoice_id, invoice_item_id, inventory_item_id, shipment_id, shipment_item_id,
    product_id, quantity, return_quantity, return_amount, cost_amount, sell_price_amount,
    total_cost_amount, total_sell_amount, gross_profit_amount, status, entry_date, note, created_by
  )
  values (
    p_tenant_id, p_invoice_id, v_invoice_item_id, p_inventory_item_id, v_shipment_id, v_shipment_item_id,
    v_product_id, p_quantity, 0, 0, p_cost_amount, p_sell_price_amount,
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

commit;
