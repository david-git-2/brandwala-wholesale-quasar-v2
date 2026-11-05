CREATE FUNCTION public.update_dropship_consignment (
  p_order_id                   bigint,
  p_cod_collect_amount         numeric DEFAULT 0.00,
  p_package_weight_band        text    DEFAULT 'under_1kg'::text,
  p_item_category              text    DEFAULT NULL::text,
  p_parcel_description         text    DEFAULT NULL::text,
  p_courier_order_ref          text    DEFAULT NULL::text,
  p_delivery_zone              text    DEFAULT 'inside_dhaka'::text,
  p_sender_name                text    DEFAULT NULL::text,
  p_pickup_phone               text    DEFAULT NULL::text,
  p_pickup_address             text    DEFAULT NULL::text,
  p_payout_account_type        text    DEFAULT 'bank'::text,
  p_payout_account_info        text    DEFAULT NULL::text,
  p_allow_open_box             boolean DEFAULT false,
  p_delivery_instruction_notes text    DEFAULT NULL::text,
  p_courier_service_id         uuid    DEFAULT NULL::uuid,
  p_courier_tracking_number    text    DEFAULT NULL::text,
  p_courier_awb_number         text    DEFAULT NULL::text,
  p_courier_consignment_id     text    DEFAULT NULL::text,
  p_tracking_url               text    DEFAULT NULL::text,
  p_courier_cost_amount        numeric DEFAULT 0.00,
  p_recipient_name             text    DEFAULT NULL::text,
  p_recipient_phone            text    DEFAULT NULL::text,
  p_recipient_phone_secondary  text    DEFAULT NULL::text,
  p_shipping_address           text    DEFAULT NULL::text,
  p_shipping_district          text    DEFAULT NULL::text,
  p_shipping_thana             text    DEFAULT NULL::text,
  p_delivery_charge_amount     numeric DEFAULT NULL::numeric,
  p_cod_charge_amount          numeric DEFAULT NULL::numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_delivery_charge numeric;
  v_cod_charge numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  v_delivery_charge := coalesce(p_delivery_charge_amount, p_courier_cost_amount, 0.00);
  v_cod_charge := coalesce(p_cod_charge_amount, 0.00);

  update public.shop_orders
  set
    cod_collect_amount = p_cod_collect_amount,
    package_weight_band = p_package_weight_band,
    item_category = p_item_category,
    parcel_description = p_parcel_description,
    courier_order_ref = coalesce(p_courier_order_ref, order_no),
    delivery_zone = p_delivery_zone,
    sender_name = p_sender_name,
    pickup_phone = p_pickup_phone,
    pickup_address = p_pickup_address,
    payout_account_type = p_payout_account_type,
    payout_account_info = p_payout_account_info,
    allow_open_box = p_allow_open_box,
    delivery_instruction_notes = p_delivery_instruction_notes,
    courier_service_id = p_courier_service_id,
    courier_tracking_number = p_courier_tracking_number,
    courier_awb_number = p_courier_awb_number,
    courier_consignment_id = p_courier_consignment_id,
    tracking_url = p_tracking_url,
    courier_cost_amount = p_courier_cost_amount,
    delivery_charge_amount = v_delivery_charge,
    cod_charge_amount = v_cod_charge,
    updated_at = now()
  where id = p_order_id;

  if nullif(trim(coalesce(p_recipient_phone, '')), '') is not null then
    v_profile := public.upsert_recipient_profile_by_phone(
      v_order.tenant_id,
      coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), v_order.recipient_name, 'Recipient'),
      p_recipient_phone,
      p_recipient_phone_secondary,
      coalesce(nullif(trim(coalesce(p_shipping_address, '')), ''), v_order.shipping_address, 'Address pending'),
      p_shipping_district,
      p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;

    update public.shop_orders
    set
      recipient_name = coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), recipient_name),
      recipient_phone = v_profile->>'phone',
      recipient_phone_secondary = coalesce(nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''), recipient_phone_secondary),
      shipping_address = coalesce(nullif(trim(coalesce(p_shipping_address, '')), ''), shipping_address),
      shipping_district = coalesce(nullif(trim(coalesce(p_shipping_district, '')), ''), shipping_district),
      shipping_thana = coalesce(nullif(trim(coalesce(p_shipping_thana, '')), ''), shipping_thana),
      recipient_profile_id = v_recipient_profile_id,
      updated_at = now()
    where id = p_order_id;
  end if;

  return jsonb_build_object('success', true);
end;
$function$;

GRANT ALL ON FUNCTION
  public.update_dropship_consignment(bigint, numeric, text, text, text, text, text, text, text, text, text, text, boolean, text, uuid, text, text, text, text, numeric, text, text,
  text, text, text, text, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION
  public.update_dropship_consignment(bigint, numeric, text, text, text, text, text, text, text, text, text, text, boolean, text, uuid, text, text, text, text, numeric, text, text,
  text, text, text, text, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION
  public.update_dropship_consignment(bigint, numeric, text, text, text, text, text, text, text, text, text, text, boolean, text, uuid, text, text, text, text, numeric, text, text,
  text, text, text, text, numeric, numeric) TO service_role;