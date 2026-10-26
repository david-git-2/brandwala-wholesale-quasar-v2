-- Migration: Add vendor filters (multiple vendors and brand options) to shops
begin;

-- 1. Add vendor_filters column to shops table
alter table public.shops add column if not exists vendor_filters jsonb default null;

-- 2. Relax the vendor_code constraint to allow either vendor_code or vendor_filters
alter table public.shops drop constraint if exists shops_vendor_catalog_requires_vendor_code;
alter table public.shops add constraint shops_vendor_catalog_requires_vendor_code check (
  shop_type <> 'vendor_catalog' or vendor_code is not null or (vendor_filters is not null and jsonb_array_length(vendor_filters) > 0)
);

-- 3. Drop old upsert_shop signature and update it
drop function if exists public.upsert_shop(
  bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean,
  public.shop_type_enum, text, bigint, bigint, bigint, boolean,
  bigint, bigint, text, numeric, text, numeric, numeric, numeric, numeric, boolean
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
  p_vendor_filters                jsonb                default null
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
      vendor_filters
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
      p_vendor_filters
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
  bigint, bigint, text, numeric, text, numeric, numeric, numeric, numeric, boolean, jsonb
) to authenticated;


-- 4. Recreate browse_shop_catalog function to support vendor_filters
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
  v_vendor_filters jsonb;
  
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
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into 
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
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
          where p.is_available = true
            and (p.tenant_id = $2 or p.parent_tenant_id = $2)
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
      v_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_limit,
      v_offset,
      v_see_price,
      v_vendor_filters;
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
    'quantity_display_mode', v_quantity_display_mode,
    'vendor_filters', v_vendor_filters
  ));

  return v_result;
end;
$$;

commit;
