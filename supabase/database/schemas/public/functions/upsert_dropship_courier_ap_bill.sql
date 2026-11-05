CREATE FUNCTION public.upsert_dropship_courier_ap_bill (
  p_order_id      bigint,
  p_keep_as_draft boolean DEFAULT false
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public._kernel_upsert_dropship_courier_ap(p_order_id, p_keep_as_draft);
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_dropship_courier_ap_bill(bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.upsert_dropship_courier_ap_bill(bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_dropship_courier_ap_bill(bigint, boolean) TO service_role;