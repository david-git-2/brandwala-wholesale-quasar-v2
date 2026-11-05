CREATE FUNCTION public._kernel_bounce_cheque_instrument_partial (
  p_tenant_id     bigint,
  p_instrument_id bigint,
  p_reason        text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_inst public.pay_instruments;
  v_pay public.pays;
  v_parent_id bigint;
  v_slice numeric(12, 2);
  v_unwound numeric(12, 2);
  v_total_alloc numeric(12, 2);
  v_pot_id bigint;
  v_point_id bigint;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_inst from public.pay_instruments where id = p_instrument_id for update;
  select * into v_pay from public.pays where id = v_inst.payment_id for update;

  v_slice := round(coalesce(v_inst.amount, 0), 2);
  if v_slice <= 0 then
    raise exception 'Cheque instrument amount must be greater than zero.';
  end if;

  update public.pay_instruments
  set bounced_at = now()
  where id = v_inst.id;

  v_unwound := public._kernel_unwind_pay_settlements_up_to(v_pay.id, v_slice);

  v_point_id := coalesce(v_inst.cashbook_point_id, v_pay.cashbook_point_id);
  v_pot_id := public._kernel_ensure_cashbook_point_pot(
    v_parent_id,
    v_point_id,
    coalesce(nullif(trim(v_pay.source_currency_code), ''), 'BDT')
  );

  if v_pay.source in ('customer_cash', 'bank', 'courier_remittance') then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'debit',
      p_amount => case
        when coalesce(v_pay.source_currency_code, 'BDT') <> 'BDT'
          then round(v_slice / coalesce(nullif(v_pay.transaction_rate, 0), 1), 2)
        else v_slice
      end,
      p_currency_code => coalesce(nullif(trim(v_pay.source_currency_code), ''), 'BDT'),
      p_exchange_rate => coalesce(v_pay.transaction_rate, 1.000000),
      p_source_type => case
        when v_pay.source = 'courier_remittance' then 'shop_order'
        else 'sales_invoice'
      end,
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'cheque_bounce_partial',
        'transaction_type', 'cheque_bounced',
        'label', 'Cheque bounced (partial)',
        'payment_id', v_pay.id,
        'instrument_id', v_inst.id,
        'reason', p_reason,
        'cashbook_point_pot_id', v_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => v_point_id
    );
  else
    raise exception 'Partial cheque bounce not supported for payment source %.', v_pay.source;
  end if;

  select coalesce(sum(pa.amount), 0.00) into v_total_alloc
  from public.pay_allocations pa
  where pa.payment_id = v_pay.id;

  update public.pays
  set
    amount = greatest(coalesce(amount, 0) - v_slice, 0),
    unallocated_amount = greatest(coalesce(amount, 0) - v_slice - v_total_alloc, 0),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[CHEQUE BOUNCED] ' || p_reason
    )
  where id = v_pay.id;

  return jsonb_build_object(
    'success', true,
    'partial', true,
    'payment_id', v_pay.id,
    'instrument_id', v_inst.id,
    'books_unwound', v_unwound,
    'slice_amount', v_slice
  );
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_bounce_cheque_instrument_partial(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public._kernel_bounce_cheque_instrument_partial(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_bounce_cheque_instrument_partial(bigint, bigint, text) TO service_role;