CREATE FUNCTION public._kernel_reverse_payment (
  p_tenant_id  bigint,
  p_payment_id bigint,
  p_reason     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_payment public.pays;
  v_parent_id bigint;
  v_bill_id bigint;
  v_bill_ids bigint[] := '{}';
  v_leftover numeric(12, 2);
  v_reason text;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_cashbook_point_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null then
    raise exception 'Tenant and payment are required.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required to void a payment.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_payment
  from public.pays
  where id = p_payment_id
    and tenant_id = v_parent_id
  for update;

  if v_payment.id is null then
    raise exception 'Payment not found.';
  end if;

  if v_payment.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  if coalesce(v_payment.method, '') = 'wallet_credit' then
    raise exception 'Store-credit application receipts cannot be voided from this screen.';
  end if;

  if v_payment.source = 'store_credit' then
    raise exception 'Store-credit application payments cannot be voided here.';
  end if;

  select coalesce(array_agg(distinct x.bid), '{}')
  into v_bill_ids
  from (
    select coalesce(pa.bill_id, pa.global_invoice_id) as bid
    from public.pay_allocations pa
    where pa.payment_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    where bs.allocator_kind = 'pay'
      and bs.allocator_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    join public.pay_allocations pa on pa.id = bs.pay_allocation_id
    where pa.payment_id = v_payment.id
  ) x
  where x.bid is not null;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public._kernel_lock_bills(array[v_bill_id]);
    select b.ap_shipment_id into v_sid
    from public.bills b
    where b.id = v_bill_id and b.ap_shipment_id is not null;
    if v_sid is not null and not (v_sid = any(v_shipment_ids)) then
      v_shipment_ids := array_append(v_shipment_ids, v_sid);
    end if;
  end loop;

  delete from public.bill_settlements bs
  where bs.pay_allocation_id in (
    select pa.id from public.pay_allocations pa where pa.payment_id = v_payment.id
  );

  delete from public.bill_settlements bs
  where bs.allocator_kind = 'pay'
    and bs.allocator_id = v_payment.id;

  delete from public.pay_allocations
  where payment_id = v_payment.id;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public.recompute_global_invoice_payment_status(v_bill_id);
  end loop;

  v_leftover := coalesce(v_payment.unallocated_amount, 0.00);

  if v_payment.source = 'ap_payout' then
    select pi.cashbook_point_id into v_cashbook_point_id
    from public.pay_instruments pi
    where pi.payment_id = v_payment.id
    order by pi.sort_order, pi.id
    limit 1;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => coalesce(v_payment.tenant_id, p_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_ap_payout',
        'transaction_type', 'ap_payout_reversal',
        'label', 'Void AP payout',
        'payment_id', v_payment.id,
        'reason', v_reason,
        'cashbook_point_pot_id', v_payment.cashbook_point_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => coalesce(v_cashbook_point_id, v_payment.cashbook_point_id)
    );
  elsif v_payment.source = 'commission' then
    v_cashbook_point_id := coalesce(v_payment.cashbook_point_id, v_cashbook_point_id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => coalesce(v_payment.tenant_id, p_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_commission_payout',
        'transaction_type', 'profit_paid_out_reversal',
        'label', 'Void commission payout',
        'payment_id', v_payment.id,
        'reason', v_reason,
        'cashbook_point_pot_id', v_payment.cashbook_point_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => v_cashbook_point_id
    );

    if v_payment.profile_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_payment.profile_id,
        p_type => 'credit',
        p_amount => v_payment.amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payment.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_commission_payout_profile',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true
      );
    end if;
  elsif v_payment.source in ('customer_cash', 'bank', 'courier_remittance') then
    if coalesce(v_payment.amount, 0.00) > 0.00 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_parent_id,
        p_type => 'debit',
        p_amount => case
          when coalesce(v_payment.source_currency_code, 'BDT') <> 'BDT'
            then coalesce(v_payment.source_amount, v_payment.amount)
          else v_payment.amount
        end,
        p_currency_code => coalesce(nullif(trim(v_payment.source_currency_code), ''), 'BDT'),
        p_exchange_rate => coalesce(v_payment.transaction_rate, 1.000000),
        p_source_type => case
          when v_payment.source = 'courier_remittance' then 'shop_order'
          else 'sales_invoice'
        end,
        p_source_id => case
          when v_payment.source = 'courier_remittance' then coalesce(v_payment.shop_order_id::text, v_payment.id::text)
          else v_payment.id::text
        end,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_batch_payment_received',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true,
        p_cashbook_point_id => v_payment.cashbook_point_id
      );
    end if;

    if v_leftover > 0.00 and v_payment.profile_id is not null
       and v_payment.source in ('customer_cash', 'bank') then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_payment.profile_id,
        p_type => 'debit',
        p_amount => v_leftover,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_payment.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_store_credit',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true
      );
    end if;
  else
    raise exception 'Cannot void payment source %.', v_payment.source;
  end if;

  update public.pays
  set
    voided_at = now(),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[VOIDED] ' || v_reason
    )
  where id = v_payment.id;

  if coalesce(array_length(v_shipment_ids, 1), 0) > 0 then
    foreach v_sid in array v_shipment_ids
    loop
      perform public.refresh_global_shipment_fx_from_ap_payments(v_sid);
    end loop;
  end if;

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment.id,
    'customer_group_id', v_payment.customer_group_id
  );
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_reverse_payment(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public._kernel_reverse_payment(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_reverse_payment(bigint, bigint, text) TO service_role;