-- Pay-in: vendor returns cash against an issued AP credit note (open credit_open).

CREATE OR REPLACE FUNCTION public.post_vendor_credit_refund(
  p_credit_note_id bigint,
  p_amount numeric,
  p_cashbook_point_id bigint,
  p_received_on date DEFAULT CURRENT_DATE,
  p_note text DEFAULT NULL
) RETURNS public.pays
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
    AS $$
declare
  v_cn public.bills;
  v_refund numeric(12,2);
  v_pay public.pays;
  v_reason text;
begin
  if p_credit_note_id is null then
    raise exception 'credit_note_id is required';
  end if;
  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for the refund';
  end if;

  v_refund := round(coalesce(p_amount, 0), 2);
  if v_refund <= 0 then
    raise exception 'Refund amount must be greater than zero';
  end if;

  select * into v_cn from public.bills where id = p_credit_note_id for update;
  if v_cn.id is null then
    raise exception 'bill not found';
  end if;
  if v_cn.document_kind <> 'credit_note'::public.bill_document_kind then
    raise exception 'Refund applies only to a credit note';
  end if;
  if v_cn.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Credit note must be issued';
  end if;
  if v_cn.invoice_type <> 'ap'::public.global_invoice_type then
    raise exception 'Vendor refund applies only to AP credit notes';
  end if;
  if v_cn.profile_id is null then
    raise exception 'Credit note has no profile';
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_cn.parent_tenant_id)
    or public.membership_has_module_action(v_cn.issued_by_tenant_id, 'payments', 'collect_payment')
    or public.membership_has_module_action(v_cn.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_cn.parent_tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_cn.parent_tenant_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  if v_refund > coalesce(v_cn.due_amount, 0.00) then
    raise exception 'Refund % exceeds open credit % on the note', v_refund, coalesce(v_cn.due_amount, 0);
  end if;

  v_reason := coalesce(nullif(trim(coalesce(p_note, '')), ''), 'Vendor credit refund');

  insert into public.pays (
    tenant_id,
    profile_id,
    source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    note,
    cashbook_point_id
  ) values (
    v_cn.parent_tenant_id,
    v_cn.profile_id,
    'customer_cash',
    v_refund,
    0,
    coalesce(p_received_on, current_date),
    'cash',
    v_reason,
    p_cashbook_point_id
  )
  returning * into v_pay;

  insert into public.pay_instruments (
    payment_id,
    payment_method_code,
    amount,
    sort_order,
    cashbook_point_id
  ) values (
    v_pay.id,
    'CASH',
    v_refund,
    1,
    p_cashbook_point_id
  );

  insert into public.pay_allocations (
    tenant_id,
    payment_id,
    global_invoice_id,
    bill_id,
    amount
  ) values (
    v_cn.parent_tenant_id,
    v_pay.id,
    v_cn.id,
    v_cn.id,
    v_refund
  );

  perform public.recompute_global_invoice_payment_status(v_cn.id);
  if v_cn.parent_bill_id is not null then
    perform public.recompute_global_invoice_payment_status(v_cn.parent_bill_id);
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_cn.parent_tenant_id,
    p_operating_tenant_id => v_cn.issued_by_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_cn.parent_tenant_id,
    p_type => 'credit',
    p_amount => v_refund,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'receipt',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'credit_note_refund',
      'transaction_type', 'vendor_credit_cash_refund',
      'label', 'Vendor credit refund received',
      'payment_id', v_pay.id,
      'credit_note_id', v_cn.id,
      'credit_note_no', v_cn.invoice_no,
      'parent_bill_id', v_cn.parent_bill_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_cashbook_point_id
  );

  return v_pay;
end;
$$;

ALTER FUNCTION public.post_vendor_credit_refund(bigint, numeric, bigint, date, text) OWNER TO postgres;

REVOKE ALL ON FUNCTION public.post_vendor_credit_refund(bigint, numeric, bigint, date, text) FROM PUBLIC;
GRANT ALL ON FUNCTION public.post_vendor_credit_refund(bigint, numeric, bigint, date, text) TO authenticated;
GRANT ALL ON FUNCTION public.post_vendor_credit_refund(bigint, numeric, bigint, date, text) TO service_role;
