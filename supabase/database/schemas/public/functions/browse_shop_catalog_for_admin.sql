CREATE FUNCTION public.browse_shop_catalog_for_admin (
  p_tenant_id               bigint,
  p_shop_id                 bigint,
  p_search                  text    DEFAULT NULL::text,
  p_limit                   integer DEFAULT 24,
  p_cursor_name             text    DEFAULT NULL::text,
  p_cursor_id               bigint  DEFAULT NULL::bigint,
  p_include_below_min_units boolean DEFAULT false
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop record;
  v_parent_tenant_id bigint;
  v_limit integer;
  v_fetch_limit integer;
  v_min_units integer;
  v_result jsonb;
  v_data jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_cursor_name text;
  v_last_name text;
  v_last_id bigint;
begin
  if p_tenant_id is null or p_shop_id is null then
    raise exception 'tenant and shop are required';
  end if;

  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
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
    and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id)
    and deleted_at is null;

  if v_shop.id is null then
    raise exception 'shop not found';
  end if;

  if v_shop.shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'has_more', false,
        'next_cursor', null,
        'limit', greatest(1, least(coalesce(p_limit, 24), 200))
      )
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop.tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 24), 200));
  v_fetch_limit := v_limit + 1;
  v_cursor_name := coalesce(p_cursor_name, '');
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
      and (
        p_cursor_id is null
        or (coalesce(p.name, ''), p.id) > (v_cursor_name, p_cursor_id)
      )
  ),
  paged as (
    select f.*
    from filtered f
    order by f.name asc, f.id asc
    limit v_fetch_limit
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
    'meta', jsonb_build_object('limit', v_limit)
  )
  into v_result;

  v_data := coalesce(v_result->'data', '[]'::jsonb);
  v_n := jsonb_array_length(v_data);
  if v_n > v_limit then
    v_has_more := true;
    select
      coalesce(t.elem->>'product_name', ''),
      (t.elem->>'product_id')::bigint
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
    jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'limit', v_limit
    )
  );

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.browse_shop_catalog_for_admin(bigint, bigint, text, integer, text, bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.browse_shop_catalog_for_admin(bigint, bigint, text, integer, text, bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.browse_shop_catalog_for_admin(bigint, bigint, text, integer, text, bigint, boolean) TO service_role;