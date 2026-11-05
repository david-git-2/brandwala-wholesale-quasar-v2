CREATE FUNCTION public.staff_remove_shop_cart_item (
  p_cart_item_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_ctx record;
BEGIN
  SELECT * INTO v_ctx FROM public.staff_assert_dropship_cart_item_access(p_cart_item_id);

  DELETE FROM public.shop_cart_items WHERE id = p_cart_item_id;

  RETURN public.staff_shop_cart_response_json(v_ctx.cart_id);
END;
$function$;

GRANT ALL ON FUNCTION public.staff_remove_shop_cart_item(bigint) TO anon;

GRANT ALL ON FUNCTION public.staff_remove_shop_cart_item(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.staff_remove_shop_cart_item(bigint) TO service_role;