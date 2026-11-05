CREATE FUNCTION public.delivery_paper_dispatch_movement_id (
  p_delivery_paper_id bigint
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  SELECT sm.id
  FROM public.stock_movements sm
  WHERE sm.reference_type = 'delivery_paper'
    AND sm.reference_id = p_delivery_paper_id::text
    AND sm.movement_type = 'issue_outbound'::public.stock_movement_type
    AND sm.is_posted = true
  ORDER BY sm.id DESC
  LIMIT 1;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_dispatch_movement_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_dispatch_movement_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_dispatch_movement_id(bigint) TO service_role;