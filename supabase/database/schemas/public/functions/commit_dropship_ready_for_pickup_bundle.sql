CREATE FUNCTION public.commit_dropship_ready_for_pickup_bundle (
  p_tenant_id   bigint,
  p_order_id    bigint,
  p_fulfillment jsonb  DEFAULT NULL::jsonb,
  p_desk        jsonb  DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_advance jsonb;
  v_cons jsonb;
begin
  if p_tenant_id is null or p_order_id is null then
    return jsonb_build_object('success', false, 'error', 'tenant and order required');
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('order must be processing (current: %s)', v_order.status)
    );
  end if;

  if p_fulfillment is not null and p_fulfillment ? 'lines' then
    perform public.apply_dropship_fulfillment_draft(p_order_id, p_fulfillment->'lines');
  end if;

  if p_desk is not null then
    if p_desk ? 'charges' then
      perform public.update_shop_order_charges_for_staff(p_tenant_id, p_order_id, p_desk->'charges');
    end if;

    if p_desk ? 'summary' then
      update public.shop_orders
      set
        discount_amount = coalesce((p_desk->'summary'->>'discount_amount')::numeric, discount_amount),
        cod_collect_amount = coalesce((p_desk->'summary'->>'cod_collect_amount')::numeric, cod_collect_amount),
        updated_at = now()
      where id = p_order_id;
    end if;

    v_cons := p_desk->'consignment';
    if v_cons is not null and v_cons <> 'null'::jsonb then
      perform public.update_dropship_consignment(
        p_order_id,
        coalesce((v_cons->>'cod_collect_amount')::numeric, 0),
        coalesce(v_cons->>'package_weight_band', 'under_1kg'),
        v_cons->>'item_category',
        v_cons->>'parcel_description',
        v_cons->>'courier_order_ref',
        coalesce(v_cons->>'delivery_zone', 'inside_dhaka'),
        v_cons->>'sender_name',
        v_cons->>'pickup_phone',
        v_cons->>'pickup_address',
        coalesce(v_cons->>'payout_account_type', 'bank'),
        v_cons->>'payout_account_info',
        coalesce((v_cons->>'allow_open_box')::boolean, false),
        v_cons->>'delivery_instruction_notes',
        nullif(v_cons->>'courier_service_id', '')::uuid,
        v_cons->>'courier_tracking_number',
        v_cons->>'courier_awb_number',
        v_cons->>'courier_consignment_id',
        v_cons->>'tracking_url',
        coalesce((v_cons->>'courier_cost_amount')::numeric, 0),
        v_cons->>'recipient_name',
        v_cons->>'recipient_phone',
        v_cons->>'recipient_phone_secondary',
        v_cons->>'shipping_address',
        v_cons->>'shipping_district',
        v_cons->>'shipping_thana',
        nullif(v_cons->>'delivery_charge_amount', '')::numeric,
        nullif(v_cons->>'cod_charge_amount', '')::numeric
      );
    end if;
  end if;

  v_advance := public.advance_dropship_order_status(p_order_id, 'ready_for_pickup'::public.shop_order_status);
  if coalesce((v_advance->>'success')::boolean, false) is not true then
    return v_advance;
  end if;

  return v_advance || jsonb_build_object(
    'dropship_detail', public.get_dropship_order_detail_v2(p_tenant_id, p_order_id)
  );
end;
$function$;

GRANT ALL ON FUNCTION public.commit_dropship_ready_for_pickup_bundle(bigint, bigint, jsonb, jsonb) TO anon;

GRANT ALL ON FUNCTION public.commit_dropship_ready_for_pickup_bundle(bigint, bigint, jsonb, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.commit_dropship_ready_for_pickup_bundle(bigint, bigint, jsonb, jsonb) TO service_role;