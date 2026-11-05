CREATE FUNCTION public.mark_dropship_order_returned_from_settlement (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_payload   jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_save jsonb;
  v_finalize jsonb;
  v_return_items jsonb;
  v_return_fee numeric(15,2) := 0;
  v_line jsonb;
  v_deduct boolean := false;
  v_return_ref text;
  v_reason text;
  v_has_return_qty boolean := false;
  v_elem jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  if v_order.status <> 'shipped'::public.shop_order_status then
    raise exception 'mark as returned requires shipped status (current: %)', v_order.status;
  end if;

  v_return_items := coalesce(p_payload->'return_items', '[]'::jsonb);
  if jsonb_typeof(v_return_items) <> 'array' then
    raise exception 'return_items must be a JSON array';
  end if;

  for v_elem in select * from jsonb_array_elements(v_return_items) loop
    if coalesce((v_elem->>'returned_qty')::numeric, 0) > 0 then
      v_has_return_qty := true;
      exit;
    end if;
  end loop;

  if not v_has_return_qty then
    raise exception 'at least one return line with quantity > 0 is required';
  end if;

  v_deduct := coalesce((p_payload->>'deduct_from_middle_man')::boolean, false);
  v_return_ref := nullif(trim(coalesce(p_payload->>'return_ref', '')), '');
  if v_return_ref is null then
    v_return_ref := 'RET-' || p_order_id::text || '-' || extract(epoch from now())::bigint::text;
  end if;
  v_reason := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  for v_line in select * from jsonb_array_elements(coalesce(p_payload->'charge_lines', '[]'::jsonb)) loop
    if v_line->>'charge_type' = 'return' then
      v_return_fee := coalesce((v_line->>'amount')::numeric, 0);
      exit;
    end if;
  end loop;

  v_finalize := public.finalize_dropship_return(
    p_order_id => p_order_id,
    p_items => v_return_items,
    p_actual_return_charge => v_return_fee,
    p_deduct_from_middle_man => v_deduct,
    p_override_reason => v_reason,
    p_return_ref => v_return_ref
  );

  if coalesce(v_finalize->>'success', 'false') <> 'true' then
    return v_finalize;
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as returned',
    'order_id', p_order_id,
    'status', 'returned',
    'return_ref', v_return_ref
  );
end;
$function$;

GRANT ALL ON FUNCTION public.mark_dropship_order_returned_from_settlement(bigint, bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.mark_dropship_order_returned_from_settlement(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.mark_dropship_order_returned_from_settlement(bigint, bigint, jsonb) TO service_role;