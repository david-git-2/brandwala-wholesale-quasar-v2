-- Phase 7: remaining RPC args — drop p_parent_tenant_id / p_parent_tenant_ids (columns unchanged).

DROP FUNCTION IF EXISTS public.list_shops(bigint, bigint, integer, integer, text, boolean);
DROP FUNCTION IF EXISTS public.list_shops_app_page(bigint, bigint, integer, integer, text, boolean, bigint);
DROP FUNCTION IF EXISTS public.list_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, bigint);
DROP FUNCTION IF EXISTS public.list_shop_orders_staff_page(bigint, bigint, integer, text, text, bigint, text, timestamp with time zone, bigint);
DROP FUNCTION IF EXISTS public.list_dropship_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, text[]);
DROP FUNCTION IF EXISTS public.get_app_dashboard_bundle(bigint, bigint[]);
DROP FUNCTION IF EXISTS public.list_child_tenant_refs(bigint[]);
DROP FUNCTION IF EXISTS public.list_catalog_refresh_log(bigint, integer);
DROP FUNCTION IF EXISTS public.notification_inbox_scope_matches(bigint, bigint, bigint);
DROP FUNCTION IF EXISTS public.list_child_tenant_ids(bigint);
DROP FUNCTION IF EXISTS public.can_manage_products_for_parent(bigint) CASCADE;
DROP FUNCTION IF EXISTS public.can_view_products_for_parent(bigint) CASCADE;
DROP FUNCTION IF EXISTS public.user_can_manage_parent_tenant(bigint) CASCADE;
DROP FUNCTION IF EXISTS public.get_parent_cash_circulation(bigint);
DROP FUNCTION IF EXISTS public.parent_tenant_has_module_action(bigint, text, text);
DROP FUNCTION IF EXISTS public.preview_tenant_data_purge(bigint, text, bigint);
DROP FUNCTION IF EXISTS public.purge_tenant_operational_data(bigint, text, text, bigint);
DROP FUNCTION IF EXISTS public.transfer_network_owner(bigint, text);
DROP FUNCTION IF EXISTS public.upsert_profile_for_party(bigint, public.profile_party_type, bigint, text, text, text, text, text, boolean, text, boolean, timestamp with time zone);
DROP FUNCTION IF EXISTS public.resolve_notification_recipient_user_ids(bigint, bigint, public.notification_audience, uuid[], text, text);


-- list_shops

CREATE OR REPLACE FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_limit" integer DEFAULT 200, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_active" boolean DEFAULT NULL::boolean) RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "slug" "text", "shop_type" "public"."shop_type_enum", "vendor_code" "text", "order_mode" "public"."shop_order_mode_enum", "is_negotiable" boolean, "show_stock_quantity" boolean, "default_currency_id" bigint, "global_stock_type_id" bigint, "is_active" boolean, "allow_delivery" boolean, "buy_currency_id" bigint, "sell_currency_id" bigint, "pricing_method" "text", "markup_percentage" numeric, "quantity_display_mode" "text", "display_quantity_add" integer, "default_print_charge_amount" numeric, "default_packing_charge_amount" numeric, "deduct_charges_from_margin" boolean, "vendor_filters" "jsonb", "deduct_print_from_margin" boolean, "deduct_packing_from_margin" boolean, "description" "text", "category_ids" bigint[], "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "total_count" bigint, "tenant_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total bigint;
begin
  if not exists (
    select 1 from public.memberships m
    where (m.tenant_id = p_tenant_id or m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total
  from public.shops s
  left join public.tenants t on t.id = s.tenant_id
  where s.tenant_id = p_tenant_id
    and s.deleted_at is null
    and (p_active is null or s.is_active = p_active)
    and (
      p_search is null
      or s.name ilike '%' || p_search || '%'
      or s.slug ilike '%' || p_search || '%'
      or t.name ilike '%' || p_search || '%'
    );

  return query
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.vendor_code,
    s.order_mode,
    s.is_negotiable,
    s.show_stock_quantity,
    s.default_currency_id,
    s.global_stock_type_id,
    s.is_active,
    s.allow_delivery,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode,
    s.display_quantity_add,
    s.default_print_charge_amount,
    s.default_packing_charge_amount,
    s.deduct_charges_from_margin,
    s.vendor_filters,
    s.deduct_print_from_margin,
    s.deduct_packing_from_margin,
    s.description,
    s.category_ids,
    s.created_at,
    s.updated_at,
    v_total,
    coalesce(t.name, '')::text as tenant_name
  from public.shops s
  left join public.tenants t on t.id = s.tenant_id
  where s.tenant_id = p_tenant_id
    and s.deleted_at is null
    and (p_active is null or s.is_active = p_active)
    and (
      p_search is null
      or s.name ilike '%' || p_search || '%'
      or s.slug ilike '%' || p_search || '%'
      or t.name ilike '%' || p_search || '%'
    );
end;
$$;


ALTER FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean) OWNER TO "postgres";

-- list_shops_app_page

CREATE OR REPLACE FUNCTION "public"."list_shops_app_page"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_active" boolean DEFAULT NULL::boolean, "p_catalog_tenant_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_total bigint;
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 200));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_shops jsonb := '[]'::jsonb;
  v_catalog jsonb := '[]'::jsonb;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  SELECT count(*)
  INTO v_total
  FROM public.shops s
  LEFT JOIN public.tenants t ON t.id = s.tenant_id
  WHERE s.tenant_id = p_tenant_id
    AND s.deleted_at IS NULL
    AND (p_active IS NULL OR s.is_active = p_active)
    AND (
      p_search IS NULL
      OR s.name ILIKE '%' || p_search || '%'
      OR s.slug ILIKE '%' || p_search || '%'
      OR t.name ILIKE '%' || p_search || '%'
    );

  SELECT coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
  INTO v_shops
  FROM (
    SELECT
      s.id,
      s.tenant_id,
      s.name,
      s.slug,
      s.shop_type,
      s.vendor_code,
      s.order_mode,
      s.is_negotiable,
      s.show_stock_quantity,
      s.default_currency_id,
      s.global_stock_type_id,
      s.is_active,
      s.allow_delivery,
      s.buy_currency_id,
      s.sell_currency_id,
      s.pricing_method,
      s.markup_percentage,
      s.quantity_display_mode,
      s.display_quantity_add,
      s.default_print_charge_amount,
      s.default_packing_charge_amount,
      s.deduct_charges_from_margin,
      s.vendor_filters,
      s.deduct_print_from_margin,
      s.deduct_packing_from_margin,
      s.description,
      s.category_ids,
      s.created_at,
      s.updated_at,
      v_total AS total_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shops s
    LEFT JOIN public.tenants t ON t.id = s.tenant_id
    WHERE s.tenant_id = p_tenant_id
      AND s.deleted_at IS NULL
      AND (p_active IS NULL OR s.is_active = p_active)
      AND (
        p_search IS NULL
        OR s.name ILIKE '%' || p_search || '%'
        OR s.slug ILIKE '%' || p_search || '%'
        OR t.name ILIKE '%' || p_search || '%'
      )
    ORDER BY s.name
    LIMIT v_limit
    OFFSET v_offset
  ) x;

  IF v_offset = 0
    AND p_catalog_tenant_id IS NOT NULL
    AND public.can_view_products_for_parent(p_catalog_tenant_id)
  THEN
    SELECT coalesce(jsonb_agg(to_jsonb(l)), '[]'::jsonb)
    INTO v_catalog
    FROM (
      SELECT
        l.id,
        l.parent_tenant_id,
        l.source,
        l.event_kind,
        l.source_url,
        l.file_name,
        l.ran_at,
        l.products_updated,
        l.duration_seconds
      FROM public.catalog_refresh_log l
      WHERE l.parent_tenant_id = p_catalog_tenant_id
      ORDER BY l.ran_at DESC
      LIMIT 200
    ) l;
  END IF;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'total_count', v_total,
    'catalog_refresh_log', v_catalog
  );
END;
$$;


ALTER FUNCTION "public"."list_shops_app_page"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean, "p_catalog_tenant_id" bigint) OWNER TO "postgres";

-- list_shop_orders_for_staff

CREATE OR REPLACE FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_shop_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "shop_id" bigint, "shop_name" "text", "customer_group_id" bigint, "customer_group_name" "text", "order_no" "text", "name" "text", "shop_type_snapshot" "public"."shop_type_enum", "is_negotiable_snapshot" boolean, "status" "public"."shop_order_status", "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "item_count" bigint, "tenant_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    s.name as shop_name,
    o.customer_group_id,
    cg.name as customer_group_name,
    o.order_no,
    o.name,
    o.shop_type_snapshot,
    o.is_negotiable_snapshot,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count,
    coalesce(t.name, '')::text as tenant_name
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.tenants t on t.id = o.tenant_id
  where o.tenant_id = p_tenant_id
    and (p_status is null or o.status::text = p_status)
    and (p_shop_id is null or o.shop_id = p_shop_id)
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.name ilike ('%' || p_search || '%')
      or s.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or t.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;


ALTER FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) OWNER TO "postgres";

-- list_shop_orders_staff_page

CREATE OR REPLACE FUNCTION "public"."list_shop_orders_staff_page"("p_tenant_id" bigint, "p_limit" integer DEFAULT 30, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_shop_id" bigint DEFAULT NULL::bigint, "p_shop_type" "text" DEFAULT NULL::"text", "p_cursor_created_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 100));
  v_fetch integer := v_limit + 1;
  v_shops jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF p_cursor_created_at IS NULL AND p_cursor_id IS NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    ) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
    INTO v_shops
    FROM (
      SELECT
        s.id,
        s.tenant_id,
        s.name,
        s.slug,
        s.shop_type,
        coalesce(t.name, '')::text AS tenant_name
      FROM public.shops s
      LEFT JOIN public.tenants t ON t.id = s.tenant_id
      WHERE s.tenant_id = p_tenant_id
        AND s.deleted_at IS NULL
      ORDER BY s.name
      LIMIT 500
    ) x;
  END IF;

  WITH base AS (
    SELECT
      o.id,
      o.tenant_id,
      o.shop_id,
      s.name AS shop_name,
      o.customer_group_id,
      cg.name AS customer_group_name,
      o.order_no,
      o.name,
      o.shop_type_snapshot,
      o.is_negotiable_snapshot,
      o.status,
      o.created_at,
      o.updated_at,
      (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.tenants t ON t.id = o.tenant_id
    WHERE o.tenant_id = p_tenant_id
      AND (p_status IS NULL OR o.status::text = p_status)
      AND (p_shop_id IS NULL OR o.shop_id = p_shop_id)
      AND (p_shop_type IS NULL OR s.shop_type::text = p_shop_type)
      AND (
        p_search IS NULL
        OR o.order_no ILIKE ('%' || p_search || '%')
        OR o.name ILIKE ('%' || p_search || '%')
        OR s.name ILIKE ('%' || p_search || '%')
        OR cg.name ILIKE ('%' || p_search || '%')
        OR t.name ILIKE ('%' || p_search || '%')
      )
      AND (
        p_cursor_created_at IS NULL
        OR (o.created_at, o.id) < (p_cursor_created_at, p_cursor_id)
      )
    ORDER BY o.created_at DESC, o.id DESC
    LIMIT v_fetch
  ),
  page AS (
    SELECT * FROM base ORDER BY created_at DESC, id DESC LIMIT v_limit
  ),
  tail AS (
    SELECT created_at, id FROM page ORDER BY created_at ASC, id ASC LIMIT 1
  )
  SELECT
    coalesce(
      (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC, p.id DESC) FROM page p),
      '[]'::jsonb
    ),
    (SELECT count(*) > v_limit FROM base),
    CASE
      WHEN (SELECT count(*) FROM base) > v_limit THEN
        (SELECT jsonb_build_object('created_at', created_at, 'id', id) FROM tail)
      ELSE NULL
    END
  INTO v_orders, v_has_more, v_next_cursor;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'orders', v_orders,
    'meta', jsonb_build_object(
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$$;


ALTER FUNCTION "public"."list_shop_orders_staff_page"("p_tenant_id" bigint, "p_limit" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint, "p_shop_type" "text", "p_cursor_created_at" timestamp with time zone, "p_cursor_id" bigint) OWNER TO "postgres";

-- list_dropship_shop_orders_for_staff

CREATE OR REPLACE FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_offset" integer DEFAULT 0, "p_status" "text" DEFAULT NULL::"text", "p_search" "text" DEFAULT NULL::"text", "p_statuses" "text"[] DEFAULT NULL::"text"[]) RETURNS TABLE("id" bigint, "order_no" "text", "status" "public"."shop_order_status", "created_at" timestamp with time zone, "customer_group_name" "text", "created_by_email" "text", "recipient_name" "text", "recipient_phone" "text", "courier_name" "text", "courier_awb_number" "text", "cod_collect_amount" numeric, "total_amount" numeric, "global_invoice_id" bigint, "courier_remittance_ref" "text", "collection_source" "public"."collection_source_type", "payout_settlement_status" "text", "tenant_id" bigint, "tenant_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    o.id,
    o.order_no,
    o.status,
    o.created_at,
    cg.name as customer_group_name,
    o.created_by_email,
    o.recipient_name,
    o.recipient_phone,
    coalesce(cs.name, o.courier_name) as courier_name,
    o.courier_awb_number,
    o.cod_collect_amount,
    coalesce(
      (
        select sum(
          coalesce(
            final_price_amount,
            staff_offer_amount,
            customer_offer_amount,
            unit_sell_price_amount,
            unit_list_price_amount
          ) * quantity
        )
        from public.shop_order_items
        where order_id = o.id
      ),
      0
    )::numeric as total_amount,
    o.global_invoice_id,
    o.courier_remittance_ref,
    o.collection_source,
    o.payout_settlement_status,
    o.tenant_id,
    coalesce(t.name, '')::text as tenant_name
  from public.shop_orders o
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.courier_services cs on cs.id::text = o.courier_service_id::text
  left join public.tenants t on t.id = o.tenant_id
  where o.tenant_id = p_tenant_id
    and o.shop_type_snapshot = 'dropship'
    and (
      case
        when p_statuses is not null and cardinality(p_statuses) > 0 then
          o.status::text = any(p_statuses)
        when p_status is not null then
          o.status::text = p_status
        else
          o.status::text in (
            'submitted',
            'confirmed',
            'placed',
            'processing',
            'ready_for_pickup',
            'shipped',
            'delivered',
            'returned',
            'payment_received'
          )
      end
    )
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.recipient_name ilike ('%' || p_search || '%')
      or o.recipient_phone ilike ('%' || p_search || '%')
      or o.courier_awb_number ilike ('%' || p_search || '%')
      or o.courier_name ilike ('%' || p_search || '%')
      or cs.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or o.created_by_email ilike ('%' || p_search || '%')
      or t.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;


ALTER FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text", "p_statuses" "text"[]) OWNER TO "postgres";

-- user_can_manage_parent_tenant

CREATE OR REPLACE FUNCTION "public"."user_can_manage_parent_tenant"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and public.membership_email_matches_current_user(m.email)
      and m.is_active = true
      and (
        m.role = 'owner'::public.app_role
        or public.has_module_action(p_tenant_id, 'procurement_stock', 'manage')
      )
  );
$$;


ALTER FUNCTION "public"."user_can_manage_parent_tenant"("p_tenant_id" bigint) OWNER TO "postgres";

-- can_manage_products_for_parent

CREATE OR REPLACE FUNCTION "public"."can_manage_products_for_parent"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p_tenant_id is not null
    and (
      public.can_manage_products(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'edit')
      )
    );
$$;


ALTER FUNCTION "public"."can_manage_products_for_parent"("p_tenant_id" bigint) OWNER TO "postgres";

-- can_view_products_for_parent

CREATE OR REPLACE FUNCTION "public"."can_view_products_for_parent"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    p_tenant_id is not null
    and (
      public.can_view_products_internal(p_tenant_id)
      or public.can_view_products_customer(p_tenant_id)
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'view')
      )
      or exists (
        select 1
        from public.customer_group_members cgm
        join public.customer_groups cg on cg.id = cgm.customer_group_id
        join public.tenants t on t.id = cg.tenant_id
        where cgm.is_active = true
          and cg.is_active = true
          and lower(trim(cgm.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_tenant_id
      )
    );
$$;


ALTER FUNCTION "public"."can_view_products_for_parent"("p_tenant_id" bigint) OWNER TO "postgres";

-- parent_tenant_has_module_action

CREATE OR REPLACE FUNCTION "public"."parent_tenant_has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.membership_has_module_action(p_tenant_id, p_module_key, p_action);
$$;


ALTER FUNCTION "public"."parent_tenant_has_module_action"("p_tenant_id" bigint, "p_module_key" "text", "p_action" "text") OWNER TO "postgres";

-- get_parent_cash_circulation

CREATE OR REPLACE FUNCTION "public"."get_parent_cash_circulation"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_deployed numeric(12,2);
  v_ar_due numeric(12,2);
  v_ar_paid numeric(12,2);
  v_stock_cost numeric(12,2);
  v_profit_mtd numeric(12,2);
  v_payouts numeric(12,2);
begin
  if not public.user_can_manage_parent_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(case when type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id;

  select coalesce(sum(coalesce(allocated_cost, invested_amount)), 0) into v_deployed
  from public.shipment_investments
  where tenant_id = p_tenant_id and status = 'active';

  select
    coalesce(sum(due_amount), 0),
    coalesce(sum(paid_amount), 0)
  into v_ar_due, v_ar_paid
  from public.bills
  where parent_tenant_id = p_tenant_id;

  select coalesce(sum(
    public.calculate_landed_unit_cost(gs.shipment_item_id) * gs.quantity
  ), 0) into v_stock_cost
  from public.global_stocks gs
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and gst.is_sellable = true
    and gs.quantity > 0;

  with invoice_line_margin as (
    select
      ii.invoice_id,
      sum(ii.sell_price_amount * ii.quantity - ii.line_discount_amount) as lines_margin
    from public.global_invoice_items ii
    join public.bills i on i.id = ii.invoice_id
    where i.parent_tenant_id = p_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ii.invoice_id
  ),
  invoice_return_margin as (
    select
      ri.invoice_id,
      sum(ri.return_accounting_amount) as returns_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    join public.bills i on i.id = ri.invoice_id
    where i.parent_tenant_id = p_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ri.invoice_id
  )
  select coalesce(sum(
    coalesce(lm.lines_margin, 0.00)
      - i.discount_amount
      + (case
           when i.invoice_type = 'wholesale' or i.invoice_type = 'dropship' then i.shipping_charge
           when i.invoice_type = 'retail' then i.shipping_charge + i.cod_charge + i.print_charge + i.wrapping_charge
           else 0.00
         end)
      - coalesce(rm.returns_margin, 0.00)
  ), 0) into v_profit_mtd
  from public.bills i
  left join invoice_line_margin lm on lm.invoice_id = i.id
  left join invoice_return_margin rm on rm.invoice_id = i.id
  where i.parent_tenant_id = p_tenant_id
    and i.invoice_status = 'posted'::public.global_invoice_status
    and i.invoice_date >= date_trunc('month', current_date)::date;

  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where tenant_id = p_tenant_id
    and type in ('profit_payout', 'profit_reinvest');

  return jsonb_build_object(
    'investor_capital_in', v_deposits,
    'investor_capital_withdrawn', v_withdrawals,
    'investor_capital_deployed', v_deployed,
    'investor_capital_available', v_deposits - v_withdrawals - v_deployed,
    'customer_ar_due', v_ar_due,
    'customer_ar_paid', v_ar_paid,
    'stock_cost_in_circulation', v_stock_cost,
    'realized_profit_mtd', v_profit_mtd,
    'profit_distributed', v_payouts
  );
end;
$$;


ALTER FUNCTION "public"."get_parent_cash_circulation"("p_tenant_id" bigint) OWNER TO "postgres";

-- list_child_tenant_ids

CREATE OR REPLACE FUNCTION "public"."list_child_tenant_ids"("p_tenant_id" bigint) RETURNS SETOF bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select t.id
  from public.tenants t
  where t.parent_id = p_tenant_id
  order by t.id;
$$;


ALTER FUNCTION "public"."list_child_tenant_ids"("p_tenant_id" bigint) OWNER TO "postgres";

-- list_child_tenant_refs

CREATE OR REPLACE FUNCTION "public"."list_child_tenant_refs"("p_tenant_ids" bigint[]) RETURNS TABLE("id" bigint, "parent_id" bigint, "name" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select t.id, t.parent_id, t.name
  from public.tenants t
  where t.parent_id = any (coalesce(p_tenant_ids, array[]::bigint[]))
    and (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(t.parent_id)
    )
  order by t.parent_id, t.id;
$$;


ALTER FUNCTION "public"."list_child_tenant_refs"("p_tenant_ids" bigint[]) OWNER TO "postgres";

-- get_app_dashboard_bundle

CREATE OR REPLACE FUNCTION "public"."get_app_dashboard_bundle"("p_tenant_id" bigint, "p_tenant_ids" bigint[] DEFAULT NULL::bigint[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_proc jsonb := NULL;
  v_shop jsonb := NULL;
  v_investor jsonb := NULL;
  v_children jsonb := '[]'::jsonb;
  v_parent_ids bigint[];
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'p_tenant_id is required';
  END IF;

  IF NOT (
    public.is_superadmin()
    OR public.has_active_tenant_membership(p_tenant_id)
    OR public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'global_stock', 'view') THEN
    v_proc := public.get_procurement_dashboard_metrics(p_tenant_id);
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'shop_order', 'view') THEN
    v_shop := public.get_shop_order_dashboard_metrics(p_tenant_id);
  END IF;

  IF public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view') THEN
    v_investor := public.get_staff_investor_capital_metrics(p_tenant_id);
  END IF;

  v_parent_ids := coalesce(p_tenant_ids, ARRAY[]::bigint[]);
  IF cardinality(v_parent_ids) > 0 THEN
    SELECT coalesce(
      jsonb_agg(
        jsonb_build_object('id', c.id, 'parent_id', c.parent_id, 'name', c.name)
        ORDER BY c.parent_id, c.id
      ),
      '[]'::jsonb
    )
    INTO v_children
    FROM public.list_child_tenant_refs(v_parent_ids) AS c;
  END IF;

  RETURN jsonb_build_object(
    'refreshed_at', to_jsonb(now() AT TIME ZONE 'utc'),
    'procurement', v_proc,
    'shop_order', v_shop,
    'investor_capital', v_investor,
    'child_tenant_refs', v_children
  );
END;
$$;


ALTER FUNCTION "public"."get_app_dashboard_bundle"("p_tenant_id" bigint, "p_tenant_ids" bigint[]) OWNER TO "postgres";

-- list_catalog_refresh_log

CREATE OR REPLACE FUNCTION "public"."list_catalog_refresh_log"("p_tenant_id" bigint, "p_limit" integer DEFAULT 50) RETURNS TABLE("id" bigint, "parent_tenant_id" bigint, "source" "text", "event_kind" "text", "source_url" "text", "file_name" "text", "ran_at" timestamp with time zone, "products_updated" integer, "duration_seconds" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;
  if not public.can_view_products_for_parent(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.tenant_id,
    l.source,
    l.event_kind,
    l.source_url,
    l.file_name,
    l.ran_at,
    l.products_updated,
    l.duration_seconds
  from public.catalog_refresh_log l
  where l.tenant_id = p_tenant_id
  order by l.ran_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;


ALTER FUNCTION "public"."list_catalog_refresh_log"("p_tenant_id" bigint, "p_limit" integer) OWNER TO "postgres";

-- preview_tenant_data_purge

CREATE OR REPLACE FUNCTION "public"."preview_tenant_data_purge"("p_tenant_id" bigint, "p_scope" "text" DEFAULT 'all_hierarchy'::"text", "p_target_child_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_target_tenant_ids BIGINT[];
    v_shipment_count BIGINT := 0;
    v_stock_count BIGINT := 0;
    v_invoice_count BIGINT := 0;
    v_order_count BIGINT := 0;
    v_cart_count BIGINT := 0;
    v_ledger_count BIGINT := 0;
    v_wallets_count BIGINT := 0;
BEGIN
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Only parent tenant administrators can preview data purges.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_tenant_id OR parent_id = p_tenant_id;

        SELECT count(*) INTO v_shipment_count FROM public.global_shipments WHERE parent_tenant_id = p_tenant_id;
        SELECT count(*) INTO v_stock_count FROM public.global_stocks WHERE parent_tenant_id = p_tenant_id;
        SELECT count(*) INTO v_invoice_count FROM public.bills WHERE parent_tenant_id = p_tenant_id;
        SELECT count(*) INTO v_ledger_count FROM public.cashbook_entries WHERE tenant_id = p_tenant_id;
        SELECT count(*) INTO v_wallets_count FROM public.cashbook_accounts WHERE tenant_id = p_tenant_id;
    ELSE
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = p_target_child_id AND parent_id = p_tenant_id) THEN
            RAISE EXCEPTION 'Invalid child tenant ID for this parent organization.';
        END IF;

        v_target_tenant_ids := ARRAY[p_target_child_id];

        SELECT count(*) INTO v_invoice_count FROM public.bills WHERE issued_by_tenant_id = p_target_child_id;
        SELECT count(*) INTO v_ledger_count FROM public.cashbook_entries WHERE operating_tenant_id = p_target_child_id;
        SELECT count(*) INTO v_wallets_count FROM public.cashbook_accounts WHERE tenant_id = p_target_child_id;
    END IF;

    SELECT count(*) INTO v_order_count FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    SELECT count(*) INTO v_cart_count FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);

    RETURN jsonb_build_object(
        'shipments', v_shipment_count,
        'stocks', v_stock_count,
        'invoices', v_invoice_count,
        'orders', v_order_count,
        'carts', v_cart_count,
        'ledgers', v_ledger_count,
        'wallets_to_reset', v_wallets_count
    );
END;
$$;


ALTER FUNCTION "public"."preview_tenant_data_purge"("p_tenant_id" bigint, "p_scope" "text", "p_target_child_id" bigint) OWNER TO "postgres";

-- purge_tenant_operational_data

CREATE OR REPLACE FUNCTION "public"."purge_tenant_operational_data"("p_tenant_id" bigint, "p_scope" "text" DEFAULT 'all_hierarchy'::"text", "p_confirmation_slug" "text" DEFAULT ''::"text", "p_target_child_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_parent_slug TEXT;
    v_target_slug TEXT;
    v_target_id BIGINT;
    v_target_tenant_ids BIGINT[];
    v_counts JSONB;
    v_user_id UUID := auth.uid();
    v_user_email TEXT := COALESCE(public.current_user_email(), 'unknown');
BEGIN
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Administrative privileges on the parent tenant required.';
    END IF;

    SELECT slug INTO v_parent_slug FROM public.tenants WHERE id = p_tenant_id AND parent_id IS NULL;
    IF v_parent_slug IS NULL THEN
        RAISE EXCEPTION 'Parent tenant not found or is not a root workspace.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        v_target_id := p_tenant_id;
        v_target_slug := v_parent_slug;

        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_tenant_id OR parent_id = p_tenant_id;
    ELSIF p_scope = 'child_only' THEN
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        SELECT slug INTO v_target_slug
        FROM public.tenants
        WHERE id = p_target_child_id AND parent_id = p_tenant_id;

        IF v_target_slug IS NULL THEN
            RAISE EXCEPTION 'Selected child tenant not found under this parent organization.';
        END IF;

        v_target_id := p_target_child_id;
        v_target_tenant_ids := ARRAY[p_target_child_id];
    ELSE
        RAISE EXCEPTION 'Invalid scope: %. Must be all_hierarchy or child_only.', p_scope;
    END IF;

    IF UPPER(TRIM(p_confirmation_slug)) <> UPPER(TRIM(v_target_slug)) THEN
        RAISE EXCEPTION 'Confirmation slug mismatch. Expected %, received %.', UPPER(TRIM(v_target_slug)), UPPER(TRIM(p_confirmation_slug));
    END IF;

    v_counts := public.preview_tenant_data_purge(p_tenant_id, p_scope, p_target_child_id);

    -- PBC master data must never be purged:
    -- product_based_costing_files, product_based_costing_items, product_based_costing_backlog_items

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.sales_return_items WHERE parent_tenant_id = p_tenant_id;
        DELETE FROM public.bill_lines WHERE parent_tenant_id = p_tenant_id;
        DELETE FROM public.bills WHERE parent_tenant_id = p_tenant_id;
    ELSE
        DELETE FROM public.sales_return_items
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE parent_tenant_id = p_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bill_lines
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE parent_tenant_id = p_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bills
        WHERE parent_tenant_id = p_tenant_id
          AND issued_by_tenant_id = p_target_child_id;
    END IF;

    DELETE FROM public.dropship_order_settlements WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.customer_demand_bucket_items WHERE tenant_id = ANY(v_target_tenant_ids);

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.cashbook_entries WHERE tenant_id = p_tenant_id;
        UPDATE public.cashbook_accounts
        SET available_balance = 0.0000,
            pending_balance = 0.0000,
            locked_balance = 0.0000,
            updated_at = now()
        WHERE tenant_id = p_tenant_id;
    ELSE
        DELETE FROM public.cashbook_entries WHERE operating_tenant_id = p_target_child_id;
        UPDATE public.cashbook_accounts
        SET available_balance = 0.0000,
            pending_balance = 0.0000,
            locked_balance = 0.0000,
            updated_at = now()
        WHERE tenant_id = p_target_child_id;
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.stock_movements WHERE tenant_id = ANY(v_target_tenant_ids);
        DELETE FROM public.global_stocks WHERE parent_tenant_id = p_tenant_id;
        DELETE FROM public.global_shipments WHERE parent_tenant_id = p_tenant_id;
    END IF;

    UPDATE public.sales_invoice_counters
    SET last_value = 0
    WHERE tenant_id = ANY(v_target_tenant_ids);

    INSERT INTO public.tenant_data_purge_logs (
        parent_tenant_id,
        target_tenant_id,
        scope,
        executed_by,
        executor_email,
        confirmation_phrase,
        deleted_counts
    ) VALUES (
        p_tenant_id,
        v_target_id,
        p_scope,
        v_user_id,
        v_user_email,
        p_confirmation_slug,
        v_counts
    );

    RETURN jsonb_build_object(
        'success', true,
        'purged_counts', v_counts,
        'purged_at', now()
    );
END;
$$;


ALTER FUNCTION "public"."purge_tenant_operational_data"("p_tenant_id" bigint, "p_scope" "text", "p_confirmation_slug" "text", "p_target_child_id" bigint) OWNER TO "postgres";

-- transfer_network_owner

CREATE OR REPLACE FUNCTION "public"."transfer_network_owner"("p_tenant_id" bigint, "p_new_email" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email text := lower(trim(p_new_email));
  v_old_owner public.memberships;
  v_new_membership public.memberships;
  v_owner_role_id bigint;
  v_manager_role_id bigint;
begin
  if not public.is_superadmin() and not public.is_network_owner(p_tenant_id) then
    raise exception 'Only the current network owner or superadmin can transfer ownership';
  end if;

  if v_email = '' then
    raise exception 'p_new_email is required';
  end if;

  select t.parent_id into v_old_owner.tenant_id
  from public.tenants t
  where t.id = p_tenant_id;

  if exists (
    select 1 from public.tenants t
    where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'Ownership transfer must target the parent or standalone tenant';
  end if;

  select tr.id into v_owner_role_id
  from public.tenant_roles tr
  where tr.tenant_id = p_tenant_id and tr.scope = 'app' and tr.slug = 'owner'
  limit 1;

  select tr.id into v_manager_role_id
  from public.tenant_roles tr
  where tr.tenant_id = p_tenant_id and tr.scope = 'app' and tr.slug = 'manager'
  limit 1;

  select m.* into v_old_owner
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and m.role = 'owner'::public.app_role
    and m.is_active = true
  order by m.id asc
  limit 1;

  if v_old_owner.id is null then
    raise exception 'No active owner found for tenant %', p_tenant_id;
  end if;

  if lower(trim(v_old_owner.email)) = v_email then
    return jsonb_build_object('success', true, 'owner_membership_id', v_old_owner.id);
  end if;

  update public.memberships
  set
    role = 'manager'::public.app_role,
    tenant_role_id = v_manager_role_id,
    updated_at = now()
  where id = v_old_owner.id;

  select m.* into v_new_membership
  from public.memberships m
  where m.tenant_id = p_tenant_id
    and lower(trim(m.email)) = v_email
  limit 1;

  if v_new_membership.id is null then
    insert into public.memberships (email, tenant_id, role, is_active, tenant_role_id)
    values (v_email, p_tenant_id, 'owner'::public.app_role, true, v_owner_role_id)
    returning * into v_new_membership;
  else
    update public.memberships
    set
      role = 'owner'::public.app_role,
      tenant_role_id = v_owner_role_id,
      is_active = true,
      updated_at = now()
    where id = v_new_membership.id
    returning * into v_new_membership;
  end if;

  return jsonb_build_object(
    'success', true,
    'previous_owner_membership_id', v_old_owner.id,
    'owner_membership_id', v_new_membership.id
  );
end;
$$;


ALTER FUNCTION "public"."transfer_network_owner"("p_tenant_id" bigint, "p_new_email" "text") OWNER TO "postgres";

-- upsert_profile_for_party

CREATE OR REPLACE FUNCTION "public"."upsert_profile_for_party"("p_tenant_id" bigint, "p_profile_type" "public"."profile_party_type", "p_subject_id" bigint, "p_name" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_phone_country_code" "text" DEFAULT '+880'::"text", "p_address" "text" DEFAULT NULL::"text", "p_is_phone_unique" boolean DEFAULT true, "p_accent_color" "text" DEFAULT NULL::"text", "p_is_active" boolean DEFAULT true, "p_deleted_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile_id bigint;
  v_phone_unique boolean;
begin
  if p_tenant_id is null or p_subject_id is null then
    return null;
  end if;

  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise exception 'profile name is required';
  end if;

  v_phone_unique := coalesce(p_is_phone_unique, true);
  if p_phone is null or btrim(p_phone) = '' then
    v_phone_unique := false;
  end if;

  insert into public.profiles (
    parent_tenant_id,
    profile_type,
    subject_id,
    name,
    email,
    phone,
    phone_country_code,
    address,
    is_phone_unique,
    accent_color,
    is_active,
    deleted_at
  )
  values (
    p_tenant_id,
    p_profile_type,
    p_subject_id,
    btrim(p_name),
    nullif(btrim(coalesce(p_email, '')), ''),
    nullif(btrim(coalesce(p_phone, '')), ''),
    coalesce(nullif(btrim(coalesce(p_phone_country_code, '')), ''), '+880'),
    nullif(btrim(coalesce(p_address, '')), ''),
    v_phone_unique,
    nullif(btrim(coalesce(p_accent_color, '')), ''),
    coalesce(p_is_active, true),
    p_deleted_at
  )
  on conflict (parent_tenant_id, profile_type, subject_id) do update set
    name = excluded.name,
    email = excluded.email,
    phone = excluded.phone,
    phone_country_code = excluded.phone_country_code,
    address = excluded.address,
    is_phone_unique = excluded.is_phone_unique,
    accent_color = coalesce(excluded.accent_color, profiles.accent_color),
    is_active = excluded.is_active,
    deleted_at = excluded.deleted_at,
    updated_at = now()
  returning id into v_profile_id;

  return v_profile_id;
end;
$$;


ALTER FUNCTION "public"."upsert_profile_for_party"("p_tenant_id" bigint, "p_profile_type" "public"."profile_party_type", "p_subject_id" bigint, "p_name" "text", "p_email" "text", "p_phone" "text", "p_phone_country_code" "text", "p_address" "text", "p_is_phone_unique" boolean, "p_accent_color" "text", "p_is_active" boolean, "p_deleted_at" timestamp with time zone) OWNER TO "postgres";

-- resolve_notification_recipient_user_ids

CREATE OR REPLACE FUNCTION "public"."resolve_notification_recipient_user_ids"("p_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_audience" "public"."notification_audience", "p_recipient_user_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_module_key" "text" DEFAULT NULL::"text", "p_action" "text" DEFAULT 'view'::"text") RETURNS "uuid"[]
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_ids uuid[];
begin
  if p_audience = 'assignee_only' then
    if p_recipient_user_ids is null or cardinality(p_recipient_user_ids) = 0 then
      return array[]::uuid[];
    end if;

    select coalesce(array_agg(distinct u.id), array[]::uuid[])
    into v_user_ids
    from unnest(p_recipient_user_ids) as input(user_id)
    join auth.users u on u.id = input.user_id
    where input.user_id is not null;

    return coalesce(v_user_ids, array[]::uuid[]);
  end if;

  if p_audience = 'child_only' and p_operating_tenant_id is null then
    return array[]::uuid[];
  end if;

  with pools as (
    select distinct
      u.id as user_id,
      m.tenant_id as membership_tenant_id,
      m.email as membership_email
    from public.memberships m
    join auth.users u on lower(trim(u.email)) = lower(trim(m.email))
    where m.is_active = true
      and (
        (
          p_audience in ('child_only', 'child_and_parent')
          and p_operating_tenant_id is not null
          and m.tenant_id = p_operating_tenant_id
        )
        or (
          p_audience in ('parent_only', 'child_and_parent')
          and m.tenant_id = p_tenant_id
        )
        or (
          m.tenant_id = p_tenant_id
          and m.role = 'owner'::public.app_role
        )
      )
  )
  select coalesce(array_agg(distinct p.user_id), array[]::uuid[])
  into v_user_ids
  from pools p
  where p_module_key is null
     or public.membership_has_module_action_for_email(
          p.membership_email,
          p.membership_tenant_id,
          p_module_key,
          p_action
        );

  return coalesce(v_user_ids, array[]::uuid[]);
end;
$$;


ALTER FUNCTION "public"."resolve_notification_recipient_user_ids"("p_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_audience" "public"."notification_audience", "p_recipient_user_ids" "uuid"[], "p_module_key" "text", "p_action" "text") OWNER TO "postgres";

-- notification_inbox_scope_matches

CREATE OR REPLACE FUNCTION "public"."notification_inbox_scope_matches"("p_tenant_id" bigint, "p_books_tenant_id" bigint, "p_operating_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT
    p_books_tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
    AND (
      NOT EXISTS (
        SELECT 1
        FROM public.tenants t
        WHERE t.id = p_tenant_id
          AND t.parent_id IS NOT NULL
      )
      OR p_operating_tenant_id IS NULL
      OR p_operating_tenant_id = p_tenant_id
    );
$$;


ALTER FUNCTION "public"."notification_inbox_scope_matches"("p_tenant_id" bigint, "p_books_tenant_id" bigint, "p_operating_tenant_id" bigint) OWNER TO "postgres";

-- get_my_notification_unread_count

CREATE OR REPLACE FUNCTION "public"."get_my_notification_unread_count"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_unread_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
    or public.has_shop_notification_access(p_tenant_id)
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  select count(*)
  into v_unread_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and r.read_at is null
    and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id);

  return jsonb_build_object('unread_count', coalesce(v_unread_count, 0));
end;
$$;


ALTER FUNCTION "public"."get_my_notification_unread_count"("p_tenant_id" bigint) OWNER TO "postgres";

-- list_my_notifications_paginated

CREATE OR REPLACE FUNCTION "public"."list_my_notifications_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_unread_only" boolean DEFAULT false, "p_event_type" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := least(greatest(coalesce(p_page_size, 20), 1), 100);
  v_total_count bigint;
  v_unread_count bigint;
  v_total_pages integer;
  v_data jsonb;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
    or public.has_shop_notification_access(p_tenant_id)
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  select count(*)
  into v_total_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
    and (not p_unread_only or r.read_at is null)
    and (p_event_type is null or p_event_type = '' or n.event_type = p_event_type);

  select count(*)
  into v_unread_count
  from public.notification_recipients r
  join public.notifications n on n.id = r.notification_id
  where r.user_id = v_user_id
    and r.read_at is null
    and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id);

  select coalesce(jsonb_agg(row_to_json(x)::jsonb), '[]'::jsonb)
  into v_data
  from (
    select
      r.id as recipient_id,
      n.id as notification_id,
      r.read_at,
      (r.read_at is null) as is_unread,
      n.event_type,
      n.title,
      n.body,
      n.link_path,
      n.entity_type,
      n.entity_id,
      n.parent_tenant_id,
      n.operating_tenant_id,
      t.name as operating_tenant_name,
      n.created_at
    from public.notification_recipients r
    join public.notifications n on n.id = r.notification_id
    left join public.tenants t on t.id = n.operating_tenant_id
    where r.user_id = v_user_id
      and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
      and (not p_unread_only or r.read_at is null)
      and (p_event_type is null or p_event_type = '' or n.event_type = p_event_type)
    order by n.created_at desc, r.created_at desc
    limit v_page_size
    offset (v_page - 1) * v_page_size
  ) x;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages,
      'unread_count', v_unread_count
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_my_notifications_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_unread_only" boolean, "p_event_type" "text") OWNER TO "postgres";

-- mark_all_my_notifications_read

CREATE OR REPLACE FUNCTION "public"."mark_all_my_notifications_read"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_user_id uuid := auth.uid();
  v_updated_count bigint;
begin
  if v_user_id is null then
    raise exception 'Authentication required';
  end if;

  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.has_active_tenant_membership(p_tenant_id)
    or public.user_can_manage_parent_tenant(public.resolve_parent_tenant_id(p_tenant_id))
    or public.has_shop_notification_access(p_tenant_id)
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  with updated as (
    update public.notification_recipients r
    set read_at = now()
    from public.notifications n
    where n.id = r.notification_id
      and r.user_id = v_user_id
      and r.read_at is null
      and public.notification_inbox_scope_matches(p_tenant_id, n.parent_tenant_id, n.operating_tenant_id)
    returning r.id
  )
  select count(*) into v_updated_count from updated;

  return jsonb_build_object(
    'success', true,
    'updated_count', coalesce(v_updated_count, 0)
  );
end;
$$;


ALTER FUNCTION "public"."mark_all_my_notifications_read"("p_tenant_id" bigint) OWNER TO "postgres";


-- Restore RLS policies dropped by CASCADE on guard functions

CREATE POLICY "batch_code_items_all" ON "public"."batch_code_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."batch_code_lists" "l"
  WHERE (("l"."id" = "batch_code_items"."list_id") AND "public"."user_can_manage_parent_tenant"("l"."parent_tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."batch_code_lists" "l"
  WHERE (("l"."id" = "batch_code_items"."list_id") AND "public"."user_can_manage_parent_tenant"("l"."parent_tenant_id")))));

CREATE POLICY "batch_code_items_select" ON "public"."batch_code_items" FOR SELECT TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."batch_code_lists" "l"
  WHERE (("l"."id" = "batch_code_items"."list_id") AND ("public"."user_can_manage_parent_tenant"("l"."parent_tenant_id") OR (EXISTS ( SELECT 1
           FROM "public"."memberships" "m"
          WHERE (("m"."tenant_id" = "l"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))))))));

CREATE POLICY "batch_code_lists_all" ON "public"."batch_code_lists" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "batch_code_lists_select" ON "public"."batch_code_lists" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "batch_code_lists"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "entity_tags_all" ON "public"."entity_tags" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "entity_tags_select" ON "public"."entity_tags" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR "public"."has_active_tenant_membership"("tenant_id")));

CREATE POLICY "global_invoices_select" ON "public"."bills" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("issued_by_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (("invoice_type" = 'ap'::"public"."global_invoice_type") AND ("public"."membership_has_module_action"("parent_tenant_id", 'global_invoice'::"text", 'view'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."tenants" "ct"
     JOIN "public"."memberships" "m" ON (("m"."tenant_id" = "ct"."id")))
  WHERE (("ct"."parent_id" = "bills"."parent_tenant_id") AND "public"."membership_email_matches_current_user"("m"."email") AND ("m"."is_active" = true) AND "public"."membership_has_module_action"("ct"."id", 'global_invoice'::"text", 'view'::"text"))))))));

CREATE POLICY "global_invoices_write" ON "public"."bills" TO "authenticated" USING (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "global_shipment_boxes_all" ON "public"."global_shipment_boxes" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "global_shipment_boxes_select" ON "public"."global_shipment_boxes" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_boxes"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_shipment_cost_entries_all" ON "public"."global_shipment_cost_entries" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "global_shipment_cost_entries_select" ON "public"."global_shipment_cost_entries" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_cost_entries"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_shipment_item_outcomes_all" ON "public"."global_shipment_item_outcomes" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "global_shipment_items_all" ON "public"."global_shipment_items" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE (("gs"."id" = "global_shipment_items"."shipment_id") AND "public"."user_can_manage_parent_tenant"("gs"."parent_tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."global_shipments" "gs"
  WHERE (("gs"."id" = "global_shipment_items"."shipment_id") AND "public"."user_can_manage_parent_tenant"("gs"."parent_tenant_id")))));

CREATE POLICY "global_shipment_outcome_vendor_credits_all" ON "public"."global_shipment_outcome_vendor_credits" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "global_shipment_sections_all" ON "public"."global_shipment_sections" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "global_shipment_sections_select" ON "public"."global_shipment_sections" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_sections"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_shipments_all" ON "public"."global_shipments" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "global_shipments_select" ON "public"."global_shipments" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipments"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_stock_types_all" ON "public"."global_stock_types" TO "authenticated" USING (("public"."is_superadmin"() OR ("parent_tenant_id" IS NULL) OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))) WITH CHECK (("public"."is_superadmin"() OR ("parent_tenant_id" IS NULL) OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "global_stocks_all" ON "public"."global_stocks" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "invoice_brands_delete" ON "public"."invoice_brands" FOR DELETE TO "authenticated" USING (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "invoice_brands_insert" ON "public"."invoice_brands" FOR INSERT TO "authenticated" WITH CHECK (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "invoice_brands_select" ON "public"."invoice_brands" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("parent_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "invoice_brands_update" ON "public"."invoice_brands" FOR UPDATE TO "authenticated" USING (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("parent_tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "members_can_view_tenants" ON "public"."tenants" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "tenants"."id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true)))) OR (("parent_id" IS NOT NULL) AND "public"."user_can_manage_parent_tenant"("parent_id"))));

CREATE POLICY "preorder_demand_select" ON "public"."preorder_demand" FOR SELECT TO "authenticated" USING (("public"."is_tenant_staff"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."tenants" "t"
  WHERE (("t"."id" = "preorder_demand"."tenant_id") AND ("t"."parent_id" IS NOT NULL) AND "public"."user_can_manage_parent_tenant"("t"."parent_id"))))));

CREATE POLICY "product_brands_read_authenticated" ON "public"."product_brands" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("product_brands"."tenant_id" = "m"."tenant_id")))) OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "product_categories_read_authenticated" ON "public"."product_categories" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("product_categories"."tenant_id" = "m"."tenant_id")))) OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "products_delete" ON "public"."products" FOR DELETE TO "authenticated" USING ("public"."can_manage_products_for_parent"("parent_tenant_id"));

CREATE POLICY "products_insert" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_products_for_parent"("parent_tenant_id"));

CREATE POLICY "products_select" ON "public"."products" FOR SELECT TO "authenticated" USING ("public"."can_view_products_for_parent"("parent_tenant_id"));

CREATE POLICY "products_update" ON "public"."products" FOR UPDATE TO "authenticated" USING ("public"."can_manage_products_for_parent"("parent_tenant_id")) WITH CHECK ("public"."can_manage_products_for_parent"("parent_tenant_id"));

CREATE POLICY "profiles_select" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("parent_tenant_id") OR "public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "profiles"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND "m"."is_active")))));

CREATE POLICY "recipient_profiles_select" ON "public"."recipient_profiles" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "recipient_profiles_write" ON "public"."recipient_profiles" TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'recipient_profile'::"text", 'edit'::"text") OR "public"."membership_has_module_action"("tenant_id", 'customer'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "shipment_progress_flow_stages_all" ON "public"."shipment_progress_flow_stages" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."shipment_progress_flows" "f"
  WHERE (("f"."id" = "shipment_progress_flow_stages"."flow_id") AND "public"."user_can_manage_parent_tenant"("f"."tenant_id"))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."shipment_progress_flows" "f"
  WHERE (("f"."id" = "shipment_progress_flow_stages"."flow_id") AND "public"."user_can_manage_parent_tenant"("f"."tenant_id")))));

CREATE POLICY "shipment_progress_flows_all" ON "public"."shipment_progress_flows" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "stock_locations_all" ON "public"."stock_locations" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("parent_tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("parent_tenant_id"));

CREATE POLICY "stock_locations_select" ON "public"."stock_locations" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("parent_tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "stock_locations"."parent_tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "tenant_data_purge_logs_select" ON "public"."tenant_data_purge_logs" FOR SELECT TO "authenticated" USING (("public"."is_superadmin"() OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

CREATE POLICY "vendors_select" ON "public"."vendors" FOR SELECT TO "authenticated" USING ((("public"."is_superadmin"() AND ("parent_tenant_id" IS NULL)) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."parent_tenant_id" = "m"."tenant_id")))) OR "public"."user_can_manage_parent_tenant"("parent_tenant_id")));

GRANT ALL ON FUNCTION public.can_manage_products_for_parent(bigint) TO anon;
GRANT ALL ON FUNCTION public.can_manage_products_for_parent(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.can_manage_products_for_parent(bigint) TO service_role;
GRANT ALL ON FUNCTION public.can_view_products_for_parent(bigint) TO anon;
GRANT ALL ON FUNCTION public.can_view_products_for_parent(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.can_view_products_for_parent(bigint) TO service_role;
GRANT ALL ON FUNCTION public.user_can_manage_parent_tenant(bigint) TO anon;
GRANT ALL ON FUNCTION public.user_can_manage_parent_tenant(bigint) TO authenticated;
GRANT ALL ON FUNCTION public.user_can_manage_parent_tenant(bigint) TO service_role;
