-- Shop order Bills tab: dedicated list RPC; remove shop_order branches from list_bills_for_source.

CREATE OR REPLACE FUNCTION public.list_bills_for_shop_order(
  p_tenant_id bigint,
  p_shop_order_id bigint,
  p_include_voided boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_books_tenant_id bigint;
  v_order public.shop_orders%rowtype;
  v_order_id_text text;
  v_rows jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_shop_order_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id and shop_order_id are required';
  END IF;

  SELECT * INTO v_order FROM public.shop_orders o WHERE o.id = p_shop_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  v_books_tenant_id := public.resolve_books_tenant_id(p_tenant_id);
  v_order_id_text := p_shop_order_id::text;

  IF NOT (
    public.is_tenant_staff(v_order.tenant_id)
    OR public.user_can_manage_books_tenant(v_books_tenant_id)
    OR public.membership_has_module_action(v_books_tenant_id, 'global_invoice', 'view')
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.resolve_books_tenant_id(v_order.tenant_id) IS DISTINCT FROM v_books_tenant_id
     AND v_order.tenant_id IS DISTINCT FROM p_tenant_id
     AND public.resolve_parent_tenant_id(v_order.tenant_id) IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'order not in tenant scope';
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_type', b.invoice_type,
        'document_kind', b.document_kind,
        'ap_kind', coalesce(
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(split_part(coalesce(b.source_key, ''), ':', 1), '')
        ),
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
  INTO v_rows
  FROM public.bills b
  WHERE b.tenant_id = v_books_tenant_id
    AND (p_include_voided OR b.invoice_status <> 'voided'::public.global_invoice_status)
    AND (
      b.shop_order_id = p_shop_order_id
      OR (b.source_type = 'shop_order' AND b.source_id = v_order_id_text)
      OR (
        b.source_type = 'delivery_close'
        AND (
          (
            coalesce(b.channel_meta->>'document_type', '') = 'shop_order'
            AND coalesce(b.channel_meta->>'document_id', '') = v_order_id_text
          )
          OR EXISTS (
            SELECT 1
            FROM public.delivery_paper dp
            WHERE dp.id::text = b.source_id
              AND dp.source_type = 'shop_order'::public.delivery_paper_source_type
              AND dp.source_id::text = v_order_id_text
          )
        )
      )
    );

  RETURN v_rows;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_bills_for_shop_order(bigint, bigint, boolean) TO authenticated;

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
DECLARE
  v_parent_id bigint;
  v_sid bigint;
  v_rows jsonb;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;
  IF nullif(trim(coalesce(p_source_type, '')), '') IS NULL THEN
    RAISE EXCEPTION 'source_type is required';
  END IF;
  IF nullif(trim(coalesce(p_source_id, '')), '') IS NULL THEN
    RAISE EXCEPTION 'source_id is required';
  END IF;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);
  v_sid := nullif(trim(p_source_id), '')::bigint;

  IF NOT (
    public.user_can_manage_books_tenant(v_parent_id)
    OR public.membership_has_module_action(v_parent_id, 'global_invoice', 'view')
    OR (
      p_source_type = 'shipment_cost'
      AND v_sid IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM public.global_shipments gs
        WHERE gs.id = v_sid
          AND public.resolve_books_tenant_id(gs.tenant_id) = v_parent_id
      )
      AND EXISTS (
        SELECT 1
        FROM public.memberships m
        WHERE m.tenant_id = v_parent_id
          AND lower(trim(m.email)) = public.current_user_email()
          AND m.is_active = true
      )
    )
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_source_type = 'shop_order' THEN
    RAISE EXCEPTION 'use list_bills_for_shop_order for shop orders';
  END IF;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'invoice_type', b.invoice_type,
        'document_kind', b.document_kind,
        'ap_kind', coalesce(
          nullif(btrim(b.ap_kind), ''),
          nullif(btrim(b.channel_meta->>'ap_kind'), ''),
          nullif(split_part(coalesce(b.source_key, ''), ':', 1), '')
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
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  INTO v_rows
  FROM public.bills b
  WHERE b.tenant_id = v_parent_id
    AND (p_include_voided OR b.invoice_status <> 'voided'::public.global_invoice_status)
    AND (
      (b.source_type = p_source_type AND b.source_id = p_source_id)
      OR (
        p_source_type = 'shipment_cost'
        AND b.invoice_type = 'ap'::public.global_invoice_type
        AND b.document_kind = 'standard'::public.bill_document_kind
        AND (
          (b.source_type = 'shipment_cost' AND b.source_id = p_source_id)
          OR (v_sid IS NOT NULL AND b.ap_shipment_id = v_sid)
        )
      )
    )
    AND (p_source_key IS NULL OR b.source_key = p_source_key)
    AND (
      NOT p_ap_shipment_buckets_only
      OR (
        p_source_type = 'shipment_cost'
        AND v_sid IS NOT NULL
        AND b.invoice_type = 'ap'::public.global_invoice_type
        AND b.document_kind = 'standard'::public.bill_document_kind
        AND b.ap_shipment_id = v_sid
      )
      OR coalesce(
        nullif(btrim(b.ap_kind), ''),
        nullif(btrim(b.channel_meta->>'ap_kind'), ''),
        nullif(btrim(b.source_key), ''),
        split_part(coalesce(b.source_key, ''), ':', 1)
      ) IN (
        'material', 'freight', 'customs', 'handling', 'finance', 'other',
        'vendor', 'cargo', 'local'
      )
      OR coalesce(b.source_key, '') ~ '^(material|freight|customs|handling|finance|other|vendor|cargo|local):'
    );

  RETURN v_rows;
END;
$$;