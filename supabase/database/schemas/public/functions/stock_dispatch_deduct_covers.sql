CREATE FUNCTION public.stock_dispatch_deduct_covers (
  p_delivery_paper_id bigint,
  p_stock_id          bigint,
  p_qty               integer
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.stock_movement_lines sml
    INNER JOIN public.stock_movements sm ON sm.id = sml.movement_id
    WHERE sm.reference_type = 'delivery_paper'
      AND sm.reference_id = p_delivery_paper_id::text
      AND sm.movement_type = 'issue_outbound'::public.stock_movement_type
      AND sm.is_posted = true
      AND sml.stock_id = p_stock_id
      AND coalesce(sml.quantity::integer, 0) >= p_qty
  );
$function$;

GRANT ALL ON FUNCTION public.stock_dispatch_deduct_covers(bigint, bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.stock_dispatch_deduct_covers(bigint, bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.stock_dispatch_deduct_covers(bigint, bigint, integer) TO service_role;