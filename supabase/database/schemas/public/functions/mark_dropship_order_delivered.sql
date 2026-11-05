CREATE FUNCTION public.mark_dropship_order_delivered (
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
  v_invoice public.bills;
  v_save jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.status <> 'shipped'::public.shop_order_status then
    raise exception 'mark as delivered requires shipped status (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'customer invoice is required before deliver';
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id;
  if v_invoice.id is null then
    raise exception 'linked customer invoice not found';
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'issued'::public.global_invoice_status
  ) then
    raise exception 'customer invoice must be draft or issued before deliver (current: %)', v_invoice.invoice_status;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  v_save := public.finalize_dropship_order_bills_at_delivered(p_order_id);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    delivered_at = coalesce(delivered_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.ensure_dropship_courier_cod_receivable(p_order_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id,
    'invoice_id', v_order.global_invoice_id
  );
end;
$function$;

GRANT ALL ON FUNCTION public.mark_dropship_order_delivered(bigint, bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.mark_dropship_order_delivered(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.mark_dropship_order_delivered(bigint, bigint, jsonb) TO service_role;