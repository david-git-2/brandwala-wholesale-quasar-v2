CREATE FUNCTION public.finalize_global_shipment (
  p_shipment_id bigint,
  p_stock_rows  jsonb  DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public.post_shipment_outcome_stock(p_shipment_id, p_stock_rows);
end;
$function$;

GRANT ALL ON FUNCTION public.finalize_global_shipment(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.finalize_global_shipment(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.finalize_global_shipment(bigint, jsonb) TO service_role;