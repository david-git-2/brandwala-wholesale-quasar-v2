-- BP10 + BP23 + BP5: kernel reads, desk/shipment wiring, returns CN
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
        where bs.pay_id = p.id
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
      or exists (
        select 1
        from public.pay_allocations pa
        join public.bills b on b.id = coalesce(pa.bill_id, pa.global_invoice_id)
        where pa.payment_id = p.id
          and pa.tenant_id = v_parent_id
          and b.source_type = p_source_type
          and b.source_id = p_source_id
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

CREATE OR REPLACE FUNCTION public.list_bills_desk_page(
  p_parent_tenant_id bigint,
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
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not (
    public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
    or public.user_can_manage_parent_tenant(v_parent_id)
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
        'document_kind', b.document_kind
      ) as row_json
    from public.bills b
    left join public.profiles pr on pr.id = b.profile_id
    left join public.v_kernel_bill_summaries ks on ks.bill_id = b.id
    where
      (
        (p_ar_side = 'we_owe' and b.parent_tenant_id = v_parent_id)
        or (
          coalesce(p_ar_side, '') is distinct from 'we_owe'
          and p_issued_by_tenant_id is not null
          and b.issued_by_tenant_id = p_issued_by_tenant_id
        )
        or (
          coalesce(p_ar_side, '') is distinct from 'we_owe'
          and p_issued_by_tenant_id is null
          and b.parent_tenant_id = v_parent_id
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
  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
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
  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);
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
      parent_tenant_id,
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
  v_parent_tenant_id bigint;
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
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
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
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
          v_parent_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_parent_tenant_id),
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
            tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.parent_tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
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
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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


