-- Admin vendor_catalog storefront preview: server-side vendor/min-units filter + pagination.

create or replace function public.browse_shop_catalog_for_admin(
  p_tenant_id bigint,
  p_shop_id bigint,
  p_search text default null,
  p_limit integer default 24,
  p_offset integer default 0,
  p_include_below_min_units boolean default false
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_shop record;
  v_parent_tenant_id bigint;
  v_limit integer;
  v_offset integer;
  v_min_units integer;
  v_result jsonb;
begin
  if p_tenant_id is null or p_shop_id is null then
    raise exception 'tenant and shop are required';
  end if;

  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  select
    id,
    tenant_id,
    shop_type,
    vendor_code,
    vendor_filters,
    min_available_units
  into v_shop
  from public.shops
  where id = p_shop_id
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop.id is null then
    raise exception 'shop not found';
  end if;

  if v_shop.shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', 1,
        'page_size', greatest(1, least(coalesce(p_limit, 24), 200)),
        'total_pages', 1
      )
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop.tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 24), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));
  v_min_units := case
    when coalesce(p_include_below_min_units, false) then 0
    else coalesce(v_shop.min_available_units, 0)
  end;

  with filtered as (
    select p.*
    from public.products p
    where p.is_available = true
      and coalesce(p.hazardous, false) = false
      and p.parent_tenant_id = v_parent_tenant_id
      and (
        ((v_shop.vendor_filters is null or jsonb_array_length(v_shop.vendor_filters) = 0)
          and p.vendor_code = v_shop.vendor_code)
        or (
          v_shop.vendor_filters is not null
          and jsonb_array_length(v_shop.vendor_filters) > 0
          and exists (
            select 1
            from jsonb_to_recordset(v_shop.vendor_filters) as vf(vendor_code text, brands text[])
            where vf.vendor_code = p.vendor_code
              and (
                vf.brands is null
                or array_length(vf.brands, 1) is null
                or p.brand = any(vf.brands)
              )
          )
        )
      )
      and (
        p_search is null
        or trim(p_search) = ''
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
      )
      and (v_min_units = 0 or coalesce(p.available_units, 0) >= v_min_units)
  ),
  paged as (
    select f.*
    from filtered f
    order by f.name asc, f.id asc
    limit v_limit
    offset v_offset
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
            'product_brand', p.brand,
            'vendor_code', p.vendor_code,
            'country_of_origin', p.country_of_origin,
            'batch_code_manufacture_date', p.batch_code_manufacture_date,
            'expire_date', p.expire_date,
            'languages', p.languages,
            'available_units', p.available_units,
            'unit_price_amount', p.list_price_amount,
            'unit_price_currency_id', p.list_price_currency_id,
            'unit_price_currency_code', (
              select code from public.global_currencies where id = p.list_price_currency_id
            ),
            'unit_price_currency_symbol', (
              select symbol from public.global_currencies where id = p.list_price_currency_id
            )
          )
          order by p.name asc, p.id asc
        )
        from paged p
      ),
      '[]'::jsonb
    ),
    'meta',
    jsonb_build_object(
      'total', (select count(*) from filtered),
      'page', ((v_offset / v_limit) + 1),
      'page_size', v_limit,
      'total_pages', greatest(1, ceil((select count(*)::numeric from filtered) / v_limit::numeric))
    )
  )
  into v_result;

  return v_result;
end;
$$;

grant execute on function public.browse_shop_catalog_for_admin(
  bigint, bigint, text, integer, integer, boolean
) to authenticated;
