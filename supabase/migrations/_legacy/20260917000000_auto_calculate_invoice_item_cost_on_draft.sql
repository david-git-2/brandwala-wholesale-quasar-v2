begin;

-- =========================================================
-- Redefine add_global_invoice_item to calculate landed unit cost
-- =========================================================
create or replace function public.add_global_invoice_item(
  p_invoice_id bigint,
  p_global_stock_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_recipient_price_amount numeric default 0,
  p_line_discount_amount numeric default 0
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
  v_recipient_price numeric;
  v_line_total numeric;
  v_line_face_total numeric;
  v_product_id bigint;
  v_unit_cost numeric;
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

  -- Load item details from global_shipment_items including product_id
  select name, barcode, product_code, product_id
  into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  -- Resolve recipient price
  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    v_recipient_price := coalesce(p_recipient_price_amount, 0.00);
  else
    v_recipient_price := p_sell_price_amount;
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(p_line_discount_amount, 0.00), 0.00);
  v_line_face_total := greatest((p_quantity * v_recipient_price) - coalesce(p_line_discount_amount, 0.00), 0.00);

  -- Auto calculate landed unit cost from shipment
  v_unit_cost := coalesce(public.calculate_landed_unit_cost(v_stock.shipment_item_id), 0.00);

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
    recipient_price_amount,
    line_discount_amount,
    line_total_amount,
    line_face_total_amount,
    return_quantity
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_global_stock_id,
    v_stock.shipment_item_id,
    v_product_id,
    v_name_snapshot,
    v_barcode_snapshot,
    v_product_code_snapshot,
    p_quantity,
    v_unit_cost,
    p_sell_price_amount,
    v_recipient_price,
    coalesce(p_line_discount_amount, 0.00),
    v_line_total,
    v_line_face_total,
    0.00
  )
  returning * into v_row;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric, numeric) to authenticated;

-- =========================================================
-- Redefine unpost_global_invoice to recalculate landed unit cost
-- =========================================================
create or replace function public.unpost_global_invoice(
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
  v_qty_to_restore integer;
  v_unit_cost numeric;
begin
  -- Load and lock invoice
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'only posted invoices can be unposted';
  end if;
  
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot unpost a paid or partially paid invoice; reverse collections/payments first';
  end if;

  if exists (select 1 from public.global_return_items where invoice_id = p_invoice_id) then
    raise exception 'cannot unpost an invoice with return items; remove return items first';
  end if;

  -- Restore stock quantities
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_qty_to_restore := ceil(v_item.quantity)::integer;
    
    update public.global_stocks
    set quantity = quantity + v_qty_to_restore
    where id = v_item.global_stock_id;
    
    if exists (
      select 1 from public.global_stock_allocations
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id
    ) then
      update public.global_stock_allocations
      set quantity = quantity + v_qty_to_restore
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id;
    end if;

    -- Update/recalculate unit cost price instead of resetting to 0.00 since it is back to draft
    v_unit_cost := coalesce(public.calculate_landed_unit_cost(v_item.shipment_item_id), 0.00);
    
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  -- Mark invoice as draft
  update public.global_invoices
  set
    invoice_status = 'draft'::public.global_invoice_status
  where id = p_invoice_id;

  -- Recompute totals
  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$$;

-- Backfill existing draft invoice items' unit_cost_price from their shipments
update public.global_invoice_items gii
set unit_cost_price = coalesce(public.calculate_landed_unit_cost(gii.shipment_item_id), 0.00)
from public.global_invoices gi
where gii.invoice_id = gi.id
  and gi.invoice_status = 'draft'::public.global_invoice_status;

commit;
