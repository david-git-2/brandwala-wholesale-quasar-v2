-- get_bill_net_balances: kernel fallback; shipment AP list includes money_kernel.bills

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
    return public._desk_kernel_net_balances_json(p_bill_id);
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

-- Shipment AP list: copy from schemas/bills_pays/07_shipment_money_wrappers.sql (_list_shipment_cost_ap_bills_json)
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
      'net_balances', public._desk_kernel_net_balances_json(kb.id)
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
