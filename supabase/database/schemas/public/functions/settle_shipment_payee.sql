CREATE FUNCTION public.settle_shipment_payee (
  p_shipment_id   bigint,
  p_entity_type   text,
  p_entity_id     bigint,
  p_action        text,
  p_amount        numeric,
  p_exchange_rate numeric DEFAULT NULL::numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  raise exception
    'settle_shipment_payee is retired. Pay shipment AP via Finance → Payments: allocate to bucket bills using post_shipment_ap_money_out (kernel post_money_out). Shipment %.',
    p_shipment_id;
end;
$function$;

GRANT ALL ON FUNCTION public.settle_shipment_payee(bigint, text, bigint, text, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.settle_shipment_payee(bigint, text, bigint, text, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.settle_shipment_payee(bigint, text, bigint, text, numeric, numeric) TO service_role;