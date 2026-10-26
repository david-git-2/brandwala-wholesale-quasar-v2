-- CN/DN numbers: prefix once at start (INV-INV-… → INV-CN-INV-…, not INV-CN-INV-CN-…).

CREATE OR REPLACE FUNCTION public.create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true,
  p_refund_amount numeric DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_lines jsonb DEFAULT '[]'::jsonb
) RETURNS public.bills
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO public
    AS $$
declare
  v_parent public.bills;
  v_kind public.bill_document_kind;
  v_row public.bills;
  v_no text;
  v_reason text;
  v_amount numeric(12,2);
  v_status public.global_invoice_status;
  v_refund numeric(12,2);
  v_child_due numeric(12,2);
  v_pay public.pays;
  v_line_elem jsonb;
  v_line_total numeric(12,2);
  v_books numeric(12,2);
  v_line_kind text;
  v_stock_id bigint;
  v_lines_sum numeric(12,2) := 0.00;
begin
  if p_parent_bill_id is null then
    raise exception 'parent_bill_id is required';
  end if;

  v_kind := case lower(trim(coalesce(p_kind, '')))
    when 'credit_note' then 'credit_note'::public.bill_document_kind
    when 'credit' then 'credit_note'::public.bill_document_kind
    when 'debit_note' then 'debit_note'::public.bill_document_kind
    when 'debit' then 'debit_note'::public.bill_document_kind
    else null
  end;
  if v_kind is null then
    raise exception 'kind must be credit_note or debit_note';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'reason is required';
  end if;

  select * into v_parent from public.bills where id = p_parent_bill_id for update;
  if v_parent.id is null then
    raise exception 'bill not found';
  end if;
  if v_parent.document_kind <> 'standard'::public.bill_document_kind then
    raise exception 'adjustments must attach to a standard bill';
  end if;
  if v_parent.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'parent bill must be issued';
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent.parent_tenant_id)
    or public.membership_has_module_action(v_parent.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' and jsonb_array_length(p_lines) > 0 then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_lines_sum := v_lines_sum + v_books;
    end loop;
    v_amount := round(v_lines_sum, 2);
  else
    v_amount := round(coalesce(p_amount, 0), 2);
  end if;

  if v_amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  v_no := public.generate_sales_invoice_number(
    v_parent.issued_by_tenant_id,
    v_parent.invoice_type,
    current_date
  );
  if v_kind = 'credit_note'::public.bill_document_kind then
    v_no := regexp_replace(v_no, '^INV-', 'INV-CN-');
  else
    v_no := regexp_replace(v_no, '^INV-', 'INV-DN-');
  end if;

  v_status := case when coalesce(p_issue, true)
    then 'issued'::public.global_invoice_status
    else 'draft'::public.global_invoice_status
  end;

  insert into public.bills (
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    invoice_status,
    profile_id,
    collection_source,
    payment_status,
    subtotal_amount,
    total_amount,
    due_amount,
    paid_amount,
    note,
    document_kind,
    parent_bill_id,
    ap_shipment_id,
    ap_kind,
    channel_meta
  ) values (
    v_parent.parent_tenant_id,
    v_parent.issued_by_tenant_id,
    v_no,
    v_parent.invoice_type,
    current_date,
    v_status,
    v_parent.profile_id,
    v_parent.collection_source,
    'due',
    v_amount,
    v_amount,
    v_amount,
    0,
    v_reason,
    v_kind,
    v_parent.id,
    v_parent.ap_shipment_id,
    v_parent.ap_kind,
    jsonb_build_object(
      'adjustment', jsonb_build_object(
        'kind', v_kind::text,
        'reason', v_reason,
        'parent_invoice_no', v_parent.invoice_no
      )
    )
  )
  returning * into v_row;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_line_kind := lower(trim(coalesce(v_line_elem ->> 'line_kind', 'description')));
      if v_line_kind not in ('stock', 'description', 'charge') then
        v_line_kind := 'description';
      end if;
      v_stock_id := nullif(trim(coalesce(v_line_elem ->> 'global_stock_id', '')), '')::bigint;

      insert into public.bill_lines (
        parent_tenant_id,
        invoice_id,
        line_kind,
        name_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        currency_code,
        books_amount,
        line_meta,
        global_stock_id
      ) values (
        v_parent.parent_tenant_id,
        v_row.id,
        v_line_kind,
        coalesce(nullif(trim(coalesce(v_line_elem ->> 'name_snapshot', '')), ''), 'Adjustment line'),
        greatest(coalesce((v_line_elem ->> 'quantity')::numeric, 1.000), 0.001),
        v_line_total,
        0.00,
        v_line_total,
        upper(trim(coalesce(v_line_elem ->> 'currency_code', 'BDT'))),
        v_books,
        coalesce(v_line_elem -> 'line_meta', '{}'::jsonb)
          || case
            when nullif(trim(coalesce(v_line_elem ->> 'parent_line_id', '')), '') is not null
            then jsonb_build_object('parent_line_id', v_line_elem ->> 'parent_line_id')
            else '{}'::jsonb
          end,
        v_stock_id
      );
    end loop;
  end if;

  perform public.stamp_bill_kernel_fields(v_row.id);

  if v_status = 'issued'::public.global_invoice_status then
    perform public.recompute_global_invoice_payment_status(v_parent.id);
    select * into v_row from public.bills where id = v_row.id;
  end if;

  v_refund := round(coalesce(p_refund_amount, 0), 2);
  if v_refund > 0 then
    if v_kind <> 'credit_note'::public.bill_document_kind then
      raise exception 'Cash refund applies only to credit notes';
    end if;
    if v_parent.profile_id is null then
      raise exception 'Bill has no profile for refund';
    end if;
    if p_cashbook_point_id is null then
      raise exception 'Choose a cash point for the refund';
    end if;
    if not exists (
      select 1
      from public.cashbook_points cp
      join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
      where cp.id = p_cashbook_point_id
        and cp.is_active = true
        and ca.parent_tenant_id = v_parent.parent_tenant_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent.parent_tenant_id
    ) then
      raise exception 'Invalid cash point for this tenant';
    end if;

    v_child_due := coalesce(v_row.due_amount, 0.00);
    if v_refund > v_child_due then
      raise exception 'Refund % exceeds open credit % on the note', v_refund, v_child_due;
    end if;

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
      v_parent.parent_tenant_id,
      v_parent.profile_id,
      'ap_payout',
      v_refund,
      0,
      current_date,
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
      v_parent.parent_tenant_id,
      v_pay.id,
      v_row.id,
      v_row.id,
      v_refund
    );

    perform public.recompute_global_invoice_payment_status(v_row.id);
    perform public.recompute_global_invoice_payment_status(v_parent.id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent.parent_tenant_id,
      p_operating_tenant_id => v_parent.issued_by_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent.parent_tenant_id,
      p_type => 'debit',
      p_amount => v_refund,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'credit_note_refund',
        'transaction_type', 'credit_note_cash_refund',
        'label', 'Credit note cash refund',
        'payment_id', v_pay.id,
        'credit_note_id', v_row.id,
        'credit_note_no', v_row.invoice_no,
        'parent_bill_id', v_parent.id,
        'parent_invoice_no', v_parent.invoice_no
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => p_cashbook_point_id
    );

    select * into v_row from public.bills where id = v_row.id;
  elsif p_cashbook_point_id is not null and coalesce(p_refund_amount, 0) <= 0 then
    raise exception 'Refund amount is required when a cash point is selected';
  end if;

  return v_row;
end;
$$;

GRANT ALL ON FUNCTION public.create_bill_adjustment(bigint, text, numeric, text, boolean, numeric, bigint, jsonb) TO authenticated;
GRANT ALL ON FUNCTION public.create_bill_adjustment(bigint, text, numeric, text, boolean, numeric, bigint, jsonb) TO service_role;
