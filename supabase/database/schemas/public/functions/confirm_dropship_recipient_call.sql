CREATE FUNCTION public.confirm_dropship_recipient_call (
  p_order_id  bigint,
  p_tenant_id bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_advance jsonb;
  v_staff_tenant_id bigint;
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
      'error', format('order must be confirmed to verify recipient (current: %s)', v_order.status)
    );
  end if;

  if v_order.recipient_verified_at is not null then
    v_advance := public.advance_dropship_order_status(p_order_id, 'processing'::public.shop_order_status);
    if coalesce((v_advance->>'success')::boolean, false) is not true then
      return v_advance;
    end if;
    v_staff_tenant_id := coalesce(p_tenant_id, v_order.tenant_id);
    return v_advance || jsonb_build_object(
      'dropship_detail', public.get_dropship_order_detail_v2(v_staff_tenant_id, p_order_id)
    );
  end if;

  update public.shop_orders
  set recipient_verified_at = now(), updated_at = now()
  where id = p_order_id;

  v_advance := public.advance_dropship_order_status(p_order_id, 'processing'::public.shop_order_status);
  if coalesce((v_advance->>'success')::boolean, false) is not true then
    return v_advance;
  end if;

  v_staff_tenant_id := coalesce(p_tenant_id, v_order.tenant_id);
  return v_advance || jsonb_build_object(
    'dropship_detail', public.get_dropship_order_detail_v2(v_staff_tenant_id, p_order_id)
  );
end;
$function$;

CREATE FUNCTION public.confirm_dropship_recipient_call (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_advance jsonb;
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
      'error', format('order must be confirmed to verify recipient (current: %s)', v_order.status)
    );
  end if;

  if v_order.recipient_verified_at is not null then
    v_advance := public.advance_dropship_order_status(p_order_id, 'processing'::public.shop_order_status);
    return v_advance;
  end if;

  update public.shop_orders
  set recipient_verified_at = now(), updated_at = now()
  where id = p_order_id;

  v_advance := public.advance_dropship_order_status(p_order_id, 'processing'::public.shop_order_status);
  return v_advance;
end;
$function$;

GRANT ALL ON FUNCTION public.confirm_dropship_recipient_call(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.confirm_dropship_recipient_call(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.confirm_dropship_recipient_call(bigint, bigint) TO service_role;

GRANT ALL ON FUNCTION public.confirm_dropship_recipient_call(bigint) TO anon;

GRANT ALL ON FUNCTION public.confirm_dropship_recipient_call(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.confirm_dropship_recipient_call(bigint) TO service_role;