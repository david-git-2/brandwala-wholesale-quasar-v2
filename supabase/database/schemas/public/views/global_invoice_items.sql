CREATE VIEW public.global_invoice_items WITH (security_invoker=false) AS SELECT id,
    parent_tenant_id AS tenant_id,
    parent_tenant_id,
    invoice_id,
    (((line_meta -> 'stock_ref'::text) ->> 'global_stock_id'::text))::bigint AS global_stock_id,
    shipment_item_id,
    product_id,
    name_snapshot,
    barcode_snapshot,
    product_code_snapshot,
    quantity,
    sell_price_amount,
    line_discount_amount,
    line_total_amount,
    return_quantity,
    created_at,
    updated_at,
    assigned_child_tenant_id,
    line_meta,
    line_kind,
    currency_code,
    books_amount
   FROM public.bill_lines;

GRANT ALL ON public.global_invoice_items TO anon;

GRANT ALL ON public.global_invoice_items TO authenticated;

GRANT ALL ON public.global_invoice_items TO service_role;