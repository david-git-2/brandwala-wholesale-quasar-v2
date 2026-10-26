-- Confirmed / placed catalog orders are in progress, not unpaid.

CREATE OR REPLACE FUNCTION public.customer_shop_order_glance_segment(p_status public.shop_order_status)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_status IN (
      'priced'::public.shop_order_status,
      'negotiating'::public.shop_order_status,
      'countered'::public.shop_order_status,
      'final_offered'::public.shop_order_status
    ) THEN 'needs_you'
    WHEN p_status IN (
      'submitted'::public.shop_order_status,
      'costing_pending'::public.shop_order_status,
      'confirmed'::public.shop_order_status,
      'placed'::public.shop_order_status,
      'procuring'::public.shop_order_status,
      'ordered'::public.shop_order_status,
      'processing'::public.shop_order_status,
      'shipped'::public.shop_order_status,
      'ready_for_shipment'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    ) THEN 'in_progress'
    WHEN p_status = 'delivered'::public.shop_order_status THEN 'delivered'
    WHEN p_status IN (
      'payment_received'::public.shop_order_status,
      'reseller_paid'::public.shop_order_status
    ) THEN 'paid'
    ELSE NULL
  END;
$$;
