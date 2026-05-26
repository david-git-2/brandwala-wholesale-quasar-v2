begin;

alter table public.koba_orders
add column extra_profit_user numeric(12,2) default 0,
add column extra_profit_company numeric(12,2) default 0,
add column delivery_adjustment numeric(12,2) default 0,
add column cod_charge numeric(12,2) default 0,
add column packing_charge numeric(12,2) default 0,
add column invoice_charge numeric(12,2) default 0,
add column net_order_commission numeric(12,2) default 0;

drop function if exists public.place_koba_order(bigint, bigint, text, text, text, text, text, boolean);

create or replace function public.place_koba_order(
  p_tenant_id bigint,
  p_customer_group_id bigint default null,
  p_shipping_name text default null,
  p_shipping_phone text default null,
  p_shipping_district text default null,
  p_shipping_thana text default null,
  p_shipping_address text default null,
  p_free_delivery boolean default false,
  p_extra_profit_user numeric default 0,
  p_extra_profit_company numeric default 0,
  p_delivery_adjustment numeric default 0,
  p_cod_charge numeric default 0,
  p_packing_charge numeric default 0,
  p_invoice_charge numeric default 0,
  p_net_order_commission numeric default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_id bigint;
  v_order_id bigint;
  v_subtotal numeric(12,2) := 0;
  v_commission numeric(12,2) := 0;
  v_count integer := 0;
begin
  if not public.koba_context_access_allowed(p_tenant_id, p_customer_group_id) then
    raise exception 'not allowed';
  end if;

  select id into v_cart_id
  from public.koba_carts
  where tenant_id = p_tenant_id
    and customer_group_id is not distinct from p_customer_group_id
  limit 1;

  if v_cart_id is null then
    raise exception 'no cart found for this customer group';
  end if;

  select count(*) into v_count
  from public.koba_cart_items
  where cart_id = v_cart_id;

  if v_count = 0 then
    raise exception 'cart is empty';
  end if;

  select
    coalesce(sum(coalesce(unit_price_gbp, 0) * quantity), 0),
    coalesce(sum(coalesce(commission, 0) * quantity), 0),
    count(*)
  into v_subtotal, v_commission, v_count
  from public.koba_cart_items
  where cart_id = v_cart_id;

  insert into public.koba_orders (
    tenant_id,
    customer_group_id,
    shipping_name,
    shipping_phone,
    shipping_district,
    shipping_thana,
    shipping_address,
    free_delivery,
    subtotal_gbp,
    total_commission,
    item_count,
    status,
    extra_profit_user,
    extra_profit_company,
    delivery_adjustment,
    cod_charge,
    packing_charge,
    invoice_charge,
    net_order_commission
  ) values (
    p_tenant_id,
    p_customer_group_id,
    p_shipping_name,
    p_shipping_phone,
    p_shipping_district,
    p_shipping_thana,
    p_shipping_address,
    p_free_delivery,
    v_subtotal,
    v_commission,
    v_count,
    'pending',
    p_extra_profit_user,
    p_extra_profit_company,
    p_delivery_adjustment,
    p_cod_charge,
    p_packing_charge,
    p_invoice_charge,
    p_net_order_commission
  )
  returning id into v_order_id;

  insert into public.koba_order_items (
    order_id,
    product_id,
    product_code,
    barcode,
    name,
    brand,
    image_url,
    case_size,
    unit_price_gbp,
    commission,
    commission_percentage,
    quantity
  )
  select
    v_order_id,
    product_id,
    product_code,
    barcode,
    name,
    brand,
    image_url,
    case_size,
    unit_price_gbp,
    commission,
    commission_percentage,
    quantity
  from public.koba_cart_items
  where cart_id = v_cart_id;

  delete from public.koba_cart_items
  where cart_id = v_cart_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'customer_group_id', p_customer_group_id,
    'item_count', v_count,
    'subtotal_gbp', v_subtotal,
    'total_commission', v_commission,
    'status', 'pending'
  );
end;
$$;

grant execute on function public.place_koba_order(
  bigint, bigint, text, text, text, text, text, boolean, numeric, numeric, numeric, numeric, numeric, numeric, numeric
)
to authenticated, service_role;

commit;
