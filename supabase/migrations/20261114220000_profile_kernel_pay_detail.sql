-- Profile payment account: kernel pay detail for info dialog.

CREATE OR REPLACE FUNCTION public._kernel_cash_bundle_detail_json(p_bundle_id bigint)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT CASE
    WHEN p_bundle_id IS NULL THEN NULL
    ELSE (
      SELECT jsonb_build_object(
        'bundle_id', cb.id,
        'location_code', cl.location_code,
        'location_name', cl.name,
        'currency_code', cb.currency_code,
        'amount', cb.amount
      )
      FROM money_kernel.cash_bundles cb
      JOIN money_kernel.cash_locations cl ON cl.id = cb.cash_location_id
      WHERE cb.id = p_bundle_id
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.get_profile_kernel_pay_detail_for_staff(
  p_tenant_id bigint,
  p_pays_id bigint
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_pay money_kernel.pays;
  v_from_pid bigint;
  v_to_pid bigint;
  v_allocs jsonb := '[]'::jsonb;
BEGIN
  IF p_pays_id IS NULL OR p_pays_id <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid pays_id');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_pay
    FROM money_kernel.pays py
   WHERE py.tenant_id = v_books_id
     AND py.id = p_pays_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'pay not found');
  END IF;

  v_from_pid := coalesce(
    v_pay.from_profile_id,
    public._kernel_bundle_owner_profile_id(v_pay.from_cash_bundle_id)
  );
  v_to_pid := coalesce(
    v_pay.to_profile_id,
    public._kernel_bundle_owner_profile_id(v_pay.to_cash_bundle_id),
    CASE
      WHEN v_pay.kind = 'payment' THEN (
        SELECT b.to_profile_id
          FROM money_kernel.bill_settlements bs
          JOIN money_kernel.bills b
            ON b.id = bs.bill_id AND b.tenant_id = v_pay.tenant_id
         WHERE bs.pays_id = v_pay.id
           AND bs.settlement_kind = 'pay'
         ORDER BY bs.id
         LIMIT 1
      )
      ELSE NULL
    END
  );

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', bs.bill_id,
        'invoice_no', b.invoice_no,
        'amount', bs.allocated_amount
      )
      ORDER BY bs.id
    ),
    '[]'::jsonb
  )
  INTO v_allocs
  FROM money_kernel.bill_settlements bs
  JOIN money_kernel.bills b
    ON b.id = bs.bill_id AND b.tenant_id = v_pay.tenant_id
 WHERE bs.pays_id = v_pay.id
   AND bs.settlement_kind = 'pay';

  RETURN jsonb_build_object(
    'success', true,
    'spine', 'kernel',
    'id', v_pay.id,
    'kind', v_pay.kind,
    'status', v_pay.status,
    'payment_date', v_pay.payment_date,
    'created_at', v_pay.created_at,
    'amount', v_pay.amount,
    'books_amount', v_pay.books_amount,
    'currency_code', coalesce(v_pay.currency_code, 'BDT'),
    'books_rate', v_pay.books_rate,
    'exchange_rate', v_pay.exchange_rate,
    'from_profile_id', v_from_pid,
    'to_profile_id', v_to_pid,
    'from_profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = v_from_pid),
    'to_profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = v_to_pid),
    'from_bundle', public._kernel_cash_bundle_detail_json(v_pay.from_cash_bundle_id),
    'to_bundle', public._kernel_cash_bundle_detail_json(v_pay.to_cash_bundle_id),
    'from_balance_after', v_pay.from_balance_after,
    'to_balance_after', v_pay.to_balance_after,
    'meta', coalesce(v_pay.meta, '{}'::jsonb),
    'refs', coalesce(v_pay.refs, '{}'::jsonb),
    'reverted_at', v_pay.meta->>'reverted_at',
    'revert_reason', v_pay.meta->>'revert_reason',
    'is_reversal', (v_pay.refs ? 'reverses_pays_id'),
    'reverses_pays_id', nullif(v_pay.refs->>'reverses_pays_id', '')::bigint,
    'bank_name', (
      SELECT bb.name
      FROM public.bd_banks bb
      WHERE bb.id = nullif(v_pay.meta->>'bd_bank_id', '')::bigint
    ),
    'allocations', v_allocs
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_cash_bundle_detail_json(bigint)
  TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.get_profile_kernel_pay_detail_for_staff(bigint, bigint)
  TO authenticated, service_role;