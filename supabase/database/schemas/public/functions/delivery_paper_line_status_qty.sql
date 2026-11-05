CREATE FUNCTION public.delivery_paper_line_status_qty (
  p_splits jsonb,
  p_status text
)
  RETURNS integer
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT coalesce(sum(greatest(0, (elem->>'quantity')::integer)), 0)::integer
  FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb)) AS elem
  WHERE lower(trim(coalesce(elem->>'status', ''))) = lower(trim(coalesce(p_status, '')));
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_status_qty(jsonb, text) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_status_qty(jsonb, text) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_status_qty(jsonb, text) TO service_role;