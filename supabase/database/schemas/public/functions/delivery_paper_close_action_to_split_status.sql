CREATE FUNCTION public.delivery_paper_close_action_to_split_status (
  p_close_action text
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT CASE lower(trim(coalesce(p_close_action, '')))
    WHEN 'condition' THEN 'conditioned'
    WHEN 'return' THEN 'rejected'
    WHEN 'take' THEN 'accepted'
    ELSE 'packed'
  END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_close_action_to_split_status(text) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_close_action_to_split_status(text) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_close_action_to_split_status(text) TO service_role;