-- Split shop see_price into can_see_buy_price and can_see_sell_price.

ALTER TABLE public.customer_group_shop_profiles
  ADD COLUMN IF NOT EXISTS default_can_see_buy_price boolean,
  ADD COLUMN IF NOT EXISTS default_can_see_sell_price boolean;

UPDATE public.customer_group_shop_profiles
SET
  default_can_see_buy_price = COALESCE(default_can_see_buy_price, default_see_price, false),
  default_can_see_sell_price = COALESCE(default_can_see_sell_price, default_see_price, false)
WHERE default_see_price IS NOT NULL OR default_can_see_buy_price IS NULL OR default_can_see_sell_price IS NULL;

ALTER TABLE public.customer_group_shop_profiles
  ALTER COLUMN default_can_see_buy_price SET DEFAULT false,
  ALTER COLUMN default_can_see_buy_price SET NOT NULL,
  ALTER COLUMN default_can_see_sell_price SET DEFAULT false,
  ALTER COLUMN default_can_see_sell_price SET NOT NULL;

ALTER TABLE public.customer_group_shop_profiles
  DROP COLUMN IF EXISTS default_see_price;

ALTER TABLE public.shop_customer_group_access
  ADD COLUMN IF NOT EXISTS can_see_buy_price boolean,
  ADD COLUMN IF NOT EXISTS can_see_sell_price boolean;

UPDATE public.shop_customer_group_access
SET
  can_see_buy_price = COALESCE(can_see_buy_price, see_price),
  can_see_sell_price = COALESCE(can_see_sell_price, see_price)
WHERE see_price IS NOT NULL OR can_see_buy_price IS NULL OR can_see_sell_price IS NULL;

ALTER TABLE public.shop_customer_group_access
  DROP COLUMN IF EXISTS see_price;

ALTER TABLE public.shop_carts
  ADD COLUMN IF NOT EXISTS can_see_buy_price_snapshot boolean,
  ADD COLUMN IF NOT EXISTS can_see_sell_price_snapshot boolean;

UPDATE public.shop_carts
SET
  can_see_buy_price_snapshot = COALESCE(can_see_buy_price_snapshot, see_price_snapshot, false),
  can_see_sell_price_snapshot = COALESCE(can_see_sell_price_snapshot, see_price_snapshot, false)
WHERE see_price_snapshot IS NOT NULL OR can_see_buy_price_snapshot IS NULL OR can_see_sell_price_snapshot IS NULL;

ALTER TABLE public.shop_carts
  ALTER COLUMN can_see_buy_price_snapshot SET DEFAULT false,
  ALTER COLUMN can_see_buy_price_snapshot SET NOT NULL,
  ALTER COLUMN can_see_sell_price_snapshot SET DEFAULT false,
  ALTER COLUMN can_see_sell_price_snapshot SET NOT NULL;

ALTER TABLE public.shop_carts
  DROP COLUMN IF EXISTS see_price_snapshot;

DROP FUNCTION IF EXISTS public.upsert_customer_group_shop_profile(bigint, bigint, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean);
DROP FUNCTION IF EXISTS public.upsert_shop_customer_group_access(bigint, bigint, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, text, numeric, bigint);
DROP FUNCTION IF EXISTS public.get_shop_permissions_for_customer(bigint);
DROP FUNCTION IF EXISTS public.list_customer_active_carts(bigint);
DROP FUNCTION IF EXISTS public.list_customer_shops(bigint);


CREATE OR REPLACE FUNCTION "public"."upsert_customer_group_shop_profile"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_is_active" boolean, "p_default_can_browse" boolean, "p_default_can_see_buy_price" boolean, "p_default_can_see_sell_price" boolean, "p_default_can_add_to_cart" boolean, "p_default_can_place_order" boolean, "p_default_can_negotiate" boolean, "p_default_can_view_quantity" boolean, "p_default_can_set_dropship_price" boolean) RETURNS SETOF "public"."customer_group_shop_profiles"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  return query
  insert into public.customer_group_shop_profiles (
    tenant_id,
    customer_group_id,
    is_active,
    default_can_browse,
    default_can_see_buy_price,
    default_can_see_sell_price,
    default_can_add_to_cart,
    default_can_place_order,
    default_can_negotiate,
    default_can_view_quantity,
    default_can_set_dropship_price
  )
  values (
    p_tenant_id,
    p_customer_group_id,
    p_is_active,
    p_default_can_browse,
    p_default_can_see_buy_price,
    p_default_can_see_sell_price,
    p_default_can_add_to_cart,
    p_default_can_place_order,
    p_default_can_negotiate,
    p_default_can_view_quantity,
    p_default_can_set_dropship_price
  )
  on conflict (tenant_id, customer_group_id) do update set
    is_active = excluded.is_active,
    default_can_browse = excluded.default_can_browse,
    default_can_see_buy_price = excluded.default_can_see_buy_price,
    default_can_see_sell_price = excluded.default_can_see_sell_price,
    default_can_add_to_cart = excluded.default_can_add_to_cart,
    default_can_place_order = excluded.default_can_place_order,
    default_can_negotiate = excluded.default_can_negotiate,
    default_can_view_quantity = excluded.default_can_view_quantity,
    default_can_set_dropship_price = excluded.default_can_set_dropship_price,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_customer_group_shop_profile"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_is_active" boolean, "p_default_can_browse" boolean, "p_default_can_see_buy_price" boolean, "p_default_can_see_sell_price" boolean, "p_default_can_add_to_cart" boolean, "p_default_can_place_order" boolean, "p_default_can_negotiate" boolean, "p_default_can_view_quantity" boolean, "p_default_can_set_dropship_price" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."upsert_shop_customer_group_access"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_status" boolean, "p_can_browse" boolean DEFAULT NULL::boolean, "p_can_see_buy_price" boolean DEFAULT NULL::boolean, "p_can_see_sell_price" boolean DEFAULT NULL::boolean, "p_can_add_to_cart" boolean DEFAULT NULL::boolean, "p_can_place_order" boolean DEFAULT NULL::boolean, "p_can_negotiate" boolean DEFAULT NULL::boolean, "p_can_view_quantity" boolean DEFAULT NULL::boolean, "p_can_set_dropship_price" boolean DEFAULT NULL::boolean, "p_price_tier_code" "text" DEFAULT NULL::"text", "p_credit_limit_amount" numeric DEFAULT NULL::numeric, "p_credit_limit_currency_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."shop_customer_group_access"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id;

  if v_tenant_id is null then
    raise exception 'shop not found';
  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  if (p_credit_limit_amount is null) <> (p_credit_limit_currency_id is null) then
    raise exception 'both credit_limit_amount and credit_limit_currency_id must be provided together or be null';
  return query
  insert into public.shop_customer_group_access (
    shop_id,
    customer_group_id,
    status,
    can_browse,
    can_see_buy_price,
    can_see_sell_price,
    can_add_to_cart,
    can_place_order,
    can_negotiate,
    can_view_quantity,
    can_set_dropship_price,
    price_tier_code,
    credit_limit_amount,
    credit_limit_currency_id
  )
  values (
    p_shop_id,
    p_customer_group_id,
    p_status,
    p_can_browse,
    p_can_see_buy_price,
    p_can_see_sell_price,
    p_can_add_to_cart,
    p_can_place_order,
    p_can_negotiate,
    p_can_view_quantity,
    p_can_set_dropship_price,
    p_price_tier_code,
    p_credit_limit_amount,
    p_credit_limit_currency_id
  )
  on conflict (shop_id, customer_group_id) do update set
    status = excluded.status,
    can_browse = excluded.can_browse,
    can_see_buy_price = excluded.can_see_buy_price,
    can_see_sell_price = excluded.can_see_sell_price,
    can_add_to_cart = excluded.can_add_to_cart,
    can_place_order = excluded.can_place_order,
    can_negotiate = excluded.can_negotiate,
    can_view_quantity = excluded.can_view_quantity,
    can_set_dropship_price = excluded.can_set_dropship_price,
    price_tier_code = excluded.price_tier_code,
    credit_limit_amount = excluded.credit_limit_amount,
    credit_limit_currency_id = excluded.credit_limit_currency_id,
    updated_at = now()
  returning *;
ALTER FUNCTION "public"."upsert_shop_customer_group_access"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_status" boolean, "p_can_browse" boolean, "p_can_see_buy_price" boolean, "p_can_see_sell_price" boolean, "p_can_add_to_cart" boolean, "p_can_place_order" boolean, "p_can_negotiate" boolean, "p_can_view_quantity" boolean, "p_can_set_dropship_price" boolean, "p_price_tier_code" "text", "p_credit_limit_amount" numeric, "p_credit_limit_currency_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_shop_permissions_for_customer"("p_shop_id" bigint) RETURNS TABLE("can_browse" boolean, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "can_add_to_cart" boolean, "can_place_order" boolean, "can_negotiate" boolean, "can_view_quantity" boolean, "can_set_dropship_price" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_active boolean;
  v_shop_type public.shop_type_enum;
  v_shop_allows_negotiate boolean;
begin
  select is_active, tenant_id, shop_type
  into v_shop_active, v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id;

  if v_shop_active is not true then
    return query select false, false, false, false, false, false, false, false;
    return;
  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  return query
  select
    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_browse, profile.default_can_browse, false)
      end
    ), false) as can_browse,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
        end
      end
    ), false) as can_see_buy_price,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      end
    ), false) as can_see_sell_price,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, false)
      end
    ), false) as can_add_to_cart,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_place_order, profile.default_can_place_order, false)
      end
    ), false) as can_place_order,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_negotiate, profile.default_can_negotiate, false)
      end
    ) and v_shop_allows_negotiate, false) as can_negotiate,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_view_quantity, profile.default_can_view_quantity, false)
      end
    ), false) as can_view_quantity,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false)
        end
      end
    ), false) as can_set_dropship_price
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  join public.shop_customer_group_access access on access.customer_group_id = cg.id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = v_tenant_id
  where access.shop_id = p_shop_id
    and cg.tenant_id = v_tenant_id
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email();
ALTER FUNCTION "public"."get_shop_permissions_for_customer"("p_shop_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_customer_see_shop_price"("p_shop_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select coalesce((select can_see_sell_price from public.get_shop_permissions_for_customer(p_shop_id)), false);
ALTER FUNCTION "public"."can_customer_see_shop_price"("p_shop_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_or_create_shop_cart"("p_shop_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id         bigint;
  v_customer_group_id bigint;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_cart_id           bigint;
  v_result            jsonb;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id and is_active = true;
  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id
    and access.status = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';

  select can_see_buy_price, can_see_sell_price
  into v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot
  from public.get_shop_permissions_for_customer(p_shop_id);

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
      tenant_id, shop_id, customer_group_id, can_see_buy_price_snapshot, can_see_sell_price_snapshot, status, deduct_charges_from_margin,
      deduct_print_from_margin, deduct_packing_from_margin
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id, v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot, 'active',
      (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      (select deduct_print_from_margin from public.shops where id = p_shop_id),
      (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    )
    returning id into v_cart_id;
  else
    update public.shop_carts
    set
      deduct_charges_from_margin = (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      deduct_print_from_margin = (select deduct_print_from_margin from public.shops where id = p_shop_id),
      deduct_packing_from_margin = (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    where id = v_cart_id;
  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'can_see_buy_price_snapshot', c.can_see_buy_price_snapshot,
      'can_see_sell_price_snapshot', c.can_see_sell_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
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
            'minimum_order_quantity', p.minimum_order_quantity,
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
        left join public.products p on p.id = ci.product_id
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
ALTER FUNCTION "public"."get_or_create_shop_cart"("p_shop_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_customer_active_carts"("p_tenant_id" bigint) RETURNS TABLE("cart_id" bigint, "shop_id" bigint, "shop_name" "text", "shop_slug" "text", "shop_logo_url" "text", "shop_type" "text", "can_see_buy_price" boolean, "can_see_sell_price" boolean, "currency_id" bigint, "currency_code" "text", "currency_symbol" "text", "item_count" bigint, "cart_total" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    c.id as cart_id,
    s.id as shop_id,
    s.name as shop_name,
    s.slug as shop_slug,
    null::text as shop_logo_url,
    s.shop_type::text as shop_type,
    c.can_see_buy_price_snapshot as can_see_buy_price,
    c.can_see_sell_price_snapshot as can_see_sell_price,
    s.sell_currency_id as currency_id,
    gc.code as currency_code,
    gc.symbol as currency_symbol,
    coalesce(sum(ci.quantity), 0)::bigint as item_count,
    case
      when c.can_see_sell_price_snapshot then
        sum(
          ci.quantity * coalesce(
            ci.customer_sell_price_amount,
            ci.unit_sell_price_amount,
            ci.unit_list_price_amount,
            0
          )
        )::numeric
      else null
    end as cart_total,
    c.updated_at
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  join public.shop_cart_items ci on ci.cart_id = c.id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where p_tenant_id is not null
    and c.status = 'active'
    and c.tenant_id = p_tenant_id
    and c.customer_group_id = public.current_customer_group_id(p_tenant_id)
  group by c.id, s.id, gc.code, gc.symbol
  order by c.updated_at desc;
ALTER FUNCTION "public"."list_customer_active_carts"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_customer_shops"("p_tenant_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "slug" "text", "shop_type" "public"."shop_type_enum", "order_mode" "public"."shop_order_mode_enum", "is_negotiable" boolean, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "description" "text", "category_ids" bigint[], "categories" "jsonb", "sell_currency_id" bigint, "sell_currency_code" "text", "sell_currency_symbol" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        when s.shop_type = 'dropship' then true
        else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
      end
    ) as can_see_buy_price,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        when s.shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
      end
    ) as can_see_sell_price,
    s.description,
    s.category_ids,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'slug', c.slug,
            'icon', c.icon
          )
        )
        from public.shop_categories c
        where c.id = any(s.category_ids)
          and c.is_active = true
      ),
      '[]'::jsonb
    ) as categories,
    s.sell_currency_id,
    gc.code as sell_currency_code,
    gc.symbol as sell_currency_symbol
  from public.shops s
  join public.shop_customer_group_access access on access.shop_id = s.id
  join public.customer_groups cg on cg.id = access.customer_group_id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where p_tenant_id is not null
    and s.is_active = true
    and s.deleted_at is null
    and s.tenant_id = p_tenant_id
    and cg.id = public.current_customer_group_id(p_tenant_id)
    and cg.is_active = true
    and access.status = true
    and coalesce(profile.is_active, true) = true
    and coalesce(access.can_browse, profile.default_can_browse, false) = true
  group by
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    s.description,
    s.category_ids,
    s.sell_currency_id,
    gc.code,
    gc.symbol
  order by s.name asc;
ALTER FUNCTION "public"."list_customer_shops"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
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
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
  v_parent_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.is_available = true
            and coalesce(p.hazardous, false) = false
            and p.parent_tenant_id = $2
            and (
              (($9 is null or jsonb_array_length($9) = 0) and p.vendor_code = $1)
              or
              ($9 is not null and jsonb_array_length($9) > 0 and exists (
                select 1
                from jsonb_to_recordset($9) as vf(vendor_code text, brands text[])
                where vf.vendor_code = p.vendor_code
                  and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
              ))
            )
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
      v_parent_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_can_see_sell_price,
      v_vendor_filters;
  else
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
            l.global_stock_id,
            case
              when $8 = 'fixed_price' and $11 = 'markup' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $12 / 100.0)
              when $8 = 'fixed_price' and $11 = 'direct_cost' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
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
            greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.global_shipments gship on gship.id = gsi.shipment_id
            and gship.assigned_child_tenant_id = $14
          where l.shop_id = $1
            and l.global_stock_id is not null
            and coalesce(gship.status, 'received') = 'received'
            and l.is_active = true
            and p.is_available = true
            and coalesce(p.hazardous, false) = false
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
                  'unit_price_amount', case when (($8 = 'dropship' and $15) or ($8 <> 'dropship' and $7)) then p.computed_sell_price else null end,
                  'unit_price_currency_id', case when (($8 = 'dropship' and $15) or ($8 <> 'dropship' and $7)) then p.sell_price_currency_id else null end,
                  'unit_price_currency_code', case when (($8 = 'dropship' and $15) or ($8 <> 'dropship' and $7)) then (select code from public.global_currencies where id = p.sell_price_currency_id) else null end,
                  'unit_price_currency_symbol', case when (($8 = 'dropship' and $15) or ($8 <> 'dropship' and $7)) then (select symbol from public.global_currencies where id = p.sell_price_currency_id) else null end,
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
                  'global_stock_allocation_id', p.global_stock_id,
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
      v_can_see_sell_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id,
      v_can_see_buy_price;
  end if;

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
    'quantity_display_mode', v_quantity_display_mode,
    'vendor_filters', v_vendor_filters
  ));
  v_result := jsonb_set(v_result, '{meta, permissions}', jsonb_build_object(
    'can_browse', v_can_browse,
    'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
    'can_add_to_cart', v_can_add_to_cart,
    'can_place_order', v_can_place_order,
    'can_negotiate', v_can_negotiate,
    'can_view_quantity', v_can_view_quantity,
    'can_set_dropship_price', v_can_set_dropship_price
  ));

  return v_result;
end;
$_$;


ALTER FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  v_search := nullif(trim(coalesce(p_search, '')), '');
  v_limit := greatest(1, least(coalesce(p_limit, 20), 50));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_search is null then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', 1,
        'page_size', v_limit,
        'total_pages', 1
      )
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  with accessible_shops as (
    select
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
        end
      ) as can_see_buy_price,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      ) as can_see_sell_price
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and s.deleted_at is null
      and s.tenant_id = p_tenant_id
      and cg.id = public.current_customer_group_id(p_tenant_id)
      and cg.is_active = true
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
    group by
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage
  ),
  vendor_catalog_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case when s.can_see_sell_price then p.list_price_amount else null end as unit_price_amount,
      case when s.can_see_sell_price then p.list_price_currency_id else null end as unit_price_currency_id,
      case when s.can_see_sell_price then gc.symbol else null end as unit_price_currency_symbol
    from accessible_shops s
    join public.products p on p.parent_tenant_id = v_parent_tenant_id
    left join public.global_currencies gc on gc.id = p.list_price_currency_id
    where s.shop_type = 'vendor_catalog'
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or (
          s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
            select 1
            from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
            where vf.vendor_code = p.vendor_code
              and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
          )
        )
      )
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  listing_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case
        when s.shop_type = 'dropship' and not s.can_see_buy_price then null
        when s.shop_type <> 'dropship' and not s.can_see_sell_price then null
        when s.shop_type = 'fixed_price' and s.pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + s.markup_percentage / 100.0)
        when s.shop_type = 'fixed_price' and s.pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
        else l.sell_price_amount
      end as unit_price_amount,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then l.sell_price_currency_id
        when s.shop_type <> 'dropship' and s.can_see_sell_price then l.sell_price_currency_id
        else null
      end as unit_price_currency_id,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then gc.symbol
        when s.shop_type <> 'dropship' and s.can_see_sell_price then gc.symbol
        else null
      end as unit_price_currency_symbol
    from accessible_shops s
    join public.shop_product_listings l on l.shop_id = s.id
    join public.products p on p.id = l.product_id
    join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
      and gship.assigned_child_tenant_id = s.tenant_id
    left join public.global_currencies gc on gc.id = l.sell_price_currency_id
    where s.shop_type <> 'vendor_catalog'
      and l.global_stock_id is not null
      and coalesce(gship.status, 'received') = 'received'
      and l.is_active = true
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  combined as (
    select * from vendor_catalog_rows
    union all
    select * from listing_rows
  ),
  ranked as (
    select
      c.*,
      row_number() over (
        partition by c.product_id
        order by c.shop_name asc, c.shop_id asc
      ) as row_num
    from combined c
  ),
  deduped as (
    select * from ranked where row_num = 1
  )
  select jsonb_build_object(
    'data',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'shop_id', d.shop_id,
            'shop_slug', d.shop_slug,
            'shop_name', d.shop_name,
            'product_id', d.product_id,
            'product_name', d.product_name,
            'product_image_url', d.product_image_url,
            'product_barcode', d.product_barcode,
            'product_code', d.product_code,
            'product_brand', d.product_brand,
            'product_category', d.product_category,
            'unit_price_amount', d.unit_price_amount,
            'unit_price_currency_id', d.unit_price_currency_id,
            'unit_price_currency_symbol', d.unit_price_currency_symbol
          )
          order by d.product_name asc, d.product_id asc
        )
        from (
          select *
          from deduped
          order by product_name asc, product_id asc
          limit v_limit
          offset v_offset
        ) d
      ),
      '[]'::jsonb
    ),
    'meta',
    jsonb_build_object(
      'total', (select count(*)::bigint from deduped),
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil((select count(*)::numeric from deduped) / v_limit::numeric))
    )
  )
  into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
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
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_product jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
  end if;
  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  if v_shop_type = 'vendor_catalog' then
    select jsonb_build_object(
      'product_id', p.id,
      'product_name', p.name,
      'product_image_url', p.image_url,
      'product_barcode', p.barcode,
      'product_code', p.product_code,
      'product_brand', p.brand,
      'product_category', p.category,
      'vendor_code', p.vendor_code,
      'is_available', p.is_available,
      'country_of_origin', p.country_of_origin,
      'expire_date', p.expire_date,
      'unit_price_amount', case when v_can_see_sell_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_sell_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_sell_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_sell_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
      'minimum_sell_price_amount', null,
      'minimum_sell_price_currency_id', null,
      'minimum_sell_price_currency_code', null,
      'minimum_sell_price_currency_symbol', null,
      'available_units', null,
      'global_stock_allocation_id', null,
      'global_stock_id', null,
      'minimum_order_quantity', p.minimum_order_quantity
    )
    into v_product
    from public.products p
    where p.id = p_product_id
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
        or
        (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
          select 1
          from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
    limit 1;
  else
    select jsonb_build_object(
      'product_id', row.product_id,
      'product_name', row.product_name,
      'product_image_url', row.product_image_url,
      'product_barcode', row.product_barcode,
      'product_code', row.product_code,
      'product_brand', row.product_brand,
      'product_category', row.product_category,
      'vendor_code', row.product_vendor_code,
      'is_available', row.product_is_available,
      'country_of_origin', row.country_of_origin,
      'expire_date', row.expire_date,
      'unit_price_amount', case when (v_shop_type = 'dropship' and v_can_see_buy_price) or (v_shop_type <> 'dropship' and v_can_see_sell_price) then row.computed_sell_price else null end,
      'unit_price_currency_id', case when (v_shop_type = 'dropship' and v_can_see_buy_price) or (v_shop_type <> 'dropship' and v_can_see_sell_price) then row.sell_price_currency_id else null end,
      'unit_price_currency_code', case when (v_shop_type = 'dropship' and v_can_see_buy_price) or (v_shop_type <> 'dropship' and v_can_see_sell_price) then (select code from public.global_currencies where id = row.sell_price_currency_id) else null end,
      'unit_price_currency_symbol', case when (v_shop_type = 'dropship' and v_can_see_buy_price) or (v_shop_type <> 'dropship' and v_can_see_sell_price) then (select symbol from public.global_currencies where id = row.sell_price_currency_id) else null end,
      'minimum_sell_price_amount', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_amount else null end,
      'minimum_sell_price_currency_id', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_currency_id else null end,
      'minimum_sell_price_currency_code', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select code from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'minimum_sell_price_currency_symbol', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select symbol from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'available_units', case
        when not v_can_view_quantity or not coalesce(row.listing_show_quantity, v_show_stock_quantity) then null
        when v_quantity_display_mode = 'original' then greatest(0, row.available_qty)
        when row.display_quantity_override is not null then row.display_quantity_override
        else greatest(0, row.available_qty)
      end,
      'global_stock_allocation_id', row.global_stock_id,
      'global_stock_id', row.global_stock_id,
      'minimum_order_quantity', row.product_moq
    )
    into v_product
    from (
      select
        l.id as listing_id,
        l.global_stock_id,
        case
          when v_shop_type = 'fixed_price' and v_pricing_method = 'markup' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + v_markup_percentage / 100.0)
          when v_shop_type = 'fixed_price' and v_pricing_method = 'direct_cost' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
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
        p.country_of_origin,
        p.expire_date,
        p.minimum_order_quantity as product_moq,
        greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer as available_qty
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.global_shipments gship on gship.id = gsi.shipment_id
        and gship.assigned_child_tenant_id = v_shop_tenant_id
      where l.shop_id = v_shop_id
        and l.product_id = p_product_id
        and l.global_stock_id is not null
        and coalesce(gship.status, 'received') = 'received'
        and l.is_active = true
        and p.is_available = true
        and coalesce(p.hazardous, false) = false
      order by l.id asc
      limit 1
    ) row;
  end if;

  if v_product is null then
    raise exception 'product not found';
  end if;

  return jsonb_build_object(
    'data', v_product,
    'meta', jsonb_build_object(
      'shop', jsonb_build_object(
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
        'quantity_display_mode', v_quantity_display_mode,
        'vendor_filters', v_vendor_filters
      ),
      'permissions', jsonb_build_object(
        'can_browse', v_can_browse,
        'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
        'can_add_to_cart', v_can_add_to_cart,
        'can_place_order', v_can_place_order,
        'can_negotiate', v_can_negotiate,
        'can_view_quantity', v_can_view_quantity,
        'can_set_dropship_price', v_can_set_dropship_price
      )
    )
  );
end;
$_$;


ALTER FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer DEFAULT 4) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_is_active boolean;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_category text;
  v_limit integer;
  v_data jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
  end if;
  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, shop_type, vendor_code, is_active, vendor_filters
  into
    v_shop_id, v_shop_tenant_id, v_shop_type, v_vendor_code, v_is_active, v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select can_browse
  into v_can_browse
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  if v_shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 4), 12));

  select can_see_sell_price
  into v_can_see_sell_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  select p.category
  into v_category
  from public.products p
  where p.id = p_product_id
    and p.is_available = true
    and coalesce(p.hazardous, false) = false
    and p.parent_tenant_id = v_parent_tenant_id
    and (
      ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
      or
      (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
        select 1
        from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
        where vf.vendor_code = p.vendor_code
          and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
      ))
    )
  limit 1;

  if v_category is null or trim(v_category) = '' or left(trim(v_category), 1) = '=' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'product_id', rel.id,
          'product_name', rel.name,
          'product_image_url', rel.image_url,
          'product_barcode', rel.barcode,
          'product_code', rel.product_code,
          'product_brand', rel.brand,
          'product_category', rel.category,
          'vendor_code', rel.vendor_code,
          'is_available', rel.is_available,
          'unit_price_amount', case when v_can_see_sell_price then rel.list_price_amount else null end,
          'unit_price_currency_id', case when v_can_see_sell_price then rel.list_price_currency_id else null end,
          'unit_price_currency_code', case when v_can_see_sell_price then (select code from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'unit_price_currency_symbol', case when v_can_see_sell_price then (select symbol from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'minimum_sell_price_amount', null,
          'minimum_sell_price_currency_id', null,
          'minimum_sell_price_currency_code', null,
          'minimum_sell_price_currency_symbol', null,
          'available_units', null,
          'global_stock_allocation_id', null,
          'global_stock_id', null,
          'minimum_order_quantity', rel.minimum_order_quantity
        )
        order by rel.name asc, rel.id asc
      )
      from (
        select p.*
        from public.products p
        where p.is_available = true
          and coalesce(p.hazardous, false) = false
          and p.parent_tenant_id = v_parent_tenant_id
          and p.id <> p_product_id
          and lower(coalesce(p.category, '')) = lower(trim(v_category))
          and (
            ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
            or
            (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
              select 1
              from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
              where vf.vendor_code = p.vendor_code
                and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
            ))
          )
        order by p.name asc, p.id asc
        limit v_limit
      ) rel
    ),
    '[]'::jsonb
  )
  into v_data;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object('category', trim(v_category))
  );
end;
$$;


ALTER FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer) OWNER TO "postgres";

