-- =========================================================
-- RPC: add_item_to_cart
-- Single-call cart upsert + item upsert/increment
-- =========================================================

create or replace function public.add_item_to_cart(
  p_tenant_id bigint,
  p_store_id bigint default null,
  p_customer_group_id bigint default null,
  p_can_see_price boolean default false,
  p_product_id bigint default null,
  p_name text default null,
  p_image_url text default null,
  p_price_gbp numeric default null,
  p_quantity integer default 1,
  p_minimum_quantity integer default 1
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart public.carts;
  v_item public.cart_items;
  v_existing_item public.cart_items;
  v_qty integer;
  v_min_qty integer;
  v_name text;
begin
  v_qty := greatest(coalesce(p_quantity, 1), 1);
  v_min_qty := greatest(coalesce(p_minimum_quantity, 1), 1);
  v_name := coalesce(nullif(trim(p_name), ''), 'Unnamed product');

  select *
  into v_cart
  from public.carts c
  where c.tenant_id = p_tenant_id
    and c.store_id is not distinct from p_store_id
    and c.customer_group_id is not distinct from p_customer_group_id
  order by c.id desc
  limit 1;

  if v_cart.id is null then
    insert into public.carts (
      tenant_id,
      store_id,
      customer_group_id,
      can_see_price
    )
    values (
      p_tenant_id,
      p_store_id,
      p_customer_group_id,
      coalesce(p_can_see_price, false)
    )
    returning * into v_cart;
  end if;

  if p_product_id is not null then
    select *
    into v_existing_item
    from public.cart_items ci
    where ci.cart_id = v_cart.id
      and ci.product_id = p_product_id
    limit 1;
  end if;

  if v_existing_item.id is not null then
    update public.cart_items
    set
      quantity = v_existing_item.quantity + v_qty,
      minimum_quantity = v_min_qty,
      name = v_name,
      image_url = coalesce(p_image_url, v_existing_item.image_url),
      price_gbp = coalesce(p_price_gbp, v_existing_item.price_gbp)
    where id = v_existing_item.id
    returning * into v_item;
  else
    insert into public.cart_items (
      cart_id,
      product_id,
      name,
      image_url,
      price_gbp,
      quantity,
      minimum_quantity
    )
    values (
      v_cart.id,
      p_product_id,
      v_name,
      p_image_url,
      p_price_gbp,
      v_qty,
      v_min_qty
    )
    returning * into v_item;
  end if;

  return jsonb_build_object(
    'cart', to_jsonb(v_cart),
    'item', to_jsonb(v_item)
  );
end;
$$;

grant execute on function public.add_item_to_cart(
  bigint,
  bigint,
  bigint,
  boolean,
  bigint,
  text,
  text,
  numeric,
  integer,
  integer
) to authenticated;
