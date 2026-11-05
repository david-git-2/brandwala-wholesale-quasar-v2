CREATE FUNCTION public.record_vendor_grn_payable (
  p_tenant_id bigint,
  p_vendor_id bigint,
  p_amount    numeric,
  p_source_id text,
  p_metadata  jsonb   DEFAULT '{}'::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_res jsonb;
begin
  if p_tenant_id is null or p_vendor_id is null then
    raise exception 'Tenant ID and Vendor ID are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'GRN payable amount must be positive.';
  end if;

  v_res := public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'vendor',
    p_entity_id => p_vendor_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => p_source_id,
    p_metadata => jsonb_build_object(
      'section', 'procurement',
      'purpose', 'vendor_grn_payable',
      'transaction_type', 'vendor_payable',
      'label', 'Vendor Payable (GRN Received)'
    ) || coalesce(p_metadata, '{}'::jsonb)
  );

  return jsonb_build_object('success', true, 'entry', v_res);
end;
$function$;

GRANT ALL ON FUNCTION public.record_vendor_grn_payable(bigint, bigint, numeric, text, jsonb) TO anon;

GRANT ALL ON FUNCTION public.record_vendor_grn_payable(bigint, bigint, numeric, text, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.record_vendor_grn_payable(bigint, bigint, numeric, text, jsonb) TO service_role;