CREATE FUNCTION public.delivery_paper_line_packed_qty (
  p_splits jsonb
)
  RETURNS integer
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT coalesce(sum(greatest(0, (elem->>'quantity')::integer)), 0)::integer
  FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb)) AS elem
  WHERE lower(trim(coalesce(elem->>'status', ''))) = 'packed';
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_packed_qty(jsonb) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_packed_qty(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_packed_qty(jsonb) TO service_role;