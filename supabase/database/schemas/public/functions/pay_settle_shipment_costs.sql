CREATE FUNCTION public.pay_settle_shipment_costs (
  p_shipment_id    bigint,
  p_cost_entry_ids bigint[] DEFAULT NULL::bigint[]
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  raise exception 'pay_settle_shipment_costs is retired; use sync_shipment_ap_bills and post_ap_payout_with_allocations';
end;
$function$;

GRANT ALL ON FUNCTION public.pay_settle_shipment_costs(bigint, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.pay_settle_shipment_costs(bigint, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.pay_settle_shipment_costs(bigint, bigint[]) TO service_role;