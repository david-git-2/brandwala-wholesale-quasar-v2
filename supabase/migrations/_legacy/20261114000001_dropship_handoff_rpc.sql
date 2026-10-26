-- =========================================================
-- Migration: Add process_dropship_shop_order RPC & harden advance_dropship_order_status RPC
-- =========================================================

begin;

-- 1. Create process_dropship_shop_order RPC
create or replace function public.process_dropship_shop_order(
  p_order_id bigint
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_order public.shop_orders%rowtype;
begin
  -- Fetch order
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Only dropship orders can be handed off to the dropship desk');
  end if;

  if v_order.status <> 'confirmed' then
    return jsonb_build_object('success', false, 'error', 'Only confirmed orders can be handed off to the dropship desk');
  end if;

  -- Update status to processing (merchant details will be added later)
  update public.shop_orders
  set
    status = 'processing',
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'processing'
  );
end;
$$;

-- 2. Harden advance_dropship_order_status RPC
create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
as $$
declare
  v_current_status public.shop_order_status;
  v_shop_type public.shop_type_enum;
  v_is_valid boolean := false;
begin
  select status, shop_type_snapshot into v_current_status, v_shop_type 
  from public.shop_orders where id = p_order_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  -- Validate state transitions (Allows forward and backward movement between operational statuses)
  case v_current_status
    when 'processing' then
      if p_target_status in ('ready_for_pickup', 'cancelled') then v_is_valid := true; end if;
    when 'ready_for_pickup' then
      if p_target_status in ('processing', 'shipped', 'cancelled') then v_is_valid := true; end if;
    when 'shipped' then
      if p_target_status in ('ready_for_pickup', 'processing', 'delivered', 'returned') then v_is_valid := true; end if;
    when 'delivered' then
      if p_target_status in ('shipped', 'ready_for_pickup', 'processing', 'payment_received', 'returned') then v_is_valid := true; end if;
    when 'returned' then
      if p_target_status in ('shipped', 'ready_for_pickup', 'processing') then v_is_valid := true; end if;
    else
      v_is_valid := false;
  end case;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false, 
      'error', format('Invalid status transition for dropship order from %s to %s', v_current_status, p_target_status)
    );
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

commit;
