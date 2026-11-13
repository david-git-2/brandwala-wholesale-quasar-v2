-- Kernel profile activity rows: amount = BDT books_amount; foreign_amount = currency leg.

CREATE OR REPLACE FUNCTION public._kernel_profile_pay_row_json(
  py money_kernel.pays,
  p_viewed_profile_id bigint
) RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
  WITH prof AS (
    SELECT
      coalesce(
        py.from_profile_id,
        public._kernel_bundle_owner_profile_id(py.from_cash_bundle_id)
      ) AS from_pid,
      coalesce(
        py.to_profile_id,
        public._kernel_bundle_owner_profile_id(py.to_cash_bundle_id),
        CASE
          WHEN py.kind = 'payment' THEN (
            SELECT b.to_profile_id
              FROM money_kernel.bill_settlements bs
              JOIN money_kernel.bills b
                ON b.id = bs.bill_id AND b.tenant_id = py.tenant_id
             WHERE bs.pays_id = py.id
               AND bs.settlement_kind = 'pay'
             ORDER BY bs.id
             LIMIT 1
          )
          ELSE NULL
        END
      ) AS to_pid
  )
  SELECT jsonb_build_object(
    'id', py.id,
    'spine', 'kernel',
    'kernel_kind', py.kind,
    'payment_date', py.payment_date,
    'amount', coalesce(
      py.books_amount,
      round(
        py.amount * coalesce(nullif(py.books_rate, 0), py.exchange_rate, 1),
        4
      )
    ),
    'unallocated_amount', 0,
    'source', 'kernel_' || py.kind,
    'direction', CASE
      WHEN py.kind = 'deposit' THEN 'in'
      WHEN py.kind = 'withdrawal' THEN 'out'
      WHEN p_viewed_profile_id IS NOT NULL AND prof.from_pid = p_viewed_profile_id THEN 'out'
      ELSE 'in'
    END,
    'method', null,
    'reference', null,
    'note', coalesce(py.meta->>'note', py.meta->>'revert_reason'),
    'voided_at', null,
    'from_profile_id', prof.from_pid,
    'to_profile_id', prof.to_pid,
    'from_profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = prof.from_pid),
    'to_profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = prof.to_pid),
    'description', CASE py.kind
      WHEN 'deposit' THEN 'Deposit'
      WHEN 'withdrawal' THEN 'Withdrawal'
      WHEN 'transfer' THEN 'Transfer'
      ELSE py.kind
    END,
    'profile_id', p_viewed_profile_id,
    'profile_name', (SELECT pr.name FROM public.profiles pr WHERE pr.id = p_viewed_profile_id),
    'settlement_currency_code', coalesce(py.currency_code, 'BDT'),
    'foreign_amount', CASE
      WHEN upper(coalesce(py.currency_code, 'BDT')) <> 'BDT' THEN py.amount
      ELSE NULL
    END,
    'exchange_rate', coalesce(nullif(py.books_rate, 0), py.exchange_rate, 1),
    'reverted_at', py.meta->>'reverted_at',
    'revert_reason', py.meta->>'revert_reason',
    'is_reversal', (py.refs ? 'reverses_pays_id'),
    'reverses_pays_id', nullif(py.refs->>'reverses_pays_id', '')::bigint,
    'perspective', 'party'
  )
  FROM prof;
$$;
