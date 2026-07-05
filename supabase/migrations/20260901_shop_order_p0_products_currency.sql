-- Shop & Order Phase 0: products multi-currency migration

begin;

-- 1. Add new columns and constraints to products
alter table public.products
  add column list_price_amount numeric(12,4) null,
  add column list_price_currency_id bigint null references public.global_currencies(id) on delete set null,
  add column reference_cost_amount numeric(12,4) null,
  add column reference_cost_currency_id bigint null references public.global_currencies(id) on delete set null,
  add constraint products_list_price_currency_check check ((list_price_amount is null) = (list_price_currency_id is null)),
  add constraint products_reference_cost_currency_check check ((reference_cost_amount is null) = (reference_cost_currency_id is null));

-- 2. Create indexes for the new foreign keys
create index if not exists products_list_price_currency_id_idx on public.products (list_price_currency_id);
create index if not exists products_reference_cost_currency_id_idx on public.products (reference_cost_currency_id);

-- 3. Backfill existing GBP values
update public.products
set
  list_price_amount = price_gbp,
  list_price_currency_id = (select id from public.global_currencies where code = 'GBP' limit 1)
where price_gbp is not null;

-- 4. Drop the legacy price_gbp column
alter table public.products drop column price_gbp;

-- 5. Redefine list_products_paginated to handle new sort field
create or replace function public.list_products_paginated(
  p_tenant_id bigint default null,
  p_search text default null,
  p_search_field text default 'name',
  p_category text default null,
  p_brand text default null,
  p_vendor_code text default null,
  p_market_code text default null,
  p_is_available boolean default null,
  p_sort_by text default 'name',
  p_sort_dir text default 'asc',
  p_limit integer default 20,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit integer;
  v_offset integer;
  v_sort_by text;
  v_sort_dir text;
  v_search_field text;
  v_result jsonb;
begin
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  v_sort_by := lower(trim(coalesce(p_sort_by, 'name')));
  if not (v_sort_by = any (array[
    'id',
    'name',
    'product_code',
    'barcode',
    'brand',
    'category',
    'list_price_amount',
    'available_units',
    'created_at',
    'updated_at'
  ])) then
    v_sort_by := 'name';
  end if;

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  end if;

  v_search_field := lower(trim(coalesce(p_search_field, 'name')));
  if v_search_field not in ('name', 'barcode', 'product_code', 'id') then
    v_search_field := 'name';
  end if;

  execute format(
    $sql$
      with filtered as (
        select p.*
        from public.products p
        where
          ($1 is null or p.tenant_id = $1)
          and ($2 is null or trim($2) = '' or (
            ($3 = 'name' and p.name ilike ('%%' || trim($2) || '%%'))
            or ($3 = 'barcode' and p.barcode ilike ('%%' || trim($2) || '%%'))
            or ($3 = 'product_code' and p.product_code ilike ('%%' || trim($2) || '%%'))
            or ($3 = 'id' and trim($2) ~ '^[0-9]+$' and p.id = trim($2)::bigint)
          ))
          and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
          and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
          and ($6 is null or trim($6) = '' or upper(coalesce(p.vendor_code, '')) = upper(trim($6)))
          and ($7 is null or trim($7) = '' or upper(coalesce(p.market_code, '')) = upper(trim($7)))
          and ($8 is null or p.is_available = $8)
      ),
      paged as (
        select f.*
        from filtered f
        order by %I %s nulls last, f.id asc
        limit $9
        offset $10
      )
      select jsonb_build_object(
        'data',
        coalesce((select jsonb_agg(to_jsonb(p)) from paged p), '[]'::jsonb),
        'meta',
        jsonb_build_object(
          'total', (select count(*) from filtered),
          'page', (($10 / $9) + 1),
          'page_size', $9,
          'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / $9::numeric))
        )
      )
    $sql$,
    v_sort_by,
    v_sort_dir
  )
  into v_result
  using
    p_tenant_id,
    p_search,
    v_search_field,
    p_category,
    p_brand,
    p_vendor_code,
    p_market_code,
    p_is_available,
    v_limit,
    v_offset;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', ((v_offset / v_limit) + 1),
        'page_size', v_limit,
        'total_pages', 1
      )
    )
  );
end;
$$;

-- 6. Redefine get_cart_details to select new product pricing fields
create or replace function public.get_cart_details(
  p_cart_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.can_access_cart(p_cart_id) then
    raise exception 'not authorized to access this cart';
  end if;

  select jsonb_build_object(
    'cart',
    jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'store_id', c.store_id,
      'customer_group_id', c.customer_group_id,
      'can_see_price', c.can_see_price,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'name', ci.name,
            'image_url', ci.image_url,
            'price_gbp', ci.price_gbp,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'created_at', ci.created_at,
            'updated_at', ci.updated_at,
            'product',
            case
              when p.id is null then null
              else jsonb_build_object(
                'id', p.id,
                'tenant_id', p.tenant_id,
                'product_code', p.product_code,
                'barcode', p.barcode,
                'name', p.name,
                'price_gbp', p.list_price_amount, -- compatibility mapping
                'list_price_amount', p.list_price_amount,
                'list_price_currency_id', p.list_price_currency_id,
                'reference_cost_amount', p.reference_cost_amount,
                'reference_cost_currency_id', p.reference_cost_currency_id,
                'country_of_origin', p.country_of_origin,
                'brand', p.brand,
                'category', p.category,
                'available_units', p.available_units,
                'tariff_code', p.tariff_code,
                'languages', p.languages,
                'batch_code_manufacture_date', p.batch_code_manufacture_date,
                'image_url', p.image_url,
                'expire_date', p.expire_date,
                'minimum_order_quantity', p.minimum_order_quantity,
                'product_weight', p.product_weight,
                'package_weight', p.package_weight,
                'is_available', p.is_available,
                'vendor_code', p.vendor_code,
                'market_code', p.market_code,
                'created_at', p.created_at,
                'updated_at', p.updated_at
              )
            end
          )
          order by ci.id
        )
        from public.cart_items ci
        left join public.products p
          on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.carts c
  where c.id = p_cart_id;

  if v_result is null then
    raise exception 'cart not found';
  end if;

  return v_result;
end;
$$;

-- 7. Redefine add_shipment_item_from_product to use new list_price_amount
create or replace function public.add_shipment_item_from_product(
  p_shipment_id bigint,
  p_product_id bigint,
  p_quantity integer
)
returns public.shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
  v_product record;
  v_quantity integer;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_quantity := coalesce(p_quantity, 0);
  if v_quantity <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  select
    p.id,
    p.name,
    p.barcode,
    p.product_code,
    p.image_url,
    p.product_weight,
    p.package_weight,
    coalesce(p.list_price_amount, 0) as price_gbp
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = v_tenant_id;

  if v_product.id is null then
    raise exception 'product not found';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp
  )
  values (
    p_shipment_id,
    v_product.name,
    v_quantity,
    v_product.barcode,
    v_product.product_code,
    v_product.id,
    v_product.image_url,
    v_product.product_weight,
    v_product.package_weight,
    v_product.price_gbp
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- Reload schema cache
do $$
begin
  perform pg_notify('pgrst', 'reload schema');
exception
  when others then
    null;
end;
$$;

commit;
