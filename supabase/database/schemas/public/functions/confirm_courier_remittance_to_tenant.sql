CREATE FUNCTION public.confirm_courier_remittance_to_tenant (
  p_order_id       bigint,
  p_courier_charge numeric DEFAULT 0.00,
  p_remittance_ref text    DEFAULT NULL::text,
  p_bank_trx_id    text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order record;
  v_invoice record;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
  v_ref text;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  end if;

  if v_order.status <> 'delivered' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" to remit)', v_order.order_no, v_order.status)
    );
  end if;

  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id;
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.id is not null and v_invoice.invoice_status = 'draft'::public.global_invoice_status then
      perform public.post_global_invoice(v_order.global_invoice_id);
    end if;
  end if;

  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);
  v_ref := coalesce(nullif(trim(p_remittance_ref), ''), 'REMIT-' || v_order.order_no);

  return public.record_dropship_courier_remittance(
    p_order_id => p_order_id,
    p_net_amount => v_net_remitted,
    p_remittance_ref => v_ref,
    p_bank_trx_id => p_bank_trx_id,
    p_payment_date => current_date,
    p_method => 'cash',
    p_note => null,
    p_courier_charge => v_charge
  );
end;
$function$;

GRANT ALL ON FUNCTION public.confirm_courier_remittance_to_tenant(bigint, numeric, text, text) TO anon;

GRANT ALL ON FUNCTION public.confirm_courier_remittance_to_tenant(bigint, numeric, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.confirm_courier_remittance_to_tenant(bigint, numeric, text, text) TO service_role;