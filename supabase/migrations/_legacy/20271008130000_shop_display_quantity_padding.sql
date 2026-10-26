alter table public.shops
  add column if not exists display_quantity_add integer default 6 not null;

alter table public.shops
  drop constraint if exists shops_display_quantity_add_check;

alter table public.shops
  add constraint shops_display_quantity_add_check check (display_quantity_add >= 0);

create or replace function public.shop_padded_display_quantity(p_real integer, p_add integer default 6)
returns integer
language sql
immutable
set search_path to public
as $$
  select case
    when coalesce(p_real, 0) <= 0 then 0
    when p_real <= 2 then p_real
    else p_real + greatest(coalesce(p_add, 6), 0)
  end;
$$;

create or replace function public.recalc_shop_display_quantities(p_shop_id bigint)
returns integer
language plpgsql
security definer
set search_path to public
as $$
declare
  v_tenant_id bigint;
  v_display_add integer;
  v_updated integer;
begin
  if p_shop_id is null then
    raise exception 'shop required';
  end if;

  select s.tenant_id, coalesce(s.display_quantity_add, 6)
  into v_tenant_id, v_display_add
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  with updated as (
    update public.shop_product_listings l
    set
      display_quantity_override = public.shop_padded_display_quantity(
        public.shop_product_grade_available_units(
          v_tenant_id,
          l.product_id,
          gs.grade_tag_id
        ),
        v_display_add
      ),
      updated_at = now()
    from public.global_stocks gs
    where l.shop_id = p_shop_id
      and l.global_stock_id = gs.id
      and not l.is_quantity_locked
    returning l.id
  )
  select count(*)::integer into v_updated from updated;

  return coalesce(v_updated, 0);
end;
$$;

grant execute on function public.shop_padded_display_quantity(integer, integer) to authenticated;
grant execute on function public.recalc_shop_display_quantities(bigint) to authenticated;

DROP FUNCTION IF EXISTS "public"."list_shops"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean);


CREATE OR REPLACE FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_parent_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 200, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_active" boolean DEFAULT NULL::boolean) RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "slug" "text", "shop_type" "public"."shop_type_enum", "vendor_code" "text", "order_mode" "public"."shop_order_mode_enum", "is_negotiable" boolean, "show_stock_quantity" boolean, "default_currency_id" bigint, "global_stock_type_id" bigint, "is_active" boolean, "allow_delivery" boolean, "buy_currency_id" bigint, "sell_currency_id" bigint, "pricing_method" "text", "markup_percentage" numeric, "quantity_display_mode" "text", "display_quantity_add" integer, "default_print_charge_amount" numeric, "default_packing_charge_amount" numeric, "deduct_charges_from_margin" boolean, "vendor_filters" "jsonb", "deduct_print_from_margin" boolean, "deduct_packing_from_margin" boolean, "description" "text", "category_ids" bigint[], "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "total_count" bigint, "tenant_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total bigint;
  v_is_parent_query boolean;
begin
  if not exists (
    select 1 from public.memberships m
    where (m.tenant_id = p_tenant_id or m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  v_is_parent_query := (p_parent_tenant_id is not null and p_parent_tenant_id = p_tenant_id);

  if v_is_parent_query then
    select count(*)
    into v_total
    from public.shops s
    left join public.tenants t on t.id = s.tenant_id
    where (s.parent_tenant_id = p_parent_tenant_id or s.tenant_id = p_parent_tenant_id)
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (
        p_search is null
        or s.name ilike '%' || p_search || '%'
        or s.slug ilike '%' || p_search || '%'
        or t.name ilike '%' || p_search || '%'
      );

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
      s.display_quantity_add,
      s.default_print_charge_amount,
      s.default_packing_charge_amount,
      s.deduct_charges_from_margin,
      s.vendor_filters,
      s.deduct_print_from_margin,
      s.deduct_packing_from_margin,
      s.description,
      s.category_ids,
      s.created_at,
      s.updated_at,
      v_total,
      coalesce(t.name, '')::text as tenant_name
    from public.shops s
    left join public.tenants t on t.id = s.tenant_id
    where (s.parent_tenant_id = p_parent_tenant_id or s.tenant_id = p_parent_tenant_id)
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (
        p_search is null
        or s.name ilike '%' || p_search || '%'
        or s.slug ilike '%' || p_search || '%'
        or t.name ilike '%' || p_search || '%'
      );
  else
    select count(*)
    into v_total
    from public.shops s
    left join public.tenants t on t.id = s.tenant_id
    where s.tenant_id = p_tenant_id
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (
        p_search is null
        or s.name ilike '%' || p_search || '%'
        or s.slug ilike '%' || p_search || '%'
        or t.name ilike '%' || p_search || '%'
      );

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
      s.display_quantity_add,
      s.default_print_charge_amount,
      s.default_packing_charge_amount,
      s.deduct_charges_from_margin,
      s.vendor_filters,
      s.deduct_print_from_margin,
      s.deduct_packing_from_margin,
      s.description,
      s.category_ids,
      s.created_at,
      s.updated_at,
      v_total,
      coalesce(t.name, '')::text as tenant_name
    from public.shops s
    left join public.tenants t on t.id = s.tenant_id
    where s.tenant_id = p_tenant_id
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (
        p_search is null
        or s.name ilike '%' || p_search || '%'
        or s.slug ilike '%' || p_search || '%'
        or t.name ilike '%' || p_search || '%'
      );
  end if;
end;
$$;
ALTER FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean) OWNER TO "postgres";

DROP FUNCTION IF EXISTS public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean, bigint, bigint, text, numeric, text, numeric, numeric, boolean, jsonb, boolean, boolean, text, bigint[], integer);
CREATE OR REPLACE FUNCTION "public"."upsert_shop"("p_tenant_id" bigint, "p_name" "text", "p_slug" "text", "p_order_mode" "public"."shop_order_mode_enum", "p_is_negotiable" boolean, "p_show_stock_quantity" boolean, "p_is_active" boolean, "p_shop_type" "public"."shop_type_enum" DEFAULT NULL::"public"."shop_type_enum", "p_vendor_code" "text" DEFAULT NULL::"text", "p_id" bigint DEFAULT NULL::bigint, "p_default_currency_id" bigint DEFAULT NULL::bigint, "p_global_stock_type_id" bigint DEFAULT NULL::bigint, "p_allow_delivery" boolean DEFAULT false, "p_buy_currency_id" bigint DEFAULT NULL::bigint, "p_sell_currency_id" bigint DEFAULT NULL::bigint, "p_pricing_method" "text" DEFAULT NULL::"text", "p_markup_percentage" numeric DEFAULT 0, "p_quantity_display_mode" "text" DEFAULT NULL::"text", "p_default_print_charge_amount" numeric DEFAULT 0, "p_default_packing_charge_amount" numeric DEFAULT 0, "p_deduct_charges_from_margin" boolean DEFAULT false, "p_vendor_filters" "jsonb" DEFAULT NULL::"jsonb", "p_deduct_print_from_margin" boolean DEFAULT false, "p_deduct_packing_from_margin" boolean DEFAULT false, "p_description" "text" DEFAULT NULL::"text", "p_category_ids" bigint[] DEFAULT '{}'::bigint[], "p_min_available_units" integer DEFAULT 0, "p_display_quantity_add" integer DEFAULT 6) RETURNS SETOF "public"."shops"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_type public.shop_type_enum;
  v_result    public.shops;
  v_vendor_code text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_pricing_method is not null and p_pricing_method not in ('direct_cost', 'markup') then
    raise exception 'invalid pricing method';
  end if;
  if p_quantity_display_mode is not null and p_quantity_display_mode not in ('original', 'custom_override') then
    raise exception 'invalid quantity display mode';
  end if;
  if p_markup_percentage < 0 then
    raise exception 'markup percentage must be non-negative';
  end if;
  if coalesce(p_min_available_units, 0) < 0 then
    raise exception 'min_available_units must be non-negative';
  end if;
  if coalesce(p_display_quantity_add, 6) < 0 then
    raise exception 'display_quantity_add must be non-negative';
  end if;

  v_vendor_code := nullif(trim(coalesce(p_vendor_code, '')), '');
  if v_vendor_code is null
     and p_vendor_filters is not null
     and jsonb_typeof(p_vendor_filters) = 'array'
     and jsonb_array_length(p_vendor_filters) > 0 then
    v_vendor_code := nullif(trim(coalesce(p_vendor_filters->0->>'vendor_code', '')), '');
  end if;

  if p_id is null then
    if p_shop_type is null then
      raise exception 'shop_type is required when creating a shop';
    end if;
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
      display_quantity_add,
      default_print_charge_amount,
      default_packing_charge_amount,
      deduct_charges_from_margin,
      vendor_filters,
      deduct_print_from_margin,
      deduct_packing_from_margin,
      description,
      category_ids,
      min_available_units
    )
    values (
      p_tenant_id,
      trim(p_name),
      lower(trim(p_slug)),
      p_shop_type,
      v_vendor_code,
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
      coalesce(p_display_quantity_add, 6),
      coalesce(p_default_print_charge_amount, 0),
      coalesce(p_default_packing_charge_amount, 0),
      coalesce(p_deduct_charges_from_margin, false),
      p_vendor_filters,
      coalesce(p_deduct_print_from_margin, false),
      coalesce(p_deduct_packing_from_margin, false),
      trim(p_description),
      coalesce(p_category_ids, '{}'),
      coalesce(p_min_available_units, 0)
    )
    returning * into v_result;
  else
    select shop_type into v_shop_type
    from public.shops
    where id = p_id and tenant_id = p_tenant_id
      and deleted_at is null;

    if v_shop_type is null then
      raise exception 'shop not found';
    end if;
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
      display_quantity_add            = coalesce(p_display_quantity_add, display_quantity_add),
      default_print_charge_amount     = coalesce(p_default_print_charge_amount, default_print_charge_amount),
      default_packing_charge_amount   = coalesce(p_default_packing_charge_amount, default_packing_charge_amount),
      deduct_charges_from_margin      = coalesce(p_deduct_charges_from_margin, deduct_charges_from_margin),
      vendor_code                     = case
                                          when p_vendor_code is not null or p_vendor_filters is not null
                                            then v_vendor_code
                                          else vendor_code
                                        end,
      vendor_filters                  = coalesce(p_vendor_filters, vendor_filters),
      deduct_print_from_margin        = coalesce(p_deduct_print_from_margin, deduct_print_from_margin),
      deduct_packing_from_margin      = coalesce(p_deduct_packing_from_margin, deduct_packing_from_margin),
      description                     = trim(p_description),
      category_ids                    = coalesce(p_category_ids, '{}'),
      min_available_units             = coalesce(p_min_available_units, min_available_units),
      updated_at                      = now()
    where id = p_id
      and tenant_id = p_tenant_id
      and deleted_at is null
    returning * into v_result;

    if v_result is null then
      raise exception 'shop not found or update failed';
    end if;
  end if;

  return next v_result;
end;
$$;
CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_cursor_name" "text" DEFAULT NULL::"text", "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
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
  v_display_quantity_add integer;
  v_vendor_filters jsonb;
  v_min_available_units integer;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_can_see_catalog_price boolean;
  v_limit integer;
  v_fetch_limit integer;
  v_cursor_name text;
  v_result jsonb;
  v_parent_tenant_id bigint;
  v_data jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_name text;
  v_last_id bigint;
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
    display_quantity_add, vendor_filters, min_available_units
  into
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_display_quantity_add, v_vendor_filters, v_min_available_units
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
  v_display_quantity_add := coalesce(v_display_quantity_add, 6);
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_fetch_limit := v_limit + 1;
  v_cursor_name := coalesce(p_cursor_name, '');
  v_can_see_catalog_price := coalesce(v_can_see_buy_price, false);

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
            and ($11 = 0 or coalesce(p.available_units, 0) >= $11)
            and ($8 is null or (coalesce(p.name, ''), p.id) > (coalesce($7, ''), $8))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
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
                  'unit_price', case
                    when $10 then jsonb_build_object(
                      'amount', p.list_price_amount,
                      'currency_id', p.list_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.list_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    )
                    else null
                  end,
                  'unit_price_amount', case when $10 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $10 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case
                    when $10 then (select code from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'unit_price_currency_symbol', case
                    when $10 then (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'sell_price', null,
                  'resell_minimum_price', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
                order by p.name asc, p.id asc
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta', jsonb_build_object('limit', $6 - 1)
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
      v_fetch_limit,
      v_cursor_name,
      p_cursor_id,
      v_vendor_filters,
      v_can_see_catalog_price,
      coalesce(v_min_available_units, 0);
  else
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
            l.global_stock_id,
            case
              when $9 = 'fixed_price' and $12 = 'markup' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $13 / 100.0)
              when $9 = 'fixed_price' and $12 = 'direct_cost' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
              else
                l.sell_price_amount
            end as computed_sell_price,
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as computed_unit_cost,
            l.sell_price_amount as listing_sell_price_amount,
            l.sell_price_currency_id as listing_sell_price_currency_id,
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
            public.shop_product_grade_available_units(
              $15,
              p.id,
              coalesce(l.grade_tag_id, gs.grade_tag_id)
            ) as available_qty,
            tg.slug as grade_slug,
            tg.name as grade_label,
            tg.color as grade_color
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          left join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.tags tg on tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
          where l.shop_id = $1
            and l.is_active = true
            and p.is_available = true
            and coalesce(p.hazardous, false) = false
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
            and ($7 is null or (coalesce(p.name, ''), l.id) > (coalesce($6, ''), $7))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
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
                  'unit_price', case
                    when $9 = 'dropship' and $16 then jsonb_build_object(
                      'amount', p.computed_unit_cost,
                      'currency_id', $17,
                      'code', (select code from public.global_currencies where id = $17),
                      'symbol', (select symbol from public.global_currencies where id = $17)
                    )
                    else null
                  end,
                  'sell_price', case
                    when $8 and $9 = 'fixed_price' then jsonb_build_object(
                      'amount', p.computed_sell_price,
                      'currency_id', p.sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.sell_price_currency_id)
                    )
                    when $8 and $9 = 'dropship' then jsonb_build_object(
                      'amount', p.listing_sell_price_amount,
                      'currency_id', p.listing_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.listing_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.listing_sell_price_currency_id)
                    )
                    else null
                  end,
                  'resell_minimum_price', case
                    when $18 and $9 = 'dropship' then jsonb_build_object(
                      'amount', p.minimum_sell_price_amount,
                      'currency_id', p.minimum_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.minimum_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id)
                    )
                    else null
                  end,
                  'available_units', case
                    when not $10 or not coalesce(p.listing_show_quantity, $11) then null
                    when $14 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null
                      and not (p.display_quantity_override = 0 and p.available_qty > 0)
                      then p.display_quantity_override
                    else public.shop_padded_display_quantity(p.available_qty, $19)
                  end,
                  'listing_id', p.listing_id,
                  'stock_grade', case
                    when p.grade_slug is not null then jsonb_build_object(
                      'slug', p.grade_slug,
                      'label', p.grade_label,
                      'color', p.grade_color
                    )
                    else null
                  end,
                  'global_stock_allocation_id', p.global_stock_id,
                  'global_stock_id', p.global_stock_id,
                  'minimum_order_quantity', p.product_moq
                )
                order by p.product_name asc, p.listing_id asc
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta', jsonb_build_object('limit', $5 - 1)
        )
      $sql$
    )
    into v_result
    using
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_fetch_limit,
      v_cursor_name,
      p_cursor_id,
      v_can_see_sell_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id,
      v_can_see_buy_price,
      v_buy_currency_id,
      v_can_see_resell_minimum_price,
      v_display_quantity_add;
  end if;

  v_data := coalesce(v_result->'data', '[]'::jsonb);
  v_n := jsonb_array_length(v_data);
  if v_n > v_limit then
    v_has_more := true;
    select
      coalesce(t.elem->>'product_name', ''),
      case
        when v_shop_type = 'vendor_catalog' then (t.elem->>'product_id')::bigint
        else (t.elem->>'listing_id')::bigint
      end
    into v_last_name, v_last_id
    from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
    where ord = v_limit;

    v_next_cursor := jsonb_build_object('name', v_last_name, 'id', v_last_id);

    select coalesce(jsonb_agg(elem order by ord), '[]'::jsonb)
    into v_data
    from (
      select elem, ord
      from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
      where ord <= v_limit
    ) trimmed;
  end if;

  v_result := jsonb_set(
    jsonb_set(v_result, '{data}', v_data),
    '{meta}',
    coalesce(v_result->'meta', '{}'::jsonb)
      || jsonb_build_object(
        'has_more', v_has_more,
        'next_cursor', v_next_cursor,
        'limit', v_limit
      )
  );

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
    'can_see_resell_minimum_price', v_can_see_resell_minimum_price,
    'can_add_to_cart', v_can_add_to_cart,
    'can_place_order', v_can_place_order,
    'can_negotiate', v_can_negotiate,
    'can_view_quantity', v_can_view_quantity,
    'can_set_dropship_price', v_can_set_dropship_price
  ));

  return v_result;
end;
$_$;


ALTER FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_cursor_name" "text", "p_cursor_id" bigint) OWNER TO "postgres";
CREATE OR REPLACE FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  v_display_quantity_add integer;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_can_see_catalog_price boolean;
  v_min_available_units integer;
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
    display_quantity_add, vendor_filters, min_available_units
  into
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_display_quantity_add, v_vendor_filters, v_min_available_units
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);
  v_display_quantity_add := coalesce(v_display_quantity_add, 6);
  v_can_see_catalog_price := coalesce(v_can_see_buy_price, false);

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
      'unit_price_amount', case when v_can_see_catalog_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_catalog_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_catalog_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_catalog_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
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
      and public.shop_catalog_meets_min_available_units(v_min_available_units, p.available_units)
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
      'unit_price_amount', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.computed_sell_price
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.computed_sell_price
        else null
      end,
      'unit_price_currency_id', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.sell_price_currency_id
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.sell_price_currency_id
        else null
      end,
      'unit_price_currency_code', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'unit_price_currency_symbol', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'minimum_sell_price_amount', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_amount else null end,
      'minimum_sell_price_currency_id', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_currency_id else null end,
      'minimum_sell_price_currency_code', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select code from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'minimum_sell_price_currency_symbol', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select symbol from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'available_units', case
        when not v_can_view_quantity or not coalesce(row.listing_show_quantity, v_show_stock_quantity) then null
        when v_quantity_display_mode = 'original' then greatest(0, row.available_qty)
        when row.display_quantity_override is not null
          and not (row.display_quantity_override = 0 and row.available_qty > 0)
          then row.display_quantity_override
        else public.shop_padded_display_quantity(row.available_qty, v_display_quantity_add)
      end,
      'listing_id', row.listing_id,
      'stock_grade', case
        when row.grade_slug is not null then jsonb_build_object(
          'slug', row.grade_slug,
          'label', row.grade_label,
          'color', row.grade_color
        )
        else null
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
        public.shop_product_grade_available_units(
          v_shop_tenant_id,
          p.id,
          coalesce(l.grade_tag_id, gs.grade_tag_id)
        ) as available_qty,
        tg.slug as grade_slug,
        tg.name as grade_label,
        tg.color as grade_color
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      left join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.tags tg on tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
      where l.shop_id = v_shop_id
        and l.product_id = p_product_id
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
$$;


ALTER FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) OWNER TO "postgres";
