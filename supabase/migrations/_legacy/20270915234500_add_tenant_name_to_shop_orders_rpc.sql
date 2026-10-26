-- Add tenant_name to list_shop_orders_for_staff and list_dropship_shop_orders_for_staff RPCs

DROP FUNCTION IF EXISTS public.list_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, bigint) CASCADE;

CREATE OR REPLACE FUNCTION "public"."list_shop_orders_for_staff"(
  "p_tenant_id" bigint,
  "p_parent_tenant_id" bigint DEFAULT NULL::bigint,
  "p_limit" integer DEFAULT 50,
  "p_offset" integer DEFAULT 0,
  "p_search" "text" DEFAULT NULL::"text",
  "p_status" "text" DEFAULT NULL::"text",
  "p_shop_id" bigint DEFAULT NULL::bigint
) RETURNS TABLE(
  "id" bigint,
  "tenant_id" bigint,
  "shop_id" bigint,
  "shop_name" "text",
  "customer_group_id" bigint,
  "customer_group_name" "text",
  "order_no" "text",
  "name" "text",
  "shop_type_snapshot" "public"."shop_type_enum",
  "is_negotiable_snapshot" boolean,
  "status" "public"."shop_order_status",
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "item_count" bigint,
  "tenant_name" "text"
)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent_query boolean;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_is_parent_query := (p_parent_tenant_id is not null and p_parent_tenant_id = p_tenant_id);

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
  where (
    (v_is_parent_query and (o.parent_tenant_id = p_parent_tenant_id or o.tenant_id = p_parent_tenant_id))
    or (not v_is_parent_query and o.tenant_id = p_tenant_id)
  )
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

ALTER FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) TO "authenticated";

DROP FUNCTION IF EXISTS public.list_dropship_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, text[]) CASCADE;

CREATE OR REPLACE FUNCTION "public"."list_dropship_shop_orders_for_staff"(
  "p_tenant_id" bigint,
  "p_parent_tenant_id" bigint DEFAULT NULL::bigint,
  "p_limit" integer DEFAULT 20,
  "p_offset" integer DEFAULT 0,
  "p_status" "text" DEFAULT NULL::"text",
  "p_search" "text" DEFAULT NULL::"text",
  "p_statuses" "text"[] DEFAULT NULL::"text"[]
) RETURNS TABLE(
  "id" bigint,
  "order_no" "text",
  "status" "public"."shop_order_status",
  "created_at" timestamp with time zone,
  "customer_group_name" "text",
  "created_by_email" "text",
  "recipient_name" "text",
  "recipient_phone" "text",
  "courier_name" "text",
  "courier_awb_number" "text",
  "cod_collect_amount" numeric,
  "total_amount" numeric,
  "global_invoice_id" bigint,
  "courier_remittance_ref" "text",
  "collection_source" "public"."collection_source_type",
  "payout_settlement_status" "text",
  "tenant_id" bigint,
  "tenant_name" "text"
)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent_query boolean;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_is_parent_query := (p_parent_tenant_id is not null and p_parent_tenant_id = p_tenant_id);

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
  where (
    (v_is_parent_query and (o.parent_tenant_id = p_parent_tenant_id or o.tenant_id = p_parent_tenant_id))
    or (not v_is_parent_query and o.tenant_id = p_tenant_id)
  )
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

ALTER FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text", "p_statuses" "text"[]) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text", "p_statuses" "text"[]) TO "authenticated";
