-- Desk bridge: expose kernel write-offs in net balances and payment history.

CREATE OR REPLACE FUNCTION public._desk_kernel_net_balances_json(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_b money_kernel.bills;
  v_credits numeric(18, 4);
  v_debits numeric(18, 4);
  v_credit_open numeric(18, 4);
BEGIN
  SELECT * INTO v_b FROM money_kernel.bills WHERE id = p_bill_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  SELECT COALESCE(SUM(total_amount) FILTER (WHERE kind = 'credit_note'), 0),
         COALESCE(SUM(total_amount) FILTER (WHERE kind = 'debit_note'), 0),
         COALESCE(SUM(due_amount) FILTER (WHERE kind = 'credit_note'), 0)
    INTO v_credits, v_debits, v_credit_open
  FROM money_kernel.bills
  WHERE parent_bill_id = p_bill_id
    AND tenant_id = v_b.tenant_id
    AND kind IN ('credit_note', 'debit_note')
    AND status NOT IN ('voided', 'draft');

  RETURN jsonb_build_object(
    'bill_id', v_b.id,
    'invoice_no', v_b.invoice_no,
    'original_total', v_b.total_amount,
    'paid_amount', v_b.paid_amount,
    'written_off_amount', COALESCE(v_b.written_off_amount, 0),
    'credits_issued', v_credits,
    'debits_issued', v_debits,
    'due_amount', v_b.due_amount,
    'open_books', v_b.due_amount,
    'open_txn', v_b.due_amount,
    'credit_open', v_credit_open,
    'document_kind', CASE
      WHEN v_b.kind IN ('credit_note', 'debit_note') THEN v_b.kind
      ELSE 'standard'
    END
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._desk_kernel_payment_history_json(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(row_obj ORDER BY sort_at DESC, entry_id DESC), '[]'::jsonb)
  FROM (
    SELECT
      jsonb_build_object(
        'entry_type', 'payment',
        'entry_id', bs.id,
        'payment_id', bs.pays_id,
        'payment_date', COALESCE(p.payment_date, bs.created_at::date),
        'amount', bs.allocated_amount,
        'receipt_amount', bs.allocated_amount,
        'voided_at', CASE WHEN p.status = 'voided' THEN p.updated_at ELSE NULL END,
        'method', NULL,
        'note', p.meta->>'note',
        'write_off_reason', NULL,
        'settlement_currency_code', p.currency_code,
        'foreign_amount', p.amount,
        'exchange_rate', p.exchange_rate,
        'instruments', '[]'::jsonb,
        'payment_source', 'kernel',
        'related_invoice_no', NULL,
        'related_document_kind', NULL
      ) AS row_obj,
      bs.created_at AS sort_at,
      bs.id AS entry_id
    FROM money_kernel.bill_settlements bs
    LEFT JOIN money_kernel.pays p ON p.id = bs.pays_id
    WHERE bs.bill_id = p_bill_id
      AND bs.tenant_id = p_tenant_id
      AND bs.settlement_kind = 'pay'

    UNION ALL

    SELECT
      jsonb_build_object(
        'entry_type', 'write_off',
        'entry_id', b.id,
        'payment_id', NULL,
        'payment_date', COALESCE(
          NULLIF(trim(b.meta->>'last_write_off_at'), '')::date,
          b.updated_at::date
        ),
        'amount', b.written_off_amount,
        'receipt_amount', 0,
        'voided_at', NULL,
        'method', 'write_off',
        'note', b.meta->>'last_write_off_reason',
        'write_off_reason', b.meta->>'last_write_off_reason',
        'settlement_currency_code', b.currency_code,
        'foreign_amount', NULL,
        'exchange_rate', 1,
        'instruments', '[]'::jsonb,
        'payment_source', 'kernel',
        'related_invoice_no', NULL,
        'related_document_kind', NULL
      ) AS row_obj,
      COALESCE(
        NULLIF(trim(b.meta->>'last_write_off_at'), '')::timestamptz,
        b.updated_at
      ) AS sort_at,
      b.id AS entry_id
    FROM money_kernel.bills b
    WHERE b.id = p_bill_id
      AND b.tenant_id = p_tenant_id
      AND COALESCE(b.written_off_amount, 0) > 0
  ) hist;
$$;