CREATE FUNCTION public.record_recipient_invoice_collection (
  p_global_invoice_id bigint,
  p_amount            numeric,
  p_payment_date      date    DEFAULT NULL::date,
  p_method            text    DEFAULT 'cash'::text,
  p_reference         text    DEFAULT NULL::text,
  p_note              text    DEFAULT NULL::text
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_invoice public.bills;
  v_payment_id bigint;
begin
  select * into v_invoice from public.bills where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

  insert into public.pays (
    tenant_id,
    profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_invoice.parent_tenant_id,
    null,
    'recipient'::public.collection_source_type,
    p_amount,
    0.00,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    nullif(trim(p_note), '')
  )
  returning id into v_payment_id;

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.parent_tenant_id, v_payment_id, p_global_invoice_id, p_amount);

  update public.bills
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  -- Record Tenant Cash Credit for direct cash collection
  perform public.record_ledger_transaction(
    p_tenant_id => v_invoice.parent_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_invoice.parent_tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => p_global_invoice_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'recipient_cash_collection',
      'transaction_type', 'cash_collected',
      'label', 'Direct Cash Collection',
      'payment_id', v_payment_id,
      'invoice_id', p_global_invoice_id,
      'invoice_no', v_invoice.invoice_no
    )
  );

  return v_invoice;
end;
$function$;

GRANT ALL ON FUNCTION public.record_recipient_invoice_collection(bigint, numeric, date, text, text, text) TO anon;

GRANT ALL ON FUNCTION public.record_recipient_invoice_collection(bigint, numeric, date, text, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.record_recipient_invoice_collection(bigint, numeric, date, text, text, text) TO service_role;