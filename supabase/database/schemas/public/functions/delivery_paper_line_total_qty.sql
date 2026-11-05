CREATE FUNCTION public.delivery_paper_line_total_qty (
  p_splits jsonb
)
  RETURNS integer
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT coalesce(sum(greatest(0, (elem->>'quantity')::integer)), 0)::integer
  FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb)) AS elem;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_total_qty(jsonb) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_total_qty(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_total_qty(jsonb) TO service_role;