CREATE FUNCTION public.shipment_ap_bucket_paid_totals (
  p_shipment_id bigint,
  p_ap_kind     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_bdt numeric := 0;
  v_foreign numeric := 0;
  v_count integer := 0;
  v_rate numeric := 1;
begin
  if p_shipment_id is null or nullif(trim(coalesce(p_ap_kind, '')), '') is null then
    return jsonb_build_object(
      'bdt_paid', 0,
      'foreign_paid', 0,
      'conversion_rate', 1,
      'payment_count', 0
    );
  end if;

  select
    coalesce(sum(round(pa.amount, 2)), 0),
    coalesce(sum(
      round(
        case
          when coalesce(p.exchange_rate, 0) > 0
               and upper(coalesce(p.settlement_currency_code, 'BDT')) <> 'BDT' then
            pa.amount / p.exchange_rate
          else pa.amount
        end,
        2
      )
    ), 0),
    count(distinct p.id)::integer
  into v_bdt, v_foreign, v_count
  from public.bills b
  inner join public.pay_allocations pa on pa.global_invoice_id = b.id
  inner join public.pays p on p.id = pa.payment_id
  where b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.ap_kind = p_ap_kind
    and p.voided_at is null;

  if v_foreign > 0 then
    v_rate := round(v_bdt / v_foreign, 6);
  end if;

  return jsonb_build_object(
    'bdt_paid', v_bdt,
    'foreign_paid', v_foreign,
    'conversion_rate', v_rate,
    'payment_count', v_count
  );
end;
$function$;

GRANT ALL ON FUNCTION public.shipment_ap_bucket_paid_totals(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.shipment_ap_bucket_paid_totals(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.shipment_ap_bucket_paid_totals(bigint, text) TO service_role;