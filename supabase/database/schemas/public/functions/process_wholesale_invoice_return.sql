CREATE FUNCTION public.process_wholesale_invoice_return (
  p_invoice_id           bigint,
  p_items                jsonb,
  p_return_charge_amount numeric DEFAULT 0,
  p_refund_method        text    DEFAULT NULL::text,
  p_payout_account_id    bigint  DEFAULT NULL::bigint,
  p_note                 text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_invoice public.bills;
  v_parent_total numeric(12, 2);
  v_item_elem jsonb;
  v_item_id bigint;
  v_return_qty numeric;
  v_to_availability public.stock_availability;
  v_to_grade_tag_id bigint;
  v_item_note text;
  v_db_item public.bill_lines%rowtype;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_total_return_value numeric(12, 2) := 0.00;
  v_line_unit_price numeric(12, 2);
  v_line_return_val numeric(12, 2);
  v_paid numeric(12, 2) := 0.00;
  v_excess_paid numeric(12, 2) := 0.00;
  v_refund_amount numeric(12, 2) := 0.00;
  v_return_count integer := 0;
  v_payout_id text;
  v_charge numeric(12, 2) := 0.00;
  v_cn_lines jsonb := '[]'::jsonb;
  v_cn_amount numeric(12, 2);
  v_cn public.bills;
  v_bal jsonb;
  v_open_books numeric(12, 2);
  v_settled numeric(12, 2);
  v_reason text;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.document_kind <> 'standard'::public.bill_document_kind then
    raise exception 'Returns apply to standard bills only';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Returns can only be processed on issued/posted invoices';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one return item must be provided';
  end if;

  v_parent_total := v_invoice.total_amount;
  v_charge := greatest(coalesce(p_return_charge_amount, 0.00), 0.00);
  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);
  v_reason := coalesce(nullif(trim(p_note), ''), 'Wholesale invoice return');

  for v_item_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_item_elem->>'invoice_item_id')::bigint;
    v_return_qty := (v_item_elem->>'quantity')::numeric;
    v_to_availability := coalesce(
      (v_item_elem->>'to_availability')::public.stock_availability,
      'held'::public.stock_availability
    );
    v_to_grade_tag_id := (v_item_elem->>'to_grade_tag_id')::bigint;
    v_item_note := nullif(trim(v_item_elem->>'note'), '');

    if v_item_id is null then
      raise exception 'invoice_item_id is required for all items';
    end if;

    if v_return_qty is null or v_return_qty <= 0 then
      continue;
    end if;

    select * into v_db_item
    from public.bill_lines
    where id = v_item_id and invoice_id = p_invoice_id
    for update;

    if v_db_item.id is null then
      raise exception 'Invoice item % not found on this invoice', v_item_id;
    end if;

    if (v_db_item.return_quantity + v_return_qty) > v_db_item.quantity then
      raise exception 'Return quantity % exceeds available returnable quantity % for %',
        v_return_qty,
        (v_db_item.quantity - v_db_item.return_quantity),
        v_db_item.name_snapshot;
    end if;

    v_line_unit_price := v_db_item.sell_price_amount;
    v_line_return_val := round(v_return_qty * v_line_unit_price, 2);
    v_total_return_value := v_total_return_value + v_line_return_val;

    v_cn_lines := v_cn_lines || jsonb_build_array(
      jsonb_build_object(
        'parent_line_id', v_item_id,
        'name_snapshot', v_db_item.name_snapshot,
        'quantity', v_return_qty,
        'sell_price_amount', v_line_unit_price,
        'line_total_amount', v_line_return_val,
        'books_amount', v_line_return_val
      )
    );

    insert into public.sales_return_items (
      parent_tenant_id,
      invoice_id,
      invoice_item_id,
      global_stock_id,
      quantity,
      return_charge_amount,
      note
    ) values (
      v_parent_id,
      p_invoice_id,
      v_item_id,
      v_db_item.global_stock_id,
      v_return_qty,
      0.00,
      v_item_note
    );

    update public.bill_lines
    set
      return_quantity = return_quantity + v_return_qty,
      updated_at = now()
    where id = v_item_id;

    if v_db_item.global_stock_id is not null then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_id,
        p_stock_id => v_db_item.global_stock_id,
        p_quantity => ceil(v_return_qty)::integer,
        p_to_location_id => public.default_returns_stock_location_id(v_parent_id),
        p_to_availability => v_to_availability,
        p_to_grade_tag_id => coalesce(v_to_grade_tag_id, public.default_stock_grade_tag_id()),
        p_movement_type => 'return_inbound'::public.stock_movement_type,
        p_notes => coalesce(v_item_note, 'Wholesale invoice return #' || coalesce(v_invoice.invoice_no, p_invoice_id::text)),
        p_reference_type => 'sales_invoice',
        p_reference_id => p_invoice_id::text
      );
    end if;

    v_return_count := v_return_count + 1;
  end loop;

  if v_return_count = 0 then
    raise exception 'No items with quantity > 0 were selected for return';
  end if;

  -- Restocking / handling fee reduces credit note face (does not change parent total).
  v_cn_amount := greatest(round(v_total_return_value - v_charge, 2), 0.01);

  v_cn := public.create_bill_adjustment(
    p_invoice_id,
    'credit_note',
    v_cn_amount,
    v_reason,
    true,
    null,
    null,
    v_cn_lines
  );

  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  v_bal := public.get_bill_net_balances(p_invoice_id);
  v_open_books := coalesce((v_bal->>'open_books')::numeric, 0);
  v_settled := coalesce((v_bal->>'paid_amount')::numeric, coalesce(v_invoice.paid_amount, 0));
  v_paid := v_settled;
  v_excess_paid := greatest(v_paid - v_open_books, 0);

  if v_excess_paid > 0.00 then
    if p_refund_method = 'wallet_credit' and v_invoice.profile_id is not null then
      insert into public.cashbook_accounts (
        tenant_id, entity_type, entity_id, currency_code,
        available_balance, locked_balance, pending_balance
      ) values (
        v_eff_tenant_id, 'customer', v_invoice.profile_id, 'BDT',
        0.0000, 0.0000, 0.0000
      ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'credit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice_return',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'returns',
          'purpose', 'wholesale_return_wallet_credit',
          'transaction_type', 'return_credit',
          'label', 'Return Credit (Wallet)',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'credit_note_id', v_cn.id,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;

    elsif p_refund_method = 'payout' and v_invoice.profile_id is not null then
      v_payout_id := 'RET-PO-' || gen_random_uuid()::text;

      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_eff_tenant_id,
        p_type => 'debit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payout_id,
        p_metadata => jsonb_build_object(
          'section', 'payout_earned',
          'purpose', 'wholesale_return_payout',
          'transaction_type', 'return_cash_payout',
          'label', 'Return Cash Payout',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'profile_id', v_invoice.profile_id,
          'credit_note_id', v_cn.id,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;
    end if;
  end if;

  select * into v_invoice from public.bills where id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'credit_note_id', v_cn.id,
    'credit_note_no', v_cn.invoice_no,
    'parent_total_unchanged', v_invoice.total_amount = v_parent_total,
    'new_subtotal', v_invoice.subtotal_amount,
    'new_total', v_parent_total,
    'new_due', v_open_books,
    'open_books', v_open_books,
    'net_balances', v_bal,
    'paid_amount', v_paid,
    'excess_paid', v_excess_paid,
    'refund_amount', v_refund_amount,
    'refund_method', p_refund_method,
    'payment_status', v_invoice.payment_status,
    'returned_items_count', v_return_count
  );
end;
$function$;

GRANT ALL ON FUNCTION public.process_wholesale_invoice_return(bigint, jsonb, numeric, text, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.process_wholesale_invoice_return(bigint, jsonb, numeric, text, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.process_wholesale_invoice_return(bigint, jsonb, numeric, text, bigint, text) TO service_role;