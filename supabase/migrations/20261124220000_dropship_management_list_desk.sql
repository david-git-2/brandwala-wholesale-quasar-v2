-- Dropship management list desk: richer list rows + status-only deliver (SO-DL5).

DROP FUNCTION IF EXISTS public.list_dropship_shop_orders_for_staff(
  bigint,
  integer,
  integer,
  text,
  text,
  text[]
);

CREATE OR REPLACE FUNCTION public.list_dropship_shop_orders_for_staff(
  p_tenant_id bigint,
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0,
  p_status text DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_statuses text[] DEFAULT NULL
)
RETURNS TABLE (
  id bigint,
  order_no text,
  status public.shop_order_status,
  created_at timestamptz,
  customer_group_name text,
  created_by_email text,
  recipient_name text,
  recipient_phone text,
  courier_name text,
  courier_awb_number text,
  cod_collect_amount numeric,
  total_amount numeric,
  global_invoice_id bigint,
  courier_remittance_ref text,
  collection_source public.collection_source_type,
  payout_settlement_status text,
  tenant_id bigint,
  tenant_name text,
  cod_charge_amount numeric,
  delivery_charge_amount numeric,
  collected_cod_amount numeric,
  dropshipper_bill_amount numeric,
  customer_invoice_no text,
  courier_ar_bill_id bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  RETURN QUERY
  SELECT
    o.id,
    o.order_no,
    o.status,
    o.created_at,
    cg.name AS customer_group_name,
    o.created_by_email,
    o.recipient_name,
    o.recipient_phone,
    coalesce(cs.name, o.courier_name) AS courier_name,
    o.courier_awb_number,
    o.cod_collect_amount,
    coalesce(
      (
        SELECT sum(
          coalesce(
            final_price_amount,
            staff_offer_amount,
            customer_offer_amount,
            unit_sell_price_amount,
            unit_list_price_amount
          ) * quantity
        )
        FROM public.shop_order_items
        WHERE order_id = o.id
      ),
      0
    )::numeric AS total_amount,
    o.global_invoice_id,
    o.courier_remittance_ref,
    o.collection_source,
    o.payout_settlement_status,
    o.tenant_id,
    coalesce(t.name, '')::text AS tenant_name,
    coalesce(o.cod_charge_amount, 0)::numeric AS cod_charge_amount,
    coalesce(o.delivery_charge_amount, 0)::numeric AS delivery_charge_amount,
  coalesce(dos.collected_cod_amount, o.cod_collect_amount)::numeric AS collected_cod_amount,
    coalesce(
      b.total_amount,
      rp.reseller_purchase_cost,
      0
    )::numeric AS dropshipper_bill_amount,
    b.invoice_no AS customer_invoice_no,
    public.resolve_dropship_courier_ap_bill_id(o.id, o.tenant_id) AS courier_ar_bill_id
  FROM public.shop_orders o
  JOIN public.customer_groups cg ON cg.id = o.customer_group_id
  LEFT JOIN public.courier_services cs ON cs.id::text = o.courier_service_id::text
  LEFT JOIN public.tenants t ON t.id = o.tenant_id
  LEFT JOIN public.dropship_order_settlements dos ON dos.shop_order_id = o.id
  LEFT JOIN public.bills b ON b.id = o.global_invoice_id
  LEFT JOIN LATERAL public.compute_dropship_order_reseller_purchase(o.id) rp ON true
  WHERE o.tenant_id = p_tenant_id
    AND o.shop_type_snapshot = 'dropship'
    AND (
      CASE
        WHEN p_statuses IS NOT NULL AND cardinality(p_statuses) > 0 THEN
          o.status::text = ANY (p_statuses)
        WHEN p_status IS NOT NULL THEN
          o.status::text = p_status
        ELSE
          o.status::text IN (
            'submitted',
            'confirmed',
            'placed',
            'processing',
            'ready_for_pickup',
            'shipped',
            'delivered',
            'returned',
            'payment_received',
            'reseller_paid'
          )
      END
    )
    AND (
      p_search IS NULL
      OR o.order_no ILIKE ('%' || p_search || '%')
      OR o.recipient_name ILIKE ('%' || p_search || '%')
      OR o.recipient_phone ILIKE ('%' || p_search || '%')
      OR o.courier_awb_number ILIKE ('%' || p_search || '%')
      OR o.courier_name ILIKE ('%' || p_search || '%')
      OR cs.name ILIKE ('%' || p_search || '%')
      OR cg.name ILIKE ('%' || p_search || '%')
      OR o.created_by_email ILIKE ('%' || p_search || '%')
      OR t.name ILIKE ('%' || p_search || '%')
    )
  ORDER BY o.created_at DESC
  LIMIT p_limit
  OFFSET p_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_dropship_shop_orders_for_staff(
  bigint,
  integer,
  integer,
  text,
  text,
  text[]
) TO authenticated;

CREATE OR REPLACE FUNCTION public.mark_dropship_order_delivered(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_order public.shop_orders;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT * INTO v_order
  FROM public.shop_orders
  WHERE id = p_order_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'order not found';
  END IF;

  IF v_order.tenant_id IS DISTINCT FROM p_tenant_id THEN
    RAISE EXCEPTION 'tenant mismatch';
  END IF;

  IF v_order.status <> 'shipped'::public.shop_order_status THEN
    RAISE EXCEPTION 'mark as delivered requires shipped status (current: %)', v_order.status;
  END IF;

  UPDATE public.shop_orders
  SET
    status = 'delivered'::public.shop_order_status,
    delivered_at = coalesce(delivered_at, now()),
    updated_at = now()
  WHERE id = p_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id,
    'status', 'delivered'
  );
END;
$$;