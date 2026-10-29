-- get_shipment_money_kernel_bundle calls sync_shipment_ap_bills (locks/writes); cannot be STABLE.

CREATE OR REPLACE FUNCTION public.get_shipment_money_kernel_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bundle jsonb;
  v_ap_bills jsonb;
  v_enriched jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_bundle := public.get_shipment_settings_finance_bundle(p_shipment_id);
  v_ap_bills := coalesce(v_bundle->'ap_bills', '[]'::jsonb);

  for v_elem in select value from jsonb_array_elements(v_ap_bills)
  loop
    v_bill_id := nullif(v_elem->>'id', '')::bigint;
    if v_bill_id is not null then
      v_enriched := v_enriched || jsonb_build_array(
        v_elem || jsonb_build_object('net_balances', public.get_bill_net_balances(v_bill_id))
      );
    else
      v_enriched := v_enriched || jsonb_build_array(v_elem);
    end if;
  end loop;

  return v_bundle
    || jsonb_build_object('ap_bills', v_enriched)
    || jsonb_build_object(
      'kernel',
      jsonb_build_object(
        'source_type', 'shipment_cost',
        'source_id', p_shipment_id::text,
        'pay_out_rpc', 'post_shipment_ap_money_out',
        'issue_rpc', 'issue_bill'
      )
    );
end;
$$;
