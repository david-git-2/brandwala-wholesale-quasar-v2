CREATE FUNCTION public.delivery_paper_line_resolvable_bill_stock_id (
  p_line public.delivery_paper_line
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT CASE
    WHEN p_line.global_stock_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.global_stocks gs WHERE gs.id = p_line.global_stock_id
      ) THEN p_line.global_stock_id
    WHEN p_line.dispatched_global_stock_id IS NOT NULL
      AND p_line.dispatched_global_stock_id > 0
      AND EXISTS (
        SELECT 1 FROM public.global_stocks gs WHERE gs.id = p_line.dispatched_global_stock_id
      ) THEN p_line.dispatched_global_stock_id
    ELSE NULL::bigint
  END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_resolvable_bill_stock_id(public.delivery_paper_line) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_resolvable_bill_stock_id(public.delivery_paper_line) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_resolvable_bill_stock_id(public.delivery_paper_line) TO service_role;
