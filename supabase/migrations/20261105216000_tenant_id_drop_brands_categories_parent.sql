-- Phase 4c: drop parent_tenant_id on product_brands + product_categories.

CREATE OR REPLACE FUNCTION "public"."list_product_brands_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text" DEFAULT NULL::"text", "p_vendor_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."product_brands"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vendor_code text;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  return query
  select pb.*
  from public.product_brands pb
  where pb.tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pb.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pb.vendor_id = p_vendor_id)
  order by pb.name asc;
end;
$$;


ALTER FUNCTION "public"."list_product_brands_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text", "p_vendor_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_product_categories_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text" DEFAULT NULL::"text", "p_vendor_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."product_categories"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vendor_code text;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_vendor_code := nullif(upper(trim(coalesce(p_vendor_code, ''))), '');

  return query
  select pc.*
  from public.product_categories pc
  where pc.tenant_id = v_scope_tenant_id
    and (v_vendor_code is null or pc.vendor_code = v_vendor_code)
    and (p_vendor_id is null or pc.vendor_id = p_vendor_id)
  order by pc.name asc;
end;
$$;


ALTER FUNCTION "public"."list_product_categories_for_tenant"("p_tenant_id" bigint, "p_vendor_code" "text", "p_vendor_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shop_setup_bundle"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop jsonb;
  v_shop_tenant_id bigint;
  v_scope_tenant_id bigint;
  v_categories jsonb := '[]'::jsonb;
  v_vendors jsonb := '[]'::jsonb;
  v_brands_by_vendor jsonb := '{}'::jsonb;
BEGIN
  IF p_shop_id IS NULL OR p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop_id and tenant_id are required';
  END IF;

  SELECT
    to_jsonb(s) || jsonb_build_object('tenant_slug', coalesce(t.slug, '')),
    s.tenant_id
  INTO v_shop, v_shop_tenant_id
  FROM public.shops s
  LEFT JOIN public.tenants t ON t.id = s.tenant_id
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL
    AND s.tenant_id = p_tenant_id;

  IF v_shop IS NULL OR v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.user_can_access_tenant_fetch(v_shop_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_scope_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);

  SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.name), '[]'::jsonb)
  INTO v_categories
  FROM public.shop_categories c
  WHERE c.tenant_id = v_shop_tenant_id;

  SELECT coalesce(jsonb_agg(to_jsonb(v) ORDER BY v.id), '[]'::jsonb)
  INTO v_vendors
  FROM public.list_vendors_for_tenant(v_shop_tenant_id) v;

  SELECT coalesce(
    jsonb_object_agg(upper(trim(x.vendor_code)), x.brand_names),
    '{}'::jsonb
  )
  INTO v_brands_by_vendor
  FROM (
    SELECT
      pb.vendor_code,
      jsonb_agg(trim(pb.name) ORDER BY trim(pb.name))
        FILTER (WHERE pb.name IS NOT NULL AND trim(pb.name) <> '') AS brand_names
    FROM public.product_brands pb
    WHERE pb.tenant_id = v_scope_tenant_id
      AND pb.vendor_code IS NOT NULL
      AND trim(pb.vendor_code) <> ''
    GROUP BY pb.vendor_code
  ) x
  WHERE x.brand_names IS NOT NULL;

  RETURN jsonb_build_object(
    'shop', v_shop,
    'categories', v_categories,
    'vendors', v_vendors,
    'brands_by_vendor', v_brands_by_vendor
  );
END;
$$;


ALTER FUNCTION "public"."get_shop_setup_bundle"("p_shop_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";

DROP TRIGGER IF EXISTS trg_product_brands_set_parent_tenant_id ON public.product_brands;
DROP TRIGGER IF EXISTS trg_product_categories_set_parent_tenant_id ON public.product_categories;
DROP FUNCTION IF EXISTS public.set_parent_tenant_id_from_tenant();

DROP INDEX IF EXISTS public.product_brands_parent_tenant_id_idx;
DROP INDEX IF EXISTS public.product_categories_parent_tenant_id_idx;

ALTER TABLE public.product_brands DROP CONSTRAINT IF EXISTS product_brands_parent_tenant_id_fkey;
ALTER TABLE public.product_categories DROP CONSTRAINT IF EXISTS product_categories_parent_tenant_id_fkey;

DROP POLICY IF EXISTS product_brands_read_authenticated ON public.product_brands;
CREATE POLICY "product_brands_read_authenticated" ON "public"."product_brands" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("product_brands"."tenant_id" = "m"."tenant_id")))) OR "public"."user_can_manage_parent_tenant"("tenant_id")));

DROP POLICY IF EXISTS product_categories_read_authenticated ON public.product_categories;
CREATE POLICY "product_categories_read_authenticated" ON "public"."product_categories" FOR SELECT TO "authenticated" USING (((EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("product_categories"."tenant_id" = "m"."tenant_id")))) OR "public"."user_can_manage_parent_tenant"("tenant_id")));

ALTER TABLE public.product_brands DROP COLUMN IF EXISTS parent_tenant_id;
ALTER TABLE public.product_categories DROP COLUMN IF EXISTS parent_tenant_id;
