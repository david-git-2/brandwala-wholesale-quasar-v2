CREATE FUNCTION public.ensure_dropship_courier_cod_receivable (
  p_order_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_parent_tenant_id bigint;
  v_courier_id bigint;
  v_cod numeric(12,2) := 0.00;
  v_delivery_charge numeric(12,2) := 0.00;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return;
  end if;

  if v_order.status not in (
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if exists (
    select 1
    from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    return;
  end if;

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  if v_cod <= 0.00 then
    return;
  end if;

  if v_order.courier_service_id is null then
    raise exception 'Courier service is required before booking COD receivable on order #%', v_order.order_no;
  end if;

  select cs.wallet_entity_id
  into v_courier_id
  from public.courier_services cs
  where cs.id = v_order.courier_service_id;

  if v_courier_id is null or v_courier_id <= 0 then
    raise exception 'Courier wallet is not configured for order #%', v_order.order_no;
  end if;

  if exists (
    select 1
    from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and entity_id = v_courier_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and coalesce(metadata->>'purpose', '') in ('courier_cod_receivable', 'delivered_costing')
  ) then
    return;
  end if;

  v_delivery_charge := coalesce(v_order.delivery_charge_amount, 0.00);

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => v_order.tenant_id,
    p_entity_type => 'courier',
    p_entity_id => v_courier_id,
    p_type => 'credit',
    p_amount => v_cod,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'cod_pending',
      'purpose', 'courier_cod_receivable',
      'transaction_type', 'courier_cod_receivable',
      'label', 'Courier COD receivable',
      'order_no', v_order.order_no,
      'order_id', p_order_id,
      'gross_cod', v_cod,
      'delivery_charge', v_delivery_charge,
      'courier_service_id', v_order.courier_service_id
    )
  );

  update public.dropship_order_settlements
  set
    courier_cod_booked_at = coalesce(courier_cod_booked_at, now()),
    updated_at = now()
  where shop_order_id = p_order_id;
end;
$function$;

GRANT ALL ON FUNCTION public.ensure_dropship_courier_cod_receivable(bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_dropship_courier_cod_receivable(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_dropship_courier_cod_receivable(bigint) TO service_role;