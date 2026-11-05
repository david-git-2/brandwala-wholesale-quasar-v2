CREATE FUNCTION public.record_cashbook_manual_transaction_for_staff (
  p_tenant_id                bigint,
  p_action_type              text,
  p_primary_entity_type      text,
  p_primary_entity_id        bigint,
  p_amount                   numeric,
  p_currency_code            text    DEFAULT 'BDT'::text,
  p_exchange_rate            numeric DEFAULT 1.000000,
  p_category                 text    DEFAULT NULL::text,
  p_payment_method           text    DEFAULT NULL::text,
  p_reference_id             text    DEFAULT NULL::text,
  p_note                     text    DEFAULT NULL::text,
  p_counterparty_entity_type text    DEFAULT NULL::text,
  p_counterparty_entity_id   bigint  DEFAULT NULL::bigint,
  p_target_bucket            text    DEFAULT 'available'::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_source_id text;
  v_meta jsonb;
  v_primary_id bigint;
  v_ledger_ids uuid[] := '{}';
  v_entry jsonb;
  v_primary_entity_id bigint;
  v_counterparty_id bigint;
BEGIN
  IF NOT public.cashbook_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF coalesce(p_amount, 0) <= 0 OR coalesce(p_exchange_rate, 0) <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'amount and exchange_rate must be positive');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_primary_entity_id := p_primary_entity_id;
  IF p_primary_entity_type = 'tenant' THEN v_primary_entity_id := v_books_id; END IF;

  v_source_id := coalesce(nullif(trim(p_reference_id), ''),
    CASE p_action_type
      WHEN 'pay' THEN 'MAN-PAY-' || gen_random_uuid()::text
      WHEN 'withdraw' THEN 'MAN-WD-' || gen_random_uuid()::text
      WHEN 'deposit' THEN 'MAN-DEP-' || gen_random_uuid()::text
      ELSE 'MAN-CR-' || gen_random_uuid()::text
    END);

  v_meta := jsonb_build_object(
    'section', p_category,
    'method', p_payment_method,
    'trx_id', v_source_id,
    'note', p_note,
    'action_type', p_action_type,
    'transaction_type', 'manual_adjustment',
    'label', initcap(p_action_type),
    'recorded_by', public.current_user_email(),
    'target_bucket', coalesce(p_target_bucket, 'available')
  );

  IF p_action_type IN ('pay', 'credit') AND p_primary_entity_type = 'tenant'
     AND (p_counterparty_entity_type IS NULL OR p_counterparty_entity_id IS NULL) THEN
    RETURN jsonb_build_object('success', false, 'error', 'counterparty required');
  END IF;

  IF p_action_type = 'deposit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'withdraw' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'payout', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' AND p_primary_entity_type = 'tenant' THEN
    v_counterparty_id := p_counterparty_entity_id;
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, v_counterparty_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'credit' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' AND p_primary_entity_type = 'tenant' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_counterparty_entity_type, p_counterparty_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      CASE WHEN p_category = 'vendor_purchase' THEN 'vendor_purchase' ELSE 'adjustment' END,
      v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSIF p_action_type = 'pay' THEN
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, 'tenant', v_books_id,
      'debit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);
    v_entry := public.record_ledger_transaction(
      v_books_id, v_operating_id, p_primary_entity_type, v_primary_entity_id,
      'credit', p_amount, p_currency_code, p_exchange_rate,
      'adjustment', v_source_id, v_meta, p_target_bucket, false
    );
    v_ledger_ids := array_append(v_ledger_ids, (v_entry->>'id')::uuid);

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid action_type');
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'ledger_entry_ids', to_jsonb(v_ledger_ids),
    'primary_account', public.get_cashbook_account_balances(v_books_id, p_primary_entity_type, v_primary_entity_id, p_currency_code)
  );
END;
$function$;

GRANT ALL ON FUNCTION public.record_cashbook_manual_transaction_for_staff(bigint, text, text, bigint, numeric, text, numeric, text, text, text, text, text, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.record_cashbook_manual_transaction_for_staff(bigint, text, text, bigint, numeric, text, numeric, text, text, text, text, text, bigint, text) TO
  authenticated;

GRANT ALL ON FUNCTION public.record_cashbook_manual_transaction_for_staff(bigint, text, text, bigint, numeric, text, numeric, text, text, text, text, text, bigint, text) TO
  service_role;