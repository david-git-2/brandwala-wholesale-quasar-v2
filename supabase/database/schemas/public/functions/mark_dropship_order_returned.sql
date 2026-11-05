CREATE FUNCTION public.mark_dropship_order_returned (
  p_order_id               bigint,
  p_actual_return_charge   numeric,
  p_deduct_from_middle_man boolean,
  p_reason                 text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_items jsonb;
begin
  select jsonb_agg(
    jsonb_build_object(
      'order_item_id', id,
      'returned_qty', greatest(coalesce(delivered_quantity, quantity) - coalesce(returned_quantity, 0), 0),
      'condition', 'perfect'
    )
  )
  into v_items
  from public.shop_order_items
  where order_id = p_order_id;

  return public.finalize_dropship_return(
    p_order_id => p_order_id,
    p_items => coalesce(v_items, '[]'::jsonb),
    p_actual_return_charge => coalesce(p_actual_return_charge, 0.00),
    p_deduct_from_middle_man => coalesce(p_deduct_from_middle_man, true),
    p_override_reason => p_reason,
    p_return_ref => 'AUTO-RET-' || p_order_id::text || '-' || extract(epoch from now())::bigint
  );
end;
$function$;

GRANT ALL ON FUNCTION public.mark_dropship_order_returned(bigint, numeric, boolean, text) TO anon;

GRANT ALL ON FUNCTION public.mark_dropship_order_returned(bigint, numeric, boolean, text) TO authenticated;

GRANT ALL ON FUNCTION public.mark_dropship_order_returned(bigint, numeric, boolean, text) TO service_role;