-- payment_status on bills is text, not global_invoice_payment_status enum

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
        'total_amount', b.total_amount,
        'due_amount', b.due_amount,
        'recipient_name', b.recipient_name,
        'profile_name', pr.name,
        'retail_billing_mode', b.retail_billing_mode,
        'channel_meta', b.channel_meta,
        'ap_kind', b.ap_kind
      ) as row_json
    from public.bills b
    left join public.profiles pr on pr.id = b.profile_id
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
      and (p_payment_status is null or b.payment_status = p_payment_status)
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
        or (p_quick_filter = 'paid' and b.payment_status = 'paid')
        or (p_quick_filter = 'unpaid' and b.payment_status <> 'paid')
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
