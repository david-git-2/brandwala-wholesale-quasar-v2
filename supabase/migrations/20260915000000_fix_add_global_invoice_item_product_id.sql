-- Fix add_global_invoice_item to retrieve product_id from global_shipment_items instead of global_stocks
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
    0.00, -- Populated on post only
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
