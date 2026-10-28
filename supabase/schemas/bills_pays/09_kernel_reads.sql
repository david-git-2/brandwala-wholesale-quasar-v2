-- BP10 + BP23: kernel read projections and list RPCs (source for migrations).

-- ---------------------------------------------------------------------------
-- _kernel_bill_open_components (shared open math for view + get_bill_net_balances)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_bill_open_components(p_root_bill_id bigint)
RETURNS TABLE (
  credits_issued numeric(12, 2),
  debits_issued numeric(12, 2),
  settled_books numeric(12, 2),
  open_books numeric(12, 2),
  open_txn numeric(12, 2),
  credit_open numeric(12, 2)
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_root public.bills;
  v_credits numeric(12, 2);
  v_debits numeric(12, 2);
  v_credit_due numeric(12, 2);
  v_settled numeric(12, 2);
  v_due numeric(12, 2);
  v_open_txn numeric(12, 2);
begin
  select * into v_root from public.bills where id = p_root_bill_id;
  if v_root.id is null then
    credits_issued := 0;
    debits_issued := 0;
    settled_books := 0;
    open_books := 0;
    open_txn := 0;
    credit_open := 0;
    return next;
    return;
  end if;

  select coalesce(sum(total_amount), 0.00), coalesce(sum(due_amount), 0.00)
  into v_credits, v_credit_due
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(bs.allocated_books_amount), 0.00) into v_settled
  from public.bill_settlements bs
  where bs.bill_id = v_root.id;

  v_due := greatest(coalesce(v_root.total_amount, 0) - v_settled - v_credits + v_debits, 0);

  v_open_txn := case
    when coalesce(v_root.txn_total_amount, v_root.total_amount) is not null
      and coalesce(v_root.books_exchange_rate, 1) > 0
    then greatest(
      coalesce(v_root.txn_total_amount, v_root.total_amount)
        - coalesce((
          select sum(bs.allocated_txn_amount)
          from public.bill_settlements bs
          where bs.bill_id = v_root.id
        ), 0),
      0
    )
    else v_due
  end;

  credits_issued := v_credits;
  debits_issued := v_debits;
  settled_books := v_settled;
  open_books := v_due;
  open_txn := v_open_txn;
  credit_open := v_credit_due;
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- v_kernel_bill_summaries (BP23)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW public.v_kernel_bill_summaries
WITH (security_invoker = true)
AS
SELECT
  b.id AS bill_id,
  b.parent_tenant_id,
  b.issued_by_tenant_id,
  b.source_type,
  b.source_id,
  b.source_key,
  b.document_kind,
  b.invoice_type,
  b.invoice_no,
  b.invoice_date,
  CASE
    WHEN b.invoice_status = 'voided'::public.global_invoice_status THEN 'voided'
    WHEN b.invoice_status IN (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) THEN 'draft'
    WHEN b.invoice_status = 'issued'::public.global_invoice_status THEN 'issued'
    ELSE 'draft'
  END AS lifecycle_status,
  b.payment_status::text AS settlement_status,
  coalesce(b.txn_currency_code, b.currency_code, 'BDT') AS txn_currency_code,
  coalesce(b.txn_total_amount, b.total_amount) AS txn_total_amount,
  coalesce(b.currency_code, 'BDT') AS currency_code,
  b.total_amount,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_books,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_txn, oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_txn,
  b.due_date,
  b.from_profile_id,
  b.to_profile_id,
  b.profile_id,
  b.parent_bill_id
FROM public.bills b
LEFT JOIN LATERAL public._kernel_bill_open_components(coalesce(b.parent_bill_id, b.id)) oc ON true;

-- ---------------------------------------------------------------------------
-- list_bills_for_source (BP10)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_bills_for_source(
  p_parent_tenant_id bigint,
  p_source_type text,
  p_source_id text,
  p_source_key text DEFAULT NULL,
  p_include_voided boolean DEFAULT false,
  p_ap_shipment_buckets_only boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_sid bigint;
  v_rows jsonb;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;
  if nullif(trim(coalesce(p_source_type, '')), '') is null then
    raise exception 'source_type is required';
  end if;
  if nullif(trim(coalesce(p_source_id, '')), '') is null then
    raise exception 'source_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  v_sid := nullif(trim(p_source_id), '')::bigint;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_type', b.invoice_type,
        'document_kind', b.document_kind,
        'ap_kind', b.ap_kind,
        'source_type', b.source_type,
        'source_id', b.source_id,
        'source_key', b.source_key,
        'invoice_status', b.invoice_status,
        'payment_status', b.payment_status,
        'total_amount', b.total_amount,
        'due_amount', b.due_amount,
        'parent_bill_id', b.parent_bill_id,
        'net_balances', public.get_bill_net_balances(b.id)
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.bills b
  where b.parent_tenant_id = v_parent_id
    and (p_include_voided or b.invoice_status <> 'voided'::public.global_invoice_status)
    and (
      (b.source_type = p_source_type and b.source_id = p_source_id)
      or (
        p_source_type = 'shipment_cost'
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and (
          (b.source_type = 'shipment_cost' and b.source_id = p_source_id)
          or (v_sid is not null and b.ap_shipment_id = v_sid)
        )
      )
      or (
        p_source_type = 'shop_order'
        and b.source_type = 'shop_order'
        and b.source_id = p_source_id
      )
    )
    and (p_source_key is null or b.source_key = p_source_key)
    and (
      not p_ap_shipment_buckets_only
      or coalesce(b.source_key, b.ap_kind) in (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      )
      or coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
    );

  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_pays_for_source (BP10)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_pays_for_source(
  p_parent_tenant_id bigint,
  p_source_type text,
  p_source_id text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_order_id bigint;
  v_rows jsonb;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);
  v_order_id := nullif(trim(p_source_id), '')::bigint;

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', p.id,
        'amount', p.amount,
        'unallocated_amount', p.unallocated_amount,
        'payment_date', p.payment_date,
        'method', p.method,
        'source', p.source,
        'profile_id', p.profile_id,
        'shop_order_id', p.shop_order_id,
        'voided_at', p.voided_at,
        'settlement_currency_code', p.settlement_currency_code,
        'foreign_amount', p.foreign_amount,
        'exchange_rate', p.exchange_rate,
        'quote_currency_code', p.quote_currency_code,
        'source_currency_code', p.source_currency_code,
        'transaction_rate', p.transaction_rate,
        'source_amount', p.source_amount
      )
      ORDER BY p.id DESC
    ),
    '[]'::jsonb
  )
  into v_rows
  from public.pays p
  where p.tenant_id = v_parent_id
    and p.voided_at is null
    and (
      (
        p_source_type = 'shop_order'
        and v_order_id is not null
        and p.shop_order_id = v_order_id
      )
      or exists (
        select 1
        from public.bill_settlements bs
        join public.bills b on b.id = bs.bill_id
        where bs.allocator_kind = 'pay'
          and bs.allocator_id = p.id
          and b.parent_tenant_id = v_parent_id
          and (
            (b.source_type = p_source_type and b.source_id = p_source_id)
            or (
              p_source_type = 'shipment_cost'
              and b.invoice_type = 'ap'::public.global_invoice_type
              and (
                (b.source_type = 'shipment_cost' and b.source_id = p_source_id)
                or (v_order_id is not null and b.ap_shipment_id = v_order_id)
              )
            )
          )
      )
    );

  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- list_open_on_profile (BP10)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_open_on_profile(
  p_parent_tenant_id bigint,
  p_profile_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_due_bills jsonb;
  v_open_credits jsonb;
  v_leftover jsonb;
begin
  if p_parent_tenant_id is null or p_profile_id is null then
    raise exception 'parent_tenant_id and profile_id are required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
  ) then
    raise exception 'not allowed';
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', s.bill_id,
        'invoice_no', s.invoice_no,
        'total_amount', s.total_amount,
        'open_books', s.open_books,
        'due_date', s.due_date,
        'invoice_type', s.invoice_type
      )
      ORDER BY s.bill_id DESC
    ),
    '[]'::jsonb
  )
  into v_due_bills
  from public.v_kernel_bill_summaries s
  where s.parent_tenant_id = v_parent_id
    and s.document_kind = 'standard'::public.bill_document_kind
    and s.lifecycle_status = 'issued'
    and s.open_books > 0
    and (
      s.profile_id = p_profile_id
      or s.from_profile_id = p_profile_id
      or s.to_profile_id = p_profile_id
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'bill_id', s.bill_id,
        'invoice_no', s.invoice_no,
        'due_amount', s.open_books,
        'parent_bill_id', s.parent_bill_id
      )
      ORDER BY s.bill_id DESC
    ),
    '[]'::jsonb
  )
  into v_open_credits
  from public.v_kernel_bill_summaries s
  where s.parent_tenant_id = v_parent_id
    and s.document_kind = 'credit_note'::public.bill_document_kind
    and s.lifecycle_status = 'issued'
    and s.open_books > 0
    and (
      s.profile_id = p_profile_id
      or s.from_profile_id = p_profile_id
      or s.to_profile_id = p_profile_id
    );

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'pay_id', p.id,
        'amount', p.amount,
        'unallocated_amount', p.unallocated_amount,
        'payment_date', p.payment_date,
        'source', p.source
      )
      ORDER BY p.id DESC
    ),
    '[]'::jsonb
  )
  into v_leftover
  from public.pays p
  where p.tenant_id = v_parent_id
    and p.profile_id = p_profile_id
    and p.voided_at is null
    and p.unallocated_amount > 0;

  return jsonb_build_object(
    'due_bills', v_due_bills,
    'open_credit_notes', v_open_credits,
    'pay_leftover', v_leftover
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- list_invoice_payment_history (settlements-first reads)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_invoice_payment_history(
  p_tenant_id bigint,
  p_invoice_id bigint
) RETURNS jsonb
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
      coalesce(bs.pay_allocation_id, bs.id) AS entry_id,
      gp.id AS payment_id,
      gp.payment_date,
      gp.payment_date::timestamptz AS sort_at,
      bs.allocated_books_amount AS amount,
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
    FROM public.bill_settlements bs
    JOIN public.pays gp ON gp.id = bs.allocator_id AND bs.allocator_kind = 'pay'
    WHERE bs.bill_id = p_invoice_id

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

GRANT SELECT ON public.v_kernel_bill_summaries TO authenticated;
GRANT SELECT ON public.v_kernel_bill_summaries TO service_role;

GRANT EXECUTE ON FUNCTION public._kernel_bill_open_components(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public._kernel_bill_open_components(bigint) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_bills_for_source(
  bigint, text, text, text, boolean, boolean
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_bills_for_source(
  bigint, text, text, text, boolean, boolean
) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_pays_for_source(bigint, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_pays_for_source(bigint, text, text) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_open_on_profile(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_open_on_profile(bigint, bigint) TO service_role;

GRANT EXECUTE ON FUNCTION public.list_invoice_payment_history(bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_invoice_payment_history(bigint, bigint) TO service_role;
