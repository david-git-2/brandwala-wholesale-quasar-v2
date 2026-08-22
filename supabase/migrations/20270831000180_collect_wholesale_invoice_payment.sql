-- Atomic wholesale collect: cash (tenant wallet), store credit (customer debit), settlement write-off.

CREATE OR REPLACE FUNCTION "public"."collect_wholesale_invoice_payment"(
  "p_invoice_id" bigint,
  "p_cash_amount" numeric DEFAULT 0,
  "p_cash_method" text DEFAULT 'cash',
  "p_wallet_amount" numeric DEFAULT 0,
  "p_settlement_amount" numeric DEFAULT 0
) RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.sales_invoices;
  v_cash numeric(12,2);
  v_wallet numeric(12,2);
  v_settle numeric(12,2);
  v_due numeric(12,2);
  v_tenant_id bigint;
  v_payment_id bigint;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  v_cash := greatest(coalesce(p_cash_amount, 0.00), 0.00);
  v_wallet := greatest(coalesce(p_wallet_amount, 0.00), 0.00);
  v_settle := greatest(coalesce(p_settlement_amount, 0.00), 0.00);

  if v_cash <= 0 and v_wallet <= 0 and v_settle <= 0 then
    raise exception 'Enter cash, store credit, or settlement';
  end if;

  select * into v_invoice
  from public.sales_invoices
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Payments can only be recorded on issued invoices';
  end if;

  if v_invoice.billing_profile_id is null then
    raise exception 'Billing profile is required';
  end if;

  v_due := coalesce(v_invoice.due_amount, 0.00);
  if (v_cash + v_wallet + v_settle) > v_due then
    raise exception 'Cash + credit + settlement cannot exceed due';
  end if;

  v_tenant_id := coalesce(v_invoice.parent_tenant_id, v_invoice.tenant_id);

  if v_cash > 0 then
    insert into public.global_payments (
      tenant_id, billing_profile_id, amount, unallocated_amount,
      payment_date, method, note
    ) values (
      v_tenant_id, v_invoice.billing_profile_id, v_cash, 0.00,
      current_date, coalesce(nullif(trim(p_cash_method), ''), 'cash'),
      'Wholesale invoice collect (cash)'
    ) returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_cash);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_cash, updated_at = now()
    where id = p_invoice_id;

    perform public.recompute_global_invoice_payment_status(p_invoice_id);

    perform public.record_ledger_transaction(
      p_tenant_id => v_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_tenant_id,
      p_type => 'credit',
      p_amount => v_cash,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'tenant_payment_received',
        'transaction_type', 'payment_received',
        'label', 'Payment Received',
        'invoice_id', p_invoice_id,
        'payment_id', v_payment_id
      )
    );
  end if;

  if v_wallet > 0 then
    insert into public.wallet_accounts (
      tenant_id, entity_type, entity_id, currency_code,
      available_balance, locked_balance, pending_balance
    ) values (
      v_tenant_id, 'customer', v_invoice.billing_profile_id, 'BDT',
      0.0000, 0.0000, 0.0000
    ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

    insert into public.global_payments (
      tenant_id, billing_profile_id, amount, unallocated_amount,
      payment_date, method, note
    ) values (
      v_tenant_id, v_invoice.billing_profile_id, v_wallet, 0.00,
      current_date, 'wallet_credit',
      'Wholesale invoice collect (store credit)'
    ) returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_wallet);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_wallet, updated_at = now()
    where id = p_invoice_id;

    perform public.recompute_global_invoice_payment_status(p_invoice_id);

    perform public.record_ledger_transaction(
      p_tenant_id => v_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_invoice.billing_profile_id,
      p_type => 'debit',
      p_amount => v_wallet,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment_id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied store credit',
        'invoice_id', p_invoice_id,
        'payment_id', v_payment_id
      )
    );
  end if;

  if v_settle > 0 then
    perform public.apply_global_invoice_settlement_discount(p_invoice_id, v_settle, 'Wholesale collect settlement');
  end if;

  select * into v_invoice from public.sales_invoices where id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'paid_amount', v_invoice.paid_amount,
    'due_amount', v_invoice.due_amount,
    'payment_status', v_invoice.payment_status,
    'settlement_discount_amount', v_invoice.settlement_discount_amount
  );
end;
$$;

ALTER FUNCTION "public"."collect_wholesale_invoice_payment"(bigint, numeric, text, numeric, numeric) OWNER TO "postgres";

GRANT ALL ON FUNCTION public.collect_wholesale_invoice_payment(bigint, numeric, text, numeric, numeric) TO authenticated;
GRANT ALL ON FUNCTION public.collect_wholesale_invoice_payment(bigint, numeric, text, numeric, numeric) TO service_role;
