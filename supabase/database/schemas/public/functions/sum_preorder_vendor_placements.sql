CREATE FUNCTION public.sum_preorder_vendor_placements (
  p_placements jsonb
)
  RETURNS integer
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT coalesce(
    sum(greatest(coalesce((elem->>'quantity')::integer, 0), 0)),
    0
  )::integer
  FROM jsonb_array_elements(coalesce(p_placements, '[]'::jsonb)) elem;
$function$;

GRANT ALL ON FUNCTION public.sum_preorder_vendor_placements(jsonb) TO anon;

GRANT ALL ON FUNCTION public.sum_preorder_vendor_placements(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.sum_preorder_vendor_placements(jsonb) TO service_role;