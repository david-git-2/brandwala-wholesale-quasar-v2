-- Dropship status advance: status field only (no auto-invoice / wallet side effects).
-- Fixes 22P02 when ensure_dropship_invoice_billed_entry stored invoice_no in source_id.

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
  v_order public.shop_orders;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
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

  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed')
     and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in (
      'processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled'
    ) then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Invalid status transition for dropship order from %s to %s',
        v_current_status,
        p_target_status
      )
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

grant execute on function public.advance_dropship_order_status(
  bigint,
  public.shop_order_status,
  text,
  text
) to authenticated;

-- When invoice billing runs elsewhere, keep shop_order source_id as numeric order id.
create or replace function public.ensure_dropship_invoice_billed_entry(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_order_id bigint;
begin
  select * into v_invoice
  from public.global_invoices
  where id = p_invoice_id;

  if v_invoice.id is null then
    return;
  end if;

  select o.id into v_order_id
  from public.shop_orders o
  where o.global_invoice_id = p_invoice_id
  order by o.id
  limit 1;

  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
     and v_invoice.invoice_status in (
       'issued'::public.global_invoice_status,
       'posted'::public.global_invoice_status
     )
     and v_invoice.billing_profile_id is not null
     and v_invoice.total_amount > 0
     and v_order_id is not null
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
        and (
          metadata->>'invoice_id' = p_invoice_id::text
          or source_id = v_order_id::text
          or source_id = v_invoice.invoice_no
        )
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_invoice.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_source_type => 'shop_order',
        p_source_id => v_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', p_invoice_id,
          'order_id', v_order_id
        )
      );
    end if;
  end if;
end;
$$;

commit;
