-- Migration: Update list_shops RPC to support parent_tenant_id filtering
-- If p_parent_tenant_id is provided and equals p_tenant_id (meaning current context is the parent tenant),
-- shops belonging to that parent (via parent_tenant_id or tenant_id) are returned.
-- Otherwise, shops are filtered by p_tenant_id.

DROP FUNCTION IF EXISTS public.list_shops(bigint, integer, integer, text, boolean) CASCADE;
DROP FUNCTION IF EXISTS public.list_shops(bigint, bigint, integer, integer, text, boolean) CASCADE;

CREATE OR REPLACE FUNCTION "public"."list_shops"(
  "p_tenant_id" bigint,
  "p_parent_tenant_id" bigint DEFAULT NULL::bigint,
  "p_limit" integer DEFAULT 200,
  "p_offset" integer DEFAULT 0,
  "p_search" "text" DEFAULT NULL::"text",
  "p_active" boolean DEFAULT NULL::boolean
) RETURNS TABLE(
  "id" bigint,
  "tenant_id" bigint,
  "name" "text",
  "slug" "text",
  "shop_type" "public"."shop_type_enum",
  "vendor_code" "text",
  "order_mode" "public"."shop_order_mode_enum",
  "is_negotiable" boolean,
  "show_stock_quantity" boolean,
  "default_currency_id" bigint,
  "global_stock_type_id" bigint,
  "is_active" boolean,
  "allow_delivery" boolean,
  "buy_currency_id" bigint,
  "sell_currency_id" bigint,
  "pricing_method" "text",
  "markup_percentage" numeric,
  "quantity_display_mode" "text",
  "default_print_charge_amount" numeric,
  "default_packing_charge_amount" numeric,
  "deduct_charges_from_margin" boolean,
  "vendor_filters" "jsonb",
  "deduct_print_from_margin" boolean,
  "deduct_packing_from_margin" boolean,
  "description" "text",
  "category_ids" bigint[],
  "created_at" timestamp with time zone,
  "updated_at" timestamp with time zone,
  "total_count" bigint
)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total bigint;
  v_is_parent_query boolean;
begin
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  v_is_parent_query := (p_parent_tenant_id is not null and p_parent_tenant_id = p_tenant_id);

  if v_is_parent_query then
    select count(*)
    into v_total
    from public.shops s
    where (s.parent_tenant_id = p_parent_tenant_id or s.tenant_id = p_parent_tenant_id)
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (p_search is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%');

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
      v_total
    from public.shops s
    where (s.parent_tenant_id = p_parent_tenant_id or s.tenant_id = p_parent_tenant_id)
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (p_search is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%')
    order by s.name asc
    limit  p_limit
    offset p_offset;
  else
    select count(*)
    into v_total
    from public.shops s
    where s.tenant_id = p_tenant_id
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (p_search is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%');

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
      v_total
    from public.shops s
    where s.tenant_id = p_tenant_id
      and s.deleted_at is null
      and (p_active is null or s.is_active = p_active)
      and (p_search is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%')
    order by s.name asc
    limit  p_limit
    offset p_offset;
  end if;
end;
$$;

ALTER FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean) OWNER TO "postgres";

GRANT EXECUTE ON FUNCTION "public"."list_shops"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_active" boolean) TO "authenticated";
