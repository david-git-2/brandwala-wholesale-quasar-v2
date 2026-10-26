-- Migration: Create RPC function create_thrift_sales_invoice
-- Description: Creates a thrift sales invoice, bulk inserts line items, marks stock as SOLD, and inserts a revenue entry in thrift_accounting_ledger atomically.

CREATE OR REPLACE FUNCTION public.create_thrift_sales_invoice(
  p_tenant_id BIGINT,
  p_invoice_number TEXT,
  p_customer_name TEXT DEFAULT NULL,
  p_customer_phone TEXT DEFAULT NULL,
  p_date TIMESTAMPTZ DEFAULT NOW(),
  p_payment_method TEXT DEFAULT 'CASH',
  p_payment_status TEXT DEFAULT 'PAID',
  p_notes TEXT DEFAULT NULL,
  p_created_by TEXT DEFAULT 'cashier',
  p_total_invoice_amount NUMERIC(12,2) DEFAULT 0.00,
  p_items JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_invoice_id BIGINT;
  v_item JSONB;
  v_stock_id BIGINT;
  v_sell_price NUMERIC(12,2);
  v_discount_amount NUMERIC(12,2);
  v_final_price NUMERIC(12,2);
  v_landed_unit_cost NUMERIC(12,2);
  v_quantity INT;
  v_net_profit NUMERIC(12,2);
BEGIN
  -- 1. Insert Sales Invoice Header
  INSERT INTO public.thrift_sales_invoices (
    tenant_id,
    invoice_number,
    customer_name,
    customer_phone,
    date,
    payment_method,
    payment_status,
    notes,
    created_by,
    total_invoice_amount
  ) VALUES (
    p_tenant_id,
    p_invoice_number,
    p_customer_name,
    p_customer_phone,
    p_date,
    p_payment_method,
    p_payment_status,
    p_notes,
    p_created_by,
    p_total_invoice_amount
  )
  RETURNING id INTO v_invoice_id;

  -- 2. Process items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    v_stock_id := (v_item->>'stock_id')::BIGINT;
    v_sell_price := COALESCE((v_item->>'sell_price')::NUMERIC(12,2), 0.00);
    v_discount_amount := COALESCE((v_item->>'discount_amount')::NUMERIC(12,2), 0.00);
    v_final_price := COALESCE((v_item->>'final_price')::NUMERIC(12,2), v_sell_price - v_discount_amount);
    v_landed_unit_cost := COALESCE((v_item->>'landed_unit_cost')::NUMERIC(12,2), 0.00);
    v_quantity := COALESCE((v_item->>'quantity')::INT, 1);
    v_net_profit := COALESCE((v_item->>'net_profit')::NUMERIC(12,2), (v_final_price - v_landed_unit_cost) * v_quantity);

    -- Insert line item
    INSERT INTO public.thrift_sales_invoice_items (
      tenant_id,
      invoice_id,
      stock_id,
      sell_price,
      discount_amount,
      final_price,
      landed_unit_cost_at_sale,
      quantity,
      net_profit
    ) VALUES (
      p_tenant_id,
      v_invoice_id,
      v_stock_id,
      v_sell_price,
      v_discount_amount,
      v_final_price,
      v_landed_unit_cost,
      v_quantity,
      v_net_profit
    );

    -- Update stock status to SOLD
    UPDATE public.thrift_stocks
    SET status = 'SOLD',
        quantity = GREATEST(0, quantity - v_quantity),
        updated_at = NOW()
    WHERE id = v_stock_id AND tenant_id = p_tenant_id;
  END LOOP;

  -- 3. Insert revenue entry in thrift_accounting_ledger
  INSERT INTO public.thrift_accounting_ledger (
    tenant_id,
    type,
    source,
    reference_id,
    amount,
    note,
    inserted_by,
    date
  ) VALUES (
    p_tenant_id,
    'REVENUE'::public.thrift_ledger_type,
    'INVOICE'::public.thrift_ledger_source,
    v_invoice_id,
    p_total_invoice_amount,
    'Sales Invoice #' || p_invoice_number,
    p_created_by,
    p_date
  );

  RETURN jsonb_build_object(
    'id', v_invoice_id,
    'invoice_number', p_invoice_number,
    'status', 'success'
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_thrift_sales_invoice TO service_role;
