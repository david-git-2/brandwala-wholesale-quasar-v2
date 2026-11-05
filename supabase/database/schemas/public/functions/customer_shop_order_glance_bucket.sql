CREATE FUNCTION public.customer_shop_order_glance_bucket (
  p_status public.shop_order_status
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  select case
    when p_status = 'draft'::public.shop_order_status then null
    when p_status in (
      'priced'::public.shop_order_status,
      'negotiating'::public.shop_order_status,
      'countered'::public.shop_order_status,
      'final_offered'::public.shop_order_status
    ) then 'needs_you'
    when p_status in (
      'fulfilled'::public.shop_order_status,
      'delivered'::public.shop_order_status,
      'payment_received'::public.shop_order_status,
      'reseller_paid'::public.shop_order_status,
      'cancelled'::public.shop_order_status,
      'returned'::public.shop_order_status
    ) then 'done'
    else 'in_progress'
  end;
$function$;

GRANT ALL ON FUNCTION public.customer_shop_order_glance_bucket(public.shop_order_status) TO anon;

GRANT ALL ON FUNCTION public.customer_shop_order_glance_bucket(public.shop_order_status) TO authenticated;

GRANT ALL ON FUNCTION public.customer_shop_order_glance_bucket(public.shop_order_status) TO service_role;