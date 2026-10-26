-- Migration: Add allow_delivery to shops and update upsert_shop and get_or_create_shop_cart RPCs
begin;

-- =========================================================
-- 1. Alter shops table
-- =========================================================
alter table public.shops 
add column if not exists allow_delivery boolean not null default false;

-- =========================================================
-- 2. Drop old upsert_shop function signature to prevent overloading issues
-- =========================================================
drop function if exists public.upsert_shop(
  bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean,
  public.shop_type_enum, text, bigint, bigint, bigint
);

-- =========================================================
-- 3. Create updated upsert_shop function
-- =========================================================
create or replace function public.upsert_shop(
  p_tenant_id            bigint,
  p_name                 text,
  p_slug                 text,
  p_order_mode           public.shop_order_mode_enum,
  p_is_negotiable        boolean,
  p_show_stock_quantity  boolean,
  p_is_active            boolean,
  -- create-only fields (ignored on update)
  p_shop_type            public.shop_type_enum default null,
  p_vendor_code          text                 default null,
  -- optional fields
  p_id                   bigint               default null,
  p_default_currency_id  bigint               default null,
  p_global_stock_type_id bigint               default null,
  p_allow_delivery       boolean              default false
)
returns setof public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_type public.shop_type_enum;
  v_result    public.shops;
begin
  -- Permission: admin or staff of this tenant
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_id is null then
    -- -------------------------------------------------------
    -- CREATE
    -- -------------------------------------------------------
    if p_shop_type is null then
      raise exception 'shop_type is required when creating a shop';
    end if;

    -- vendor_code required for vendor_catalog
    if p_shop_type = 'vendor_catalog' and (p_vendor_code is null or trim(p_vendor_code) = '') then
      raise exception 'vendor_code is required for vendor_catalog shops';
    end if;

    -- dropship cannot be negotiable
    if p_shop_type = 'dropship' and p_is_negotiable then
      raise exception 'dropship shops cannot be negotiable';
    end if;

    insert into public.shops (
      tenant_id,
      name,
      slug,
      shop_type,
      vendor_code,
      order_mode,
      is_negotiable,
      show_stock_quantity,
      default_currency_id,
      global_stock_type_id,
      is_active,
      allow_delivery
    )
    values (
      p_tenant_id,
      trim(p_name),
      lower(trim(p_slug)),
      p_shop_type,
      case when p_vendor_code is not null then trim(p_vendor_code) else null end,
      p_order_mode,
      p_is_negotiable,
      p_show_stock_quantity,
      p_default_currency_id,
      p_global_stock_type_id,
      p_is_active,
      p_allow_delivery
    )
    returning * into v_result;

  else
    -- -------------------------------------------------------
    -- UPDATE — shop_type and vendor_code are immutable
    -- -------------------------------------------------------
    select shop_type into v_shop_type
    from public.shops
    where id = p_id and tenant_id = p_tenant_id;

    if v_shop_type is null then
      raise exception 'shop not found';
    end if;

    -- dropship cannot be negotiable (guard even on updates)
    if v_shop_type = 'dropship' and p_is_negotiable then
      raise exception 'dropship shops cannot be negotiable';
    end if;

    update public.shops
    set
      name                 = trim(p_name),
      slug                 = lower(trim(p_slug)),
      order_mode           = p_order_mode,
      is_negotiable        = p_is_negotiable,
      show_stock_quantity  = p_show_stock_quantity,
      default_currency_id  = p_default_currency_id,
      global_stock_type_id = p_global_stock_type_id,
      is_active            = p_is_active,
      allow_delivery       = p_allow_delivery,
      updated_at           = now()
    where id = p_id
      and tenant_id = p_tenant_id
    returning * into v_result;

    if v_result is null then
      raise exception 'shop not found or update failed';
    end if;
  end if;

  return next v_result;
end;
$$;

grant execute on function public.upsert_shop(
  bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean,
  public.shop_type_enum, text, bigint, bigint, bigint, boolean
) to authenticated;

-- =========================================================
-- 4. Re-define get_or_create_shop_cart to return shop context in the response
-- =========================================================
create or replace function public.get_or_create_shop_cart(p_shop_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_see_price_snapshot boolean;
  v_cart_id bigint;
  v_result jsonb;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id and is_active = true;
  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

  -- Find group that belongs to the user and has permissions
  select cg.id, coalesce(p.see_price, false)
  into v_customer_group_id, v_see_price_snapshot
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  join public.get_shop_permissions_for_customer(p_shop_id) p on true
  where cg.tenant_id = v_tenant_id
    and lower(trim(cgm.email)) = public.current_user_email()
    and cgm.is_active = true
    and cg.is_active = true
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  end if;

  -- Ensure they can browse
  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  -- Find or insert active cart
  select id into v_cart_id 
  from public.shop_carts
  where tenant_id = v_tenant_id
    and shop_id = p_shop_id
    and customer_group_id = v_customer_group_id
    and status = 'active'
  order by id desc
  limit 1;

  if v_cart_id is null then
    insert into public.shop_carts (
      tenant_id, shop_id, customer_group_id, see_price_snapshot, status
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id, v_see_price_snapshot, 'active'
    )
    returning id into v_cart_id;
  end if;

  -- Return serialized cart with items list and shop details
  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'see_price_snapshot', c.see_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery
    ),
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'unit_list_price_amount', ci.unit_list_price_amount,
            'unit_list_price_currency_id', ci.unit_list_price_currency_id,
            'unit_sell_price_amount', ci.unit_sell_price_amount,
            'unit_sell_price_currency_id', ci.unit_sell_price_currency_id,
            'unit_minimum_sell_price_amount', ci.unit_minimum_sell_price_amount,
            'unit_minimum_sell_price_currency_id', ci.unit_minimum_sell_price_currency_id,
            'customer_sell_price_amount', ci.customer_sell_price_amount,
            'customer_sell_price_currency_id', ci.customer_sell_price_currency_id,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  where c.id = v_cart_id;

  return v_result;
end;
$$;

grant execute on function public.get_or_create_shop_cart(bigint) to authenticated;

commit;
