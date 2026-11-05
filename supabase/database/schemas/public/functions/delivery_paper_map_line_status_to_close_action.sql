CREATE FUNCTION public.delivery_paper_map_line_status_to_close_action (
  p_status public.delivery_paper_line_status
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT CASE p_status
    WHEN 'conditioned'::public.delivery_paper_line_status THEN 'condition'
    WHEN 'rejected'::public.delivery_paper_line_status THEN 'return'
    WHEN 'accepted'::public.delivery_paper_line_status THEN 'take'
    ELSE null
  END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_map_line_status_to_close_action(public.delivery_paper_line_status) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_map_line_status_to_close_action(public.delivery_paper_line_status) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_map_line_status_to_close_action(public.delivery_paper_line_status) TO service_role;