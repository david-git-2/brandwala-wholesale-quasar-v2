CREATE FUNCTION public.preorder_demand_invoice_items_stale (
  p_document_type text,
  p_document_id   bigint,
  p_invoice_id    bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SET search_path TO 'public'
  AS $function$
  with expected as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'global_stock_id', (elem->>'global_stock_id')::bigint,
          'quantity', (elem->>'quantity')::numeric,
          'sell_price_amount', (elem->>'sell_price_amount')::numeric(12,2)
        )
        order by (elem->>'global_stock_id')::bigint, (elem->>'quantity')::numeric, (elem->>'sell_price_amount')::numeric
      ),
      '[]'::jsonb
    ) as sig
    from jsonb_array_elements(public.build_preorder_demand_invoice_items(p_document_type, p_document_id)) as elem
  ),
  actual as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'global_stock_id', sii.global_stock_id,
          'quantity', sii.quantity,
          'sell_price_amount', sii.sell_price_amount
        )
        order by sii.global_stock_id, sii.quantity, sii.sell_price_amount
      ),
      '[]'::jsonb
    ) as sig
    from public.bill_lines sii
    where sii.invoice_id = p_invoice_id
  )
  select
    p_invoice_id is not null
    and (select sig from expected) is distinct from (select sig from actual);
$function$;

GRANT ALL ON FUNCTION public.preorder_demand_invoice_items_stale(text, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.preorder_demand_invoice_items_stale(text, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.preorder_demand_invoice_items_stale(text, bigint, bigint) TO service_role;