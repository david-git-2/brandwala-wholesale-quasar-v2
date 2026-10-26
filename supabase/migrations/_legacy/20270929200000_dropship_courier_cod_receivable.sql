-- Courier wallet = COD receivable at deliver; remittance debits courier then credits tenant.

begin;

create or replace function public.ensure_dropship_courier_cod_receivable(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
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
    from public.universal_wallet_ledger
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
    from public.universal_wallet_ledger
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
$$;

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
  v_cod numeric(15,4) := 0.0000;
  v_delivery_charge numeric(15,4) := 0.0000;
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

  if v_order.status not in ('delivered', 'payment_received') then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be delivered or payment_received)', v_order.order_no, v_order.status)
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

  perform public.ensure_dropship_courier_cod_receivable(p_order_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Delivered costing fields saved; courier COD receivable booked when applicable',
    'order_id', p_order_id,
    'cod_amount', v_cod,
    'delivery_charge', v_delivery_charge
  );
end;
$$;

create or replace function public.process_dropship_courier_remittance_uwl(
  p_order_id bigint,
  p_net_amount numeric,
  p_courier_charge numeric default 0.00,
  p_remittance_ref text default null::text
)
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_order record;
  v_parent_tenant_id bigint;
  v_courier_id bigint;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net numeric(12,2) := 0.00;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  perform public.ensure_dropship_courier_cod_receivable(p_order_id);

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  v_currency := 'BDT';

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  v_charge := greatest(coalesce(p_courier_charge, 0.00), 0.00);
  v_net := greatest(coalesce(p_net_amount, 0.00), 0.00);

  if v_order.courier_service_id is null then
    raise exception 'Courier service is required before recording remittance';
  end if;

  select cs.wallet_entity_id
  into v_courier_id
  from public.courier_services cs
  where cs.id = v_order.courier_service_id;

  if v_courier_id is null or v_courier_id <= 0 then
    raise exception 'Courier wallet is not configured for order #%', v_order.order_no;
  end if;

  if v_net > 0 and not exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_remittance',
        'transaction_type', 'courier_remittance',
        'label', 'COD Remittance to Tenant',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  if v_charge > 0 and not exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_fee_retained'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_fee_retained',
        'transaction_type', 'courier_fee_retained',
        'label', 'Courier COD / Delivery Fee Retained',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  if not exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_tenant_id,
      p_type => 'credit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payment_received',
        'purpose', 'tenant_remittance_received',
        'transaction_type', 'courier_remittance_received',
        'label', 'Courier Remittance Received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'remittance_ref', p_remittance_ref
      )
    );
  end if;
end;
$function$;

create or replace function public.mark_dropship_order_delivered(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
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
    raise exception 'merchant bill must be issued before deliver';
  end if;

  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
  if v_invoice.id is null then
    raise exception 'linked merchant bill not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'merchant bill must be issued before deliver (current: %)', v_invoice.invoice_status;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
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
$$;

-- Backfill delivered dropship orders that never got a courier COD credit.
do $$
declare
  r record;
begin
  for r in
    select o.id
    from public.shop_orders o
    where o.shop_type_snapshot = 'dropship'
      and o.status in ('delivered', 'payment_received')
      and coalesce(o.cod_collect_amount, 0) > 0
      and o.courier_service_id is not null
  loop
    perform public.ensure_dropship_courier_cod_receivable(r.id);
  end loop;
end $$;

grant execute on function public.ensure_dropship_courier_cod_receivable(bigint) to authenticated;
grant execute on function public.ensure_dropship_courier_cod_receivable(bigint) to service_role;

commit;
