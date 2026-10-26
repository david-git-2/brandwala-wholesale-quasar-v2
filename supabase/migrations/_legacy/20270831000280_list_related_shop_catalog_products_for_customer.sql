-- Category-based related products for vendor_catalog shop product detail page.

CREATE OR REPLACE FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer DEFAULT 4) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_is_active boolean;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_see_price boolean;
  v_category text;
  v_limit integer;
  v_data jsonb;
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
    id, tenant_id, shop_type, vendor_code, is_active, vendor_filters
  into
    v_shop_id, v_shop_tenant_id, v_shop_type, v_vendor_code, v_is_active, v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select can_browse
  into v_can_browse
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  if v_shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);
  v_limit := greatest(1, least(coalesce(p_limit, 4), 12));

  select see_price
  into v_see_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  select p.category
  into v_category
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

  if v_category is null or trim(v_category) = '' or left(trim(v_category), 1) = '=' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object('category', null)
    );
  end if;

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'product_id', rel.id,
          'product_name', rel.name,
          'product_image_url', rel.image_url,
          'product_barcode', rel.barcode,
          'product_code', rel.product_code,
          'product_brand', rel.brand,
          'product_category', rel.category,
          'vendor_code', rel.vendor_code,
          'is_available', rel.is_available,
          'unit_price_amount', case when v_see_price then rel.list_price_amount else null end,
          'unit_price_currency_id', case when v_see_price then rel.list_price_currency_id else null end,
          'unit_price_currency_code', case when v_see_price then (select code from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'unit_price_currency_symbol', case when v_see_price then (select symbol from public.global_currencies where id = rel.list_price_currency_id) else null end,
          'minimum_sell_price_amount', null,
          'minimum_sell_price_currency_id', null,
          'minimum_sell_price_currency_code', null,
          'minimum_sell_price_currency_symbol', null,
          'available_units', null,
          'global_stock_allocation_id', null,
          'global_stock_id', null,
          'minimum_order_quantity', rel.minimum_order_quantity
        )
        order by rel.name asc, rel.id asc
      )
      from (
        select p.*
        from public.products p
        where p.is_available = true
          and coalesce(p.hazardous, false) = false
          and p.parent_tenant_id = v_parent_tenant_id
          and p.id <> p_product_id
          and lower(coalesce(p.category, '')) = lower(trim(v_category))
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
        order by p.name asc, p.id asc
        limit v_limit
      ) rel
    ),
    '[]'::jsonb
  )
  into v_data;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object('category', trim(v_category))
  );
end;
$$;

revoke all on function public.list_related_shop_catalog_products_for_customer(bigint, text, bigint, integer) from public;
grant execute on function public.list_related_shop_catalog_products_for_customer(bigint, text, bigint, integer) to authenticated;
