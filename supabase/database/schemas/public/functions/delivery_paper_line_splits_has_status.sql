CREATE FUNCTION public.delivery_paper_line_splits_has_status (
  p_splits jsonb,
  p_status text
)
  RETURNS boolean
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM jsonb_array_elements(coalesce(p_splits, '[]'::jsonb)) elem(value)
    WHERE lower(trim(elem.value->>'status')) = lower(trim(p_status))
  );
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_line_splits_has_status(jsonb, text) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_line_splits_has_status(jsonb, text) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_line_splits_has_status(jsonb, text) TO service_role;