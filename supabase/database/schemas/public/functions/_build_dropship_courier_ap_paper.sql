CREATE FUNCTION public._build_dropship_courier_ap_paper (
  p_order    public.shop_orders,
  p_courier  public.courier_services,
  p_delivery numeric,
  p_cod      numeric,
  p_total    numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  IMMUTABLE
  SET search_path TO 'public'
  AS $function$
declare
  v_lines jsonb := '[]'::jsonb;
  v_total numeric(12, 2);
begin
  v_total := round(coalesce(p_total, 0), 2);

  if coalesce(p_delivery, 0) > 0 then
    v_lines := v_lines || jsonb_build_array(
      jsonb_build_object(
        'description', 'Delivery charge',
        'amount', round(p_delivery, 2),
        'currency_code', 'BDT',
        'currency_symbol', '৳'
      )
    );
  end if;

  if coalesce(p_cod, 0) > 0 then
    v_lines := v_lines || jsonb_build_array(
      jsonb_build_object(
        'description', 'COD / cash handling',
        'amount', round(p_cod, 2),
        'currency_code', 'BDT',
        'currency_symbol', '৳'
      )
    );
  end if;

  if jsonb_array_length(v_lines) = 0 and v_total > 0 then
    v_lines := jsonb_build_array(
      jsonb_build_object(
        'description', format('Courier charges — order %s', p_order.order_no),
        'amount', v_total,
        'currency_code', 'BDT',
        'currency_symbol', '৳'
      )
    );
  end if;

  return jsonb_build_object(
    'paper', 'courier',
    'lines', v_lines,
    'currency_groups', jsonb_build_array(
      jsonb_build_object(
        'currency_code', 'BDT',
        'currency_symbol', '৳',
        'foreign_total', v_total,
        'lines', v_lines
      )
    ),
    'mixed_currencies', false,
    'foreign_total', v_total,
    'currency_code', 'BDT',
    'currency_symbol', '৳',
    'bdt_amount', v_total,
    'order_no', p_order.order_no,
    'courier_name', p_courier.name,
    'courier_awb_number', p_order.courier_awb_number,
    'tracking_url', p_order.tracking_url,
    'recipient_name', p_order.recipient_name,
    'recipient_phone', p_order.recipient_phone,
    'shipping_address', p_order.shipping_address
  );
end;
$function$;

GRANT ALL ON FUNCTION public._build_dropship_courier_ap_paper(public.shop_orders, public.courier_services, numeric, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public._build_dropship_courier_ap_paper(public.shop_orders, public.courier_services, numeric, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public._build_dropship_courier_ap_paper(public.shop_orders, public.courier_services, numeric, numeric, numeric) TO service_role;