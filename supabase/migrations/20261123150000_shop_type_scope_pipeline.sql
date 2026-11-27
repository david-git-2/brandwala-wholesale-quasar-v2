-- Shop type scope: gate login and filter customer RPCs by shop_type

DROP FUNCTION IF EXISTS public.check_shop_login_access(text, bigint);
DROP FUNCTION IF EXISTS public.get_shop_bootstrap_context(text, bigint, bigint);
DROP FUNCTION IF EXISTS public.customer_accessible_catalog_glance(bigint, bigint);
DROP FUNCTION IF EXISTS public.get_customer_dashboard_summary(bigint);
DROP FUNCTION IF EXISTS public.list_customer_shop_orders(bigint, integer, integer, text);

CREATE OR REPLACE FUNCTION "public"."check_shop_login_access"("p_email" "text", "p_tenant_id" bigint DEFAULT NULL::bigint, "p_shop_type" "public"."shop_type_enum" DEFAULT NULL::"public"."shop_type_enum") RETURNS TABLE("has_match" boolean, "matched_role" "public"."customer_group_role", "member_id" bigint, "member_name" "text", "member_email" "text", "member_tenant_id" bigint, "customer_group_id" bigint, "customer_group_name" "text", "member_is_active" boolean, "customer_group_is_active" boolean, "member_created_at" timestamp with time zone, "member_updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email(), '')));

  return query
  select
    true,
    cgm.role,
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ),
    lower(trim(cgm.email)),
    cg.tenant_id,
    cg.id,
    cg.name,
    cgm.is_active,
    cg.is_active,
    cgm.created_at,
    cgm.updated_at
  from public.customer_group_members cgm
  inner join public.customer_groups cg
    on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and cg.deleted_at is null
    and (
      p_tenant_id is null
      or exists (
        select 1
        from public.shop_customer_group_access scga
        inner join public.shops s on s.id = scga.shop_id
        left join public.customer_group_shop_profiles profile
          on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
        where scga.customer_group_id = cg.id
          and scga.status = true
          and s.tenant_id = p_tenant_id
          and s.is_active = true
          and s.deleted_at is null
          and cg.tenant_id
            = public.resolve_books_tenant_id(p_tenant_id)
          and (p_shop_type is null or s.shop_type = p_shop_type)
          and coalesce(profile.is_active, true) = true
          and coalesce(scga.can_browse, profile.default_can_browse, false) = true
      )
    )
  order by
    cg.name asc,
    cg.id asc,
    case cgm.role
      when 'admin' then 1
      when 'manager' then 2
      when 'staff' then 3
      else 99
    end asc,
    cgm.id asc;
end;
$$;



CREATE OR REPLACE FUNCTION "public"."get_shop_bootstrap_context"("p_email" "text" DEFAULT NULL::"text", "p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_member_id" bigint DEFAULT NULL::bigint, "p_shop_type" "public"."shop_type_enum" DEFAULT NULL::"public"."shop_type_enum") RETURNS TABLE("member_id" bigint, "member_name" "text", "member_email" "text", "member_role" "public"."customer_group_role", "member_is_active" boolean, "customer_group_id" bigint, "customer_group_name" "text", "customer_group_is_active" boolean, "customer_group_accent_color" "text", "tenant_id" bigint, "tenant_name" "text", "tenant_slug" "text", "tenant_is_active" boolean, "active_module_keys" "text"[], "tenant_role_id" bigint, "is_admin" boolean, "effective_grants" "jsonb", "permission_version" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text;
  v_member record;
  v_grants jsonb;
  v_perm_version bigint;
begin
  v_email := lower(trim(coalesce(p_email, public.current_user_email())));

  if p_tenant_id is null or p_customer_group_member_id is null then
    return;
  end if;

  select
    cgm.id,
    coalesce(
      nullif(trim(cgm.name), ''),
      (select coalesce(u.raw_user_meta_data->>'full_name', u.raw_user_meta_data->>'name') from auth.users u where u.email = v_email limit 1)
    ) as name,
    lower(trim(cgm.email)) as email,
    cgm.role,
    cgm.is_active,
    cgm.tenant_role_id,
    cg.id as customer_group_id,
    cg.name as customer_group_name,
    cg.is_active as customer_group_is_active,
    cg.accent_color as customer_group_accent_color,
    t.id as tenant_id,
    t.name as tenant_name,
    t.slug as tenant_slug,
    t.is_active as tenant_is_active,
    coalesce(tr.is_admin, cgm.role = 'admin', false) as is_admin
  into v_member
  from public.customer_group_members cgm
  inner join public.customer_groups cg on cg.id = cgm.customer_group_id
  inner join public.tenants t on t.id = p_tenant_id
  left join public.tenant_roles tr on tr.id = cgm.tenant_role_id
  where p_tenant_id is not null
    and lower(trim(cgm.email)) = v_email
    and cgm.is_active = true
    and cg.is_active = true
    and cg.deleted_at is null
    and t.is_active = true
    and cgm.id = p_customer_group_member_id
    and cg.tenant_id = public.resolve_books_tenant_id(p_tenant_id)
    and exists (
      select 1
      from public.shop_customer_group_access scga
      inner join public.shops s on s.id = scga.shop_id
      left join public.customer_group_shop_profiles profile
        on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
      where scga.customer_group_id = cg.id
        and scga.status = true
        and s.tenant_id = p_tenant_id
        and s.is_active = true
        and s.deleted_at is null
        and (p_shop_type is null or s.shop_type = p_shop_type)
        and coalesce(profile.is_active, true) = true
        and coalesce(scga.can_browse, profile.default_can_browse, false) = true
    )
  order by
    case cgm.role
      when 'admin' then 1
      when 'manager' then 2
      when 'staff' then 3
      else 99
    end,
    cgm.id asc
  limit 1;

  if v_member.id is null then
    return;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('module_key', module_key, 'action', action)),
    '[]'::jsonb
  )
  into v_grants
  from public.get_shop_effective_grants(v_member.tenant_id, v_member.id);

  select tpv.version into v_perm_version
  from public.tenant_permission_versions tpv
  where tpv.tenant_id = v_member.tenant_id;

  if v_perm_version is null then
    perform public.bump_tenant_permission_version(v_member.tenant_id);
    v_perm_version := 1;
  end if;

  return query
  select
    v_member.id as member_id,
    v_member.name as member_name,
    v_member.email as member_email,
    v_member.role as member_role,
    v_member.is_active as member_is_active,
    v_member.customer_group_id,
    v_member.customer_group_name,
    v_member.customer_group_is_active,
    v_member.customer_group_accent_color,
    v_member.tenant_id,
    v_member.tenant_name,
    v_member.tenant_slug,
    v_member.tenant_is_active,
    coalesce(public.get_active_module_keys_for_tenant(v_member.tenant_id), array[]::text[]) as active_module_keys,
    v_member.tenant_role_id,
    v_member.is_admin,
    v_grants as effective_grants,
    v_perm_version as permission_version;
end;
$$;



CREATE OR REPLACE FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shop_type" "public"."shop_type_enum" DEFAULT NULL::"public"."shop_type_enum") RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  WITH accessible_shops AS (
    SELECT
      s.id,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters
    FROM public.shops s
    JOIN public.shop_customer_group_access access ON access.shop_id = s.id
    JOIN public.customer_groups cg ON cg.id = access.customer_group_id
    LEFT JOIN public.customer_group_shop_profiles profile
      ON profile.customer_group_id = cg.id AND profile.tenant_id = s.tenant_id
    WHERE s.is_active = true
      AND s.deleted_at IS NULL
      AND s.tenant_id = p_tenant_id
      AND cg.id = p_customer_group_id
      AND cg.is_active = true
      AND access.status = true
      AND coalesce(profile.is_active, true) = true
      AND coalesce(access.can_browse, profile.default_can_browse, false) = true
      AND (p_shop_type IS NULL OR s.shop_type = p_shop_type)
  ),
  parent_tenant AS (
    SELECT public.resolve_books_tenant_id(p_tenant_id) AS tenant_id
  ),
  vendor_catalog_products AS (
    SELECT DISTINCT
      p.id AS product_id,
      p.brand AS product_brand
    FROM accessible_shops s
    CROSS JOIN parent_tenant pt
    JOIN public.products p ON p.tenant_id = pt.tenant_id
    WHERE s.shop_type = 'vendor_catalog'::public.shop_type_enum
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
      AND (
        ((s.vendor_filters IS NULL OR jsonb_array_length(s.vendor_filters) = 0) AND p.vendor_code = s.vendor_code)
        OR (
          s.vendor_filters IS NOT NULL AND jsonb_array_length(s.vendor_filters) > 0 AND EXISTS (
            SELECT 1
            FROM jsonb_to_recordset(s.vendor_filters) AS vf(vendor_code text, brands text[])
            WHERE vf.vendor_code = p.vendor_code
              AND (vf.brands IS NULL OR array_length(vf.brands, 1) IS NULL OR p.brand = ANY(vf.brands))
          )
        )
      )
  ),
  listing_products AS (
    SELECT DISTINCT
      p.id AS product_id,
      p.brand AS product_brand
    FROM accessible_shops s
    JOIN public.shop_product_listings l ON l.shop_id = s.id
    JOIN public.products p ON p.id = l.product_id
    WHERE s.shop_type <> 'vendor_catalog'::public.shop_type_enum
      AND l.is_active = true
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
  ),
  combined AS (
    SELECT product_id, product_brand FROM vendor_catalog_products
    UNION
    SELECT product_id, product_brand FROM listing_products
  )
  SELECT jsonb_build_object(
    'total_products', coalesce((SELECT count(*)::bigint FROM combined), 0),
    'total_brands', coalesce((
      SELECT count(*)::bigint
      FROM (
        SELECT DISTINCT lower(trim(product_brand)) AS brand_key
        FROM combined
        WHERE product_brand IS NOT NULL
          AND trim(product_brand) <> ''
      ) brands
    ), 0)
  );
$$;



CREATE OR REPLACE FUNCTION "public"."get_customer_dashboard_summary"("p_tenant_id" bigint, "p_shop_type" "public"."shop_type_enum" DEFAULT NULL::"public"."shop_type_enum") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  v_catalog_glance := public.customer_accessible_catalog_glance(p_tenant_id, v_group_id, p_shop_type);

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
      and (p_shop_type is null or s.shop_type = p_shop_type)
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
    and o.status is distinct from 'draft'
    and (p_shop_type is null or o.shop_type_snapshot = p_shop_type);

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
      and (p_shop_type is null or o.shop_type_snapshot = p_shop_type)
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
      and (p_shop_type is null or s.shop_type = p_shop_type)
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
$$;



CREATE OR REPLACE FUNCTION "public"."list_customer_shop_orders"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_status_bucket" "text" DEFAULT NULL::"text", "p_shop_type" "public"."shop_type_enum" DEFAULT NULL::"public"."shop_type_enum") RETURNS TABLE("id" bigint, "shop_id" bigint, "shop_name" "text", "shop_slug" "text", "shop_type_snapshot" "public"."shop_type_enum", "is_negotiable_snapshot" boolean, "order_no" "text", "status" "public"."shop_order_status", "item_count" bigint, "can_see_buy_price" boolean, "can_see_sell_price" boolean, "sell_currency_id" bigint, "currency_symbol" "text", "total_amount" numeric, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_group_id bigint;
  v_limit integer;
  v_offset integer;
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN;
  END IF;

  IF p_status_bucket IS NOT NULL
     AND p_status_bucket NOT IN ('needs_you', 'in_progress', 'done') THEN
    RETURN;
  END IF;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  IF v_group_id IS NULL THEN
    RETURN;
  END IF;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  RETURN QUERY
  SELECT
    o.id,
    o.shop_id,
    s.name AS shop_name,
    s.slug AS shop_slug,
    o.shop_type_snapshot,
    o.is_negotiable_snapshot,
    o.order_no,
    o.status,
    (
      SELECT count(*)::bigint
      FROM public.shop_order_items soi
      WHERE soi.order_id = o.id
    ) AS item_count,
    CASE
      WHEN o.shop_type_snapshot = 'dropship' THEN true
      WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_buy_price_snapshot, false)
      ELSE coalesce(live_perm.can_see_buy_price, false)
    END AS can_see_buy_price,
    CASE
      WHEN o.shop_type_snapshot = 'dropship' THEN true
      WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_sell_price_snapshot, false)
      ELSE coalesce(live_perm.can_see_sell_price, false)
    END AS can_see_sell_price,
    s.sell_currency_id,
    gc.symbol AS currency_symbol,
    CASE
      WHEN (
        CASE
          WHEN o.shop_type_snapshot = 'dropship' THEN true
          WHEN o.cart_id IS NOT NULL THEN coalesce(c.can_see_sell_price_snapshot, false)
          ELSE coalesce(live_perm.can_see_sell_price, false)
        END
      ) THEN
        coalesce(
          (
            SELECT sum(
              coalesce(
                soi.final_price_amount,
                soi.customer_offer_amount,
                soi.unit_sell_price_amount,
                soi.unit_list_price_amount
              ) * soi.quantity
            )
            FROM public.shop_order_items soi
            WHERE soi.order_id = o.id
          ),
          0
        )::numeric
      ELSE NULL
    END AS total_amount,
    o.created_at
  FROM public.shop_orders o
  JOIN public.shops s ON s.id = o.shop_id
  LEFT JOIN public.shop_carts c ON c.id = o.cart_id
  LEFT JOIN LATERAL (
    SELECT p.can_see_buy_price, p.can_see_sell_price
    FROM public.get_shop_permissions_for_customer(o.shop_id) p
    LIMIT 1
  ) live_perm ON true
  LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
  WHERE o.tenant_id = p_tenant_id
    AND o.customer_group_id = v_group_id
    AND o.status IS DISTINCT FROM 'draft'
    AND (p_shop_type IS NULL OR o.shop_type_snapshot = p_shop_type)
    AND (
      p_status_bucket IS NULL
      OR public.customer_shop_order_glance_bucket(o.status) = p_status_bucket
    )
  ORDER BY o.created_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;



GRANT ALL ON FUNCTION "public"."canonicalize_dropship_order_wallet_source_ids"("p_order_id" bigint) TO "service_role";


REVOKE ALL ON FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shop_type" "public"."shop_type_enum") FROM PUBLIC;
GRANT ALL ON FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shop_type" "public"."shop_type_enum") TO "anon";
GRANT ALL ON FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shop_type" "public"."shop_type_enum") TO "authenticated";
GRANT ALL ON FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_shop_type" "public"."shop_type_enum") TO "service_role";
GRANT ALL ON FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) TO "service_role";






GRANT ALL ON FUNCTION "public"."list_customer_group_receipts"("p_tenant_id" bigint, "p_customer_group_id" bigint) TO "service_role";


