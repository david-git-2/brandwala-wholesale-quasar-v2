CREATE FUNCTION public._bill_line_global_stock_id (
  p_line public.bill_lines
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT nullif(p_line.line_meta->'stock_ref'->>'global_stock_id', '')::bigint;
$function$;

GRANT ALL ON FUNCTION public._bill_line_global_stock_id(public.bill_lines) TO anon;

GRANT ALL ON FUNCTION public._bill_line_global_stock_id(public.bill_lines) TO authenticated;

GRANT ALL ON FUNCTION public._bill_line_global_stock_id(public.bill_lines) TO service_role;