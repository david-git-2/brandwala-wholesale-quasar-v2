-- Payment history on bills: include settlement FX + BDT amounts for display.

CREATE OR REPLACE FUNCTION public.list_invoice_payment_history(p_tenant_id bigint, p_invoice_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent_id bigint;
  v_result jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_invoice_id IS NULL THEN
    RAISE EXCEPTION 'Tenant and invoice are required.';
  END IF;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT EXISTS (
    SELECT 1
    FROM public.bills si
    WHERE si.id = p_invoice_id
      AND (si.parent_tenant_id = v_parent_id OR si.issued_by_tenant_id = p_tenant_id)
  ) THEN
    RAISE EXCEPTION 'Invoice not found for this tenant.';
  END IF;

  SELECT coalesce(jsonb_agg(row_to_json(r) ORDER BY r.sort_at DESC, r.entry_id DESC), '[]'::jsonb)
  INTO v_result
  FROM (
    SELECT
      'allocation'::text AS entry_type,
      ip.id AS entry_id,
      gp.id AS payment_id,
      gp.payment_date,
      gp.payment_date::timestamptz AS sort_at,
      ip.amount AS amount,
      gp.amount AS receipt_amount,
      gp.voided_at,
      gp.method,
      gp.note,
      NULL::text AS write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') AS settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) AS exchange_rate,
      coalesce(
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            ORDER BY gpi.sort_order, gpi.id
          )
          FROM public.pay_instruments gpi
          LEFT JOIN public.bd_banks b ON b.id = gpi.bd_bank_id
          WHERE gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) AS instruments
    FROM public.pay_allocations ip
    JOIN public.pays gp ON gp.id = ip.payment_id
    WHERE ip.global_invoice_id = p_invoice_id

    UNION ALL

    SELECT
      'write_off'::text AS entry_type,
      iwo.id AS entry_id,
      iwo.payment_id,
      coalesce(gp.payment_date, iwo.created_at::date) AS payment_date,
      coalesce(gp.payment_date::timestamptz, iwo.created_at) AS sort_at,
      iwo.amount AS amount,
      coalesce(gp.amount, 0.00) AS receipt_amount,
      gp.voided_at,
      coalesce(gp.method, 'write_off') AS method,
      iwo.note,
      iwo.reason AS write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') AS settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) AS exchange_rate,
      CASE
        WHEN gp.id IS NULL THEN '[]'::jsonb
        ELSE coalesce(
          (
            SELECT jsonb_agg(
              jsonb_build_object(
                'id', gpi.id,
                'payment_method_code', gpi.payment_method_code,
                'amount', gpi.amount,
                'reference', gpi.reference,
                'bd_bank_id', gpi.bd_bank_id,
                'bank_name', b.name,
                'cheque_number', gpi.cheque_number,
                'cheque_date', gpi.cheque_date,
                'sort_order', gpi.sort_order
              )
              ORDER BY gpi.sort_order, gpi.id
            )
            FROM public.pay_instruments gpi
            LEFT JOIN public.bd_banks b ON b.id = gpi.bd_bank_id
            WHERE gpi.payment_id = gp.id
          ),
          '[]'::jsonb
        )
      END AS instruments
    FROM public.invoice_write_offs iwo
    LEFT JOIN public.pays gp ON gp.id = iwo.payment_id
    WHERE iwo.invoice_id = p_invoice_id
  ) r;

  RETURN v_result;
END;
$$;
