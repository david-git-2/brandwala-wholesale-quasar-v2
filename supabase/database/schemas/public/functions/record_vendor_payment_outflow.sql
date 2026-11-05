CREATE FUNCTION public.record_vendor_payment_outflow (
  p_tenant_id      bigint,
  p_vendor_id      bigint,
  p_amount         numeric,
  p_payment_method text    DEFAULT 'bank_transfer'::text,
  p_reference      text    DEFAULT NULL::text,
  p_note           text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_payment_id text;
  v_vendor_res jsonb;
  v_tenant_res jsonb;
begin
  if p_tenant_id is null or p_vendor_id is null then
    raise exception 'Tenant ID and Vendor ID are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Vendor payment amount must be positive.';
  end if;

  v_payment_id := 'VP-' || gen_random_uuid()::text;

  -- Leg 1: Debit Vendor AP (reduces vendor payable balance)
  v_vendor_res := public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'vendor',
    p_entity_id => p_vendor_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => v_payment_id,
    p_metadata => jsonb_build_object(
      'section', 'vendor_payments',
      'purpose', 'vendor_ap_settlement',
      'transaction_type', 'vendor_payment_paid',
      'label', 'Vendor Payment Settled',
      'payment_method', p_payment_method,
      'reference', p_reference,
      'notes', p_note
    )
  );

  -- Leg 2: Debit Tenant Cash (cash outflow from bank/cash account)
  v_tenant_res := public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => v_payment_id,
    p_metadata => jsonb_build_object(
      'section', 'vendor_payments',
      'purpose', 'tenant_vendor_cash_outflow',
      'transaction_type', 'vendor_payment_paid',
      'label', 'Cash Outflow (Vendor Payment)',
      'vendor_id', p_vendor_id,
      'payment_method', p_payment_method,
      'reference', p_reference,
      'notes', p_note
    )
  );

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'vendor_entry', v_vendor_res,
    'tenant_entry', v_tenant_res
  );
end;
$function$;

GRANT ALL ON FUNCTION public.record_vendor_payment_outflow(bigint, bigint, numeric, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.record_vendor_payment_outflow(bigint, bigint, numeric, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.record_vendor_payment_outflow(bigint, bigint, numeric, text, text, text) TO service_role;