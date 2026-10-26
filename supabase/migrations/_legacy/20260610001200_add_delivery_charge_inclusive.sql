-- Migration: Add is_delivery_charge_inclusive column to commerce_orders and update place_commerce_order RPC
begin;

-- 1. Add column to public.commerce_orders if it doesn't exist, defaulting to true
alter table public.commerce_orders
add column if not exists is_delivery_charge_inclusive boolean not null default true;

-- 2. Drop the old function signature first to avoid PostgREST schema cache issues/overloads
drop function if exists public.place_commerce_order(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_shipment_payment numeric,
  p_invoice_print_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_delivery_charge numeric,
  p_items jsonb
);

-- 3. Create the updated function with the new parameter
create or replace function public.place_commerce_order(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_shipment_payment numeric,
  p_invoice_print_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_delivery_charge numeric,
  p_is_delivery_charge_inclusive boolean,
  p_items jsonb
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id bigint;
  v_item jsonb;
begin
  -- 1. Insert Commerce Order
  insert into public.commerce_orders (
    recipient_name,
    recipient_phone,
    shipping_address,
    shipment_payment,
    invoice_print_charge,
    wrapping_charge,
    cod,
    tenant_id,
    customer_group_id,
    order_placement_date,
    delivery_charge,
    is_delivery_charge_inclusive,
    status
  )
  values (
    p_recipient_name,
    p_recipient_phone,
    p_shipping_address,
    p_shipment_payment,
    p_invoice_print_charge,
    p_wrapping_charge,
    p_cod,
    p_tenant_id,
    p_customer_group_id,
    now(),
    p_delivery_charge,
    p_is_delivery_charge_inclusive,
    'placed'::public.commerce_order_status
  )
  returning id into v_order_id;

  -- 2. Insert Order Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.commerce_order_items (
      order_id,
      product_id,
      image_url,
      cost_bdt,
      sell_price_bdt,
      recipient_price_bdt,
      quantity,
      phone_invite_id
    )
    values (
      v_order_id,
      (v_item->>'product_id')::bigint,
      v_item->>'image_url',
      (v_item->>'cost_bdt')::numeric,
      (v_item->>'sell_price_bdt')::numeric,
      (v_item->>'recipient_price_bdt')::numeric,
      (v_item->>'quantity')::integer,
      v_item->>'phone_invite_id'
    );
  end loop;

  -- 3. Clear customer's commerce cart
  delete from public.commerce_cart
  where tenant_id = p_tenant_id and customer_group_id = p_customer_group_id;

  return v_order_id;
end;
$$;

-- 4. Grant execution permissions
grant execute on function public.place_commerce_order(bigint, bigint, text, text, text, numeric, numeric, numeric, numeric, numeric, boolean, jsonb) to authenticated;

commit;
