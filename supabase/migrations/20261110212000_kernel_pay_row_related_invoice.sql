-- Activity list: show first allocated bill number on pay rows (AP payout → bill).
CREATE OR REPLACE FUNCTION public._kernel_pay_row_json(
  py public.pays,
  p_direction text,
  p_counterparty_name text DEFAULT NULL,
  p_perspective text DEFAULT 'party'
) RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO public
AS $$
  SELECT jsonb_build_object(
    'id', py.id,
    'payment_date', py.payment_date,
    'amount', py.amount,
    'unallocated_amount', coalesce(py.unallocated_amount, 0),
    'source', py.source,
    'direction', p_direction,
    'method', py.method,
    'reference', py.reference,
    'note', py.note,
    'voided_at', py.voided_at,
    'profile_id', py.profile_id,
    'profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id),
    'counterparty_name', coalesce(
      nullif(btrim(p_counterparty_name), ''),
      (SELECT pr.name FROM public.profiles pr WHERE pr.id = py.profile_id)
    ),
    'shop_order_id', py.shop_order_id,
    'settlement_currency_code', coalesce(py.settlement_currency_code, 'BDT'),
    'foreign_amount', py.foreign_amount,
    'exchange_rate', coalesce(py.exchange_rate, 1),
    'cashbook_point_id', py.cashbook_point_id,
    'cashbook_point_name', (
      SELECT cp.name FROM public.cashbook_points cp WHERE cp.id = py.cashbook_point_id
    ),
    'related_invoice_no', (
      SELECT b.invoice_no
      FROM public.pay_allocations pa
      INNER JOIN public.bills b ON b.id = pa.bill_id
      WHERE pa.payment_id = py.id
      ORDER BY pa.id ASC
      LIMIT 1
    ),
    'perspective', p_perspective
  );
$$;
