create or replace function public.list_store_products_inventory_aggregated(
  p_store_id bigint,
  p_fields text[] default null,
  p_search text default null,
  p_category text default null,
  p_brand text default null,
  p_is_available boolean default null,
  p_sort_by text default 'id',
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
  v_tenant_id bigint;
  v_vendor_code text;
  v_sort_by text;
  v_sort_dir text;
  v_limit integer;
  v_offset integer;
  v_has_internal_access boolean;
  v_has_customer_access boolean;
  v_can_see_price boolean;
  v_allowed_fields text[] := array[
    'id',
    'tenant_id',
    'product_code',
    'barcode',
    'name',
    'price_gbp',
    'country_of_origin',
    'brand',
    'category',
    'available_units',
    'tariff_code',
    'languages',
    'batch_code_manufacture_date',
    'image_url',
    'expire_date',
    'minimum_order_quantity',
    'product_weight',
    'package_weight',
    'is_available',
    'created_at',
    'updated_at',
    'vendor_code',
    'market_code'
  ];
  v_selected_fields text[];
  v_result jsonb;
begin
  select s.tenant_id, s.vendor_code
  into v_tenant_id, v_vendor_code
  from public.stores s
  where s.id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.tenant_id = v_tenant_id
      and m.role in ('admin', 'staff')
  ) into v_has_internal_access;

  v_has_customer_access := public.can_customer_access_store(p_store_id);

  if not v_has_internal_access and not v_has_customer_access then
    raise exception 'not allowed';
  end if;

  v_can_see_price := v_has_internal_access or public.can_customer_see_store_price(p_store_id);

  v_sort_by := lower(trim(coalesce(p_sort_by, 'id')));
  if not (v_sort_by = any (array[
    'id',
    'name',
    'product_code',
    'barcode',
    'brand',
    'category',
    'price_gbp',
    'available_units',
    'created_at',
    'updated_at'
  ])) then
    v_sort_by := 'id';
  end if;

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select coalesce(array_agg(distinct field_name), '{}'::text[])
  into v_selected_fields
  from unnest(coalesce(p_fields, v_allowed_fields)) as field_name
  where field_name = any (v_allowed_fields);

  if coalesce(array_length(v_selected_fields, 1), 0) = 0 then
    v_selected_fields := array['id', 'name', 'vendor_code', 'brand', 'category', 'available_units'];
  end if;

  if not v_can_see_price then
    select coalesce(array_agg(field_name), '{}'::text[])
    into v_selected_fields
    from unnest(v_selected_fields) as field_name
    where field_name <> 'price_gbp';
  end if;

  execute format(
    $sql$
      with inventory_base as (
        select
          p.id,
          p.tenant_id,
          p.product_code,
          p.barcode,
          p.name,
          p.price_gbp,
          p.country_of_origin,
          p.brand,
          p.category,
          p.tariff_code,
          p.languages,
          p.batch_code_manufacture_date,
          p.image_url,
          p.expire_date,
          p.minimum_order_quantity,
          p.product_weight,
          p.package_weight,
          p.is_available as product_is_available,
          p.created_at,
          p.updated_at,
          p.vendor_code,
          p.market_code,
          greatest(
            0,
            coalesce(st.available_quantity, 0)
            - coalesce(st.reserved_quantity, 0)
            - coalesce(st.damaged_quantity, 0)
            - coalesce(st.stolen_quantity, 0)
            - coalesce(st.expired_quantity, 0)
            - coalesce(st.open_box_quantity, 0)
          )::numeric as usable_quantity
        from public.inventory_items ii
        join public.products p
          on p.id = ii.product_id
         and p.tenant_id = $1
         and p.vendor_code = $2
        left join public.inventory_stocks st
          on st.inventory_item_id = ii.id
        where ii.tenant_id = $1
          and ii.product_id is not null
          and ii.status = 'active'
      ),
      aggregated as (
        select
          id,
          max(tenant_id) as tenant_id,
          max(product_code) as product_code,
          max(barcode) as barcode,
          max(name) as name,
          max(price_gbp) as price_gbp,
          max(country_of_origin) as country_of_origin,
          max(brand) as brand,
          max(category) as category,
          sum(usable_quantity)::int as available_units,
          max(tariff_code) as tariff_code,
          max(languages) as languages,
          max(batch_code_manufacture_date) as batch_code_manufacture_date,
          max(image_url) as image_url,
          max(expire_date) as expire_date,
          max(minimum_order_quantity) as minimum_order_quantity,
          max(product_weight) as product_weight,
          max(package_weight) as package_weight,
          bool_or(product_is_available) and sum(usable_quantity) > 0 as is_available,
          max(created_at) as created_at,
          max(updated_at) as updated_at,
          max(vendor_code) as vendor_code,
          max(market_code) as market_code
        from inventory_base
        group by id
      ),
      filtered as (
        select a.*
        from aggregated a
        where (
            $3 is null
            or trim($3) = ''
            or a.name ilike ('%%' || trim($3) || '%%')
            or a.product_code ilike ('%%' || trim($3) || '%%')
            or a.barcode ilike ('%%' || trim($3) || '%%')
          )
          and (
            $4 is null
            or trim($4) = ''
            or lower(coalesce(a.category, '')) = lower(trim($4))
          )
          and (
            $5 is null
            or trim($5) = ''
            or lower(coalesce(a.brand, '')) = lower(trim($5))
          )
          and (
            $6 is null
            or a.is_available is not distinct from $6
          )
      ),
      paged as (
        select f.*
        from filtered f
        order by %I %s nulls last, f.id asc
        limit $8
        offset $9
      )
      select jsonb_build_object(
        'data',
        coalesce(
          (
            select jsonb_agg(
              (
                select jsonb_object_agg(field_name, to_jsonb(p) -> field_name)
                from unnest($7::text[]) as field_name
              )
            )
            from paged p
          ),
          '[]'::jsonb
        ),
        'meta',
        jsonb_build_object(
          'store_id', $10,
          'limit', $8,
          'offset', $9,
          'current_page', (($9 / $8) + 1),
          'sort_by', $11,
          'sort_dir', $12,
          'total', (select count(*) from filtered),
          'can_see_price', $13
        )
      )
    $sql$,
    v_sort_by,
    v_sort_dir
  )
  into v_result
  using
    v_tenant_id,
    v_vendor_code,
    p_search,
    p_category,
    p_brand,
    p_is_available,
    v_selected_fields,
    v_limit,
    v_offset,
    p_store_id,
    v_sort_by,
    v_sort_dir,
    v_can_see_price;

  return coalesce(
    v_result,
    jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'store_id', p_store_id,
        'limit', v_limit,
        'offset', v_offset,
        'current_page', ((v_offset / v_limit) + 1),
        'sort_by', v_sort_by,
        'sort_dir', v_sort_dir,
        'total', 0,
        'can_see_price', v_can_see_price
      )
    )
  );
end;
$$;

grant execute on function public.list_store_products_inventory_aggregated(
  bigint,
  text[],
  text,
  text,
  text,
  boolean,
  text,
  text,
  integer,
  integer
)
to authenticated;
