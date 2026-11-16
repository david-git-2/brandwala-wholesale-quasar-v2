-- rpc_get_bill ran as INVOKER; kernel RLS keys off JWT auth_tenant_id(), not workspace header.
-- Bills created under current_tenant_id() were invisible → not_found despite list (DEFINER) showing them.

CREATE OR REPLACE FUNCTION public.rpc_get_bill(
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_include   text[] DEFAULT '{lines}'
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bill money_kernel.bills;
  v_result     jsonb;
  v_lines      jsonb;
  v_settlements jsonb;
  v_events     jsonb;
  v_meta_exp   jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'invalid_arguments: tenant_id and bill_id are required';
  END IF;

  PERFORM money_kernel.assert_kernel_money_read(p_tenant_id);

  SELECT * INTO v_bill FROM money_kernel.bills
    WHERE id = p_bill_id AND tenant_id = p_tenant_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'not_found: bill % in tenant %', p_bill_id, p_tenant_id;
  END IF;

  v_result := jsonb_build_object(
    'bill_id',                 v_bill.id,
    'tenant_id',               v_bill.tenant_id,
    'kind',                    v_bill.kind,
    'status',                  v_bill.status,
    'invoice_no',              v_bill.invoice_no,
    'invoice_date',            v_bill.invoice_date,
    'due_date',                v_bill.due_date,
    'from_profile_id',         v_bill.from_profile_id,
    'to_profile_id',           v_bill.to_profile_id,
    'counterparty_profile_id', v_bill.counterparty_profile_id,
    'counterparty_tenant_id',  v_bill.counterparty_tenant_id,
    'currency_code',           v_bill.currency_code,
    'total_amount',            v_bill.total_amount,
    'paid_amount',             v_bill.paid_amount,
    'due_amount',              v_bill.due_amount,
    'written_off_amount',      v_bill.written_off_amount,
    'parent_bill_id',          v_bill.parent_bill_id,
    'source_entity',           v_bill.source_entity,
    'source_type',             v_bill.source_type,
    'source_id',               v_bill.source_id,
    'source_key',              v_bill.source_key,
    'note',                    v_bill.note,
    'meta',                    v_bill.meta,
    'created_by',              v_bill.created_by,
    'created_at',              v_bill.created_at,
    'updated_at',              v_bill.updated_at
  );

  IF 'lines' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'id',          bl.id,
      'line_no',     bl.line_no,
      'item_kind',   bl.item_kind,
      'product_id',  bl.product_id,
      'description', bl.description,
      'quantity',    bl.quantity,
      'unit_price',  bl.unit_price,
      'line_total',        bl.line_total,
      'shipment_item_id',  bl.shipment_item_id,
      'global_stock_id',   bl.global_stock_id,
      'shipment_id',       bl.shipment_id,
      'meta',              bl.meta
    ) ORDER BY bl.line_no), '[]'::jsonb)
    INTO v_lines
    FROM money_kernel.bill_lines bl
    WHERE bl.bill_id = p_bill_id AND bl.tenant_id = p_tenant_id;

    v_result := v_result || jsonb_build_object('lines', v_lines);
  END IF;

  IF 'settlements' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'settlement_id',          bs.id,
      'settlement_kind',        bs.settlement_kind,
      'pays_id',                bs.pays_id,
      'source_bill_id',         bs.source_bill_id,
      'allocated_amount',       bs.allocated_amount,
      'allocated_books_amount', bs.allocated_books_amount,
      'payment_date',           p.payment_date,
      'payment_kind',           p.kind,
      'payment_status',         p.status,
      'payment_amount',         p.amount,
      'payment_currency',       p.currency_code,
      'from_cash_bundle_id',            p.from_cash_bundle_id,
      'to_cash_bundle_id',              p.to_cash_bundle_id,
      'payment_meta',           p.meta,
      'settled_at',             bs.created_at
    ) ORDER BY bs.created_at DESC), '[]'::jsonb)
    INTO v_settlements
    FROM money_kernel.bill_settlements bs
    LEFT JOIN money_kernel.pays p ON p.id = bs.pays_id AND p.tenant_id = p_tenant_id
    WHERE bs.bill_id = p_bill_id AND bs.tenant_id = p_tenant_id;

    v_result := v_result || jsonb_build_object('settlements', v_settlements);
  END IF;

  IF 'events' = ANY(p_include) THEN
    SELECT COALESCE(jsonb_agg(jsonb_build_object(
      'event_id',   be.id,
      'event_type', be.event_type,
      'payload',    be.payload,
      'actor_id',   be.actor_id,
      'created_at', be.created_at
    ) ORDER BY be.created_at DESC, be.id DESC), '[]'::jsonb)
    INTO v_events
    FROM money_kernel.bill_events be
    WHERE be.bill_id = p_bill_id AND be.tenant_id = p_tenant_id;

    v_result := v_result || jsonb_build_object('events', v_events);
  END IF;

  IF 'meta_expanded' = ANY(p_include) THEN
    v_meta_exp := jsonb_build_object(
      'raw', v_bill.meta,
      'well_known', jsonb_build_object(
        'shipment_id',          (v_bill.meta->>'shipment_id')::bigint,
        'ap_kind',              v_bill.meta->>'ap_kind',
        'original_bill_id',     (v_bill.meta->>'original_bill_id')::bigint,
        'retail_billing_mode',  v_bill.meta->>'retail_billing_mode',
        'reason',               v_bill.meta->>'reason'
      )
    );
    v_result := v_result || jsonb_build_object('meta_expanded', v_meta_exp);
  END IF;

  RETURN v_result || jsonb_build_object('echoed_filters', jsonb_build_object(
    'tenant_id', p_tenant_id,
    'bill_id',   p_bill_id,
    'include',   to_jsonb(p_include)
  ));
END;
$$;