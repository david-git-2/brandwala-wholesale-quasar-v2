-- Cross-shop customer catalog search (shop header typeahead).
begin;

CREATE OR REPLACE FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  v_search := nullif(trim(coalesce(p_search, '')), '');
  v_limit := greatest(1, least(coalesce(p_limit, 20), 50));
  v_offset := greatest(0, coalesce(p_offset, 0));

  if v_search is null then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', 1,
        'page_size', v_limit,
        'total_pages', 1
      )
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  with accessible_shops as (
    select
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          else coalesce(access.see_price, profile.default_see_price, false)
        end
      ) as see_price
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and s.deleted_at is null
      and s.tenant_id = p_tenant_id
      and cg.id = public.current_customer_group_id(p_tenant_id)
      and cg.is_active = true
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
    group by
      s.id,
      s.slug,
      s.name,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage
  ),
  vendor_catalog_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case when s.see_price then p.list_price_amount else null end as unit_price_amount,
      case when s.see_price then p.list_price_currency_id else null end as unit_price_currency_id,
      case when s.see_price then gc.symbol else null end as unit_price_currency_symbol
    from accessible_shops s
    join public.products p on p.parent_tenant_id = v_parent_tenant_id
    left join public.global_currencies gc on gc.id = p.list_price_currency_id
    where s.shop_type = 'vendor_catalog'
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or (
          s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
            select 1
            from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
            where vf.vendor_code = p.vendor_code
              and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
          )
        )
      )
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  listing_rows as (
    select
      s.id as shop_id,
      s.slug as shop_slug,
      s.name as shop_name,
      p.id as product_id,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      case
        when not s.see_price then null
        when s.shop_type = 'fixed_price' and s.pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + s.markup_percentage / 100.0)
        when s.shop_type = 'fixed_price' and s.pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
        else l.sell_price_amount
      end as unit_price_amount,
      case when s.see_price then l.sell_price_currency_id else null end as unit_price_currency_id,
      case when s.see_price then gc.symbol else null end as unit_price_currency_symbol
    from accessible_shops s
    join public.shop_product_listings l on l.shop_id = s.id
    join public.products p on p.id = l.product_id
    join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
      and gship.assigned_child_tenant_id = s.tenant_id
    left join public.global_currencies gc on gc.id = l.sell_price_currency_id
    where s.shop_type <> 'vendor_catalog'
      and l.global_stock_id is not null
      and coalesce(gship.status, 'received') = 'received'
      and l.is_active = true
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and (
        p.name ilike ('%' || v_search || '%')
        or p.product_code ilike ('%' || v_search || '%')
        or p.barcode ilike ('%' || v_search || '%')
      )
  ),
  combined as (
    select * from vendor_catalog_rows
    union all
    select * from listing_rows
  ),
  ranked as (
    select
      c.*,
      row_number() over (
        partition by c.product_id
        order by c.shop_name asc, c.shop_id asc
      ) as row_num
    from combined c
  ),
  deduped as (
    select * from ranked where row_num = 1
  )
  select jsonb_build_object(
    'data',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'shop_id', d.shop_id,
            'shop_slug', d.shop_slug,
            'shop_name', d.shop_name,
            'product_id', d.product_id,
            'product_name', d.product_name,
            'product_image_url', d.product_image_url,
            'product_barcode', d.product_barcode,
            'product_code', d.product_code,
            'product_brand', d.product_brand,
            'product_category', d.product_category,
            'unit_price_amount', d.unit_price_amount,
            'unit_price_currency_id', d.unit_price_currency_id,
            'unit_price_currency_symbol', d.unit_price_currency_symbol
          )
          order by d.product_name asc, d.product_id asc
        )
        from (
          select *
          from deduped
          order by product_name asc, product_id asc
          limit v_limit
          offset v_offset
        ) d
      ),
      '[]'::jsonb
    ),
    'meta',
    jsonb_build_object(
      'total', (select count(*)::bigint from deduped),
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil((select count(*)::numeric from deduped) / v_limit::numeric))
    )
  )
  into v_result;

  return v_result;
end;
$$;


revoke all on function public.search_shop_catalog_for_customer(bigint, text, integer, integer) from public;
grant execute on function public.search_shop_catalog_for_customer(bigint, text, integer, integer) to authenticated;

commit;
