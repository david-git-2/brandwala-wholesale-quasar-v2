CREATE VIEW public.global_return_items WITH (security_invoker=false) AS SELECT id,
    parent_tenant_id,
    parent_tenant_id AS tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
    return_charge_amount,
    note,
    created_at,
    updated_at
   FROM public.sales_return_items;

GRANT ALL ON public.global_return_items TO anon;

GRANT ALL ON public.global_return_items TO authenticated;

GRANT ALL ON public.global_return_items TO service_role;