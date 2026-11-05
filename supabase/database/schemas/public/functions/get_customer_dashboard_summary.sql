CREATE FUNCTION public.get_customer_dashboard_summary (
  p_tenant_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_group_id bigint;
  v_shops jsonb := '[]'::jsonb;
  v_categories jsonb := '[]'::jsonb;
  v_recent_orders jsonb := '[]'::jsonb;
  v_active_carts jsonb := '[]'::jsonb;
  v_buckets jsonb;
  v_catalog_glance jsonb := jsonb_build_object('total_products', 0, 'total_brands', 0);
begin
  if p_tenant_id is null then
    return jsonb_build_object(
      'tenant_id', null,
      'customer_group_id', null,
      'shops', '[]'::jsonb,
      'categories', '[]'::jsonb,
      'catalog_glance', v_catalog_glance,
      'order_glance', jsonb_build_object(
        'buckets', jsonb_build_object('needs_you', 0, 'in_progress', 0, 'done', 0, 'total', 0),
        'segments', jsonb_build_object(
          'needs_you', 0,
          'in_progress', 0,
          'delivered', 0,
          'paid', 0,
          'payment_needed', 0,
          'total', 0
        )
      ),
      'recent_orders', '[]'::jsonb,
      'active_carts', '[]'::jsonb
    );
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    return jsonb_build_object(
      'tenant_id', p_tenant_id,
      'customer_group_id', null,
      'shops', '[]'::jsonb,
      'categories', '[]'::jsonb,
      'catalog_glance', v_catalog_glance,
      'order_glance', jsonb_build_object(
        'buckets', jsonb_build_object('needs_you', 0, 'in_progress', 0, 'done', 0, 'total', 0),
        'segments', jsonb_build_object(
          'needs_you', 0,
          'in_progress', 0,
          'delivered', 0,
          'paid', 0,
          'payment_needed', 0,
          'total', 0
        )
      ),
      'recent_orders', '[]'::jsonb,
      'active_carts', '[]'::jsonb
    );
  end if;

  v_catalog_glance := public.customer_accessible_catalog_glance(p_tenant_id, v_group_id);

  select coalesce(jsonb_agg(row_to_json(shop_row) order by shop_row.name), '[]'::jsonb)
  into v_shops
  from (
    select
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.order_mode,
      s.is_negotiable,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          else public.resolve_shop_can_see_buy_price(
            s.shop_type,
            access.can_see_buy_price,
            access.can_see_sell_price,
            profile.default_can_see_buy_price,
            profile.default_can_see_sell_price
          )
        end
      ) as can_see_buy_price,
      bool_or(
        case
          when access.status = false or coalesce(profile.is_active, true) = false then false
          when s.shop_type = 'dropship' then true
          else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      ) as can_see_sell_price,
      s.description,
      s.category_ids,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', c.id,
              'name', c.name,
              'slug', c.slug,
              'icon', c.icon
            )
            order by c.name
          )
          from public.shop_categories c
          where c.id = any(s.category_ids)
            and c.is_active = true
        ),
        '[]'::jsonb
      ) as categories,
      s.sell_currency_id,
      gc.code as sell_currency_code,
      gc.symbol as sell_currency_symbol
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    left join public.global_currencies gc on gc.id = s.sell_currency_id
    where s.is_active = true
      and s.deleted_at is null
      and s.tenant_id = p_tenant_id
      and cg.id = v_group_id
      and cg.is_active = true
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
    group by
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.order_mode,
      s.is_negotiable,
      s.description,
      s.category_ids,
      s.sell_currency_id,
      gc.code,
      gc.symbol
  ) shop_row;

  select coalesce(jsonb_agg(cat order by cat ->> 'name'), '[]'::jsonb)
  into v_categories
  from (
    select distinct on ((cat ->> 'id')::bigint) cat
    from (
      select jsonb_array_elements(coalesce(shop_elem -> 'categories', '[]'::jsonb)) as cat
      from jsonb_array_elements(v_shops) shop_elem
    ) cats
    order by (cat ->> 'id')::bigint
  ) deduped;

  select jsonb_build_object(
    'buckets', jsonb_build_object(
      'needs_you', coalesce(count(*) filter (
        where public.customer_shop_order_glance_bucket(o.status) = 'needs_you'
      ), 0),
      'in_progress', coalesce(count(*) filter (
        where public.customer_shop_order_glance_bucket(o.status) = 'in_progress'
      ), 0),
      'done', coalesce(count(*) filter (
        where public.customer_shop_order_glance_bucket(o.status) = 'done'
      ), 0),
      'total', coalesce(count(*) filter (where o.status is distinct from 'draft'), 0)
    ),
    'segments', jsonb_build_object(
      'needs_you', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'needs_you'
      ), 0),
      'in_progress', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'in_progress'
      ), 0),
      'delivered', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'delivered'
      ), 0),
      'paid', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'paid'
      ), 0),
      'payment_needed', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) = 'payment_needed'
      ), 0),
      'total', coalesce(count(*) filter (
        where public.customer_shop_order_glance_segment(o.status) is not null
      ), 0)
    )
  )
  into v_buckets
  from public.shop_orders o
  where o.tenant_id = p_tenant_id
    and o.customer_group_id = v_group_id
    and o.status is distinct from 'draft';

  select coalesce(jsonb_agg(row_to_json(order_row) order by order_row.created_at desc), '[]'::jsonb)
  into v_recent_orders
  from (
    select
      o.id,
      o.shop_id,
      s.name as shop_name,
      s.slug as shop_slug,
      o.order_no,
      o.status,
      gc.symbol as currency_symbol,
      o.created_at
    from public.shop_orders o
    join public.shops s on s.id = o.shop_id
    left join public.global_currencies gc on gc.id = s.sell_currency_id
    where o.tenant_id = p_tenant_id
      and o.customer_group_id = v_group_id
      and o.status is distinct from 'draft'
    order by o.created_at desc
    limit 5
  ) order_row;

  select coalesce(jsonb_agg(row_to_json(cart_row) order by cart_row.updated_at desc), '[]'::jsonb)
  into v_active_carts
  from (
    select
      c.id as cart_id,
      s.id as shop_id,
      s.name as shop_name,
      s.slug as shop_slug,
      null::text as shop_logo_url,
      s.shop_type::text as shop_type,
      c.can_see_buy_price_snapshot as can_see_buy_price,
      c.can_see_sell_price_snapshot as can_see_sell_price,
      s.sell_currency_id as currency_id,
      gc.code as currency_code,
      gc.symbol as currency_symbol,
      coalesce(sum(ci.quantity), 0)::bigint as item_count,
      case
        when c.can_see_sell_price_snapshot then
          sum(
            ci.quantity * coalesce(
              ci.customer_sell_price_amount,
              ci.unit_sell_price_amount,
              ci.unit_list_price_amount,
              0
            )
          )::numeric
        else null
      end as cart_total,
      c.updated_at
    from public.shop_carts c
    join public.shops s on s.id = c.shop_id
    join public.shop_cart_items ci on ci.cart_id = c.id
    left join public.global_currencies gc on gc.id = s.sell_currency_id
    where c.status = 'active'
      and c.tenant_id = p_tenant_id
      and c.customer_group_id = v_group_id
    group by c.id, s.id, gc.code, gc.symbol
  ) cart_row;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'customer_group_id', v_group_id,
    'shops', v_shops,
    'categories', v_categories,
    'catalog_glance', v_catalog_glance,
    'order_glance', v_buckets,
    'recent_orders', v_recent_orders,
    'active_carts', v_active_carts
  );
end;
$function$;

GRANT ALL ON FUNCTION public.get_customer_dashboard_summary(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_customer_dashboard_summary(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_customer_dashboard_summary(bigint) TO service_role;