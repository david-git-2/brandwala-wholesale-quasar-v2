-- Redeploy bills/pays RPC bodies from supabase/schemas/bills_pays after phase 8c column rename.
-- Phase 5 migration left prosrc on parent_tenant_id; declarative schema uses tenant_id.

-- from schemas/bills_pays/06_bills_desk_wrappers.sql
-- Bills desk public API wrappers (delegate to legacy; do not ALTER 05_money_spine.sql)

CREATE OR REPLACE FUNCTION public.update_draft_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_update_compose_draft(p_tenant_id, p_bill_id, p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_bill(
  p_bill_id bigint,
  p_items jsonb DEFAULT NULL
)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.commit_wholesale_bill_stock(p_bill_id);
  return public._kernel_issue_wholesale_stock(p_bill_id, p_items);
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_retail_bill(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.post_sales_invoice(p_bill_id);
end;
$$;

GRANT EXECUTE ON FUNCTION public.update_draft_bill(bigint, bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_draft_bill(bigint, bigint, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO service_role;

GRANT EXECUTE ON FUNCTION public.issue_retail_bill(bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.issue_retail_bill(bigint) TO service_role;

CREATE OR REPLACE FUNCTION public.list_bills_desk_page(
  p_tenant_id bigint,
  p_issued_by_tenant_id bigint DEFAULT NULL,
  p_ar_side text DEFAULT NULL,
  p_invoice_status text DEFAULT NULL,
  p_payment_status text DEFAULT NULL,
  p_quick_filter text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_page_size integer DEFAULT 25,
  p_cursor bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_limit integer;
  v_data jsonb;
  v_fetched integer;
  v_has_more boolean := false;
  v_next_cursor bigint;
  v_search text;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  if not (
    public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
    or public.user_can_manage_books_tenant(v_parent_id)
    or (
      p_issued_by_tenant_id is not null
      and public.has_active_tenant_membership(p_issued_by_tenant_id)
      and public.membership_has_module_action(p_issued_by_tenant_id, 'global_invoice', 'view')
    )
  ) then
    raise exception 'Access denied';
  end if;

  v_limit := greatest(coalesce(p_page_size, 25), 1);
  v_search := nullif(trim(coalesce(p_search, '')), '');

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      b.id as sort_id,
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_date', b.invoice_date,
        'invoice_type', b.invoice_type,
        'invoice_status', b.invoice_status,
        'payment_status', b.payment_status,
        'lifecycle_status', coalesce(ks.lifecycle_status, 'draft'),
        'settlement_status', coalesce(ks.settlement_status, b.payment_status::text),
        'total_amount', b.total_amount,
        'due_amount', coalesce(ks.open_books, b.due_amount),
        'open_books', coalesce(ks.open_books, b.due_amount),
        'open_txn', coalesce(ks.open_txn, b.due_amount),
        'recipient_name', b.recipient_name,
        'profile_name', pr.name,
        'retail_billing_mode', b.retail_billing_mode,
        'channel_meta', b.channel_meta,
        'ap_kind', b.ap_kind,
        'document_kind', b.document_kind,
        'parent_bill_id', b.parent_bill_id
      ) as row_json
    from public.bills b
    left join public.profiles pr on pr.id = b.profile_id
    left join public.v_kernel_bill_summaries ks on ks.bill_id = b.id
    where
      (
        (p_ar_side = 'we_owe' and b.tenant_id = v_parent_id)
        or (
          coalesce(p_ar_side, '') is distinct from 'we_owe'
          and p_issued_by_tenant_id is not null
          and b.issued_by_tenant_id = p_issued_by_tenant_id
        )
        or (
          coalesce(p_ar_side, '') is distinct from 'we_owe'
          and p_issued_by_tenant_id is null
          and b.tenant_id = v_parent_id
        )
      )
      and (coalesce(p_ar_side, '') is distinct from 'we_owe' or b.invoice_type = 'ap'::public.global_invoice_type)
      and (coalesce(p_ar_side, '') is distinct from 'they_owe' or b.invoice_type <> 'ap'::public.global_invoice_type)
      and (
        coalesce(p_ar_side, '') is distinct from 'we_owe'
        or p_invoice_status is not null
        or b.invoice_status in ('draft', 'proforma_generated', 'issued')
      )
      and (p_payment_status is null or b.payment_status::text = p_payment_status)
      and (
        p_invoice_status is null
        or (
          p_invoice_status = 'draft'
          and b.invoice_status in ('draft', 'proforma_generated')
        )
        or (
          p_invoice_status <> 'draft'
          and b.invoice_status::text = p_invoice_status
        )
      )
      and (
        p_quick_filter is null
        or p_quick_filter = ''
        or (p_quick_filter = 'paid' and coalesce(ks.open_books, b.due_amount) <= 0 and b.invoice_status = 'issued'::public.global_invoice_status)
        or (p_quick_filter = 'unpaid' and coalesce(ks.open_books, b.due_amount) > 0 and b.invoice_status = 'issued'::public.global_invoice_status)
        or (p_quick_filter = 'paid' and b.invoice_status <> 'issued'::public.global_invoice_status and b.payment_status = 'paid')
        or (p_quick_filter = 'unpaid' and b.invoice_status <> 'issued'::public.global_invoice_status and b.payment_status <> 'paid')
      )
      and (p_cursor is null or b.id < p_cursor)
      and (
        v_search is null
        or b.invoice_no ilike '%' || v_search || '%'
        or b.recipient_name ilike '%' || v_search || '%'
        or (v_search ~ '^[0-9]+$' and b.id = v_search::bigint)
        or exists (
          select 1
          from public.profiles p2
          where p2.id = b.profile_id
            and p2.name ilike '%' || v_search || '%'
        )
      )
    order by b.id desc
    limit v_limit + 1
  ) q;

  v_fetched := coalesce(jsonb_array_length(v_data), 0);
  if v_fetched > v_limit then
    v_has_more := true;
    v_data := coalesce(
      (
        select jsonb_agg(elem order by (elem->>'id')::bigint desc)
        from (
          select elem
          from jsonb_array_elements(v_data) as elem
          limit v_limit
        ) trimmed
      ),
      '[]'::jsonb
    );
  end if;

  if coalesce(jsonb_array_length(v_data), 0) > 0 then
    v_next_cursor := (v_data->(jsonb_array_length(v_data) - 1)->>'id')::bigint;
  else
    v_next_cursor := null;
  end if;

  if not v_has_more then
    v_next_cursor := null;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public.list_bills_desk_page(
  bigint,
  bigint,
  text,
  text,
  text,
  text,
  text,
  integer,
  bigint
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.list_bills_desk_page(
  bigint,
  bigint,
  text,
  text,
  text,
  text,
  text,
  integer,
  bigint
) TO service_role;

CREATE OR REPLACE FUNCTION public.get_bill_detail_bundle(
  p_tenant_id bigint,
  p_bill_id bigint
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_parent_id bigint;
  v_bill public.bills;
  v_bill_json jsonb;
  v_adjustments jsonb := '[]'::jsonb;
  v_stock_items jsonb := '[]'::jsonb;
  v_bill_lines jsonb := '[]'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'Tenant and bill are required.';
  END IF;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
  IF v_bill.id IS NULL THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF NOT (v_bill.tenant_id = v_parent_id OR v_bill.issued_by_tenant_id = p_tenant_id) THEN
    RAISE EXCEPTION 'Invoice not found for this tenant.';
  END IF;

  v_bill_json := row_to_json(v_bill)::jsonb
    || jsonb_build_object(
      'profiles', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address,
          'color', p.accent_color
        )
        FROM public.profiles p
        WHERE p.id = v_bill.profile_id
      ),
      'from_profile', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        FROM public.profiles p
        WHERE p.id = v_bill.from_profile_id
      ),
      'to_profile', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        FROM public.profiles p
        WHERE p.id = v_bill.to_profile_id
      )
    );

  IF v_bill.document_kind = 'standard'::public.bill_document_kind THEN
    SELECT coalesce(jsonb_agg(row_to_json(adj)), '[]'::jsonb)
    INTO v_adjustments
    FROM public.list_bill_adjustments(p_bill_id) AS adj;
  END IF;

  IF v_bill.invoice_type <> 'ap'::public.global_invoice_type
    AND v_bill.document_kind IN (
      'standard'::public.bill_document_kind,
      'credit_note'::public.bill_document_kind,
      'debit_note'::public.bill_document_kind
    )
  THEN
    SELECT coalesce(jsonb_agg(row_to_json(li)), '[]'::jsonb)
    INTO v_stock_items
    FROM public.list_global_invoice_items(p_bill_id) AS li;
  END IF;

  IF v_bill.invoice_type = 'ap'::public.global_invoice_type
    OR v_bill.document_kind <> 'standard'::public.bill_document_kind
  THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', bl.id,
          'name_snapshot', bl.name_snapshot,
          'currency_code', upper(coalesce(bl.currency_code, 'BDT')),
          'line_total_amount', bl.line_total_amount,
          'books_amount', coalesce(bl.books_amount, bl.line_total_amount),
          'quantity', bl.quantity
        )
        ORDER BY bl.id
      ),
      '[]'::jsonb
    )
    INTO v_bill_lines
    FROM public.bill_lines bl
    WHERE bl.invoice_id = p_bill_id;
  END IF;

  RETURN jsonb_build_object(
    'bill', v_bill_json,
    'payment_history', public.list_invoice_payment_history(p_tenant_id, p_bill_id),
    'net_balances', public.get_bill_net_balances(p_bill_id),
    'adjustments', v_adjustments,
    'stock_items', v_stock_items,
    'bill_lines', v_bill_lines
  );
END;
$$;

-- from schemas/bills_pays/09_kernel_reads.sql
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
  b.tenant_id,
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
  p_tenant_id bigint,
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
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if nullif(trim(coalesce(p_source_type, '')), '') is null then
    raise exception 'source_type is required';
  end if;
  if nullif(trim(coalesce(p_source_id, '')), '') is null then
    raise exception 'source_id is required';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  if not (
    public.user_can_manage_books_tenant(v_parent_id)
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
  where b.tenant_id = v_parent_id
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
      or (
        p_source_type = 'shop_order'
        and b.source_type = 'delivery_close'
        and (
          (
            coalesce(b.channel_meta->>'document_type', '') = 'shop_order'
            and coalesce(b.channel_meta->>'document_id', '') = p_source_id
          )
          or exists (
            select 1
            from public.delivery_paper dp
            where dp.id::text = b.source_id
              and dp.source_type = 'shop_order'::public.delivery_paper_source_type
              and dp.source_id::text = p_source_id
          )
        )
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
  p_tenant_id bigint,
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
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_order_id := nullif(trim(p_source_id), '')::bigint;

  if not (
    public.user_can_manage_books_tenant(v_parent_id)
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
          and b.tenant_id = v_parent_id
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
  p_tenant_id bigint,
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
  if p_tenant_id is null or p_profile_id is null then
    raise exception 'tenant_id and profile_id are required';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  if not (
    public.user_can_manage_books_tenant(v_parent_id)
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
  where s.tenant_id = v_parent_id
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
  where s.tenant_id = v_parent_id
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

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  IF NOT EXISTS (
    SELECT 1
    FROM public.bills si
    WHERE si.id = p_invoice_id
      AND (si.tenant_id = v_parent_id OR si.issued_by_tenant_id = p_tenant_id)
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
      gp.reference AS payment_reference,
      gp.source AS payment_source,
      gp.cashbook_point_pot_id,
      gp.transaction_rate,
      gp.source_currency_code,
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
      gp.reference AS payment_reference,
      gp.source AS payment_source,
      gp.cashbook_point_pot_id,
      gp.transaction_rate,
      gp.source_currency_code,
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

-- ---------------------------------------------------------------------------
-- list_global_invoice_items (desk / bundle stock lines; use view for global_stock_id)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.list_global_invoice_items(p_invoice_id bigint)
RETURNS TABLE(
  id bigint,
  invoice_id bigint,
  global_stock_id bigint,
  name_snapshot text,
  quantity numeric,
  sell_price_amount numeric,
  recipient_price_amount numeric,
  line_face_total_amount numeric,
  line_discount_amount numeric,
  line_total_amount numeric,
  return_quantity numeric,
  image_url text,
  shipment_id bigint,
  shipment_item_id bigint,
  purchase_price numeric,
  product_weight numeric,
  package_weight numeric,
  ordered_quantity integer,
  shipment_type text,
  product_conversion_rate numeric,
  cargo_conversion_rate numeric,
  cargo_rate numeric,
  received_weight numeric,
  transaction_rate numeric,
  available_atp numeric,
  unit_cost_price numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_tenant_id bigint;
  v_issued_by bigint;
  v_invoice_status public.global_invoice_status;
BEGIN
  SELECT tenant_id, issued_by_tenant_id, invoice_status
  INTO v_books_tenant_id, v_issued_by, v_invoice_status
  FROM public.bills
  WHERE public.bills.id = p_invoice_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invoice with ID % not found', p_invoice_id;
  END IF;

  IF NOT (
    public.user_can_manage_books_tenant(v_books_tenant_id)
    OR public.has_active_tenant_membership(v_issued_by)
    OR public.membership_has_module_action(v_issued_by, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'Access denied for invoice with ID %', p_invoice_id;
  END IF;

  RETURN QUERY
  SELECT
    gii.id,
    gii.invoice_id,
    gii.global_stock_id,
    gii.name_snapshot,
    gii.quantity,
    gii.sell_price_amount,
    nullif(gii.line_meta->>'resell_price_amount', '')::numeric AS recipient_price_amount,
    (gii.quantity * nullif(gii.line_meta->>'resell_price_amount', '')::numeric) AS line_face_total_amount,
    gii.line_discount_amount,
    gii.line_total_amount,
    gii.return_quantity,
    CASE
      WHEN gii.line_kind = 'stock'::text THEN coalesce(gsi.image_url, p.image_url)
      ELSE NULL::text
    END AS image_url,
    gsi.shipment_id,
    gsi.id AS shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text AS shipment_type,
    NULL::numeric AS product_conversion_rate,
    NULL::numeric AS cargo_conversion_rate,
    NULL::numeric AS cargo_rate,
    gship.received_weight,
    NULL::numeric AS transaction_rate,
    CASE
      WHEN gii.global_stock_id IS NULL THEN 0::numeric
      WHEN v_invoice_status IN (
        'draft'::public.global_invoice_status,
        'proforma_generated'::public.global_invoice_status
      )
        THEN (
          coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0) + gii.quantity
        )::numeric
      ELSE (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0))::numeric
    END AS available_atp,
    coalesce(gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric AS unit_cost_price
  FROM public.global_invoice_items gii
  LEFT JOIN public.global_stocks gs ON gs.id = gii.global_stock_id
  LEFT JOIN public.global_shipment_items gsi
    ON gsi.id = coalesce(gii.shipment_item_id, gs.shipment_item_id)
  LEFT JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.products p ON p.id = gii.product_id
  WHERE gii.invoice_id = p_invoice_id
  ORDER BY gii.id;
END;
$$;

-- from schemas/bills_pays/05_money_spine.sql
-- Bills & pays money kernel spine (BP18–BP25, BP9, BP22 partial).
-- Applied via migration 20261027220000_bills_pays_money_spine.sql

-- ---------------------------------------------------------------------------
-- BP20: source plug unique (exclude voided)
-- ---------------------------------------------------------------------------
DROP INDEX IF EXISTS public.bills_source_plug_uidx;

CREATE UNIQUE INDEX IF NOT EXISTS uq_active_standard_bill
  ON public.bills (tenant_id, source_type, source_id, COALESCE(source_key, ''::text))
  WHERE document_kind = 'standard'::public.bill_document_kind
    AND source_type IS NOT NULL
    AND source_id IS NOT NULL
    AND invoice_status <> 'voided'::public.global_invoice_status;

-- ---------------------------------------------------------------------------
-- BP18: bill_settlements
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.bill_settlements (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id bigint NOT NULL REFERENCES public.tenants (id),
  bill_id bigint NOT NULL REFERENCES public.bills (id) ON DELETE RESTRICT,
  allocator_kind text NOT NULL CHECK (allocator_kind IN ('pay', 'credit_note', 'custody_entry')),
  allocator_id bigint NOT NULL,
  pay_allocation_id bigint REFERENCES public.pay_allocations (id),
  allocated_txn_amount numeric(12, 2) NOT NULL DEFAULT 0,
  allocated_books_amount numeric(12, 2) NOT NULL,
  books_rate_at_alloc numeric(15, 6),
  fx_realized_books_delta numeric(12, 2),
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.bill_settlements
  ADD COLUMN IF NOT EXISTS pay_allocation_id bigint REFERENCES public.pay_allocations (id);

CREATE UNIQUE INDEX IF NOT EXISTS bill_settlements_pay_allocation_uidx
  ON public.bill_settlements (pay_allocation_id)
  WHERE pay_allocation_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS bill_settlements_bill_id_idx ON public.bill_settlements (bill_id);
CREATE INDEX IF NOT EXISTS bill_settlements_allocator_idx
  ON public.bill_settlements (allocator_kind, allocator_id);

ALTER TABLE public.bill_settlements ENABLE ROW LEVEL SECURITY;

-- ---------------------------------------------------------------------------
-- BP19: txn face on bills (nullable until issue)
-- ---------------------------------------------------------------------------
ALTER TABLE public.bills
  ADD COLUMN IF NOT EXISTS txn_currency_code text,
  ADD COLUMN IF NOT EXISTS txn_total_amount numeric(12, 2),
  ADD COLUMN IF NOT EXISTS books_exchange_rate numeric(15, 6);

-- ---------------------------------------------------------------------------
-- BP25: pay idempotency
-- ---------------------------------------------------------------------------
ALTER TABLE public.pays ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS pays_tenant_idempotency_uidx
  ON public.pays (tenant_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

CREATE OR REPLACE FUNCTION public._kernel_claim_pay_idempotency(
  p_tenant_id bigint,
  p_key text
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_key text := nullif(btrim(p_key), '');
begin
  if v_key is null then
    return v_pay;
  end if;

  perform pg_advisory_xact_lock(
    hashtext('pay_idem:' || p_tenant_id::text || ':' || v_key)
  );

  select * into v_pay
  from public.pays p
  where p.tenant_id = p_tenant_id
    and p.idempotency_key = v_key
  limit 1;

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_finalize_pay_idempotency(
  p_pay_id bigint,
  p_tenant_id bigint,
  p_key text
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_key text := nullif(btrim(p_key), '');
begin
  if v_key is null then
    select * into v_pay from public.pays where id = p_pay_id;
    return v_pay;
  end if;

  begin
    update public.pays
    set idempotency_key = v_key
    where id = p_pay_id;
  exception
    when unique_violation then
      select * into v_pay
      from public.pays p
      where p.tenant_id = p_tenant_id
        and p.idempotency_key = v_key
      limit 1;
      return v_pay;
  end;

  select * into v_pay from public.pays where id = p_pay_id;
  return v_pay;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_resolve_bill_id_from_alloc(
  p_invoice_id bigint,
  p_global_invoice_id bigint,
  p_bill_id bigint
) RETURNS bigint
LANGUAGE sql IMMUTABLE AS $$
  SELECT COALESCE(p_bill_id, p_global_invoice_id, p_invoice_id);
$$;

CREATE OR REPLACE FUNCTION public._kernel_settlement_amounts_from_pay_alloc(
  p_bill public.bills,
  p_pay public.pays,
  p_alloc_books numeric
) RETURNS TABLE (
  allocated_txn_amount numeric,
  allocated_books_amount numeric,
  books_rate_at_alloc numeric,
  fx_realized_books_delta numeric
)
LANGUAGE plpgsql
STABLE
AS $$
declare
  v_books numeric(12, 2);
  v_txn numeric(12, 2);
  v_bill_rate numeric(15, 6);
  v_pay_rate numeric(15, 6);
  v_txn_ccy text;
  v_books_ccy text;
begin
  v_books := round(coalesce(p_alloc_books, 0), 2);
  v_bill_rate := coalesce(nullif(p_bill.books_exchange_rate, 0), 1.000000);
  v_txn_ccy := upper(btrim(coalesce(p_bill.txn_currency_code, p_bill.currency_code, 'BDT')));
  v_books_ccy := upper(btrim(coalesce(p_bill.currency_code, 'BDT')));

  if v_txn_ccy = v_books_ccy or v_bill_rate <= 0 then
    v_txn := v_books;
    v_pay_rate := 1.000000;
  else
    if p_pay.id is not null
       and upper(btrim(coalesce(p_pay.settlement_currency_code, 'BDT'))) <> v_books_ccy
       and coalesce(p_pay.exchange_rate, 0) > 0
    then
      v_txn := round(v_books / p_pay.exchange_rate, 2);
      v_pay_rate := p_pay.exchange_rate;
    else
      v_txn := round(v_books / v_bill_rate, 2);
      v_pay_rate := v_bill_rate;
    end if;
  end if;

  if v_txn > 0 then
    v_pay_rate := round(v_books / v_txn, 6);
  end if;

  return query
  select
    v_txn,
    v_books,
    v_pay_rate,
    v_books - round(v_txn * v_bill_rate, 2);
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_freeze_bill_txn_face(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_foreign numeric(12, 2);
  v_paper_ccy text;
  v_rate numeric(15, 6);
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    return;
  end if;

  v_foreign := public.ap_bill_channel_foreign_face(coalesce(v_bill.channel_meta, '{}'::jsonb));
  v_paper_ccy := public.ap_bill_channel_currency(coalesce(v_bill.channel_meta, '{}'::jsonb));

  if v_foreign is not null and v_foreign > 0 and v_paper_ccy is not null and btrim(v_paper_ccy) <> '' then
    v_rate := case
      when v_foreign > 0 then round(coalesce(v_bill.total_amount, 0) / v_foreign, 6)
      else 1.000000
    end;
    update public.bills
    set
      txn_currency_code = coalesce(txn_currency_code, upper(btrim(v_paper_ccy))),
      txn_total_amount = coalesce(txn_total_amount, v_foreign),
      books_exchange_rate = coalesce(books_exchange_rate, coalesce(nullif(v_rate, 0), 1.000000)),
      due_amount = case
        when invoice_status = 'issued'::public.global_invoice_status
          then greatest(coalesce(total_amount, 0) - coalesce(paid_amount, 0), 0)
        else due_amount
      end,
      updated_at = now()
    where id = p_bill_id;
  else
    update public.bills
    set
      txn_currency_code = coalesce(txn_currency_code, coalesce(currency_code, 'BDT')),
      txn_total_amount = coalesce(txn_total_amount, total_amount),
      books_exchange_rate = coalesce(books_exchange_rate, 1.000000),
      due_amount = case
        when invoice_status = 'issued'::public.global_invoice_status
         and coalesce(due_amount, 0) = 0
         and coalesce(total_amount, 0) > 0
          then total_amount
        else due_amount
      end,
      updated_at = now()
    where id = p_bill_id;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_record_pay_bill_settlement(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_bill_id bigint,
  p_books_amount numeric,
  p_update_unallocated boolean DEFAULT true
) RETURNS public.pay_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_pay public.pays;
  v_row public.pay_allocations;
  v_settle_id bigint;
  v_txn numeric(12, 2);
  v_books numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
  v_parent_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null or p_bill_id is null then
    raise exception 'Tenant, payment and bill are required.';
  end if;
  if coalesce(p_books_amount, 0) <= 0 then
    raise exception 'Settlement amount must be greater than zero.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_books := round(p_books_amount, 2);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'Bill not found.';
  end if;
  if v_bill.tenant_id <> v_parent_id then
    raise exception 'Bill tenant mismatch.';
  end if;

  select * into v_pay from public.pays where id = p_payment_id;
  if v_pay.id is null then
    raise exception 'Payment not found.';
  end if;
  if v_pay.tenant_id <> p_tenant_id then
    raise exception 'Payment tenant mismatch.';
  end if;

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, v_pay, v_books) sa;

  insert into public.bill_settlements (
    tenant_id,
    bill_id,
    allocator_kind,
    allocator_id,
    pay_allocation_id,
    allocated_txn_amount,
    allocated_books_amount,
    books_rate_at_alloc,
    fx_realized_books_delta
  ) values (
    v_bill.tenant_id,
    p_bill_id,
    'pay',
    p_payment_id,
    null,
    v_txn,
    v_books,
    v_rate,
    v_delta
  )
  returning id into v_settle_id;

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
  values (v_parent_id, p_payment_id, p_bill_id, p_bill_id, v_books)
  returning * into v_row;

  update public.bill_settlements
  set pay_allocation_id = v_row.id
  where id = v_settle_id;

  if p_update_unallocated then
    update public.pays
    set unallocated_amount = unallocated_amount - v_books
    where id = p_payment_id;
  end if;

  perform public.recompute_global_invoice_payment_status(p_bill_id);

  return v_row;
end;
$$;

-- Legacy trigger path retired at BP18-c cutover (settlements-first writer above).

CREATE OR REPLACE FUNCTION public._kernel_advisory_shipment_money_lock(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
begin
  if p_shipment_id is not null then
    perform pg_advisory_xact_lock(hashtext('shipment_money:' || p_shipment_id::text));
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_lock_bills(p_bill_ids bigint[])
RETURNS void
LANGUAGE plpgsql
AS $$
declare
  v_id bigint;
begin
  if p_bill_ids is null then
    return;
  end if;
  for v_id in
    select distinct u.x
    from unnest(p_bill_ids) as u(x)
    where u.x is not null
    order by u.x
  loop
    perform 1 from public.bills where id = v_id for update;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- BP22: pot sync on ledger insert
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_sync_pot_on_cashbook_entry()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_delta numeric(12, 2);
begin
  if NEW.cashbook_point_pot_id is null then
    return NEW;
  end if;

  v_delta := case when NEW.type = 'credit' then NEW.amount else -NEW.amount end;

  update public.cashbook_point_pots
  set amount = amount + v_delta
  where id = NEW.cashbook_point_pot_id;

  return NEW;
end;
$$;

DROP TRIGGER IF EXISTS trg_cashbook_entry_sync_pot ON public.cashbook_entries;
CREATE TRIGGER trg_cashbook_entry_sync_pot
  AFTER INSERT ON public.cashbook_entries
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_sync_pot_on_cashbook_entry();

-- ---------------------------------------------------------------------------
-- get_bill_net_balances (settlements-aware)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_bill_net_balances(p_bill_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_root public.bills;
  v_oc record;
  v_due numeric(12, 2);
  v_open_books numeric(12, 2);
  v_open_txn numeric(12, 2);
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  select * into v_root
  from public.bills
  where id = coalesce(v_bill.parent_bill_id, v_bill.id);

  select * into v_oc
  from public._kernel_bill_open_components(v_root.id) oc;

  v_due := coalesce(v_oc.open_books, 0);
  v_open_books := v_due;
  v_open_txn := coalesce(v_oc.open_txn, v_due);

  return jsonb_build_object(
    'bill_id', v_root.id,
    'invoice_no', v_root.invoice_no,
    'original_total', v_root.total_amount,
    'paid_amount', coalesce(v_oc.settled_books, 0),
    'credits_issued', coalesce(v_oc.credits_issued, 0),
    'debits_issued', coalesce(v_oc.debits_issued, 0),
    'due_amount', v_due,
    'open_books', v_open_books,
    'open_txn', v_open_txn,
    'credit_open', coalesce(v_oc.credit_open, 0),
    'document_kind', v_bill.document_kind
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- recompute_global_invoice_payment_status (settlements-aware; BP11 CN cross-apply)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_root_id bigint;
  v_total numeric(12, 2);
  v_paid numeric(12, 2);
  v_written_off numeric(12, 2);
  v_credits numeric(12, 2);
  v_debits numeric(12, 2);
  v_due numeric(12, 2);
  v_child record;
  v_child_paid numeric(12, 2);
  v_child_written_off numeric(12, 2);
  v_child_cross numeric(12, 2);
  v_child_due numeric(12, 2);
  v_child_total numeric(12, 2);
begin
  select * into v_bill from public.bills where id = p_global_invoice_id;
  if not found then return; end if;

  v_root_id := coalesce(v_bill.parent_bill_id, v_bill.id);

  select * into v_bill from public.bills where id = v_root_id for update;
  if not found then return; end if;

  select coalesce(sum(bs.allocated_books_amount), 0.00) into v_paid
  from public.bill_settlements bs
  where bs.bill_id = v_root_id;

  select coalesce(sum(amount), 0.00) into v_written_off
  from public.invoice_write_offs where invoice_id = v_root_id;

  select coalesce(sum(total_amount), 0.00) into v_credits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  v_total := coalesce(v_bill.total_amount, 0.00);
  v_due := greatest(v_total - v_paid - v_written_off - v_credits + v_debits, 0.00);

  update public.bills
  set
    paid_amount = v_paid,
    written_off_amount = v_written_off,
    due_amount = v_due,
    payment_status = case
      when v_due = 0.00 and v_written_off > 0.00 then 'settled_with_write_off'
      when v_due = 0.00 and v_paid > 0.00 then 'paid'
      when v_paid > 0.00 or v_written_off > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = v_root_id;

  for v_child in
    select id, document_kind, total_amount, invoice_status
    from public.bills
    where parent_bill_id = v_root_id
    order by id
  loop
    select coalesce(sum(bs.allocated_books_amount), 0.00) into v_child_paid
    from public.bill_settlements bs where bs.bill_id = v_child.id;

    select coalesce(sum(amount), 0.00) into v_child_written_off
    from public.invoice_write_offs where invoice_id = v_child.id;

    v_child_total := coalesce(v_child.total_amount, 0.00);
    v_child_cross := 0.00;
    if v_child.document_kind = 'credit_note'::public.bill_document_kind then
      select coalesce(sum(bs.allocated_books_amount), 0.00) into v_child_cross
      from public.bill_settlements bs
      where bs.allocator_kind = 'credit_note'
        and bs.allocator_id = v_child.id;
    end if;

    if v_child.invoice_status <> 'issued'::public.global_invoice_status then
      v_child_due := 0.00;
    elsif v_due = 0.00 and (v_written_off > 0.00 or v_paid > 0.00) then
      v_child_due := 0.00;
    else
      v_child_due := greatest(
        v_child_total - v_child_paid - v_child_written_off - v_child_cross,
        0.00
      );
    end if;

    update public.bills
    set
      paid_amount = v_child_paid,
      written_off_amount = v_child_written_off,
      due_amount = v_child_due,
      payment_status = case
        when v_child.invoice_status = 'voided'::public.global_invoice_status then 'due'
        when v_child_total <= 0.00 then 'paid'
        when v_child_due <= 0.00 and v_child_written_off > 0.00 then 'settled_with_write_off'
        when v_child_due <= 0.00 and v_due = 0.00 and v_written_off > 0.00 then 'settled_with_write_off'
        when v_child_due <= 0.00 and v_child_paid > 0.00 then 'paid'
        when v_child_paid > 0.00 then 'partially_paid'
        else 'due'
      end,
      updated_at = now()
    where id = v_child.id;
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- Shared pay leftover → bill (pay_allocations + settlements trigger)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_apply_pay_leftover_to_bill(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_bill_id bigint,
  p_amount numeric,
  p_allow_ap_payout boolean DEFAULT false
) RETURNS public.pay_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_payment public.pays;
  v_invoice public.bills;
  v_row public.pay_allocations;
  v_due numeric(12, 2);
  v_parent_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null or p_bill_id is null then
    raise exception 'Tenant, payment and bill are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  perform public._kernel_lock_bills(array[p_bill_id]);

  select * into v_payment from public.pays where id = p_payment_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if v_payment.tenant_id <> p_tenant_id then raise exception 'Payment tenant mismatch.'; end if;
  if v_payment.voided_at is not null then raise exception 'Payment is voided.'; end if;

  if p_allow_ap_payout then
    if v_payment.source not in ('customer_cash', 'bank', 'ap_payout') then
      raise exception 'Payment source % cannot apply leftover to bills.', v_payment.source;
    end if;
  elsif v_payment.source not in ('customer_cash', 'bank') then
    raise exception 'Only customer cash/bank leftover can be allocated later.';
  end if;

  select * into v_invoice from public.bills where id = p_bill_id;
  if not found then raise exception 'Bill not found.'; end if;
  if v_invoice.tenant_id <> v_parent_id then raise exception 'Bill tenant mismatch.'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill % is not issued', v_invoice.invoice_no;
  end if;
  if coalesce(v_invoice.document_kind, 'standard'::public.bill_document_kind)
    <> 'standard'::public.bill_document_kind then
    raise exception 'Leftover can only apply to standard bills.';
  end if;
  if v_invoice.parent_bill_id is not null then
    raise exception 'Leftover applies to the main bill, not adjustment notes.';
  end if;

  if coalesce(v_invoice.profile_id, 0) <> coalesce(v_payment.profile_id, 0) then
    raise exception 'Bill and payment billing profile mismatch.';
  end if;

  if p_amount > v_payment.unallocated_amount then
    raise exception 'Allocation amount % exceeds payment unallocated amount %.', p_amount, v_payment.unallocated_amount;
  end if;

  v_due := coalesce(
    (public.get_bill_net_balances(p_bill_id)->>'open_books')::numeric,
    (public.get_bill_net_balances(p_bill_id)->>'due_amount')::numeric,
    v_invoice.due_amount
  );
  if p_amount > v_due then
    raise exception 'Allocation amount % exceeds bill remaining due %.', p_amount, v_due;
  end if;

  v_row := public._kernel_record_pay_bill_settlement(
    p_tenant_id,
    p_payment_id,
    p_bill_id,
    p_amount,
    true
  );

  if v_payment.profile_id is not null
    and v_payment.source in ('customer_cash', 'bank') then
    perform public.record_ledger_transaction(
      p_tenant_id => p_tenant_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_payment.profile_id,
      p_type => 'debit',
      p_amount => p_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => p_payment_id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied leftover to bill',
        'payment_id', p_payment_id,
        'bill_id', p_bill_id
      )
    );
  end if;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- allocate_payment: legacy wrapper (customer cash/bank only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.allocate_payment_to_global_invoice(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_global_invoice_id bigint,
  p_amount numeric
) RETURNS public.pay_allocations
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_apply_pay_leftover_to_bill(
    p_tenant_id,
    p_payment_id,
    p_global_invoice_id,
    p_amount,
    false
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- BP9: issue_bill / void_bill / upsert_draft_bill (minimal kernel)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.issue_bill(p_bill_id bigint)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
begin
  select * into v_bill from public.bills where id = p_bill_id for update;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;
  if v_bill.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft bills can be issued';
  end if;

  if v_bill.ap_shipment_id is not null
     and v_bill.invoice_type = 'ap'::public.global_invoice_type then
    perform public._assert_shipment_ap_issue_allowed(v_bill.ap_shipment_id);
  elsif v_bill.invoice_type = 'ap'::public.global_invoice_type
    and v_bill.source_type = 'shipment_cost'
    and nullif(trim(v_bill.source_id), '') is not null then
    perform public._assert_shipment_ap_issue_allowed(nullif(trim(v_bill.source_id), '')::bigint);
  end if;

  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    due_amount = total_amount,
    paid_amount = 0,
    payment_status = 'due',
    updated_at = now()
  where id = p_bill_id
  returning * into v_bill;

  perform public._kernel_freeze_bill_txn_face(p_bill_id);
  select * into v_bill from public.bills where id = p_bill_id;

  return v_bill;
end;
$$;

CREATE OR REPLACE FUNCTION public.void_bill(p_bill_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.void_sales_invoice(p_bill_id);
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_draft_bill(p_payload jsonb)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_tenant_id bigint;
  v_result jsonb;
  v_bill public.bills;
  v_bill_id bigint;
begin
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if coalesce(p_payload->>'adapter', '') = 'shipment_cost' then
    v_bill_id := public._upsert_shipment_ap_bill(
      nullif(p_payload->>'tenant_id', '')::bigint,
      nullif(p_payload->>'issued_by_tenant_id', '')::bigint,
      nullif(p_payload->>'shipment_id', '')::bigint,
      p_payload->>'shipment_name',
      p_payload->>'ap_kind',
      nullif(p_payload->>'profile_id', '')::bigint,
      nullif(p_payload->>'amount', '')::numeric,
      coalesce(p_payload->'ap_paper', '{}'::jsonb),
      coalesce((p_payload->>'keep_as_draft')::boolean, true),
      nullif(p_payload->>'source_key', '')
    );
    if v_bill_id is null then
      raise exception 'shipment AP upsert returned no bill';
    end if;
    select * into v_bill from public.bills where id = v_bill_id;
    return v_bill;
  end if;

  if coalesce(p_payload->>'adapter', '') = 'dropship_courier' then
    v_result := public._kernel_upsert_dropship_courier_ap(
      nullif(p_payload->>'order_id', '')::bigint,
      coalesce((p_payload->>'keep_as_draft')::boolean, false)
    );
    if coalesce(v_result->>'success', 'false') <> 'true' then
      raise exception '%', coalesce(v_result->>'error', 'dropship courier AP upsert failed');
    end if;
    select * into v_bill from public.bills where id = (v_result->>'bill_id')::bigint;
    if v_bill.id is null then
      raise exception 'dropship courier AP bill missing after upsert';
    end if;
    return v_bill;
  end if;

  if coalesce(p_payload->>'adapter', '') = 'shop_order'
    or nullif(p_payload->>'shop_order_id', '') is not null then
    return public._kernel_upsert_shop_order_draft(p_payload);
  end if;

  return public._kernel_upsert_compose_draft(p_payload);
end;
$$;

-- ---------------------------------------------------------------------------
-- Pay kernel wrappers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.post_money_in(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_received_on date,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_source text DEFAULT 'customer_cash',
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_shop_order_id bigint DEFAULT NULL,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
begin
  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_received_on,
    p_note,
    p_reference,
    p_source,
    p_instruments,
    p_allocations,
    p_shop_order_id,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    true,
    p_idempotency_key,
    p_cashbook_point_id,
    p_cashbook_point_pot_id,
    p_source_currency_code,
    p_transaction_rate
  );

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public.post_money_out(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_source text DEFAULT 'ap_payout',
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_type text DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_payout_method text DEFAULT 'bank_transfer'
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
begin
  if coalesce(p_source_type, '') = 'commission' or p_source = 'commission' then
    return public._kernel_post_commission_payout(
      p_tenant_id,
      p_profile_id,
      p_paid_on,
      p_amount,
      p_note,
      p_reference,
      p_payout_method,
      p_cashbook_point_id,
      p_cashbook_point_pot_id,
      p_source_id,
      p_idempotency_key
    );
  end if;

  if p_cashbook_point_id is null then
    raise exception 'cashbook_point_id required for pay out';
  end if;

  v_pay := public.post_ap_payout_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cashbook_point_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    null,
    null,
    null,
    p_idempotency_key
  );

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public.apply_settlement_to_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_allocator_kind text,
  p_allocator_id bigint,
  p_books_amount numeric
) RETURNS public.bill_settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_cn public.bills;
  v_row public.bill_settlements;
  v_alloc public.pay_allocations;
  v_txn numeric(12, 2);
  v_books numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
  v_parent_id bigint;
  v_target_due numeric(12, 2);
  v_cn_open numeric(12, 2);
begin
  if not public.membership_has_module_action(p_tenant_id, 'payments', 'allocate_payment') then
    raise exception 'Permission denied.';
  end if;
  if coalesce(p_books_amount, 0) <= 0 then
    raise exception 'Settlement amount must be greater than zero.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  if p_allocator_kind = 'pay' then
    perform public._kernel_lock_bills(array[p_bill_id]);
    v_alloc := public._kernel_apply_pay_leftover_to_bill(
      p_tenant_id,
      p_allocator_id,
      p_bill_id,
      p_books_amount,
      true
    );
    select bs.* into v_row
    from public.bill_settlements bs
    where bs.pay_allocation_id = v_alloc.id;
    if v_row.id is null then
      raise exception 'Settlement row missing after pay allocation.';
    end if;
    return v_row;
  end if;

  if p_allocator_kind = 'custody_entry' then
    return public._kernel_apply_custody_to_bill(p_tenant_id, p_bill_id, p_books_amount);
  end if;

  if p_allocator_kind <> 'credit_note' then
    raise exception 'Unsupported allocator_kind %.', p_allocator_kind;
  end if;

  perform public._kernel_lock_bills(array[p_bill_id, p_allocator_id]);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then raise exception 'Target bill not found.'; end if;
  if v_bill.tenant_id <> v_parent_id then raise exception 'Target bill tenant mismatch.'; end if;
  if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Target bill is not issued.';
  end if;
  if coalesce(v_bill.document_kind, 'standard'::public.bill_document_kind)
    <> 'standard'::public.bill_document_kind then
    raise exception 'Credit can only apply to standard bills.';
  end if;
  if v_bill.parent_bill_id is not null then
    raise exception 'Credit applies to a main bill, not adjustment notes.';
  end if;

  select * into v_cn from public.bills where id = p_allocator_id;
  if v_cn.id is null then raise exception 'Credit note not found.'; end if;
  if v_cn.tenant_id <> v_parent_id then raise exception 'Credit note tenant mismatch.'; end if;
  if v_cn.document_kind <> 'credit_note'::public.bill_document_kind then
    raise exception 'Allocator is not a credit note.';
  end if;
  if v_cn.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Credit note is not issued.';
  end if;
  if coalesce(v_cn.profile_id, 0) <> coalesce(v_bill.profile_id, 0) then
    raise exception 'Credit note and target bill profile mismatch.';
  end if;

  perform public.recompute_global_invoice_payment_status(v_cn.id);
  select * into v_cn from public.bills where id = p_allocator_id;
  v_cn_open := coalesce(v_cn.due_amount, 0.00);
  if p_books_amount > v_cn_open then
    raise exception 'Amount % exceeds open credit note balance %.', p_books_amount, v_cn_open;
  end if;

  v_target_due := coalesce(
    (public.get_bill_net_balances(p_bill_id)->>'open_books')::numeric,
    (public.get_bill_net_balances(p_bill_id)->>'due_amount')::numeric,
    v_bill.due_amount
  );
  if p_books_amount > v_target_due then
    raise exception 'Amount % exceeds target bill due %.', p_books_amount, v_target_due;
  end if;

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, null, p_books_amount) sa;

  insert into public.bill_settlements (
    tenant_id, bill_id, allocator_kind, allocator_id,
    allocated_txn_amount, allocated_books_amount, books_rate_at_alloc, fx_realized_books_delta
  ) values (
    v_bill.tenant_id, p_bill_id, p_allocator_kind, p_allocator_id,
    v_txn, v_books, v_rate, v_delta
  )
  returning * into v_row;

  perform public.recompute_global_invoice_payment_status(p_bill_id);
  if v_cn.parent_bill_id is not null then
    perform public.recompute_global_invoice_payment_status(v_cn.parent_bill_id);
  else
    perform public.recompute_global_invoice_payment_status(v_cn.id);
  end if;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.reverse_pay(p_payment_id bigint, p_reason text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_reason text;
begin
  select * into v_pay from public.pays where id = p_payment_id;
  if v_pay.id is null then
    raise exception 'Payment not found.';
  end if;
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;
  perform public._kernel_reverse_payment(v_pay.tenant_id, p_payment_id, v_reason);
end;
$$;

-- Block silent issued total edits
CREATE OR REPLACE FUNCTION public.apply_global_invoice_target_total(
  p_invoice_id bigint,
  p_target_total numeric,
  p_dry_run boolean DEFAULT false
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  raise exception 'apply_global_invoice_target_total is retired; use credit_note or debit_note on the bill';
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_ensure_cashbook_point_pot(
  p_tenant_id bigint,
  p_cashbook_point_id bigint,
  p_currency_code text
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
begin
  if p_cashbook_point_id is null then
    return null;
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  insert into public.cashbook_point_pots (
    tenant_id, cashbook_point_id, currency_code, amount
  ) values (
    p_tenant_id, p_cashbook_point_id, v_ccy, 0
  )
  on conflict (cashbook_point_id, currency_code)
  do update set updated_at = now()
  returning id into v_id;

  return v_id;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_lock_cashbook_point_pots(p_cashbook_point_id bigint)
RETURNS void
LANGUAGE plpgsql
AS $$
declare
  v_id bigint;
begin
  if p_cashbook_point_id is null then
    return;
  end if;
  for v_id in
    select cpp.id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
    order by cpp.currency_code asc, cpp.id asc
  loop
    perform 1 from public.cashbook_point_pots where id = v_id for update;
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_lock_cashbook_points_for_transfer(
  p_from_point_id bigint,
  p_to_point_id bigint,
  p_currency_code text
)
RETURNS void
LANGUAGE plpgsql
AS $$
declare
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
  v_first bigint;
  v_second bigint;
begin
  if p_from_point_id is null or p_to_point_id is null then
    raise exception 'Both cash points are required.';
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  if p_from_point_id < p_to_point_id then
    v_first := p_from_point_id;
    v_second := p_to_point_id;
  else
    v_first := p_to_point_id;
    v_second := p_from_point_id;
  end if;

  perform 1
  from public.cashbook_point_pots cpp
  where cpp.cashbook_point_id = v_first
    and upper(trim(cpp.currency_code)) = v_ccy
  order by cpp.id
  for update;

  perform 1
  from public.cashbook_point_pots cpp
  where cpp.cashbook_point_id = v_second
    and upper(trim(cpp.currency_code)) = v_ccy
  order by cpp.id
  for update;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_deny_cashbook_entry_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
begin
  if coalesce(current_setting('role', true), '') = 'service_role'
     or current_user in ('postgres', 'supabase_admin') then
    if TG_OP = 'DELETE' then
      return OLD;
    end if;
    return NEW;
  end if;
  raise exception 'cashbook_entries are append-only; post a reversing entry instead';
end;
$$;

DROP TRIGGER IF EXISTS trg_cashbook_entries_immutable ON public.cashbook_entries;
CREATE TRIGGER trg_cashbook_entries_immutable
  BEFORE UPDATE OR DELETE ON public.cashbook_entries
  FOR EACH ROW
  EXECUTE FUNCTION public._kernel_deny_cashbook_entry_mutation();

REVOKE UPDATE, DELETE ON TABLE public.cashbook_entries FROM authenticated;

GRANT SELECT, INSERT ON public.bill_settlements TO authenticated;
GRANT ALL ON public.bill_settlements TO service_role;

-- from schemas/bills_pays/07_shipment_ap_upsert.sql
-- Shipment AP draft upsert (sync adapter). Called from sync_shipment_ap_bills / upsert_draft_bill adapter.

CREATE OR REPLACE FUNCTION public._upsert_shipment_ap_bill(
  p_tenant_id bigint,
  p_issued_by_tenant_id bigint,
  p_shipment_id bigint,
  p_shipment_name text,
  p_ap_kind text,
  p_profile_id bigint,
  p_amount numeric,
  p_ap_paper jsonb DEFAULT NULL,
  p_keep_as_draft boolean DEFAULT false,
  p_source_key text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_old_total numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
  v_plug_key text;
  v_face_currency text;
  v_base_note text;
  v_note text;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  v_plug_key := coalesce(nullif(btrim(p_source_key), ''), p_ap_kind);
  v_face_currency := upper(trim(coalesce(p_ap_paper->>'currency_code', 'BDT')));

  select * into v_bill
  from public.bills b
  where b.tenant_id = p_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.source_type = 'shipment_cost'
    and b.source_id = p_shipment_id::text
    and b.source_key = v_plug_key
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status in (
         'issued'::public.global_invoice_status,
         'draft'::public.global_invoice_status
       ) then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_kind_label := initcap(replace(p_ap_kind, '_', ' '));
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

  v_base_note := format(
    'Shipment %s — %s AP%s',
    coalesce(p_shipment_name, p_shipment_id::text),
    v_kind_label,
    case when v_plug_key <> p_ap_kind then ' (' || v_plug_key || ')' else '' end
  );

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(
      p_issued_by_tenant_id,
      'ap'::public.global_invoice_type,
      current_date
    );
    insert into public.bills (
      tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      p_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind, 'shipment_cost', p_shipment_id::text, v_plug_key, v_face_currency,
      v_base_note,
      v_meta_base,
      'standard'::public.bill_document_kind
    )
    returning id into v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) = 0
       and not exists (
         select 1 from public.bill_settlements bs where bs.bill_id = v_bill.id
       )
       and p_ap_paper is not null then
      update public.bills
      set
        channel_meta = coalesce(channel_meta, '{}'::jsonb)
          || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
          || jsonb_build_object('ap_paper', p_ap_paper),
        updated_at = now()
      where id = v_bill.id;
    end if;
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return v_bill.id;
    end if;

    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = p_profile_id,
      subtotal_amount = v_target,
      total_amount = v_target,
      due_amount = v_target,
      payment_status = 'due',
      source_type = coalesce(source_type, 'shipment_cost'),
      source_id = coalesce(source_id, p_shipment_id::text),
      source_key = coalesce(source_key, v_plug_key),
      currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
      note = v_base_note,
      channel_meta = coalesce(channel_meta, '{}'::jsonb)
        || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
        || case
          when p_ap_paper is not null then jsonb_build_object('ap_paper', p_ap_paper)
          else '{}'::jsonb
        end,
      updated_at = now()
    where id = v_bill.id;

    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  v_old_total := round(coalesce(v_bill.total_amount, 0), 2);
  v_note := coalesce(nullif(trim(v_bill.note), ''), v_base_note);
  if v_old_total is distinct from v_target then
    v_note := v_note || format(
      E'\nCost sync %s: %s → %s %s',
      to_char(current_date, 'YYYY-MM-DD'),
      v_old_total,
      v_target,
      v_face_currency
    );
  end if;

  v_due := greatest(v_target - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = p_profile_id,
    subtotal_amount = v_target,
    total_amount = v_target,
    due_amount = v_due,
    payment_status = v_status,
    source_type = coalesce(source_type, 'shipment_cost'),
    source_id = coalesce(source_id, p_shipment_id::text),
    source_key = coalesce(source_key, v_plug_key),
    currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
    note = v_note,
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  perform public.stamp_bill_kernel_fields(v_bill.id);
  return v_bill.id;
end;
$$;

-- from schemas/bills_pays/03_adjustments.sql
-- Credit/debit notes on standard bills (BP8). Source for migrations; live copy also in baseline until full split.

CREATE OR REPLACE FUNCTION public.create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true,
  p_refund_amount numeric DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_lines jsonb DEFAULT '[]'::jsonb
) RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent public.bills;
  v_kind public.bill_document_kind;
  v_row public.bills;
  v_no text;
  v_reason text;
  v_amount numeric(12, 2);
  v_status public.global_invoice_status;
  v_refund numeric(12, 2);
  v_child_due numeric(12, 2);
  v_pay public.pays;
  v_pay_source text;
  v_line_elem jsonb;
  v_line_total numeric(12, 2);
  v_books numeric(12, 2);
  v_line_kind text;
  v_stock_id bigint;
  v_pot_id bigint;
  v_lines_sum numeric(12, 2) := 0.00;
begin
  if p_parent_bill_id is null then
    raise exception 'parent_bill_id is required';
  end if;

  v_kind := case lower(trim(coalesce(p_kind, '')))
    when 'credit_note' then 'credit_note'::public.bill_document_kind
    when 'credit' then 'credit_note'::public.bill_document_kind
    when 'debit_note' then 'debit_note'::public.bill_document_kind
    when 'debit' then 'debit_note'::public.bill_document_kind
    else null
  end;
  if v_kind is null then
    raise exception 'kind must be credit_note or debit_note';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'reason is required';
  end if;

  select * into v_parent from public.bills where id = p_parent_bill_id for update;
  if v_parent.id is null then
    raise exception 'bill not found';
  end if;
  if v_parent.document_kind <> 'standard'::public.bill_document_kind then
    raise exception 'adjustments must attach to a standard bill';
  end if;
  if v_parent.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'parent bill must be issued';
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent.tenant_id)
    or public.membership_has_module_action(v_parent.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' and jsonb_array_length(p_lines) > 0 then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_lines_sum := v_lines_sum + v_books;
    end loop;
    v_amount := round(v_lines_sum, 2);
  else
    v_amount := round(coalesce(p_amount, 0), 2);
  end if;

  if v_amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  v_no := public.next_document_number(
    v_parent.issued_by_tenant_id,
    case
      when v_kind = 'credit_note'::public.bill_document_kind then 'credit_note'
      else 'debit_note'
    end,
    public.map_global_invoice_type_to_sub_type(v_parent.invoice_type),
    (current_date::timestamp AT TIME ZONE public._document_number_tenant_timezone(v_parent.issued_by_tenant_id, 'UTC'))
  );

  v_status := case
    when coalesce(p_issue, true) then 'issued'::public.global_invoice_status
    else 'draft'::public.global_invoice_status
  end;

  insert into public.bills (
    tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    invoice_status,
    profile_id,
    collection_source,
    payment_status,
    subtotal_amount,
    total_amount,
    due_amount,
    paid_amount,
    note,
    document_kind,
    parent_bill_id,
    ap_shipment_id,
    ap_kind,
    channel_meta
  ) values (
    v_parent.tenant_id,
    v_parent.issued_by_tenant_id,
    v_no,
    v_parent.invoice_type,
    current_date,
    v_status,
    v_parent.profile_id,
    v_parent.collection_source,
    'due',
    v_amount,
    v_amount,
    v_amount,
    0,
    v_reason,
    v_kind,
    v_parent.id,
    v_parent.ap_shipment_id,
    v_parent.ap_kind,
    jsonb_build_object(
      'adjustment', jsonb_build_object(
        'kind', v_kind::text,
        'reason', v_reason,
        'parent_invoice_no', v_parent.invoice_no
      )
    )
  )
  returning * into v_row;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_line_kind := lower(trim(coalesce(v_line_elem ->> 'line_kind', 'description')));
      if v_line_kind not in ('stock', 'description', 'charge') then
        v_line_kind := 'description';
      end if;
      v_stock_id := nullif(trim(coalesce(v_line_elem ->> 'global_stock_id', '')), '')::bigint;

      insert into public.bill_lines (
        tenant_id,
        invoice_id,
        line_kind,
        name_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        currency_code,
        books_amount,
        line_meta
      ) values (
        v_parent.tenant_id,
        v_row.id,
        v_line_kind,
        coalesce(nullif(trim(coalesce(v_line_elem ->> 'name_snapshot', '')), ''), 'Adjustment line'),
        greatest(coalesce((v_line_elem ->> 'quantity')::numeric, 1.000), 0.001),
        v_line_total,
        0.00,
        v_line_total,
        upper(trim(coalesce(v_line_elem ->> 'currency_code', 'BDT'))),
        v_books,
        coalesce(v_line_elem -> 'line_meta', '{}'::jsonb)
          || case
            when v_stock_id is not null
            then jsonb_build_object(
              'stock_ref',
              jsonb_build_object('global_stock_id', v_stock_id)
            )
            else '{}'::jsonb
          end
          || case
            when nullif(trim(coalesce(v_line_elem ->> 'parent_line_id', '')), '') is not null
            then jsonb_build_object('parent_line_id', v_line_elem ->> 'parent_line_id')
            else '{}'::jsonb
          end
      );
    end loop;
  end if;

  perform public.stamp_bill_kernel_fields(v_row.id);

  if v_status = 'issued'::public.global_invoice_status then
    perform public.recompute_global_invoice_payment_status(v_parent.id);
    select * into v_row from public.bills where id = v_row.id;
  end if;

  v_refund := round(coalesce(p_refund_amount, 0), 2);
  if v_refund > 0 then
    if v_kind <> 'credit_note'::public.bill_document_kind then
      raise exception 'Cash refund applies only to credit notes';
    end if;
    if v_parent.profile_id is null then
      raise exception 'Bill has no profile for refund';
    end if;
    if p_cashbook_point_id is null then
      raise exception 'Choose a cash point for the refund';
    end if;
    if not exists (
      select 1
      from public.cashbook_points cp
      join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
      where cp.id = p_cashbook_point_id
        and cp.is_active = true
        and ca.tenant_id = v_parent.tenant_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent.tenant_id
    ) then
      raise exception 'Invalid cash point for this tenant';
    end if;

    v_child_due := coalesce(v_row.due_amount, 0.00);
    if v_refund > v_child_due then
      raise exception 'Refund % exceeds open credit % on the note', v_refund, v_child_due;
    end if;

    v_pay_source := case
      when v_parent.invoice_type = 'ap'::public.global_invoice_type then 'ap_payout'
      else 'customer_cash'
    end;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      v_parent.tenant_id,
      p_cashbook_point_id,
      'BDT'
    );

    insert into public.pays (
      tenant_id,
      profile_id,
      source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      note,
      cashbook_point_id,
      cashbook_point_pot_id,
      source_currency_code,
      transaction_rate
    ) values (
      v_parent.tenant_id,
      v_parent.profile_id,
      v_pay_source,
      v_refund,
      0,
      current_date,
      'cash',
      v_reason,
      p_cashbook_point_id,
      v_pot_id,
      'BDT',
      1.000000
    )
    returning * into v_pay;

    insert into public.pay_instruments (
      payment_id,
      payment_method_code,
      amount,
      sort_order,
      cashbook_point_id
    ) values (
      v_pay.id,
      'CASH',
      v_refund,
      1,
      p_cashbook_point_id
    );

    perform public._kernel_record_pay_bill_settlement(
      v_parent.tenant_id,
      v_pay.id,
      v_row.id,
      v_refund,
      false
    );

    perform public.recompute_global_invoice_payment_status(v_parent.id);

    perform public.record_ledger_transaction(
      p_tenant_id => v_parent.tenant_id,
      p_operating_tenant_id => v_parent.issued_by_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent.tenant_id,
      p_type => 'debit',
      p_amount => v_refund,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'credit_note_refund',
        'transaction_type', 'credit_note_cash_refund',
        'label', case
          when v_parent.invoice_type = 'ap'::public.global_invoice_type
          then 'Vendor credit note cash refund'
          else 'Customer credit note cash refund'
        end,
        'payment_id', v_pay.id,
        'credit_note_id', v_row.id,
        'credit_note_no', v_row.invoice_no,
        'parent_bill_id', v_parent.id,
        'parent_invoice_no', v_parent.invoice_no,
        'cashbook_point_pot_id', v_pot_id,
        'source_currency_code', coalesce(v_pay.source_currency_code, 'BDT'),
        'transaction_rate', coalesce(v_pay.transaction_rate, 1.000000)
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => p_cashbook_point_id
    );

    select * into v_row from public.bills where id = v_row.id;
  elsif p_cashbook_point_id is not null and coalesce(p_refund_amount, 0) <= 0 then
    raise exception 'Refund amount is required when a cash point is selected';
  end if;

  return v_row;
end;
$$;

-- from schemas/bills_pays/10_returns_kernel.sql
-- BP5: returns issue credit notes; parent bill totals stay unchanged.

CREATE OR REPLACE FUNCTION public.process_wholesale_invoice_return(
  p_invoice_id bigint,
  p_items jsonb,
  p_return_charge_amount numeric DEFAULT 0,
  p_refund_method text DEFAULT NULL,
  p_payout_account_id bigint DEFAULT NULL,
  p_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_invoice public.bills;
  v_parent_total numeric(12, 2);
  v_item_elem jsonb;
  v_item_id bigint;
  v_return_qty numeric;
  v_to_availability public.stock_availability;
  v_to_grade_tag_id bigint;
  v_item_note text;
  v_db_item public.bill_lines%rowtype;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_total_return_value numeric(12, 2) := 0.00;
  v_line_unit_price numeric(12, 2);
  v_line_return_val numeric(12, 2);
  v_paid numeric(12, 2) := 0.00;
  v_excess_paid numeric(12, 2) := 0.00;
  v_refund_amount numeric(12, 2) := 0.00;
  v_return_count integer := 0;
  v_payout_id text;
  v_charge numeric(12, 2) := 0.00;
  v_cn_lines jsonb := '[]'::jsonb;
  v_cn_amount numeric(12, 2);
  v_cn public.bills;
  v_bal jsonb;
  v_open_books numeric(12, 2);
  v_settled numeric(12, 2);
  v_reason text;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.document_kind <> 'standard'::public.bill_document_kind then
    raise exception 'Returns apply to standard bills only';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Returns can only be processed on issued/posted invoices';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one return item must be provided';
  end if;

  v_parent_total := v_invoice.total_amount;
  v_charge := greatest(coalesce(p_return_charge_amount, 0.00), 0.00);
  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);
  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);
  v_reason := coalesce(nullif(trim(p_note), ''), 'Wholesale invoice return');

  for v_item_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_item_elem->>'invoice_item_id')::bigint;
    v_return_qty := (v_item_elem->>'quantity')::numeric;
    v_to_availability := coalesce(
      (v_item_elem->>'to_availability')::public.stock_availability,
      'held'::public.stock_availability
    );
    v_to_grade_tag_id := (v_item_elem->>'to_grade_tag_id')::bigint;
    v_item_note := nullif(trim(v_item_elem->>'note'), '');

    if v_item_id is null then
      raise exception 'invoice_item_id is required for all items';
    end if;

    if v_return_qty is null or v_return_qty <= 0 then
      continue;
    end if;

    select * into v_db_item
    from public.bill_lines
    where id = v_item_id and invoice_id = p_invoice_id
    for update;

    if v_db_item.id is null then
      raise exception 'Invoice item % not found on this invoice', v_item_id;
    end if;

    if (v_db_item.return_quantity + v_return_qty) > v_db_item.quantity then
      raise exception 'Return quantity % exceeds available returnable quantity % for %',
        v_return_qty,
        (v_db_item.quantity - v_db_item.return_quantity),
        v_db_item.name_snapshot;
    end if;

    v_line_unit_price := v_db_item.sell_price_amount;
    v_line_return_val := round(v_return_qty * v_line_unit_price, 2);
    v_total_return_value := v_total_return_value + v_line_return_val;

    v_cn_lines := v_cn_lines || jsonb_build_array(
      jsonb_build_object(
        'parent_line_id', v_item_id,
        'name_snapshot', v_db_item.name_snapshot,
        'quantity', v_return_qty,
        'sell_price_amount', v_line_unit_price,
        'line_total_amount', v_line_return_val,
        'books_amount', v_line_return_val
      )
    );

    insert into public.sales_return_items (
      tenant_id,
      invoice_id,
      invoice_item_id,
      global_stock_id,
      quantity,
      return_charge_amount,
      note
    ) values (
      v_parent_id,
      p_invoice_id,
      v_item_id,
      v_db_item.global_stock_id,
      v_return_qty,
      0.00,
      v_item_note
    );

    update public.bill_lines
    set
      return_quantity = return_quantity + v_return_qty,
      updated_at = now()
    where id = v_item_id;

    if v_db_item.global_stock_id is not null then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_id,
        p_stock_id => v_db_item.global_stock_id,
        p_quantity => ceil(v_return_qty)::integer,
        p_to_location_id => public.default_returns_stock_location_id(v_parent_id),
        p_to_availability => v_to_availability,
        p_to_grade_tag_id => coalesce(v_to_grade_tag_id, public.default_stock_grade_tag_id()),
        p_movement_type => 'return_inbound'::public.stock_movement_type,
        p_notes => coalesce(v_item_note, 'Wholesale invoice return #' || coalesce(v_invoice.invoice_no, p_invoice_id::text)),
        p_reference_type => 'sales_invoice',
        p_reference_id => p_invoice_id::text
      );
    end if;

    v_return_count := v_return_count + 1;
  end loop;

  if v_return_count = 0 then
    raise exception 'No items with quantity > 0 were selected for return';
  end if;

  -- Restocking / handling fee reduces credit note face (does not change parent total).
  v_cn_amount := greatest(round(v_total_return_value - v_charge, 2), 0.01);

  v_cn := public.create_bill_adjustment(
    p_invoice_id,
    'credit_note',
    v_cn_amount,
    v_reason,
    true,
    null,
    null,
    v_cn_lines
  );

  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  v_bal := public.get_bill_net_balances(p_invoice_id);
  v_open_books := coalesce((v_bal->>'open_books')::numeric, 0);
  v_settled := coalesce((v_bal->>'paid_amount')::numeric, coalesce(v_invoice.paid_amount, 0));
  v_paid := v_settled;
  v_excess_paid := greatest(v_paid - v_open_books, 0);

  if v_excess_paid > 0.00 then
    if p_refund_method = 'wallet_credit' and v_invoice.profile_id is not null then
      insert into public.cashbook_accounts (
        tenant_id, entity_type, entity_id, currency_code,
        available_balance, locked_balance, pending_balance
      ) values (
        v_eff_tenant_id, 'customer', v_invoice.profile_id, 'BDT',
        0.0000, 0.0000, 0.0000
      ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'credit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice_return',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'returns',
          'purpose', 'wholesale_return_wallet_credit',
          'transaction_type', 'return_credit',
          'label', 'Return Credit (Wallet)',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'credit_note_id', v_cn.id,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;

    elsif p_refund_method = 'payout' and v_invoice.profile_id is not null then
      v_payout_id := 'RET-PO-' || gen_random_uuid()::text;

      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_eff_tenant_id,
        p_type => 'debit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payout_id,
        p_metadata => jsonb_build_object(
          'section', 'payout_earned',
          'purpose', 'wholesale_return_payout',
          'transaction_type', 'return_cash_payout',
          'label', 'Return Cash Payout',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'profile_id', v_invoice.profile_id,
          'credit_note_id', v_cn.id,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;
    end if;
  end if;

  select * into v_invoice from public.bills where id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'credit_note_id', v_cn.id,
    'credit_note_no', v_cn.invoice_no,
    'parent_total_unchanged', v_invoice.total_amount = v_parent_total,
    'new_subtotal', v_invoice.subtotal_amount,
    'new_total', v_parent_total,
    'new_due', v_open_books,
    'open_books', v_open_books,
    'net_balances', v_bal,
    'paid_amount', v_paid,
    'excess_paid', v_excess_paid,
    'refund_amount', v_refund_amount,
    'refund_method', p_refund_method,
    'payment_status', v_invoice.payment_status,
    'returned_items_count', v_return_count
  );
end;
$$;

-- Dropship: issue CN on merchant bill instead of shrinking totals via recompute_global_invoice_totals.
CREATE OR REPLACE FUNCTION public._kernel_dropship_return_credit_note(
  p_parent_bill_id bigint,
  p_return_credit numeric,
  p_return_charge numeric,
  p_reason text,
  p_lines jsonb DEFAULT '[]'::jsonb
)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_net numeric(12, 2);
  v_reason text;
begin
  if p_parent_bill_id is null then
    return null;
  end if;

  v_net := round(greatest(coalesce(p_return_credit, 0) - greatest(coalesce(p_return_charge, 0), 0), 0), 2);
  if v_net <= 0 then
    return null;
  end if;

  v_reason := coalesce(nullif(trim(p_reason), ''), 'Dropship return credit');

  return public.create_bill_adjustment(
    p_parent_bill_id,
    'credit_note',
    v_net,
    v_reason,
    true,
    null,
    null,
    coalesce(p_lines, '[]'::jsonb)
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public.process_wholesale_invoice_return(
  bigint, jsonb, numeric, text, bigint, text
) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public._kernel_dropship_return_credit_note(
  bigint, numeric, numeric, text, jsonb
) TO authenticated, service_role;


-- Patched finalize_dropship_return (BP5 CN path)
CREATE OR REPLACE FUNCTION public."finalize_dropship_return"(p_order_id bigint, "p_items" jsonb, "p_actual_return_charge" numeric DEFAULT 0.00, "p_deduct_from_middle_man" boolean DEFAULT true, "p_override_reason" "text" DEFAULT NULL::"text", "p_return_ref" "text" DEFAULT NULL::"text") RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_invoice record;
  v_books_tenant_id bigint;
  v_ref text;
  v_item_elem jsonb;
  v_order_item_id bigint;
  v_returned_qty numeric;
  v_condition text;
  v_order_item record;
  v_invoice_item record;
  v_stock record;
  v_target_stock_type_id bigint;
  v_target_stock_id bigint;
  v_net_delivered numeric;
  v_currency text;
  v_profile_id bigint;
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
  v_profit numeric(12,2) := 0;
  v_revenue numeric(12,2) := 0;
  v_billed numeric(12,2) := 0;
  v_remit_net numeric(12,2) := 0;
  v_courier_charge numeric(12,2) := 0;
  v_has_billed boolean := false;
  v_has_profit boolean := false;
  v_grade_tag_id bigint;
  v_to_availability public.stock_availability;
  v_to_availability_raw text;
  v_use_explicit_targets boolean := false;
  v_return_credit_total numeric(12,2) := 0.00;
  v_line_credit numeric(12,2);
  v_cn_lines jsonb := '[]'::jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order #% is not a dropship order', p_order_id;
  end if;

  v_currency := 'BDT';
  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  if not (
    public.user_can_manage_books_tenant(v_books_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  v_ref := nullif(trim(coalesce(p_return_ref, '')), '');
  if v_ref is not null then
    select id into v_existing_ref_order_id
    from public.shop_orders
    where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
      and return_ref = v_ref;

    if v_existing_ref_order_id is not null then
      if v_existing_ref_order_id = p_order_id and v_order.return_sub_state = 'return_finalized' then
        return jsonb_build_object(
          'success', true,
          'idempotent', true,
          'message', 'Return already finalized with reference ' || v_ref,
          'order_id', p_order_id
        );
      else
        raise exception 'Duplicate return reference % already used for another return', v_ref;
      end if;
    end if;
  end if;

  if v_order.return_sub_state = 'return_finalized' then
    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'message', 'Order return is already finalized',
      'order_id', p_order_id
    );
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  end if;

  v_profile_id := v_order.profile_id;
  if v_profile_id is null and v_order.customer_group_id is not null then
    select id into v_profile_id
    from public.profiles
    where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');
      v_grade_tag_id := nullif((v_item_elem->>'grade_tag_id')::bigint, 0);
      v_to_availability_raw := nullif(lower(trim(v_item_elem->>'to_availability')), '');
      v_use_explicit_targets := v_grade_tag_id is not null or v_to_availability_raw is not null;

      if v_returned_qty <= 0 then
        continue;
      end if;

      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      end if;

      v_net_delivered := coalesce(v_order_item.confirmed_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      end if;

      if v_use_explicit_targets then
        v_grade_tag_id := coalesce(
          v_grade_tag_id,
          v_order_item.grade_tag_id,
          public.default_stock_grade_tag_id()
        );
        v_to_availability := coalesce(
          v_to_availability_raw::public.stock_availability,
          'held'::public.stock_availability
        );
      else
        v_to_availability := case
          when v_condition = 'damaged' then 'unsellable'::public.stock_availability
          else 'held'::public.stock_availability
        end;
        v_grade_tag_id := public.stock_grade_tag_id_for_slug(
          case v_condition
            when 'open_box' then 'open_box'
            when 'damaged' then 'badly_damaged'
            else 'standard'
          end
        );
      end if;

      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        perform public.create_and_post_stock_movement(
          v_books_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_books_tenant_id),
          v_to_availability,
          v_grade_tag_id,
          'return_inbound'::public.stock_movement_type,
          coalesce(p_override_reason, 'Dropship return'),
          'shop_order',
          p_order_id::text
        );
      end if;

      update public.shop_order_items
      set returned_quantity = coalesce(returned_quantity, 0) + v_returned_qty, updated_at = now()
      where id = v_order_item_id;

      if v_invoice.id is not null then
        select * into v_invoice_item
        from public.global_invoice_items
        where invoice_id = v_invoice.id
          and (global_stock_id = v_order_item.global_stock_id or product_id = v_order_item.product_id)
        limit 1;

        if v_invoice_item.id is not null then
          -- global_return_items schema: quantity + return_charge_amount only (no return_amount / face / accounting)
          insert into public.global_return_items (
            tenant_id, tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.tenant_id, v_invoice.tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
            v_returned_qty, 0.00, coalesce(p_override_reason, 'Dropship return finalization')
          );

          update public.global_invoice_items
          set return_quantity = coalesce(return_quantity, 0) + v_returned_qty, updated_at = now()
          where id = v_invoice_item.id;

          v_line_credit := round(
            v_returned_qty * coalesce(v_invoice_item.sell_price_amount, 0),
            2
          );
          if v_line_credit > 0 then
            v_return_credit_total := v_return_credit_total + v_line_credit;
            v_cn_lines := v_cn_lines || jsonb_build_array(
              jsonb_build_object(
                'parent_line_id', v_invoice_item.id,
                'name_snapshot', v_invoice_item.name_snapshot,
                'quantity', v_returned_qty,
                'sell_price_amount', v_invoice_item.sell_price_amount,
                'line_total_amount', v_line_credit,
                'books_amount', v_line_credit
              )
            );
          end if;
        end if;
      end if;
    end loop;
  end if;

  if v_invoice.id is not null and v_return_credit_total > 0 then
    perform public._kernel_dropship_return_credit_note(
      v_invoice.id,
      v_return_credit_total,
      p_actual_return_charge,
      coalesce(p_override_reason, 'Dropship return finalization'),
      v_cn_lines
    );
    perform public.recompute_global_invoice_payment_status(v_invoice.id);
    select * into v_invoice from public.bills where id = v_invoice.id;
  end if;

  select exists (
    select 1 from public.cashbook_entries
    where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.cashbook_entries
  where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.cashbook_entries
    where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.cashbook_entries
  where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.cashbook_entries
  where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'tenant'
    and metadata->>'transaction_type' = 'revenue';

  if v_revenue <= 0 then
    v_revenue := coalesce(v_invoice.total_amount, 0.00);
  end if;

  select coalesce((metadata->>'net_remitted')::numeric, amount, 0)
  into v_remit_net
  from public.cashbook_entries
  where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.cashbook_entries
  where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
      p_type => 'credit',
      p_amount => v_billed,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'return_reversal',
        'label', 'Return Billed Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  elsif v_profile_id is not null and v_has_billed and v_billed = 0
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    -- Invoice fully collected already — reverse original billed amount then reverse collection net via billed lookup
    select coalesce(base_amount, 0) into v_billed
    from public.cashbook_entries
    where source_type = 'shop_order' and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
    limit 1;

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
        p_type => 'credit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_reversal',
          'label', 'Return Billed Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );

      if exists (
        select 1 from public.cashbook_entries
        where source_type = 'shop_order' and source_id = p_order_id::text
          and metadata->>'transaction_type' = 'invoice_collection'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_profile_id,
          p_type => 'debit',
          p_amount => v_billed,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'receivable',
            'transaction_type', 'return_collection_reversal',
            'label', 'Return Collection Reversal',
            'order_no', v_order.order_no,
            'return_ref', v_ref
          )
        );
      end if;
    end if;

  -- Historical remittance path: invoice_collection posted without invoice_billed.
  -- Unwind collection only (no synthetic return_reversal credit).
  elsif v_profile_id is not null
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_collection'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_collection_reversal'
     )
  then
    select coalesce(sum(base_amount), 0) into v_billed
    from public.cashbook_entries
    where tenant_id = public.resolve_books_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
        p_type => 'debit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_collection_reversal',
          'label', 'Return Collection Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Leg 2: Claw back profit on customer (unified billing-profile wallet)
  if v_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
      p_type => 'debit',
      p_amount => v_profit,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_profit_clawback',
        'label', 'Return Profit Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 3: Reverse tenant revenue
  if v_revenue > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_revenue_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_type => 'debit',
      p_amount => v_revenue,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'revenue',
        'transaction_type', 'return_revenue_reversal',
        'label', 'Return Revenue Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 4: Reverse remittance cash + courier fee if remitted
  if v_is_remitted then
    if coalesce(v_remit_net, 0) > 0
       and not exists (
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'remittance_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_books_tenant_id(v_order.tenant_id),
        p_type => 'debit',
        p_amount => v_remit_net,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'payment_received',
          'purpose', 'remittance_return_reversal',
          'transaction_type', 'remittance_return_reversal',
          'label', 'Remittance Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;

    if coalesce(v_courier_charge, 0) > 0
       and not exists (
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'courier_charge_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_books_tenant_id(v_order.tenant_id),
        p_type => 'credit',
        p_amount => v_courier_charge,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'delivery_fee',
          'purpose', 'courier_charge_return_reversal',
          'transaction_type', 'courier_charge_return_reversal',
          'label', 'Courier Fee Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Return fee: UWL only (legacy middle_man_payout_ledger was dropped)
  if p_deduct_from_middle_man
     and p_actual_return_charge > 0
     and v_profile_id is not null
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => public.resolve_books_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
      p_type => 'debit',
      p_amount => p_actual_return_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_fee',
        'label', 'Return Fee',
        'order_no', v_order.order_no,
        'return_ref', v_ref,
        'invoice_id', v_order.global_invoice_id
      )
    );
  end if;

  update public.shop_orders
  set
    status = 'returned'::public.shop_order_status,
    return_sub_state = 'return_finalized',
    returned_at = coalesce(returned_at, now()),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man,
    return_override_reason = coalesce(p_override_reason, return_override_reason),
    return_ref = v_ref,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'returned',
    'return_sub_state', 'return_finalized',
    'return_ref', v_ref
  );
end;
$$;



-- from schemas/bills_pays/11_pay_reverse.sql
-- BP12 + BP11 custody + WA13 bounce (source for migrations).

ALTER TABLE public.pay_instruments
  ADD COLUMN IF NOT EXISTS bounced_at timestamptz;

-- ---------------------------------------------------------------------------
-- BP12: settlements-aware payment reverse
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_reverse_payment(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_payment public.pays;
  v_parent_id bigint;
  v_bill_id bigint;
  v_bill_ids bigint[] := '{}';
  v_leftover numeric(12, 2);
  v_reason text;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_cashbook_point_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null then
    raise exception 'Tenant and payment are required.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required to void a payment.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  select * into v_payment
  from public.pays
  where id = p_payment_id
    and tenant_id = v_parent_id
  for update;

  if v_payment.id is null then
    raise exception 'Payment not found.';
  end if;

  if v_payment.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  if coalesce(v_payment.method, '') = 'wallet_credit' then
    raise exception 'Store-credit application receipts cannot be voided from this screen.';
  end if;

  if v_payment.source = 'store_credit' then
    raise exception 'Store-credit application payments cannot be voided here.';
  end if;

  select coalesce(array_agg(distinct x.bid), '{}')
  into v_bill_ids
  from (
    select coalesce(pa.bill_id, pa.global_invoice_id) as bid
    from public.pay_allocations pa
    where pa.payment_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    where bs.allocator_kind = 'pay'
      and bs.allocator_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    join public.pay_allocations pa on pa.id = bs.pay_allocation_id
    where pa.payment_id = v_payment.id
  ) x
  where x.bid is not null;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public._kernel_lock_bills(array[v_bill_id]);
    select b.ap_shipment_id into v_sid
    from public.bills b
    where b.id = v_bill_id and b.ap_shipment_id is not null;
    if v_sid is not null and not (v_sid = any(v_shipment_ids)) then
      v_shipment_ids := array_append(v_shipment_ids, v_sid);
    end if;
  end loop;

  delete from public.bill_settlements bs
  where bs.pay_allocation_id in (
    select pa.id from public.pay_allocations pa where pa.payment_id = v_payment.id
  );

  delete from public.bill_settlements bs
  where bs.allocator_kind = 'pay'
    and bs.allocator_id = v_payment.id;

  delete from public.pay_allocations
  where payment_id = v_payment.id;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public.recompute_global_invoice_payment_status(v_bill_id);
  end loop;

  v_leftover := coalesce(v_payment.unallocated_amount, 0.00);

  if v_payment.source = 'ap_payout' then
    select pi.cashbook_point_id into v_cashbook_point_id
    from public.pay_instruments pi
    where pi.payment_id = v_payment.id
    order by pi.sort_order, pi.id
    limit 1;

    perform public.record_ledger_transaction(
      p_tenant_id => v_parent_id,
      p_operating_tenant_id => coalesce(v_payment.tenant_id, p_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_ap_payout',
        'transaction_type', 'ap_payout_reversal',
        'label', 'Void AP payout',
        'payment_id', v_payment.id,
        'reason', v_reason,
        'cashbook_point_pot_id', v_payment.cashbook_point_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => coalesce(v_cashbook_point_id, v_payment.cashbook_point_id)
    );
  elsif v_payment.source = 'commission' then
    v_cashbook_point_id := coalesce(v_payment.cashbook_point_id, v_cashbook_point_id);

    perform public.record_ledger_transaction(
      p_tenant_id => v_parent_id,
      p_operating_tenant_id => coalesce(v_payment.tenant_id, p_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_commission_payout',
        'transaction_type', 'profit_paid_out_reversal',
        'label', 'Void commission payout',
        'payment_id', v_payment.id,
        'reason', v_reason,
        'cashbook_point_pot_id', v_payment.cashbook_point_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => v_cashbook_point_id
    );

    if v_payment.profile_id is not null then
      perform public.record_ledger_transaction(
        p_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_payment.profile_id,
        p_type => 'credit',
        p_amount => v_payment.amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payment.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_commission_payout_profile',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true
      );
    end if;
  elsif v_payment.source in ('customer_cash', 'bank', 'courier_remittance') then
    if coalesce(v_payment.amount, 0.00) > 0.00 then
      perform public.record_ledger_transaction(
        p_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_parent_id,
        p_type => 'debit',
        p_amount => case
          when coalesce(v_payment.source_currency_code, 'BDT') <> 'BDT'
            then coalesce(v_payment.source_amount, v_payment.amount)
          else v_payment.amount
        end,
        p_currency_code => coalesce(nullif(trim(v_payment.source_currency_code), ''), 'BDT'),
        p_exchange_rate => coalesce(v_payment.transaction_rate, 1.000000),
        p_source_type => case
          when v_payment.source = 'courier_remittance' then 'shop_order'
          else 'sales_invoice'
        end,
        p_source_id => case
          when v_payment.source = 'courier_remittance' then coalesce(v_payment.shop_order_id::text, v_payment.id::text)
          else v_payment.id::text
        end,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_batch_payment_received',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true,
        p_cashbook_point_id => v_payment.cashbook_point_id
      );
    end if;

    if v_leftover > 0.00 and v_payment.profile_id is not null
       and v_payment.source in ('customer_cash', 'bank') then
      perform public.record_ledger_transaction(
        p_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_payment.profile_id,
        p_type => 'debit',
        p_amount => v_leftover,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_payment.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_store_credit',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true
      );
    end if;
  else
    raise exception 'Cannot void payment source %.', v_payment.source;
  end if;

  update public.pays
  set
    voided_at = now(),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[VOIDED] ' || v_reason
    )
  where id = v_payment.id;

  if coalesce(array_length(v_shipment_ids, 1), 0) > 0 then
    foreach v_sid in array v_shipment_ids
    loop
      perform public.refresh_global_shipment_fx_from_ap_payments(v_sid);
    end loop;
  end if;

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment.id,
    'customer_group_id', v_payment.customer_group_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.void_customer_receipt(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_reverse_payment(p_tenant_id, p_payment_id, p_reason);
end;
$$;

CREATE OR REPLACE FUNCTION public.reverse_pay(
  p_payment_id bigint,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_reason text;
begin
  select * into v_pay from public.pays where id = p_payment_id;
  if v_pay.id is null then
    raise exception 'Payment not found.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;

  perform public._kernel_reverse_payment(v_pay.tenant_id, p_payment_id, v_reason);
end;
$$;

-- ---------------------------------------------------------------------------
-- BP11: profile custody → bill
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_apply_custody_to_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_books_amount numeric
)
RETURNS public.bill_settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_parent_id bigint;
  v_avail numeric(18, 4);
  v_books numeric(12, 2);
  v_open numeric(12, 2);
  v_row public.bill_settlements;
  v_txn numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
  v_ledger jsonb;
  v_entry_id uuid;
  v_anchor bigint;
  v_source_key text;
begin
  if not public.membership_has_module_action(p_tenant_id, 'payments', 'allocate_payment') then
    raise exception 'Permission denied.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_books := round(coalesce(p_books_amount, 0), 2);
  if v_books <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  perform public._kernel_lock_bills(array[p_bill_id]);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then raise exception 'Bill not found.'; end if;
  if v_bill.tenant_id <> v_parent_id then raise exception 'Bill tenant mismatch.'; end if;
  if v_bill.profile_id is null then raise exception 'Bill has no profile.'; end if;
  if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill is not issued.';
  end if;
  if coalesce(v_bill.document_kind, 'standard'::public.bill_document_kind)
    <> 'standard'::public.bill_document_kind then
    raise exception 'Custody applies to standard bills only.';
  end if;

  v_open := coalesce(
    (public.get_bill_net_balances(p_bill_id)->>'open_books')::numeric,
    v_bill.due_amount,
    0
  );
  if v_books > v_open then
    raise exception 'Amount % exceeds open bill balance %.', v_books, v_open;
  end if;

  select coalesce(ca.available_balance, 0)
  into v_avail
  from public.cashbook_accounts ca
  where ca.tenant_id = v_parent_id
    and ca.entity_type = 'customer'
    and ca.entity_id = v_bill.profile_id
    and ca.currency_code = 'BDT';

  if v_avail < v_books then
    raise exception 'Insufficient profile custody (available %).', v_avail;
  end if;

  v_source_key := 'custody_apply:' || p_bill_id::text || ':' || gen_random_uuid()::text;

  v_ledger := public.record_ledger_transaction(
    p_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_bill.profile_id,
    p_type => 'debit',
    p_amount => v_books,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'bill_settlement',
    p_source_id => v_source_key,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'apply_custody_to_bill',
      'transaction_type', 'custody_apply',
      'label', 'Applied custody to bill',
      'bill_id', p_bill_id
    ),
    p_allow_overdraft => false
  );

  v_entry_id := (v_ledger->>'id')::uuid;
  v_anchor := abs(hashtext(v_entry_id::text));

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, null, v_books) sa;

  insert into public.bill_settlements (
    tenant_id, bill_id, allocator_kind, allocator_id,
    allocated_txn_amount, allocated_books_amount, books_rate_at_alloc, fx_realized_books_delta
  ) values (
    v_bill.tenant_id, p_bill_id, 'custody_entry', v_anchor,
    v_txn, v_books, v_rate, v_delta
  )
  returning * into v_row;

  update public.cashbook_entries
  set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
    'bill_settlement_id', v_row.id,
    'custody_entry_uuid', v_entry_id
  )
  where id = v_entry_id;

  perform public.recompute_global_invoice_payment_status(p_bill_id);

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- WA13-p: unwind pay settlements LIFO (books cap; full rows only)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_unwind_pay_settlements_up_to(
  p_payment_id bigint,
  p_books_cap numeric
) RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_remaining numeric(12, 2);
  v_unwound numeric(12, 2) := 0.00;
  v_row record;
  v_bill_ids bigint[] := '{}';
  v_bill_id bigint;
begin
  if p_payment_id is null then
    raise exception 'payment_id is required';
  end if;
  v_remaining := round(coalesce(p_books_cap, 0), 2);
  if v_remaining <= 0 then
    return 0;
  end if;

  for v_row in
    select bs.id, bs.bill_id, bs.pay_allocation_id, bs.allocated_books_amount
    from public.bill_settlements bs
    where bs.allocator_kind = 'pay'
      and bs.allocator_id = p_payment_id
    order by bs.id desc
  loop
    exit when v_remaining <= 0;
    if v_row.allocated_books_amount > v_remaining then
      exit;
    end if;

    delete from public.bill_settlements where id = v_row.id;
    if v_row.pay_allocation_id is not null then
      delete from public.pay_allocations where id = v_row.pay_allocation_id;
    end if;

    v_unwound := v_unwound + v_row.allocated_books_amount;
    v_remaining := v_remaining - v_row.allocated_books_amount;

    if v_row.bill_id is not null
       and not (v_row.bill_id = any(v_bill_ids)) then
      v_bill_ids := array_append(v_bill_ids, v_row.bill_id);
    end if;
  end loop;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public.recompute_global_invoice_payment_status(v_bill_id);
  end loop;

  return v_unwound;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_bounce_cheque_instrument_partial(
  p_tenant_id bigint,
  p_instrument_id bigint,
  p_reason text
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_inst public.pay_instruments;
  v_pay public.pays;
  v_parent_id bigint;
  v_slice numeric(12, 2);
  v_unwound numeric(12, 2);
  v_total_alloc numeric(12, 2);
  v_pot_id bigint;
  v_point_id bigint;
begin
  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  select * into v_inst from public.pay_instruments where id = p_instrument_id for update;
  select * into v_pay from public.pays where id = v_inst.payment_id for update;

  v_slice := round(coalesce(v_inst.amount, 0), 2);
  if v_slice <= 0 then
    raise exception 'Cheque instrument amount must be greater than zero.';
  end if;

  update public.pay_instruments
  set bounced_at = now()
  where id = v_inst.id;

  v_unwound := public._kernel_unwind_pay_settlements_up_to(v_pay.id, v_slice);

  v_point_id := coalesce(v_inst.cashbook_point_id, v_pay.cashbook_point_id);
  v_pot_id := public._kernel_ensure_cashbook_point_pot(
    v_parent_id,
    v_point_id,
    coalesce(nullif(trim(v_pay.source_currency_code), ''), 'BDT')
  );

  if v_pay.source in ('customer_cash', 'bank', 'courier_remittance') then
    perform public.record_ledger_transaction(
      p_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'debit',
      p_amount => case
        when coalesce(v_pay.source_currency_code, 'BDT') <> 'BDT'
          then round(v_slice / coalesce(nullif(v_pay.transaction_rate, 0), 1), 2)
        else v_slice
      end,
      p_currency_code => coalesce(nullif(trim(v_pay.source_currency_code), ''), 'BDT'),
      p_exchange_rate => coalesce(v_pay.transaction_rate, 1.000000),
      p_source_type => case
        when v_pay.source = 'courier_remittance' then 'shop_order'
        else 'sales_invoice'
      end,
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'cheque_bounce_partial',
        'transaction_type', 'cheque_bounced',
        'label', 'Cheque bounced (partial)',
        'payment_id', v_pay.id,
        'instrument_id', v_inst.id,
        'reason', p_reason,
        'cashbook_point_pot_id', v_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => v_point_id
    );
  else
    raise exception 'Partial cheque bounce not supported for payment source %.', v_pay.source;
  end if;

  select coalesce(sum(pa.amount), 0.00) into v_total_alloc
  from public.pay_allocations pa
  where pa.payment_id = v_pay.id;

  update public.pays
  set
    amount = greatest(coalesce(amount, 0) - v_slice, 0),
    unallocated_amount = greatest(coalesce(amount, 0) - v_slice - v_total_alloc, 0),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[CHEQUE BOUNCED] ' || p_reason
    )
  where id = v_pay.id;

  return jsonb_build_object(
    'success', true,
    'partial', true,
    'payment_id', v_pay.id,
    'instrument_id', v_inst.id,
    'books_unwound', v_unwound,
    'slice_amount', v_slice
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- WA13: cheque bounce (whole pay or partial on split tender)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.bounce_cheque_instrument(
  p_tenant_id bigint,
  p_instrument_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_inst public.pay_instruments;
  v_pay public.pays;
  v_reason text;
  v_active_count int;
  v_parent_id bigint;
begin
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  select * into v_inst
  from public.pay_instruments
  where id = p_instrument_id
  for update;

  if v_inst.id is null then
    raise exception 'Instrument not found.';
  end if;

  if upper(trim(v_inst.payment_method_code)) <> 'CHEQUE' then
    raise exception 'Instrument is not a cheque.';
  end if;

  if v_inst.bounced_at is not null then
    raise exception 'Cheque already marked bounced.';
  end if;

  select * into v_pay from public.pays where id = v_inst.payment_id for update;
  if v_pay.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  if v_pay.tenant_id <> v_parent_id then
    raise exception 'Payment tenant mismatch.';
  end if;

  select count(*)::int into v_active_count
  from public.pay_instruments pi
  where pi.payment_id = v_pay.id
    and pi.bounced_at is null;

  if v_active_count <= 1 then
    update public.pay_instruments
    set bounced_at = now()
    where id = v_inst.id;

    perform public.reverse_pay(
      v_pay.id,
      'Cheque bounced: ' || v_reason
    );

    return jsonb_build_object(
      'success', true,
      'partial', false,
      'payment_id', v_pay.id,
      'instrument_id', v_inst.id
    );
  end if;

  return public._kernel_bounce_cheque_instrument_partial(
    p_tenant_id,
    p_instrument_id,
    v_reason
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_reverse_payment(bigint, bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reverse_pay(bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_apply_custody_to_bill(bigint, bigint, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bounce_cheque_instrument(bigint, bigint, text) TO authenticated, service_role;

-- from schemas/bills_pays/12_cashbook_wiring.sql
-- BP15 + BP16 + BP21 cashbook wiring (source for migrations).

DO $$ BEGIN
  CREATE TYPE public.cashbook_account_class AS ENUM ('tenant_asset', 'profile_custody');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.cashbook_accounts
  ADD COLUMN IF NOT EXISTS account_class public.cashbook_account_class;

UPDATE public.cashbook_accounts
SET account_class = 'tenant_asset'::public.cashbook_account_class
WHERE account_class IS NULL AND entity_type = 'tenant';

UPDATE public.cashbook_accounts
SET account_class = 'profile_custody'::public.cashbook_account_class
WHERE account_class IS NULL AND entity_type <> 'tenant';

ALTER TABLE public.cashbook_accounts
  ALTER COLUMN account_class SET DEFAULT 'profile_custody'::public.cashbook_account_class;

ALTER TABLE public.cashbook_accounts
  ALTER COLUMN account_class SET NOT NULL;

ALTER TABLE public.cashbook_accounts DROP CONSTRAINT IF EXISTS cashbook_accounts_class_entity_check;
ALTER TABLE public.cashbook_accounts ADD CONSTRAINT cashbook_accounts_class_entity_check CHECK (
  (account_class = 'tenant_asset'::public.cashbook_account_class AND entity_type = 'tenant')
  OR (account_class = 'profile_custody'::public.cashbook_account_class AND entity_type <> 'tenant')
);

CREATE OR REPLACE FUNCTION public.cashbook_staff_can_view(p_tenant_id bigint) RETURNS boolean
    LANGUAGE sql STABLE SECURITY DEFINER
    SET search_path TO public
    AS $$
  SELECT
    public.is_superadmin()
    OR public.membership_has_module_action(public.resolve_books_tenant_id(p_tenant_id), 'cashbook', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'cashbook', 'view')
    OR public.membership_has_module_action(public.resolve_books_tenant_id(p_tenant_id), 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
    OR public.user_can_manage_books_tenant(public.resolve_books_tenant_id(p_tenant_id));
$$;

CREATE OR REPLACE FUNCTION public."get_cashbook_account_balances"("p_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_currency_code" text DEFAULT 'BDT'::text) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
  v_books_id bigint;
  v_entity_id bigint;
BEGIN
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
  END IF;

  SELECT jsonb_build_object(
    'tenant_id', v_books_id,
    'tenant_id', v_books_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(w.currency_code, p_currency_code),
    'available_balance', coalesce(w.available_balance, 0.0000),
    'pending_balance', coalesce(w.pending_balance, 0.0000),
    'locked_balance', coalesce(w.locked_balance, 0.0000),
    'total_balance', (
      coalesce(w.available_balance, 0.0000)
      + coalesce(w.pending_balance, 0.0000)
      + coalesce(w.locked_balance, 0.0000)
    ),
    'account_class', coalesce(w.account_class::text, case when p_entity_type = 'tenant' then 'tenant_asset' else 'profile_custody' end)
  )
  INTO v_result
  FROM (SELECT 1) dummy
  LEFT JOIN public.cashbook_accounts w
    ON w.tenant_id = v_books_id
   AND w.entity_type = p_entity_type
   AND w.entity_id = v_entity_id
   AND w.currency_code = coalesce(p_currency_code, 'BDT');

  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public."get_cashbook_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_currency_code" text DEFAULT 'BDT'::text) RETURNS jsonb
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_name text;
  v_code text;
  v_caption text;
  v_source_uuid uuid;
  v_entity_id bigint;
  v_account jsonb;
BEGIN
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_entity_id := p_entity_id;

  IF NOT (
    public.cashbook_staff_can_view(p_tenant_id)
    OR public.membership_has_module_action(v_books_id, 'payments', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
    SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = v_books_id;
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;
    v_caption := 'Company cash pool';

  ELSIF p_entity_type = 'customer' THEN
    SELECT
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || pr.name ELSE pr.name END,
      nullif(trim(concat_ws(' • ', pr.phone, pr.email)), '')
    INTO v_name, v_caption
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    WHERE pr.id = p_entity_id
      AND (pr.operating_tenant_id = v_books_id OR pr.operating_tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;

  ELSIF p_entity_type = 'vendor' THEN
    SELECT v.name, v.code, nullif(trim(concat_ws(' • ', v.phone, v.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.vendors v WHERE v.id = p_entity_id AND v.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'cargo_company' THEN
    SELECT c.name, c.code, nullif(trim(concat_ws(' • ', c.phone, c.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.cargo_companies c WHERE c.id = p_entity_id AND c.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'courier' THEN
    SELECT cs.name, upper(cs.code), coalesce(nullif(trim(cs.notes), ''), 'Courier service'), cs.id
    INTO v_name, v_code, v_caption, v_source_uuid
    FROM public.courier_services cs
    WHERE cs.wallet_entity_id = p_entity_id AND cs.is_active = true
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'investor' THEN
    SELECT i.name, nullif(trim(concat_ws(' • ', i.phone, i.email)), '')
    INTO v_name, v_caption
    FROM public.investors i WHERE i.id = p_entity_id AND i.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_account := public.get_cashbook_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

  RETURN jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'operating_tenant_id', v_operating_id,
    'entity', jsonb_build_object(
      'entity_type', p_entity_type,
      'entity_id', v_entity_id,
      'name', v_name,
      'code', v_code,
      'caption', v_caption,
      'source_uuid', v_source_uuid
    ),
    'account', jsonb_build_object(
      'currency_code', coalesce(v_account->>'currency_code', p_currency_code),
      'available_balance', coalesce((v_account->>'available_balance')::numeric, 0),
      'pending_balance', coalesce((v_account->>'pending_balance')::numeric, 0),
      'locked_balance', coalesce((v_account->>'locked_balance')::numeric, 0),
      'total_balance', coalesce((v_account->>'total_balance')::numeric, 0),
      'account_class', coalesce(v_account->>'account_class', case when p_entity_type = 'tenant' then 'tenant_asset' else 'profile_custody' end)
    ),
    'permissions', jsonb_build_object(
      'can_record_manual', public.cashbook_staff_can_edit(p_tenant_id),
      'can_reverse', public.cashbook_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public."record_ledger_transaction"("p_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" text, "p_entity_id" bigint, "p_type" text, "p_amount" numeric, "p_currency_code" text DEFAULT 'BDT'::text, "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" text DEFAULT 'adjustment'::text, "p_source_id" text DEFAULT NULL::text, "p_metadata" jsonb DEFAULT '{}'::jsonb, "p_target_bucket" text DEFAULT 'available'::text, "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_base_amount numeric(18,4);
  v_new_balance numeric(18,4);
  v_ledger_entry jsonb;
  v_ledger_id uuid;
  v_entity_id bigint;
  v_point_ok boolean;
  v_pot_id bigint;
  v_pot_amt numeric(12, 2);
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be greater than zero.';
  END IF;

  IF p_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction type must be credit or debit.';
  END IF;

  IF p_target_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Target bucket must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_tenant_id THEN
    v_entity_id := p_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance, account_class
  )
  VALUES (
    p_tenant_id, p_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000,
    CASE WHEN p_entity_type = 'tenant' THEN 'tenant_asset'::public.cashbook_account_class
         ELSE 'profile_custody'::public.cashbook_account_class END
  )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.tenant_id = p_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
    END IF;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      p_tenant_id,
      p_cashbook_point_id,
      coalesce(p_currency_code, 'BDT')
    );
    PERFORM 1
    FROM public.cashbook_point_pots cpp
    WHERE cpp.id = v_pot_id
    FOR UPDATE;

    IF p_type = 'debit' THEN
      SELECT cpp.amount
      INTO v_pot_amt
      FROM public.cashbook_point_pots cpp
      WHERE cpp.id = v_pot_id;

      IF coalesce(v_pot_amt, 0) < p_amount THEN
        IF NOT coalesce(p_allow_overdraft, false) THEN
          RAISE EXCEPTION 'Insufficient cash in till (available: %, requested: %).',
            coalesce(v_pot_amt, 0), p_amount;
        END IF;
        v_pot_id := NULL;
      END IF;
    END IF;
  END IF;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      IF v_avail < p_amount AND NOT coalesce(p_allow_overdraft, false) THEN
        RAISE EXCEPTION 'Insufficient available balance (available: %, requested debit: %).',
          v_avail, p_amount;
      END IF;
      v_avail := v_avail - p_amount;
    END IF;
    v_new_balance := v_avail;
  ELSIF p_target_bucket = 'pending' THEN
    IF p_type = 'credit' THEN
      v_pend := v_pend + p_amount;
    ELSE
      v_pend := v_pend - p_amount;
    END IF;
    v_new_balance := v_pend;
  ELSIF p_target_bucket = 'locked' THEN
    IF p_type = 'credit' THEN
      v_lock := v_lock + p_amount;
    ELSE
      v_lock := v_lock - p_amount;
    END IF;
    v_new_balance := v_lock;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = p_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
    tenant_id,
    operating_tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata,
    cashbook_point_id,
    cashbook_point_pot_id
  )
  VALUES (
    p_tenant_id,
    p_tenant_id,
    p_operating_tenant_id,
    p_entity_type,
    v_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket),
    p_cashbook_point_id,
    v_pot_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'tenant_id', tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'tenant_id', tenant_id,
    'entity_type', entity_type,
    'entity_id', entity_id,
    'type', type,
    'amount', amount,
    'currency_code', currency_code,
    'exchange_rate', exchange_rate,
    'base_amount', base_amount,
    'balance_after', balance_after,
    'source_type', source_type,
    'source_id', source_id,
    'metadata', metadata,
    'cashbook_point_id', cashbook_point_id,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;


CREATE OR REPLACE FUNCTION public.list_books_exchange_rates(
  p_tenant_id bigint,
  p_quote_currency_code text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  id bigint,
  base_currency_code text,
  quote_currency_code text,
  rate numeric,
  rate_date timestamptz
)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path TO public
AS $$
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'tenant_id is required'; END IF;
  IF NOT public.cashbook_staff_can_view(p_tenant_id) THEN RAISE EXCEPTION 'not allowed'; END IF;
  RETURN QUERY
  SELECT DISTINCT ON (upper(r.quote_currency_code))
    r.id, r.base_currency_code, r.quote_currency_code, r.rate, r.rate_date
  FROM public.books_exchange_rates r
  WHERE r.tenant_id = public.resolve_books_tenant_id(p_tenant_id)
    AND (p_quote_currency_code IS NULL OR upper(r.quote_currency_code) = upper(p_quote_currency_code))
  ORDER BY upper(r.quote_currency_code), r.rate_date DESC, r.id DESC
  LIMIT greatest(1, least(coalesce(p_limit, 50), 200));
END;
$$;
GRANT EXECUTE ON FUNCTION public.list_books_exchange_rates(bigint, text, integer) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" date, "p_note" text DEFAULT NULL::text, "p_reference" text DEFAULT NULL::text, "p_source" text DEFAULT 'customer_cash'::text, "p_instruments" jsonb DEFAULT '[]'::jsonb, "p_allocations" jsonb DEFAULT '[]'::jsonb, "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" text DEFAULT 'BDT'::text, "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_credit_dropship_profit" boolean DEFAULT true, "p_idempotency_key" text DEFAULT NULL::text, "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint, "p_source_currency_code" text DEFAULT NULL::text, "p_transaction_rate" numeric DEFAULT NULL::numeric) RETURNS public.pays
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_source text := lower(trim(coalesce(p_source, 'customer_cash')));
  v_received_on date := coalesce(p_received_on, current_date);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_reference text := nullif(trim(coalesce(p_reference, '')), '');
  v_pay public.pays;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int := 0;
  v_amount numeric(12, 2) := 0.00;
  v_header_method text;
  v_alloc jsonb;
  v_bill public.bills;
  v_bill_id bigint;
  v_alloc_amount numeric(12, 2);
  v_total_alloc numeric(12, 2) := 0.00;
  v_leftover numeric(12, 2);
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_cashbook_point_id bigint;
  v_pot_id bigint;
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_base_currency text := 'BDT';
  v_source_amount numeric(12, 2);
  v_payment_face numeric(12, 2);
  v_ledger_amount numeric(12, 2);
  v_ledger_currency text;
  v_ledger_rate numeric(15, 6);
  v_bill_ids bigint[] := '{}';
  v_sid bigint;
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;
  if v_source not in ('customer_cash', 'bank', 'store_credit', 'courier_remittance') then
    raise exception 'Invalid receipt source: %', p_source;
  end if;
  if v_source = 'courier_remittance' and p_shop_order_id is null then
    raise exception 'Courier remittance requires a shop order';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  v_pay := public._kernel_claim_pay_idempotency(v_parent_id, p_idempotency_key);
  if v_pay.id is not null then
    return v_pay;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent_id)
    or public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: cannot record receipts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_profile_id;
  end if;

  -- Instruments: validate and total (header amount = instrument sum).
  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then
        continue;
      end if;
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
      if v_line_count = 1 then
        v_header_method := lower(v_method_code);
      else
        v_header_method := 'split';
      end if;
    end loop;
  end if;

  if v_source = 'store_credit' then
    if v_line_count > 0 then
      raise exception 'Store credit receipts take no instrument lines';
    end if;
    v_header_method := 'store_credit';
  elsif v_line_count = 0 then
    raise exception 'Enter at least one payment line';
  end if;

  if v_header_method is not null and v_header_method not in (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split',
    'store_credit'
  ) then
    v_header_method := 'other';
  end if;

  if v_source <> 'store_credit' then
    select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
    into v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
    from public.normalize_pay_settlement_fx(
      v_amount,
      p_settlement_currency_code,
      p_foreign_amount,
      p_exchange_rate,
      public.resolve_tenant_base_currency_code(p_tenant_id)
    ) n;
  end if;


  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  v_cashbook_point_id := p_cashbook_point_id;
  if v_cashbook_point_id is null and coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      if nullif(v_line.value ->> 'cashbook_point_id', '') is not null then
        v_cashbook_point_id := (v_line.value ->> 'cashbook_point_id')::bigint;
        exit;
      end if;
    end loop;
  end if;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if v_cashbook_point_id is null then
      raise exception 'Choose a cash point for this receipt';
    end if;
    if not exists (
      select 1
      from public.cashbook_points cp
      join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
      where cp.id = v_cashbook_point_id
        and cp.is_active = true
        and ca.tenant_id = v_parent_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent_id
    ) then
      raise exception 'Invalid cash point for this tenant';
    end if;
  end if;

  v_pot_id := p_cashbook_point_pot_id;
  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  if v_source_currency = '' and v_cashbook_point_id is not null then
    select upper(cpp.currency_code)
    into v_source_currency
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = v_cashbook_point_id
      and cpp.tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = v_base_currency then 0 else 1 end, cpp.id
    limit 1;
  end if;
  if v_pot_id is null and v_cashbook_point_id is not null and coalesce(v_source_currency, '') <> '' then
    v_pot_id := public._kernel_ensure_cashbook_point_pot(v_parent_id, v_cashbook_point_id, v_source_currency);
  end if;

  if upper(v_settle_currency) = coalesce(v_source_currency, v_base_currency) then
    v_transaction_rate := 1.000000;
  elsif v_source in ('customer_cash', 'bank', 'courier_remittance') then
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    if v_transaction_rate <= 0 and coalesce(v_source_currency, v_base_currency) <> v_base_currency then
      raise exception 'transaction_rate required when pot currency differs from books currency';
    end if;
  end if;

  if upper(v_settle_currency) = v_base_currency then
    v_payment_face := v_amount;
  else
    v_payment_face := coalesce(v_foreign_amt, 0);
  end if;
  v_source_amount := round(v_payment_face * v_transaction_rate, 2);

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    select coalesce(array_agg(distinct x.bid order by x.bid), '{}'::bigint[])
    into v_bill_ids
    from (
      select coalesce(
        nullif(v_alloc_elem.value ->> 'bill_id', '')::bigint,
        nullif(v_alloc_elem.value ->> 'invoice_id', '')::bigint
      ) as bid
      from jsonb_array_elements(p_allocations) as v_alloc_elem(value)
    ) x
    where x.bid is not null;
  end if;

  perform public._kernel_lock_bills(v_bill_ids);

  for v_sid in
    select distinct b.ap_shipment_id
    from public.bills b
    where b.id = any(v_bill_ids)
      and b.ap_shipment_id is not null
    order by b.ap_shipment_id asc
  loop
    perform public._kernel_advisory_shipment_money_lock(v_sid);
  end loop;

  if v_cashbook_point_id is not null then
    perform public._kernel_lock_cashbook_point_pots(v_cashbook_point_id);
  end if;

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code,
    cashbook_point_id, source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, p_profile_id, v_source, v_amount, v_amount,
    v_received_on, v_header_method, v_reference, v_note, p_shop_order_id,
    v_settle_currency, v_foreign_amt, v_fx_rate, v_base_currency,
    v_cashbook_point_id, v_source_currency, v_transaction_rate, v_source_amount, v_pot_id
  ) returning * into v_pay;

  if v_line_count > 0 then
    perform public.insert_global_payment_instruments(v_pay.id, p_instruments);
  end if;

  update public.pay_instruments pi
  set cashbook_point_id = coalesce(pi.cashbook_point_id, v_cashbook_point_id)
  where pi.payment_id = v_pay.id;

  -- Allocations: open issued bills of this profile only.
  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    for v_alloc in select value from jsonb_array_elements(p_allocations)
    loop
      v_bill_id := coalesce(nullif(v_alloc ->> 'bill_id', '')::bigint, nullif(v_alloc ->> 'invoice_id', '')::bigint);
      v_alloc_amount := round(coalesce((v_alloc ->> 'amount')::numeric, 0.00), 2);
      if v_bill_id is null or v_alloc_amount <= 0 then
        continue;
      end if;

      select * into v_bill from public.bills where id = v_bill_id for update;
      if v_bill.id is null then
        raise exception 'Bill % not found', v_bill_id;
      end if;
      if v_bill.tenant_id <> v_parent_id then
        raise exception 'Bill % belongs to other books', v_bill_id;
      end if;
      if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
        raise exception 'Bill % is not issued', v_bill.invoice_no;
      end if;
      if v_bill.profile_id is distinct from p_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;
      if v_alloc_amount > coalesce(
        (public.get_bill_net_balances(v_bill_id)->>'open_books')::numeric,
        v_bill.due_amount,
        0.00
      ) then
        raise exception 'Allocation % exceeds bill % open balance', v_alloc_amount, v_bill.invoice_no;
      end if;

      perform public._kernel_record_pay_bill_settlement(
        v_parent_id,
        v_pay.id,
        v_bill_id,
        v_alloc_amount,
        false
      );

      v_total_alloc := v_total_alloc + v_alloc_amount;
    end loop;
  end if;

  if v_source = 'store_credit' then
    if v_total_alloc <= 0 then
      raise exception 'Store credit receipt needs at least one allocation';
    end if;
    v_amount := v_total_alloc;
  elsif v_total_alloc > v_amount then
    raise exception 'Allocations (%) exceed receipt amount (%)', v_total_alloc, v_amount;
  end if;

  v_leftover := v_amount - v_total_alloc;

  update public.pays
  set amount = v_amount, unallocated_amount = v_leftover
  where id = v_pay.id
  returning * into v_pay;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if coalesce(v_source_currency, v_base_currency) = v_base_currency then
      v_ledger_amount := v_amount;
      v_ledger_currency := v_base_currency;
      v_ledger_rate := 1.000000;
    else
      v_ledger_amount := v_payment_face;
      v_ledger_currency := v_source_currency;
      v_ledger_rate := v_transaction_rate;
    end if;

    perform public.record_ledger_transaction(
      p_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_ledger_amount,
      p_currency_code => v_ledger_currency,
      p_exchange_rate => v_ledger_rate,
      p_source_type => case when v_source = 'courier_remittance' then 'shop_order' else 'sales_invoice' end,
      p_source_id => case when v_source = 'courier_remittance' then p_shop_order_id::text else v_pay.id::text end,
      p_metadata => jsonb_build_object(
        'section', case when v_source = 'courier_remittance' then 'payment_received' else 'payments' end,
        'purpose', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'tenant_payment_received'
        end,
        'transaction_type', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'payment_received'
        end,
        'label', case when v_source = 'courier_remittance' then 'Courier remittance received' else 'Payment received' end,
        'payment_id', v_pay.id,
        'method', v_header_method,
        'instrument_count', v_line_count,
        'reference', v_reference,
        'shop_order_id', case when v_source = 'courier_remittance' then p_shop_order_id else null end,
        'settlement_currency_code', v_settle_currency,
        'foreign_amount', v_foreign_amt,
        'exchange_rate', v_fx_rate,
        'source_currency_code', v_source_currency,
        'transaction_rate', v_transaction_rate,
        'source_amount', v_source_amount,
        'cashbook_point_pot_id', v_pot_id
      ),
      p_cashbook_point_id => v_cashbook_point_id
    );
  elsif v_source = 'store_credit' then
    perform public.record_ledger_transaction(
      p_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => p_profile_id,
      p_type => 'debit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_pay.id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied store credit',
        'payment_id', v_pay.id
      )
    );
  end if;

  if v_leftover > 0 then
    if v_source = 'courier_remittance' then
      if coalesce(p_credit_dropship_profit, true) then
        perform public.credit_dropship_profit_from_courier_remittance(
          p_tenant_id,
          p_profile_id,
          p_shop_order_id,
          v_pay.id,
          v_leftover,
          v_reference,
          v_amount,
          v_total_alloc
        );
      end if;
    else
      perform public.record_ledger_transaction(
        p_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => p_profile_id,
        p_type => 'credit',
        p_amount => v_leftover,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_pay.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'store_credit',
          'payment_id', v_pay.id,
          'reference', v_reference
        )
      );
    end if;
  end if;

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_id, p_idempotency_key);
end;
$$;

-- from schemas/bills_pays/13_commission_payout.sql
-- BP24: commission / merchant profit payout on money spine (replaces dispense as writer).

ALTER TABLE public.pays DROP CONSTRAINT IF EXISTS pays_source_check;
ALTER TABLE public.pays ADD CONSTRAINT pays_source_check CHECK (
  source = ANY (ARRAY[
    'customer_cash'::text,
    'bank'::text,
    'store_credit'::text,
    'courier_remittance'::text,
    'ap_payout'::text,
    'commission'::text
  ])
);

CREATE OR REPLACE FUNCTION public._kernel_post_commission_payout(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_payout_method text DEFAULT 'bank_transfer',
  p_cashbook_point_id bigint DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_profile public.profiles;
  v_books_tenant_id bigint;
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_pay public.pays;
  v_existing public.pays;
  v_ledger_source_id text;
  v_method text := coalesce(nullif(btrim(p_payout_method), ''), 'bank_transfer');
  v_paid_on date := coalesce(p_paid_on, current_date);
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;
  if p_profile_id is null then
    raise exception 'Billing profile ID is required';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payout amount must be greater than 0';
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(p_tenant_id);

  v_existing := public._kernel_claim_pay_idempotency(v_books_tenant_id, p_idempotency_key);
  if v_existing.id is not null then
    return v_existing;
  end if;

  select * into v_profile
  from public.profiles
  where id = p_profile_id
    and profile_type = 'customer'::public.profile_party_type;

  if v_profile.id is null or not public.profile_valid_for_issuer(p_profile_id, p_tenant_id) then
    raise exception 'Customer profile #% not found for tenant %', p_profile_id, p_tenant_id;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for this pay out';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.tenant_id = v_books_tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_books_tenant_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  if v_pot_id is null then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_books_tenant_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null then
    raise exception 'No currency pot at this cash point';
  end if;

  perform public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  insert into public.pays (
    tenant_id,
    profile_id,
    source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note,
    settlement_currency_code,
    foreign_amount,
    exchange_rate,
    quote_currency_code,
    cashbook_point_id,
    cashbook_point_pot_id
  ) values (
    v_books_tenant_id,
    p_profile_id,
    'commission',
    round(p_amount, 2),
    0.00,
    v_paid_on,
    v_method,
    coalesce(nullif(btrim(p_reference), ''), nullif(btrim(p_source_id), '')),
    p_note,
    'BDT',
    null,
    1.000000,
    'BDT',
    p_cashbook_point_id,
    v_pot_id
  ) returning * into v_pay;

  v_ledger_source_id := coalesce(nullif(btrim(p_source_id), ''), v_pay.id::text);

  perform public.record_ledger_transaction(
    p_tenant_id => v_books_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_books_tenant_id,
    p_type => 'debit',
    p_amount => round(p_amount, 2),
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_ledger_source_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_tenant_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'profile_id', p_profile_id,
      'profile_name', v_profile.name,
      'payout_method', v_method,
      'notes', p_note,
      'cashbook_point_pot_id', v_pot_id,
      'pay_id', v_pay.id,
      'commission_source_id', nullif(btrim(p_source_id), '')
    ),
    p_cashbook_point_id => p_cashbook_point_id
  );

  perform public.record_ledger_transaction(
    p_tenant_id => v_books_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
    p_type => 'debit',
    p_amount => round(p_amount, 2),
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_ledger_source_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'payout_method', v_method,
      'notes', p_note,
      'pay_id', v_pay.id
    )
  );

  perform public.apply_dropship_payout_settlement_fifo(
    p_tenant_id,
    p_profile_id,
    round(p_amount, 2)
  );

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_books_tenant_id, p_idempotency_key);
end;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_post_commission_payout(
  bigint, bigint, date, numeric, text, text, text, bigint, bigint, text, text
) TO authenticated, service_role;

-- from schemas/bills_pays/14_post_sales_invoice.sql
-- BP17: post_sales_invoice stock via commit_sales_bill_stock

CREATE OR REPLACE FUNCTION public.post_sales_invoice(p_invoice_id bigint) RETURNS void
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
  v_delivery_kind text;
  v_held_stock_id bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'only draft or proforma invoices can be posted/issued';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);
  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  v_delivery_kind := lower(trim(coalesce(v_invoice.channel_meta->>'delivery_kind', 'take')));
  if v_delivery_kind not in ('take', 'condition') then
    v_delivery_kind := 'take';
  end if;

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type
     and v_delivery_kind = 'condition' then
    for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
      v_qty := ceil(v_item.quantity)::integer;

      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if v_stock.id is null then
        continue;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'insufficient stock quantity on stock % (requested %, available %)',
          v_item.global_stock_id, v_qty, v_stock.quantity;
      end if;

      if v_stock.availability = 'sellable'::public.stock_availability then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_id,
          p_stock_id => v_item.global_stock_id,
          p_quantity => v_qty,
          p_to_availability => 'held'::public.stock_availability,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Condition bill #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
          p_reference_type => 'sales_invoice',
          p_reference_id => p_invoice_id::text
        );

        select gs.id
        into v_held_stock_id
        from public.global_stocks gs
        where gs.shipment_item_id = v_stock.shipment_item_id
          and gs.availability = 'held'::public.stock_availability
          and gs.location_id = v_stock.location_id
          and gs.grade_tag_id = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
        order by gs.id desc
        limit 1;

        if v_held_stock_id is null then
          raise exception 'held stock not found after condition transfer for line %', v_item.id;
        end if;

        update public.bill_lines
        set line_meta = jsonb_set(
          coalesce(line_meta, '{}'::jsonb),
          '{stock_ref}',
          jsonb_build_object('global_stock_id', v_held_stock_id),
          true
        )
        where id = v_item.id;
      elsif v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'condition bill stock % must be sellable or held (current: %)',
          v_item.global_stock_id, v_stock.availability;
      end if;
    end loop;
  else
    perform public.commit_sales_bill_stock(p_invoice_id);
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status
  where id = p_invoice_id;

  perform public._kernel_freeze_bill_txn_face(p_invoice_id);
  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  if v_invoice.invoice_type = 'retail'::public.global_invoice_type
     and v_invoice.profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.cashbook_entries
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'invoices',
          'purpose', 'invoice_billed',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', v_invoice.id,
          'invoice_type', v_invoice.invoice_type
        )
      );
    end if;
  end if;
end;
$$;

-- from schemas/bills_pays/15_pay_payout_alloc.sql
-- BP18-c: AP payout (settlements-first alloc)

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint, "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "public"."pays"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_received_on date := coalesce(p_paid_on, current_date);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_reference text := nullif(trim(coalesce(p_reference, '')), '');
  v_pay public.pays;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int := 0;
  v_amount numeric(12, 2) := 0.00;
  v_header_method text;
  v_alloc jsonb;
  v_bill public.bills;
  v_bill_id bigint;
  v_alloc_amount numeric(12, 2);
  v_total_alloc numeric(12, 2) := 0.00;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_leftover numeric(12, 2);
  v_channel_meta jsonb;
  v_foreign_face numeric(12, 2);
  v_paper_currency text;
  v_effective_due numeric(12, 2);
  v_paper jsonb;
  v_books_total numeric(12, 2);
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_source_amount numeric(12, 2);
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_payment_face numeric(12, 2);
  v_base_currency text := 'BDT';
  v_bill_ids bigint[] := '{}';
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  v_pay := public._kernel_claim_pay_idempotency(v_parent_id, p_idempotency_key);
  if v_pay.id is not null then
    return v_pay;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent_id)
    or public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: cannot record AP payouts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_profile_id;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for this pay out';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.tenant_id = v_parent_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_parent_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then
        continue;
      end if;
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
      if v_line_count = 1 then
        v_header_method := lower(v_method_code);
      else
        v_header_method := 'split';
      end if;
    end loop;
  end if;

  if v_line_count = 0 then
    raise exception 'Enter at least one payment line';
  end if;

  if v_header_method is not null and v_header_method not in (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split'
  ) then
    v_header_method := 'other';
  end if;

  select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
  into v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
  from public.normalize_pay_settlement_fx(
    v_amount,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    v_base_currency
  ) n;

  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  if v_source_currency = '' then
    select upper(cpp.currency_code)
    into v_source_currency
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_parent_id
      and upper(cpp.currency_code) = v_source_currency
    limit 1;
  end if;

  if upper(v_settle_currency) = v_source_currency then
    v_transaction_rate := 1.000000;
  else
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    if v_transaction_rate <= 0 then
      raise exception 'transaction_rate required when source currency (%) differs from payment currency (%)',
        v_source_currency, v_settle_currency;
    end if;
  end if;

  if upper(v_settle_currency) = v_base_currency then
    v_payment_face := v_amount;
  else
    v_payment_face := coalesce(v_foreign_amt, 0);
  end if;

  v_source_amount := round(v_payment_face * v_transaction_rate, 2);

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    select coalesce(array_agg(distinct x.bid order by x.bid), '{}'::bigint[])
    into v_bill_ids
    from (
      select coalesce(
        nullif(v_alloc_elem.value ->> 'bill_id', '')::bigint,
        nullif(v_alloc_elem.value ->> 'invoice_id', '')::bigint
      ) as bid
      from jsonb_array_elements(p_allocations) as v_alloc_elem(value)
    ) x
    where x.bid is not null;
  end if;

  perform public._kernel_lock_bills(v_bill_ids);

  for v_sid in
    select distinct b.ap_shipment_id
    from public.bills b
    where b.id = any(v_bill_ids)
      and b.ap_shipment_id is not null
    order by b.ap_shipment_id asc
  loop
    perform public._kernel_advisory_shipment_money_lock(v_sid);
  end loop;

  perform public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code, cashbook_point_id,
    source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, p_profile_id, 'ap_payout', v_amount, 0,
    v_received_on, v_header_method, v_reference, v_note,
    v_settle_currency, v_foreign_amt, v_fx_rate, v_base_currency, p_cashbook_point_id,
    v_source_currency, v_transaction_rate, v_source_amount, v_pot_id
  ) returning * into v_pay;

  perform public.insert_global_payment_instruments(v_pay.id, p_instruments);

  update public.pay_instruments pi
  set cashbook_point_id = coalesce(pi.cashbook_point_id, p_cashbook_point_id)
  where pi.payment_id = v_pay.id;

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    for v_alloc in select value from jsonb_array_elements(p_allocations)
    loop
      v_bill_id := coalesce(nullif(v_alloc ->> 'bill_id', '')::bigint, nullif(v_alloc ->> 'invoice_id', '')::bigint);
      v_alloc_amount := round(coalesce((v_alloc ->> 'amount')::numeric, 0.00), 2);
      if v_bill_id is null or v_alloc_amount <= 0 then
        continue;
      end if;

      select * into v_bill from public.bills where id = v_bill_id for update;
      if v_bill.id is null then
        raise exception 'Bill % not found', v_bill_id;
      end if;
      if v_bill.tenant_id <> v_parent_id then
        raise exception 'Bill % belongs to other books', v_bill_id;
      end if;
      if v_bill.invoice_type <> 'ap'::public.global_invoice_type then
        raise exception 'Bill % is not AP', v_bill.invoice_no;
      end if;
      if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
        raise exception 'Bill % is not issued', v_bill.invoice_no;
      end if;
      if v_bill.profile_id is distinct from p_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;

      v_channel_meta := coalesce(v_bill.channel_meta, '{}'::jsonb);
      v_foreign_face := public.ap_bill_channel_foreign_face(v_channel_meta);
      v_paper_currency := public.ap_bill_channel_currency(v_channel_meta);

      if upper(v_settle_currency) <> v_base_currency
         and v_fx_rate > 0
         and v_foreign_face is not null
         and v_foreign_face > 0
         and upper(coalesce(v_paper_currency, v_base_currency)) <> v_base_currency
      then
        if v_alloc_amount <= v_foreign_face + 0.01
           and v_alloc_amount < v_amount * 0.99
        then
          v_alloc_amount := round(v_alloc_amount * v_fx_rate, 2);
        end if;

        if abs(coalesce(v_bill.due_amount, 0) - v_foreign_face) < 0.02 then
          v_effective_due := round(v_foreign_face * v_fx_rate, 2);
        else
          v_effective_due := coalesce(v_bill.due_amount, 0);
        end if;
      else
        v_effective_due := coalesce(v_bill.due_amount, 0);
      end if;

      if v_alloc_amount > v_effective_due then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_effective_due;
      end if;

      perform public._kernel_record_pay_bill_settlement(
        v_parent_id,
        v_pay.id,
        v_bill_id,
        v_alloc_amount,
        false
      );
      v_total_alloc := v_total_alloc + v_alloc_amount;

      if v_bill.ap_shipment_id is not null
         and not (v_bill.ap_shipment_id = any(v_shipment_ids)) then
        v_shipment_ids := array_append(v_shipment_ids, v_bill.ap_shipment_id);
      end if;
    end loop;
  end if;

  if v_total_alloc > v_amount then
    raise exception 'AP payout allocations (%) exceed payment amount (%)', v_total_alloc, v_amount;
  end if;

  v_leftover := v_amount - v_total_alloc;

  update public.pays
  set unallocated_amount = v_leftover
  where id = v_pay.id
  returning * into v_pay;

  perform public.record_ledger_transaction(
    p_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'debit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'ap_payout',
      'transaction_type', 'ap_paid_out',
      'label', 'AP paid out',
      'payment_id', v_pay.id,
      'method', v_header_method,
      'reference', v_reference,
      'settlement_currency_code', v_settle_currency,
      'foreign_amount', v_foreign_amt,
      'exchange_rate', v_fx_rate,
      'source_currency_code', v_source_currency,
      'transaction_rate', v_transaction_rate,
      'source_amount', v_source_amount,
      'cashbook_point_pot_id', v_pot_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_cashbook_point_id
  );

  if coalesce(array_length(v_shipment_ids, 1), 0) > 0 then
    foreach v_sid in array v_shipment_ids
    loop
      perform public.refresh_global_shipment_fx_from_ap_payments(v_sid);
      perform public.stamp_global_shipment_landed_costs(v_sid);
    end loop;
  end if;

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_id, p_idempotency_key);
end;
$$;

-- from schemas/bills_pays/16_cashbook_transfer.sql
-- BP15-t: move cash between tenant cash points (same currency pot v1)

CREATE OR REPLACE FUNCTION public.transfer_cashbook_point(
  p_tenant_id bigint,
  p_from_point_id bigint,
  p_to_point_id bigint,
  p_currency_code text,
  p_amount numeric,
  p_note text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent_id bigint;
  v_ccy text := upper(trim(coalesce(p_currency_code, 'BDT')));
  v_amt numeric(12, 2);
  v_from public.cashbook_points;
  v_to public.cashbook_points;
  v_from_pot_id bigint;
  v_to_pot_id bigint;
  v_transfer_id text := gen_random_uuid()::text;
  v_note text := nullif(trim(coalesce(p_note, '')), '');
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;
  if p_from_point_id is null or p_to_point_id is null then
    raise exception 'From and to cash points are required.';
  end if;
  if p_from_point_id = p_to_point_id then
    raise exception 'From and to cash points must differ.';
  end if;

  v_amt := round(coalesce(p_amount, 0), 2);
  if v_amt <= 0 then
    raise exception 'Transfer amount must be greater than zero.';
  end if;
  if v_ccy = '' then
    v_ccy := 'BDT';
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  if not public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment') then
    raise exception 'Permission denied.';
  end if;

  select * into v_from
  from public.cashbook_points cp
  where cp.id = p_from_point_id
    and cp.tenant_id = v_parent_id
    and cp.is_active = true;

  if v_from.id is null then
    raise exception 'From cash point not found or inactive.';
  end if;

  select * into v_to
  from public.cashbook_points cp
  where cp.id = p_to_point_id
    and cp.tenant_id = v_parent_id
    and cp.is_active = true;

  if v_to.id is null then
    raise exception 'To cash point not found or inactive.';
  end if;

  v_from_pot_id := public._kernel_ensure_cashbook_point_pot(v_parent_id, p_from_point_id, v_ccy);
  v_to_pot_id := public._kernel_ensure_cashbook_point_pot(v_parent_id, p_to_point_id, v_ccy);

  perform public._kernel_lock_cashbook_points_for_transfer(
    p_from_point_id,
    p_to_point_id,
    v_ccy
  );

  perform public.record_ledger_transaction(
    p_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'debit',
    p_amount => v_amt,
    p_currency_code => v_ccy,
    p_exchange_rate => 1.000000,
    p_source_type => 'point_transfer',
    p_source_id => v_transfer_id,
    p_metadata => jsonb_build_object(
      'section', 'cashbook',
      'purpose', 'point_transfer_out',
      'transaction_type', 'point_transfer',
      'label', 'Cash moved out',
      'from_point_id', p_from_point_id,
      'to_point_id', p_to_point_id,
      'note', v_note,
      'cashbook_point_pot_id', v_from_pot_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_from_point_id
  );

  perform public.record_ledger_transaction(
    p_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'credit',
    p_amount => v_amt,
    p_currency_code => v_ccy,
    p_exchange_rate => 1.000000,
    p_source_type => 'point_transfer',
    p_source_id => v_transfer_id,
    p_metadata => jsonb_build_object(
      'section', 'cashbook',
      'purpose', 'point_transfer_in',
      'transaction_type', 'point_transfer',
      'label', 'Cash moved in',
      'from_point_id', p_from_point_id,
      'to_point_id', p_to_point_id,
      'note', v_note,
      'cashbook_point_pot_id', v_to_pot_id
    ),
    p_allow_overdraft => false,
    p_cashbook_point_id => p_to_point_id
  );

  return jsonb_build_object(
    'success', true,
    'transfer_id', v_transfer_id,
    'amount', v_amt,
    'currency_code', v_ccy,
    'from_point_id', p_from_point_id,
    'to_point_id', p_to_point_id
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public.transfer_cashbook_point(
  bigint, bigint, bigint, text, numeric, text
) TO authenticated, service_role;

-- from schemas/bills_pays/08_kernel_compose_adapters.sql
-- BP9 kernel compose / shop / courier / wholesale adapters
CREATE OR REPLACE FUNCTION public._insert_bill_line_from_compose_payload(
  p_parent_id bigint,
  p_invoice_id bigint,
  p_item_elem jsonb
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_line_meta jsonb;
  v_line_kind text;
  v_name_snapshot text;
  v_created_item_id bigint;
  v_stock_parent bigint;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
begin
  v_line_meta := coalesce(p_item_elem->'line_meta', '{}'::jsonb);
  v_global_stock_id := coalesce(
    nullif(p_item_elem->>'global_stock_id', '')::bigint,
    nullif(v_line_meta->'stock_ref'->>'global_stock_id', '')::bigint
  );
  v_quantity := nullif(p_item_elem->>'quantity', '')::numeric;
  v_sell_price := nullif(p_item_elem->>'sell_price_amount', '')::numeric;
  v_line_discount := coalesce(nullif(p_item_elem->>'line_discount_amount', '')::numeric, 0);
  v_line_kind := lower(trim(coalesce(p_item_elem->>'line_kind', '')));

  if v_quantity is null or v_quantity <= 0 then
    raise exception 'each item requires quantity > 0';
  end if;
  if v_sell_price is null or v_sell_price < 0 then
    raise exception 'each item requires sell_price_amount >= 0';
  end if;

  if v_global_stock_id is null and coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
    v_product_id := nullif(p_item_elem->>'product_id', '')::bigint;
    v_shipment_item_id := nullif(p_item_elem->>'shipment_item_id', '')::bigint;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Gift item');
    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest((v_quantity * v_sell_price) - v_line_discount, 0)
    );

    insert into public.bill_lines (
      tenant_id, invoice_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
    ) values (
      p_parent_id, p_invoice_id, v_shipment_item_id, v_product_id,
      v_name_snapshot,
      nullif(trim(p_item_elem->>'barcode_snapshot'), ''),
      nullif(trim(p_item_elem->>'product_code_snapshot'), ''),
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      nullif(p_item_elem->>'assigned_child_tenant_id', '')::bigint,
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  if v_global_stock_id is null then
    if v_line_kind = '' then
      v_line_kind := 'description';
    end if;
    if v_line_kind not in ('description', 'charge') then
      raise exception 'non-stock items require line_kind description or charge';
    end if;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Line');
    v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

    insert into public.bill_lines (
      tenant_id, invoice_id, line_kind, name_snapshot,
      quantity, sell_price_amount, line_discount_amount, line_total_amount,
      currency_code, books_amount, line_meta
    ) values (
      p_parent_id, p_invoice_id, v_line_kind, v_name_snapshot,
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      upper(trim(coalesce(p_item_elem->>'currency_code', 'BDT'))),
      coalesce(nullif(p_item_elem->>'books_amount', '')::numeric, v_line_total),
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  select
    gs.tenant_id, gs.shipment_item_id, gsi.name, gsi.barcode, gsi.product_code,
    sh.assigned_child_tenant_id, p.id
  into
    v_stock_parent, v_shipment_item_id, v_name_snapshot, v_barcode_snapshot,
    v_product_code_snapshot, v_assigned_child, v_product_id
  from public.global_stocks gs
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments sh on sh.id = gsi.shipment_id
  left join public.products p on p.id = gsi.product_id
  where gs.id = v_global_stock_id;

  if v_stock_parent is null then
    raise exception 'stock % not found', v_global_stock_id;
  end if;
  if v_stock_parent <> p_parent_id then
    raise exception 'stock % does not belong to invoice parent tenant', v_global_stock_id;
  end if;

  v_shipment_item_id := coalesce(nullif(p_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
  v_product_id := coalesce(nullif(p_item_elem->>'product_id', '')::bigint, v_product_id);
  v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
  v_line_total := coalesce(
    nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
    greatest((v_quantity * v_sell_price) - v_line_discount, 0)
  );

  v_line_meta := jsonb_set(
    coalesce(v_line_meta, '{}'::jsonb),
    '{stock_ref}',
    jsonb_build_object('global_stock_id', v_global_stock_id),
    true
  );

  insert into public.bill_lines (
    tenant_id, invoice_id, line_kind, shipment_item_id, product_id,
    name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
    sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
  ) values (
    p_parent_id, p_invoice_id, 'stock', v_shipment_item_id, v_product_id,
    v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot,
    v_quantity, v_sell_price, v_line_discount, v_line_total, v_assigned_child, v_line_meta
  )
  returning id into v_created_item_id;
  return v_created_item_id;
end;
$$;
CREATE OR REPLACE FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type", "p_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_retail_billing_mode" "public"."retail_billing_mode" DEFAULT NULL::"public"."retail_billing_mode", "p_due_date" "date" DEFAULT NULL::"date", "p_note" "text" DEFAULT NULL::"text", "p_invoice_date" "date" DEFAULT NULL::"date") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.bills;
  v_parent_id bigint;
  v_issued_by bigint;
  v_rec_name text;
  v_rec_phone text;
  v_rec_address text;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_bill_name text;
  v_bill_phone text;
  v_bill_address text;
  v_collection_source public.collection_source_type;
  v_invoice_no text;
  v_invoice_date date;
begin
  v_issued_by := p_tenant_id;
  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_invoice_date := coalesce(p_invoice_date, CURRENT_DATE);

  if not (
    public.user_can_manage_books_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where (m.tenant_id = p_tenant_id or m.tenant_id = v_parent_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
    or public.is_superadmin()
  ) then
    raise exception 'not allowed';
  end if;

  if p_profile_id is not null then
    if not public.profile_valid_for_issuer(p_profile_id, v_issued_by) then
      raise exception 'billing profile not accessible for this tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not public.recipient_profile_valid_for_issuer(p_recipient_profile_id, v_issued_by) then
      raise exception 'recipient profile not accessible for this tenant';
    end if;
  end if;

  if p_invoice_type = 'wholesale'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for wholesale invoices';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;

  elsif p_invoice_type = 'retail'::public.global_invoice_type then
    if p_retail_billing_mode is null then
      raise exception 'retail billing mode (account or direct) is required for retail invoices';
    end if;

    if p_retail_billing_mode = 'account'::public.retail_billing_mode then
      if p_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
      v_collection_source := 'profile'::public.collection_source_type;
    else
      if p_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
      v_collection_source := 'recipient'::public.collection_source_type;
    end if;

  elsif p_invoice_type = 'dropship'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'billing profile (middle man) is required for dropship invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for dropship invoices';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;
  elsif p_invoice_type = 'ap'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'payee profile_id is required for AP bills';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;
  end if;

  if p_recipient_profile_id is not null then
    select name, phone, address
    into v_rec_name, v_rec_phone, v_rec_address
    from public.recipient_profiles
    where id = p_recipient_profile_id;
  end if;

  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_rec_name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_rec_phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_rec_address);

  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.profiles
    where id = p_profile_id;

    v_recipient_name := coalesce(v_recipient_name, v_bill_name);
    v_recipient_phone := coalesce(v_recipient_phone, v_bill_phone);
    v_recipient_address := coalesce(v_recipient_address, v_bill_address);
  end if;

  -- Resolve invoice_no: auto-generate if omitted or empty
  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := public.generate_sales_invoice_number(p_tenant_id, p_invoice_type, v_invoice_date);
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  insert into public.bills (
    tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    due_date,
    payment_status,
    note
  )
  values (
    v_parent_id,
    v_issued_by,
    v_invoice_no,
    p_invoice_type,
    v_invoice_date,
    p_retail_billing_mode,
    'draft'::public.global_invoice_status,
    p_profile_id,
    p_recipient_profile_id,
    v_recipient_name,
    v_recipient_phone,
    v_recipient_address,
    v_collection_source,
    p_due_date,
    'due',
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning * into v_row;

  perform public.stamp_bill_kernel_fields(v_row.id);
  select * into v_row from public.bills where id = v_row.id;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_compose_draft_json(p_payload jsonb) RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_inv jsonb;
  v_item_elem jsonb;
  v_invoice public.bills;
  v_invoice_id bigint;
  v_parent_id bigint;
  v_invoice_type public.global_invoice_type;
  v_retail_mode public.retail_billing_mode;
  v_issue boolean;
  v_shop_order_id bigint;
  v_items jsonb;
  v_item_ids bigint[] := '{}';
  v_created_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_stock_parent bigint;
  v_has_charges boolean;
  v_cod_charge numeric(12,2);
  v_line_meta jsonb;
  v_channel_meta jsonb;
  v_delivery_kind text;
begin
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'tenant_id required');
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object');
  end if;

  v_inv := coalesce(p_payload->'invoice', '{}'::jsonb);
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_issue := coalesce((p_payload->>'issue')::boolean, false);
  v_shop_order_id := nullif(p_payload->>'shop_order_id', '')::bigint;
  if v_inv->>'invoice_type' is null or trim(v_inv->>'invoice_type') = '' then
    return jsonb_build_object('success', false, 'error', 'invoice.invoice_type is required');
  end if;

  v_invoice_type := (v_inv->>'invoice_type')::public.global_invoice_type;

  v_channel_meta := coalesce(v_inv->'channel_meta', '{}'::jsonb);
  v_delivery_kind := lower(trim(coalesce(v_channel_meta->>'delivery_kind', 'take')));
  if v_invoice_type = 'ap'::public.global_invoice_type then
    v_delivery_kind := 'take';
  elsif v_delivery_kind not in ('take', 'condition') then
    return jsonb_build_object('success', false, 'error', 'channel_meta.delivery_kind must be take or condition');
  end if;

  if jsonb_typeof(v_items) <> 'array' then
    return jsonb_build_object('success', false, 'error', 'items must be a JSON array');
  end if;

  if v_issue and jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'at least one item is required when issue is true');
  end if;

  v_retail_mode := case
    when v_inv->>'retail_billing_mode' is null or trim(v_inv->>'retail_billing_mode') = '' then null
    else (v_inv->>'retail_billing_mode')::public.retail_billing_mode
  end;

  if v_delivery_kind = 'condition' then
    if v_invoice_type <> 'wholesale'::public.global_invoice_type then
      return jsonb_build_object('success', false, 'error', 'condition bills require wholesale invoice_type');
    end if;
    if v_retail_mode = 'direct'::public.retail_billing_mode then
      return jsonb_build_object('success', false, 'error', 'walk-in bills cannot be condition');
    end if;
    if v_issue and not exists (
      select 1 from jsonb_array_elements(v_items) e
      where nullif(e.value->>'global_stock_id', '') is not null
    ) then
      return jsonb_build_object('success', false, 'error', 'condition bills require at least one stock line');
    end if;
  end if;

  if v_invoice_type = 'ap'::public.global_invoice_type and exists (
    select 1 from jsonb_array_elements(v_items) e
    where nullif(e.value->>'global_stock_id', '') is not null
  ) then
    return jsonb_build_object('success', false, 'error', 'AP bills cannot have stock lines');
  end if;

  v_channel_meta := coalesce(v_channel_meta, '{}'::jsonb) || jsonb_build_object('delivery_kind', v_delivery_kind);

  select * into v_invoice
  from public.create_sales_invoice(
    p_tenant_id => v_tenant_id,
    p_invoice_no => coalesce(nullif(trim(v_inv->>'invoice_no'), ''), ''),
    p_invoice_type => v_invoice_type,
    p_profile_id => nullif(v_inv->>'profile_id', '')::bigint,
    p_recipient_profile_id => nullif(v_inv->>'recipient_profile_id', '')::bigint,
    p_recipient_name => nullif(trim(v_inv->>'recipient_name'), ''),
    p_recipient_phone => nullif(trim(v_inv->>'recipient_phone'), ''),
    p_recipient_address => nullif(trim(v_inv->>'recipient_address'), ''),
    p_retail_billing_mode => v_retail_mode,
    p_due_date => nullif(v_inv->>'due_date', '')::date,
    p_note => nullif(trim(v_inv->>'note'), ''),
    p_invoice_date => nullif(v_inv->>'invoice_date', '')::date
  );

  v_invoice_id := v_invoice.id;
  v_parent_id := v_invoice.tenant_id;

  update public.bills
  set
    shop_order_id = v_shop_order_id,
    channel_meta = v_channel_meta,
    settlement_kind = v_delivery_kind::public.bill_settlement_kind,
    updated_at = now()
  where id = v_invoice_id;

  perform public.stamp_bill_kernel_fields(v_invoice_id);

  for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
    v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
    v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
    v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
    v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);
    v_line_meta := coalesce(v_item_elem->'line_meta', '{}'::jsonb);

    if v_quantity is null or v_quantity <= 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires quantity > 0');
    end if;
    if v_sell_price is null or v_sell_price < 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires sell_price_amount >= 0');
    end if;

    if v_global_stock_id is null
       and coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
      v_product_id := nullif(v_item_elem->>'product_id', '')::bigint;
      v_shipment_item_id := nullif(v_item_elem->>'shipment_item_id', '')::bigint;
      v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), 'Gift item');
      v_barcode_snapshot := nullif(trim(v_item_elem->>'barcode_snapshot'), '');
      v_product_code_snapshot := nullif(trim(v_item_elem->>'product_code_snapshot'), '');
      v_assigned_child := nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint;
      v_line_total := coalesce(
        nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
        greatest((v_quantity * v_sell_price) - v_line_discount, 0)
      );

      insert into public.bill_lines (
        tenant_id,
        invoice_id,
        shipment_item_id,
        product_id,
        name_snapshot,
        barcode_snapshot,
        product_code_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        assigned_child_tenant_id,
        line_meta
      )
      values (
        v_parent_id,
        v_invoice_id,
        v_shipment_item_id,
        v_product_id,
        v_name_snapshot,
        v_barcode_snapshot,
        v_product_code_snapshot,
        v_quantity,
        v_sell_price,
        v_line_discount,
        v_line_total,
        v_assigned_child,
        v_line_meta
      );

      continue;
    end if;

    if v_global_stock_id is null
       and coalesce(v_line_meta->>'is_warehouse_gift', 'false') <> 'true' then
      v_created_item_id := public._insert_bill_line_from_compose_payload(v_parent_id, v_invoice_id, v_item_elem);
      v_item_ids := array_append(v_item_ids, v_created_item_id);
      continue;
    end if;

    if v_global_stock_id is null then
      continue;
    end if;

    select
      gs.tenant_id,
      gs.shipment_item_id,
      gsi.name,
      gsi.barcode,
      gsi.product_code,
      sh.assigned_child_tenant_id,
      p.id
    into
      v_stock_parent,
      v_shipment_item_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_assigned_child,
      v_product_id
    from public.global_stocks gs
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    left join public.products p on p.id = gsi.product_id
    where gs.id = v_global_stock_id;

    if v_stock_parent is null then
      return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id));
    end if;

    if v_stock_parent <> v_parent_id then
      return jsonb_build_object('success', false, 'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id));
    end if;

    v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
    v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
    v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
    v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
    v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
    v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);

    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest((v_quantity * v_sell_price) - v_line_discount, 0)
    );

    v_line_meta := jsonb_set(
      coalesce(v_line_meta, '{}'::jsonb),
      '{stock_ref}',
      jsonb_build_object('global_stock_id', v_global_stock_id),
      true
    );

    insert into public.bill_lines (
      tenant_id,
      invoice_id,
      line_kind,
      shipment_item_id,
      product_id,
      name_snapshot,
      barcode_snapshot,
      product_code_snapshot,
      quantity,
      sell_price_amount,
      line_discount_amount,
      line_total_amount,
      assigned_child_tenant_id,
      line_meta
    )
    values (
      v_parent_id,
      v_invoice_id,
      'stock',
      v_shipment_item_id,
      v_product_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_quantity,
      v_sell_price,
      v_line_discount,
      v_line_total,
      v_assigned_child,
      v_line_meta
    )
    returning id into v_created_item_id;

    v_item_ids := array_append(v_item_ids, v_created_item_id);
  end loop;

  v_cod_charge := case
    when v_invoice_type = 'wholesale'::public.global_invoice_type then null
    when v_inv ? 'cod_charge_amount' then nullif(v_inv->>'cod_charge_amount', '')::numeric
    when v_inv ? 'cod_charge' then nullif(v_inv->>'cod_charge', '')::numeric
    else null
  end;

  v_has_charges := (
    v_inv ? 'discount_amount'
    or v_inv ? 'shipping_charge'
    or v_inv ? 'print_charge'
    or v_inv ? 'wrapping_charge'
    or (
      v_invoice_type <> 'wholesale'::public.global_invoice_type
      and (v_inv ? 'cod_charge_amount' or v_inv ? 'cod_charge')
    )
  );

  if v_has_charges then
    perform public.update_global_invoice_header(
      p_invoice_id => v_invoice_id,
      p_discount_amount => case when v_inv ? 'discount_amount' then nullif(v_inv->>'discount_amount', '')::numeric else null end,
      p_shipping_charge => case when v_inv ? 'shipping_charge' then nullif(v_inv->>'shipping_charge', '')::numeric else null end,
      p_cod_charge => v_cod_charge,
      p_wrapping_charge => case when v_inv ? 'wrapping_charge' then nullif(v_inv->>'wrapping_charge', '')::numeric else null end,
      p_print_charge => case when v_inv ? 'print_charge' then nullif(v_inv->>'print_charge', '')::numeric else null end,
      p_recipient_name => null,
      p_recipient_phone => null,
      p_recipient_address => null,
      p_note => null,
      p_invoice_no => null,
      p_invoice_date => null
    );
  else
    perform public.recompute_global_invoice_totals(v_invoice_id);
  end if;

  if v_issue then
    perform public.post_sales_invoice(v_invoice_id);
    perform public.sync_sales_invoice_charges_from_header(v_invoice_id);
  end if;

  if v_shop_order_id is not null then
    if not exists (
      select 1 from public.shop_orders o
      where o.id = v_shop_order_id
        and o.tenant_id = v_tenant_id
        and o.shop_type_snapshot = 'dropship'
    ) then
      return jsonb_build_object('success', false, 'error', 'shop_order_id must be a dropship order for this tenant');
    end if;

    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = v_shop_order_id
      and tenant_id = v_tenant_id
      and global_invoice_id is null;
  end if;

  select * into v_invoice from public.bills where id = v_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'subtotal_amount', v_invoice.subtotal_amount,
    'discount_amount', v_invoice.discount_amount,
    'shipping_charge', v_invoice.shipping_charge,
    'cod_charge_amount', coalesce((v_invoice.channel_meta->>'cod_charge_amount')::numeric, 0),
    'print_charge', v_invoice.print_charge,
    'wrapping_charge', v_invoice.wrapping_charge,
    'total_amount', v_invoice.total_amount,
    'paid_amount', v_invoice.paid_amount,
    'due_amount', v_invoice.due_amount,
    'profile_id', v_invoice.profile_id,
    'collection_source', v_invoice.collection_source,
    'item_ids', to_jsonb(v_item_ids),
    'issued', v_issue,
    'shop_order_id', v_shop_order_id
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_update_compose_draft_json(p_tenant_id bigint, p_invoice_id bigint, p_payload jsonb) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_inv_patch jsonb;
  v_items jsonb;
  v_remove_ids jsonb;
  v_item_elem jsonb;
  v_invoice public.bills;
  v_parent_id bigint;
  v_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_line_meta jsonb;
  v_stock_parent bigint;
  v_db_item public.bill_lines;
  v_removed_ids bigint[] := '{}';
  v_remove_id bigint;
  v_created_item_id bigint;
  v_result_items jsonb := '[]'::jsonb;
  v_has_changes boolean := false;
  v_recompute boolean := true;
  v_dropship_sync boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied', 'code', 'ACCESS_DENIED');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object', 'code', 'VALIDATION_ERROR');
  end if;

  v_dropship_sync := coalesce((p_payload->'options'->>'dropship_sync')::boolean, false);

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice not found', 'code', 'NOT_FOUND');
  end if;

  if v_invoice.issued_by_tenant_id <> p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'invoice does not belong to tenant', 'code', 'ACCESS_DENIED');
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    if not (
      v_dropship_sync
      and v_invoice.invoice_type = 'dropship'::public.global_invoice_type
      and v_invoice.invoice_status = 'issued'::public.global_invoice_status
    ) then
      return jsonb_build_object(
        'success', false,
        'error', format('invoice is not editable (status: %s)', v_invoice.invoice_status),
        'code', 'INVOICE_NOT_EDITABLE'
      );
    end if;
  end if;

  v_inv_patch := p_payload->'invoice';
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_remove_ids := coalesce(p_payload->'remove_item_ids', '[]'::jsonb);
  v_recompute := coalesce((p_payload->'options'->>'recompute_totals')::boolean, true);

  if v_dropship_sync and v_invoice.invoice_status = 'issued'::public.global_invoice_status then
    v_remove_ids := '[]'::jsonb;
  end if;

  if (v_inv_patch is null or v_inv_patch = '{}'::jsonb)
     and jsonb_array_length(v_items) = 0
     and jsonb_array_length(v_remove_ids) = 0 then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  v_parent_id := v_invoice.tenant_id;

  if v_inv_patch is not null and jsonb_typeof(v_inv_patch) = 'object' and v_inv_patch <> '{}'::jsonb then
    if v_inv_patch ? 'profile_id' and nullif(v_inv_patch->>'profile_id', '') is not null then
      if not exists (
        select 1 from public.profiles pr
        where pr.id = (v_inv_patch->>'profile_id')::bigint
          and pr.operating_tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'billing profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    if v_inv_patch ? 'recipient_profile_id' and nullif(v_inv_patch->>'recipient_profile_id', '') is not null then
      if not exists (
        select 1 from public.recipient_profiles rp
        where rp.id = (v_inv_patch->>'recipient_profile_id')::bigint
          and rp.tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'recipient profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    update public.bills
    set
      invoice_no = case
        when v_inv_patch ? 'invoice_no' then coalesce(nullif(trim(v_inv_patch->>'invoice_no'), ''), invoice_no)
        else invoice_no
      end,
      invoice_date = case
        when v_inv_patch ? 'invoice_date' then coalesce(nullif(v_inv_patch->>'invoice_date', '')::date, invoice_date)
        else invoice_date
      end,
      due_date = case
        when v_inv_patch ? 'due_date' then nullif(v_inv_patch->>'due_date', '')::date
        else due_date
      end,
      profile_id = case
        when v_inv_patch ? 'profile_id' then nullif(v_inv_patch->>'profile_id', '')::bigint
        else profile_id
      end,
      recipient_profile_id = case
        when v_inv_patch ? 'recipient_profile_id' then nullif(v_inv_patch->>'recipient_profile_id', '')::bigint
        else recipient_profile_id
      end,
      recipient_name = case
        when v_inv_patch ? 'recipient_name' then nullif(trim(v_inv_patch->>'recipient_name'), '')
        else recipient_name
      end,
      recipient_phone = case
        when v_inv_patch ? 'recipient_phone' then nullif(trim(v_inv_patch->>'recipient_phone'), '')
        else recipient_phone
      end,
      recipient_address = case
        when v_inv_patch ? 'recipient_address' then nullif(trim(v_inv_patch->>'recipient_address'), '')
        else recipient_address
      end,
      note = case
        when v_inv_patch ? 'note' then nullif(trim(v_inv_patch->>'note'), '')
        else note
      end,
      discount_amount = case
        when v_inv_patch ? 'discount_amount' then coalesce(nullif(v_inv_patch->>'discount_amount', '')::numeric, 0)
        else discount_amount
      end,
      shipping_charge = case
        when v_inv_patch ? 'shipping_charge' then coalesce(nullif(v_inv_patch->>'shipping_charge', '')::numeric, 0)
        else shipping_charge
      end,
      channel_meta = case
        when v_inv_patch ? 'channel_meta' and jsonb_typeof(v_inv_patch->'channel_meta') = 'object'
          then coalesce(channel_meta, '{}'::jsonb) || (v_inv_patch->'channel_meta')
        when v_inv_patch ? 'cod_charge_amount' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge_amount', '')::numeric, 0))
        when v_inv_patch ? 'cod_charge' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge', '')::numeric, 0))
        else channel_meta
      end,
      print_charge = case
        when v_inv_patch ? 'print_charge' then coalesce(nullif(v_inv_patch->>'print_charge', '')::numeric, 0)
        else print_charge
      end,
      wrapping_charge = case
        when v_inv_patch ? 'wrapping_charge' then coalesce(nullif(v_inv_patch->>'wrapping_charge', '')::numeric, 0)
        else wrapping_charge
      end,
      collection_source = case
        when v_inv_patch ? 'collection_source' and nullif(trim(v_inv_patch->>'collection_source'), '') is not null
          then (v_inv_patch->>'collection_source')::public.collection_source_type
        else collection_source
      end,
      updated_at = now()
    where id = p_invoice_id;

    v_has_changes := true;
  end if;

  if jsonb_typeof(v_remove_ids) = 'array' and jsonb_array_length(v_remove_ids) > 0 then
    for v_remove_id in
      select (value::text)::bigint
      from jsonb_array_elements(v_remove_ids) as t(value)
      where value is not null and value::text ~ '^[0-9]+$'
    loop
      delete from public.bill_lines
      where id = v_remove_id
        and invoice_id = p_invoice_id
      returning id into v_item_id;

      if v_item_id is not null then
        v_removed_ids := array_append(v_removed_ids, v_item_id);
        v_has_changes := true;
      end if;
    end loop;
  end if;

  if jsonb_typeof(v_items) = 'array' and jsonb_array_length(v_items) > 0 then
    for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
      v_item_id := nullif(v_item_elem->>'id', '')::bigint;

      if v_item_id is not null then
        select * into v_db_item
        from public.bill_lines
        where id = v_item_id
          and invoice_id = p_invoice_id;

        if v_db_item.id is null then
          return jsonb_build_object(
            'success', false,
            'error', format('invoice item %s not found on invoice', v_item_id),
            'code', 'NOT_FOUND'
          );
        end if;

        v_quantity := coalesce(
          case when v_item_elem ? 'quantity' then nullif(v_item_elem->>'quantity', '')::numeric else null end,
          v_db_item.quantity
        );
        v_sell_price := coalesce(
          case when v_item_elem ? 'sell_price_amount' then nullif(v_item_elem->>'sell_price_amount', '')::numeric else null end,
          v_db_item.sell_price_amount
        );
        v_line_discount := coalesce(
          case when v_item_elem ? 'line_discount_amount' then nullif(v_item_elem->>'line_discount_amount', '')::numeric else null end,
          v_db_item.line_discount_amount,
          0
        );

        if v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'quantity must be > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'sell_price_amount must be >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        update public.bill_lines
        set
          quantity = v_quantity,
          sell_price_amount = v_sell_price,
          line_discount_amount = v_line_discount,
          line_total_amount = v_line_total,
          books_amount = coalesce(books_amount, v_line_total),
          name_snapshot = case
            when v_item_elem ? 'name_snapshot' then coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), name_snapshot)
            else name_snapshot
          end,
          line_kind = case
            when v_item_elem ? 'line_kind' then lower(trim(v_item_elem->>'line_kind'))
            else line_kind
          end,
          updated_at = now()
        where id = v_item_id
        returning * into v_db_item;

        v_has_changes := true;
      elsif not v_dropship_sync then
        v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
        v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
        v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
        v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);

        if v_global_stock_id is null then
          begin
            v_created_item_id := public._insert_bill_line_from_compose_payload(v_parent_id, p_invoice_id, v_item_elem);
            v_db_item.id := v_created_item_id;
          exception when others then
            return jsonb_build_object('success', false, 'error', sqlerrm, 'code', 'VALIDATION_ERROR');
          end;
          v_has_changes := true;
          continue;
        end if;
        if v_quantity is null or v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'new items require quantity > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price is null or v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'new items require sell_price_amount >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        select
          gs.tenant_id,
          gs.shipment_item_id,
          gsi.name,
          gsi.barcode,
          gsi.product_code,
          sh.assigned_child_tenant_id,
          p.id
        into
          v_stock_parent,
          v_shipment_item_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_assigned_child,
          v_product_id
        from public.global_stocks gs
        left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
        left join public.global_shipments sh on sh.id = gsi.shipment_id
        left join public.products p on p.id = gsi.product_id
        where gs.id = v_global_stock_id;

        if v_stock_parent is null then
          return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id), 'code', 'NOT_FOUND');
        end if;

        if v_stock_parent <> v_parent_id then
          return jsonb_build_object(
            'success', false,
            'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id),
            'code', 'VALIDATION_ERROR'
          );
        end if;

        v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
        v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
        v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
        v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
        v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
        v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);
        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);
        v_line_meta := jsonb_set(
          coalesce(v_db_item.line_meta, '{}'::jsonb),
          '{stock_ref}',
          jsonb_build_object('global_stock_id', v_global_stock_id),
          true
        );

        insert into public.bill_lines (
          tenant_id,
          invoice_id,
          line_kind,
          shipment_item_id,
          product_id,
          name_snapshot,
          barcode_snapshot,
          product_code_snapshot,
          quantity,
          sell_price_amount,
          line_discount_amount,
          line_total_amount,
          assigned_child_tenant_id,
          line_meta
        )
        values (
          v_parent_id,
          p_invoice_id,
          'stock',
          v_shipment_item_id,
          v_product_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_quantity,
          v_sell_price,
          v_line_discount,
          v_line_total,
          v_assigned_child,
          v_line_meta
        )
        returning * into v_db_item;

        v_has_changes := true;
      end if;
    end loop;
  end if;

  if not v_has_changes then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  if v_recompute then
    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  select * into v_invoice from public.bills where id = p_invoice_id;

  if v_dropship_sync then
    if v_invoice.invoice_status in (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) then
      perform public.post_sales_invoice(p_invoice_id);
      select * into v_invoice from public.bills where id = p_invoice_id;
    elsif v_invoice.payment_status not in ('paid', 'partially_paid') then
      update public.bills
      set
        payment_status = 'due',
        due_amount = greatest(coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0), 0),
        updated_at = now()
      where id = p_invoice_id;
      select * into v_invoice from public.bills where id = p_invoice_id;
    end if;
    perform public.recompute_global_invoice_payment_status(p_invoice_id);
    select * into v_invoice from public.bills where id = p_invoice_id;
  end if;

  select coalesce(jsonb_agg(to_jsonb(sii.*) order by sii.id), '[]'::jsonb)
  into v_result_items
  from public.bill_lines sii
  where sii.invoice_id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'tenant_id', v_invoice.tenant_id,
      'issued_by_tenant_id', v_invoice.issued_by_tenant_id,
      'invoice_type', v_invoice.invoice_type,
      'invoice_no', v_invoice.invoice_no,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'profile_id', v_invoice.profile_id,
      'recipient_profile_id', v_invoice.recipient_profile_id,
      'recipient_name', v_invoice.recipient_name,
      'recipient_phone', v_invoice.recipient_phone,
      'recipient_address', v_invoice.recipient_address,
      'collection_source', v_invoice.collection_source,
      'subtotal_amount', v_invoice.subtotal_amount,
      'discount_amount', v_invoice.discount_amount,
      'shipping_charge', v_invoice.shipping_charge,
      'cod_charge_amount', coalesce((v_invoice.channel_meta->>'cod_charge_amount')::numeric, 0),
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'note', v_invoice.note,
      'due_date', v_invoice.due_date,
      'invoice_date', v_invoice.invoice_date
    ),
    'items', v_result_items,
    'removed_item_ids', to_jsonb(v_removed_ids)
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm, 'code', 'VALIDATION_ERROR');
end;
$_$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_dropship_courier_ap(p_order_id bigint, p_keep_as_draft boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_books_tenant_id bigint;
  v_profile_id bigint;
  v_bill public.bills;
  v_amount numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_paper_status public.global_invoice_status;
  v_courier public.courier_services;
  v_tenant_name text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required');
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  select * into v_courier
  from public.courier_services cs
  where cs.id = v_order.courier_service_id;

  if v_courier.id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required');
  end if;

  select t.name into v_tenant_name
  from public.tenants t
  where t.id = v_order.tenant_id;

  perform public.upsert_profile_for_party(
    v_books_tenant_id,
    'tenant'::public.profile_party_type,
    v_order.tenant_id,
    coalesce(v_tenant_name, 'Tenant'),
    null,
    null,
    '+880',
    null,
    false,
    null,
    true,
    null
  );

  select p.id into v_profile_id
  from public.profiles p
  where p.tenant_id = v_books_tenant_id
    and p.profile_type = 'courier'::public.profile_party_type
    and p.subject_id = v_courier.wallet_entity_id
  limit 1;

  if v_profile_id is null then
    v_profile_id := public.upsert_profile_for_party(
      v_books_tenant_id,
      'courier'::public.profile_party_type,
      v_courier.wallet_entity_id,
      v_courier.name,
      null,
      null,
      '+880',
      null,
      false,
      null,
      coalesce(v_courier.is_active, true),
      null
    );
  end if;

  if v_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'courier profile is required');
  end if;

  v_amount := round(
    coalesce(
      nullif(
        coalesce(v_order.delivery_charge_amount, 0) + coalesce(v_order.cod_charge_amount, 0),
        0
      ),
      nullif(v_order.courier_cost_amount, 0),
      nullif(v_courier.inside_dhaka_fee, 0),
      0
    ),
    2
  );

  select * into v_bill
  from public.bills b
  where b.tenant_id = v_books_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
  for update;

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := 'AP-CR-' || v_order.order_no;
    insert into public.bills (
      tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind,
      recipient_name, recipient_phone, recipient_address
    ) values (
      v_books_tenant_id, v_order.tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, v_profile_id, 'profile'::public.collection_source_type, 'due',
      v_amount, v_amount, v_amount, 0,
      'dropship_courier', p_order_id::text, 'courier', 'BDT',
      format('Courier AP — %s — order %s', v_courier.name, v_order.order_no),
      '{}'::jsonb,
      'standard'::public.bill_document_kind,
      v_order.recipient_name, v_order.recipient_phone, v_order.shipping_address
    )
    returning * into v_bill;
    perform public._sync_dropship_courier_ap_bill_details(v_bill.id, p_order_id, true);
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'created', true, 'amount', v_amount);
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true);
    end if;
    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = v_profile_id,
      source_type = 'dropship_courier',
      source_id = p_order_id::text,
      source_key = 'courier',
      subtotal_amount = v_amount,
      total_amount = v_amount,
      due_amount = v_amount,
      payment_status = 'due',
      recipient_name = v_order.recipient_name,
      recipient_phone = v_order.recipient_phone,
      recipient_address = v_order.shipping_address,
      updated_at = now()
    where id = v_bill.id;
    perform public._sync_dropship_courier_ap_bill_details(v_bill.id, p_order_id, true);
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'revived', true, 'amount', v_amount);
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status then
    perform public._sync_dropship_courier_ap_bill_details(
      v_bill.id,
      p_order_id,
      coalesce(v_bill.paid_amount, 0) = 0
    );
    if coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_no not like 'AP-CR-%' then
      update public.bills b
      set invoice_no = 'AP-CR-' || v_order.order_no,
          updated_at = now()
      where b.id = v_bill.id
        and not exists (
          select 1
          from public.bills b2
          where b2.tenant_id = v_books_tenant_id
            and b2.invoice_no = 'AP-CR-' || v_order.order_no
            and b2.id <> b.id
        );
    end if;
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true, 'amount', v_bill.total_amount);
  end if;

  if coalesce(v_bill.paid_amount, 0) > 0 then
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true, 'amount', v_bill.total_amount);
  end if;

  v_due := greatest(v_amount - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = v_profile_id,
    source_type = 'dropship_courier',
    source_id = p_order_id::text,
    source_key = 'courier',
    subtotal_amount = v_amount,
    total_amount = v_amount,
    due_amount = v_due,
    payment_status = v_status,
    invoice_status = case
      when invoice_status = 'issued'::public.global_invoice_status then invoice_status
      else v_paper_status
    end,
    recipient_name = v_order.recipient_name,
    recipient_phone = v_order.recipient_phone,
    recipient_address = v_order.shipping_address,
    updated_at = now()
  where id = v_bill.id;

  perform public._sync_dropship_courier_ap_bill_details(v_bill.id, p_order_id, true);
  perform public.stamp_bill_kernel_fields(v_bill.id);
  return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'amount', v_amount);
end;
$$;



CREATE OR REPLACE FUNCTION public._kernel_issue_wholesale_stock(p_invoice_id bigint, p_items jsonb DEFAULT NULL::jsonb)
 RETURNS bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.bills;
  v_item_record jsonb;
  v_item_id bigint;
  v_item_qty numeric;
  v_item_price numeric;
  v_line_total numeric;
  v_db_item public.bill_lines%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can be issued';
  end if;

  if v_invoice.profile_id is null then
    raise exception 'Billing profile is required for wholesale invoices';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);
  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);

  -- 1. Optionally apply batch quantity/price updates from dialog payload
  if p_items is not null and jsonb_typeof(p_items) = 'array' and jsonb_array_length(p_items) > 0 then
    for v_item_record in select * from jsonb_array_elements(p_items) loop
      v_item_id := (v_item_record->>'id')::bigint;
      v_item_qty := (v_item_record->>'quantity')::numeric;
      v_item_price := (v_item_record->>'sell_price_amount')::numeric;

      if v_item_id is not null and v_item_qty is not null and v_item_qty > 0 then
        select * into v_db_item from public.bill_lines where id = v_item_id and invoice_id = p_invoice_id;
        if v_db_item.id is not null then
          v_item_price := coalesce(v_item_price, v_db_item.sell_price_amount);
          v_line_total := greatest((v_item_qty * v_item_price) - coalesce(v_db_item.line_discount_amount, 0.00), 0.00);

          update public.bill_lines
          set
            quantity = v_item_qty,
            sell_price_amount = v_item_price,
            line_total_amount = v_line_total
          where id = v_item_id;
        end if;
      end if;
    end loop;

    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  if not exists (select 1 from public.bill_lines where invoice_id = p_invoice_id) then
    raise exception 'Cannot issue an empty invoice';
  end if;

  if exists (
    select 1
    from public.bill_lines bl
    where bl.invoice_id = p_invoice_id
      and public._bill_line_global_stock_id(bl) is not null
  ) and not exists (
    select 1
    from public.stock_movements sm
    where sm.reference_type = 'sales_invoice'
      and sm.reference_id = p_invoice_id::text
      and sm.is_posted = true
  ) then
    raise exception 'Stock must be committed before issue — call commit_wholesale_bill_stock first';
  end if;

  -- Mark invoice as issued (status = 'issued'::public.global_invoice_status)
  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(payment_status, ''), 'due')
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$function$;


-- ---------------------------------------------------------------------------
-- Kernel wrappers (BP9)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_upsert_compose_draft(p_payload jsonb)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_result jsonb;
  v_bill public.bills;
begin
  v_result := public._kernel_upsert_compose_draft_json(p_payload);
  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'compose upsert failed');
  end if;
  select * into v_bill from public.bills where id = (v_result->>'invoice_id')::bigint;
  if v_bill.id is null then
    raise exception 'compose upsert returned no bill';
  end if;
  return v_bill;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_shop_order_draft(p_payload jsonb)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if nullif(p_payload->>'shop_order_id', '') is null then
    raise exception 'shop_order_id required for shop_order adapter';
  end if;
  return public._kernel_upsert_compose_draft(p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_update_compose_draft(p_tenant_id bigint, p_bill_id bigint, p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_update_compose_draft_json(p_tenant_id, p_bill_id, p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public.create_sales_invoice_from_payload(p_tenant_id bigint, p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_upsert_compose_draft_json(
    coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('tenant_id', p_tenant_id)
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.update_sales_invoice_from_payload(p_tenant_id bigint, p_invoice_id bigint, p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_update_compose_draft_json(p_tenant_id, p_invoice_id, p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_dropship_courier_ap_bill(p_order_id bigint, p_keep_as_draft boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_upsert_dropship_courier_ap(p_order_id, p_keep_as_draft);
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_invoice(p_invoice_id bigint, p_items jsonb DEFAULT NULL)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public.issue_wholesale_bill(p_invoice_id, p_items);
end;
$$;

-- from schemas/bills_pays/07_shipment_money_wrappers.sql
-- Inbound shipment ↔ money kernel adapters.
-- Do NOT edit 05_money_spine.sql. These wrappers call spine RPCs where supported.

CREATE OR REPLACE FUNCTION public._shipment_money_advisory_lock(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;
  perform pg_advisory_xact_lock(hashtext('shipment_money:' || p_shipment_id::text));
end;
$$;

CREATE OR REPLACE FUNCTION public._shipment_money_lock_shipment_ids(p_shipment_ids bigint[])
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_id bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    return;
  end if;
  for v_id in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
    order by x.id asc
  loop
    perform public._shipment_money_advisory_lock(v_id);
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_issue_allowed(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Shipment % must be in transit or received before issuing AP bills', p_shipment_id;
  end if;

  if not coalesce(v_ship.costs_locked, false) then
    raise exception 'Shipment % costs are not locked; use Lock costs on the shipment first', p_shipment_id;
  end if;

  if current_setting('app.shipment_ap_issue', true) is distinct from '1'
     and coalesce(auth.role(), '') is distinct from 'service_role' then
    raise exception 'Issue shipment AP only via lock_global_shipment_costs on the shipment';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_payable(p_shipment_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if v_ship.status in ('draft', 'cancelled') then
    raise exception 'Shipment % must be in transit or received before AP payout', p_shipment_id;
  end if;

  if not coalesce(v_ship.costs_locked, false) then
    raise exception 'Shipment % costs are not locked; lock and issue AP before payout', p_shipment_id;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_ap_allocations_payable(p_allocations jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_elem jsonb;
  v_bill_id bigint;
  v_bill public.bills;
begin
  if p_allocations is null or jsonb_typeof(p_allocations) <> 'array' then
    return;
  end if;

  for v_elem in select value from jsonb_array_elements(p_allocations)
  loop
    v_bill_id := nullif(v_elem->>'bill_id', '')::bigint;
    if v_bill_id is null then
      continue;
    end if;

    select * into v_bill from public.bills where id = v_bill_id;
    if v_bill.id is null then
      raise exception 'Allocation bill % not found', v_bill_id;
    end if;

    if v_bill.invoice_type = 'ap'::public.global_invoice_type
       and v_bill.source_type = 'shipment_cost'
       and v_bill.invoice_status <> 'issued'::public.global_invoice_status then
      raise exception 'Bill % must be issued before shipment AP payout', v_bill_id;
    end if;

    if v_bill.ap_shipment_id is not null then
      perform public._assert_shipment_ap_payable(v_bill.ap_shipment_id);
    elsif v_bill.source_type = 'shipment_cost' and nullif(trim(v_bill.source_id), '') is not null then
      perform public._assert_shipment_ap_payable(nullif(trim(v_bill.source_id), '')::bigint);
    end if;
  end loop;
end;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_money_kernel_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bundle jsonb;
  v_ap_bills jsonb;
  v_enriched jsonb := '[]'::jsonb;
  v_elem jsonb;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_bundle := public.get_shipment_settings_finance_bundle(p_shipment_id);
  v_ap_bills := coalesce(v_bundle->'ap_bills', '[]'::jsonb);

  for v_elem in select value from jsonb_array_elements(v_ap_bills)
  loop
    v_bill_id := nullif(v_elem->>'id', '')::bigint;
    if v_bill_id is not null then
      v_enriched := v_enriched || jsonb_build_array(
        v_elem || jsonb_build_object('net_balances', public.get_bill_net_balances(v_bill_id))
      );
    else
      v_enriched := v_enriched || jsonb_build_array(v_elem);
    end if;
  end loop;

  return v_bundle
    || jsonb_build_object('ap_bills', v_enriched)
    || jsonb_build_object(
      'kernel',
      jsonb_build_object(
        'source_type', 'shipment_cost',
        'source_id', p_shipment_id::text,
        'pay_out_rpc', 'post_shipment_ap_money_out',
        'issue_rpc', 'issue_bill'
      )
    );
end;
$$;

CREATE OR REPLACE FUNCTION public.post_shipment_ap_money_out(
  p_shipment_ids bigint[],
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_source text DEFAULT 'ap_payout',
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_type text DEFAULT 'shipment_cost',
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_sid text;
  v_primary bigint;
  v_sid_loop bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  for v_sid_loop in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
  loop
    perform public._assert_shipment_ap_payable(v_sid_loop);
  end loop;

  perform public._assert_shipment_ap_allocations_payable(p_allocations);

  select min(x.id) into v_primary from unnest(p_shipment_ids) as x(id) where x.id is not null;
  v_sid := coalesce(nullif(trim(p_source_id), ''), v_primary::text);

  v_pay := public.post_money_out(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_amount,
    p_source,
    p_note,
    p_reference,
    p_cashbook_point_id,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    coalesce(nullif(trim(p_source_type), ''), 'shipment_cost'),
    v_sid,
    p_idempotency_key
  );

  return v_pay;
end;
$$;

CREATE OR REPLACE FUNCTION public.post_shipment_ap_money_out_snapshot(
  p_shipment_ids bigint[],
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_cashbook_point_id bigint,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_currency_code text DEFAULT NULL,
  p_transaction_rate numeric DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_sid_loop bigint;
begin
  if p_shipment_ids is null or coalesce(array_length(p_shipment_ids, 1), 0) = 0 then
    raise exception 'shipment_ids is required';
  end if;

  perform public._shipment_money_lock_shipment_ids(p_shipment_ids);

  for v_sid_loop in
    select distinct x.id
    from unnest(p_shipment_ids) as x(id)
    where x.id is not null
  loop
    perform public._assert_shipment_ap_payable(v_sid_loop);
  end loop;

  perform public._assert_shipment_ap_allocations_payable(p_allocations);

  return public.post_ap_payout_with_allocations_snapshot(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cashbook_point_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    p_source_currency_code,
    p_transaction_rate,
    p_cashbook_point_pot_id,
    p_idempotency_key
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bills(p_shipment_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
  v_count integer := 0;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select gs.tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  perform public._assert_shipment_ap_issue_allowed(p_shipment_id);
  perform public._shipment_money_advisory_lock(p_shipment_id);

  for v_bill_id in
    select b.id
    from public.bills b
    where b.tenant_id = v_parent
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status = 'draft'::public.global_invoice_status
      and coalesce(b.total_amount, 0) > 0
      and (
        (b.source_type = 'shipment_cost' and b.source_id = p_shipment_id::text)
        or b.ap_shipment_id = p_shipment_id
      )
    order by b.id asc
  loop
    perform public.issue_bill(v_bill_id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_shipment_ap_bill_for_kind(
  p_shipment_id bigint,
  p_ap_kind text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  raise exception 'issue_shipment_ap_bill_for_kind is retired. Use lock_global_shipment_costs on shipment % to sync and issue all AP bills.',
    p_shipment_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_tenant_name text;
  v_bucket public.global_shipment_cost_bucket;
  v_bucket_text text;
  v_paper jsonb;
  v_amt numeric(12, 2);
  v_profile bigint;
  v_bill_id bigint;
  v_bills jsonb := '{}'::jsonb;
  v_keep_as_draft boolean := false;
  v_void_id bigint;
  v_groups jsonb;
  v_grp jsonb;
  v_ccy text;
  v_plug_key text;
  v_group_count int;
  v_slice jsonb;
  v_active_keys text[] := '{}';
  v_elem jsonb;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  perform public._shipment_money_advisory_lock(p_shipment_id);

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := v_ship.tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.tenant_id = v_parent
      and pr.profile_type = 'cargo'::public.profile_party_type
      and pr.subject_id = v_ship.cargo_company_id;
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_parent;

  v_local_profile := public.upsert_profile_for_party(
    v_parent,
    'company'::public.profile_party_type,
    v_parent,
    coalesce(v_tenant_name, 'Local opex'),
    null, null, '+880', null, false, null, true, null
  );

  v_keep_as_draft := not coalesce(v_ship.costs_locked, false);

  if v_ship.status = 'cancelled' then
    for v_void_id in
      select b.id
      from public.bills b
      where b.tenant_id = v_parent
        and b.ap_shipment_id = p_shipment_id
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and b.invoice_status in (
          'issued'::public.global_invoice_status,
          'draft'::public.global_invoice_status
        )
        and coalesce(b.paid_amount, 0) = 0
      order by b.id asc
    loop
      perform public.void_bill(v_void_id);
    end loop;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_groups := coalesce(v_paper->'currency_groups', '[]'::jsonb);
    v_group_count := jsonb_array_length(v_groups);

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    if v_group_count = 0 then
      for v_void_id in
        select b.id
        from public.bills b
        where b.tenant_id = v_parent
          and b.source_type = 'shipment_cost'
          and b.source_id = p_shipment_id::text
          and b.invoice_type = 'ap'::public.global_invoice_type
          and b.document_kind = 'standard'::public.bill_document_kind
          and b.invoice_status in (
            'issued'::public.global_invoice_status,
            'draft'::public.global_invoice_status
          )
          and coalesce(b.paid_amount, 0) = 0
          and (
            b.source_key = v_bucket::text
            or b.source_key like v_bucket::text || ':%'
          )
        order by b.id asc
      loop
        perform public.void_bill(v_void_id);
      end loop;
      continue;
    end if;

    for v_elem in select value from jsonb_array_elements(v_groups)
    loop
      v_grp := v_elem;
      v_ccy := upper(trim(coalesce(v_grp->>'currency_code', 'BDT')));
      v_plug_key := case
        when v_group_count > 1 then v_bucket::text || ':' || v_ccy
        else v_bucket::text
      end;
      v_amt := round(coalesce((v_grp->>'foreign_total')::numeric, 0), 2);
      v_slice := v_paper
        || jsonb_build_object(
          'foreign_total', v_grp->>'foreign_total',
          'currency_code', v_ccy,
          'currency_symbol', v_grp->>'currency_symbol',
          'currency_groups', jsonb_build_array(v_grp),
          'mixed_currencies', false,
          'lines', coalesce(v_grp->'lines', '[]'::jsonb)
        );

      if coalesce(v_amt, 0) <= 0 or v_profile is null then
        v_bill_id := public._upsert_shipment_ap_bill(
          v_parent,
          v_issued_by,
          p_shipment_id,
          v_ship.name,
          v_bucket::text,
          v_profile,
          v_amt,
          v_slice,
          v_keep_as_draft,
          v_plug_key
        );
      else
        select u.id
        into v_bill_id
        from public.upsert_draft_bill(
          jsonb_build_object(
            'tenant_id', v_issued_by,
            'adapter', 'shipment_cost',
            'tenant_id', v_parent,
            'issued_by_tenant_id', v_issued_by,
            'shipment_id', p_shipment_id,
            'shipment_name', v_ship.name,
            'ap_kind', v_bucket::text,
            'profile_id', v_profile,
            'amount', v_amt,
            'ap_paper', v_slice,
            'keep_as_draft', v_keep_as_draft,
            'source_key', v_plug_key
          )
        ) u;
      end if;

      if v_bill_id is not null then
        v_active_keys := array_append(v_active_keys, v_plug_key);
        v_bills := v_bills || jsonb_build_object(v_plug_key, v_bill_id);
      end if;
    end loop;
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.tenant_id = v_parent
      and b.source_type = 'shipment_cost'
      and b.source_id = p_shipment_id::text
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status in (
        'draft'::public.global_invoice_status,
        'issued'::public.global_invoice_status
      )
      and coalesce(b.paid_amount, 0) = 0
      and b.source_key is not null
      and not (b.source_key = any(v_active_keys))
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.tenant_id = v_parent
      and b.ap_shipment_id = p_shipment_id
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.ap_kind in ('vendor', 'cargo', 'local')
      and b.invoice_status = 'issued'::public.global_invoice_status
      and coalesce(b.paid_amount, 0) = 0
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent bigint;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select gs.tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_books_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);
  perform public.sync_shipment_ap_bills(p_shipment_id);

  v_sid := p_shipment_id::text;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      order by ce.cost_bucket, ce.cost_component, ce.id
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

  for v_elem in
    select value
    from jsonb_array_elements(
      public.list_bills_for_source(v_parent, 'shipment_cost', v_sid, null, false, true)
    )
  loop
    v_slim := v_slim || jsonb_build_array(
      jsonb_build_object(
        'id', v_elem->'id',
        'invoice_no', v_elem->'invoice_no',
        'ap_kind', v_elem->'ap_kind',
        'source_type', v_elem->'source_type',
        'source_id', v_elem->'source_id',
        'source_key', v_elem->'source_key',
        'invoice_status', v_elem->'invoice_status',
        'payment_status', v_elem->'payment_status',
        'total_amount', v_elem->'total_amount',
        'due_amount', coalesce(
          v_elem->'net_balances'->'open_books',
          v_elem->'due_amount'
        )
      )
    );
  end loop;
  v_ap_bills := v_slim;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx
  );
end;
$$;

REVOKE ALL ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_shipment_settings_finance_bundle(bigint) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.settle_shipment_payee(
  p_shipment_id bigint,
  p_entity_type text,
  p_entity_id bigint,
  p_action text,
  p_amount numeric,
  p_exchange_rate numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  raise exception
    'settle_shipment_payee is retired. Pay shipment AP via Finance → Payments: allocate to bucket bills using post_shipment_ap_money_out (kernel post_money_out). Shipment %.',
    p_shipment_id;
end;
$$;

GRANT EXECUTE ON FUNCTION public._shipment_money_advisory_lock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._shipment_money_lock_shipment_ids(bigint[]) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_shipment_money_kernel_bundle(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_shipment_ap_money_out(
  bigint[], bigint, bigint, date, numeric, text, text, text, bigint, jsonb, jsonb, text, numeric, numeric, text, text, text
) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.post_shipment_ap_money_out_snapshot(
  bigint[], bigint, bigint, date, bigint, text, text, jsonb, jsonb, text, numeric, numeric, text, numeric, bigint, text
) TO authenticated, service_role;

-- from schemas/bills_pays/07_shipment_cost_lock.sql
-- Procurement: lock shipment costs → sync AP → issue AP (calls bills_pays adapters).

CREATE OR REPLACE FUNCTION public.lock_global_shipment_costs(p_shipment_id bigint)
RETURNS public.global_shipments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_books_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.status not in ('in_transit', 'received') then
    raise exception 'Set shipment to in transit or received before locking costs';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment stock is not posted; receive before locking costs';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are already locked';
  end if;

  perform set_config('app.allow_costs_lock', '1', true);

  update public.global_shipments
  set costs_locked = true,
      costs_locked_at = now(),
      costs_locked_by = auth.uid(),
      updated_at = now()
  where id = p_shipment_id
  returning * into v_ship;

  perform public.sync_shipment_ap_bills(p_shipment_id);

  perform set_config('app.shipment_ap_issue', '1', true);
  perform public.issue_shipment_ap_bills(p_shipment_id);
  perform set_config('app.shipment_ap_issue', '0', true);

  return v_ship;
end;
$$;

-- from schemas/bills_pays/09_wholesale_stock_issue.sql
-- BP17: sales bill stock commit before kernel issue (warehouse orchestration).

CREATE OR REPLACE FUNCTION public._bill_line_global_stock_id(p_line public.bill_lines)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(p_line.line_meta->'stock_ref'->>'global_stock_id', '')::bigint;
$$;

CREATE OR REPLACE FUNCTION public.commit_sales_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_invoice public.bills;
  v_db_item public.bill_lines%rowtype;
  v_stock_id bigint;
  v_qty integer;
  v_stock record;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_has_stock boolean := false;
  v_delivery_paper_id bigint;
  v_skip_deduct boolean;
begin
  select * into v_invoice from public.bills where id = p_bill_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can commit stock';
  end if;

  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);

  v_delivery_paper_id := nullif(trim(coalesce(v_invoice.channel_meta->>'delivery_paper_id', '')), '')::bigint;

  select sm.id
  into v_mov_id
  from public.stock_movements sm
  where sm.reference_type = 'sales_invoice'
    and sm.reference_id = p_bill_id::text
    and sm.is_posted = true
  order by sm.id desc
  limit 1;

  if v_mov_id is not null then
    return v_mov_id;
  end if;

  select exists (
    select 1
    from public.bill_lines bl
    where bl.invoice_id = p_bill_id
      and public._bill_line_global_stock_id(bl) is not null
  ) into v_has_stock;

  if not v_has_stock then
    return null;
  end if;

  v_mov_no := public.next_stock_movement_number(v_parent_id, 'stock_movement');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent_id,
    v_mov_no,
    'adjustment'::public.stock_movement_type,
    'sales_invoice',
    p_bill_id::text,
    'Issued ' || upper(v_invoice.invoice_type::text) || ' Invoice #' || coalesce(v_invoice.invoice_no, p_bill_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  for v_db_item in select * from public.bill_lines where invoice_id = p_bill_id loop
    v_stock_id := public._bill_line_global_stock_id(v_db_item);
    if v_stock_id is null then
      continue;
    end if;

    v_qty := ceil(v_db_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_stock_id for update;
    if v_stock.id is null then
      raise exception 'Stock % not found for line %', v_stock_id, v_db_item.name_snapshot;
    end if;

    if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
       and v_stock.availability <> 'held'::public.stock_availability then
      raise exception 'dropship invoice stock % must be held before issue', v_stock_id;
    end if;

    v_skip_deduct := (
      v_delivery_paper_id is not null
      and public.stock_dispatch_deduct_covers(v_delivery_paper_id, v_stock_id, v_qty)
    );

    if v_skip_deduct then
      insert into public.stock_movement_lines (
        movement_id,
        stock_id,
        quantity,
        from_location_id,
        to_location_id,
        from_availability,
        to_availability
      ) values (
        v_mov_id,
        v_stock_id,
        v_qty,
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        v_stock.availability
      );
      continue;
    end if;

    if v_stock.quantity < v_qty then
      raise exception 'Insufficient stock for % (requested %, available %)', v_db_item.name_snapshot, v_qty, v_stock.quantity;
    end if;

    update public.global_stocks
    set quantity = quantity - v_qty
    where id = v_stock_id;

    insert into public.stock_movement_lines (
      movement_id,
      stock_id,
      quantity,
      from_location_id,
      to_location_id,
      from_availability,
      to_availability
    ) values (
      v_mov_id,
      v_stock_id,
      v_qty,
      v_stock.location_id,
      v_stock.location_id,
      v_stock.availability,
      v_stock.availability
    );
  end loop;

  return v_mov_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.commit_wholesale_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public.commit_sales_bill_stock(p_bill_id);
end;
$$;

GRANT EXECUTE ON FUNCTION public.commit_sales_bill_stock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.commit_wholesale_bill_stock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._bill_line_global_stock_id(public.bill_lines) TO authenticated, service_role;

-- from schemas/bills_pays/17_payment_profile_read.sql
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

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

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
    WHERE l.tenant_id = v_books_id
      AND l.entity_type = p_entity_type
      AND l.entity_id = v_ledger_entity_id
    ORDER BY l.created_at DESC, l.id DESC
    LIMIT v_ledger_lim
  ) ledger_rows;

  IF p_entity_type <> 'tenant' THEN
    SELECT coalesce(sum(b.due_amount), 0::numeric)
    INTO v_due_total
    FROM public.bills b
    WHERE b.tenant_id = v_books_id
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
