CREATE FUNCTION public.set_global_shipment_progress_tag (
  p_shipment_id bigint,
  p_tag_id      bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public.set_shipment_progress_stage(p_shipment_id, p_tag_id);
end;
$function$;

GRANT ALL ON FUNCTION public.set_global_shipment_progress_tag(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.set_global_shipment_progress_tag(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.set_global_shipment_progress_tag(bigint, bigint) TO service_role;