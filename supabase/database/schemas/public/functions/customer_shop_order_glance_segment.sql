CREATE FUNCTION public.customer_shop_order_glance_segment (
  p_status public.shop_order_status
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select case
    when p_status in (
      'priced'::public.shop_order_status,
      'negotiating'::public.shop_order_status,
      'countered'::public.shop_order_status,
      'final_offered'::public.shop_order_status
    ) then 'needs_you'
    when p_status in (
      'submitted'::public.shop_order_status,
      'costing_pending'::public.shop_order_status,
      'confirmed'::public.shop_order_status,
      'placed'::public.shop_order_status,
      'procuring'::public.shop_order_status,
      'ordered'::public.shop_order_status,
      'processing'::public.shop_order_status,
      'shipped'::public.shop_order_status,
      'packed'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    ) then 'in_progress'
    when p_status = 'delivered'::public.shop_order_status then 'delivered'
    when p_status in (
      'payment_received'::public.shop_order_status,
      'reseller_paid'::public.shop_order_status
    ) then 'paid'
    else null
  end;
$function$;

GRANT ALL ON FUNCTION public.customer_shop_order_glance_segment(public.shop_order_status) TO anon;

GRANT ALL ON FUNCTION public.customer_shop_order_glance_segment(public.shop_order_status) TO authenticated;

GRANT ALL ON FUNCTION public.customer_shop_order_glance_segment(public.shop_order_status) TO service_role;