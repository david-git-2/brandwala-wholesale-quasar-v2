CREATE FUNCTION public._sync_dropship_courier_ap_bill_details (
  p_bill_id         bigint,
  p_order_id        bigint,
  p_allow_line_sync boolean DEFAULT true
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_bill public.bills;
  v_order public.shop_orders;
  v_courier public.courier_services;
  v_delivery numeric(12, 2);
  v_cod numeric(12, 2);
  v_charges_total numeric(12, 2) := 0;
  v_paper jsonb;
  v_note text;
  v_meta jsonb;
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    return;
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return;
  end if;

  select * into v_courier from public.courier_services where id = v_order.courier_service_id;

  v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
  v_cod := round(coalesce(v_order.cod_charge_amount, 0), 2);

  v_paper := public._build_dropship_courier_ap_paper(
    v_order,
    v_courier,
    v_delivery,
    v_cod,
    v_bill.total_amount
  );

  v_note := format(
    'Courier AP — %s — order %s%s',
    coalesce(v_courier.name, 'Courier'),
    v_order.order_no,
    case
      when nullif(trim(coalesce(v_order.courier_awb_number, '')), '') is not null
      then format(' (AWB %s)', trim(v_order.courier_awb_number))
      else ''
    end
  );

  v_meta := coalesce(v_bill.channel_meta, '{}'::jsonb) || jsonb_build_object(
    'shop_order_id', p_order_id,
    'order_no', v_order.order_no,
    'courier_service_id', v_order.courier_service_id,
    'courier_name', v_courier.name,
    'courier_awb_number', v_order.courier_awb_number,
    'tracking_url', v_order.tracking_url,
    'delivery_charge_amount', v_order.delivery_charge_amount,
    'cod_charge_amount', v_order.cod_charge_amount,
    'courier_cost_amount', v_order.courier_cost_amount,
    'recipient_name', v_order.recipient_name,
    'recipient_phone', v_order.recipient_phone,
    'shipping_address', v_order.shipping_address,
    'ap_paper', v_paper
  );

  update public.bills
  set
    note = v_note,
    recipient_name = v_order.recipient_name,
    recipient_phone = v_order.recipient_phone,
    recipient_address = v_order.shipping_address,
    shipping_charge = case when p_allow_line_sync then v_delivery else shipping_charge end,
    channel_meta = v_meta,
    updated_at = now()
  where id = p_bill_id;

  if not p_allow_line_sync then
    return;
  end if;

  delete from public.bill_lines
  where invoice_id = p_bill_id
    and line_kind = 'charge';

  if v_delivery > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.parent_tenant_id, 'charge', 'Delivery charge', 1,
      v_delivery, 0, v_delivery, v_delivery,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'delivery')
    );
    v_charges_total := v_charges_total + v_delivery;
  end if;

  if v_cod > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.parent_tenant_id, 'charge', 'COD / cash handling', 1,
      v_cod, 0, v_cod, v_cod,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'cod')
    );
    v_charges_total := v_charges_total + v_cod;
  end if;

  if v_charges_total = 0 and coalesce(v_bill.total_amount, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.parent_tenant_id, 'charge',
      format('Courier charges — order %s', v_order.order_no), 1,
      v_bill.total_amount, 0, v_bill.total_amount, v_bill.total_amount,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'courier')
    );
    v_charges_total := v_bill.total_amount;
  end if;

  update public.bills
  set charges_amount = v_charges_total,
      updated_at = now()
  where id = p_bill_id;
end;
$function$;

GRANT ALL ON FUNCTION public._sync_dropship_courier_ap_bill_details(bigint, bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public._sync_dropship_courier_ap_bill_details(bigint, bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public._sync_dropship_courier_ap_bill_details(bigint, bigint, boolean) TO service_role;