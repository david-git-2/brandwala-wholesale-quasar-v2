-- get_customer_account_summary_for_staff: profiles use parent_tenant_id / operating_tenant_id, not tenant_id.
CREATE OR REPLACE FUNCTION public.get_customer_account_summary_for_staff(
  p_tenant_id bigint,
  p_customer_group_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_id bigint;
  v_group_tenant_id bigint;
  v_profile_id bigint;
  v_bp_ids bigint[];
  v_still_due numeric(12, 2) := 0;
  v_total_billed numeric(12, 2) := 0;
  v_settlement numeric(12, 2) := 0;
  v_collected_cash numeric(12, 2) := 0;
  v_wallet_applied numeric(12, 2) := 0;
  v_store_credit numeric(15, 4) := 0;
  v_unallocated numeric(12, 2) := 0;
  v_open_invoices jsonb := '[]'::jsonb;
  v_recent_payments jsonb := '[]'::jsonb;
  v_recent_ledger jsonb := '[]'::jsonb;
  v_shop_access jsonb := '[]'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_customer_group_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'tenant and customer group are required');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT (
    public.is_tenant_staff(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'customer', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT cg.tenant_id
  INTO v_group_tenant_id
  FROM public.customer_groups cg
  WHERE cg.id = p_customer_group_id;

  IF v_group_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'customer group not found');
  END IF;

  SELECT
    coalesce(array_agg(pr.id ORDER BY
      CASE WHEN pr.operating_tenant_id = v_group_tenant_id THEN 0 ELSE 1 END,
      pr.id
    ), '{}'::bigint[]),
    (array_agg(pr.id ORDER BY
      CASE WHEN pr.operating_tenant_id = v_group_tenant_id THEN 0 ELSE 1 END,
      pr.id
    ))[1]
  INTO v_bp_ids, v_profile_id
  FROM public.profiles pr
  WHERE pr.customer_group_id = p_customer_group_id
    AND pr.profile_type = 'customer'::public.profile_party_type
    AND pr.parent_tenant_id = v_books_id;

  IF v_profile_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'books_tenant_id', v_books_id,
      'profile_id', null,
      'still_due', 0,
      'total_billed', 0,
      'collected_cash', 0,
      'wallet_applied', 0,
      'settlement', 0,
      'store_credit_balance', 0,
      'unallocated_payments', 0,
      'open_invoices', '[]'::jsonb,
      'recent_payments', '[]'::jsonb,
      'recent_ledger', '[]'::jsonb,
      'shop_access', coalesce((
        SELECT jsonb_agg(to_jsonb(r))
        FROM (
          SELECT
            s.id AS shop_id,
            s.name AS shop_name,
            s.shop_type::text AS shop_type,
            st.id AS shop_tenant_id,
            st.name AS shop_tenant_name,
            scga.status,
            scga.credit_limit_amount
          FROM public.shop_customer_group_access scga
          JOIN public.shops s ON s.id = scga.shop_id
          JOIN public.tenants st ON st.id = s.tenant_id
          WHERE scga.customer_group_id = p_customer_group_id
          ORDER BY st.name, s.name
          LIMIT 20
        ) r
      ), '[]'::jsonb)
    );
  END IF;

  SELECT
    coalesce(sum(si.due_amount), 0.00),
    coalesce(sum(si.total_amount), 0.00),
    coalesce(sum(si.settlement_discount_amount), 0.00)
  INTO v_still_due, v_total_billed, v_settlement
  FROM public.bills si
  WHERE si.profile_id = ANY(v_bp_ids)
    AND si.invoice_status = 'issued'::public.global_invoice_status;

  SELECT
    coalesce(sum(ip.amount) FILTER (WHERE coalesce(gp.method, '') <> 'wallet_credit'), 0.00),
    coalesce(sum(ip.amount) FILTER (WHERE gp.method = 'wallet_credit'), 0.00)
  INTO v_collected_cash, v_wallet_applied
  FROM public.pay_allocations ip
  JOIN public.pays gp ON gp.id = ip.payment_id
  JOIN public.bills si ON si.id = ip.global_invoice_id
  WHERE si.profile_id = ANY(v_bp_ids)
    AND si.invoice_status = 'issued'::public.global_invoice_status;

  SELECT coalesce(wa.available_balance, 0.0000)
  INTO v_store_credit
  FROM public.cashbook_accounts wa
  WHERE wa.parent_tenant_id = v_books_id
    AND wa.entity_type = 'customer'
    AND wa.entity_id = v_profile_id
    AND wa.currency_code = 'BDT';

  SELECT coalesce(sum(gp.unallocated_amount), 0.00)
  INTO v_unallocated
  FROM public.pays gp
  WHERE gp.profile_id = ANY(v_bp_ids);

  SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_open_invoices
  FROM (
    SELECT
      si.id,
      si.invoice_no,
      si.invoice_type::text AS invoice_type,
      si.due_amount,
      si.paid_amount,
      si.total_amount,
      si.payment_status,
      si.invoice_date,
      si.due_date,
      si.issued_by_tenant_id,
      it.name AS issued_by_tenant_name
    FROM public.bills si
    LEFT JOIN public.tenants it ON it.id = si.issued_by_tenant_id
    WHERE si.profile_id = ANY(v_bp_ids)
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.due_amount > 0
    ORDER BY si.due_amount DESC, si.invoice_date DESC, si.id DESC
    LIMIT 50
  ) r;

  SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_recent_payments
  FROM (
    SELECT
      gp.id AS payment_id,
      gp.payment_date,
      gp.method,
      gp.amount,
      gp.unallocated_amount,
      gp.note,
      ip.global_invoice_id AS invoice_id,
      ip.amount AS allocated_amount
    FROM public.pays gp
    LEFT JOIN public.pay_allocations ip ON ip.payment_id = gp.id
    WHERE gp.profile_id = ANY(v_bp_ids)
    ORDER BY gp.payment_date DESC, gp.id DESC
    LIMIT 30
  ) r;

  SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_recent_ledger
  FROM (
    SELECT
      l.id,
      l.type,
      l.amount,
      l.balance_after,
      l.operating_tenant_id,
      l.source_type,
      l.source_id,
      l.created_at,
      l.metadata->>'transaction_type' AS transaction_type,
      coalesce(
        l.metadata->>'label',
        l.metadata->>'transaction_type',
        'Adjustment'
      ) AS label
    FROM public.cashbook_entries l
    WHERE l.parent_tenant_id = v_books_id
      AND l.entity_type = 'customer'
      AND l.entity_id = ANY(v_bp_ids)
    ORDER BY l.created_at DESC, l.id DESC
    LIMIT 30
  ) r;

  SELECT coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_shop_access
  FROM (
    SELECT
      s.id AS shop_id,
      s.name AS shop_name,
      s.shop_type::text AS shop_type,
      st.id AS shop_tenant_id,
      st.name AS shop_tenant_name,
      scga.status,
      scga.credit_limit_amount
    FROM public.shop_customer_group_access scga
    JOIN public.shops s ON s.id = scga.shop_id
    JOIN public.tenants st ON st.id = s.tenant_id
    WHERE scga.customer_group_id = p_customer_group_id
    ORDER BY st.name, s.name
    LIMIT 20
  ) r;

  RETURN jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'profile_id', v_profile_id,
    'still_due', v_still_due,
    'total_billed', v_total_billed,
    'collected_cash', v_collected_cash,
    'wallet_applied', v_wallet_applied,
    'settlement', v_settlement,
    'store_credit_balance', v_store_credit,
    'unallocated_payments', v_unallocated,
    'open_invoices', v_open_invoices,
    'recent_payments', v_recent_payments,
    'recent_ledger', v_recent_ledger,
    'shop_access', v_shop_access
  );
END;
$$;
