-- confirm_dropship_delivered_costing: resolve courier from courier_services.wallet_entity_id (no public.couriers table)

begin;

create or replace function public.confirm_dropship_delivered_costing(
  p_order_id bigint,
  p_cod_amount numeric default null,
  p_delivery_charge numeric default null,
  p_courier_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_courier_id bigint := 0;
  v_cod numeric(15,4) := 0.0000;
  v_delivery_charge numeric(15,4) := 0.0000;
  v_existing_ledger public.universal_wallet_ledger;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', v_order.tenant_id));
  end if;

  if v_order.status <> 'delivered' and v_order.status <> 'payment_received' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" or "payment_received" to confirm costing)', v_order.order_no, v_order.status)
    );
  end if;

  v_cod := coalesce(p_cod_amount, v_order.cod_collect_amount, 0.0000);
  v_delivery_charge := coalesce(p_delivery_charge, v_order.delivery_charge_amount, 0.0000);

  update public.shop_orders
  set
    cod_collect_amount = v_cod,
    delivery_charge_amount = v_delivery_charge,
    driver_notes = coalesce(nullif(trim(p_courier_notes), ''), driver_notes),
    updated_at = now()
  where id = p_order_id;

  if v_order.courier_service_id is not null then
    select coalesce(cs.wallet_entity_id, 0)
    into v_courier_id
    from public.courier_services cs
    where cs.id = v_order.courier_service_id;
  end if;

  v_courier_id := coalesce(v_courier_id, 0);

  select * into v_existing_ledger
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and entity_type = 'courier'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'delivered_costing'
  limit 1;

  if v_existing_ledger.id is null and v_cod > 0 then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'credit',
      p_amount => v_cod,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'delivered_costing',
        'order_no', v_order.order_no,
        'delivery_charge', v_delivery_charge,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Delivered costing confirmed and courier wallet credited',
    'order_id', p_order_id,
    'cod_amount', v_cod,
    'delivery_charge', v_delivery_charge
  );
end;
$$;

commit;
