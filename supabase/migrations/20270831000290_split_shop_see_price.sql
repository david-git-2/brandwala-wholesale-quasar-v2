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

CREATE OR REPLACE FUNCTION public.upsert_customer_group_shop_profile(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_is_active boolean,
  p_default_can_browse boolean,
  p_default_can_see_buy_price boolean,
  p_default_can_see_sell_price boolean,
  p_default_can_add_to_cart boolean,
  p_default_can_place_order boolean,
  p_default_can_negotiate boolean,
  p_default_can_view_quantity boolean,
  p_default_can_set_dropship_price boolean
)
RETURNS SETOF public.customer_group_shop_profiles
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

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
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_shop_customer_group_access(
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_status boolean,
  p_can_browse boolean DEFAULT NULL,
  p_can_see_buy_price boolean DEFAULT NULL,
  p_can_see_sell_price boolean DEFAULT NULL,
  p_can_add_to_cart boolean DEFAULT NULL,
  p_can_place_order boolean DEFAULT NULL,
  p_can_negotiate boolean DEFAULT NULL,
  p_can_view_quantity boolean DEFAULT NULL,
  p_can_set_dropship_price boolean DEFAULT NULL,
  p_price_tier_code text DEFAULT NULL,
  p_credit_limit_amount numeric DEFAULT NULL,
  p_credit_limit_currency_id bigint DEFAULT NULL
)
RETURNS SETOF public.shop_customer_group_access
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  if (p_credit_limit_amount is null) <> (p_credit_limit_currency_id is null) then
    raise exception 'both credit_limit_amount and credit_limit_currency_id must be provided together or be null';
  end if;

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
end;
$$;

CREATE OR REPLACE FUNCTION public.get_shop_permissions_for_customer(p_shop_id bigint)
RETURNS TABLE (
  can_browse boolean,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  can_add_to_cart boolean,
  can_place_order boolean,
  can_negotiate boolean,
  can_view_quantity boolean,
  can_set_dropship_price boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_shop_active boolean;
  v_tenant_id bigint;
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
  end if;

  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  return query
  select
    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_browse, profile.default_can_browse, false)
      end
    ), false) as can_browse,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
        end
      end
    ), false) as can_see_buy_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      end
    ), false) as can_see_sell_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, false)
      end
    ), false) as can_add_to_cart,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_place_order, profile.default_can_place_order, false)
      end
    ), false) as can_place_order,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_negotiate, profile.default_can_negotiate, false)
      end
    ) and v_shop_allows_negotiate, false) as can_negotiate,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_view_quantity, profile.default_can_view_quantity, false)
      end
    ), false) as can_view_quantity,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
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
end;
$$;

CREATE OR REPLACE FUNCTION public.can_customer_see_shop_price(p_shop_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  select coalesce((select can_see_sell_price from public.get_shop_permissions_for_customer(p_shop_id)), false);
$$;

CREATE OR REPLACE FUNCTION public.list_customer_active_carts(p_tenant_id bigint)
RETURNS TABLE (
  cart_id bigint,
  shop_id bigint,
  shop_name text,
  shop_slug text,
  shop_logo_url text,
  shop_type text,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  currency_id bigint,
  currency_code text,
  currency_symbol text,
  item_count bigint,
  cart_total numeric,
  updated_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
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
$$;

CREATE OR REPLACE FUNCTION public.list_customer_shops(p_tenant_id bigint)
RETURNS TABLE (
  id bigint,
  tenant_id bigint,
  name text,
  slug text,
  shop_type public.shop_type_enum,
  order_mode public.shop_order_mode_enum,
  is_negotiable boolean,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  description text,
  category_ids bigint[],
  categories jsonb,
  sell_currency_id bigint,
  sell_currency_code text,
  sell_currency_symbol text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
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
$$;
