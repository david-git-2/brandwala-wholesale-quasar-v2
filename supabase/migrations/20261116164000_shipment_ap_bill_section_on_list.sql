-- AP bill cards: section from bill meta
CREATE OR REPLACE FUNCTION public._list_shipment_cost_ap_bills_json(
  p_books_tenant_id bigint,
  p_shipment_id bigint,
  p_include_voided boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
  SELECT COALESCE(
    jsonb_agg(row_data ORDER BY (row_data->>'id')::bigint),
    '[]'::jsonb
  )
  FROM (
    SELECT jsonb_build_object(
      'id', b.id,
      'invoice_no', b.invoice_no,
      'invoice_type', b.invoice_type,
      'document_kind', b.document_kind,
      'ap_kind', COALESCE(
        NULLIF(btrim(b.ap_kind), ''),
        NULLIF(btrim(b.channel_meta->>'ap_kind'), ''),
        NULLIF(split_part(COALESCE(b.source_key, ''), ':', 1), '')
      ),
      'ap_shipment_id', b.ap_shipment_id,
      'source_type', b.source_type,
      'source_id', b.source_id,
      'source_key', b.source_key,
      'invoice_status', b.invoice_status,
      'payment_status', b.payment_status,
      'total_amount', b.total_amount,
      'due_amount', b.due_amount,
      'parent_bill_id', b.parent_bill_id,
      'net_balances', public.get_bill_net_balances(b.id)
    ) AS row_data
    FROM public.bills b
    WHERE b.tenant_id = p_books_tenant_id
      AND (p_include_voided OR b.invoice_status <> 'voided'::public.global_invoice_status)
      AND b.invoice_type = 'ap'::public.global_invoice_type
      AND b.document_kind = 'standard'::public.bill_document_kind
      AND (
        (b.source_type = 'shipment_cost' AND b.source_id = p_shipment_id::text)
        OR b.ap_shipment_id = p_shipment_id
      )
      AND (
        b.ap_shipment_id = p_shipment_id
        OR COALESCE(
          NULLIF(btrim(b.ap_kind), ''),
          NULLIF(btrim(b.channel_meta->>'ap_kind'), ''),
          NULLIF(btrim(b.source_key), ''),
          split_part(COALESCE(b.source_key, ''), ':', 1)
        ) IN (
          'material', 'freight', 'customs', 'handling', 'finance', 'other',
          'vendor', 'cargo', 'local'
        )
        OR COALESCE(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
      )

    UNION ALL

    SELECT jsonb_build_object(
      'id', kb.id,
      'invoice_no', kb.invoice_no,
      'invoice_type', 'ap',
      'document_kind', 'standard',
      'ap_kind', COALESCE(kb.meta->>'ap_kind', split_part(COALESCE(kb.source_key, ''), ':', 1)),
      'ap_shipment_id', (kb.meta->>'shipment_id')::bigint,
      'source_type', kb.source_type,
      'source_id', kb.source_id,
      'source_key', kb.source_key,
      'invoice_status', CASE kb.status WHEN 'voided' THEN 'voided' WHEN 'draft' THEN 'draft' ELSE 'issued' END,
      'payment_status', public._desk_kernel_status_payment(kb.status, kb.due_amount),
      'total_amount', kb.total_amount,
      'due_amount', kb.due_amount,
      'parent_bill_id', kb.parent_bill_id,
      'net_balances', public._desk_kernel_net_balances_json(kb.id),
      'section_id', NULLIF(kb.meta->>'section_id', '')::bigint,
      'section_title', NULLIF(btrim(kb.meta->>'section_title'), ''),
      'cost_lines', COALESCE((
        SELECT jsonb_agg(
          jsonb_build_object(
            'cost_component', COALESCE(NULLIF(btrim(bl.meta->>'cost_component'), ''), 'misc'),
            'amount', bl.line_total,
            'description', bl.description
          )
          ORDER BY bl.line_no
        )
        FROM money_kernel.bill_lines bl
        WHERE bl.tenant_id = kb.tenant_id
          AND bl.bill_id = kb.id
      ), '[]'::jsonb)
    ) AS row_data
    FROM money_kernel.bills kb
    WHERE kb.tenant_id = p_books_tenant_id
      AND kb.kind = 'shipment_cost_ap'
      AND kb.source_type = 'shipment_cost'
      AND kb.source_id = p_shipment_id::text
      AND (p_include_voided OR kb.status <> 'voided')
      AND NOT EXISTS (SELECT 1 FROM public.bills pb WHERE pb.id = kb.id)
  ) merged;
$$;

CREATE OR REPLACE FUNCTION public.get_shipment_settings_finance_bundle(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_workspace bigint;
  v_buckets jsonb;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
  v_elem jsonb;
  v_slim jsonb := '[]'::jsonb;
begin
  select coalesce(gs.buckets, '[]'::jsonb)
    into v_buckets
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if not found then
    raise exception 'shipment not found';
  end if;

  v_workspace := public._shipment_money_workspace_tenant(p_shipment_id);

  if not (
    public.user_can_manage_books_tenant(v_workspace)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_workspace
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  v_cost_entries := '[]'::jsonb;
  v_sid := p_shipment_id::text;

  for v_elem in
    select value
    from jsonb_array_elements(
      public._list_shipment_cost_ap_bills_json(v_workspace, p_shipment_id, false)
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
        'total_amount', coalesce(
          nullif(v_elem->>'total_amount', '')::numeric,
          nullif(v_elem->'net_balances'->>'open_txn', '')::numeric,
          0
        ),
        'due_amount', coalesce(
          nullif(v_elem->'net_balances'->>'open_books', '')::numeric,
          nullif(v_elem->'net_balances'->>'open_txn', '')::numeric,
          nullif(v_elem->>'due_amount', '')::numeric,
          0
        ),
        'net_balances', v_elem->'net_balances',
        'section_id', v_elem->'section_id',
        'section_title', v_elem->'section_title',
        'cost_lines', coalesce(v_elem->'cost_lines', '[]'::jsonb)
      )
    );
  end loop;
  v_ap_bills := v_slim;

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  return jsonb_build_object(
    'buckets', v_buckets,
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx,
    'ap_issue_parties', public._resolve_shipment_cost_ap_kernel_parties(p_shipment_id)
  );
end;
$$;
