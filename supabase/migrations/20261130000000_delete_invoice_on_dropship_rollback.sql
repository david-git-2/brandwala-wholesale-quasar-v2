-- Migration: Delete invoice on dropship rollback to processing
begin;

-- Redefine advance_dropship_order_status to delete invoice (after unposting) on rollback to processing
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
  v_global_invoice_id bigint;
  v_invoice record;
  v_order record;
begin
  select status, shop_type_snapshot, global_invoice_id into v_current_status, v_shop_type, v_global_invoice_id
  from public.shop_orders where id = p_order_id;

  if not found then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  -- Operational statuses list
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

  -- Perform update
  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  -- Handle Invoice Auto-Creation / Post / Rollback Draft
  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    if v_order.global_invoice_id is null then
      -- Auto-create dual invoice
      perform public.create_dual_invoice_from_dropship_order(p_order_id);
    else
      -- Re-post if it was previously set to draft (on hold)
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
        perform public.post_global_invoice(v_order.global_invoice_id);

        -- Re-insert profit credit ledger entry if needed
        if v_order.customer_group_id is not null and v_invoice.middle_man_payout_amount > 0 then
          declare
            v_member_id uuid;
            v_prev_bal numeric := 0;
          begin
            select id into v_member_id
            from public.customer_group_members
            where customer_group_id = v_order.customer_group_id
            limit 1;

            if v_member_id is not null then
              if not exists (
                select 1 from public.middle_man_payout_ledger 
                where global_invoice_id = v_order.global_invoice_id and entry_type = 'profit_credit'
              ) then
                select coalesce(balance_after, 0.00) into v_prev_bal
                from public.middle_man_payout_ledger
                where tenant_id = v_order.tenant_id and customer_group_member_id = v_member_id
                order by created_at desc limit 1;

                insert into public.middle_man_payout_ledger (
                  tenant_id,
                  customer_group_member_id,
                  shop_order_id,
                  global_invoice_id,
                  entry_type,
                  amount,
                  balance_after,
                  reference_notes
                )
                values (
                  v_order.tenant_id,
                  v_member_id,
                  v_order.id,
                  v_order.global_invoice_id,
                  'profit_credit',
                  v_invoice.middle_man_payout_amount,
                  v_prev_bal + v_invoice.middle_man_payout_amount,
                  'Profit credit from dual invoice #' || v_invoice.invoice_no
                );
              end if;
            end if;
          end;
        end if;
      end if;
    end if;
  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      -- Unpost invoice to ensure stock is restored safely
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      -- Remove profit credit from payout ledger
      delete from public.middle_man_payout_ledger 
      where global_invoice_id = v_order.global_invoice_id 
        and entry_type = 'profit_credit';

      -- Disconnect from order
      update public.shop_orders 
      set global_invoice_id = null 
      where id = p_order_id;

      -- Hard delete the invoice and its items
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.invoice_charge_lines where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

commit;
