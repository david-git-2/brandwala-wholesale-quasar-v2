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

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
  IF v_bill.id IS NULL THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF NOT (v_bill.parent_tenant_id = v_parent_id OR v_bill.issued_by_tenant_id = p_tenant_id) THEN
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
