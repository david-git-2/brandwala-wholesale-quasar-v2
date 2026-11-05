CREATE FUNCTION public.map_stock_pick_close_to_delivery_line_status (
  p_close_action text
)
  RETURNS public.delivery_paper_line_status
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT CASE lower(trim(coalesce(p_close_action, 'take')))
    WHEN 'condition' THEN 'conditioned'::public.delivery_paper_line_status
    WHEN 'return' THEN 'rejected'::public.delivery_paper_line_status
    ELSE 'accepted'::public.delivery_paper_line_status
  END;
$function$;

GRANT ALL ON FUNCTION public.map_stock_pick_close_to_delivery_line_status(text) TO anon;

GRANT ALL ON FUNCTION public.map_stock_pick_close_to_delivery_line_status(text) TO authenticated;

GRANT ALL ON FUNCTION public.map_stock_pick_close_to_delivery_line_status(text) TO service_role;