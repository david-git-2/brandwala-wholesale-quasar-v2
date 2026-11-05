CREATE FUNCTION public.mark_thrift_items_as_sold (
  p_tenant_id                bigint,
  p_invoice_number           text,
  p_recipient_name           text,
  p_address                  text,
  p_phone                    text,
  p_transaction_method       public.thrift_transaction_method,
  p_cod_charge               numeric,
  p_packing_charge           numeric,
  p_invoice_print_charge     numeric,
  p_shipping_charge_customer numeric,
  p_inserted_by              text,
  p_items                    jsonb
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_invoice_id bigint;
  v_item jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_sold_price numeric(12,2);
  v_platform_fees numeric(12,2);
  v_ship_paid_by_shop numeric(12,2);
  v_available_qty integer;
  v_total_ship_paid_by_shop numeric(12,2) := 0.00;
begin
  -- 1. Insert Invoice
  insert into public.thrift_invoices (
    tenant_id,
    invoice_number,
    recipient_name,
    address,
    phone,
    transaction_method,
    cod_charge,
    packing_charge,
    invoice_print_charge,
    shipping_charge_customer,
    inserted_by
  )
  values (
    p_tenant_id,
    p_invoice_number,
    p_recipient_name,
    p_address,
    p_phone,
    p_transaction_method,
    p_cod_charge,
    p_packing_charge,
    p_invoice_print_charge,
    p_shipping_charge_customer,
    p_inserted_by
  )
  returning id into v_invoice_id;

  -- 2. Process items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_stock_id := (v_item->>'stock_id')::bigint;
    v_qty := (v_item->>'quantity')::integer;
    v_sold_price := (v_item->>'sold_price')::numeric;
    v_platform_fees := coalesce((v_item->>'platform_fees')::numeric, 0.00);
    v_ship_paid_by_shop := coalesce((v_item->>'shipping_cost_paid_by_shop')::numeric, 0.00);

    v_total_ship_paid_by_shop := v_total_ship_paid_by_shop + v_ship_paid_by_shop;

    -- Qty validation
    select quantity into v_available_qty
    from public.thrift_stocks
    where id = v_stock_id and tenant_id = p_tenant_id;

    if v_available_qty < v_qty then
      raise exception 'Insufficient stock for stock ID %', v_stock_id;
    end if;

    -- Add item to invoice
    insert into public.thrift_invoice_items (
      invoice_id,
      stock_id,
      quantity,
      sold_price,
      platform_fees,
      shipping_cost_paid_by_shop,
      item_status
    )
    values (
      v_invoice_id,
      v_stock_id,
      v_qty,
      v_sold_price,
      v_platform_fees,
      v_ship_paid_by_shop,
      'SOLD'::public.thrift_item_status
    );

    -- Deduct stock qty
    update public.thrift_stocks
    set 
      quantity = quantity - v_qty,
      status = case when (quantity - v_qty) = 0 then 'OUT_OF_STOCK'::public.thrift_stock_status else status end,
      updated_at = now()
    where id = v_stock_id;
  end loop;

  -- 3. Log Revenue (accrual basis)
  insert into public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    inserted_by,
    note
  )
  select 
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    total_invoice_amount,
    p_inserted_by,
    'Auto-logged revenue from Thrift Invoice #' || invoice_number
  from public.thrift_invoices
  where id = v_invoice_id;

  -- 4. Log Shipping Expense (if applicable)
  if v_total_ship_paid_by_shop > 0 then
    insert into public.thrift_accounting_ledger (
      tenant_id,
      type,
      source,
      reference_id,
      amount,
      inserted_by,
      note
    )
    values (
      p_tenant_id,
      'EXPENSE'::public.thrift_ledger_type,
      'INVOICE'::public.thrift_ledger_source,
      v_invoice_id,
      v_total_ship_paid_by_shop,
      p_inserted_by,
      'Auto-logged shipping cost absorbed by shop for Invoice #' || p_invoice_number
    );
  end if;

  return v_invoice_id;
end;
$function$;

COMMENT ON FUNCTION public.mark_thrift_items_as_sold(bigint,text,text,text,text,public.thrift_transaction_method,numeric,numeric,numeric,numeric,text,jsonb) IS
  'LEGACY ARCHIVE — execute revoked (P21). Use create_thrift_sales_invoice.';

GRANT ALL ON FUNCTION public.mark_thrift_items_as_sold(bigint, text, text, text, text, public.thrift_transaction_method, numeric, numeric, numeric, numeric, text, jsonb) TO anon;

GRANT ALL ON FUNCTION public.mark_thrift_items_as_sold(bigint, text, text, text, text, public.thrift_transaction_method, numeric, numeric, numeric, numeric, text, jsonb) TO
  authenticated;

GRANT ALL ON FUNCTION public.mark_thrift_items_as_sold(bigint, text, text, text, text, public.thrift_transaction_method, numeric, numeric, numeric, numeric, text, jsonb) TO
  service_role;