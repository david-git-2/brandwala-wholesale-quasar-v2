CREATE FUNCTION public.reconcile_single_order_remittance (
  p_order_id       bigint,
  p_courier_charge numeric DEFAULT 0.00
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_payment_id bigint;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'Order #% cannot be remitted because current status is "%" (must be "delivered")', v_order.order_no, v_order.status;
  end if;

  -- Permission check
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
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_order.tenant_id;
  end if;

  -- Ensure global invoice exists or create it
  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id for update;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Failed to resolve accounting invoice for order #%', v_order.order_no;
  end if;

  select * into v_invoice
  from public.bills
  where id = v_order.global_invoice_id for update;

  v_cod := coalesce(v_order.cod_collect_amount, v_invoice.total_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);

  -- Record global payment with valid 'bank' method
  insert into public.pays (
    tenant_id,
    profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_order.tenant_id,
    v_invoice.profile_id,
    coalesce(v_invoice.collection_source, 'recipient'),
    v_net_remitted,
    0.00,
    current_date,
    'bank',
    coalesce(v_order.courier_awb_number, v_order.order_no),
    'Single-order inline remittance for order #' || v_order.order_no
  )
  returning id into v_payment_id;

  -- Allocate invoice payment
  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
  values (v_order.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

  -- Update global invoice paid amount & status
  update public.bills
  set
    paid_amount = coalesce(paid_amount, 0.00) + v_net_remitted,
    updated_at = now()
  where id = v_order.global_invoice_id;

  perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

  -- Update shop order status to payment_received
  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = coalesce(courier_remittance_ref, 'SINGLE-REMIT-' || v_order.order_no),
    updated_at = now()
  where id = v_order.id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'payment_received',
    'net_remitted', v_net_remitted
  );
end;
$function$;

GRANT ALL ON FUNCTION public.reconcile_single_order_remittance(bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public.reconcile_single_order_remittance(bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.reconcile_single_order_remittance(bigint, numeric) TO service_role;