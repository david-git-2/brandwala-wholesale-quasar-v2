-- Migration: Add wrapping_charge and cod columns to commerce_invoices and update create_commerce_invoice RPC
begin;

-- 1. Add columns to public.commerce_invoices if they don't exist
alter table public.commerce_invoices
add column if not exists wrapping_charge numeric(12, 2) not null default 0.00,
add column if not exists cod numeric(12, 2) not null default 0.00;

-- 2. Recreate create_commerce_invoice RPC function
create or replace function public.create_commerce_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_delivery_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_total_amount numeric,
  p_amount_paid numeric,
  p_delivered_by text
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_id bigint;
  v_cust_group_id bigint;
  v_item record;
begin
  -- Resolve tenant_id and customer_group_id from the order directly
  select tenant_id, customer_group_id into p_tenant_id, v_cust_group_id
  from public.commerce_orders
  where id = p_order_id;

  -- 1. Insert Invoice
  insert into public.commerce_invoices (
    order_id,
    delivery_charge,
    wrapping_charge,
    cod,
    total_amount,
    amount_paid,
    amount_due,
    is_customer_group_paid,
    delivered_by,
    tenant_id
  )
  values (
    p_order_id,
    p_delivery_charge,
    p_wrapping_charge,
    p_cod,
    p_total_amount,
    p_amount_paid,
    p_total_amount - p_amount_paid,
    case when p_amount_paid >= p_total_amount then true else false end,
    p_delivered_by,
    p_tenant_id
  )
  returning id into v_invoice_id;

  -- 2. Update order status to 'reviewing' and append to invoice_ids
  update public.commerce_orders
  set
    status = 'reviewing'::public.commerce_order_status,
    invoice_ids = array_append(coalesce(invoice_ids, '{}'::bigint[]), v_invoice_id)
  where id = p_order_id;

  -- 3. Update order items to set invoice_id
  update public.commerce_order_items
  set invoice_id = v_invoice_id
  where order_id = p_order_id;

  -- 4. Create accounting entries for each order item
  for v_item in (
    select id, product_id, cost_bdt, sell_price_bdt, recipient_price_bdt
    from public.commerce_order_items
    where order_id = p_order_id
  ) loop
    insert into public.commerce_accounting (
      order_item_id,
      cost_bdt,
      shipment_item_id,
      sell_price_bdt,
      recipient_sell_price_bdt,
      customer_group_id,
      is_customer_group_paid,
      tenant_id
    )
    values (
      v_item.id,
      v_item.cost_bdt,
      null,
      v_item.sell_price_bdt,
      v_item.recipient_price_bdt,
      coalesce(v_cust_group_id, 0), -- fallback to 0 if not resolved
      false,
      p_tenant_id
    );
  end loop;

  return v_invoice_id;
end;
$$;

-- Grant execution permissions
grant execute on function public.create_commerce_invoice(bigint, bigint, numeric, numeric, numeric, numeric, numeric, text) to authenticated;

commit;
