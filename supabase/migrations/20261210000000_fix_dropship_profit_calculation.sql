-- Migration: Fix dropship profit calculation using dynamic items query instead of dropped column
-- Issue: record "v_invoice" has no field "middle_man_payout_amount"

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
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
  v_billing_profile_id bigint;
  v_profit numeric(12,2) := 0.00;
  
  v_recipient_subtotal numeric(12,2) := 0;
  v_accounting_subtotal numeric(12,2) := 0;
  v_middleman_cost numeric(12,2) := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  end if;

  -- Status transition rules
  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed') and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
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

    -- Book dropship_profit credit to Billing Profile Wallet if not already recorded
    v_billing_profile_id := v_order.billing_profile_id;
    if v_billing_profile_id is null and v_order.customer_group_id is not null then
      select id into v_billing_profile_id
      from public.billing_profiles
      where tenant_id = v_order.tenant_id
        and customer_group_id = v_order.customer_group_id
      order by is_default desc, created_at asc
      limit 1;
    end if;

    -- Refresh order details to ensure we have the correct invoice ID if it was just created
    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    end if;

    -- Calculate profit manually instead of reading from v_invoice.middle_man_payout_amount (dropped column)
    select
      coalesce(sum(coalesce(customer_sell_price_amount, 0) * quantity), 0),
      coalesce(sum(coalesce(unit_sell_price_amount, unit_list_price_amount, 0) * quantity), 0)
    into v_recipient_subtotal, v_accounting_subtotal
    from public.shop_order_items
    where order_id = p_order_id;

    v_middleman_cost := v_accounting_subtotal
      + coalesce(v_order.print_charge_amount, 0)
      + coalesce(v_order.packing_charge_amount, 0)
      + case when coalesce(v_order.deduct_delivery_from_margin, false) then coalesce(v_order.delivery_charge_amount, 0) else 0 end
      + case when coalesce(v_order.deduct_cod_from_margin, false) then coalesce(v_order.cod_charge_amount, 0) else 0 end;

    v_profit := v_recipient_subtotal - coalesce(v_order.discount_amount, 0) - v_middleman_cost;

    if v_billing_profile_id is not null and v_profit > 0 then
      if not exists (
        select 1 from public.billing_profile_wallet_ledger
        where shop_order_id = p_order_id and transaction_type = 'dropship_profit'
      ) then
        perform public.record_wallet_ledger_entry(
          p_tenant_id => v_order.tenant_id,
          p_billing_profile_id => v_billing_profile_id,
          p_transaction_type => 'dropship_profit',
          p_amount => v_profit,
          p_reference_id => v_order.order_no,
          p_shop_order_id => v_order.id,
          p_global_invoice_id => v_order.global_invoice_id,
          p_reference_notes => 'Dropship profit from order #' || v_order.order_no
        );
      end if;
    end if;

  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      -- Remove wallet profit entry if order is rolled back to processing
      delete from public.billing_profile_wallet_ledger
      where shop_order_id = p_order_id and transaction_type = 'dropship_profit';

      -- Disconnect from order
      update public.shop_orders 
      set global_invoice_id = null 
      where id = p_order_id;

      -- Hard delete draft invoice and lines
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

grant execute on function public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) to authenticated;
