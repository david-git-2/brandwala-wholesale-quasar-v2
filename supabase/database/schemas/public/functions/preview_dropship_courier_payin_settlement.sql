CREATE FUNCTION public.preview_dropship_courier_payin_settlement (
  p_order_id        bigint,
  p_delivery_charge numeric,
  p_cod_charge      numeric,
  p_net_amount      numeric
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_parent_tenant_id bigint;
  v_ar public.bills;
  v_ap public.bills;
  v_notes jsonb;
  v_net numeric(12, 2);
  v_charge numeric(12, 2);
  v_invoice_due_after numeric(12, 2);
  v_invoice_allocated numeric(12, 2);
  v_ap_due_after numeric(12, 2);
  v_ap_settled numeric(12, 2);
  v_merchant_remainder numeric(12, 2);
  v_ar_adj jsonb;
  v_ap_adj jsonb;
  v_ap_id bigint;
begin
  v_net := round(greatest(coalesce(p_net_amount, 0), 0), 2);
  v_charge := round(greatest(coalesce(p_delivery_charge, 0) + coalesce(p_cod_charge, 0), 0), 2);

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  v_notes := public.preview_dropship_issued_bill_notes_at_deliver(
    p_order_id,
    p_delivery_charge,
    p_cod_charge
  );

  if coalesce(v_notes->>'success', 'false') <> 'true' then
    return v_notes;
  end if;

  select * into v_ar from public.bills where id = v_order.global_invoice_id;
  if v_ar.id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice not found');
  end if;

  v_ar_adj := v_notes->'customer_invoice';
  if v_ar_adj is not null and v_ar_adj <> 'null'::jsonb then
    v_invoice_due_after := greatest(coalesce((v_ar_adj->>'wanted_net')::numeric, 0), 0)
      - greatest(coalesce(v_ar.paid_amount, 0), 0);
  else
    v_invoice_due_after := greatest(coalesce(v_ar.due_amount, 0), 0);
  end if;

  v_invoice_due_after := greatest(v_invoice_due_after, 0);
  v_invoice_allocated := least(v_net, v_invoice_due_after);

  v_ap_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_ap_id is not null then
    select * into v_ap from public.bills where id = v_ap_id;
    v_ap_adj := v_notes->'courier_ap';
    if v_ap_adj is not null and v_ap_adj <> 'null'::jsonb then
      v_ap_due_after := greatest(
        coalesce((v_ap_adj->>'wanted_net')::numeric, 0) - greatest(coalesce(v_ap.paid_amount, 0), 0),
        0
      );
    else
      v_ap_due_after := greatest(coalesce(v_ap.due_amount, 0), 0);
    end if;
    v_ap_settled := least(v_ap_due_after, v_charge);
  else
    v_ap_due_after := 0;
    v_ap_settled := 0;
  end if;

  v_merchant_remainder := greatest(v_net - v_invoice_allocated, 0);

  return v_notes || jsonb_build_object(
    'net_amount', v_net,
    'courier_charge', v_charge,
    'invoice_due_after_notes', v_invoice_due_after,
    'invoice_allocated', v_invoice_allocated,
    'courier_ap_bill_id', v_ap_id,
    'courier_ap_due_after_notes', v_ap_due_after,
    'courier_ap_settled', v_ap_settled,
    'merchant_remainder', v_merchant_remainder
  );
end;
$function$;

GRANT ALL ON FUNCTION public.preview_dropship_courier_payin_settlement(bigint, numeric, numeric, numeric) TO anon;

GRANT ALL ON FUNCTION public.preview_dropship_courier_payin_settlement(bigint, numeric, numeric, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.preview_dropship_courier_payin_settlement(bigint, numeric, numeric, numeric) TO service_role;