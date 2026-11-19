-- Vendor credit refund: ensure pot server-side; ignore stale client pot ids.

CREATE OR REPLACE FUNCTION "public"."post_vendor_credit_refund"("p_credit_note_id" bigint, "p_amount" numeric, "p_cashbook_point_id" bigint, "p_received_on" "date" DEFAULT CURRENT_DATE, "p_note" "text" DEFAULT NULL::"text", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "public"."pays"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cn public.bills;
  v_refund numeric(12,2);
  v_pay public.pays;
  v_reason text;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_base_currency text := 'BDT';
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_source_amount numeric(12, 2);
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_payment_face numeric(12, 2);
  v_bill_currency text;
  v_due_face numeric(12, 2);
  v_refund_face numeric(12, 2);
  v_books_rate numeric(15, 6);
begin
  if p_credit_note_id is null then
    raise exception 'credit_note_id is required';
  end if;
  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for the refund';
  end if;

  v_refund := round(coalesce(p_amount, 0), 2);
  if v_refund <= 0 and coalesce(p_foreign_amount, 0) <= 0 then
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
    or public.user_can_manage_books_tenant(v_cn.tenant_id)
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
      and ca.tenant_id = v_cn.tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_cn.tenant_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  v_reason := coalesce(nullif(trim(coalesce(p_note, '')), ''), 'Vendor credit refund');

  v_base_currency := public.resolve_tenant_base_currency_code(v_cn.tenant_id);

  select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
  into v_settle_currency, v_foreign_amt, v_fx_rate, v_refund
  from public.normalize_pay_settlement_fx(
    v_refund,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    v_base_currency
  ) n;

  if v_refund <= 0 then
    raise exception 'Refund amount must be greater than zero';
  end if;

  v_bill_currency := upper(coalesce(nullif(trim(v_cn.currency_code), ''), v_base_currency));
  v_due_face := coalesce(v_cn.due_amount, 0);

  if coalesce(v_foreign_amt, 0) > 0 then
    v_refund_face := round(v_foreign_amt, 2);
    if v_refund_face > v_due_face then
      raise exception 'Refund % exceeds open credit % on the note', v_refund_face, v_due_face;
    end if;
  elsif v_bill_currency = v_base_currency then
    if v_refund > v_due_face then
      raise exception 'Refund % exceeds open credit % on the note', v_refund, v_due_face;
    end if;
  else
    v_books_rate := coalesce(nullif(v_cn.books_exchange_rate, 0), nullif(p_exchange_rate, 0), 0);
    if v_books_rate <= 0 then
      raise exception 'exchange_rate required for % credit note refund', v_bill_currency;
    end if;
    v_refund_face := round(v_refund / v_books_rate, 2);
    if v_refund_face > v_due_face then
      raise exception 'Refund % exceeds open credit % on the note', v_refund_face, v_due_face;
    end if;
  end if;

  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  if v_source_currency = '' then
    select upper(cpp.currency_code)
    into v_source_currency
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_cn.tenant_id
    order by case when upper(cpp.currency_code) = v_base_currency then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is not null and not exists (
    select 1
    from public.cashbook_point_pots cpp
    where cpp.id = v_pot_id
      and cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_cn.tenant_id
  ) then
    v_pot_id := null;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      v_cn.tenant_id,
      p_cashbook_point_id,
      v_source_currency
    );
  end if;

  perform public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  if upper(v_settle_currency) = v_source_currency then
    v_transaction_rate := 1.000000;
  else
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    if v_transaction_rate <= 0 then
      raise exception 'transaction_rate required when pot currency (%) differs from refund currency (%)',
        v_source_currency, v_settle_currency;
    end if;
  end if;

  if upper(v_settle_currency) = v_base_currency then
    v_payment_face := v_refund;
  else
    v_payment_face := coalesce(v_foreign_amt, 0);
  end if;

  v_source_amount := round(v_payment_face * v_transaction_rate, 2);

  insert into public.pays (
    tenant_id,
    profile_id,
    source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    note,
    cashbook_point_id,
    settlement_currency_code,
    foreign_amount,
    exchange_rate,
    quote_currency_code,
    source_currency_code,
    transaction_rate,
    source_amount,
    cashbook_point_pot_id
  ) values (
    v_cn.tenant_id,
    v_cn.profile_id,
    'customer_cash',
    v_refund,
    0,
    coalesce(p_received_on, current_date),
    'cash',
    v_reason,
    p_cashbook_point_id,
    v_settle_currency,
    v_foreign_amt,
    v_fx_rate,
    v_base_currency,
    v_source_currency,
    v_transaction_rate,
    v_source_amount,
    v_pot_id
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
    v_cn.tenant_id,
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
    p_tenant_id => v_cn.tenant_id,
    p_operating_tenant_id => v_cn.issued_by_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_cn.tenant_id,
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
      'parent_bill_id', v_cn.parent_bill_id,
      'settlement_currency_code', v_settle_currency,
      'foreign_amount', v_foreign_amt,
      'exchange_rate', v_fx_rate,
      'source_currency_code', v_source_currency,
      'transaction_rate', v_transaction_rate,
      'source_amount', v_source_amount,
      'cashbook_point_pot_id', v_pot_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_cashbook_point_id
  );

  return v_pay;
end;
$$;
