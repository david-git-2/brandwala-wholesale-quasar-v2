-- Deferred advance_dropship_order_status from 20260725165421

begin;

create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_current_status public.shop_order_status;
  v_shop_type public.shop_type_enum;
  v_is_valid boolean := false;
  v_global_invoice_id bigint;
  v_invoice record;
  v_order record;
begin
  select status, shop_type_snapshot, global_invoice_id into v_current_status, v_shop_type, v_global_invoice_id
  from public.shop_orders where id = p_order_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled') then
      v_is_valid := true;
    end if;
  end if;

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

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    if v_order.global_invoice_id is null then
      perform public.create_dual_invoice_from_dropship_order(p_order_id);
    else
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
        perform public.post_global_invoice(v_order.global_invoice_id);
      end if;
    end if;
  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      -- Disconnect from order
      update public.shop_orders 
      set global_invoice_id = null 
      where id = p_order_id;

      -- Hard delete draft invoice and items
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

commit;
