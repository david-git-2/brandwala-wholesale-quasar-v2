CREATE FUNCTION public.issue_shipment_ap_bill_for_kind (
  p_shipment_id bigint,
  p_ap_kind     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  raise exception 'issue_shipment_ap_bill_for_kind is retired. Use lock_global_shipment_costs on shipment % to sync and issue all AP bills.',
    p_shipment_id;
end;
$function$;

GRANT ALL ON FUNCTION public.issue_shipment_ap_bill_for_kind(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.issue_shipment_ap_bill_for_kind(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.issue_shipment_ap_bill_for_kind(bigint, text) TO service_role;