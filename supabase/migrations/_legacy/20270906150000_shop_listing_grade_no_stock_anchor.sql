-- Grade-based listings without stock anchor: listing = product + grade_tag_id.
-- Cart/order carry listing_id + grade_tag_id; stock allocated at place order (hold).

-- 1. Schema
ALTER TABLE public.shop_product_listings
  ADD COLUMN IF NOT EXISTS grade_tag_id bigint REFERENCES public.tags(id);

ALTER TABLE public.shop_cart_items
  ADD COLUMN IF NOT EXISTS listing_id bigint REFERENCES public.shop_product_listings(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS grade_tag_id bigint REFERENCES public.tags(id);

ALTER TABLE public.shop_order_items
  ADD COLUMN IF NOT EXISTS listing_id bigint REFERENCES public.shop_product_listings(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS grade_tag_id bigint REFERENCES public.tags(id);

-- Backfill grade from legacy anchor stock
UPDATE public.shop_product_listings l
SET grade_tag_id = gs.grade_tag_id
FROM public.global_stocks gs
WHERE gs.id = l.global_stock_id
  AND l.grade_tag_id IS NULL
  AND gs.grade_tag_id IS NOT NULL;

-- Dedupe: one listing per shop + product + grade (keep oldest active)
WITH ranked AS (
  SELECT
    l.id,
    row_number() OVER (
      PARTITION BY l.shop_id, l.product_id, coalesce(l.grade_tag_id, public.default_stock_grade_tag_id())
      ORDER BY l.is_active DESC, l.id ASC
    ) AS rn
  FROM public.shop_product_listings l
  WHERE coalesce(l.grade_tag_id, (
    SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = l.global_stock_id
  )) IS NOT NULL
    OR l.global_stock_id IS NOT NULL
)
DELETE FROM public.shop_product_listings spl
USING ranked r
WHERE spl.id = r.id
  AND r.rn > 1;

UPDATE public.shop_product_listings l
SET grade_tag_id = coalesce(l.grade_tag_id, public.default_stock_grade_tag_id())
WHERE l.grade_tag_id IS NULL
  AND l.global_stock_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS shop_product_listings_shop_product_grade_unique
  ON public.shop_product_listings (shop_id, product_id, grade_tag_id)
  WHERE grade_tag_id IS NOT NULL;

-- 2. Helpers
CREATE OR REPLACE FUNCTION public.shop_product_grade_avg_landed_cost(
  p_shop_tenant_id bigint,
  p_product_id bigint,
  p_grade_tag_id bigint
)
RETURNS numeric
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    avg(coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))),
    0
  )::numeric
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  WHERE gsi.product_id = p_product_id
    AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(p_grade_tag_id, public.default_stock_grade_tag_id())
    AND gs.parent_tenant_id = public.resolve_parent_tenant_id(p_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = TRUE);
$$;

GRANT EXECUTE ON FUNCTION public.shop_product_grade_avg_landed_cost(bigint, bigint, bigint) TO authenticated;

CREATE OR REPLACE FUNCTION public.hold_shop_grade_stock_for_order(
  p_parent_tenant_id bigint,
  p_shop_tenant_id bigint,
  p_product_id bigint,
  p_grade_tag_id bigint,
  p_quantity integer,
  p_order_id bigint,
  p_notes text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_grade_tag_id bigint;
  v_remaining integer;
  v_stock record;
  v_take integer;
  v_primary_held bigint := NULL;
  v_held_stock_id bigint;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'quantity must be positive';
  END IF;

  v_grade_tag_id := coalesce(p_grade_tag_id, public.default_stock_grade_tag_id());
  v_remaining := p_quantity;

  FOR v_stock IN
    SELECT
      gs.id,
      gs.location_id,
      gs.grade_tag_id,
      gs.shipment_item_id,
      greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer AS atp
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gsi.product_id = p_product_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      AND gs.parent_tenant_id = p_parent_tenant_id
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = TRUE)
    ORDER BY gs.id
    FOR UPDATE OF gs
  LOOP
    IF v_remaining <= 0 THEN
      EXIT;
    END IF;

    v_take := least(v_remaining, v_stock.atp);
    IF v_take <= 0 THEN
      CONTINUE;
    END IF;

    PERFORM public.create_and_post_stock_movement(
      p_parent_tenant_id,
      v_stock.id,
      v_take,
      v_stock.location_id,
      'held'::public.stock_availability,
      v_stock.grade_tag_id,
      'availability_transfer'::public.stock_movement_type,
      coalesce(p_notes, 'Shop order hold'),
      'shop_order',
      p_order_id::text
    );

    SELECT gs.id
    INTO v_held_stock_id
    FROM public.global_stocks gs
    WHERE gs.shipment_item_id = v_stock.shipment_item_id
      AND gs.parent_tenant_id = p_parent_tenant_id
      AND gs.availability = 'held'::public.stock_availability
      AND gs.location_id IS NOT DISTINCT FROM v_stock.location_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
        = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
    ORDER BY gs.id DESC
    LIMIT 1;

    v_primary_held := coalesce(v_primary_held, v_held_stock_id);
    v_remaining := v_remaining - v_take;
  END LOOP;

  IF v_remaining > 0 THEN
    RAISE EXCEPTION 'insufficient sellable stock for product % (grade %): short by %',
      p_product_id, v_grade_tag_id, v_remaining;
  END IF;

  RETURN v_primary_held;
END;
$$;

GRANT EXECUTE ON FUNCTION public.hold_shop_grade_stock_for_order(
  bigint, bigint, bigint, bigint, integer, bigint, text
) TO authenticated;


-- 3. Catalog + cart RPCs (grade on listing, no stock anchor)
-- browse_shop_catalog_for_customer
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
  v_can_see_resell_minimum_price boolean;
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
                  'unit_price', case
                    when $8 then jsonb_build_object(
                      'amount', p.list_price_amount,
                      'currency_id', p.list_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.list_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    )
                    else null
                  end,
                  'sell_price', null,
                  'resell_minimum_price', null,
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
      v_can_see_buy_price,
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
                public.shop_product_grade_avg_landed_cost($14, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id)) * (1 + $12 / 100.0)
              when $8 = 'fixed_price' and $11 = 'direct_cost' then
                public.shop_product_grade_avg_landed_cost($14, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id))
              else
                l.sell_price_amount
            end as computed_sell_price,
            coalesce(
              gsi.landed_cost_bdt,
              public.calculate_landed_unit_cost(gsi.id),
              public.shop_product_grade_avg_landed_cost($14, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id))
            ) as computed_unit_cost,
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
            public.shop_product_grade_available_units($14, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id)) as available_qty,
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
            and coalesce(l.grade_tag_id, gs.grade_tag_id) is not null
            and (
              l.display_quantity_override is not null and l.display_quantity_override > 0
              or public.shop_product_grade_available_units($14, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id)) > 0
            )
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.grade_slug asc nulls last, f.listing_id asc
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
                  'unit_price', case
                    when $8 = 'dropship' and $15 then jsonb_build_object(
                      'amount', p.computed_unit_cost,
                      'currency_id', $16,
                      'code', (select code from public.global_currencies where id = $16),
                      'symbol', (select symbol from public.global_currencies where id = $16)
                    )
                    else null
                  end,
                  'sell_price', case
                    when $7 and $8 = 'fixed_price' then jsonb_build_object(
                      'amount', p.computed_sell_price,
                      'currency_id', p.sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.sell_price_currency_id)
                    )
                    when $7 and $8 = 'dropship' then jsonb_build_object(
                      'amount', p.listing_sell_price_amount,
                      'currency_id', p.listing_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.listing_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.listing_sell_price_currency_id)
                    )
                    else null
                  end,
                  'resell_minimum_price', case
                    when $17 and $8 = 'dropship' then jsonb_build_object(
                      'amount', p.minimum_sell_price_amount,
                      'currency_id', p.minimum_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.minimum_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id)
                    )
                    else null
                  end,
                  'available_units', case
                    when not $9 or not coalesce(p.listing_show_quantity, $10) then null
                    when $13 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null then p.display_quantity_override
                    else greatest(0, p.available_qty)
                  end,
                  'global_stock_allocation_id', p.global_stock_id,
                  'global_stock_id', p.global_stock_id,
                  'listing_id', p.listing_id,                  'stock_grade', case                    when p.grade_slug is not null then jsonb_build_object(                      'slug', p.grade_slug,                      'label', p.grade_label,                      'color', p.grade_color                    )                    else null                  end,                  'minimum_order_quantity', p.product_moq
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
      v_can_see_buy_price,
      v_buy_currency_id,
      v_can_see_resell_minimum_price;
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
-- get_shop_catalog_product_for_customer
CREATE OR REPLACE FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_listing_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
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
  v_can_see_resell_minimum_price boolean;
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
      'unit_price_amount', case when v_can_see_buy_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_buy_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_buy_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_buy_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
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
        when row.display_quantity_override is not null then row.display_quantity_override
        else greatest(0, row.available_qty)
      end,
      'listing_id', row.listing_id,      'stock_grade', case        when row.grade_slug is not null then jsonb_build_object(          'slug', row.grade_slug,          'label', row.grade_label,          'color', row.grade_color        )        else null      end,      'global_stock_allocation_id', row.global_stock_id,
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
            public.shop_product_grade_avg_landed_cost(v_shop_tenant_id, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id)) * (1 + v_markup_percentage / 100.0)
          when v_shop_type = 'fixed_price' and v_pricing_method = 'direct_cost' then
            public.shop_product_grade_avg_landed_cost(v_shop_tenant_id, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id))
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
        public.shop_product_grade_available_units(v_shop_tenant_id, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id)) as available_qty,
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
        and (p_listing_id is null or l.id = p_listing_id)
        and coalesce(l.grade_tag_id, gs.grade_tag_id) is not null
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


-- add_to_shop_cart: resolve listing by listing_id or grade_slug; grade-pooled ATP check
CREATE OR REPLACE FUNCTION public.add_to_shop_cart(
  p_shop_id bigint,
  p_product_id bigint,
  p_global_stock_allocation_id bigint DEFAULT NULL,
  p_quantity integer DEFAULT 1,
  p_customer_sell_price_amount numeric DEFAULT NULL,
  p_customer_sell_price_currency_id bigint DEFAULT NULL,
  p_global_stock_id bigint DEFAULT NULL,
  p_listing_id bigint DEFAULT NULL,
  p_grade_slug text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart_res jsonb;
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_buy_currency_id bigint;
  v_prod_name text;
  v_prod_image text;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_grade_tag_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_display_qty_override integer;
  v_landed_cost numeric;
  v_available_to_sell integer;
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
BEGIN
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;

  SELECT tenant_id, shop_type, pricing_method, markup_percentage, buy_currency_id, quantity_display_mode
  INTO v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage, v_buy_currency_id, v_quantity_display_mode
  FROM public.shops
  WHERE id = p_shop_id;

  SELECT can_add_to_cart, can_set_dropship_price
  INTO v_can_add_to_cart, v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer(p_shop_id);

  IF coalesce(v_can_add_to_cart, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'cart additions not allowed';
  END IF;

  SELECT name, image_url, list_price_amount, list_price_currency_id
  INTO v_prod_name, v_prod_image, v_prod_price_amount, v_prod_price_currency_id
  FROM public.products
  WHERE id = p_product_id;

  IF v_prod_name IS NULL THEN
    RAISE EXCEPTION 'product not found';
  END IF;

  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  IF v_shop_type IN ('fixed_price', 'dropship') THEN
    IF p_listing_id IS NOT NULL THEN
      SELECT
        l.id, coalesce(l.grade_tag_id, gs.grade_tag_id), l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
      INTO
        v_listing_id, v_grade_tag_id, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.id = p_listing_id
        AND l.shop_id = p_shop_id
        AND l.product_id = p_product_id
        AND l.is_active = TRUE;
    ELSIF v_global_stock_id IS NOT NULL THEN
      SELECT coalesce(gs_ref.grade_tag_id, public.default_stock_grade_tag_id())
      INTO v_grade_tag_id
      FROM public.global_stocks gs_ref
      WHERE gs_ref.id = v_global_stock_id;

      SELECT
        l.id, coalesce(l.grade_tag_id, gs.grade_tag_id), l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
      INTO
        v_listing_id, v_grade_tag_id, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.shop_id = p_shop_id
        AND l.product_id = p_product_id
        AND l.is_active = TRUE
        AND coalesce(l.grade_tag_id, gs.grade_tag_id) = v_grade_tag_id
      ORDER BY l.id ASC
      LIMIT 1;
    ELSIF p_grade_slug IS NOT NULL AND trim(p_grade_slug) <> '' THEN
      SELECT
        l.id, coalesce(l.grade_tag_id, gs.grade_tag_id), l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
      INTO
        v_listing_id, v_grade_tag_id, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      LEFT JOIN public.tags tg ON tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
      WHERE l.shop_id = p_shop_id
        AND l.product_id = p_product_id
        AND l.is_active = TRUE
        AND coalesce(tg.slug, 'standard') = coalesce(nullif(trim(p_grade_slug), ''), 'standard')
      ORDER BY l.id ASC
      LIMIT 1;
    ELSE
      RAISE EXCEPTION 'listing, grade, or global stock required for this shop type';
    END IF;

    IF v_listing_id IS NULL THEN
      RAISE EXCEPTION 'active product listing not found on this shop';
    END IF;

    v_grade_tag_id := coalesce(v_grade_tag_id, public.default_stock_grade_tag_id());

    IF v_grade_tag_id IS NULL THEN
      RAISE EXCEPTION 'listing grade required';
    END IF;

    v_global_stock_id := NULL;

    SELECT public.shop_product_grade_avg_landed_cost(v_tenant_id, p_product_id, v_grade_tag_id)
    INTO v_landed_cost;

    IF v_shop_type = 'fixed_price' THEN
      IF v_pricing_method = 'markup' THEN
        v_sell_price_amount := v_landed_cost * (1 + v_markup_percentage / 100.0);
      ELSIF v_pricing_method = 'direct_cost' THEN
        v_sell_price_amount := v_landed_cost;
      END IF;
    END IF;

    v_available_to_sell := public.shop_product_grade_available_units(v_tenant_id, p_product_id, v_grade_tag_id);
    IF v_display_qty_override IS NOT NULL THEN
      v_available_to_sell := v_display_qty_override;
    END IF;

    SELECT id, quantity INTO v_existing_item_id, v_existing_item_qty
    FROM public.shop_cart_items
    WHERE cart_id = v_cart_id
      AND listing_id = v_listing_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;

    IF v_target_qty > v_available_to_sell THEN
      RAISE EXCEPTION 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
    END IF;

    IF v_shop_type = 'dropship' THEN
      IF coalesce(v_can_set_dropship_price, false) THEN
        IF p_customer_sell_price_amount IS NOT NULL THEN
          v_customer_sell_price_amount := p_customer_sell_price_amount;
          v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
        ELSE
          IF v_sell_price_currency_id = v_min_sell_price_currency_id THEN
            v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
          ELSE
            v_customer_sell_price_amount := v_sell_price_amount;
          END IF;
          v_customer_sell_price_currency_id := v_sell_price_currency_id;
        END IF;

        IF v_customer_sell_price_currency_id = v_min_sell_price_currency_id
           AND v_customer_sell_price_amount < v_min_sell_price_amount THEN
          RAISE EXCEPTION 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
        END IF;
      ELSE
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      END IF;
    END IF;
  ELSE
    SELECT id, quantity INTO v_existing_item_id, v_existing_item_qty
    FROM public.shop_cart_items
    WHERE cart_id = v_cart_id
      AND product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  END IF;

  IF v_existing_item_id IS NOT NULL THEN
    UPDATE public.shop_cart_items
    SET
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    WHERE id = v_existing_item_id;
  ELSE
    INSERT INTO public.shop_cart_items (
      cart_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    VALUES (
      v_cart_id, p_product_id, v_listing_id, v_grade_tag_id, NULL, NULL,
      p_quantity, 1,
      CASE WHEN v_shop_type = 'dropship' THEN coalesce(v_landed_cost, v_prod_price_amount) ELSE v_prod_price_amount END,
      CASE WHEN v_shop_type = 'dropship' THEN v_buy_currency_id ELSE v_prod_price_currency_id END,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  END IF;

  RETURN public.get_or_create_shop_cart(p_shop_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_shop_catalog_product_for_customer(bigint, text, bigint, bigint) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_to_shop_cart(
  bigint, bigint, bigint, integer, numeric, bigint, bigint, bigint, text
) TO authenticated;

-- 4. get_or_create_shop_cart: expose listing_id + grade_tag_id on items
CREATE OR REPLACE FUNCTION public.get_or_create_shop_cart(p_shop_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_cart_id bigint;
  v_result jsonb;
  v_perm record;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

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
  end if;

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_perm
  from public.get_shop_permissions_for_customer(p_shop_id)
  limit 1;

  v_can_see_buy_price_snapshot := coalesce(v_perm.can_see_buy_price, false);
  v_can_see_sell_price_snapshot := coalesce(v_perm.can_see_sell_price, false);

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
      tenant_id, shop_id, customer_group_id,
      can_see_buy_price_snapshot, can_see_sell_price_snapshot, status,
      deduct_charges_from_margin, deduct_print_from_margin, deduct_packing_from_margin
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id,
      v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot, 'active',
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
  end if;

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
            'listing_id', ci.listing_id,
            'grade_tag_id', ci.grade_tag_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'minimum_order_quantity', p.minimum_order_quantity,
            'unit_list_price_amount', case when c.can_see_buy_price_snapshot then ci.unit_list_price_amount else null end,
            'unit_list_price_currency_id', case when c.can_see_buy_price_snapshot then ci.unit_list_price_currency_id else null end,
            'unit_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.unit_sell_price_amount else null end,
            'unit_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.unit_sell_price_currency_id else null end,
            'unit_minimum_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.unit_minimum_sell_price_amount else null end,
            'unit_minimum_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.unit_minimum_sell_price_currency_id else null end,
            'customer_sell_price_amount', case when c.can_see_sell_price_snapshot then ci.customer_sell_price_amount else null end,
            'customer_sell_price_currency_id', case when c.can_see_sell_price_snapshot then ci.customer_sell_price_currency_id else null end,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
        left join public.products p on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    ),
    'permissions', jsonb_build_object(
      'can_browse', coalesce(v_perm.can_browse, false),
      'can_see_buy_price', coalesce(v_perm.can_see_buy_price, false),
      'can_see_sell_price', coalesce(v_perm.can_see_sell_price, false),
      'can_see_resell_minimum_price', coalesce(v_perm.can_see_resell_minimum_price, false),
      'can_add_to_cart', coalesce(v_perm.can_add_to_cart, false),
      'can_place_order', coalesce(v_perm.can_place_order, false),
      'can_negotiate', coalesce(v_perm.can_negotiate, false),
      'can_view_quantity', coalesce(v_perm.can_view_quantity, false),
      'can_set_dropship_price', coalesce(v_perm.can_set_dropship_price, false)
    ),
    'currency', case
      when gc.id is not null then jsonb_build_object(
        'id', gc.id,
        'code', gc.code,
        'symbol', gc.symbol
      )
      else null
    end
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where c.id = v_cart_id;

  return v_result;
end;
$$;

GRANT EXECUTE ON FUNCTION public.get_or_create_shop_cart(bigint) TO authenticated;

-- 5. update_shop_cart_item_qty: grade-pooled ATP when listing_id present
CREATE OR REPLACE FUNCTION public.update_shop_cart_item_qty(
  p_cart_item_id bigint,
  p_quantity integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart_id bigint;
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_product_id bigint;
  v_listing_id bigint;
  v_grade_tag_id bigint;
  v_display_qty_override integer;
  v_available_to_sell integer;
BEGIN
  IF p_quantity <= 0 THEN
    RETURN public.remove_shop_cart_item(p_cart_item_id);
  END IF;

  SELECT ci.cart_id, ci.product_id, ci.listing_id, ci.grade_tag_id,
         c.shop_id, c.tenant_id, s.shop_type
  INTO v_cart_id, v_product_id, v_listing_id, v_grade_tag_id,
       v_shop_id, v_tenant_id, v_shop_type
  FROM public.shop_cart_items ci
  JOIN public.shop_carts c ON c.id = ci.cart_id
  JOIN public.shops s ON s.id = c.shop_id
  WHERE ci.id = p_cart_item_id;

  IF v_cart_id IS NULL THEN
    RAISE EXCEPTION 'cart item not found';
  END IF;

  IF NOT public.is_cart_owner(
    (SELECT customer_group_id FROM public.shop_carts WHERE id = v_cart_id),
    v_tenant_id
  ) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_shop_type IN ('fixed_price', 'dropship') AND v_grade_tag_id IS NOT NULL THEN
    SELECT l.display_quantity_override
    INTO v_display_qty_override
    FROM public.shop_product_listings l
    WHERE l.id = coalesce(v_listing_id, -1);

    v_available_to_sell := public.shop_product_grade_available_units(
      v_tenant_id, v_product_id, v_grade_tag_id
    );
    IF v_display_qty_override IS NOT NULL THEN
      v_available_to_sell := v_display_qty_override;
    END IF;

    IF p_quantity > v_available_to_sell THEN
      RAISE EXCEPTION 'insufficient stock: requested %, available %',
        p_quantity, greatest(0, v_available_to_sell);
    END IF;
  END IF;

  UPDATE public.shop_cart_items
  SET quantity = p_quantity, updated_at = now()
  WHERE id = p_cart_item_id;

  RETURN public.get_or_create_shop_cart(v_shop_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_shop_cart_item_qty(bigint, integer) TO authenticated;

-- 6. upsert_shop_product_listing: persist grade_tag_id; stock anchor optional
CREATE OR REPLACE FUNCTION public.upsert_shop_product_listing(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_global_stock_allocation_id bigint DEFAULT NULL,
  p_sell_price_amount numeric DEFAULT NULL,
  p_sell_price_currency_id bigint DEFAULT NULL,
  p_minimum_sell_price_amount numeric DEFAULT NULL,
  p_minimum_sell_price_currency_id bigint DEFAULT NULL,
  p_show_quantity boolean DEFAULT NULL,
  p_display_quantity_override integer DEFAULT NULL,
  p_is_active boolean DEFAULT NULL,
  p_id bigint DEFAULT NULL,
  p_is_price_locked boolean DEFAULT NULL,
  p_is_quantity_locked boolean DEFAULT NULL,
  p_quantity_override_type text DEFAULT NULL,
  p_global_stock_id bigint DEFAULT NULL,
  p_product_id bigint DEFAULT NULL
)
RETURNS SETOF public.shop_product_listings
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_product_id bigint;
  v_target_stock_id bigint;
  v_grade_tag_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
  v_default_sell_amount numeric;
BEGIN
  IF NOT public.user_can_manage_shop_tenant(p_tenant_id)
     AND NOT public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;

    IF v_existing.id IS NULL THEN
      RAISE EXCEPTION 'listing not found';
    END IF;

    IF v_existing.global_stock_id IS NULL AND v_existing.grade_tag_id IS NULL THEN
      v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
      v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
      v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

      RETURN QUERY
      UPDATE public.shop_product_listings
      SET
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        updated_at = now()
      WHERE id = v_existing.id
      RETURNING *;
      RETURN;
    END IF;
  END IF;

  v_target_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id, v_existing.global_stock_id);

  IF v_target_stock_id IS NOT NULL THEN
    SELECT gsi.product_id, coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
    INTO v_product_id, v_grade_tag_id
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE gs.id = v_target_stock_id;

    IF v_product_id IS NULL THEN
      RAISE EXCEPTION 'global stock not found';
    END IF;

    IF p_id IS NOT NULL THEN
      SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;
    ELSE
      SELECT * INTO v_existing
      FROM public.shop_product_listings
      WHERE shop_id = p_shop_id
        AND product_id = v_product_id
        AND grade_tag_id = v_grade_tag_id;
    END IF;

    v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
    v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
    v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

    IF v_existing.id IS NOT NULL THEN
      RETURN QUERY
      UPDATE public.shop_product_listings
      SET
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id),
        global_stock_allocation_id = NULL,
        updated_at = now()
      WHERE id = v_existing.id
      RETURNING *;
      RETURN;
    END IF;

    RETURN QUERY
    INSERT INTO public.shop_product_listings (
      tenant_id, shop_id, global_stock_allocation_id, global_stock_id, product_id,
      grade_tag_id, sell_price_amount, sell_price_currency_id,
      minimum_sell_price_amount, minimum_sell_price_currency_id,
      show_quantity, display_quantity_override, is_active,
      is_price_locked, is_quantity_locked, quantity_override_type
    ) VALUES (
      p_tenant_id, p_shop_id, NULL, NULL, v_product_id,
      v_grade_tag_id, p_sell_price_amount, p_sell_price_currency_id,
      p_minimum_sell_price_amount, p_minimum_sell_price_currency_id,
      p_show_quantity, p_display_quantity_override, coalesce(p_is_active, true),
      v_price_locked, v_qty_locked, v_override_type
    )
    RETURNING *;
    RETURN;
  END IF;

  v_product_id := coalesce(p_product_id, v_existing.product_id);
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'product or stock required';
  END IF;

  SELECT p.id, coalesce(p.list_price_amount, p.reference_cost_amount, 0)::numeric
  INTO v_product_id, v_default_sell_amount
  FROM public.products p
  WHERE p.id = v_product_id;

  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'product not found';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;
  ELSE
    SELECT * INTO v_existing
    FROM public.shop_product_listings
    WHERE shop_id = p_shop_id
      AND product_id = v_product_id
      AND global_stock_id IS NULL
      AND grade_tag_id IS NULL;
  END IF;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  IF v_existing.id IS NOT NULL THEN
    RETURN QUERY
    UPDATE public.shop_product_listings
    SET
      sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
      sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = coalesce(p_show_quantity, show_quantity),
      display_quantity_override = p_display_quantity_override,
      is_active = coalesce(p_is_active, is_active),
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      updated_at = now()
    WHERE id = v_existing.id
    RETURNING *;
    RETURN;
  END IF;

  RETURN QUERY
  INSERT INTO public.shop_product_listings (
    tenant_id, shop_id, global_stock_allocation_id, global_stock_id, product_id,
    grade_tag_id, sell_price_amount, sell_price_currency_id,
    minimum_sell_price_amount, minimum_sell_price_currency_id,
    show_quantity, display_quantity_override, is_active,
    is_price_locked, is_quantity_locked, quantity_override_type
  ) VALUES (
    p_tenant_id, p_shop_id, NULL, NULL, v_product_id,
    NULL, coalesce(p_sell_price_amount, v_default_sell_amount, 0), p_sell_price_currency_id,
    p_minimum_sell_price_amount, p_minimum_sell_price_currency_id,
    coalesce(p_show_quantity, true), p_display_quantity_override, coalesce(p_is_active, false),
    v_price_locked, v_qty_locked, v_override_type
  )
  RETURNING *;
END;
$$;

GRANT EXECUTE ON FUNCTION public.upsert_shop_product_listing(
  bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint, bigint
) TO authenticated;

-- 7. submit_shop_order_from_cart: allocate + hold stock by grade at place order
CREATE OR REPLACE FUNCTION public.submit_shop_order_from_cart(
  p_cart_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_recipient_phone_secondary text DEFAULT NULL,
  p_shipping_district text DEFAULT NULL,
  p_shipping_thana text DEFAULT NULL,
  p_billing_profile_id bigint DEFAULT NULL,
  p_is_prepaid boolean DEFAULT false,
  p_delivery_instructions text DEFAULT NULL,
  p_cod_charge_amount numeric DEFAULT 0,
  p_delivery_charge_amount numeric DEFAULT 0,
  p_print_charge_amount numeric DEFAULT 0,
  p_packing_charge_amount numeric DEFAULT 0,
  p_discount_amount numeric DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_parent_tenant_id bigint;
  v_held_stock_id bigint;
  v_available_after integer;
  v_order_item_id bigint;
BEGIN
  SELECT * INTO v_cart FROM public.shop_carts WHERE id = p_cart_id AND status = 'active';
  IF v_cart.id IS NULL THEN
    RAISE EXCEPTION 'active cart not found';
  END IF;

  IF NOT public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  SELECT * INTO v_shop FROM public.shops WHERE id = v_cart.shop_id;
  IF v_shop.id IS NULL OR NOT v_shop.is_active THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  SELECT can_place_order INTO v_can_place_order
  FROM public.get_shop_permissions_for_customer(v_shop.id);

  IF coalesce(v_can_place_order, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'checkout not allowed for this customer group';
  END IF;

  SELECT count(*) INTO v_item_count FROM public.shop_cart_items WHERE cart_id = p_cart_id;
  IF v_item_count = 0 THEN
    RAISE EXCEPTION 'cart is empty';
  END IF;

  IF v_shop.shop_type = 'dropship' THEN
    IF EXISTS (
      SELECT 1 FROM public.shop_cart_items ci
      WHERE ci.cart_id = p_cart_id
        AND ci.customer_sell_price_currency_id = ci.unit_minimum_sell_price_currency_id
        AND ci.customer_sell_price_amount < ci.unit_minimum_sell_price_amount
    ) THEN
      RAISE EXCEPTION 'price floor violation: some items are priced below the minimum sell price';
    END IF;
  END IF;

  v_billing_profile_id := p_billing_profile_id;
  IF v_billing_profile_id IS NULL THEN
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(
      v_cart.tenant_id, v_cart.customer_group_id
    );
  END IF;

  IF v_shop.shop_type = 'vendor_catalog' THEN
    IF v_shop.order_mode <> 'procurement_intent' THEN
      RAISE EXCEPTION 'invalid order mode for vendor catalog shop';
    END IF;
    v_order_status := 'submitted';
  ELSE
    IF v_shop.order_mode = 'checkout_fixed' THEN
      v_order_status := 'confirmed';
    ELSE
      v_order_status := 'submitted';
    END IF;
  END IF;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_cart.tenant_id);
  SELECT public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) INTO v_order_no;

  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  IF v_phone IS NOT NULL THEN
    v_profile := public.upsert_recipient_profile_and_address(
      p_tenant_id => v_cart.tenant_id,
      p_name => p_recipient_name,
      p_phone => v_phone,
      p_phone_secondary => p_recipient_phone_secondary,
      p_address => p_shipping_address,
      p_district => p_shipping_district,
      p_thana => p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;
  END IF;

  INSERT INTO public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, billing_profile_id,
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  VALUES (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), 'customer'),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable,
    v_order_status, CASE WHEN v_order_status = 'negotiating' THEN 1 ELSE 0 END,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id,
    public.current_user_email(),
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions, v_shop.deduct_charges_from_margin,
    false, false, v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id,
    global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id
  )
  SELECT
    v_order_id, ci.product_id, ci.listing_id, ci.grade_tag_id,
    NULL, NULL,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    CASE WHEN v_shop.shop_type = 'dropship' THEN ci.customer_sell_price_amount ELSE NULL END,
    CASE WHEN v_shop.shop_type = 'dropship' THEN ci.customer_sell_price_currency_id ELSE NULL END,
    CASE
      WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      ELSE NULL
    END,
    CASE
      WHEN v_order_status = 'confirmed' THEN coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      ELSE NULL
    END,
    CASE
      WHEN v_shop.shop_type = 'dropship' THEN coalesce(
        ci.unit_list_price_amount,
        public.shop_product_grade_avg_landed_cost(v_cart.tenant_id, ci.product_id, ci.grade_tag_id)
      )
      ELSE NULL
    END,
    CASE WHEN v_shop.shop_type = 'dropship' THEN v_shop.buy_currency_id ELSE NULL END
  FROM public.shop_cart_items ci
  WHERE ci.cart_id = p_cart_id;

  IF v_shop.shop_type IN ('fixed_price', 'dropship') THEN
    FOR v_ci IN SELECT * FROM public.shop_cart_items WHERE cart_id = p_cart_id LOOP
      IF v_ci.grade_tag_id IS NULL THEN
        RAISE EXCEPTION 'cart line missing grade for %', v_ci.name;
      END IF;

      IF v_ci.listing_id IS NOT NULL THEN
        UPDATE public.shop_product_listings
        SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
        WHERE id = v_ci.listing_id
          AND display_quantity_override IS NOT NULL;
      END IF;

      v_held_stock_id := public.hold_shop_grade_stock_for_order(
        v_parent_tenant_id,
        v_cart.tenant_id,
        v_ci.product_id,
        v_ci.grade_tag_id,
        v_ci.quantity,
        v_order_id,
        CASE
          WHEN v_shop.shop_type = 'dropship' THEN 'Dropship order hold'
          ELSE 'Shop order hold'
        END
      );

      SELECT soi.id INTO v_order_item_id
      FROM public.shop_order_items soi
      WHERE soi.order_id = v_order_id
        AND soi.product_id = v_ci.product_id
        AND soi.listing_id IS NOT DISTINCT FROM v_ci.listing_id
      ORDER BY soi.id ASC
      LIMIT 1;

      IF v_order_item_id IS NOT NULL THEN
        UPDATE public.shop_order_items
        SET
          global_stock_id = v_held_stock_id,
          cost_price_amount = CASE
            WHEN v_shop.shop_type = 'dropship' THEN coalesce(
              cost_price_amount,
              public.resolve_shop_order_item_landed_cost(v_held_stock_id, NULL, unit_list_price_amount)
            )
            ELSE cost_price_amount
          END
        WHERE id = v_order_item_id;
      END IF;

      IF v_ci.listing_id IS NOT NULL THEN
        v_available_after := public.shop_product_grade_available_units(
          v_cart.tenant_id, v_ci.product_id, v_ci.grade_tag_id
        );
        IF coalesce((
          SELECT display_quantity_override
          FROM public.shop_product_listings
          WHERE id = v_ci.listing_id
        ), v_available_after, 0) <= 0 THEN
          UPDATE public.shop_product_listings
          SET is_active = false
          WHERE id = v_ci.listing_id;
        END IF;
      END IF;
    END LOOP;
  END IF;

  DELETE FROM public.shop_stock_reservations
  WHERE cart_item_id IN (SELECT id FROM public.shop_cart_items WHERE cart_id = p_cart_id);

  UPDATE public.shop_carts
  SET status = 'converted', updated_at = now()
  WHERE id = p_cart_id;

  SELECT jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) INTO v_result;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_shop_order_from_cart(
  bigint, text, text, text, text, text, text, bigint, boolean, text, numeric, numeric, numeric, numeric, numeric
) TO authenticated;
