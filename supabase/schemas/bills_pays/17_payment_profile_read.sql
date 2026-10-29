-- Payments profile page: one round-trip for header, due, ledger, and pays.

CREATE OR REPLACE FUNCTION public.get_payment_profile_for_staff(
  p_tenant_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_currency_code text DEFAULT 'BDT'::text,
  p_ledger_limit integer DEFAULT 50,
  p_pays_limit integer DEFAULT 50
) RETURNS jsonb
    LANGUAGE plpgsql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
DECLARE
  v_books_id bigint;
  v_detail jsonb;
  v_ledger_entity_id bigint;
  v_ledger jsonb := '[]'::jsonb;
  v_pays jsonb := '[]'::jsonb;
  v_due_total numeric(18, 4) := 0;
  v_ledger_lim integer;
  v_pays_lim integer;
BEGIN
  IF p_entity_type NOT IN ('tenant', 'customer', 'vendor', 'courier') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  v_detail := public.get_cashbook_detail_for_staff(
    p_tenant_id, p_entity_type, p_entity_id, p_currency_code
  );
  IF coalesce((v_detail->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN v_detail;
  END IF;

  v_ledger_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_ledger_entity_id := v_books_id;
  END IF;

  v_ledger_lim := greatest(least(coalesce(p_ledger_limit, 50), 200), 1);
  v_pays_lim := greatest(least(coalesce(p_pays_limit, 50), 200), 1);

  SELECT coalesce(jsonb_agg(row_data ORDER BY sort_created DESC, sort_id DESC), '[]'::jsonb)
  INTO v_ledger
  FROM (
    SELECT
      jsonb_build_object(
        'id', l.id::text,
        'type', l.type,
        'amount', l.amount,
        'balance_after', l.balance_after,
        'source_type', l.source_type,
        'source_id', l.source_id,
        'created_at', l.created_at,
        'is_reversal', (l.metadata ? 'reversal_of'),
        'metadata', coalesce(l.metadata, '{}'::jsonb),
        'cashbook_point_id', l.cashbook_point_id,
        'cashbook_point_name', cp.name
      ) AS row_data,
      l.created_at AS sort_created,
      l.id AS sort_id
    FROM public.cashbook_entries l
    LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
    WHERE l.parent_tenant_id = v_books_id
      AND l.entity_type = p_entity_type
      AND l.entity_id = v_ledger_entity_id
    ORDER BY l.created_at DESC, l.id DESC
    LIMIT v_ledger_lim
  ) ledger_rows;

  IF p_entity_type <> 'tenant' THEN
    SELECT coalesce(sum(b.due_amount), 0::numeric)
    INTO v_due_total
    FROM public.bills b
    WHERE b.parent_tenant_id = v_books_id
      AND b.profile_id = p_entity_id
      AND b.invoice_status = 'issued'
      AND coalesce(b.payment_status, '') <> 'paid';
  END IF;

  IF p_entity_type = 'customer' THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_id DESC), '[]'::jsonb)
    INTO v_pays
    FROM (
      SELECT
        jsonb_build_object(
          'id', py.id,
          'payment_date', py.payment_date,
          'amount', py.amount,
          'unallocated_amount', coalesce(py.unallocated_amount, 0),
          'source', py.source,
          'method', py.method,
          'reference', py.reference,
          'note', py.note,
          'voided_at', py.voided_at,
          'profile_id', py.profile_id,
          'profile_name', pr.name,
          'shop_order_id', py.shop_order_id,
          'settlement_currency_code', coalesce(py.settlement_currency_code, 'BDT'),
          'foreign_amount', py.foreign_amount,
          'exchange_rate', coalesce(py.exchange_rate, 1)
        ) AS row_data,
        py.id AS sort_id
      FROM public.pays py
      LEFT JOIN public.profiles pr ON pr.id = py.profile_id
      WHERE py.tenant_id = v_books_id
        AND py.profile_id = p_entity_id
        AND py.source = ANY (ARRAY['customer_cash', 'bank', 'store_credit', 'courier_remittance']::text[])
      ORDER BY py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;

  ELSIF p_entity_type IN ('vendor', 'courier') THEN
    SELECT coalesce(jsonb_agg(row_data ORDER BY sort_id DESC), '[]'::jsonb)
    INTO v_pays
    FROM (
      SELECT
        jsonb_build_object(
          'id', py.id,
          'payment_date', py.payment_date,
          'amount', py.amount,
          'unallocated_amount', coalesce(py.unallocated_amount, 0),
          'source', py.source,
          'method', py.method,
          'reference', py.reference,
          'note', py.note,
          'voided_at', py.voided_at,
          'profile_id', py.profile_id,
          'profile_name', pr.name,
          'shop_order_id', py.shop_order_id,
          'settlement_currency_code', coalesce(py.settlement_currency_code, 'BDT'),
          'foreign_amount', py.foreign_amount,
          'exchange_rate', coalesce(py.exchange_rate, 1)
        ) AS row_data,
        py.id AS sort_id
      FROM public.pays py
      LEFT JOIN public.profiles pr ON pr.id = py.profile_id
      WHERE py.tenant_id = v_books_id
        AND py.profile_id = p_entity_id
        AND py.source = ANY (ARRAY['ap_payout', 'commission']::text[])
      ORDER BY py.id DESC
      LIMIT v_pays_lim
    ) pay_rows;
  END IF;

  RETURN v_detail
    || jsonb_build_object(
      'due_total', v_due_total,
      'ledger', v_ledger,
      'pays', v_pays
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO authenticated;

GRANT EXECUTE ON FUNCTION public.get_payment_profile_for_staff(
  bigint, text, bigint, text, integer, integer
) TO service_role;
