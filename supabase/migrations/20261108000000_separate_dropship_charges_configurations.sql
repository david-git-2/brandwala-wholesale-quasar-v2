-- Migration: Separate Dropship Charges Configurations
begin;

-- 1. Add columns to public.shops, public.shop_carts, public.shop_orders
alter table public.shops 
  add column if not exists deduct_cod_from_margin boolean not null default false,
  add column if not exists deduct_delivery_from_margin boolean not null default false,
  add column if not exists deduct_print_from_margin boolean not null default false,
  add column if not exists deduct_packing_from_margin boolean not null default false;

alter table public.shop_carts 
  add column if not exists deduct_cod_from_margin boolean not null default false,
  add column if not exists deduct_delivery_from_margin boolean not null default false,
  add column if not exists deduct_print_from_margin boolean not null default false,
  add column if not exists deduct_packing_from_margin boolean not null default false;

alter table public.shop_orders 
  add column if not exists deduct_cod_from_margin boolean not null default false,
  add column if not exists deduct_delivery_from_margin boolean not null default false,
  add column if not exists deduct_print_from_margin boolean not null default false,
  add column if not exists deduct_packing_from_margin boolean not null default false;

-- 2. Backfill existing records to match the previous toggle state
update public.shops set 
  deduct_cod_from_margin = deduct_charges_from_margin,
  deduct_delivery_from_margin = deduct_charges_from_margin,
  deduct_print_from_margin = deduct_charges_from_margin,
  deduct_packing_from_margin = deduct_charges_from_margin;

update public.shop_carts set 
  deduct_cod_from_margin = deduct_charges_from_margin,
  deduct_delivery_from_margin = deduct_charges_from_margin,
  deduct_print_from_margin = deduct_charges_from_margin,
  deduct_packing_from_margin = deduct_charges_from_margin;

update public.shop_orders set 
  deduct_cod_from_margin = deduct_charges_from_margin,
  deduct_delivery_from_margin = deduct_charges_from_margin,
  deduct_print_from_margin = deduct_charges_from_margin,
  deduct_packing_from_margin = deduct_charges_from_margin;

-- 3. Redefine upsert_shop
drop function if exists public.upsert_shop(
  bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean,
  public.shop_type_enum, text, bigint, bigint, bigint, boolean,
  bigint, bigint, text, numeric, text, numeric, numeric, numeric, numeric, boolean, jsonb
) cascade;

create or replace function public.upsert_shop(
  p_tenant_id                     bigint,
  p_name                          text,
  p_slug                          text,
  p_order_mode                    public.shop_order_mode_enum,
  p_is_negotiable                 boolean,
  p_show_stock_quantity           boolean,
  p_is_active                     boolean,
  -- create-only fields (ignored on update)
  p_shop_type                     public.shop_type_enum default null,
  p_vendor_code                   text                 default null,
  -- optional fields
  p_id                            bigint               default null,
  p_default_currency_id           bigint               default null,
  p_global_stock_type_id          bigint               default null,
  p_allow_delivery                boolean              default false,
  -- pricing fields
  p_buy_currency_id               bigint               default null,
  p_sell_currency_id              bigint               default null,
  p_pricing_method                text                 default null,
  p_markup_percentage             numeric              default 0,
  p_quantity_display_mode         text                 default null,
  -- dropship defaults
  p_default_cod_charge_pct        numeric              default 0,
  p_default_delivery_charge_amount numeric             default 0,
  p_default_print_charge_amount    numeric             default 0,
  p_default_packing_charge_amount  numeric             default 0,
  p_deduct_charges_from_margin     boolean              default false,
  p_vendor_filters                jsonb                default null,
  p_deduct_cod_from_margin         boolean              default false,
  p_deduct_delivery_from_margin    boolean              default false,
  p_deduct_print_from_margin       boolean              default false,
  p_deduct_packing_from_margin     boolean              default false
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

    -- vendor_code or vendor_filters required for vendor_catalog
    if p_shop_type = 'vendor_catalog' and (p_vendor_code is null or trim(p_vendor_code) = '') and (p_vendor_filters is null or jsonb_array_length(p_vendor_filters) = 0) then
      raise exception 'vendor_code or vendor_filters is required for vendor_catalog shops';
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
      quantity_display_mode,
      default_cod_charge_pct,
      default_delivery_charge_amount,
      default_print_charge_amount,
      default_packing_charge_amount,
      deduct_charges_from_margin,
      vendor_filters,
      deduct_cod_from_margin,
      deduct_delivery_from_margin,
      deduct_print_from_margin,
      deduct_packing_from_margin
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
      coalesce(p_quantity_display_mode, 'original'),
      coalesce(p_default_cod_charge_pct, 0),
      coalesce(p_default_delivery_charge_amount, 0),
      coalesce(p_default_print_charge_amount, 0),
      coalesce(p_default_packing_charge_amount, 0),
      coalesce(p_deduct_charges_from_margin, false),
      p_vendor_filters,
      coalesce(p_deduct_cod_from_margin, false),
      coalesce(p_deduct_delivery_from_margin, false),
      coalesce(p_deduct_print_from_margin, false),
      coalesce(p_deduct_packing_from_margin, false)
    )
    returning * into v_result;

  else
    -- -------------------------------------------------------
    -- UPDATE — shop_type and vendor_code are immutable, but vendor_filters can be updated
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
      name                            = trim(p_name),
      slug                            = lower(trim(p_slug)),
      order_mode                      = p_order_mode,
      is_negotiable                   = p_is_negotiable,
      show_stock_quantity             = p_show_stock_quantity,
      default_currency_id             = coalesce(p_default_currency_id, p_sell_currency_id, default_currency_id),
      global_stock_type_id            = p_global_stock_type_id,
      is_active                       = p_is_active,
      allow_delivery                  = p_allow_delivery,
      buy_currency_id                 = coalesce(p_buy_currency_id, buy_currency_id),
      sell_currency_id                = coalesce(p_sell_currency_id, p_default_currency_id, sell_currency_id),
      pricing_method                  = coalesce(p_pricing_method, pricing_method),
      markup_percentage               = coalesce(p_markup_percentage, markup_percentage),
      quantity_display_mode           = coalesce(p_quantity_display_mode, quantity_display_mode),
      default_cod_charge_pct          = coalesce(p_default_cod_charge_pct, default_cod_charge_pct),
      default_delivery_charge_amount  = coalesce(p_default_delivery_charge_amount, default_delivery_charge_amount),
      default_print_charge_amount     = coalesce(p_default_print_charge_amount, default_print_charge_amount),
      default_packing_charge_amount   = coalesce(p_default_packing_charge_amount, default_packing_charge_amount),
      deduct_charges_from_margin      = coalesce(p_deduct_charges_from_margin, deduct_charges_from_margin),
      vendor_filters                  = coalesce(p_vendor_filters, vendor_filters),
      deduct_cod_from_margin          = coalesce(p_deduct_cod_from_margin, deduct_cod_from_margin),
      deduct_delivery_from_margin     = coalesce(p_deduct_delivery_from_margin, deduct_delivery_from_margin),
      deduct_print_from_margin        = coalesce(p_deduct_print_from_margin, deduct_print_from_margin),
      deduct_packing_from_margin      = coalesce(p_deduct_packing_from_margin, deduct_packing_from_margin),
      updated_at                      = now()
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
  bigint, bigint, text, numeric, text, numeric, numeric, numeric, numeric, boolean, jsonb,
  boolean, boolean, boolean, boolean
) to authenticated;


-- 4. Redefine list_shops
drop function if exists public.list_shops(bigint, int, int, text, boolean) cascade;

create or replace function public.list_shops(
  p_tenant_id bigint,
  p_limit     int     default 200,
  p_offset    int     default 0,
  p_search    text    default null,
  p_active    boolean default null
)
returns table (
  id                              bigint,
  tenant_id                       bigint,
  name                            text,
  slug                            text,
  shop_type                       public.shop_type_enum,
  vendor_code                     text,
  order_mode                      public.shop_order_mode_enum,
  is_negotiable                   boolean,
  show_stock_quantity             boolean,
  default_currency_id             bigint,
  global_stock_type_id            bigint,
  is_active                       boolean,
  allow_delivery                  boolean,
  buy_currency_id                 bigint,
  sell_currency_id                bigint,
  pricing_method                  text,
  markup_percentage               numeric,
  quantity_display_mode           text,
  default_cod_charge_pct          numeric,
  default_delivery_charge_amount  numeric,
  default_print_charge_amount     numeric,
  default_packing_charge_amount   numeric,
  deduct_charges_from_margin      boolean,
  vendor_filters                  jsonb,
  deduct_cod_from_margin          boolean,
  deduct_delivery_from_margin     boolean,
  deduct_print_from_margin        boolean,
  deduct_packing_from_margin      boolean,
  created_at                      timestamptz,
  updated_at                      timestamptz,
  total_count                     bigint
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
    s.default_cod_charge_pct,
    s.default_delivery_charge_amount,
    s.default_print_charge_amount,
    s.default_packing_charge_amount,
    s.deduct_charges_from_margin,
    s.vendor_filters,
    s.deduct_cod_from_margin,
    s.deduct_delivery_from_margin,
    s.deduct_print_from_margin,
    s.deduct_packing_from_margin,
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


-- 5. Redefine get_or_create_shop_cart
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
      tenant_id, shop_id, customer_group_id, see_price_snapshot, status, deduct_charges_from_margin,
      deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id, v_see_price_snapshot, 'active',
      (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      (select deduct_cod_from_margin from public.shops where id = p_shop_id),
      (select deduct_delivery_from_margin from public.shops where id = p_shop_id),
      (select deduct_print_from_margin from public.shops where id = p_shop_id),
      (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    )
    returning id into v_cart_id;
  else
    -- Update cart's deduct_charges_from_margin snapshots to current shop defaults
    update public.shop_carts
    set 
      deduct_charges_from_margin = (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      deduct_cod_from_margin = (select deduct_cod_from_margin from public.shops where id = p_shop_id),
      deduct_delivery_from_margin = (select deduct_delivery_from_margin from public.shops where id = p_shop_id),
      deduct_print_from_margin = (select deduct_print_from_margin from public.shops where id = p_shop_id),
      deduct_packing_from_margin = (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    where id = v_cart_id;
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
      'allow_delivery', s.allow_delivery,
      'default_cod_charge_pct', s.default_cod_charge_pct,
      'default_delivery_charge_amount', s.default_delivery_charge_amount,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
      'deduct_cod_from_margin', s.deduct_cod_from_margin,
      'deduct_delivery_from_margin', s.deduct_delivery_from_margin,
      'deduct_print_from_margin', s.deduct_print_from_margin,
      'deduct_packing_from_margin', s.deduct_packing_from_margin
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


-- 6. Redefine submit_shop_order_from_cart
create or replace function public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_billing_profile_id bigint default null,
  p_is_prepaid boolean default false,
  p_delivery_instructions text default null,
  p_cod_charge_amount numeric default 0,
  p_delivery_charge_amount numeric default 0,
  p_print_charge_amount numeric default 0,
  p_packing_charge_amount numeric default 0,
  p_discount_amount numeric default 0
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
  v_billing_profile_id bigint;
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

  -- Resolve billing profile id
  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
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
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || p_recipient_name,
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    p_recipient_name, p_recipient_phone, p_shipping_address, v_billing_profile_id,
    public.current_user_email(),
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions, v_shop.deduct_charges_from_margin,
    v_shop.deduct_cod_from_margin, v_shop.deduct_delivery_from_margin, v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
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

grant execute on function public.submit_shop_order_from_cart(bigint, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric) to authenticated;

commit;
