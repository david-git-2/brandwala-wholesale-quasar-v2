CREATE FUNCTION public.add_to_shop_cart (
  p_shop_id                         bigint,
  p_product_id                      bigint,
  p_global_stock_allocation_id      bigint  DEFAULT NULL::bigint,
  p_quantity                        integer DEFAULT 1,
  p_customer_sell_price_amount      numeric DEFAULT NULL::numeric,
  p_customer_sell_price_currency_id bigint  DEFAULT NULL::bigint,
  p_global_stock_id                 bigint  DEFAULT NULL::bigint,
  p_listing_id                      bigint  DEFAULT NULL::bigint,
  p_grade_slug                      text    DEFAULT NULL::text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
  v_min_available_units integer;
  v_product_available_units integer;
BEGIN
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;

  SELECT tenant_id, shop_type, pricing_method, markup_percentage, buy_currency_id, quantity_display_mode, min_available_units
  INTO v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage, v_buy_currency_id, v_quantity_display_mode, v_min_available_units
  FROM public.shops
  WHERE id = p_shop_id;

  SELECT can_add_to_cart, can_set_dropship_price
  INTO v_can_add_to_cart, v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer(p_shop_id);

  IF coalesce(v_can_add_to_cart, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'cart additions not allowed';
  END IF;

  SELECT name, image_url, list_price_amount, list_price_currency_id, available_units
  INTO v_prod_name, v_prod_image, v_prod_price_amount, v_prod_price_currency_id, v_product_available_units
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
    IF NOT public.shop_catalog_meets_min_available_units(v_min_available_units, v_product_available_units) THEN
      RAISE EXCEPTION 'product does not meet minimum available units requirement';
    END IF;

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
$function$;

CREATE FUNCTION public.add_to_shop_cart (
  p_shop_id                         bigint,
  p_product_id                      bigint,
  p_global_stock_allocation_id      bigint  DEFAULT NULL::bigint,
  p_quantity                        integer DEFAULT 1,
  p_customer_sell_price_amount      numeric DEFAULT NULL::numeric,
  p_customer_sell_price_currency_id bigint  DEFAULT NULL::bigint,
  p_global_stock_id                 bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_cart_res jsonb;
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_buy_currency_id bigint;
  v_prod_name text;
  v_prod_image text;
  v_prod_vendor text;
  v_prod_is_available boolean;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_listing_id bigint;
  v_global_stock_id bigint;
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
begin
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;

  select tenant_id, shop_type, pricing_method, markup_percentage, buy_currency_id
  into v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage, v_buy_currency_id
  from public.shops
  where id = p_shop_id;

  select can_add_to_cart, can_set_dropship_price
  into v_can_add_to_cart, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(p_shop_id);

  if coalesce(v_can_add_to_cart, false) is not true then
    raise exception 'cart additions not allowed';
  end if;

  select name, image_url, vendor_code, is_available, list_price_amount, list_price_currency_id
  into v_prod_name, v_prod_image, v_prod_vendor, v_prod_is_available, v_prod_price_amount, v_prod_price_currency_id
  from public.products
  where id = p_product_id;

  if v_prod_name is null then
    raise exception 'product not found';
  end if;

  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_shop_type in ('fixed_price', 'dropship') then
    if v_global_stock_id is null then
      raise exception 'global stock required for this shop type';
    end if;

    select
      l.id, l.global_stock_id, l.sell_price_amount, l.sell_price_currency_id,
      l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
    into
      v_listing_id, v_global_stock_id, v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
    from public.shop_product_listings l
    where l.shop_id = p_shop_id
      and l.global_stock_id = v_global_stock_id
      and l.product_id = p_product_id
      and l.is_active = true;

    if v_listing_id is null then
      raise exception 'active product listing not found on this shop';
    end if;

    if v_shop_type = 'dropship' and exists (
      select 1
      from public.shop_listing_group_hides h
      where h.listing_id = v_listing_id
        and h.customer_group_id = public.current_customer_group_id(v_tenant_id)
    ) then
      raise exception 'product not available for this customer';
    end if;

    select coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
    into v_landed_cost
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gs.id = v_global_stock_id;

    if v_shop_type = 'fixed_price' then
      if v_pricing_method = 'markup' then
        v_sell_price_amount := v_landed_cost * (1 + v_markup_percentage / 100.0);
      elsif v_pricing_method = 'direct_cost' then
        v_sell_price_amount := v_landed_cost;
      end if;
    end if;

    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and global_stock_id = v_global_stock_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
    v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);

    if v_target_qty > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
    end if;

    if v_shop_type = 'dropship' then
      if coalesce(v_can_set_dropship_price, false) then
        if p_customer_sell_price_amount is not null then
          v_customer_sell_price_amount := p_customer_sell_price_amount;
          v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
        else
          if v_sell_price_currency_id = v_min_sell_price_currency_id then
            v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
          else
            v_customer_sell_price_amount := v_sell_price_amount;
          end if;
          v_customer_sell_price_currency_id := v_sell_price_currency_id;
        end if;

        if v_customer_sell_price_currency_id = v_min_sell_price_currency_id
           and v_customer_sell_price_amount < v_min_sell_price_amount then
          raise exception 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
        end if;
      else
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      end if;
    end if;
  else
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  end if;

  if v_existing_item_id is not null then
    update public.shop_cart_items
    set
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    where id = v_existing_item_id;
  else
    insert into public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    values (
      v_cart_id, p_product_id, v_global_stock_id, null,
      p_quantity, 1,
      case when v_shop_type = 'dropship' then coalesce(v_landed_cost, v_prod_price_amount) else v_prod_price_amount end,
      case when v_shop_type = 'dropship' then v_buy_currency_id else v_prod_price_currency_id end,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  end if;

  return public.get_or_create_shop_cart(p_shop_id);
end;
$function$;

GRANT ALL ON FUNCTION public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint, bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint, bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint, bigint, bigint, text) TO service_role;

GRANT ALL ON FUNCTION public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.add_to_shop_cart(bigint, bigint, bigint, integer, numeric, bigint, bigint) TO service_role;