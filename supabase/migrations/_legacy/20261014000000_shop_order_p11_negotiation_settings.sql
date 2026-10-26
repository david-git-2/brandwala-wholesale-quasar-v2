begin;

-- =========================================================
-- 1. Alter shops table
-- =========================================================
alter table public.shops 
add column if not exists buy_currency_id bigint references public.global_currencies(id),
add column if not exists sell_currency_id bigint references public.global_currencies(id),
add column if not exists pricing_method text check (pricing_method in ('direct_cost', 'markup')),
add column if not exists markup_percentage numeric(5,2) not null default 0 check (markup_percentage >= 0),
add column if not exists quantity_display_mode text check (quantity_display_mode in ('original', 'custom_override'));

-- =========================================================
-- 2. Backfill existing shops
-- =========================================================
update public.shops
set 
  buy_currency_id = coalesce(default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
  sell_currency_id = coalesce(default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
  pricing_method = coalesce(pricing_method, 'direct_cost'),
  quantity_display_mode = coalesce(quantity_display_mode, 'original');

-- =========================================================
-- 3. Set columns as NOT NULL and add constraints
-- =========================================================
alter table public.shops 
alter column buy_currency_id set not null,
alter column sell_currency_id set not null,
alter column pricing_method set not null,
alter column quantity_display_mode set not null;

alter table public.shops drop constraint if exists shops_sell_currency_match;
alter table public.shops add constraint shops_sell_currency_match check (sell_currency_id = default_currency_id);

-- =========================================================
-- 4. Drop old functions to prevent overloading conflicts
-- =========================================================
drop function if exists public.list_shops(bigint, int, int, text, boolean);
drop function if exists public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean);

-- =========================================================
-- 5. Recreate list_shops
-- =========================================================
create or replace function public.list_shops(
  p_tenant_id bigint,
  p_limit     int     default 200,
  p_offset    int     default 0,
  p_search    text    default null,
  p_active    boolean default null
)
returns table (
  id                    bigint,
  tenant_id             bigint,
  name                  text,
  slug                  text,
  shop_type             public.shop_type_enum,
  vendor_code           text,
  order_mode            public.shop_order_mode_enum,
  is_negotiable         boolean,
  show_stock_quantity   boolean,
  default_currency_id   bigint,
  global_stock_type_id  bigint,
  is_active             boolean,
  allow_delivery        boolean,
  buy_currency_id       bigint,
  sell_currency_id      bigint,
  pricing_method        text,
  markup_percentage     numeric,
  quantity_display_mode text,
  created_at            timestamptz,
  updated_at            timestamptz,
  total_count           bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total bigint;
begin
  -- Caller must be a member of this tenant (any active role)
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total
  from public.shops s
  where s.tenant_id = p_tenant_id
    and (p_active  is null or s.is_active = p_active)
    and (p_search  is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%');

  return query
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.vendor_code,
    s.order_mode,
    s.is_negotiable,
    s.show_stock_quantity,
    s.default_currency_id,
    s.global_stock_type_id,
    s.is_active,
    s.allow_delivery,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode,
    s.created_at,
    s.updated_at,
    v_total
  from public.shops s
  where s.tenant_id = p_tenant_id
    and (p_active  is null or s.is_active = p_active)
    and (p_search  is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%')
  order by s.name asc
  limit  p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_shops(bigint, int, int, text, boolean) to authenticated;

-- =========================================================
-- 6. Recreate upsert_shop
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
  p_allow_delivery       boolean              default false,
  -- new fields
  p_buy_currency_id      bigint               default null,
  p_sell_currency_id     bigint               default null,
  p_pricing_method       text                 default null,
  p_markup_percentage    numeric              default 0,
  p_quantity_display_mode text                default null
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

  -- Constraints checking
  if p_pricing_method is not null and p_pricing_method not in ('direct_cost', 'markup') then
    raise exception 'invalid pricing method';
  end if;
  if p_quantity_display_mode is not null and p_quantity_display_mode not in ('original', 'custom_override') then
    raise exception 'invalid quantity display mode';
  end if;
  if p_markup_percentage < 0 then
    raise exception 'markup percentage must be non-negative';
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
      allow_delivery,
      buy_currency_id,
      sell_currency_id,
      pricing_method,
      markup_percentage,
      quantity_display_mode
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
      coalesce(p_default_currency_id, p_sell_currency_id),
      p_global_stock_type_id,
      p_is_active,
      p_allow_delivery,
      coalesce(p_buy_currency_id, p_default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
      coalesce(p_sell_currency_id, p_default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
      coalesce(p_pricing_method, 'direct_cost'),
      coalesce(p_markup_percentage, 0),
      coalesce(p_quantity_display_mode, 'original')
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
      name                  = trim(p_name),
      slug                  = lower(trim(p_slug)),
      order_mode            = p_order_mode,
      is_negotiable         = p_is_negotiable,
      show_stock_quantity   = p_show_stock_quantity,
      default_currency_id   = coalesce(p_default_currency_id, p_sell_currency_id, default_currency_id),
      global_stock_type_id  = p_global_stock_type_id,
      is_active             = p_is_active,
      allow_delivery        = p_allow_delivery,
      buy_currency_id       = coalesce(p_buy_currency_id, buy_currency_id),
      sell_currency_id      = coalesce(p_sell_currency_id, p_default_currency_id, sell_currency_id),
      pricing_method        = coalesce(p_pricing_method, pricing_method),
      markup_percentage     = coalesce(p_markup_percentage, markup_percentage),
      quantity_display_mode = coalesce(p_quantity_display_mode, quantity_display_mode),
      updated_at            = now()
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
  public.shop_type_enum, text, bigint, bigint, bigint, boolean,
  bigint, bigint, text, numeric, text
) to authenticated;

-- =========================================================
-- 7. Recreate browse_shop_catalog with retail markup logic
-- =========================================================
create or replace function public.browse_shop_catalog(
  p_shop_slug text,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  
  v_can_browse boolean;
  v_see_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;

  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  -- Resolve the shop (slug unique per tenant)
  select 
    id, tenant_id, name, shop_type, vendor_code, order_mode, 
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode
  into 
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode
  from public.shops
  where slug = p_shop_slug
    and tenant_id = public.current_tenant_id();

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  -- Resolve effective permissions
  select 
    can_browse, see_price, can_add_to_cart, can_place_order, 
    can_negotiate, can_view_quantity, can_set_dropship_price
  into 
    v_can_browse, v_see_price, v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.vendor_code = $1
            and p.is_available = true
            and (p.tenant_id = $2 or p.parent_tenant_id = $2)
            and ($3 is null or trim($3) = '' or p.name ilike ('%%' || trim($3) || '%%') or p.product_code ilike ('%%' || trim($3) || '%%') or p.barcode ilike ('%%' || trim($3) || '%%'))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
          offset $7
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.id,
                  'product_name', p.name,
                  'product_image_url', p.image_url,
                  'product_barcode', p.barcode,
                  'product_code', p.product_code,
                  'product_brand', p.brand,
                  'product_category', p.category,
                  'vendor_code', p.vendor_code,
                  'is_available', p.is_available,
                  'unit_price_amount', case when $8 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $8 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case when $8 then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $8 then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
                  'minimum_sell_price_amount', null,
                  'minimum_sell_price_currency_id', null,
                  'minimum_sell_price_currency_code', null,
                  'minimum_sell_price_currency_symbol', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($7 / $6) + 1),
            'page_size', $6,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $6::numeric))
          )
        )
      $sql$
    )
    into v_result
    using 
      v_vendor_code,
      v_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price;
  else
    -- fixed_price or dropship
    execute format(
      $sql$
        with filtered as (
          select 
            l.id as listing_id,
            l.global_stock_allocation_id,
            l.global_stock_id,
            case 
              when $8 = 'fixed_price' and $11 = 'markup' then 
                (gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0)) * (1 + $12 / 100.0)
              when $8 = 'fixed_price' and $11 = 'direct_cost' then
                (gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0))
              else 
                l.sell_price_amount
            end as computed_sell_price,
            l.sell_price_currency_id,
            l.minimum_sell_price_amount,
            l.minimum_sell_price_currency_id,
            l.show_quantity as listing_show_quantity,
            l.display_quantity_override,
            p.id as product_id,
            p.name as product_name,
            p.image_url as product_image_url,
            p.barcode as product_barcode,
            p.product_code as product_code,
            p.brand as product_brand,
            p.category as product_category,
            p.vendor_code as product_vendor_code,
            p.is_available as product_is_available,
            p.minimum_order_quantity as product_moq,
            gsa.quantity as allocation_qty,
            (gsa.quantity - coalesce((select sum(quantity) from public.shop_stock_reservations where global_stock_allocation_id = gsa.id), 0)) as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stock_allocations gsa on gsa.id = l.global_stock_allocation_id
          join public.global_stocks gs on gs.id = gsa.stock_id
          join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          join public.global_shipments gship on gship.id = gsi.shipment_id
          where l.shop_id = $1
            and l.is_active = true
            and p.is_available = true
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
          offset $6
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.product_id,
                  'product_name', p.product_name,
                  'product_image_url', p.product_image_url,
                  'product_barcode', p.product_barcode,
                  'product_code', p.product_code,
                  'product_brand', p.product_brand,
                  'product_category', p.product_category,
                  'vendor_code', p.product_vendor_code,
                  'is_available', p.product_is_available,
                  'unit_price_amount', case when $7 then p.computed_sell_price else null end,
                  'unit_price_currency_id', case when $7 then p.sell_price_currency_id else null end,
                  'unit_price_currency_code', case when $7 then (select code from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when $7 then (select symbol from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'minimum_sell_price_amount', case when $7 and $8 = 'dropship' then p.minimum_sell_price_amount else null end,
                  'minimum_sell_price_currency_id', case when $7 and $8 = 'dropship' then p.minimum_sell_price_currency_id else null end,
                  'minimum_sell_price_currency_code', case when $7 and $8 = 'dropship' then (select code from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'minimum_sell_price_currency_symbol', case when $7 and $8 = 'dropship' then (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id) else null end,
                  'available_units', case 
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when $13 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'global_stock_allocation_id', p.global_stock_allocation_id,
                  'global_stock_id', p.global_stock_id,
                  'minimum_order_quantity', p.product_moq
                )
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta',
          jsonb_build_object(
            'total', (select count(*) from filtered),
            'page', (($6 / $5) + 1),
            'page_size', $5,
            'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $5::numeric))
          )
        )
      $sql$
    )
    into v_result
    using 
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode;
  end if;

  -- Add shop & permissions info to metadata
  v_result := jsonb_set(v_result, '{meta, shop}', jsonb_build_object(
    'id', v_shop_id,
    'name', v_shop_name,
    'slug', p_shop_slug,
    'shop_type', v_shop_type,
    'vendor_code', v_vendor_code,
    'order_mode', v_order_mode,
    'is_negotiable', v_is_negotiable,
    'show_stock_quantity', v_show_stock_quantity,
    'default_currency_id', v_default_currency_id,
    'is_active', v_is_active,
    'buy_currency_id', v_buy_currency_id,
    'sell_currency_id', v_sell_currency_id,
    'pricing_method', v_pricing_method,
    'markup_percentage', v_markup_percentage,
    'quantity_display_mode', v_quantity_display_mode
  ));

  v_result := jsonb_set(v_result, '{meta, permissions}', jsonb_build_object(
    'can_browse', v_can_browse,
    'see_price', v_see_price,
    'can_add_to_cart', v_can_add_to_cart,
    'can_place_order', v_can_place_order,
    'can_negotiate', v_can_negotiate,
    'can_view_quantity', v_can_view_quantity,
    'can_set_dropship_price', v_can_set_dropship_price
  ));

  return v_result;
end;
$$;

grant execute on function public.browse_shop_catalog(text, text, text, text, integer, integer) to authenticated;

-- =========================================================
-- 8. Update submit_shop_order_from_cart checkout validator
-- =========================================================
create or replace function public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_billing_profile_id bigint default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_item_count integer;
  v_result jsonb;
begin
  -- 1. Fetch and verify cart
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  -- 2. Verify ownership
  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  -- 3. Fetch shop context
  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;

  -- 4. Verify permission
  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  -- Verify cart has items
  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  -- 5. For dropship shops, enforce price floor validation
  if v_shop.shop_type = 'dropship' then
    if exists (
      select 1 from public.shop_cart_items ci
      where ci.cart_id = p_cart_id
        and ci.customer_sell_price_currency_id = ci.unit_minimum_sell_price_currency_id
        and ci.customer_sell_price_amount < ci.unit_minimum_sell_price_amount
    ) then
      raise exception 'price floor violation: some items are priced below the minimum sell price';
    end if;
  end if;

  -- 6. Determine order status based on shop_type × order_mode matrix
  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    if v_shop.is_negotiable and coalesce(v_can_negotiate, false) then
      v_order_status := 'negotiating';
    else
      v_order_status := 'submitted';
    end if;
  else
    -- fixed_price or dropship
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  -- 7. Generate order number
  v_order_no := 'ORD-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(floor(random() * 100000)::text, 5, '0');

  -- 8. Insert order
  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, shipping_address, billing_profile_id,
    created_by_email
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || p_recipient_name,
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    p_recipient_name, p_recipient_phone, p_shipping_address, p_billing_profile_id,
    public.current_user_email()
  )
  returning id into v_order_id;

  -- 9. Copy items and set pricing snapshots
  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    ordered_quantity
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_amount else null end,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_currency_id else null end,
    case 
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      else null 
    end,
    case 
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      else null 
    end,
    ci.quantity
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  -- 10. Delete reservations
  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  -- 11. Update cart status
  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$$;

grant execute on function public.submit_shop_order_from_cart(bigint, text, text, text, bigint) to authenticated;

commit;
