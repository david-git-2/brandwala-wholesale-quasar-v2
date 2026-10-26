-- Dropship listing visibility per customer group (hide rows).
-- Default: no row = shown. Catalog browse, product, and cart skip hidden listings.

create table if not exists public.shop_listing_group_hides (
  id bigint generated always as identity primary key,
  shop_id bigint not null references public.shops(id) on delete cascade,
  listing_id bigint not null references public.shop_product_listings(id) on delete cascade,
  customer_group_id bigint not null references public.customer_groups(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint shop_listing_group_hides_listing_group_unique unique (listing_id, customer_group_id)
);

comment on table public.shop_listing_group_hides is
  'Dropship: row means this group cannot see the listing. No row = shown.';

create index if not exists idx_shop_listing_group_hides_shop_group
  on public.shop_listing_group_hides using btree (shop_id, customer_group_id);

alter table public.shop_listing_group_hides enable row level security;

create policy shop_listing_group_hides_select_tenant_member on public.shop_listing_group_hides
  for select using ((exists ( select 1
   from (public.shops s
     join public.memberships tm on (tm.tenant_id = s.tenant_id))
  where ((s.id = shop_listing_group_hides.shop_id) and (lower(trim(both from tm.email)) = public.current_user_email()) and (tm.is_active = true)))));

create policy shop_listing_group_hides_superadmin_all on public.shop_listing_group_hides
  using ((exists ( select 1
   from public.memberships m
  where ((lower(trim(both from m.email)) = public.current_user_email()) and (m.role = 'superadmin'::public.app_role) and (m.is_active = true)))));

create policy shop_listing_group_hides_write_tenant_admin_staff on public.shop_listing_group_hides
  using ((exists ( select 1
   from public.shops s
  where ((s.id = shop_listing_group_hides.shop_id) and public.membership_has_module_action(s.tenant_id, 'shop_permissions'::text, 'configure'::text)))))
  with check ((exists ( select 1
   from public.shops s
  where ((s.id = shop_listing_group_hides.shop_id) and public.membership_has_module_action(s.tenant_id, 'shop_permissions'::text, 'configure'::text)))));

grant select, insert, update, delete on table public.shop_listing_group_hides to authenticated;
grant all on table public.shop_listing_group_hides to service_role;
grant usage, select, update on sequence public.shop_listing_group_hides_id_seq to authenticated;
grant usage, select, update on sequence public.shop_listing_group_hides_id_seq to service_role;

CREATE OR REPLACE FUNCTION "public"."add_to_shop_cart"("p_shop_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint DEFAULT NULL::bigint, "p_quantity" integer DEFAULT 1, "p_customer_sell_price_amount" numeric DEFAULT NULL::numeric, "p_customer_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_global_stock_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  v_group_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
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
            and not exists (
              select 1
              from public.shop_listing_group_hides h
              where h.listing_id = l.id
                and h.customer_group_id = $20
            )
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
      v_display_quantity_add,
      v_group_id;
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
        and not exists (
          select 1
          from public.shop_listing_group_hides h
          where h.listing_id = l.id
            and h.customer_group_id = public.current_customer_group_id(p_tenant_id)
        )
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



CREATE OR REPLACE FUNCTION "public"."list_shop_listing_group_visibility"("p_shop_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_data jsonb;
begin
  select s.tenant_id, s.shop_type
  into v_tenant_id, v_shop_type
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if v_shop_type <> 'dropship' then
    return jsonb_build_object('data', '[]'::jsonb);
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'listing_id', l.id,
        'product_id', p.id,
        'product_name', p.name,
        'product_image_url', p.image_url,
        'is_visible', h.listing_id is null
      )
      order by p.name asc, l.id asc
    ),
    '[]'::jsonb
  )
  into v_data
  from public.shop_product_listings l
  join public.products p on p.id = l.product_id
  left join public.shop_listing_group_hides h
    on h.listing_id = l.id
   and h.customer_group_id = p_customer_group_id
  where l.shop_id = p_shop_id
    and l.is_active = true;

  return jsonb_build_object('data', v_data);
end;
$$;


ALTER FUNCTION "public"."list_shop_listing_group_visibility"("p_shop_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shop_listing_group_visibility"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_listing_id" bigint, "p_visible" boolean) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
begin
  select s.tenant_id, s.shop_type
  into v_tenant_id, v_shop_type
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'listing visibility is only for dropship shops';
  end if;

  if not exists (
    select 1
    from public.shop_product_listings l
    where l.id = p_listing_id
      and l.shop_id = p_shop_id
  ) then
    raise exception 'listing not found on this shop';
  end if;

  if coalesce(p_visible, true) then
    delete from public.shop_listing_group_hides
    where listing_id = p_listing_id
      and customer_group_id = p_customer_group_id;
  else
    insert into public.shop_listing_group_hides (shop_id, listing_id, customer_group_id)
    values (p_shop_id, p_listing_id, p_customer_group_id)
    on conflict (listing_id, customer_group_id) do nothing;
  end if;

  return jsonb_build_object('success', true, 'listing_id', p_listing_id, 'is_visible', coalesce(p_visible, true));
end;
$$;





grant execute on function public.list_shop_listing_group_visibility(bigint, bigint) to authenticated;
grant execute on function public.set_shop_listing_group_visibility(bigint, bigint, bigint, boolean) to authenticated;
