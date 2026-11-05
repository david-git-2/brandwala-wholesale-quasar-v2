CREATE FUNCTION public.record_dropship_recipient_call_no_answer (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_new_count integer;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if v_order.status <> 'confirmed'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('order must be confirmed to log a call attempt (current: %s)', v_order.status)
    );
  end if;

  update public.shop_orders
  set
    recipient_call_attempt_count = coalesce(recipient_call_attempt_count, 0) + 1,
    updated_at = now()
  where id = p_order_id
  returning recipient_call_attempt_count into v_new_count;

  return jsonb_build_object(
    'success', true,
    'recipient_call_attempt_count', v_new_count
  );
end;
$function$;

GRANT ALL ON FUNCTION public.record_dropship_recipient_call_no_answer(bigint) TO anon;

GRANT ALL ON FUNCTION public.record_dropship_recipient_call_no_answer(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.record_dropship_recipient_call_no_answer(bigint) TO service_role;