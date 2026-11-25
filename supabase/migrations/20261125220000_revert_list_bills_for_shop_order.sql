-- Bills tab: use generic list_bills_for_source (shop_order); drop list_bills_for_shop_order.

DROP FUNCTION IF EXISTS public.list_bills_for_shop_order(bigint, bigint, boolean);

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
      OR (
        p_source_type = 'shop_order'
        AND v_sid IS NOT NULL
        AND b.shop_order_id = v_sid
      )
      OR (
        p_source_type = 'shop_order'
        AND b.source_type = 'shop_order'
        AND b.source_id = p_source_id
      )
      OR (
        p_source_type = 'shop_order'
        AND b.source_type = 'delivery_close'
        AND (
          (
            coalesce(b.channel_meta->>'document_type', '') = 'shop_order'
            AND coalesce(b.channel_meta->>'document_id', '') = p_source_id
          )
          OR EXISTS (
            SELECT 1
            FROM public.delivery_paper dp
            WHERE dp.id::text = b.source_id
              AND dp.source_type = 'shop_order'::public.delivery_paper_source_type
              AND dp.source_id::text = p_source_id
          )
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