-- Extracted from supabase/schemas/public.sql (procurement/stock/costing). Move-only.

CREATE OR REPLACE FUNCTION "public"."_assert_parent_warehouse_tenant"("p_parent_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;

  select parent_id into v_parent_id
  from public.tenants
  where id = p_parent_tenant_id;

  if not found then
    raise exception 'tenant not found';
  end if;

  if v_parent_id is not null then
    raise exception 'stock locations are only for parent warehouse tenants';
  end if;
end;
$$;


ALTER FUNCTION "public"."_assert_parent_warehouse_tenant"("p_parent_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_can_view_stock_locations"("p_parent_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public._can_view_parent_warehouse_stock(p_parent_tenant_id)
    or public.membership_has_module_action(p_parent_tenant_id, 'global_stock_location', 'view')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    );
$$;


ALTER FUNCTION "public"."_can_view_stock_locations"("p_parent_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_can_view_parent_warehouse_stock"("p_parent_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_parent_tenant_id)
    or public.membership_has_module_action(p_parent_tenant_id, 'global_stock', 'view')
    or exists (
      select 1
      from public.tenants child
      inner join public.memberships m on m.tenant_id = child.id
      where child.parent_id = p_parent_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and public.membership_has_module_action(child.id, 'global_stock', 'view')
    );
$$;


ALTER FUNCTION "public"."_can_view_parent_warehouse_stock"("p_parent_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_stock_location_is_leaf"("p_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select not exists (
    select 1 from public.stock_locations c
    where c.parent_location_id = p_id
      and c.is_active = true
  );
$$;


ALTER FUNCTION "public"."_stock_location_is_leaf"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."_validate_stock_location_nesting"("p_kind" "public"."stock_location_kind", "p_parent_location_id" bigint, "p_parent_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent public.stock_locations%rowtype;
begin
  if p_kind in ('shelf', 'returns') then
    if p_parent_location_id is not null then
      raise exception 'shelf and returns must be top-level (no parent)';
    end if;
    return;
  end if;

  if p_parent_location_id is null then
    raise exception '% requires a parent location', p_kind;
  end if;

  select * into v_parent
  from public.stock_locations
  where id = p_parent_location_id;

  if not found then
    raise exception 'parent location not found';
  end if;

  if v_parent.parent_tenant_id <> p_parent_tenant_id then
    raise exception 'parent location belongs to another tenant';
  end if;

  if p_kind = 'slot' then
    if v_parent.kind not in ('shelf', 'returns') then
      raise exception 'slot parent must be a shelf or returns area';
    end if;
  elsif p_kind = 'box' then
    if v_parent.kind <> 'slot' then
      raise exception 'box parent must be a slot';
    end if;
  end if;
end;
$$;


ALTER FUNCTION "public"."_validate_stock_location_nesting"("p_kind" "public"."stock_location_kind", "p_parent_location_id" bigint, "p_parent_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."add_child_line_to_parent_shipment"("p_parent_shipment_id" bigint, "p_source_type" "text", "p_source_id" bigint) RETURNS "public"."global_shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shipment public.global_shipments%ROWTYPE;
  v_costing_item public.product_based_costing_items%ROWTYPE;
  v_costing_file public.product_based_costing_files%ROWTYPE;
  v_shop_order_item public.shop_order_items%ROWTYPE;
  v_prod RECORD;
  v_child_tenant_id bigint;
  v_row public.global_shipment_items%ROWTYPE;
BEGIN
  SELECT * INTO v_shipment
  FROM public.global_shipments
  WHERE id = p_parent_shipment_id;

  IF v_shipment.id IS NULL THEN
    RAISE EXCEPTION 'parent shipment % not found', p_parent_shipment_id;
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) THEN
    RAISE EXCEPTION 'access denied for parent shipment tenant %', v_shipment.parent_tenant_id;
  END IF;

  IF p_source_type = 'costing_item' THEN
    SELECT * INTO v_costing_item
    FROM public.product_based_costing_items
    WHERE id = p_source_id;

    IF v_costing_item.id IS NULL THEN
      RAISE EXCEPTION 'costing item % not found', p_source_id;
    END IF;

    SELECT * INTO v_costing_file
    FROM public.product_based_costing_files
    WHERE id = v_costing_item.product_based_costing_file_id;

    IF v_costing_file.id IS NULL THEN
      RAISE EXCEPTION 'costing file % not found', v_costing_item.product_based_costing_file_id;
    END IF;

    IF v_costing_file.status <> 'ready_for_shipment' THEN
      RAISE EXCEPTION 'costing file must be in ready_for_shipment status to pull items';
    END IF;

    IF coalesce(v_costing_item.confirmed_quantity, v_costing_item.quantity::integer, 0) <= 0 THEN
      RAISE EXCEPTION 'costing item confirmed quantity must be greater than 0';
    END IF;

    IF v_costing_item.assigned_shipment_id IS NOT NULL THEN
      RAISE EXCEPTION 'costing item is already assigned to a shipment';
    END IF;

    IF v_costing_item.product_id IS NULL THEN
      RAISE EXCEPTION 'costing item must have a product_id to add to shipment';
    END IF;

    v_child_tenant_id := v_costing_file.tenant_id;

    SELECT product_weight, package_weight INTO v_prod
    FROM public.products
    WHERE id = v_costing_item.product_id;

    INSERT INTO public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    VALUES (
      p_parent_shipment_id,
      v_costing_item.product_id,
      v_costing_item.name,
      greatest(coalesce(v_costing_item.confirmed_quantity, v_costing_item.quantity::integer, 0), 0),
      v_costing_item.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(v_costing_item.price_gbp, 0.00),
      coalesce(v_costing_item.product_weight::numeric, v_prod.product_weight, 0.00),
      coalesce(v_costing_item.package_weight::numeric, v_prod.package_weight, 0.00),
      v_costing_item.barcode,
      v_costing_item.product_code,
      v_child_tenant_id,
      'costing_item',
      v_costing_item.id
    )
    RETURNING * INTO v_row;

    UPDATE public.product_based_costing_items
    SET assigned_shipment_id = p_parent_shipment_id
    WHERE id = p_source_id;

  ELSIF p_source_type = 'shop_order_item' THEN
    SELECT o.tenant_id INTO v_child_tenant_id
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    WHERE oi.id = p_source_id;

    SELECT * INTO v_shop_order_item
    FROM public.shop_order_items
    WHERE id = p_source_id;

    IF v_shop_order_item.id IS NULL THEN
      RAISE EXCEPTION 'shop order item % not found', p_source_id;
    END IF;

    IF v_shop_order_item.product_id IS NULL THEN
      RAISE EXCEPTION 'shop order item must have a product_id to add to shipment';
    END IF;

    SELECT product_weight, package_weight INTO v_prod
    FROM public.products
    WHERE id = v_shop_order_item.product_id;

    INSERT INTO public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    VALUES (
      p_parent_shipment_id,
      v_shop_order_item.product_id,
      v_shop_order_item.title,
      v_shop_order_item.quantity,
      v_shop_order_item.image_url,
      'order'::public.global_shipment_item_add_method,
      v_shop_order_item.unit_price,
      coalesce(v_shop_order_item.product_weight::numeric, v_prod.product_weight, 0.00),
      coalesce(v_shop_order_item.package_weight::numeric, v_prod.package_weight, 0.00),
      v_shop_order_item.sku,
      v_shop_order_item.sku,
      v_child_tenant_id,
      'shop_order_item',
      v_shop_order_item.id
    )
    RETURNING * INTO v_row;

    UPDATE public.shop_order_items
    SET procurement_pulled = true
    WHERE id = p_source_id;
  ELSE
    RAISE EXCEPTION 'invalid source_type %', p_source_type;
  END IF;

  RETURN v_row;
END;
$$;


ALTER FUNCTION "public"."add_child_line_to_parent_shipment"("p_parent_shipment_id" bigint, "p_source_type" "text", "p_source_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_pbc_backlog_to_costing_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) RETURNS SETOF bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (
    public.can_admin_manage_costing_file(v_file.tenant_id)
    OR public.can_staff_access_costing_file(v_file.tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.billing_profile_id IS NULL THEN
    RAISE EXCEPTION 'costing file % must have a billing_profile_id assigned before consuming backlog', p_file_id;
  END IF;

  IF p_backlog_ids IS NULL OR array_length(p_backlog_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOR v_backlog IN
    SELECT *
    FROM public.product_based_costing_backlog_items
    WHERE id = ANY(p_backlog_ids)
      AND tenant_id = v_file.tenant_id
      AND billing_profile_id = v_file.billing_profile_id
  LOOP
    INSERT INTO public.product_based_costing_items (
      product_based_costing_file_id,
      product_id,
      name,
      image_url,
      quantity,
      confirmed_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      v_backlog.open_quantity,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    RETURN NEXT v_new_item_id;
  END LOOP;

  RETURN;
END;
$$;


ALTER FUNCTION "public"."add_pbc_backlog_to_costing_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_pbc_backlog_to_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) RETURNS bigint[]
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
  v_added_ids bigint[] := ARRAY[]::bigint[];
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (
    public.can_admin_manage_costing_file(v_file.tenant_id)
    OR public.can_staff_access_costing_file(v_file.tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.billing_profile_id IS NULL THEN
    RAISE EXCEPTION 'costing file % must have a billing_profile_id assigned before consuming backlog', p_file_id;
  END IF;

  IF p_backlog_ids IS NULL OR array_length(p_backlog_ids, 1) IS NULL THEN
    RETURN v_added_ids;
  END IF;

  FOR v_backlog IN
    SELECT *
    FROM public.product_based_costing_backlog_items
    WHERE id = ANY(p_backlog_ids)
      AND tenant_id = v_file.tenant_id
      AND billing_profile_id = v_file.billing_profile_id
  LOOP
    INSERT INTO public.product_based_costing_items (
      product_based_costing_file_id,
      product_id,
      name,
      image_url,
      quantity,
      confirmed_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      v_backlog.open_quantity,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    v_added_ids := array_append(v_added_ids, v_new_item_id);
  END LOOP;

  RETURN v_added_ids;
END;
$$;


ALTER FUNCTION "public"."add_pbc_backlog_to_file"("p_file_id" bigint, "p_backlog_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_shipment_item_from_product"("p_shipment_id" bigint, "p_product_id" bigint, "p_quantity" integer) RETURNS "public"."shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
  v_parent bigint;
  v_product record;
  v_quantity integer;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_parent := public.resolve_parent_tenant_id(v_tenant_id);

  v_quantity := coalesce(p_quantity, 0);
  if v_quantity <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  select
    p.id,
    p.name,
    p.barcode,
    p.product_code,
    p.image_url,
    p.product_weight,
    p.package_weight,
    coalesce(p.list_price_amount, 0) as price_gbp
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.parent_tenant_id = v_parent;

  if v_product.id is null then
    raise exception 'product not found';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp
  )
  values (
    p_shipment_id,
    v_product.name,
    v_quantity,
    v_product.barcode,
    v_product.product_code,
    v_product.id,
    v_product.image_url,
    v_product.product_weight,
    v_product.package_weight,
    v_product.price_gbp
  )
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."add_shipment_item_from_product"("p_shipment_id" bigint, "p_product_id" bigint, "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_shipment_item_manual"("p_shipment_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_quantity" integer DEFAULT NULL::integer, "p_barcode" "text" DEFAULT NULL::"text", "p_product_code" "text" DEFAULT NULL::"text", "p_product_id" bigint DEFAULT NULL::bigint, "p_image_url" "text" DEFAULT NULL::"text", "p_product_weight" numeric DEFAULT NULL::numeric, "p_package_weight" numeric DEFAULT NULL::numeric, "p_price_gbp" numeric DEFAULT NULL::numeric, "p_receiving_splits" "jsonb" DEFAULT NULL::"jsonb", "p_cost_bdt" numeric DEFAULT NULL::numeric) RETURNS "public"."shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp,
    receiving_splits,
    cost_bdt
  )
  values (
    p_shipment_id,
    nullif(trim(coalesce(p_name, '')), ''),
    greatest(coalesce(p_quantity, 0), 0),
    nullif(trim(coalesce(p_barcode, '')), ''),
    nullif(trim(coalesce(p_product_code, '')), ''),
    p_product_id,
    nullif(trim(coalesce(p_image_url, '')), ''),
    p_product_weight,
    p_package_weight,
    p_price_gbp,
    p_receiving_splits,
    p_cost_bdt
  )
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."add_shipment_item_manual"("p_shipment_id" bigint, "p_name" "text", "p_quantity" integer, "p_barcode" "text", "p_product_code" "text", "p_product_id" bigint, "p_image_url" "text", "p_product_weight" numeric, "p_package_weight" numeric, "p_price_gbp" numeric, "p_receiving_splits" "jsonb", "p_cost_bdt" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_shipment_item_manual"("p_shipment_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_quantity" integer DEFAULT NULL::integer, "p_barcode" "text" DEFAULT NULL::"text", "p_product_code" "text" DEFAULT NULL::"text", "p_product_id" bigint DEFAULT NULL::bigint, "p_image_url" "text" DEFAULT NULL::"text", "p_product_weight" numeric DEFAULT NULL::numeric, "p_package_weight" numeric DEFAULT NULL::numeric, "p_price_gbp" numeric DEFAULT NULL::numeric, "p_received_quantity" integer DEFAULT NULL::integer, "p_damaged_quantity" integer DEFAULT NULL::integer, "p_stolen_quantity" integer DEFAULT NULL::integer) RETURNS "public"."shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp,
    received_quantity,
    damaged_quantity,
    stolen_quantity
  )
  values (
    p_shipment_id,
    nullif(trim(coalesce(p_name, '')), ''),
    greatest(coalesce(p_quantity, 0), 0),
    nullif(trim(coalesce(p_barcode, '')), ''),
    nullif(trim(coalesce(p_product_code, '')), ''),
    p_product_id,
    nullif(trim(coalesce(p_image_url, '')), ''),
    p_product_weight,
    p_package_weight,
    p_price_gbp,
    greatest(coalesce(p_received_quantity, 0), 0),
    greatest(coalesce(p_damaged_quantity, 0), 0),
    greatest(coalesce(p_stolen_quantity, 0), 0)
  )
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."add_shipment_item_manual"("p_shipment_id" bigint, "p_name" "text", "p_quantity" integer, "p_barcode" "text", "p_product_code" "text", "p_product_id" bigint, "p_image_url" "text", "p_product_weight" numeric, "p_package_weight" numeric, "p_price_gbp" numeric, "p_received_quantity" integer, "p_damaged_quantity" integer, "p_stolen_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_stock_movement_line"("p_movement_id" bigint, "p_stock_id" bigint, "p_quantity" numeric, "p_from_location_id" bigint DEFAULT NULL::bigint, "p_to_location_id" bigint DEFAULT NULL::bigint, "p_from_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_to_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_from_grade_tag_id" bigint DEFAULT NULL::bigint, "p_to_grade_tag_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
begin
  select * into v_mov from public.stock_movements where id = p_movement_id for update;
  if not found then
    raise exception 'movement not found';
  end if;
  if v_mov.is_posted then
    raise exception 'movement already posted';
  end if;
  if not public.has_active_tenant_membership(v_mov.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;
  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be positive';
  end if;

  insert into public.stock_movement_lines (
    movement_id, stock_id, from_location_id, to_location_id,
    from_availability, to_availability, from_grade_tag_id, to_grade_tag_id, quantity
  ) values (
    p_movement_id, p_stock_id, p_from_location_id, p_to_location_id,
    p_from_availability, p_to_availability, p_from_grade_tag_id, p_to_grade_tag_id, p_quantity
  )
  returning * into v_line;

  return jsonb_build_object('line', to_jsonb(v_line));
end;
$$;


ALTER FUNCTION "public"."add_stock_movement_line"("p_movement_id" bigint, "p_stock_id" bigint, "p_quantity" numeric, "p_from_location_id" bigint, "p_to_location_id" bigint, "p_from_availability" "public"."stock_availability", "p_to_availability" "public"."stock_availability", "p_from_grade_tag_id" bigint, "p_to_grade_tag_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_costing_item_calculations"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cargo_rate_1kg numeric(12,2);
  v_cargo_rate_2kg numeric(12,2);
  v_conversion_rate numeric(12,2);
  v_admin_profit_rate numeric(12,2);
  v_total_weight integer;
  v_auxiliary_price_gbp numeric(12,2);
  v_item_price_gbp numeric(12,2);
  v_cargo_rate numeric(12,2);
  v_costing_price_gbp numeric(12,2);
  v_costing_price_bdt integer;
  v_calculated_offer_price_bdt integer;
begin
  select
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate
  into
    v_cargo_rate_1kg,
    v_cargo_rate_2kg,
    v_conversion_rate,
    v_admin_profit_rate
  from public.costing_files cf
  where cf.id = new.costing_file_id;

  v_total_weight := coalesce(new.product_weight, 0) + coalesce(new.package_weight, 0);
  v_auxiliary_price_gbp := public.calculate_costing_auxiliary_price_gbp(
    new.price_in_web_gbp,
    new.delivery_price_gbp
  )::numeric(12,2);

  v_item_price_gbp := round(
    (
      coalesce(new.price_in_web_gbp, 0)
      + coalesce(new.delivery_price_gbp, 0)
      + coalesce(v_auxiliary_price_gbp, 0)
    )::numeric,
    2
  );

  if coalesce(new.cargo_rate_is_manual, false) and new.cargo_rate is not null then
    v_cargo_rate := round(new.cargo_rate::numeric, 2);
  elsif v_item_price_gbp > 10 then
    v_cargo_rate := coalesce(v_cargo_rate_2kg, 0);
  else
    v_cargo_rate := coalesce(v_cargo_rate_1kg, 0);
  end if;

  v_cargo_rate := round(v_cargo_rate::numeric, 2);

  v_costing_price_gbp := round(
    (
      coalesce(v_item_price_gbp, 0)
      + (coalesce(v_total_weight, 0) / 1000.0) * coalesce(v_cargo_rate, 0)
    )::numeric,
    2
  );

  v_costing_price_bdt := public.round_bdt_up_to_zero_or_five(
    coalesce(v_costing_price_gbp, 0) * coalesce(v_conversion_rate, 0)
  );

  v_calculated_offer_price_bdt := public.round_bdt_up_to_zero_or_five(
    v_costing_price_bdt + (v_costing_price_bdt * coalesce(v_admin_profit_rate, 0) / 100.0)
  );

  new.auxiliary_price_gbp := v_auxiliary_price_gbp;
  new.item_price_gbp := v_item_price_gbp;
  new.cargo_rate := v_cargo_rate;
  new.costing_price_gbp := v_costing_price_gbp;
  new.costing_price_bdt := v_costing_price_bdt;
  new.offer_price_bdt := coalesce(new.offer_price_override_bdt, v_calculated_offer_price_bdt);

  return new;
end;
$$;


ALTER FUNCTION "public"."apply_costing_item_calculations"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_global_shipment_purchase_balance"("p_shipment_id" bigint, "p_adjustments" "jsonb", "p_transaction_rate" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_shipment public.global_shipments%rowtype;
  v_adjustment_count int;
  v_valid_count int;
  v_estimated_total numeric;
  v_actual_total numeric;
begin
  if p_adjustments is null or jsonb_typeof(p_adjustments) <> 'array' or jsonb_array_length(p_adjustments) = 0 then
    raise exception 'At least one purchase price adjustment is required.';
  end if;

  select *
  into v_shipment
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'Shipment not found.';
  end if;

  -- Invoice target = Σ product cost-entry amounts (v2); not header purchase_invoice_total
  select coalesce(sum(e.amount), 0)
  into v_actual_total
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type = 'product';

  if v_actual_total <= 0 then
    raise exception 'Product cost entry amount must be saved before applying purchase price balance.';
  end if;

  select count(*)
  into v_adjustment_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, purchase_price numeric);

  select count(*)
  into v_valid_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, purchase_price numeric)
  inner join public.global_shipment_items gsi
    on gsi.id = a.item_id
   and gsi.shipment_id = p_shipment_id;

  if v_adjustment_count <> v_valid_count then
    raise exception 'One or more adjustment rows do not belong to this shipment.';
  end if;

  update public.global_shipment_items gsi
  set
    purchase_price = adj.purchase_price,
    updated_at = now()
  from jsonb_to_recordset(p_adjustments) as adj(item_id bigint, purchase_price numeric)
  where gsi.id = adj.item_id
    and gsi.shipment_id = p_shipment_id;

  -- Touch shipment updated_at only — do not write transaction_rate (p_transaction_rate ignored)
  update public.global_shipments
  set updated_at = now()
  where id = p_shipment_id;

  select coalesce(
    sum(gsi.purchase_price * gsi.ordered_quantity),
    0
  )
  into v_estimated_total
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'estimated_total', v_estimated_total,
    'actual_total', v_actual_total,
    'delta_total', v_actual_total - v_estimated_total
  );
end;
$$;


ALTER FUNCTION "public"."apply_global_shipment_purchase_balance"("p_shipment_id" bigint, "p_adjustments" "jsonb", "p_transaction_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_global_shipment_weight_balance"("p_shipment_id" bigint, "p_adjustments" "jsonb", "p_transaction_rate" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_shipment public.global_shipments%rowtype;
  v_adjustment_count int;
  v_valid_count int;
  v_estimated_kg numeric;
  v_actual_kg numeric;
begin
  if p_adjustments is null or jsonb_typeof(p_adjustments) <> 'array' or jsonb_array_length(p_adjustments) = 0 then
    raise exception 'At least one package weight adjustment is required.';
  end if;

  select *
  into v_shipment
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'Shipment not found.';
  end if;

  v_actual_kg := round(coalesce(v_shipment.received_weight, 0), 2);

  if v_actual_kg <= 0 then
    raise exception 'Cargo Invoice Weight must be saved before applying weight balance.';
  end if;

  select count(*)
  into v_adjustment_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, package_weight numeric);

  select count(*)
  into v_valid_count
  from jsonb_to_recordset(p_adjustments) as a(item_id bigint, package_weight numeric)
  inner join public.global_shipment_items gsi
    on gsi.id = a.item_id
   and gsi.shipment_id = p_shipment_id;

  if v_adjustment_count <> v_valid_count then
    raise exception 'One or more adjustment rows do not belong to this shipment.';
  end if;

  update public.global_shipment_items gsi
  set
    package_weight = adj.package_weight,
    updated_at = now()
  from jsonb_to_recordset(p_adjustments) as adj(item_id bigint, package_weight numeric)
  where gsi.id = adj.item_id
    and gsi.shipment_id = p_shipment_id;

  update public.products p
  set
    package_weight = adj.package_weight,
    updated_at = now()
  from jsonb_to_recordset(p_adjustments) as adj(item_id bigint, package_weight numeric)
  inner join public.global_shipment_items gsi
    on gsi.id = adj.item_id
   and gsi.shipment_id = p_shipment_id
  where p.id = gsi.product_id
    and gsi.product_id is not null;

  -- Touch shipment updated_at only — do not write transaction_rate (p_transaction_rate ignored)
  update public.global_shipments
  set updated_at = now()
  where id = p_shipment_id;

  select coalesce(
    sum((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity),
    0
  ) / 1000.0
  into v_estimated_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'estimated_kg', v_estimated_kg,
    'actual_kg', v_actual_kg,
    'delta_kg', v_actual_kg - v_estimated_kg
  );
end;
$$;


ALTER FUNCTION "public"."apply_global_shipment_weight_balance"("p_shipment_id" bigint, "p_adjustments" "jsonb", "p_transaction_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_shipment_progress_flow"("p_flow_id" bigint, "p_archive" boolean DEFAULT true) RETURNS "public"."shipment_progress_flows"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_archive = true and exists (
    select 1 from public.global_shipments gs
    where gs.progress_flow_id = p_flow_id
  ) then
    raise exception 'flow is in use by one or more shipments and cannot be archived';
  end if;

  update public.shipment_progress_flows
  set
    is_active = not p_archive,
    is_default = case when p_archive then false else is_default end
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$$;


ALTER FUNCTION "public"."archive_shipment_progress_flow"("p_flow_id" bigint, "p_archive" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_shipment_progress_flow_stage"("p_flow_stage_id" bigint, "p_archive" boolean DEFAULT true) RETURNS TABLE("flow_stage_id" bigint, "flow_id" bigint, "tag_id" bigint, "sort_order" integer, "name" "text", "slug" "text", "color" "text", "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stage public.shipment_progress_flow_stages;
  v_flow public.shipment_progress_flows;
  v_tag public.tags;
begin
  select * into v_stage
  from public.shipment_progress_flow_stages
  where id = p_flow_stage_id
  for update;

  if not found then
    raise exception 'flow stage not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = v_stage.flow_id;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_archive = true and exists (
    select 1
    from public.global_shipments gs
    where gs.progress_tag_id = v_stage.tag_id
  ) then
    raise exception 'stage is in use by one or more shipments and cannot be archived';
  end if;

  update public.tags
  set is_active = not p_archive
  where id = v_stage.tag_id
  returning * into v_tag;

  return query
  select
    v_stage.id,
    v_stage.flow_id,
    v_stage.tag_id,
    v_stage.sort_order,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active;
end;
$$;


ALTER FUNCTION "public"."archive_shipment_progress_flow_stage"("p_flow_stage_id" bigint, "p_archive" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."archive_shipment_progress_tag"("p_tag_id" bigint, "p_archive" boolean DEFAULT true) RETURNS "public"."tags"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tag public.tags;
  v_result public.tags;
begin
  select * into v_tag
  from public.tags
  where id = p_tag_id
  for update;

  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag is not a shipment_progress tag';
  end if;

  if not public.has_active_tenant_membership(v_tag.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_archive = true then
    if exists (
      select 1
      from public.global_shipments gs
      where gs.progress_tag_id = p_tag_id
    ) then
      raise exception 'tag is in use by one or more shipments and cannot be archived';
    end if;
  end if;

  update public.tags
  set is_active = not p_archive
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."archive_shipment_progress_tag"("p_tag_id" bigint, "p_archive" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_shipment_to_child"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_child_exists boolean;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
    and parent_tenant_id = p_parent_tenant_id
  for update;

  if not found then
    raise exception 'shipment not found or tenant mismatch';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before assignment';
  end if;

  if not public.has_active_tenant_membership(p_parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_child_tenant_id is not null then
    select exists(
      select 1 from public.tenants t
      where t.id = p_child_tenant_id
        and (t.id = p_parent_tenant_id or t.parent_id = p_parent_tenant_id)
    ) into v_child_exists;

    if not v_child_exists then
      raise exception 'invalid child tenant for this parent';
    end if;
  end if;

  update public.global_shipments
  set assigned_child_tenant_id = p_child_tenant_id,
      updated_at = now()
  where id = p_shipment_id;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'assigned_child_tenant_id', p_child_tenant_id
  );
end;
$$;


ALTER FUNCTION "public"."assign_shipment_to_child"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."assign_tenant_shipment_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.tenant_id is null then
    raise exception 'tenant_id is required for shipments';
  end if;

  if tg_op = 'UPDATE' and new.tenant_id <> old.tenant_id then
    raise exception 'changing shipment tenant_id is not allowed';
  end if;

  if new.tenant_shipment_id is null then
    new.tenant_shipment_id := public.next_tenant_scoped_counter(new.tenant_id, 'shipment');
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."assign_tenant_shipment_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_add_global_shipment_items"("p_shipment_id" bigint, "p_items" "jsonb") RETURNS SETOF "public"."global_shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item jsonb;
  v_next_sort integer;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select coalesce(max(sort_order), 0) + 10
  into v_next_sort
  from public.global_shipment_items
  where shipment_id = p_shipment_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into public.global_shipment_items (
      shipment_id,
      section_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id,
      sort_order
    )
    values (
      p_shipment_id,
      nullif((v_item->>'section_id'), '')::bigint,
      nullif((v_item->>'product_id'), '')::bigint,
      nullif((v_item->>'vendor_id'), '')::bigint,
      coalesce(v_item->>'name', 'Unnamed Item'),
      greatest(1, coalesce((v_item->>'ordered_quantity')::integer, 1)),
      v_item->>'image_url',
      coalesce((v_item->>'add_method')::public.global_shipment_item_add_method, 'manual'::public.global_shipment_item_add_method),
      greatest(0, coalesce((v_item->>'purchase_price')::numeric, 0)),
      greatest(0, coalesce((v_item->>'product_weight')::numeric, 0)),
      greatest(0, coalesce((v_item->>'package_weight')::numeric, 0)),
      v_item->>'barcode',
      v_item->>'product_code',
      nullif((v_item->>'source_child_tenant_id'), '')::bigint,
      v_item->>'source_type',
      nullif((v_item->>'source_id'), '')::bigint,
      coalesce((v_item->>'sort_order')::integer, v_next_sort)
    );

    v_next_sort := v_next_sort + 10;
  end loop;

  return query
  select *
  from public.global_shipment_items
  where shipment_id = p_shipment_id
  order by sort_order asc, id asc;
end;
$$;


ALTER FUNCTION "public"."bulk_add_global_shipment_items"("p_shipment_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_add_shipment_items_from_product_ids"("p_shipment_id" bigint, "p_items" "jsonb") RETURNS SETOF "public"."shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_entry jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_row public.shipment_items;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a json array';
  end if;

  for v_entry in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(trim(coalesce(v_entry ->> 'product_id', '')), '')::bigint;
    v_quantity := coalesce(nullif(trim(coalesce(v_entry ->> 'quantity', '')), '')::integer, 0);

    if v_product_id is null or v_quantity <= 0 then
      continue;
    end if;

    select * into v_row
    from public.add_shipment_item_from_product(
      p_shipment_id,
      v_product_id,
      v_quantity
    );

    return next v_row;
  end loop;

  return;
end;
$$;


ALTER FUNCTION "public"."bulk_add_shipment_items_from_product_ids"("p_shipment_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_allocate_shipment_stock"("p_parent_tenant_id" bigint, "p_shipment_id" bigint, "p_child_tenant_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_rec record;
  v_updated_count integer := 0;
  v_other_allocated_sum integer;
  v_remaining_qty integer;
begin
  -- Verify child tenant belongs to parent
  if not exists (
    select 1 from public.tenants
    where id = p_child_tenant_id and parent_id = p_parent_tenant_id
  ) then
    raise exception 'Child tenant % does not belong to parent tenant %', p_child_tenant_id, p_parent_tenant_id;
  end if;

  -- Loop through all ready sellable stocks in the given shipment batch
  for v_rec in
    select
      gs.id as stock_id,
      gs.quantity as pool_qty
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    where gs.parent_tenant_id = p_parent_tenant_id
      and gship.id = p_shipment_id
      and gship.status = 'received'
      and gst.is_sellable = true
  loop
    -- Calculate sum allocated to OTHER child tenants
    select coalesce(sum(quantity), 0)::integer into v_other_allocated_sum
    from public.global_stock_allocations
    where stock_id = v_rec.stock_id
      and child_tenant_id <> p_child_tenant_id;

    -- Calculate remaining available stock for this stock pool
    v_remaining_qty := greatest(v_rec.pool_qty - v_other_allocated_sum, 0);

    if v_remaining_qty > 0 then
      -- Upsert global_stock_allocations for target child tenant
      insert into public.global_stock_allocations (parent_tenant_id, child_tenant_id, stock_id, quantity)
      values (p_parent_tenant_id, p_child_tenant_id, v_rec.stock_id, v_remaining_qty)
      on conflict (child_tenant_id, stock_id)
      do update set quantity = v_remaining_qty, updated_at = now();

      v_updated_count := v_updated_count + 1;
    end if;
  end loop;

  return v_updated_count;
end;
$$;


ALTER FUNCTION "public"."bulk_allocate_shipment_stock"("p_parent_tenant_id" bigint, "p_shipment_id" bigint, "p_child_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_allocate_shipment_stock"("p_shipment_id" bigint, "p_child_tenant_id" bigint, "p_allocations" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return jsonb_build_object('status', 'retired');
end;
$$;


ALTER FUNCTION "public"."bulk_allocate_shipment_stock"("p_shipment_id" bigint, "p_child_tenant_id" bigint, "p_allocations" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_delete_shipment_items_by_product_id"("p_shipment_id" bigint, "p_items" "jsonb") RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_entry jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_item_id bigint;
  v_deleted_count integer := 0;
begin
  if not public.can_manage_shipment_by_id(p_shipment_id) then
    raise exception 'not allowed';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a json array';
  end if;

  for v_entry in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(trim(coalesce(v_entry ->> 'product_id', '')), '')::bigint;
    v_quantity := coalesce(nullif(trim(coalesce(v_entry ->> 'quantity', '')), '')::integer, 0);

    if v_product_id is null or v_quantity <= 0 then
      continue;
    end if;

    select id into v_item_id
    from public.shipment_items
    where shipment_id = p_shipment_id
      and product_id = v_product_id;

    if v_item_id is null then
      continue;
    end if;

    perform public.delete_shipment_item_quantity(v_item_id, v_quantity);
    v_deleted_count := v_deleted_count + 1;
  end loop;

  return v_deleted_count;
end;
$$;


ALTER FUNCTION "public"."bulk_delete_shipment_items_by_product_id"("p_shipment_id" bigint, "p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_update_global_shipment_items"("p_shipment_id" bigint, "p_updates" "jsonb") RETURNS SETOF "public"."global_shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_update jsonb;
  v_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  for v_update in select * from jsonb_array_elements(p_updates)
  loop
    v_id := (v_update->>'id')::bigint;
    if v_id is not null then
      update public.global_shipment_items
      set
        section_id = case
          when v_update ? 'section_id' then nullif((v_update->>'section_id'), '')::bigint
          else section_id
        end,
        vendor_id = case
          when v_update ? 'vendor_id' then nullif((v_update->>'vendor_id'), '')::bigint
          else vendor_id
        end,
        ordered_quantity = case
          when v_update ? 'ordered_quantity' and (v_update->>'ordered_quantity') is not null then greatest(1, (v_update->>'ordered_quantity')::integer)
          else ordered_quantity
        end,
        purchase_price = case
          when v_update ? 'purchase_price' and (v_update->>'purchase_price') is not null then greatest(0, (v_update->>'purchase_price')::numeric)
          else purchase_price
        end,
        product_weight = case
          when v_update ? 'product_weight' and (v_update->>'product_weight') is not null then greatest(0, (v_update->>'product_weight')::numeric)
          else product_weight
        end,
        package_weight = case
          when v_update ? 'package_weight' and (v_update->>'package_weight') is not null then greatest(0, (v_update->>'package_weight')::numeric)
          else package_weight
        end,
        barcode = case
          when v_update ? 'barcode' then v_update->>'barcode'
          else barcode
        end,
        product_code = case
          when v_update ? 'product_code' then v_update->>'product_code'
          else product_code
        end,
        name = case
          when v_update ? 'name' and (v_update->>'name') is not null then v_update->>'name'
          else name
        end,
        updated_at = now()
      where id = v_id and shipment_id = p_shipment_id;
    end if;
  end loop;

  return query
  select *
  from public.global_shipment_items
  where shipment_id = p_shipment_id
  order by sort_order asc, id asc;
end;
$$;


ALTER FUNCTION "public"."bulk_update_global_shipment_items"("p_shipment_id" bigint, "p_updates" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_costing_auxiliary_price_gbp"("p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_base_price_gbp numeric(12,2);
begin
  v_base_price_gbp := round((coalesce(p_price_in_web_gbp, 0) + coalesce(p_delivery_price_gbp, 0))::numeric, 2);

  if v_base_price_gbp <= 10 then
    return 0;
  end if;

  if v_base_price_gbp <= 100 then
    return 2;
  end if;

  return round((2 + ceil((v_base_price_gbp - 100) / 50.0))::numeric, 2);
end;
$$;


ALTER FUNCTION "public"."calculate_costing_auxiliary_price_gbp"("p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_costing_item_type_surcharge_gbp"("p_item_type" "text") RETURNS numeric
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_normalized_type text;
begin
  v_normalized_type := lower(trim(coalesce(p_item_type, '')));

  if v_normalized_type in ('watch', 'perfume') then
    return 3;
  end if;

  return 0;
end;
$$;


ALTER FUNCTION "public"."calculate_costing_item_type_surcharge_gbp"("p_item_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
$$;


ALTER FUNCTION "public"."can_admin_manage_costing_file"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.is_customer_group_member(p_customer_group_id)
$$;


ALTER FUNCTION "public"."can_customer_access_costing_file"("p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_costing"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
$$;


ALTER FUNCTION "public"."can_manage_costing"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.can_admin_manage_costing_file(p_tenant_id);
$$;


ALTER FUNCTION "public"."can_manage_costing_file_viewers"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_manage_costing(f.tenant_id)
  )
$$;


ALTER FUNCTION "public"."can_manage_costing_item"("p_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_shipment"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
$$;


ALTER FUNCTION "public"."can_manage_shipment"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_manage_shipment_by_id"("p_shipment_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.shipments s
    where s.id = p_shipment_id
      and public.can_manage_shipment(s.tenant_id)
  )
$$;


ALTER FUNCTION "public"."can_manage_shipment_by_id"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.is_tenant_staff(p_tenant_id)
$$;


ALTER FUNCTION "public"."can_staff_access_costing_file"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status::text in ('po_placed', 'completed')
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or cf.status = 'draft'
            or public.is_customer_group_admin_or_negotiator(cf.customer_group_id)
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$$;


ALTER FUNCTION "public"."can_view_costing_file"("p_costing_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          public.is_assigned_costing_file_viewer(cf.id)
          and cf.status::text in ('po_placed', 'completed')
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            lower(trim(cf.created_by_email)) = public.current_user_email()
            or cf.status = 'draft'
            or public.is_customer_group_admin_or_negotiator(cf.customer_group_id)
            or (
              cf.status = 'offered'
              and public.is_internal_costing_file_creator(cf.tenant_id, cf.created_by_email)
            )
          )
        )
      )
  );
$$;


ALTER FUNCTION "public"."can_view_costing_file_items"("p_costing_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_costing_internal"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE
    AS $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff', 'viewer')
    )
$$;


ALTER FUNCTION "public"."can_view_costing_internal"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.product_based_costing_files f
    where f.id = p_file_id
      and public.can_view_costing_internal(f.tenant_id)
  )
$$;


ALTER FUNCTION "public"."can_view_costing_item"("p_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select count(*)
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      p_customer_group_id is null
      or cf.customer_group_id = p_customer_group_id
    )
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and p_tenant_id is null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  );
$$;


ALTER FUNCTION "public"."count_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."count_search_stock_network"("p_context_tenant_id" bigint, "p_mode" "text" DEFAULT 'search'::"text", "p_search" "text" DEFAULT NULL::"text", "p_search_field" "text" DEFAULT NULL::"text", "p_product_id" bigint DEFAULT NULL::bigint, "p_status" "text" DEFAULT 'excellent'::"text", "p_shipment_id" bigint DEFAULT NULL::bigint, "p_exclude_zero_qty" boolean DEFAULT true) RETURNS bigint
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_count bigint;
begin
  select count(*)::bigint into v_count
  from public.search_stock_network(
    p_context_tenant_id := p_context_tenant_id,
    p_mode := p_mode,
    p_search := p_search,
    p_search_field := p_search_field,
    p_product_id := p_product_id,
    p_status := p_status,
    p_shipment_id := p_shipment_id,
    p_exclude_zero_qty := p_exclude_zero_qty,
    p_limit := 100000,
    p_offset := 0
  );
  return coalesce(v_count, 0);
end;
$$;


ALTER FUNCTION "public"."count_search_stock_network"("p_context_tenant_id" bigint, "p_mode" "text", "p_search" "text", "p_search_field" "text", "p_product_id" bigint, "p_status" "text", "p_shipment_id" bigint, "p_exclude_zero_qty" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_and_post_stock_movement"("p_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer, "p_to_location_id" bigint DEFAULT NULL::bigint, "p_to_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_to_grade_tag_id" bigint DEFAULT NULL::bigint, "p_movement_type" "public"."stock_movement_type" DEFAULT 'grade_change'::"public"."stock_movement_type", "p_notes" "text" DEFAULT NULL::"text", "p_reference_type" "text" DEFAULT NULL::"text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stock public.global_stocks%rowtype;
  v_mov_id bigint;
  v_mov_no text;
  v_is_customer_return boolean;
begin
  if not public.can_act_on_parent_tenant_stock(p_tenant_id) then
    raise exception 'not authorized';
  end if;

  select * into v_stock
  from public.global_stocks
  where id = p_stock_id
    and parent_tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'stock % not found', p_stock_id;
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be > 0';
  end if;

  v_is_customer_return := (
    p_movement_type = 'return_inbound'::public.stock_movement_type
    and coalesce(p_reference_type, '') is distinct from 'shipment_return'
  );

  if not v_is_customer_return and v_stock.quantity < p_quantity then
    raise exception 'insufficient stock quantity (requested %, available %)', p_quantity, v_stock.quantity;
  end if;

  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    p_tenant_id,
    v_mov_no,
    p_movement_type,
    coalesce(p_reference_type, 'global_stock'),
    coalesce(p_reference_id, p_stock_id::text),
    p_notes,
    public.current_user_email(),
    false,
    null
  )
  returning id into v_mov_id;

  insert into public.stock_movement_lines (
    movement_id,
    stock_id,
    quantity,
    from_location_id,
    to_location_id,
    from_availability,
    to_availability,
    from_grade_tag_id,
    to_grade_tag_id
  ) values (
    v_mov_id,
    p_stock_id,
    p_quantity,
    v_stock.location_id,
    case
      when v_is_customer_return then coalesce(
        p_to_location_id,
        public.default_returns_stock_location_id(p_tenant_id)
      )
      else coalesce(p_to_location_id, v_stock.location_id)
    end,
    v_stock.availability,
    case
      when v_is_customer_return then coalesce(p_to_availability, 'held'::public.stock_availability)
      else coalesce(p_to_availability, v_stock.availability)
    end,
    v_stock.grade_tag_id,
    coalesce(p_to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  );

  perform public.post_stock_movement(v_mov_id);

  return jsonb_build_object(
    'success', true,
    'movement_id', v_mov_id,
    'movement_no', v_mov_no
  );
end;
$$;


ALTER FUNCTION "public"."create_and_post_stock_movement"("p_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer, "p_to_location_id" bigint, "p_to_availability" "public"."stock_availability", "p_to_grade_tag_id" bigint, "p_movement_type" "public"."stock_movement_type", "p_notes" "text", "p_reference_type" "text", "p_reference_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") RETURNS TABLE("id" bigint, "name" "text", "market" "text", "status" "public"."costing_file_status", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or (
      public.can_customer_access_costing_file(p_customer_group_id)
      and exists (
        select 1
        from public.customer_groups cg
        where cg.id = p_customer_group_id
          and cg.tenant_id = p_tenant_id
      )
    )
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files (
      tenant_id,
      customer_group_id,
      name,
      market
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), '')
    )
    returning
      id,
      name,
      market,
      status,
      customer_group_id,
      tenant_id,
      created_by_email,
      created_at,
      updated_at;
end;
$$;


ALTER FUNCTION "public"."create_costing_file"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_name" "text", "p_market" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status" DEFAULT 'draft'::"public"."costing_file_status", "p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "market" "text", "status" "public"."costing_file_status", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "default_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
  ) then
    raise exception 'Customer group does not belong to this tenant.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or public.can_staff_access_costing_file(p_tenant_id)
    or public.can_customer_access_costing_file(p_customer_group_id)
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files as cf (
      tenant_id,
      customer_group_id,
      name,
      market,
      status
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), ''),
      coalesce(p_status, 'draft')
    )
    returning
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at;
end;
$$;


ALTER FUNCTION "public"."create_costing_file"("p_customer_group_id" bigint, "p_market" "text", "p_name" "text", "p_status" "public"."costing_file_status", "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "website_url" "text", "quantity" integer, "status" "public"."costing_file_item_status", "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with inserted as (
    insert into public.costing_file_items (
      costing_file_id,
      website_url,
      quantity
    )
    select
      cf.id,
      trim(p_website_url),
      p_quantity
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
          and lower(trim(cf.created_by_email)) = public.current_user_email()
        )
      )
    returning
      id,
      costing_file_id,
      website_url,
      quantity,
      status,
      created_by_email,
      created_at,
      updated_at
  )
  select *
  from inserted;
$$;


ALTER FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "costing_file_id" bigint, "item_type" "text", "website_url" "text", "quantity" integer, "status" "public"."costing_file_item_status", "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with inserted as (
    insert into public.costing_file_items (
      costing_file_id,
      item_type,
      website_url,
      quantity
    )
    select
      cf.id,
      nullif(trim(p_item_type), ''),
      trim(p_website_url),
      p_quantity
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
    returning
      id,
      costing_file_id,
      item_type,
      website_url,
      quantity,
      status,
      created_by_email,
      created_at,
      updated_at
  )
  select *
  from inserted;
$$;


ALTER FUNCTION "public"."create_costing_file_item_request"("p_costing_file_id" bigint, "p_website_url" "text", "p_quantity" integer, "p_item_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_shipment"("p_name" "text", "p_tenant_id" bigint, "p_shipment_type" "text" DEFAULT 'international'::"text") RETURNS "public"."shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.shipments;
  v_type text;
begin
  if not public.can_manage_shipment(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_type := lower(trim(coalesce(p_shipment_type, 'international')));
  if v_type not in ('local', 'international') then
    raise exception 'invalid shipment_type: %', p_shipment_type;
  end if;

  insert into public.shipments (name, tenant_id, shipment_type)
  values (trim(p_name), p_tenant_id, v_type)
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."create_shipment"("p_name" "text", "p_tenant_id" bigint, "p_shipment_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_shipment_draft"("p_parent_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint DEFAULT NULL::bigint, "p_cargo_company_id" bigint DEFAULT NULL::bigint) RETURNS "public"."global_shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stock_parent bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_row public.global_shipments%rowtype;
begin
  if p_parent_tenant_id is null then
    raise exception 'p_parent_tenant_id is required';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if p_type is null then
    raise exception 'type is required';
  end if;

  v_stock_parent := public.resolve_parent_tenant_id(p_parent_tenant_id);

  if not public.user_can_manage_parent_tenant(v_stock_parent) then
    raise exception 'not allowed';
  end if;

  v_vendor_id := p_vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_stock_parent);
  else
    if not exists (
      select 1
      from public.vendors v
      where v.id = v_vendor_id
        and coalesce(v.parent_tenant_id, v.tenant_id) = v_stock_parent
    ) then
      raise exception 'vendor % does not belong to parent tenant %', v_vendor_id, v_stock_parent;
    end if;
  end if;

  v_cargo_id := p_cargo_company_id;
  if v_cargo_id is null then
    v_cargo_id := public.ensure_default_cargo_company(v_stock_parent);
  else
    if not exists (
      select 1
      from public.cargo_companies c
      where c.id = v_cargo_id
        and coalesce(c.parent_tenant_id, c.tenant_id) = v_stock_parent
    ) then
      raise exception 'cargo company % does not belong to parent tenant %', v_cargo_id, v_stock_parent;
    end if;
  end if;

  insert into public.global_shipments (
    parent_tenant_id,
    name,
    type,
    vendor_id,
    cargo_company_id,
    status
  )
  values (
    v_stock_parent,
    trim(p_name),
    p_type,
    v_vendor_id,
    v_cargo_id,
    'draft'
  )
  returning * into v_row;

  -- Auto-create primary default section for this shipment
  insert into public.global_shipment_sections (
    parent_tenant_id,
    shipment_id,
    vendor_id,
    title,
    sort_order,
    metadata
  )
  values (
    v_stock_parent,
    v_row.id,
    v_vendor_id,
    'Section 1',
    0,
    '{}'::jsonb
  );

  return v_row;
end;
$$;


ALTER FUNCTION "public"."create_shipment_draft"("p_parent_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint, "p_cargo_company_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reorder_shipment_sections"("p_shipment_id" bigint, "p_section_ids" bigint[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments;
  v_idx integer;
  v_section_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_section_ids is null or array_length(p_section_ids, 1) is null then
    return;
  end if;

  for v_idx in 1..array_length(p_section_ids, 1) loop
    v_section_id := p_section_ids[v_idx];

    update public.global_shipment_sections
    set sort_order = v_idx - 1,
        updated_at = now()
    where id = v_section_id
      and shipment_id = p_shipment_id;
  end loop;
end;
$$;


ALTER FUNCTION "public"."reorder_shipment_sections"("p_shipment_id" bigint, "p_section_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_shipment_progress_flow"("p_tenant_id" bigint, "p_name" "text") RETURNS "public"."shipment_progress_flows"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_slug text;
  v_result public.shipment_progress_flows;
  v_has_default boolean;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  select exists(
    select 1
    from public.shipment_progress_flows
    where tenant_id = p_tenant_id
      and is_default = true
  ) into v_has_default;

  insert into public.shipment_progress_flows (
    tenant_id, name, slug, is_active, is_default
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_slug,
    true,
    not v_has_default
  )
  returning * into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."create_shipment_progress_flow"("p_tenant_id" bigint, "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_shipment_progress_flow_stage"("p_flow_id" bigint, "p_name" "text", "p_color" "text" DEFAULT '#64748b'::"text", "p_sort_order" integer DEFAULT NULL::integer) RETURNS TABLE("flow_stage_id" bigint, "flow_id" bigint, "tag_id" bigint, "sort_order" integer, "name" "text", "slug" "text", "color" "text", "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
#variable_conflict use_column
declare
  v_flow public.shipment_progress_flows;
  v_slug text;
  v_tag public.tags;
  v_sort integer;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  -- RETURNS TABLE(sort_order ...) makes sort_order an OUT variable, so do not
  -- read a column of that name in SQL. Alias it, then skip any taken slot.
  v_sort := coalesce(p_sort_order, (
    select coalesce(max(x.stage_sort), 0) + 1
    from (
      select fs.sort_order as stage_sort
      from public.shipment_progress_flow_stages as fs
      where fs.flow_id = p_flow_id
    ) x
  ));

  while exists (
    select 1
    from public.shipment_progress_flow_stages as fs
    where fs.flow_id = p_flow_id
      and fs.sort_order = v_sort
  ) loop
    v_sort := v_sort + 1;
  end loop;

  insert into public.tags (
    tenant_id, name, slug, color, type, group_name, sort_order, is_active, is_system, created_by_email
  )
  values (
    v_flow.tenant_id,
    trim(p_name),
    v_slug,
    coalesce(p_color, '#64748b'),
    'shipment_progress',
    'shipment_progress',
    v_sort,
    true,
    false,
    'tenant-settings'
  )
  returning * into v_tag;

  return query
  with inserted as (
    insert into public.shipment_progress_flow_stages (flow_id, tag_id, sort_order)
    select p_flow_id, v_tag.id, v_sort
    returning
      shipment_progress_flow_stages.id,
      shipment_progress_flow_stages.flow_id,
      shipment_progress_flow_stages.tag_id,
      shipment_progress_flow_stages.sort_order as stage_sort
  )
  select
    i.id,
    i.flow_id,
    i.tag_id,
    i.stage_sort,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active
  from inserted i;
end;
$$;


ALTER FUNCTION "public"."create_shipment_progress_flow_stage"("p_flow_id" bigint, "p_name" "text", "p_color" "text", "p_sort_order" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_shipment_progress_tag"("p_tenant_id" bigint, "p_name" "text", "p_color" "text" DEFAULT '#64748b'::"text", "p_sort_order" integer DEFAULT NULL::integer) RETURNS "public"."tags"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_slug text;
  v_max_sort integer;
  v_result public.tags;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  -- Slugify name
  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  -- Guard duplicate slug within tenant progress group
  if exists (
    select 1 from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
      and t.slug = v_slug
  ) then
    raise exception 'a progress tag with this name already exists';
  end if;

  -- Default sort_order to end of list
  if p_sort_order is null then
    select coalesce(max(t.sort_order), 0) + 1
    into v_max_sort
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress';
  else
    v_max_sort := p_sort_order;
  end if;

  insert into public.tags (
    tenant_id, name, slug, color, type, group_name, sort_order, is_active, is_system, created_by_email
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_slug,
    coalesce(p_color, '#64748b'),
    'shipment_progress',
    'shipment_progress',
    v_max_sort,
    true,
    false,
    'tenant-settings'
  )
  returning * into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."create_shipment_progress_tag"("p_tenant_id" bigint, "p_name" "text", "p_color" "text", "p_sort_order" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_stock_movement"("p_tenant_id" bigint, "p_movement_type" "public"."stock_movement_type", "p_notes" "text" DEFAULT NULL::"text", "p_reference_type" "text" DEFAULT NULL::"text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mov public.stock_movements%rowtype;
  v_no text;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_no := 'SM-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    p_tenant_id,
    v_no,
    p_movement_type,
    p_reference_type,
    p_reference_id,
    p_notes,
    public.current_user_email()
  )
  returning * into v_mov;

  return jsonb_build_object('movement', to_jsonb(v_mov));
end;
$$;


ALTER FUNCTION "public"."create_stock_movement"("p_tenant_id" bigint, "p_movement_type" "public"."stock_movement_type", "p_notes" "text", "p_reference_type" "text", "p_reference_id" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_website" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_vendor public.vendors;
  v_wallet public.wallet_accounts;
  v_currency_code text := 'BDT';
begin
  -- 1. Permission checks
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;
  else
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
  end if;

  -- 2. Insert vendor record
  insert into public.vendors (
    tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    p_tenant_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  -- 3. Create or fetch wallet_accounts anchor for vendor (Default BDT)
  insert into public.wallet_accounts (
    tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    'vendor',
    v_vendor.id,
    v_currency_code,
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  -- 4. Return JSON payload matching documentation specification
  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;


ALTER FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_website" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select case
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_admin_manage_costing_file(cf.tenant_id)
    ) then 'admin'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_staff_access_costing_file(cf.tenant_id)
    ) then 'staff'
    when exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_customer_access_costing_file(cf.customer_group_id)
    ) then 'customer'
    else null
  end
$$;


ALTER FUNCTION "public"."current_costing_item_actor_role"("p_costing_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."default_pickable_stock_location_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select public.default_putaway_stock_location_id(p_tenant_id);
$$;


ALTER FUNCTION "public"."default_pickable_stock_location_id"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."default_putaway_stock_location_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_loc bigint;
begin
  select sl.id into v_loc
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and public._stock_location_is_leaf(sl.id)
  order by sl.is_default desc, sl.is_pickable desc, sl.sort_order, sl.id
  limit 1;

  if v_loc is null then
    v_loc := public.ensure_default_stock_location(p_tenant_id);
  end if;

  return v_loc;
end;
$$;


ALTER FUNCTION "public"."default_putaway_stock_location_id"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."default_returns_stock_location_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_loc bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant from public.tenants where id = p_tenant_id;
  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    return public.default_returns_stock_location_id(v_tenant.parent_id);
  end if;

  select sl.id into v_loc
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and sl.kind = 'returns'::public.stock_location_kind
  order by sl.sort_order, sl.id
  limit 1;

  if v_loc is not null then
    return v_loc;
  end if;

  insert into public.stock_locations (
    parent_tenant_id, parent_location_id, code, name, kind,
    is_default, is_pickable, sort_order, is_active
  ) values (
    p_tenant_id, null, 'RETURNS', 'Returns', 'returns',
    false, false, 100, true
  )
  on conflict (parent_tenant_id, code) do update
    set kind = 'returns'::public.stock_location_kind,
        is_active = true,
        is_pickable = false
  returning id into v_loc;

  return v_loc;
end;
$$;


ALTER FUNCTION "public"."default_returns_stock_location_id"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."default_stock_grade_tag_id"() RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select t.id
  from public.tags t
  join public.tag_categories tc on tc.id = t.category_id
  where tc.module_key = 'stock_grade' and tc.code = 'warehouse' and t.slug = 'standard'
  limit 1;
$$;


ALTER FUNCTION "public"."default_stock_grade_tag_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_global_shipment_cost_entry"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_entry public.global_shipment_cost_entries%rowtype;
  v_ship public.global_shipments%rowtype;
begin
  select * into v_entry from public.global_shipment_cost_entries where id = p_id;
  if not found then
    raise exception 'cost entry not found';
  end if;

  select * into v_ship from public.global_shipments where id = v_entry.shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.stock_ready = true or v_ship.status = 'received' then
    raise exception 'shipment finalized; use revise_global_shipment_costs';
  end if;

  delete from public.global_shipment_cost_entries where id = p_id;
end;
$$;


ALTER FUNCTION "public"."delete_global_shipment_cost_entry"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_global_stock_allocation"("p_allocation_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  delete from public.global_stock_allocations where id = p_allocation_id;
end;
$$;


ALTER FUNCTION "public"."delete_global_stock_allocation"("p_allocation_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_shipment"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shipments where id = p_id;
end;
$$;


ALTER FUNCTION "public"."delete_shipment"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_shipment_item_quantity"("p_id" bigint, "p_quantity" integer) RETURNS boolean
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.shipment_items;
  v_next_qty integer;
begin
  select * into v_item
  from public.shipment_items
  where id = p_id;

  if v_item.id is null then
    return false;
  end if;

  if not public.can_manage_shipment_by_id(v_item.shipment_id) then
    raise exception 'not allowed';
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  v_next_qty := v_item.quantity - p_quantity;

  if v_next_qty <= 0 then
    delete from public.shipment_items where id = p_id;
    return true;
  end if;

  update public.shipment_items
  set quantity = v_next_qty
  where id = p_id;

  return true;
end;
$$;


ALTER FUNCTION "public"."delete_shipment_item_quantity"("p_id" bigint, "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_shipment_order"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shipment_id bigint;
begin
  select shipment_id into v_shipment_id
  from public.shipment_orders
  where id = p_id;

  if v_shipment_id is null then
    raise exception 'shipment_order not found';
  end if;

  if not public.can_manage_shipment_by_id(v_shipment_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shipment_orders where id = p_id;
end;
$$;


ALTER FUNCTION "public"."delete_shipment_order"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."delete_stock_location"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.stock_locations%rowtype;
  v_parent bigint;
begin
  select * into v_row
  from public.stock_locations
  where id = p_id
  for update;

  if not found then
    raise exception 'location not found';
  end if;

  v_parent := v_row.parent_tenant_id;
  perform public._assert_parent_warehouse_tenant(v_parent);

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or public.membership_has_module_action(v_parent, 'global_stock_location', 'delete')
    or public.membership_has_module_action(v_parent, 'global_stock_location', 'edit')
  ) then
    raise exception 'not allowed';
  end if;

  delete from public.stock_locations where id = p_id;

  -- Promote another leaf default if needed
  if not exists (
    select 1 from public.stock_locations l
    where l.parent_tenant_id = v_parent
      and l.is_default = true
      and l.is_active = true
      and public._stock_location_is_leaf(l.id)
  ) then
    update public.stock_locations
    set is_default = true
    where id = (
      select l.id from public.stock_locations l
      where l.parent_tenant_id = v_parent
        and l.is_active = true
        and public._stock_location_is_leaf(l.id)
      order by l.sort_order, l.id
      limit 1
    );
  end if;
end;
$$;


ALTER FUNCTION "public"."delete_stock_location"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."enforce_costing_file_item_update_rules"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_actor_role text;
  v_file_status public.costing_file_status;
begin
  v_actor_role := public.current_costing_item_actor_role(old.costing_file_id);

  select cf.status
  into v_file_status
  from public.costing_files cf
  where cf.id = old.costing_file_id;

  if v_actor_role = 'admin' then
    return new;
  end if;

  if v_actor_role = 'staff' then
    if new.costing_file_id is distinct from old.costing_file_id
      or new.website_url is distinct from old.website_url
      or new.quantity is distinct from old.quantity
      or new.status is distinct from old.status
      or new.customer_profit_rate is distinct from old.customer_profit_rate
      or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
      or new.item_price_gbp is distinct from old.item_price_gbp
      or new.cargo_rate is distinct from old.cargo_rate
      or new.costing_price_gbp is distinct from old.costing_price_gbp
      or new.costing_price_bdt is distinct from old.costing_price_bdt
      or new.offer_price_bdt is distinct from old.offer_price_bdt
      or new.created_by_email is distinct from old.created_by_email
      or new.created_at is distinct from old.created_at
    then
      raise exception 'staff can update enrichment fields only';
    end if;

    return new;
  end if;

  if v_actor_role = 'customer' then
    if v_file_status = 'draft' then
      if new.costing_file_id is distinct from old.costing_file_id
        or new.status is distinct from old.status
        or new.name is distinct from old.name
        or new.image_url is distinct from old.image_url
        or new.product_weight is distinct from old.product_weight
        or new.package_weight is distinct from old.package_weight
        or new.price_in_web_gbp is distinct from old.price_in_web_gbp
        or new.delivery_price_gbp is distinct from old.delivery_price_gbp
        or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
        or new.item_price_gbp is distinct from old.item_price_gbp
        or new.cargo_rate is distinct from old.cargo_rate
        or new.costing_price_gbp is distinct from old.costing_price_gbp
        or new.costing_price_bdt is distinct from old.costing_price_bdt
        or new.offer_price_bdt is distinct from old.offer_price_bdt
        or new.offer_price_override_bdt is distinct from old.offer_price_override_bdt
        or new.customer_profit_rate is distinct from old.customer_profit_rate
        or new.created_by_email is distinct from old.created_by_email
        or new.created_at is distinct from old.created_at
      then
        raise exception 'customer can update website_url and quantity only while file is draft';
      end if;

      return new;
    end if;

    if v_file_status = 'offered' then
      if new.costing_file_id is distinct from old.costing_file_id
        or new.website_url is distinct from old.website_url
        or new.quantity is distinct from old.quantity
        or new.name is distinct from old.name
        or new.image_url is distinct from old.image_url
        or new.product_weight is distinct from old.product_weight
        or new.package_weight is distinct from old.package_weight
        or new.price_in_web_gbp is distinct from old.price_in_web_gbp
        or new.delivery_price_gbp is distinct from old.delivery_price_gbp
        or new.auxiliary_price_gbp is distinct from old.auxiliary_price_gbp
        or new.item_price_gbp is distinct from old.item_price_gbp
        or new.cargo_rate is distinct from old.cargo_rate
        or new.costing_price_gbp is distinct from old.costing_price_gbp
        or new.costing_price_bdt is distinct from old.costing_price_bdt
        or new.offer_price_bdt is distinct from old.offer_price_bdt
        or new.offer_price_override_bdt is distinct from old.offer_price_override_bdt
        or new.created_by_email is distinct from old.created_by_email
        or new.created_at is distinct from old.created_at
      then
        raise exception 'customer can update item status and customer_profit_rate only when file is offered';
      end if;

      return new;
    end if;

    raise exception 'customer cannot update costing file items in the current file status';
  end if;

  raise exception 'current user cannot update costing file items';
end;
$$;


ALTER FUNCTION "public"."enforce_costing_file_item_update_rules"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_default_stock_location"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_loc_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  -- Stock locations live on parent (stock-owning) tenants only
  if v_tenant.parent_id is not null then
    return public.ensure_default_stock_location(v_tenant.parent_id);
  end if;

  -- Check if an active leaf location already exists for this parent tenant
  select sl.id into v_loc_id
  from public.stock_locations sl
  where sl.parent_tenant_id = p_tenant_id
    and sl.is_active = true
    and public._stock_location_is_leaf(sl.id)
  order by sl.is_default desc, sl.is_pickable desc, sl.sort_order, sl.id
  limit 1;

  if v_loc_id is not null then
    return v_loc_id;
  end if;

  -- Create default leaf stock location for tenant
  insert into public.stock_locations (
    parent_tenant_id,
    name,
    code,
    kind,
    parent_location_id,
    is_pickable,
    is_default,
    is_active,
    sort_order
  ) values (
    p_tenant_id,
    'Main Warehouse',
    'MAIN',
    'shelf',
    null,
    true,
    true,
    true,
    10
  )
  returning id into v_loc_id;

  return v_loc_id;
end;
$$;


ALTER FUNCTION "public"."ensure_default_stock_location"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_vendor_id bigint;
  v_market_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  -- Vendors / default vendor live on parent (stock-owning) tenants only
  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_vendor requires a parent tenant (got child %)', p_tenant_id;
  end if;

  -- Auth: skip when no JWT (migration / service); otherwise same bar as create_vendor
  if auth.uid() is not null then
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
  end if;

  -- Already has a default
  select id into v_vendor_id
  from public.vendors
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_vendor_id is not null then
    return v_vendor_id;
  end if;

  -- Promote reserved code DEFAULT if present
  select id into v_vendor_id
  from public.vendors
  where tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_vendor_id is not null then
    update public.vendors
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Vendor'),
        updated_at = now()
    where id = v_vendor_id;
    return v_vendor_id;
  end if;

  -- Resolve market_code from existing tenant vendors, then stable prod FKs
  select v.market_code into v_market_code
  from public.vendors v
  where v.tenant_id = p_tenant_id
  order by v.id
  limit 1;

  if v_market_code is null then
    select m.code into v_market_code
    from public.markets m
    where m.is_active = true
      and m.code in ('GB', 'BD', 'US')
    order by case m.code when 'GB' then 1 when 'BD' then 2 else 3 end
    limit 1;
  end if;

  if v_market_code is null then
    select m.code into v_market_code
    from public.markets m
    where m.is_active = true
    order by m.id
    limit 1;
  end if;

  if v_market_code is null then
    raise exception 'no active market available for default vendor';
  end if;

  insert into public.vendors (
    tenant_id,
    name,
    code,
    market_code,
    is_default
  )
  values (
    p_tenant_id,
    'Default Vendor',
    'DEFAULT',
    v_market_code,
    true
  )
  returning id into v_vendor_id;

  -- Mirror create_vendor_with_wallet: zero BDT wallet anchor
  insert into public.wallet_accounts (
    tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    'vendor',
    v_vendor_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_vendor_id;
end;
$$;


ALTER FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_global_shipment_cost_entries_from_header"("p_shipment_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_goods numeric;
  v_cargo_amt numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if exists (
    select 1 from public.global_shipment_cost_entries e where e.shipment_id = p_shipment_id
  ) then
    return;
  end if;

  select coalesce(sum(gsi.purchase_price * gsi.ordered_quantity), 0)
  into v_goods
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  if v_ship.purchase_invoice_total is not null and v_ship.purchase_invoice_total > 0 then
    v_goods := v_ship.purchase_invoice_total;
  end if;

  v_cargo_amt := coalesce(v_ship.cargo_invoice_total, 0);

  insert into public.global_shipment_cost_entries (
    parent_tenant_id, shipment_id, cost_type, amount, currency_id, exchange_rate, metadata
  ) values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    'product',
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    1.0,
    jsonb_build_object('source', 'header_backfill')
  );

  if v_cargo_amt > 0 then
    insert into public.global_shipment_cost_entries (
      parent_tenant_id, shipment_id, cost_type, amount, currency_id, exchange_rate, metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      'cargo',
      v_cargo_amt,
      v_ship.shipment_cost_currency_id,
      1.0,
      jsonb_build_object('source', 'header_backfill')
    );
  end if;
end;
$$;


ALTER FUNCTION "public"."ensure_global_shipment_cost_entries_from_header"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_shipment_progress_tags"("p_tenant_id" bigint) RETURNS SETOF "public"."tags"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_email constant text := 'system@brandwala.local';
  v_slug text;
  v_name text;
  v_sort integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  -- Seed defaults only if they don't already exist (never overwrite user customizations)
  for v_slug, v_name, v_sort in
    select *
    from (
      values
        ('uk-warehouse'::text, 'UK Warehouse'::text, 1),
        ('on-flight',          'On flight',          2),
        ('airport',            'Airport',            3),
        ('customs-clearance',  'Customs clearance',  4),
        ('bd-warehouse',       'BD Warehouse',       5)
    ) as s(slug, name, sort_order)
  loop
    if not exists (
      select 1 from public.tags t
      where t.tenant_id = p_tenant_id
        and t.slug = v_slug
        and t.group_name = 'shipment_progress'
    ) then
      insert into public.tags (
        tenant_id, name, slug, color, type, group_name, sort_order, created_by_email
      )
      values (
        p_tenant_id,
        v_name,
        v_slug,
        '#64748b',
        'shipment_progress',
        'shipment_progress',
        v_sort,
        v_email
      );
    end if;
  end loop;

  return query
    select t.*
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
    order by t.sort_order nulls last, t.name;
end;
$$;


ALTER FUNCTION "public"."ensure_shipment_progress_tags"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."finalize_global_shipment"("p_shipment_id" bigint, "p_stock_rows" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_stamped integer;
  v_stock_count integer := 0;
  v_row jsonb;
  v_parent bigint;
  v_loc bigint;
  v_grade_tag bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_qty int;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.parent_tenant_id;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.stock_ready = true or v_ship.status = 'received' then
    raise exception 'shipment already finalized; use revise_global_shipment_costs';
  end if;

  if not exists (
    select 1 from public.global_shipment_items where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no items';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  if not exists (
    select 1 from public.global_shipment_cost_entries where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no cost entries';
  end if;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
    v_mov_no := 'RP-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

    insert into public.stock_movements (
      tenant_id,
      movement_no,
      movement_type,
      reference_type,
      reference_id,
      notes,
      created_by_email,
      is_posted,
      posted_at
    ) values (
      v_parent,
      v_mov_no,
      'receive_putaway',
      'global_shipment',
      p_shipment_id::text,
      'Receive put-away audit for shipment ' || p_shipment_id::text,
      public.current_user_email(),
      true,
      now()
    )
    returning id into v_mov_id;

    for v_row in select value from jsonb_array_elements(p_stock_rows)
    loop
      v_qty := coalesce((v_row->>'quantity')::int, 0);
      if v_qty <= 0 then
        continue;
      end if;

      if (v_row->>'shipment_item_id')::bigint is null then
        raise exception 'stock row requires shipment_item_id';
      end if;

      if not exists (
        select 1
        from public.global_shipment_items gsi
        where gsi.id = (v_row->>'shipment_item_id')::bigint
          and gsi.shipment_id = p_shipment_id
      ) then
        raise exception 'stock row shipment_item_id % not on shipment', v_row->>'shipment_item_id';
      end if;

      v_loc := coalesce((v_row->>'location_id')::bigint, public.default_putaway_stock_location_id(v_parent));

      if v_loc is null then
        raise exception 'no put-away location configured';
      end if;

      if not exists (
        select 1
        from public.stock_locations sl
        where sl.id = v_loc
          and sl.parent_tenant_id = v_parent
          and sl.is_active = true
          and public._stock_location_is_leaf(v_loc)
      ) then
        raise exception 'invalid put-away location';
      end if;

      v_avail := coalesce((v_row->>'availability')::public.stock_availability, 'sellable'::public.stock_availability);
      v_grade_tag := coalesce((v_row->>'grade_tag_id')::bigint, public.default_stock_grade_tag_id());

      insert into public.global_stocks (
        parent_tenant_id,
        shipment_item_id,
        stock_type_id,
        quantity,
        is_usable,
        availability,
        location_id,
        grade_tag_id
      ) values (
        v_parent,
        (v_row->>'shipment_item_id')::bigint,
        (v_row->>'stock_type_id')::bigint,
        v_qty,
        coalesce((v_row->>'is_usable')::boolean, v_avail = 'sellable'::public.stock_availability),
        v_avail,
        v_loc,
        v_grade_tag
      )
      on conflict (shipment_item_id, availability, location_id, grade_tag_id)
      do update set
        quantity = excluded.quantity,
        updated_at = now()
      returning id into v_stock_id;

      insert into public.stock_movement_lines (
        movement_id,
        stock_id,
        quantity,
        to_location_id,
        to_availability
      ) values (
        v_mov_id,
        v_stock_id,
        v_qty,
        v_loc,
        v_avail
      );

      v_stock_count := v_stock_count + 1;
    end loop;

    if v_stock_count = 0 then
      raise exception 'p_stock_rows provided but no quantities to post';
    end if;

    update public.global_shipment_items gsi
    set
      received_quantity = coalesce(agg.total_qty, 0),
      updated_at = now()
    from (
      select (r->>'shipment_item_id')::bigint as item_id, sum(coalesce((r->>'quantity')::int, 0)) as total_qty
      from jsonb_array_elements(p_stock_rows) r
      where (r->>'shipment_item_id')::bigint is not null
      group by (r->>'shipment_item_id')::bigint
    ) agg
    where gsi.id = agg.item_id and gsi.shipment_id = p_shipment_id;

    update public.global_shipments
    set
      status = 'received',
      stock_ready = true,
      inventory_added = true,
      updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'stock_rows_posted', v_stock_count,
    'stock_ready', (select stock_ready from public.global_shipments where id = p_shipment_id),
    'wallet_posted', false,
    'movement_id', v_mov_id
  );
end;
$$;


ALTER FUNCTION "public"."finalize_global_shipment"("p_shipment_id" bigint, "p_stock_rows" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."generate_shipment_tracking_token"("p_shipment_id" bigint) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_token text;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  -- URL-safe token (32 hex chars). gen_random_uuid is in pg_catalog;
  -- gen_random_bytes lives in extensions and is hidden by search_path = public.
  v_token := replace(gen_random_uuid()::text, '-', '');

  update public.global_shipments
  set public_tracking_token = v_token, updated_at = now()
  where id = p_shipment_id;

  return v_token;
end;
$$;


ALTER FUNCTION "public"."generate_shipment_tracking_token"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_available_stock"("p_stock_id" bigint, "p_tenant_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_global_qty integer;
  v_other_allocated integer;
begin
  select parent_tenant_id, quantity
  into v_parent_tenant_id, v_global_qty
  from public.global_stocks
  where id = p_stock_id;

  if v_parent_tenant_id is null then
    return 0;
  end if;

  -- Parent tenant can sell up to the entire global quantity
  if p_tenant_id = v_parent_tenant_id then
    return v_global_qty;
  end if;

  -- Child tenant can sell: global quantity - sum of allocations to OTHER child tenants
  select coalesce(sum(quantity), 0)
  into v_other_allocated
  from public.global_stock_allocations
  where stock_id = p_stock_id
    and child_tenant_id <> p_tenant_id;

  return greatest(v_global_qty - v_other_allocated, 0);
end;
$$;


ALTER FUNCTION "public"."get_available_stock"("p_stock_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) RETURNS TABLE("id" bigint, "name" "text", "cargo_rate_1kg" numeric, "cargo_rate_2kg" numeric, "conversion_rate" numeric, "admin_profit_rate" numeric, "status" "public"."costing_file_status", "market" "text", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "default_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    cf.id,
    cf.name,
    cf.cargo_rate_1kg,
    cf.cargo_rate_2kg,
    cf.conversion_rate,
    cf.admin_profit_rate,
    cf.status,
    cf.market,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.default_shipment_id,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where cf.id = p_id
    and public.can_view_costing_file(cf.id)
  limit 1;
$$;


ALTER FUNCTION "public"."get_costing_file_by_id"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_payee_settlement_summary"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_avail NUMERIC(18,4) := 0;
  v_paid NUMERIC(18,4) := 0;
  v_credited NUMERIC(18,4) := 0;
  v_used NUMERIC(18,4) := 0;
  v_events JSONB := '[]'::jsonb;
BEGIN
  IF p_entity_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(available_balance, 0) INTO v_avail
  FROM public.wallet_accounts
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND currency_code = 'BDT';

  SELECT COALESCE(SUM(base_amount), 0) INTO v_paid
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'pay'
    AND metadata->>'payee_type' = p_entity_type
    AND (metadata->>'payee_id')::bigint = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_credited
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'record_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_used
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'use_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'created_at', created_at,
      'type', type,
      'action', metadata->>'action',
      'amount_input', COALESCE((metadata->>'amount_input')::numeric, amount),
      'exchange_rate', COALESCE((metadata->>'exchange_rate')::numeric, exchange_rate),
      'base_amount', base_amount
    ) ORDER BY created_at DESC
  ), '[]'::jsonb) INTO v_events
  FROM public.universal_wallet_ledger
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND (
      (entity_type = p_entity_type AND entity_id = p_entity_id)
      OR
      (metadata->>'payee_type' = p_entity_type AND (metadata->>'payee_id')::bigint = p_entity_id)
    );

  RETURN jsonb_build_object(
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'available_bdt', v_avail,
    'paid_bdt', v_paid,
    'credited_bdt', v_credited,
    'used_bdt', v_used,
    'recent_events', v_events
  );
END;
$$;


ALTER FUNCTION "public"."get_payee_settlement_summary"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shipment_pnl"("p_tenant_id" bigint, "p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shipment jsonb;
  v_items jsonb;
  v_total_landed_cost numeric(12,2) := 0;
  v_total_sold_cost numeric(12,2) := 0;
  v_total_revenue numeric(12,2) := 0;
  v_total_gross_profit numeric(12,2) := 0;
  v_total_sellable_on_hand_value numeric(12,2) := 0;
  v_total_shrinkage_value numeric(12,2) := 0;
  v_total_stolen_value numeric(12,2) := 0;
  v_total_box_damage_value numeric(12,2) := 0;
  v_total_expired_value numeric(12,2) := 0;
  v_total_reconciliation_gap bigint := 0;
  v_disposition_available boolean := false;
begin
  -- Resolve parent tenant to enforce access
  if public.resolve_parent_tenant_id(p_tenant_id) <> (select parent_tenant_id from public.global_shipments where id = p_shipment_id) then
    raise exception 'unauthorized tenant access to shipment';
  end if;

  -- 1. Get shipment header
  select row_to_json(s)::jsonb
  into v_shipment
  from public.global_shipments s
  where s.id = p_shipment_id;

  -- Check if disposition is available (i.e. global_stocks rows exist for shipment items)
  select exists (
    select 1
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gs.shipment_item_id = gsi.id
    where gsi.shipment_id = p_shipment_id
  ) into v_disposition_available;

  -- 2. Get shipment items details with on-the-fly margins and stock disposition
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_items
  from (
    select
      si.*,
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(sum(ii.unit_cost_price * (ii.quantity - ii.return_quantity)), 0) as sold_cost,
      coalesce(sum(ii.sell_price_amount * ii.quantity - coalesce((
        select sum(ri.return_accounting_amount)
        from public.global_return_items ri
        where ri.invoice_item_id = ii.id
      ), 0.00) - case
        when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
        else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.settlement_discount_amount, 0.00))
          * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
      end), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      coalesce(disp.reserved_qty, 0) as reserved_qty,
      (coalesce(disp.sellable_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as sellable_value,
      ((coalesce(disp.stolen_qty, 0) + coalesce(disp.box_damage_qty, 0) + coalesce(disp.expired_qty, 0)) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as shrinkage_value,
      (coalesce(disp.stolen_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as stolen_value,
      (coalesce(disp.box_damage_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as box_damage_value,
      (coalesce(disp.expired_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as expired_value,
      (si.ordered_quantity - coalesce(sum(ii.quantity - ii.return_quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    left join lateral (
      select coalesce(sum(x.line_total_amount), 0.00) as inv_line_subtotal
      from public.global_invoice_items x
      where x.invoice_id = ii.invoice_id
    ) invagg on true
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) r;

  -- 3. Sum total metrics
  select
    coalesce(sum(landed_unit_cost * received_qty), 0),
    coalesce(sum(sold_cost), 0),
    coalesce(sum(revenue), 0),
    coalesce(sum(sellable_qty * landed_unit_cost), 0),
    coalesce(sum((stolen_qty + box_damage_qty + expired_qty) * landed_unit_cost), 0),
    coalesce(sum(stolen_qty * landed_unit_cost), 0),
    coalesce(sum(box_damage_qty * landed_unit_cost), 0),
    coalesce(sum(expired_qty * landed_unit_cost), 0),
    coalesce(sum(reconciliation_gap), 0)
  into
    v_total_landed_cost,
    v_total_sold_cost,
    v_total_revenue,
    v_total_sellable_on_hand_value,
    v_total_shrinkage_value,
    v_total_stolen_value,
    v_total_box_damage_value,
    v_total_expired_value,
    v_total_reconciliation_gap
  from (
    select
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      si.ordered_quantity as received_qty,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(sum(ii.unit_cost_price * (ii.quantity - ii.return_quantity)), 0) as sold_cost,
      coalesce(sum(ii.sell_price_amount * ii.quantity - coalesce((
        select sum(ri.return_accounting_amount)
        from public.global_return_items ri
        where ri.invoice_item_id = ii.id
      ), 0.00) - case
        when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
        else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.settlement_discount_amount, 0.00))
          * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
      end), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      (si.ordered_quantity - coalesce(sum(ii.quantity - ii.return_quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    left join lateral (
      select coalesce(sum(x.line_total_amount), 0.00) as inv_line_subtotal
      from public.global_invoice_items x
      where x.invoice_id = ii.invoice_id
    ) invagg on true
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) rollup;

  v_total_gross_profit := v_total_revenue - v_total_sold_cost;

  return jsonb_build_object(
    'shipment', v_shipment,
    'items', v_items,
    'totals', jsonb_build_object(
      'landed_cost', v_total_landed_cost,
      'sold_cost', v_total_sold_cost,
      'revenue', v_total_revenue,
      'gross_profit', v_total_gross_profit,
      'sellable_on_hand_value', v_total_sellable_on_hand_value,
      'shrinkage_value', v_total_shrinkage_value,
      'stolen_value', v_total_stolen_value,
      'box_damage_value', v_total_box_damage_value,
      'expired_value', v_total_expired_value,
      'unsold_value', v_total_sellable_on_hand_value, -- alias for backward compat
      'disposition_available', v_disposition_available,
      'reconciliation_gap', v_total_reconciliation_gap
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_shipment_pnl"("p_tenant_id" bigint, "p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shipment_public_status"("p_token" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_progress_tag jsonb := null;
  v_progress_list jsonb := '[]'::jsonb;
  v_flow jsonb := null;
  v_tag public.tags%rowtype;
begin
  if p_token is null or trim(p_token) = '' then
    return null;
  end if;

  select * into v_ship
  from public.global_shipments
  where public_tracking_token = p_token
  limit 1;

  if not found then
    return null;
  end if;

  select jsonb_build_object(
    'id', f.id,
    'name', f.name,
    'slug', f.slug,
    'is_default', f.is_default
  )
  into v_flow
  from public.shipment_progress_flows f
  where f.id = v_ship.progress_flow_id;

  if v_ship.progress_tag_id is not null then
    select * into v_tag
    from public.tags
    where id = v_ship.progress_tag_id
      and is_active = true
    limit 1;

    if found then
      v_progress_tag := jsonb_build_object(
        'id', v_tag.id,
        'name', v_tag.name,
        'color', v_tag.color,
        'sort_order', v_tag.sort_order
      );
    end if;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', t.id,
        'name', t.name,
        'color', t.color,
        'sort_order', s.sort_order
      )
      order by s.sort_order asc
    ),
    '[]'::jsonb
  )
  into v_progress_list
  from public.shipment_progress_flow_stages s
  join public.tags t on t.id = s.tag_id
  where s.flow_id = v_ship.progress_flow_id
    and t.is_active = true;

  return jsonb_build_object(
    'id', v_ship.id,
    'name', v_ship.name,
    'status', v_ship.status,
    'progress_flow', v_flow,
    'progress_tag', v_progress_tag,
    'progress_tags', v_progress_list,
    'updated_at', v_ship.updated_at
  );
end;
$$;


ALTER FUNCTION "public"."get_shipment_public_status"("p_token" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_vendor_for_tenant"("p_id" bigint, "p_tenant_id" bigint) RETURNS "public"."vendors"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.vendors;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    select * into v_row
    from public.vendors
    where id = p_id
      and tenant_id is null;

    return v_row;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.is_child_tenant(p_tenant_id) then
    select * into v_row
    from public.vendors
    where id = p_id
      and tenant_id = p_tenant_id;
  else
    select * into v_row
    from public.vendors
    where id = p_id
      and parent_tenant_id = p_tenant_id;
  end if;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."get_vendor_for_tenant"("p_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."global_stock_atp_qty"("p_global_stock_id" bigint) RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select greatest(
    coalesce((
      select sum(gs.quantity)
      from public.global_stocks gs
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.id = p_global_stock_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
    ), 0) - public.global_stock_hold_qty(p_global_stock_id),
    0
  );
$$;


ALTER FUNCTION "public"."global_stock_atp_qty"("p_global_stock_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."global_stock_hold_qty"("p_global_stock_id" bigint) RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    coalesce((
      select sum(gii.quantity - coalesce(gii.return_quantity, 0))
      from public.global_invoice_items gii
      join public.global_invoices gi on gi.id = gii.invoice_id
      where gii.global_stock_id = p_global_stock_id
        and gi.invoice_status = 'draft'::public.global_invoice_status
    ), 0)
    + coalesce((
      select sum(sci.quantity)
      from public.shop_cart_items sci
      where sci.global_stock_id = p_global_stock_id
    ), 0);
$$;


ALTER FUNCTION "public"."global_stock_hold_qty"("p_global_stock_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) RETURNS TABLE("costing_file_viewer_id" bigint, "costing_file_id" bigint, "membership_id" bigint, "name" "text", "email" "text", "role" "public"."app_role", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with target_file as (
    select cf.id, cf.tenant_id
    from public.costing_files cf
    where cf.id = p_costing_file_id
      and public.can_manage_costing_file_viewers(cf.tenant_id)
  ),
  target_viewer as (
    select m.id, m.email, m.role, m.is_active
    from public.memberships m
    inner join target_file tf
      on true
    where m.id = p_membership_id
      and m.tenant_id = tf.tenant_id
      and m.role = 'viewer'
      and m.is_active = true
  ),
  inserted as (
    insert into public.costing_file_viewers (
      costing_file_id,
      membership_id
    )
    select
      tf.id,
      tv.id
    from target_file tf
    cross join target_viewer tv
    on conflict (costing_file_id, membership_id) do update
      set updated_at = now()
    returning
      id as costing_file_viewer_id,
      costing_file_id,
      membership_id,
      created_at,
      updated_at
  )
  select
    i.costing_file_viewer_id,
    i.costing_file_id,
    i.membership_id,
    tv.email as name,
    tv.email,
    tv.role,
    tv.is_active,
    i.created_at,
    i.updated_at
  from inserted i
  inner join target_viewer tv
    on tv.id = i.membership_id;
$$;


ALTER FUNCTION "public"."grant_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.costing_file_viewers cfv
    inner join public.memberships m
      on m.id = cfv.membership_id
    where cfv.costing_file_id = p_costing_file_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role = 'viewer'
  );
$$;


ALTER FUNCTION "public"."is_assigned_costing_file_viewer"("p_costing_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where lower(trim(m.email)) = lower(trim(coalesce(p_email, '')))
      and m.is_active = true
      and (
        (m.tenant_id = p_tenant_id and m.role in ('admin', 'staff'))
        or (m.tenant_id is null and m.role = 'superadmin')
      )
  );
$$;


ALTER FUNCTION "public"."is_internal_costing_file_creator"("p_tenant_id" bigint, "p_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."is_vendor_code_available"("p_code" "text", "p_exclude_id" bigint DEFAULT NULL::bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select not exists (
    select 1
    from public.vendors v
    where upper(trim(v.code)) = upper(trim(p_code))
      and (p_exclude_id is null or v.id <> p_exclude_id)
  );
$$;


ALTER FUNCTION "public"."is_vendor_code_available"("p_code" "text", "p_exclude_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_allocatable_stock_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_shipment_id" bigint DEFAULT NULL::bigint, "p_stock_type_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Get total count of matching stocks
  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and gship.status = 'received'
    and gst.is_sellable = true
    and (p_shipment_id is null or gship.id = p_shipment_id)
    and (p_stock_type_id is null or gst.id = p_stock_type_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
      )
    );

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity as pool_quantity,
      gs.is_usable,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gship.id as shipment_id,
      gship.name as shipment_name,
      gst.description as stock_type_description,
      gst.is_sellable,
      coalesce(sum(gsa.quantity), 0)::integer as allocated_qty,
      greatest(gs.quantity - coalesce(sum(gsa.quantity), 0), 0)::integer as unallocated_qty
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.global_stock_allocations gsa on gsa.stock_id = gs.id
    where gs.parent_tenant_id = p_tenant_id
      and gship.status = 'received'
      and gst.is_sellable = true
      and (p_shipment_id is null or gship.id = p_shipment_id)
      and (p_stock_type_id is null or gst.id = p_stock_type_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
        )
      )
    group by gs.id, gsi.id, gship.id, gst.id
    order by gs.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_allocatable_stock_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_shipment_id" bigint, "p_stock_type_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_child_stock_atp"("p_child_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_total_count bigint;
  v_data jsonb;
begin
  if not public.has_active_tenant_membership(p_child_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(distinct s.id)
  into v_total_count
  from public.global_shipments s
  where s.assigned_child_tenant_id = p_child_tenant_id
    and s.status = 'received'
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      jsonb_build_object(
        'shipment_id', s.id,
        'shipment_name', s.name,
        'tenant_shipment_id', s.tenant_shipment_id,
        'parent_tenant_id', s.parent_tenant_id,
        'status', s.status,
        'received_date', s.received_date,
        'total_ordered_qty', coalesce(sum(gsi.ordered_quantity), 0),
        'total_sellable_qty', coalesce(sum(gs.quantity) filter (
          where gs.availability = 'sellable'::public.stock_availability
            and (gs.location_id is null or sl.is_pickable = true)
        ), 0),
        'atp_qty', coalesce(sum(public.global_stock_atp_qty(gs.id)), 0)
      ) as row_json
    from public.global_shipments s
    left join public.global_shipment_items gsi on gsi.shipment_id = s.id
    left join public.global_stocks gs on gs.shipment_item_id = gsi.id
    left join public.stock_locations sl on sl.id = gs.location_id
    where s.assigned_child_tenant_id = p_child_tenant_id
      and s.status = 'received'
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    group by s.id, s.name, s.tenant_shipment_id, s.parent_tenant_id, s.status, s.received_date
    order by s.id desc
    limit p_limit
    offset p_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
end;
$_$;


ALTER FUNCTION "public"."list_child_stock_atp"("p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "name" "text", "image_url" "text", "website_url" "text", "quantity" integer, "product_weight" integer, "package_weight" integer, "price_in_web_gbp" numeric, "delivery_price_gbp" numeric, "auxiliary_price_gbp" numeric, "item_price_gbp" numeric, "cargo_rate" numeric, "costing_price_gbp" numeric, "costing_price_bdt" integer, "offer_price_bdt" integer, "customer_profit_rate" numeric, "status" "public"."costing_file_item_status", "created_by_email" "text", "assigned_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    cfi.id,
    cfi.costing_file_id,
    cfi.name,
    cfi.image_url,
    cfi.website_url,
    cfi.quantity,
    cfi.product_weight,
    cfi.package_weight,
    cfi.price_in_web_gbp,
    cfi.delivery_price_gbp,
    cfi.auxiliary_price_gbp,
    cfi.item_price_gbp,
    cfi.cargo_rate,
    cfi.costing_price_gbp,
    cfi.costing_price_bdt,
    cfi.offer_price_bdt,
    cfi.customer_profit_rate,
    cfi.status,
    cfi.created_by_email,
    cfi.assigned_shipment_id,
    cfi.created_at,
    cfi.updated_at
  from public.costing_file_items cfi
  where cfi.costing_file_id = p_costing_file_id
    and public.can_view_costing_file(cfi.costing_file_id)
  order by cfi.id asc;
$$;


ALTER FUNCTION "public"."list_costing_file_items"("p_costing_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) RETURNS TABLE("costing_file_viewer_id" bigint, "costing_file_id" bigint, "membership_id" bigint, "name" "text", "email" "text", "role" "public"."app_role", "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    cfv.id as costing_file_viewer_id,
    cfv.costing_file_id,
    cfv.membership_id,
    m.email as name,
    m.email,
    m.role,
    m.is_active,
    cfv.created_at,
    cfv.updated_at
  from public.costing_file_viewers cfv
  inner join public.memberships m
    on m.id = cfv.membership_id
  where cfv.costing_file_id = p_costing_file_id
    and exists (
      select 1
      from public.costing_files cf
      where cf.id = p_costing_file_id
        and public.can_manage_costing_file_viewers(cf.tenant_id)
    )
  order by cfv.id asc;
$$;


ALTER FUNCTION "public"."list_costing_file_viewers"("p_costing_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "market" "text", "status" "public"."costing_file_status", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    cf.id,
    cf.name,
    cf.market,
    cf.status,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
  )
  order by cf.id desc;
$$;


ALTER FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- Get total count of matching files
  select count(*)
  into v_total_count
  from public.costing_files cf
  where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
    and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
    and public.can_view_costing_file(cf.id);

  -- Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      public.resolve_costing_file_creator_label(
        cf.tenant_id,
        cf.customer_group_id,
        cf.created_by_email
      ) as created_by_label,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at
    from public.costing_files cf
    where (p_tenant_id is null or cf.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cf.customer_group_id = p_customer_group_id)
      and public.can_view_costing_file(cf.id)
    order by cf.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total_count', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_costing_files_for_actor"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_global_inventory_items_with_stock"("p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_sort_by" "text" DEFAULT 'id'::"text", "p_sort_order" "text" DEFAULT 'desc'::"text", "p_filters" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  with filtered as (
    select
      ii.id,
      ii.tenant_id,
      t.name as tenant_name,
      t.slug as tenant_slug,
      ii.source_type,
      ii.source_id,
      ii.product_id,
      ii.name,
      ii.image_url,
      ii.cost,
      ii.barcode,
      ii.product_code,
      ii.manufacturing_date,
      ii.expire_date,
      ii.status,
      ii.created_at,
      ii.updated_at,
      case
        when s.id is null then null
        else jsonb_build_object(
          'id', s.id,
          'inventory_item_id', s.inventory_item_id,
          'available_quantity', s.available_quantity,
          'reserved_quantity', s.reserved_quantity,
          'damaged_quantity', s.damaged_quantity,
          'stolen_quantity', s.stolen_quantity,
          'expired_quantity', s.expired_quantity,
          'open_box_quantity', s.open_box_quantity,
          'created_at', s.created_at,
          'updated_at', s.updated_at
        )
      end as stock,
      case
        when si.id is null then null
        else jsonb_build_object(
          'shipment', jsonb_build_object(
            'id', sh.id,
            'name', sh.name,
            'tenant_shipment_id', sh.tenant_shipment_id
          ),
          'shipment_item', null
        )
      end as shipment
    from public.inventory_items ii
    left join public.tenants t
      on t.id = ii.tenant_id
    left join public.inventory_stocks s
      on s.inventory_item_id = ii.id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
      and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
    where (
      exists (
        select 1
        from public.memberships m
        where m.tenant_id = ii.tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.is_active = true
      )
    )
      and (
        not (p_filters ? 'name')
        or ii.name ilike ('%' || coalesce(p_filters->>'name', '') || '%')
      )
      and (
        not (p_filters ? 'status')
        or ii.status = p_filters->>'status'
      )
      and (
        not (p_filters ? 'source_type')
        or ii.source_type = p_filters->>'source_type'
      )
      and (
        not (p_filters ? 'source_id')
        or ii.source_id = nullif(p_filters->>'source_id', '')::bigint
      )
      and (
        not (p_filters ? 'product_id')
        or ii.product_id = nullif(p_filters->>'product_id', '')::bigint
      )
      and (
        not (p_filters ? 'barcode')
        or coalesce(ii.barcode, '') ilike ('%' || coalesce(p_filters->>'barcode', '') || '%')
      )
      and (
        not (p_filters ? 'product_code')
        or coalesce(ii.product_code, '') ilike ('%' || coalesce(p_filters->>'product_code', '') || '%')
      )
      and (
        not (p_filters ? 'shipment_id')
        or sh.id = nullif(p_filters->>'shipment_id', '')::bigint
      )
  ),
  counted as (
    select filtered.*, count(*) over() as total_count
    from filtered
  ),
  paged as (
    select * from counted
    order by
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end desc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end desc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end desc,
      id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', paged.id,
          'tenant_id', paged.tenant_id,
          'tenant_name', paged.tenant_name,
          'tenant_slug', paged.tenant_slug,
          'source_type', paged.source_type,
          'source_id', paged.source_id,
          'product_id', paged.product_id,
          'name', paged.name,
          'image_url', paged.image_url,
          'cost', paged.cost,
          'barcode', paged.barcode,
          'product_code', paged.product_code,
          'manufacturing_date', paged.manufacturing_date,
          'expire_date', paged.expire_date,
          'status', paged.status,
          'created_at', paged.created_at,
          'updated_at', paged.updated_at,
          'stock', paged.stock,
          'shipment', paged.shipment
        )
      ),
      '[]'::jsonb
    ),
    'meta', jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$$;


ALTER FUNCTION "public"."list_global_inventory_items_with_stock"("p_page" integer, "p_page_size" integer, "p_sort_by" "text", "p_sort_order" "text", "p_filters" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_global_shipment_cost_entries"("p_shipment_id" bigint) RETURNS SETOF "public"."global_shipment_cost_entries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
begin
  select parent_tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select e.*
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
  order by e.cost_type, e.id;
end;
$$;


ALTER FUNCTION "public"."list_global_shipment_cost_entries"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_global_shipments_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.parent_tenant_id = p_tenant_id
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      (
        to_jsonb(s)
        || jsonb_build_object(
          'progress_tag',
          case
            when t.id is null then null
            else jsonb_build_object(
              'id', t.id,
              'name', t.name,
              'slug', t.slug,
              'group_name', t.group_name,
              'sort_order', t.sort_order,
              'color', t.color
            )
          end
        )
      ) as row_json
    from public.global_shipments s
    left join public.tags t
      on t.id = s.progress_tag_id
     and t.group_name = 'shipment_progress'
    where s.parent_tenant_id = p_tenant_id
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    order by s.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$_$;


ALTER FUNCTION "public"."list_global_shipments_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_global_stock_allocations_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_stock_type_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent boolean;
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select (parent_id is null) into v_is_parent from public.tenants where id = p_tenant_id;

  select count(*)
  into v_total_count
  from public.global_stock_allocations gsa
  inner join public.global_stocks gs on gs.id = gsa.stock_id
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.tenants child_t on child_t.id = gsa.child_tenant_id
  where (
    (v_is_parent and gsa.parent_tenant_id = p_tenant_id)
    or (not v_is_parent and gsa.child_tenant_id = p_tenant_id)
  )
  and (p_child_tenant_id is null or gsa.child_tenant_id = p_child_tenant_id)
  and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
  and (
    p_search is null or p_search = '' or (
      gsi.name ilike '%' || p_search || '%'
      or gsi.product_code ilike '%' || p_search || '%'
      or gsi.barcode ilike '%' || p_search || '%'
      or child_t.name ilike '%' || p_search || '%'
    )
  );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gsa.*,
      child_t.name as child_tenant_name,
      gs.quantity as pool_quantity,
      gs.is_usable,
      gsi.id as shipment_item_id,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.product_conversion_rate,
      gship.cargo_conversion_rate,
      gship.cargo_rate,
      gship.received_weight,
      gship.transaction_rate,
      gst.description as stock_type_description,
      gst.is_sellable
    from public.global_stock_allocations gsa
    inner join public.global_stocks gs on gs.id = gsa.stock_id
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    inner join public.tenants child_t on child_t.id = gsa.child_tenant_id
    where (
      (v_is_parent and gsa.parent_tenant_id = p_tenant_id)
      or (not v_is_parent and gsa.child_tenant_id = p_tenant_id)
    )
    and (p_child_tenant_id is null or gsa.child_tenant_id = p_child_tenant_id)
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or child_t.name ilike '%' || p_search || '%'
      )
    )
    order by gsa.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_global_stock_allocations_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_child_tenant_id" bigint, "p_stock_type_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_stock_type_id" bigint DEFAULT NULL::bigint, "p_is_sellable" boolean DEFAULT NULL::boolean, "p_shipment_status" "text" DEFAULT NULL::"text", "p_hide_zero_stock" boolean DEFAULT true, "p_location_id" bigint DEFAULT NULL::bigint, "p_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (p_availability is null or gs.availability = p_availability)
    and (
      p_is_sellable is null
      or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
      or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
    )
    and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
    and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
    and (p_location_id is null or gs.location_id = p_location_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      sl.name as location_name,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gsi.landed_cost_bdt,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as resolved_landed_cost_bdt,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.received_weight,
      gst.description as stock_type_description,
      coalesce(gst.is_sellable, gs.availability = 'sellable') as is_sellable,
      public.global_stock_atp_qty(gs.id) as available_atp
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gs.parent_tenant_id = p_tenant_id
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (p_availability is null or gs.availability = p_availability)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and (p_location_id is null or gs.location_id = p_location_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_stock_type_id" bigint, "p_is_sellable" boolean, "p_shipment_status" "text", "p_hide_zero_stock" boolean, "p_location_id" bigint, "p_availability" "public"."stock_availability") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_stock_type_id" bigint DEFAULT NULL::bigint, "p_is_sellable" boolean DEFAULT NULL::boolean, "p_shipment_status" "text" DEFAULT NULL::"text", "p_hide_zero_stock" boolean DEFAULT true, "p_location_id" bigint DEFAULT NULL::bigint, "p_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_shipment_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total_count
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_tenant_id
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (
      p_is_sellable is null
      or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
      or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
    )
    and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
    and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
    and (p_location_id is null or gs.location_id = p_location_id)
    and (p_availability is null or gs.availability = p_availability)
    and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
    and (
      p_search is null or p_search = '' or (
        gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
      )
    );

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      gs.grade_tag_id,
      sl.name as location_name,
      gsi.shipment_id,
      gsi.ordered_quantity,
      gsi.name as item_name,
      gsi.product_code,
      gsi.barcode,
      gsi.image_url,
      gsi.purchase_price,
      gsi.product_weight,
      gsi.package_weight,
      gsi.landed_cost_bdt,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as resolved_landed_cost_bdt,
      gship.name as shipment_name,
      gship.type as shipment_type,
      gship.status as shipment_status,
      gship.received_weight,
      coalesce(gst.description, gs.availability::text) as stock_type_description,
      (gs.availability = 'sellable'::public.stock_availability) as is_sellable,
      public.global_stock_atp_qty(gs.id) as available_atp
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
    left join public.stock_locations sl on sl.id = gs.location_id
    where gs.parent_tenant_id = p_tenant_id
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and (p_location_id is null or gs.location_id = p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
    order by gs.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_stock_type_id" bigint, "p_is_sellable" boolean, "p_shipment_status" "text", "p_hide_zero_stock" boolean, "p_location_id" bigint, "p_availability" "public"."stock_availability", "p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_inventory_items_with_stock"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_sort_by" "text" DEFAULT 'id'::"text", "p_sort_order" "text" DEFAULT 'desc'::"text", "p_filters" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  with filtered as (
    select
      ii.id,
      ii.tenant_id,
      ii.source_type,
      ii.source_id,
      ii.product_id,
      ii.name,
      ii.image_url,
      ii.cost,
      ii.barcode,
      ii.product_code,
      ii.manufacturing_date,
      ii.expire_date,
      ii.status,
      ii.created_at,
      ii.updated_at,
      case
        when s.id is null then null
        else jsonb_build_object(
          'id', s.id,
          'inventory_item_id', s.inventory_item_id,
          'available_quantity', s.available_quantity,
          'reserved_quantity', s.reserved_quantity,
          'damaged_quantity', s.damaged_quantity,
          'stolen_quantity', s.stolen_quantity,
          'expired_quantity', s.expired_quantity,
          'open_box_quantity', s.open_box_quantity,
          'created_at', s.created_at,
          'updated_at', s.updated_at
        )
      end as stock,
      case
        when si.id is null then null
        else jsonb_build_object(
          'shipment', jsonb_build_object(
            'id', sh.id,
            'name', sh.name,
            'tenant_shipment_id', sh.tenant_shipment_id
          ),
          'shipment_item', null
        )
      end as shipment
    from public.inventory_items ii
    left join public.inventory_stocks s
      on s.inventory_item_id = ii.id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
      and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
    where ii.tenant_id = p_tenant_id
      and (
        not (p_filters ? 'name')
        or ii.name ilike ('%' || coalesce(p_filters->>'name', '') || '%')
      )
      and (
        not (p_filters ? 'status')
        or ii.status = p_filters->>'status'
      )
      and (
        not (p_filters ? 'source_type')
        or ii.source_type = p_filters->>'source_type'
      )
      and (
        not (p_filters ? 'source_id')
        or ii.source_id = nullif(p_filters->>'source_id', '')::bigint
      )
      and (
        not (p_filters ? 'product_id')
        or ii.product_id = nullif(p_filters->>'product_id', '')::bigint
      )
      and (
        not (p_filters ? 'barcode')
        or coalesce(ii.barcode, '') ilike ('%' || coalesce(p_filters->>'barcode', '') || '%')
      )
      and (
        not (p_filters ? 'product_code')
        or coalesce(ii.product_code, '') ilike ('%' || coalesce(p_filters->>'product_code', '') || '%')
      )
      and (
        not (p_filters ? 'shipment_id')
        or sh.id = nullif(p_filters->>'shipment_id', '')::bigint
      )
  ),
  counted as (
    select filtered.*, count(*) over() as total_count
    from filtered
  ),
  paged as (
    select * from counted
    order by
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'id' then id end desc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'name' then name end desc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'asc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end asc,
      case when lower(coalesce(p_sort_order, 'desc')) = 'desc' and lower(coalesce(p_sort_by, 'id')) = 'created_at' then created_at end desc,
      id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data', coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', paged.id,
          'tenant_id', paged.tenant_id,
          'source_type', paged.source_type,
          'source_id', paged.source_id,
          'product_id', paged.product_id,
          'name', paged.name,
          'image_url', paged.image_url,
          'cost', paged.cost,
          'barcode', paged.barcode,
          'product_code', paged.product_code,
          'manufacturing_date', paged.manufacturing_date,
          'expire_date', paged.expire_date,
          'status', paged.status,
          'created_at', paged.created_at,
          'updated_at', paged.updated_at,
          'stock', paged.stock,
          'shipment', paged.shipment
        )
      ),
      '[]'::jsonb
    ),
    'meta', jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$$;


ALTER FUNCTION "public"."list_inventory_items_with_stock"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_sort_by" "text", "p_sort_order" "text", "p_filters" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_pbc_backlog_items"("p_tenant_id" bigint, "p_billing_profile_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "billing_profile_id" bigint, "product_id" bigint, "open_quantity" integer, "name" "text", "image_url" "text", "barcode" "text", "product_code" "text", "price_gbp" numeric, "product_weight" numeric, "package_weight" numeric, "note" "text", "last_costing_file_id" bigint, "last_costing_item_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT (public.can_admin_manage_costing_file(p_tenant_id) OR public.can_staff_access_costing_file(p_tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', p_tenant_id;
  END IF;

  RETURN QUERY
  SELECT
    bi.id,
    bi.tenant_id,
    bi.billing_profile_id,
    bi.product_id,
    bi.open_quantity,
    bi.name,
    bi.image_url,
    bi.barcode,
    bi.product_code,
    bi.price_gbp,
    bi.product_weight,
    bi.package_weight,
    bi.note,
    bi.last_costing_file_id,
    bi.last_costing_item_id,
    bi.created_at,
    bi.updated_at
  FROM public.product_based_costing_backlog_items bi
  WHERE bi.tenant_id = p_tenant_id
    AND bi.billing_profile_id = p_billing_profile_id
  ORDER BY bi.updated_at DESC;
END;
$$;


ALTER FUNCTION "public"."list_pbc_backlog_items"("p_tenant_id" bigint, "p_billing_profile_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_product_based_costing_files"("p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "sql" STABLE
    SET "search_path" TO 'public'
    AS $$
  with filtered as (
    select
      f.*,
      count(*) over() as total_count
    from public.product_based_costing_files f
    where
      (p_tenant_id is null or f.tenant_id = p_tenant_id)
      and (
        coalesce(trim(p_search), '') = ''
        or coalesce(f.name, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.order_for, '') ilike ('%' || trim(p_search) || '%')
        or coalesce(f.note, '') ilike ('%' || trim(p_search) || '%')
      )
      and (
        coalesce(trim(p_status), '') = ''
        or f.status = trim(p_status)
      )
  ),
  paged as (
    select *
    from filtered
    order by created_at desc, id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
      case
        when coalesce(max(paged.total_count), 0) = 0 then 1
        else ceil(coalesce(max(paged.total_count), 0)::numeric / greatest(coalesce(p_page_size, 20), 1))::int
      end
    )
  )
  from paged;
$$;


ALTER FUNCTION "public"."list_product_based_costing_files"("p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shipment_items_for_shipments"("p_shipment_ids" bigint[]) RETURNS TABLE("shipment_id" bigint, "purchase_price" numeric, "product_weight" numeric, "package_weight" numeric, "ordered_quantity" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_shipment_ids is null or array_length(p_shipment_ids, 1) is null or array_length(p_shipment_ids, 1) = 0 then
    return;
  end if;

  return query
  select
    gsi.shipment_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity
  from public.global_shipment_items gsi
  inner join public.global_shipments gs on gs.id = gsi.shipment_id
  where gsi.shipment_id = any(p_shipment_ids)
    and (
      public.user_can_manage_parent_tenant(gs.parent_tenant_id)
      or exists (
        select 1 from public.memberships m
        where m.tenant_id = gs.parent_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.is_active = true
      )
    )
  order by gsi.shipment_id, gsi.sort_order, gsi.id;
end;
$$;


ALTER FUNCTION "public"."list_shipment_items_for_shipments"("p_shipment_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shipment_payee_settlements"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_ship.parent_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'vendor', public.get_payee_settlement_summary(v_ship.parent_tenant_id, p_shipment_id, 'vendor', v_ship.vendor_id),
    'cargo_company', public.get_payee_settlement_summary(v_ship.parent_tenant_id, p_shipment_id, 'cargo_company', v_ship.cargo_company_id)
  );
END;
$$;


ALTER FUNCTION "public"."list_shipment_payee_settlements"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shipment_progress_flow_stages"("p_flow_id" bigint, "p_include_archived" boolean DEFAULT true) RETURNS TABLE("flow_stage_id" bigint, "flow_id" bigint, "tag_id" bigint, "sort_order" integer, "name" "text", "slug" "text", "color" "text", "is_active" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    s.id as flow_stage_id,
    s.flow_id,
    t.id as tag_id,
    s.sort_order,
    t.name,
    t.slug,
    t.color,
    t.is_active
  from public.shipment_progress_flow_stages s
  join public.tags t on t.id = s.tag_id
  where s.flow_id = p_flow_id
    and (p_include_archived or t.is_active = true)
  order by s.sort_order asc, t.name asc;
end;
$$;


ALTER FUNCTION "public"."list_shipment_progress_flow_stages"("p_flow_id" bigint, "p_include_archived" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shipment_progress_flows"("p_tenant_id" bigint, "p_include_archived" boolean DEFAULT false) RETURNS TABLE("id" bigint, "tenant_id" bigint, "name" "text", "slug" "text", "is_active" boolean, "is_default" boolean, "created_at" timestamp with time zone, "stage_count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  return query
  select
    f.id,
    f.tenant_id,
    f.name,
    f.slug,
    f.is_active,
    f.is_default,
    f.created_at,
    count(s.id) as stage_count
  from public.shipment_progress_flows f
  left join public.shipment_progress_flow_stages s on s.flow_id = f.id
  where f.tenant_id = p_tenant_id
    and (p_include_archived or f.is_active = true)
  group by f.id
  order by f.is_default desc, f.name asc;
end;
$$;


ALTER FUNCTION "public"."list_shipment_progress_flows"("p_tenant_id" bigint, "p_include_archived" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shipment_progress_tags"("p_tenant_id" bigint, "p_include_archived" boolean DEFAULT false) RETURNS SETOF "public"."tags"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  return query
    select t.*
    from public.tags t
    where t.tenant_id = p_tenant_id
      and t.group_name = 'shipment_progress'
      and (p_include_archived or t.is_active = true)
    order by t.sort_order nulls last, t.name;
end;
$$;


ALTER FUNCTION "public"."list_shipment_progress_tags"("p_tenant_id" bigint, "p_include_archived" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_shipments_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  -- 1. Get total count of matching shipments
  select count(*)
  into v_total_count
  from public.shipments s
  where s.tenant_id = p_tenant_id
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    );

  -- 2. Get paginated records as a jsonb array
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select *
    from public.shipments s
    where s.tenant_id = p_tenant_id
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
    order by s.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- 3. Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$_$;


ALTER FUNCTION "public"."list_shipments_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_stock_locations"("p_parent_tenant_id" bigint, "p_include_inactive" boolean DEFAULT false) RETURNS SETOF "public"."stock_locations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public._assert_parent_warehouse_tenant(p_parent_tenant_id);

  if not public._can_view_stock_locations(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select l.*
  from public.stock_locations l
  where l.parent_tenant_id = p_parent_tenant_id
    and (p_include_inactive or l.is_active = true)
  order by l.sort_order asc, l.code asc, l.id asc;
end;
$$;


ALTER FUNCTION "public"."list_stock_locations"("p_parent_tenant_id" bigint, "p_include_inactive" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_stock_movements"("p_tenant_id" bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_data jsonb;
  v_total bigint;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select count(*) into v_total
  from public.stock_movements m
  where m.tenant_id = p_tenant_id;

  select coalesce(jsonb_agg(to_jsonb(m) order by m.id desc), '[]'::jsonb)
  into v_data
  from (
    select * from public.stock_movements
    where tenant_id = p_tenant_id
    order by id desc
    limit p_limit offset p_offset
  ) m;

  return jsonb_build_object('data', v_data, 'total', v_total);
end;
$$;


ALTER FUNCTION "public"."list_stock_movements"("p_tenant_id" bigint, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_vendor_markets"() RETURNS TABLE("code" "text", "name" "text", "region" "text")
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select m.code, m.name, m.region
  from public.markets m
  where m.is_active = true
  order by m.name asc;
$$;


ALTER FUNCTION "public"."list_vendor_markets"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_vendors_for_tenant"("p_tenant_id" bigint) RETURNS SETOF "public"."vendors"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    return query
    select v.*
    from public.vendors v
    where v.tenant_id is null
    order by v.id asc;

    return;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.is_child_tenant(p_tenant_id) then
    return query
    select v.*
    from public.vendors v
    where v.tenant_id = p_tenant_id
    order by v.id asc;
  else
    return query
    select v.*
    from public.vendors v
    where v.parent_tenant_id = p_tenant_id
    order by v.id asc;
  end if;
end;
$$;


ALTER FUNCTION "public"."list_vendors_for_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."migrate_legacy_inventory_to_global_stock"("p_tenant_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item record;
  v_stock_id bigint;
  v_parent_id bigint;
  v_migrated integer := 0;
begin
  for v_item in
    select ii.*
    from public.inventory_items ii
    where (p_tenant_id is null or ii.tenant_id = p_tenant_id)
      and not exists (
        select 1 from public.global_stocks gs
        where gs.legacy_inventory_item_id = ii.id
      )
  loop
    v_parent_id := public.resolve_parent_tenant_id(v_item.tenant_id);

    insert into public.global_stocks (
      tenant_id,
      parent_tenant_id,
      name,
      cost,
      image_url,
      product_code,
      barcode,
      product_id,
      source_module,
      source_type,
      source_id,
      legacy_inventory_item_id
    )
    values (
      v_parent_id,
      v_parent_id,
      v_item.name,
      coalesce(v_item.cost, 0),
      v_item.image_url,
      v_item.product_code,
      v_item.barcode,
      v_item.product_id,
      'wholesale',
      coalesce(v_item.source_type, 'migration'),
      v_item.source_id,
      v_item.id
    )
    returning id into v_stock_id;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'excellent', coalesce(s.available_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.available_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'box_less', coalesce(s.open_box_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.open_box_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'expired', coalesce(s.expired_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.expired_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'stolen', coalesce(s.stolen_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.stolen_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    v_migrated := v_migrated + 1;
  end loop;

  return jsonb_build_object('migrated_count', v_migrated);
end;
$$;


ALTER FUNCTION "public"."migrate_legacy_inventory_to_global_stock"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_costing_file_item_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.website_url := trim(coalesce(new.website_url, ''));

  if new.image_url is not null then
    new.image_url := nullif(trim(new.image_url), '');
  end if;

  if new.name is not null then
    new.name := nullif(trim(new.name), '');
  end if;

  if new.item_type is not null then
    new.item_type := nullif(trim(new.item_type), '');
  end if;

  if new.size is not null then
    new.size := nullif(trim(new.size), '');
  end if;

  if new.color is not null then
    new.color := nullif(trim(new.color), '');
  end if;

  if new.extra_information_1 is not null then
    new.extra_information_1 := nullif(trim(new.extra_information_1), '');
  end if;

  if new.extra_information_2 is not null then
    new.extra_information_2 := nullif(trim(new.extra_information_2), '');
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."normalize_costing_file_item_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_costing_file_market"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  if new.market is null then
    return new;
  end if;

  new.market := nullif(upper(trim(new.market)), '');
  return new;
end;
$$;


ALTER FUNCTION "public"."normalize_costing_file_market"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_costing_file_status_po_placed"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.status::text = 'completed' then
    new.status = 'po_placed'::public.costing_file_status;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."normalize_costing_file_status_po_placed"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."normalize_vendor_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.name = trim(new.name);
  new.code = upper(trim(new.code));
  new.market_code = upper(trim(new.market_code));

  if new.email is not null then
    new.email = nullif(lower(trim(new.email)), '');
  end if;

  if new.phone is not null then
    new.phone = nullif(trim(new.phone), '');
  end if;

  if new.address is not null then
    new.address = nullif(trim(new.address), '');
  end if;

  if new.website is not null then
    new.website = nullif(trim(new.website), '');
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."normalize_vendor_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."pay_settle_shipment_costs"("p_shipment_id" bigint, "p_cost_entry_ids" bigint[] DEFAULT NULL::bigint[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry public.global_shipment_cost_entries%rowtype;
  v_amount numeric;
  v_settled_count integer := 0;
  v_wallet_posted boolean := false;
  v_ledger jsonb;
  v_wallet_entity_type text;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before settlement';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_entry in
    select *
    from public.global_shipment_cost_entries
    where shipment_id = p_shipment_id
      and (p_cost_entry_ids is null or id = any(p_cost_entry_ids))
      and payment_source is not null
      and entity_type is not null
      and entity_id is not null
      and settled_at is null
  loop
    if v_entry.entity_type = 'shipment' then
      raise exception 'cost entry % cannot settle shipment entity', v_entry.id;
    end if;

    v_amount := round(coalesce(v_entry.amount, 0) * coalesce(v_entry.exchange_rate, 1), 4);
    if v_amount <= 0 then
      continue;
    end if;

    v_wallet_entity_type := case
      when v_entry.entity_type = 'cargo_company' then 'cargo_company'
      else v_entry.entity_type
    end;

    if v_entry.payment_source in ('cash', 'wallet') then
      v_ledger := public.record_ledger_transaction(
        p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
        p_entity_type => v_wallet_entity_type,
        p_entity_id => v_entry.entity_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', v_entry.payment_source,
          'purpose', 'shipment_cost_settle_payee'
        ),
        p_target_bucket => 'available'
      );

      v_ledger := public.record_ledger_transaction(
        p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
        p_entity_type => 'tenant',
        p_entity_id => v_ship.parent_tenant_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', v_entry.payment_source,
          'purpose', 'shipment_cost_settle_tenant_cash'
        ),
        p_target_bucket => 'available'
      );
      v_wallet_posted := true;

    elsif v_entry.payment_source = 'credit' then
      v_ledger := public.record_ledger_transaction(
        p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
        p_entity_type => v_wallet_entity_type,
        p_entity_id => v_entry.entity_id,
        p_type => 'credit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'shipment',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object(
          'cost_entry_id', v_entry.id,
          'payment_source', 'credit',
          'purpose', 'shipment_cost_credit_payable'
        ),
        p_target_bucket => 'pending'
      );
      v_wallet_posted := true;
    else
      raise exception 'unsupported payment_source % on entry %', v_entry.payment_source, v_entry.id;
    end if;

    update public.global_shipment_cost_entries
    set
      settled_at = now(),
      settlement_ledger_id = coalesce((v_ledger->>'id')::uuid, settlement_ledger_id),
      updated_at = now()
    where id = v_entry.id;

    v_settled_count := v_settled_count + 1;
  end loop;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'settled_entries_count', v_settled_count,
    'wallet_posted', v_wallet_posted and v_settled_count > 0
  );
end;
$$;


ALTER FUNCTION "public"."pay_settle_shipment_costs"("p_shipment_id" bigint, "p_cost_entry_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."post_stock_movement"("p_movement_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_mov public.stock_movements%rowtype;
  v_line public.stock_movement_lines%rowtype;
  v_stock public.global_stocks%rowtype;
  v_target_stock public.global_stocks%rowtype;
  v_target_avail public.stock_availability;
  v_target_loc bigint;
  v_target_grade bigint;
  v_move_qty int;
  v_new_qty int;
begin
  select * into v_mov
  from public.stock_movements
  where id = p_movement_id
  for update;

  if not found then
    raise exception 'stock movement not found';
  end if;

  if v_mov.is_posted then
    raise exception 'stock movement already posted';
  end if;

  if not public.can_act_on_parent_tenant_stock(v_mov.tenant_id) then
    raise exception 'not authorized';
  end if;

  for v_line in
    select * from public.stock_movement_lines where movement_id = p_movement_id
  loop
    if v_line.stock_id is null then
      continue;
    end if;

    select * into v_stock
    from public.global_stocks
    where id = v_line.stock_id
    for update;

    if not found then
      raise exception 'stock % not found for movement line', v_line.stock_id;
    end if;

    v_move_qty := coalesce(v_line.quantity::int, 0);
    if v_move_qty <= 0 then
      continue;
    end if;

    case v_mov.movement_type
      when 'adjustment' then
        if v_line.to_availability is not null and v_line.from_availability is null then
          v_new_qty := v_stock.quantity + v_move_qty;
        else
          v_new_qty := v_stock.quantity - v_move_qty;
        end if;

        if v_new_qty < 0 then
          raise exception 'adjustment would make stock % negative', v_line.stock_id;
        end if;

        update public.global_stocks
        set
          quantity = v_new_qty,
          location_id = coalesce(v_line.to_location_id, location_id),
          availability = coalesce(v_line.to_availability, availability),
          grade_tag_id = coalesce(v_line.to_grade_tag_id, grade_tag_id, public.default_stock_grade_tag_id()),
          updated_at = now()
        where id = v_line.stock_id;

      when 'location_transfer', 'availability_transfer', 'grade_change', 'receive_putaway' then
        v_target_avail := coalesce(v_line.to_availability, v_stock.availability);
        v_target_loc := coalesce(v_line.to_location_id, v_stock.location_id);
        v_target_grade := coalesce(v_line.to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id());

        if v_stock.quantity < v_move_qty then
          raise exception 'insufficient stock quantity on stock % (requested %, available %)',
            v_line.stock_id, v_move_qty, v_stock.quantity;
        end if;

        if v_target_avail = v_stock.availability
           and v_target_loc = v_stock.location_id
           and v_target_grade = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id()) then
          update public.global_stocks
          set updated_at = now()
          where id = v_stock.id;
        else
          select * into v_target_stock
          from public.global_stocks
          where shipment_item_id = v_stock.shipment_item_id
            and availability = v_target_avail
            and location_id = v_target_loc
            and grade_tag_id = v_target_grade
          for update;

          if found then
            update public.global_stocks
            set quantity = quantity + v_move_qty, updated_at = now()
            where id = v_target_stock.id;

            if v_stock.quantity = v_move_qty then
              delete from public.global_stocks where id = v_stock.id;
              update public.stock_movement_lines
              set stock_id = v_target_stock.id
              where id = v_line.id;
            else
              update public.global_stocks
              set quantity = quantity - v_move_qty, updated_at = now()
              where id = v_stock.id;
            end if;
          else
            if v_stock.quantity = v_move_qty then
              update public.global_stocks
              set
                availability = v_target_avail,
                location_id = v_target_loc,
                grade_tag_id = v_target_grade,
                updated_at = now()
              where id = v_stock.id;
            else
              insert into public.global_stocks (
                parent_tenant_id,
                shipment_item_id,
                stock_type_id,
                quantity,
                is_usable,
                availability,
                location_id,
                grade_tag_id
              ) values (
                v_stock.parent_tenant_id,
                v_stock.shipment_item_id,
                v_stock.stock_type_id,
                v_move_qty,
                (v_target_avail = 'sellable'::public.stock_availability),
                v_target_avail,
                v_target_loc,
                v_target_grade
              );

              update public.global_stocks
              set quantity = quantity - v_move_qty, updated_at = now()
              where id = v_stock.id;
            end if;
          end if;
        end if;

      when 'return_inbound' then
        if v_mov.reference_type = 'shipment_return' then
          v_new_qty := v_stock.quantity - v_move_qty;
          if v_new_qty < 0 then
            raise exception 'return would make stock % negative', v_line.stock_id;
          end if;
          if v_new_qty = 0 then
            delete from public.global_stocks where id = v_stock.id;
          else
            update public.global_stocks
            set quantity = v_new_qty, updated_at = now()
            where id = v_stock.id;
          end if;
        else
          v_target_avail := coalesce(v_line.to_availability, 'held'::public.stock_availability);
          v_target_loc := coalesce(
            v_line.to_location_id,
            public.default_returns_stock_location_id(v_stock.parent_tenant_id)
          );
          v_target_grade := coalesce(
            v_line.to_grade_tag_id,
            public.default_stock_grade_tag_id()
          );

          select * into v_target_stock
          from public.global_stocks
          where shipment_item_id = v_stock.shipment_item_id
            and availability = v_target_avail
            and location_id = v_target_loc
            and grade_tag_id = v_target_grade
          for update;

          if found then
            update public.global_stocks
            set quantity = quantity + v_move_qty, updated_at = now()
            where id = v_target_stock.id;
          else
            insert into public.global_stocks (
              parent_tenant_id,
              shipment_item_id,
              stock_type_id,
              quantity,
              is_usable,
              availability,
              location_id,
              grade_tag_id
            ) values (
              v_stock.parent_tenant_id,
              v_stock.shipment_item_id,
              v_stock.stock_type_id,
              v_move_qty,
              (v_target_avail = 'sellable'::public.stock_availability),
              v_target_avail,
              v_target_loc,
              v_target_grade
            );
          end if;
        end if;

      when 'receive_rollback' then
        v_new_qty := v_stock.quantity - v_move_qty;
        if v_new_qty < 0 then
          raise exception 'return would make stock % negative', v_line.stock_id;
        end if;
        if v_new_qty = 0 then
          delete from public.global_stocks where id = v_stock.id;
        else
          update public.global_stocks
          set quantity = v_new_qty, updated_at = now()
          where id = v_stock.id;
        end if;

      else
        raise exception 'unsupported movement type %', v_mov.movement_type;
    end case;
  end loop;

  update public.stock_movements
  set is_posted = true, posted_at = now(), updated_at = now()
  where id = p_movement_id;

  return jsonb_build_object(
    'movement_id', p_movement_id,
    'is_posted', true,
    'posted_at', now()
  );
end;
$$;


ALTER FUNCTION "public"."post_stock_movement"("p_movement_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_product_based_costing_file_offer_prices"("p_file_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
declare
  v_conversion_rate numeric;
  v_cargo_rate numeric;
  v_profit_rate numeric;
begin
  select conversion_rate, cargo_rate_kg_gbp, profit_rate
    into v_conversion_rate, v_cargo_rate, v_profit_rate
    from public.product_based_costing_files
   where id = p_file_id;

  update public.product_based_costing_items
     set offer_price = public.round_bdt_up_to_zero_or_five(
           ceil(
             round(
               (coalesce(price_gbp, 0) + ((coalesce(product_weight, 0) + coalesce(package_weight, 0)) / 1000.0) * coalesce(v_cargo_rate, 0)),
               2
             ) * coalesce(v_conversion_rate, 140) - 1e-9
           ) + (
             ceil(
               round(
                 (coalesce(price_gbp, 0) + ((coalesce(product_weight, 0) + coalesce(package_weight, 0)) / 1000.0) * coalesce(v_cargo_rate, 0)),
                 2
               ) * coalesce(v_conversion_rate, 140) - 1e-9
             ) * coalesce(v_profit_rate, 25) / 100.0
           )
         ),
         is_offer_price_manual = false
   where product_based_costing_file_id = p_file_id
     and (is_offer_price_manual is not true);
end;
$$;


ALTER FUNCTION "public"."recalculate_product_based_costing_file_offer_prices"("p_file_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recalculate_shipment_transaction_rate"("p_shipment_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_product_conv numeric;
  v_cargo_conv numeric;
  v_cargo_rate numeric;
  v_received_weight numeric;
  v_shipment_type text;
  v_goods_cost_gbp numeric := 0;
  v_goods_cost_bdt numeric := 0;
  v_cargo_weight numeric := 0;
  v_cargo_cost_gbp numeric := 0;
  v_cargo_cost_bdt numeric := 0;
  v_total_cost_gbp numeric := 0;
  v_total_cost_bdt numeric := 0;
  v_transaction_rate numeric;
begin
  select
    product_conversion_rate,
    cargo_conversion_rate,
    cargo_rate,
    received_weight,
    shipment_type
  into
    v_product_conv,
    v_cargo_conv,
    v_cargo_rate,
    v_received_weight,
    v_shipment_type
  from public.shipments
  where id = p_shipment_id;

  if coalesce(v_shipment_type, 'international') <> 'international' then
    update public.shipments
    set transaction_rate = null
    where id = p_shipment_id;
    return null;
  end if;

  select coalesce(sum(price_gbp * quantity), 0)
  into v_goods_cost_gbp
  from public.shipment_items
  where shipment_id = p_shipment_id;

  v_goods_cost_bdt := coalesce(v_product_conv, 0) * v_goods_cost_gbp;
  v_cargo_weight := coalesce(v_received_weight, 0);
  v_cargo_cost_gbp := v_cargo_weight * coalesce(v_cargo_rate, 0);
  v_cargo_cost_bdt := v_cargo_cost_gbp * coalesce(v_cargo_conv, 0);
  v_total_cost_gbp := v_goods_cost_gbp + v_cargo_cost_gbp;
  v_total_cost_bdt := v_goods_cost_bdt + v_cargo_cost_bdt;

  if v_total_cost_gbp > 0 then
    v_transaction_rate := v_total_cost_bdt / v_total_cost_gbp;
  else
    v_transaction_rate := (coalesce(v_product_conv, 0) + coalesce(v_cargo_conv, 0)) / 2.0;
  end if;

  update public.shipments
  set transaction_rate = round(coalesce(v_transaction_rate, 1.0), 2)
  where id = p_shipment_id;

  return v_transaction_rate;
end;
$$;


ALTER FUNCTION "public"."recalculate_shipment_transaction_rate"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_vendor_grn_payable"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_source_id" "text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_res jsonb;
begin
  if p_tenant_id is null or p_vendor_id is null then
    raise exception 'Tenant ID and Vendor ID are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'GRN payable amount must be positive.';
  end if;

  v_res := public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'vendor',
    p_entity_id => p_vendor_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => p_source_id,
    p_metadata => jsonb_build_object(
      'section', 'procurement',
      'purpose', 'vendor_grn_payable',
      'transaction_type', 'vendor_payable',
      'label', 'Vendor Payable (GRN Received)'
    ) || coalesce(p_metadata, '{}'::jsonb)
  );

  return jsonb_build_object('success', true, 'entry', v_res);
end;
$$;


ALTER FUNCTION "public"."record_vendor_grn_payable"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_source_id" "text", "p_metadata" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_vendor_payment_outflow"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_payment_method" "text" DEFAULT 'bank_transfer'::"text", "p_reference" "text" DEFAULT NULL::"text", "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_payment_id text;
  v_vendor_res jsonb;
  v_tenant_res jsonb;
begin
  if p_tenant_id is null or p_vendor_id is null then
    raise exception 'Tenant ID and Vendor ID are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Vendor payment amount must be positive.';
  end if;

  v_payment_id := 'VP-' || gen_random_uuid()::text;

  -- Leg 1: Debit Vendor AP (reduces vendor payable balance)
  v_vendor_res := public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'vendor',
    p_entity_id => p_vendor_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => v_payment_id,
    p_metadata => jsonb_build_object(
      'section', 'vendor_payments',
      'purpose', 'vendor_ap_settlement',
      'transaction_type', 'vendor_payment_paid',
      'label', 'Vendor Payment Settled',
      'payment_method', p_payment_method,
      'reference', p_reference,
      'notes', p_note
    )
  );

  -- Leg 2: Debit Tenant Cash (cash outflow from bank/cash account)
  v_tenant_res := public.record_ledger_transaction(
    p_parent_tenant_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => public.resolve_parent_tenant_id(p_tenant_id),
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => v_payment_id,
    p_metadata => jsonb_build_object(
      'section', 'vendor_payments',
      'purpose', 'tenant_vendor_cash_outflow',
      'transaction_type', 'vendor_payment_paid',
      'label', 'Cash Outflow (Vendor Payment)',
      'vendor_id', p_vendor_id,
      'payment_method', p_payment_method,
      'reference', p_reference,
      'notes', p_note
    )
  );

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'vendor_entry', v_vendor_res,
    'tenant_entry', v_tenant_res
  );
end;
$$;


ALTER FUNCTION "public"."record_vendor_payment_outflow"("p_tenant_id" bigint, "p_vendor_id" bigint, "p_amount" numeric, "p_payment_method" "text", "p_reference" "text", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_costing_file_item_calculations_for_file"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if
    new.cargo_rate_1kg is distinct from old.cargo_rate_1kg
    or new.cargo_rate_2kg is distinct from old.cargo_rate_2kg
    or new.conversion_rate is distinct from old.conversion_rate
    or new.admin_profit_rate is distinct from old.admin_profit_rate
  then
    update public.costing_file_items cfi
    set updated_at = now()
    where cfi.costing_file_id = new.id;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."refresh_costing_file_item_calculations_for_file"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_shipment_inventory_accounting"("p_tenant_id" bigint, "p_shipment_id" bigint DEFAULT NULL::bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_rows integer := 0;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Not allowed to refresh shipment inventory accounting for this tenant.';
  end if;

  insert into public.shipment_inventory_accounting (
    tenant_id,
    shipment_id,
    usable_quantity,
    damaged_quantity,
    stolen_quantity,
    expired_quantity,
    usable_cost_total,
    damaged_cost_total,
    stolen_cost_total,
    expired_cost_total,
    inventory_cost_total
  )
  select
    s.tenant_id,
    s.id as shipment_id,
    coalesce(sum(greatest(
      0,
      coalesce(ist.available_quantity, 0)
      - coalesce(ist.reserved_quantity, 0)
      - coalesce(ist.damaged_quantity, 0)
      - coalesce(ist.stolen_quantity, 0)
      - coalesce(ist.expired_quantity, 0)
    )), 0)::integer as usable_quantity,
    coalesce(sum(coalesce(ist.damaged_quantity, 0)), 0)::integer as damaged_quantity,
    coalesce(sum(coalesce(ist.stolen_quantity, 0)), 0)::integer as stolen_quantity,
    coalesce(sum(coalesce(ist.expired_quantity, 0)), 0)::integer as expired_quantity,
    coalesce(sum(coalesce(ii.cost, 0) * greatest(
      0,
      coalesce(ist.available_quantity, 0)
      - coalesce(ist.reserved_quantity, 0)
      - coalesce(ist.damaged_quantity, 0)
      - coalesce(ist.stolen_quantity, 0)
      - coalesce(ist.expired_quantity, 0)
    )), 0)::numeric(14, 2) as usable_cost_total,
    coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.damaged_quantity, 0)), 0)::numeric(14, 2) as damaged_cost_total,
    coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.stolen_quantity, 0)), 0)::numeric(14, 2) as stolen_cost_total,
    coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.expired_quantity, 0)), 0)::numeric(14, 2) as expired_cost_total,
    (
      coalesce(sum(coalesce(ii.cost, 0) * greatest(
        0,
        coalesce(ist.available_quantity, 0)
        - coalesce(ist.reserved_quantity, 0)
        - coalesce(ist.damaged_quantity, 0)
        - coalesce(ist.stolen_quantity, 0)
        - coalesce(ist.expired_quantity, 0)
      )), 0)
      + coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.damaged_quantity, 0)), 0)
      + coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.stolen_quantity, 0)), 0)
      + coalesce(sum(coalesce(ii.cost, 0) * coalesce(ist.expired_quantity, 0)), 0)
    )::numeric(14, 2) as inventory_cost_total
  from public.shipments s
  left join public.shipment_items si
    on si.shipment_id = s.id
  left join public.inventory_items ii
    on ii.tenant_id = s.tenant_id
    and ii.source_type = 'shipment'
    and ii.source_id = si.id
  left join public.inventory_stocks ist
    on ist.inventory_item_id = ii.id
  where s.tenant_id = p_tenant_id
    and (p_shipment_id is null or s.id = p_shipment_id)
  group by s.tenant_id, s.id
  on conflict (tenant_id, shipment_id)
  do update
  set
    usable_quantity = excluded.usable_quantity,
    damaged_quantity = excluded.damaged_quantity,
    stolen_quantity = excluded.stolen_quantity,
    expired_quantity = excluded.expired_quantity,
    usable_cost_total = excluded.usable_cost_total,
    damaged_cost_total = excluded.damaged_cost_total,
    stolen_cost_total = excluded.stolen_cost_total,
    expired_cost_total = excluded.expired_cost_total,
    inventory_cost_total = excluded.inventory_cost_total,
    updated_at = now();

  get diagnostics v_rows = row_count;
  return v_rows;
end;
$$;


ALTER FUNCTION "public"."refresh_shipment_inventory_accounting"("p_tenant_id" bigint, "p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."refresh_shipment_investor_profits"("p_global_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shipment public.global_shipments;
  v_pnl jsonb;
  v_buy numeric(12,2);
  v_profit numeric(12,2);
  v_updated integer := 0;
  v_inv record;
  v_status text;
  v_sold_qty numeric;
  v_received_qty numeric;
  v_computed_profit numeric(12,2);
begin
  select * into v_shipment from public.global_shipments where id = p_global_shipment_id;
  if v_shipment.id is null then raise exception 'global shipment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_pnl := public.get_shipment_pnl(v_shipment.parent_tenant_id, p_global_shipment_id);
  v_buy := coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00);
  v_profit := coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00);

  select
    coalesce(sum(ordered_quantity), 0),
    coalesce(sum(sold_qty), 0)
  into v_received_qty, v_sold_qty
  from (
    select
      si.ordered_quantity,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    where si.shipment_id = p_global_shipment_id
    group by si.id, si.ordered_quantity
  ) t;

  if v_received_qty = 0 then
    v_status := 'open';
  elsif v_sold_qty >= v_received_qty then
    v_status := 'realized';
  elsif v_sold_qty > 0 then
    v_status := 'partial';
  else
    v_status := 'open';
  end if;

  for v_inv in
    select * from public.shipment_investments
    where global_shipment_id = p_global_shipment_id
      and status = 'active'
      and cost_share_pct is not null
  loop
    v_computed_profit := round(v_profit * v_inv.cost_share_pct / 100.0, 2);

    update public.shipment_investments
    set
      allocated_cost = round(v_buy * v_inv.cost_share_pct / 100.0, 2),
      computed_profit = v_computed_profit,
      profit_status = v_status
    where id = v_inv.id;

    -- Update investor pending profit bucket if profit is realized
    if v_computed_profit > 0 and v_status = 'realized' then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where tenant_id = v_shipment.parent_tenant_id
          and entity_type = 'investor'
          and entity_id = v_inv.investor_id
          and source_type = 'vendor_purchase'
          and source_id = p_global_shipment_id::text
          and metadata->>'purpose' = 'shipment_investor_profit'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => v_shipment.parent_tenant_id, p_operating_tenant_id => coalesce(v_shipment.assigned_child_tenant_id, v_shipment.parent_tenant_id),
          p_entity_type => 'investor',
          p_entity_id => v_inv.investor_id,
          p_type => 'credit',
          p_amount => v_computed_profit,
          p_currency_code => 'BDT',
          p_exchange_rate => 1.000000,
          p_source_type => 'vendor_purchase',
          p_source_id => p_global_shipment_id::text,
          p_metadata => jsonb_build_object(
            'section', 'investor_capital',
            'purpose', 'shipment_investor_profit',
            'transaction_type', 'profit_accrued',
            'label', 'Shipment Profit Distribution',
            'shipment_id', p_global_shipment_id
          ),
          p_target_bucket => 'pending'
        );
      end if;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'global_shipment_id', p_global_shipment_id,
    'updated_count', v_updated,
    'buy_cost_total', v_buy,
    'profit_total', v_profit,
    'profit_status', v_status
  );
end;
$$;


ALTER FUNCTION "public"."refresh_shipment_investor_profits"("p_global_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reorder_shipment_progress_flow_stages"("p_flow_id" bigint, "p_flow_stage_ids" bigint[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_flow public.shipment_progress_flows;
  v_idx integer;
  v_stage_id bigint;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_flow_stage_ids is null or array_length(p_flow_stage_ids, 1) is null then
    return;
  end if;

  -- Unique (flow_id, sort_order) is checked per row; park first so swaps
  -- do not collide with a sort_order another stage still holds.
  update public.shipment_progress_flow_stages
  set sort_order = (-id)::integer
  where flow_id = p_flow_id
    and id = any(p_flow_stage_ids);

  for v_idx in 1..array_length(p_flow_stage_ids, 1) loop
    v_stage_id := p_flow_stage_ids[v_idx];

    update public.shipment_progress_flow_stages
    set sort_order = v_idx
    where id = v_stage_id
      and flow_id = p_flow_id;
  end loop;
end;
$$;


ALTER FUNCTION "public"."reorder_shipment_progress_flow_stages"("p_flow_id" bigint, "p_flow_stage_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."reorder_shipment_progress_tags"("p_tenant_id" bigint, "p_tag_ids" bigint[]) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_idx integer;
  v_id  bigint;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  for v_idx in 1..array_length(p_tag_ids, 1) loop
    v_id := p_tag_ids[v_idx];

    update public.tags
    set sort_order = v_idx
    where id = v_id
      and tenant_id = p_tenant_id
      and group_name = 'shipment_progress';
  end loop;
end;
$$;


ALTER FUNCTION "public"."reorder_shipment_progress_tags"("p_tenant_id" bigint, "p_tag_ids" bigint[]) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") RETURNS "text"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select case
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and (
          (m.tenant_id = p_tenant_id and m.role = 'admin')
          or (m.tenant_id is null and m.role = 'superadmin')
        )
    ) then 'admin'
    when exists (
      select 1
      from public.memberships m
      where lower(trim(m.email)) = lower(trim(coalesce(p_created_by_email, '')))
        and m.is_active = true
        and m.tenant_id = p_tenant_id
        and m.role = 'staff'
    ) then 'staff'
    else coalesce(
      (
        select cg.name
        from public.customer_group_members cgm
        inner join public.customer_groups cg
          on cg.id = cgm.customer_group_id
        where lower(trim(cgm.email)) = lower(trim(coalesce(p_created_by_email, '')))
          and cgm.is_active = true
          and cg.is_active = true
          and cgm.customer_group_id = p_customer_group_id
        limit 1
      ),
      'Unknown'
    )
  end;
$$;


ALTER FUNCTION "public"."resolve_costing_file_creator_label"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_created_by_email" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."return_shipment_to_vendor"("p_shipment_id" bigint, "p_items_qty" "jsonb", "p_outcome" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_item jsonb;
  v_stock_id bigint;
  v_shipment_item_id bigint;
  v_qty numeric;
  v_mov_id bigint;
  v_amount numeric := 0;
  v_ledger jsonb;
  v_vendor_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before return';
  end if;

  if p_outcome not in ('cash_refund', 'store_credit') then
    raise exception 'outcome must be cash_refund or store_credit';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_vendor_id := v_ship.vendor_id;

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    v_ship.parent_tenant_id,
    'VR-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('stock_movements_id_seq')::text, 6, '0'),
    'return_inbound',
    'shipment_return',
    p_shipment_id::text,
    'Vendor return outcome: ' || p_outcome,
    public.current_user_email()
  )
  returning id into v_mov_id;

  for v_item in select value from jsonb_array_elements(coalesce(p_items_qty, '[]'::jsonb))
  loop
    v_stock_id := (v_item->>'global_stock_id')::bigint;
    v_shipment_item_id := (v_item->>'shipment_item_id')::bigint;
    v_qty := coalesce((v_item->>'quantity')::numeric, 0);

    if v_stock_id is null and v_shipment_item_id is not null then
      select gs.id into v_stock_id
      from public.global_stocks gs
      join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = v_shipment_item_id
        and gs.parent_tenant_id = v_ship.parent_tenant_id
        and gst.is_sellable = true
        and gs.availability = 'sellable'::public.stock_availability
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_id is null or v_qty <= 0 then
      continue;
    end if;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, from_availability, to_availability
    ) values (
      v_mov_id, v_stock_id, v_qty, 'sellable'::public.stock_availability, 'held'::public.stock_availability
    );

    v_amount := v_amount + (v_qty * coalesce(
      (select gsi.landed_cost_bdt from public.global_stocks gs
       join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gs.id = v_stock_id),
      0
    ));
  end loop;

  perform public.post_stock_movement(v_mov_id);

  if v_amount <= 0 then
    v_amount := coalesce((
      select sum(coalesce(e.amount, 0) * coalesce(e.exchange_rate, 1))
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id and e.cost_type = 'product'
    ), 0);
  end if;

  if p_outcome = 'cash_refund' then
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_ship.parent_tenant_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
    );
    if v_vendor_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
        p_entity_type => 'vendor',
        p_entity_id => v_vendor_id,
        p_type => 'debit',
        p_amount => v_amount,
        p_currency_code => 'BDT',
        p_source_type => 'shipment_return',
        p_source_id => p_shipment_id::text,
        p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
      );
    end if;
  else
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => 'vendor',
      p_entity_id => v_vendor_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'store_credit', 'movement_id', v_mov_id)
    );
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcome', p_outcome,
    'movement_id', v_mov_id,
    'return_processed', true,
    'wallet_posted', true,
    'amount_bdt', v_amount
  );
end;
$$;


ALTER FUNCTION "public"."return_shipment_to_vendor"("p_shipment_id" bigint, "p_items_qty" "jsonb", "p_outcome" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revise_global_shipment_costs"("p_shipment_id" bigint, "p_entries" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_stamped integer;
  v_old_costs jsonb;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if not (v_ship.stock_ready = true or v_ship.status = 'received') then
    raise exception 'shipment not finalized; use upsert_global_shipment_cost_entry';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception 'p_entries must be a non-empty array';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'cost_type', e.cost_type,
    'amount', e.amount,
    'exchange_rate', e.exchange_rate,
    'landed_snapshot', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'item_id', i.id,
        'landed_cost_bdt', i.landed_cost_bdt
      )), '[]'::jsonb)
      from public.global_shipment_items i
      where i.shipment_id = p_shipment_id
    )
  )), '[]'::jsonb)
  into v_old_costs
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  -- Replace all entries for this shipment with the provided set
  delete from public.global_shipment_cost_entries where shipment_id = p_shipment_id;

  for v_entry in select value from jsonb_array_elements(p_entries)
  loop
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_type,
      amount,
      currency_id,
      exchange_rate,
      payment_source,
      entity_type,
      entity_id,
      allocation,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      (v_entry->>'cost_type')::public.global_shipment_cost_type,
      (v_entry->>'amount')::numeric,
      nullif(v_entry->>'currency_id', '')::bigint,
      coalesce(nullif(v_entry->>'exchange_rate', '')::numeric, 1.0),
      nullif(v_entry->>'payment_source', ''),
      nullif(v_entry->>'entity_type', ''),
      nullif(v_entry->>'entity_id', '')::bigint,
      nullif(v_entry->>'allocation', ''),
      coalesce(v_entry->'metadata', '{}'::jsonb)
    );
  end loop;

  -- Re-stamp only — no wallet delta, no invoice line rewrite
  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'prior_entries', v_old_costs,
    'wallet_posted', false
  );
end;
$$;


ALTER FUNCTION "public"."revise_global_shipment_costs"("p_shipment_id" bigint, "p_entries" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) RETURNS TABLE("costing_file_viewer_id" bigint, "costing_file_id" bigint, "membership_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  delete from public.costing_file_viewers cfv
  using public.costing_files cf
  where cf.id = p_costing_file_id
    and cf.id = cfv.costing_file_id
    and cfv.membership_id = p_membership_id
    and public.can_manage_costing_file_viewers(cf.tenant_id)
  returning
    cfv.id as costing_file_viewer_id,
    cfv.costing_file_id,
    cfv.membership_id,
    cfv.created_at,
    cfv.updated_at;
$$;


ALTER FUNCTION "public"."revoke_costing_file_viewer"("p_costing_file_id" bigint, "p_membership_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."revoke_shipment_tracking_token"("p_shipment_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  update public.global_shipments
  set public_tracking_token = null, updated_at = now()
  where id = p_shipment_id;
end;
$$;


ALTER FUNCTION "public"."revoke_shipment_tracking_token"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."search_stock_network"("p_context_tenant_id" bigint, "p_mode" "text" DEFAULT 'search'::"text", "p_search" "text" DEFAULT NULL::"text", "p_search_field" "text" DEFAULT NULL::"text", "p_product_id" bigint DEFAULT NULL::bigint, "p_status" "text" DEFAULT 'excellent'::"text", "p_shipment_id" bigint DEFAULT NULL::bigint, "p_exclude_zero_qty" boolean DEFAULT true, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("global_stock_id" bigint, "product_id" bigint, "name" "text", "barcode" "text", "product_code" "text", "image_url" "text", "shipment_item_id" bigint, "ordered_quantity" integer, "purchase_price" numeric, "product_weight" numeric, "package_weight" numeric, "shipment_type" "text", "product_conversion_rate" numeric, "cargo_conversion_rate" numeric, "cargo_rate" numeric, "received_weight" numeric, "transaction_rate" numeric, "shipment_id" bigint, "shipment_name" "text", "parent_tenant_id" bigint, "holding_tenant_id" bigint, "holding_tenant_name" "text", "allocated_qty" integer, "global_qty" integer, "excellent_qty" integer, "box_less_qty" integer, "box_damage_qty" integer, "expired_qty" integer, "stolen_qty" integer, "reserved_qty" integer, "total_qty" integer, "is_own_tenant" boolean, "is_pickable" boolean, "sort_rank" integer, "product_group_key" "text", "available_atp" numeric, "location_id" bigint, "location_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_is_parent_context boolean;
  v_avail public.stock_availability;
begin
  if p_context_tenant_id is null then
    raise exception 'context tenant is required';
  end if;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_context_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_context_tenant_id);
  v_is_parent_context := (p_context_tenant_id = v_parent_id);

  v_avail := case lower(coalesce(nullif(trim(p_status), ''), 'excellent'))
    when 'excellent' then 'sellable'::public.stock_availability
    when 'sellable' then 'sellable'::public.stock_availability
    when 'held' then 'held'::public.stock_availability
    when 'hold' then 'held'::public.stock_availability
    when 'reserved' then 'held'::public.stock_availability
    when 'unsellable' then 'unsellable'::public.stock_availability
    when 'damaged' then 'unsellable'::public.stock_availability
    when 'box_damage' then 'unsellable'::public.stock_availability
    when 'box_less' then 'unsellable'::public.stock_availability
    when 'expired' then 'unsellable'::public.stock_availability
    when 'stolen' then 'unsellable'::public.stock_availability
    else null
  end;

  return query
  select
    gs.id as global_stock_id,
    gsi.product_id,
    gsi.name,
    gsi.barcode,
    gsi.product_code,
    gsi.image_url,
    gsi.id as shipment_item_id,
    gsi.ordered_quantity,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    sh.type::text as shipment_type,
    1.0::numeric as product_conversion_rate,
    1.0::numeric as cargo_conversion_rate,
    0::numeric as cargo_rate,
    sh.received_weight,
    1.0::numeric as transaction_rate,
    gsi.shipment_id,
    sh.name as shipment_name,
    gs.parent_tenant_id,
    coalesce(sh.assigned_child_tenant_id, v_parent_id) as holding_tenant_id,
    coalesce(ht.name, pt.name) as holding_tenant_name,
    gs.quantity as allocated_qty,
    gs.quantity as global_qty,
    case when gs.availability = 'sellable' then gs.quantity else 0 end as excellent_qty,
    0 as box_less_qty,
    case when gs.availability = 'unsellable' then gs.quantity else 0 end as box_damage_qty,
    0 as expired_qty,
    0 as stolen_qty,
    case when gs.availability = 'held' then gs.quantity else 0 end as reserved_qty,
    gs.quantity as total_qty,
    (coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_context_tenant_id) as is_own_tenant,
    (gs.availability = 'sellable' and (gs.location_id is null or sl.is_pickable = true)) as is_pickable,
    case
      when coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_context_tenant_id then 0
      else 1
    end as sort_rank,
    coalesce(gsi.product_id::text, 'stock:' || gs.id::text) as product_group_key,
    public.global_stock_atp_qty(gs.id) as available_atp,
    gs.location_id,
    sl.name as location_name
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments sh on sh.id = gsi.shipment_id
  inner join public.tenants pt on pt.id = v_parent_id
  left join public.tenants ht on ht.id = coalesce(sh.assigned_child_tenant_id, v_parent_id)
  left join public.stock_locations sl on sl.id = gs.location_id
  where gs.parent_tenant_id = v_parent_id
    and (
      v_is_parent_context
      or sh.assigned_child_tenant_id is null
      or sh.assigned_child_tenant_id = p_context_tenant_id
    )
    and sh.status = 'received'
    and (p_shipment_id is null or sh.id = p_shipment_id)
    and (p_product_id is null or gsi.product_id = p_product_id)
    and (v_avail is null or gs.availability = v_avail)
    and (not coalesce(p_exclude_zero_qty, true) or gs.quantity > 0)
    and (
      p_search is null
      or trim(p_search) = ''
      or case coalesce(nullif(lower(trim(p_search_field)), ''), 'all')
        when 'name' then (
          select coalesce(bool_and(gsi.name ilike '%' || trim(word) || '%'), true)
          from unnest(string_to_array(trim(p_search), ' ')) as word
          where trim(word) <> ''
        )
        when 'barcode' then coalesce(gsi.barcode, '') ilike '%' || trim(p_search) || '%'
        when 'product_code' then coalesce(gsi.product_code, '') ilike '%' || trim(p_search) || '%'
        else (
          select coalesce(bool_and(
            gsi.name ilike '%' || trim(word) || '%'
            or coalesce(gsi.barcode, '') ilike '%' || trim(p_search) || '%'
            or coalesce(gsi.product_code, '') ilike '%' || trim(p_search) || '%'
          ), true)
          from unnest(string_to_array(trim(p_search), ' ')) as word
          where trim(word) <> ''
        )
      end
    )
  order by
    coalesce(gsi.product_id::text, 'stock:' || gs.id::text) asc,
    case
      when coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_context_tenant_id then 0
      else 1
    end asc,
    gs.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."search_stock_network"("p_context_tenant_id" bigint, "p_mode" "text", "p_search" "text", "p_search_field" "text", "p_product_id" bigint, "p_status" "text", "p_shipment_id" bigint, "p_exclude_zero_qty" boolean, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_default_shipment_progress_flow"("p_flow_id" bigint) RETURNS "public"."shipment_progress_flows"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_flow public.shipment_progress_flows;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  update public.shipment_progress_flows
  set is_default = false
  where tenant_id = v_flow.tenant_id;

  update public.shipment_progress_flows
  set is_default = true, is_active = true
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$$;


ALTER FUNCTION "public"."set_default_shipment_progress_flow"("p_flow_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_default_stock_location"("p_id" bigint) RETURNS "public"."stock_locations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.stock_locations%rowtype;
begin
  select * into v_row
  from public.stock_locations
  where id = p_id
  for update;

  if not found then
    raise exception 'location not found';
  end if;

  perform public._assert_parent_warehouse_tenant(v_row.parent_tenant_id);

  if not (
    public.user_can_manage_parent_tenant(v_row.parent_tenant_id)
    or public.membership_has_module_action(v_row.parent_tenant_id, 'global_stock_location', 'edit')
  ) then
    raise exception 'not allowed';
  end if;

  if not v_row.is_active then
    raise exception 'cannot set inactive location as default';
  end if;

  if not public._stock_location_is_leaf(v_row.id) then
    raise exception 'only leaf locations can be the default put-away';
  end if;

  update public.stock_locations
  set is_default = false
  where parent_tenant_id = v_row.parent_tenant_id
    and is_default = true
    and id <> p_id;

  update public.stock_locations
  set is_default = true
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."set_default_stock_location"("p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_global_shipment_progress_tag"("p_shipment_id" bigint, "p_tag_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return public.set_shipment_progress_stage(p_shipment_id, p_tag_id);
end;
$$;


ALTER FUNCTION "public"."set_global_shipment_progress_tag"("p_shipment_id" bigint, "p_tag_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shipment_progress_flow"("p_shipment_id" bigint, "p_flow_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_flow public.shipment_progress_flows%rowtype;
  v_first_stage_tag_id bigint;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id;

  if not found then
    raise exception 'flow not found';
  end if;

  if v_flow.tenant_id <> v_ship.parent_tenant_id then
    raise exception 'flow tenant mismatch';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if v_ship.progress_tag_id is not null and not exists (
    select 1
    from public.shipment_progress_flow_stages s
    where s.flow_id = p_flow_id
      and s.tag_id = v_ship.progress_tag_id
  ) then
    select s.tag_id into v_first_stage_tag_id
    from public.shipment_progress_flow_stages s
    join public.tags t on t.id = s.tag_id
    where s.flow_id = p_flow_id
      and t.is_active = true
    order by s.sort_order asc
    limit 1;

    update public.global_shipments
    set
      progress_flow_id = p_flow_id,
      progress_tag_id = v_first_stage_tag_id,
      updated_at = now()
    where id = p_shipment_id;
  else
    update public.global_shipments
    set
      progress_flow_id = p_flow_id,
      updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'progress_flow_id', p_flow_id
  );
end;
$$;


ALTER FUNCTION "public"."set_shipment_progress_flow"("p_shipment_id" bigint, "p_flow_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_shipment_progress_stage"("p_shipment_id" bigint, "p_tag_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_tag public.tags%rowtype;
  v_progress jsonb := null;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.has_active_tenant_membership(v_ship.parent_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_tag_id is null then
    update public.global_shipments
    set progress_tag_id = null, updated_at = now()
    where id = p_shipment_id;

    return jsonb_build_object(
      'shipment_id', p_shipment_id,
      'progress_tag', null
    );
  end if;

  select * into v_tag from public.tags where id = p_tag_id;
  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag must be in group shipment_progress';
  end if;

  if not exists (
    select 1
    from public.shipment_progress_flow_stages s
    where s.flow_id = v_ship.progress_flow_id
      and s.tag_id = p_tag_id
  ) then
    raise exception 'tag does not belong to shipment flow';
  end if;

  update public.global_shipments
  set progress_tag_id = p_tag_id, updated_at = now()
  where id = p_shipment_id;

  v_progress := jsonb_build_object(
    'id', v_tag.id,
    'name', v_tag.name,
    'slug', v_tag.slug,
    'group_name', v_tag.group_name,
    'sort_order', v_tag.sort_order,
    'color', v_tag.color
  );

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'progress_tag', v_progress
  );
end;
$$;


ALTER FUNCTION "public"."set_shipment_progress_stage"("p_shipment_id" bigint, "p_tag_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."settle_shipment_payee"("p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_action" "text", "p_amount" numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_rate NUMERIC(12,6);
  v_bdt_amount NUMERIC(18,4);
  v_ledger JSONB;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'Amount must be greater than zero.';
  END IF;

  IF p_entity_type NOT IN ('vendor', 'cargo_company') THEN
    RAISE EXCEPTION 'Entity type must be vendor or cargo_company.';
  END IF;

  IF p_action NOT IN ('pay', 'record_credit', 'use_credit') THEN
    RAISE EXCEPTION 'Action must be pay, record_credit, or use_credit.';
  END IF;

  -- Lock shipment row
  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF v_ship.status IS DISTINCT FROM 'received' THEN
    RAISE EXCEPTION 'shipment must be received before settlement';
  END IF;

  IF NOT public.has_active_tenant_membership(v_ship.parent_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  -- Payee header validation
  IF p_entity_type = 'vendor' THEN
    IF v_ship.vendor_id IS NULL OR v_ship.vendor_id <> p_entity_id THEN
      RAISE EXCEPTION 'vendor_id does not match shipment header';
    END IF;
  ELSIF p_entity_type = 'cargo_company' THEN
    IF v_ship.cargo_company_id IS NULL OR v_ship.cargo_company_id <> p_entity_id THEN
      RAISE EXCEPTION 'cargo_company_id does not match shipment header';
    END IF;
  END IF;

  -- Determine exchange rate
  IF p_exchange_rate IS NOT NULL AND p_exchange_rate > 0 THEN
    v_rate := p_exchange_rate;
  ELSE
    IF p_entity_type = 'vendor' THEN
      SELECT COALESCE(exchange_rate, 1.000000) INTO v_rate
      FROM public.global_shipment_cost_entries
      WHERE shipment_id = p_shipment_id
        AND cost_category = 'product'
      ORDER BY id ASC
      LIMIT 1;
    ELSIF p_entity_type = 'cargo_company' THEN
      SELECT COALESCE(exchange_rate, 1.000000) INTO v_rate
      FROM public.global_shipment_cost_entries
      WHERE shipment_id = p_shipment_id
        AND cost_category = 'cargo'
      ORDER BY id ASC
      LIMIT 1;
    END IF;
  END IF;

  v_rate := COALESCE(v_rate, 1.000000);
  IF v_rate <= 0 THEN
    v_rate := 1.000000;
  END IF;

  v_bdt_amount := ROUND(p_amount * v_rate, 4);

  IF p_action = 'pay' THEN
    -- Action: pay — debit tenant available (overdraft allowed). Payee available untouched.
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_ship.parent_tenant_id,
      p_type => 'debit',
      p_amount => v_bdt_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shipment',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object(
        'action', 'pay',
        'payee_type', p_entity_type,
        'payee_id', p_entity_id,
        'amount_input', p_amount,
        'exchange_rate', v_rate
      ),
      p_target_bucket => 'available',
      p_allow_overdraft => true
    );
  ELSIF p_action = 'record_credit' THEN
    -- Action: record_credit — credit payee available. Tenant unchanged.
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => p_entity_type,
      p_entity_id => p_entity_id,
      p_type => 'credit',
      p_amount => v_bdt_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shipment',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object(
        'action', 'record_credit',
        'payee_type', p_entity_type,
        'payee_id', p_entity_id,
        'amount_input', p_amount,
        'exchange_rate', v_rate
      ),
      p_target_bucket => 'available',
      p_allow_overdraft => false
    );
  ELSIF p_action = 'use_credit' THEN
    -- Action: use_credit — debit payee available (strict check). Tenant unchanged.
    v_ledger := public.record_ledger_transaction(
      p_parent_tenant_id => v_ship.parent_tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.parent_tenant_id),
      p_entity_type => p_entity_type,
      p_entity_id => p_entity_id,
      p_type => 'debit',
      p_amount => v_bdt_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shipment',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object(
        'action', 'use_credit',
        'payee_type', p_entity_type,
        'payee_id', p_entity_id,
        'amount_input', p_amount,
        'exchange_rate', v_rate
      ),
      p_target_bucket => 'available',
      p_allow_overdraft => false
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'action', p_action,
    'amount_bdt', v_bdt_amount,
    'ledger', v_ledger
  );
END;
$$;


ALTER FUNCTION "public"."settle_shipment_payee"("p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_action" "text", "p_amount" numeric, "p_exchange_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stamp_global_shipment_landed_costs"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_product_amount numeric := 0;
  v_cargo_amount numeric := 0;
  v_goods_bdt numeric := 0;
  v_cargo_bdt numeric := 0;
  v_blended numeric := 1;
  v_pack_kg numeric := 0;
  v_updated integer := 0;
  r record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_base numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  select
    coalesce(sum(amount) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount) filter (where cost_type != 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type != 'product'), 0)
  into v_product_amount, v_goods_bdt, v_cargo_amount, v_cargo_bdt
  from public.global_shipment_cost_entries
  where shipment_id = p_shipment_id;

  if (v_product_amount + v_cargo_amount) > 0 then
    v_blended := (v_goods_bdt + v_cargo_bdt) / (v_product_amount + v_cargo_amount);
  else
    v_blended := 1;
  end if;

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  perform set_config('app.allow_landed_cost_stamp', '1', true);

  for r in
    select *
    from public.global_shipment_items
    where shipment_id = p_shipment_id
  loop
    v_line_gross := (
      (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) * r.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_amount;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_amount;
    else
      v_line_cargo_share := 0;
    end if;

    if r.ordered_quantity > 0 then
      v_unit_base := coalesce(r.purchase_price, 0) + (v_line_cargo_share / r.ordered_quantity);
    else
      v_unit_base := coalesce(r.purchase_price, 0);
    end if;

    if v_ship.type::text in ('local', 'domestic') then
      v_landed := v_unit_base;
    else
      v_landed := v_unit_base * v_blended;
    end if;

    update public.global_shipment_items
    set landed_cost_bdt = round(v_landed::numeric, 4)
    where id = r.id;

    v_updated := v_updated + 1;
  end loop;

  return v_updated;
end;
$$;


ALTER FUNCTION "public"."stamp_global_shipment_landed_costs"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."stock_grade_tag_id_for_slug"("p_slug" "text") RETURNS bigint
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_id bigint;
begin
  select tg.id into v_id
  from public.tags tg
  inner join public.tag_categories tc on tc.id = tg.category_id
  where tc.module_key = 'stock_grade'
    and tc.code = 'warehouse'
    and tg.slug = p_slug
    and tg.is_active = true
  order by tg.id
  limit 1;

  if v_id is null then
    return public.default_stock_grade_tag_id();
  end if;
  return v_id;
end;
$$;


ALTER FUNCTION "public"."stock_grade_tag_id_for_slug"("p_slug" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_global_shipment_header_aliases"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'INSERT' then
    if new.total_weight_kg is null and new.received_weight is not null then
      new.total_weight_kg := new.received_weight;
    elsif new.received_weight is null and new.total_weight_kg is not null then
      new.received_weight := new.total_weight_kg;
    elsif new.total_weight_kg is distinct from new.received_weight then
      -- Prefer plan name when both provided
      if new.total_weight_kg is not null then
        new.received_weight := new.total_weight_kg;
      else
        new.total_weight_kg := new.received_weight;
      end if;
    end if;

    if new.inventory_added is null then
      new.inventory_added := coalesce(new.stock_ready, false);
    end if;
    new.stock_ready := new.inventory_added;
    return new;
  end if;

  -- UPDATE: whichever side changed wins
  if new.total_weight_kg is distinct from old.total_weight_kg then
    new.received_weight := new.total_weight_kg;
  elsif new.received_weight is distinct from old.received_weight then
    new.total_weight_kg := new.received_weight;
  end if;

  if new.inventory_added is distinct from old.inventory_added then
    new.stock_ready := new.inventory_added;
  elsif new.stock_ready is distinct from old.stock_ready then
    new.inventory_added := new.stock_ready;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."sync_global_shipment_header_aliases"() OWNER TO "postgres";




CREATE OR REPLACE FUNCTION "public"."sync_product_tenant_from_vendor"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_tenant_id bigint;
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.tenant_id, v.parent_tenant_id
    into v_tenant_id, v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    elsif v_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
    end if;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."sync_product_tenant_from_vendor"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_vendor_reference_fields"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_id bigint;
  v_code text;
begin
  if new.vendor_id is not null then
    select id, code
    into v_id, v_code
    from public.vendors
    where id = new.vendor_id
    limit 1;

    if v_id is null then
      raise exception 'invalid vendor_id: %', new.vendor_id;
    end if;

    new.vendor_id := v_id;
    new.vendor_code := v_code;
    return new;
  end if;

  if new.vendor_code is not null and length(trim(new.vendor_code)) > 0 then
    select id, code
    into v_id, v_code
    from public.vendors
    where upper(trim(code)) = upper(trim(new.vendor_code))
    order by id asc
    limit 1;

    if v_id is not null then
      new.vendor_id := v_id;
      new.vendor_code := v_code;
    else
      new.vendor_id := null;
      new.vendor_code := upper(trim(new.vendor_code));
    end if;

    return new;
  end if;

  new.vendor_id := null;
  new.vendor_code := null;
  return new;
end;
$$;


ALTER FUNCTION "public"."sync_vendor_reference_fields"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_auto_upsert_pbc_backlog"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_tenant_id bigint;
  v_other_id bigint;
  v_open_qty numeric;
  v_prod RECORD;
  v_price_gbp numeric;
  v_name text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.product_id IS NOT NULL AND OLD.product_based_costing_file_id IS NOT NULL THEN
      SELECT * INTO v_file
      FROM public.product_based_costing_files
      WHERE id = OLD.product_based_costing_file_id;

      IF v_file.id IS NOT NULL THEN
        v_tenant_id := v_file.tenant_id;
        IF v_tenant_id IS NULL AND v_file.billing_profile_id IS NOT NULL THEN
          SELECT tenant_id INTO v_tenant_id
          FROM public.billing_profiles
          WHERE id = v_file.billing_profile_id;
        END IF;

        SELECT pci.id INTO v_other_id
        FROM public.product_based_costing_items pci
        INNER JOIN public.product_based_costing_files pcf
          ON pcf.id = pci.product_based_costing_file_id
        WHERE pci.product_id = OLD.product_id
          AND pcf.billing_profile_id IS NOT DISTINCT FROM v_file.billing_profile_id
        ORDER BY pci.updated_at DESC NULLS LAST, pci.id DESC
        LIMIT 1;

        IF v_other_id IS NOT NULL THEN
          PERFORM public.upsert_pbc_backlog_from_item(v_other_id);
        ELSIF v_tenant_id IS NOT NULL AND v_file.billing_profile_id IS NOT NULL THEN
          v_open_qty := coalesce(OLD.confirmed_quantity, OLD.quantity, 0);

          IF coalesce(v_file.status, 'pending') IN ('pending', 'offered')
             AND v_open_qty > 0
          THEN
            SELECT
              p.name,
              p.image_url,
              p.list_price_amount,
              p.product_weight,
              p.package_weight,
              p.barcode,
              p.product_code,
              gc.code AS list_price_currency_code
            INTO v_prod
            FROM public.products p
            LEFT JOIN public.global_currencies gc ON gc.id = p.list_price_currency_id
            WHERE p.id = OLD.product_id;

            v_name := coalesce(OLD.name, v_prod.name);
            v_price_gbp := coalesce(
              OLD.price_gbp,
              CASE
                WHEN v_prod.list_price_currency_code IS NULL OR v_prod.list_price_currency_code = 'GBP'
                  THEN v_prod.list_price_amount
                ELSE NULL
              END
            );

            IF v_name IS NOT NULL THEN
              INSERT INTO public.product_based_costing_backlog_items (
                tenant_id,
                billing_profile_id,
                product_id,
                open_quantity,
                name,
                image_url,
                barcode,
                product_code,
                price_gbp,
                product_weight,
                package_weight,
                last_costing_file_id,
                last_costing_item_id,
                updated_at
              )
              VALUES (
                v_tenant_id,
                v_file.billing_profile_id,
                OLD.product_id,
                round(v_open_qty)::integer,
                v_name,
                coalesce(OLD.image_url, v_prod.image_url),
                coalesce(OLD.barcode, v_prod.barcode),
                coalesce(OLD.product_code, v_prod.product_code),
                v_price_gbp,
                coalesce(OLD.product_weight::numeric, v_prod.product_weight),
                coalesce(OLD.package_weight::numeric, v_prod.package_weight),
                v_file.id,
                NULL,
                now()
              )
              ON CONFLICT (tenant_id, billing_profile_id, product_id)
              DO UPDATE SET
                open_quantity = EXCLUDED.open_quantity,
                name = EXCLUDED.name,
                image_url = EXCLUDED.image_url,
                barcode = EXCLUDED.barcode,
                product_code = EXCLUDED.product_code,
                price_gbp = EXCLUDED.price_gbp,
                product_weight = EXCLUDED.product_weight,
                package_weight = EXCLUDED.package_weight,
                last_costing_file_id = EXCLUDED.last_costing_file_id,
                last_costing_item_id = EXCLUDED.last_costing_item_id,
                updated_at = now();
            END IF;
          ELSE
            DELETE FROM public.product_based_costing_backlog_items
            WHERE tenant_id = v_tenant_id
              AND billing_profile_id = v_file.billing_profile_id
              AND product_id = OLD.product_id;
          END IF;
        END IF;
      END IF;
    END IF;

    RETURN OLD;
  END IF;

  PERFORM public.upsert_pbc_backlog_from_item(NEW.id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_fn_auto_upsert_pbc_backlog"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_pbc_files_auto_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NEW.tenant_id IS NULL AND NEW.billing_profile_id IS NOT NULL THEN
    SELECT tenant_id INTO NEW.tenant_id
    FROM public.billing_profiles
    WHERE id = NEW.billing_profile_id;
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."trg_fn_pbc_files_auto_tenant_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_global_shipment_items_guard_landed_cost"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if tg_op = 'UPDATE'
     and new.landed_cost_bdt is distinct from old.landed_cost_bdt
     and coalesce(current_setting('app.allow_landed_cost_stamp', true), '') is distinct from '1'
  then
    raise exception 'landed_cost_bdt is stamp-only; use finalize/revise RPCs';
  end if;
  if tg_op = 'INSERT'
     and new.landed_cost_bdt is not null
     and coalesce(current_setting('app.allow_landed_cost_stamp', true), '') is distinct from '1'
  then
    raise exception 'landed_cost_bdt is stamp-only; use finalize/revise RPCs';
  end if;
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_global_shipment_items_guard_landed_cost"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_shipment_items_recalc_transaction_rate"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  if tg_op = 'DELETE' then
    perform public.recalculate_shipment_transaction_rate(old.shipment_id);
    return old;
  else
    perform public.recalculate_shipment_transaction_rate(new.shipment_id);
    return new;
  end if;
end;
$$;


ALTER FUNCTION "public"."trg_shipment_items_recalc_transaction_rate"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_shipments_recalc_transaction_rate"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.recalculate_shipment_transaction_rate(new.id);
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_shipments_recalc_transaction_rate"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_market" "text" DEFAULT NULL::"text", "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "name" "text", "cargo_rate_1kg" numeric, "cargo_rate_2kg" numeric, "conversion_rate" numeric, "admin_profit_rate" numeric, "status" "public"."costing_file_status", "market" "text", "customer_group_id" bigint, "tenant_id" bigint, "created_by_email" "text", "default_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_files cf
    set
      name = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_name), cf.name)
        else cf.name
      end,
      market = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
          or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
        then coalesce(trim(p_market), cf.market)
        else cf.market
      end,
      customer_group_id = case
        when public.can_admin_manage_costing_file(cf.tenant_id)
        then coalesce(p_customer_group_id, cf.customer_group_id)
        else cf.customer_group_id
      end
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (cf.status = 'draft' and public.can_customer_access_costing_file(cf.customer_group_id))
      )
    returning
      cf.id,
      cf.name,
      cf.cargo_rate_1kg,
      cf.cargo_rate_2kg,
      cf.conversion_rate,
      cf.admin_profit_rate,
      cf.status,
      cf.market,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.default_shipment_id,
      cf.created_at,
      cf.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file"("p_id" bigint, "p_name" "text", "p_market" "text", "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) RETURNS TABLE("id" bigint, "customer_profit_rate" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set customer_profit_rate = p_customer_profit_rate
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
    returning
      cfi.id,
      cfi.customer_profit_rate,
      cfi.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file_item_customer_profit"("p_id" bigint, "p_customer_profit_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_image_url" "text" DEFAULT NULL::"text", "p_product_weight" integer DEFAULT NULL::integer, "p_package_weight" integer DEFAULT NULL::integer, "p_price_in_web_gbp" numeric DEFAULT NULL::numeric, "p_delivery_price_gbp" numeric DEFAULT NULL::numeric) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "name" "text", "image_url" "text", "product_weight" integer, "package_weight" integer, "price_in_web_gbp" numeric, "delivery_price_gbp" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set
      name = coalesce(trim(p_name), cfi.name),
      image_url = coalesce(trim(p_image_url), cfi.image_url),
      product_weight = coalesce(p_product_weight, cfi.product_weight),
      package_weight = coalesce(p_package_weight, cfi.package_weight),
      price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
      delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
      )
    returning
      cfi.id,
      cfi.costing_file_id,
      cfi.name,
      cfi.image_url,
      cfi.product_weight,
      cfi.package_weight,
      cfi.price_in_web_gbp,
      cfi.delivery_price_gbp,
      cfi.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) RETURNS TABLE("id" bigint, "costing_file_id" bigint, "name" "text", "image_url" "text", "website_url" "text", "quantity" integer, "product_weight" integer, "package_weight" integer, "price_in_web_gbp" numeric, "delivery_price_gbp" numeric, "auxiliary_price_gbp" numeric, "item_price_gbp" numeric, "cargo_rate" numeric, "costing_price_gbp" numeric, "costing_price_bdt" integer, "offer_price_bdt" integer, "customer_profit_rate" numeric, "status" "public"."costing_file_item_status", "created_by_email" "text", "assigned_shipment_id" bigint, "created_at" timestamp with time zone, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return query
    with updated as (
      update public.costing_file_items cfi
      set
        name = coalesce(trim(p_name), cfi.name),
        item_type = coalesce(trim(p_item_type), cfi.item_type),
        image_url = coalesce(trim(p_image_url), cfi.image_url),
        product_weight = coalesce(p_product_weight, cfi.product_weight),
        package_weight = coalesce(p_package_weight, cfi.package_weight),
        price_in_web_gbp = coalesce(p_price_in_web_gbp, cfi.price_in_web_gbp),
        delivery_price_gbp = coalesce(p_delivery_price_gbp, cfi.delivery_price_gbp)
      where cfi.id = p_id
        and public.can_admin_manage_costing_file((select cf.tenant_id from public.costing_files cf where cf.id = cfi.costing_file_id))
      returning
        cfi.id,
        cfi.costing_file_id,
        cfi.name,
        cfi.image_url,
        cfi.website_url,
        cfi.quantity,
        cfi.product_weight,
        cfi.package_weight,
        cfi.price_in_web_gbp,
        cfi.delivery_price_gbp,
        cfi.auxiliary_price_gbp,
        cfi.item_price_gbp,
        cfi.cargo_rate,
        cfi.costing_price_gbp,
        cfi.costing_price_bdt,
        cfi.offer_price_bdt,
        cfi.customer_profit_rate,
        cfi.status,
        cfi.created_by_email,
        cfi.assigned_shipment_id,
        cfi.created_at,
        cfi.updated_at
    )
    select *
    from updated;
end;
$$;


ALTER FUNCTION "public"."update_costing_file_item_enrichment"("p_id" bigint, "p_name" "text", "p_item_type" "text", "p_image_url" "text", "p_product_weight" integer, "p_package_weight" integer, "p_price_in_web_gbp" numeric, "p_delivery_price_gbp" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric DEFAULT NULL::numeric, "p_item_price_gbp" numeric DEFAULT NULL::numeric, "p_cargo_rate" numeric DEFAULT NULL::numeric, "p_costing_price_gbp" numeric DEFAULT NULL::numeric, "p_costing_price_bdt" integer DEFAULT NULL::integer, "p_offer_price_override_bdt" integer DEFAULT NULL::integer) RETURNS TABLE("id" bigint, "auxiliary_price_gbp" numeric, "item_price_gbp" numeric, "cargo_rate" numeric, "costing_price_gbp" numeric, "costing_price_bdt" integer, "offer_price_override_bdt" integer, "offer_price_bdt" integer, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set
      auxiliary_price_gbp = coalesce(p_auxiliary_price_gbp, cfi.auxiliary_price_gbp),
      item_price_gbp = coalesce(p_item_price_gbp, cfi.item_price_gbp),
      cargo_rate = coalesce(p_cargo_rate, cfi.cargo_rate),
      costing_price_gbp = coalesce(p_costing_price_gbp, cfi.costing_price_gbp),
      costing_price_bdt = coalesce(p_costing_price_bdt, cfi.costing_price_bdt),
      offer_price_override_bdt = p_offer_price_override_bdt
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cfi.id,
      cfi.auxiliary_price_gbp,
      cfi.item_price_gbp,
      cfi.cargo_rate,
      cfi.costing_price_gbp,
      cfi.costing_price_bdt,
      cfi.offer_price_override_bdt,
      cfi.offer_price_bdt,
      cfi.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file_item_offer"("p_id" bigint, "p_auxiliary_price_gbp" numeric, "p_item_price_gbp" numeric, "p_cargo_rate" numeric, "p_costing_price_gbp" numeric, "p_costing_price_bdt" integer, "p_offer_price_override_bdt" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") RETURNS TABLE("id" bigint, "status" "public"."costing_file_item_status", "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set status = p_status
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          cf.status = 'offered'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
    returning
      cfi.id,
      cfi.status,
      cfi.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file_item_status"("p_id" bigint, "p_status" "public"."costing_file_item_status") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) RETURNS TABLE("id" bigint, "customer_profit_rate" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_file_items cfi
    set customer_profit_rate = p_customer_profit_rate
    from public.costing_files cf
    where cf.id = cfi.costing_file_id
      and cfi.costing_file_id = p_costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
    returning
      cfi.id,
      cfi.customer_profit_rate,
      cfi.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file_items_customer_profit"("p_costing_file_id" bigint, "p_customer_profit_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric DEFAULT NULL::numeric, "p_cargo_rate_2kg" numeric DEFAULT NULL::numeric, "p_conversion_rate" numeric DEFAULT NULL::numeric, "p_admin_profit_rate" numeric DEFAULT NULL::numeric) RETURNS TABLE("id" bigint, "cargo_rate_1kg" numeric, "cargo_rate_2kg" numeric, "conversion_rate" numeric, "admin_profit_rate" numeric, "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_files cf
    set
      cargo_rate_1kg = coalesce(p_cargo_rate_1kg, cf.cargo_rate_1kg),
      cargo_rate_2kg = coalesce(p_cargo_rate_2kg, cf.cargo_rate_2kg),
      conversion_rate = coalesce(p_conversion_rate, cf.conversion_rate),
      admin_profit_rate = coalesce(p_admin_profit_rate, cf.admin_profit_rate)
    where cf.id = p_id
      and public.can_admin_manage_costing_file(cf.tenant_id)
    returning
      cf.id,
      cf.cargo_rate_1kg,
      cf.cargo_rate_2kg,
      cf.conversion_rate,
      cf.admin_profit_rate,
      cf.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file_pricing"("p_id" bigint, "p_cargo_rate_1kg" numeric, "p_cargo_rate_2kg" numeric, "p_conversion_rate" numeric, "p_admin_profit_rate" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") RETURNS TABLE("id" bigint, "status" "public"."costing_file_status", "updated_at" timestamp with time zone)
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  with updated as (
    update public.costing_files cf
    set status = p_status
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          public.can_staff_access_costing_file(cf.tenant_id)
          and cf.status = 'customer_submitted'
          and p_status = 'in_review'
        )
        or (
          public.can_customer_access_costing_file(cf.customer_group_id)
          and (
            (cf.status = 'draft' and p_status = 'customer_submitted')
            or (cf.status = 'offered' and p_status = 'accepted')
          )
        )
      )
    returning
      cf.id,
      cf.status,
      cf.updated_at
  )
  select *
  from updated;
$$;


ALTER FUNCTION "public"."update_costing_file_status"("p_id" bigint, "p_status" "public"."costing_file_status") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_global_shipment_items_order"("p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql"
    AS $$
declare
  item_row record;
begin
  for item_row in select * from jsonb_to_recordset(p_items) as x(id bigint, sort_order int) loop
    update public.global_shipment_items
    set sort_order = item_row.sort_order
    where id = item_row.id;
  end loop;
end;
$$;


ALTER FUNCTION "public"."update_global_shipment_items_order"("p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_product_based_costing_items_order"("p_items" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  item_row record;
begin
  for item_row in select * from jsonb_to_recordset(p_items) as x(id bigint, sort_order int) loop
    update public.product_based_costing_items
    set sort_order = item_row.sort_order
    where id = item_row.id;
  end loop;
end;
$$;


ALTER FUNCTION "public"."update_product_based_costing_items_order"("p_items" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shipment"("p_id" bigint, "p_field" "text", "p_value" "text") RETURNS "public"."shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.shipments;
  v_field text;
  v_value text;
  v_type text;
begin
  select *
  into v_row
  from public.shipments
  where id = p_id;

  if v_row.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_row.tenant_id) then
    raise exception 'not allowed';
  end if;

  v_field := lower(trim(coalesce(p_field, '')));
  v_value := trim(coalesce(p_value, ''));

  if v_field = 'name' then
    update public.shipments set name = v_value where id = p_id returning * into v_row;
  elsif v_field = 'shipment_type' then
    v_type := lower(v_value);
    if v_type not in ('local', 'international') then
      raise exception 'invalid shipment_type: %', v_value;
    end if;
    update public.shipments set shipment_type = v_type where id = p_id returning * into v_row;
  elsif v_field = 'status' then
    update public.shipments set status = v_value where id = p_id returning * into v_row;
  elsif v_field = 'inventory_added' then
    update public.shipments
    set inventory_added = coalesce(nullif(v_value, '')::boolean, false)
    where id = p_id returning * into v_row;
  elsif v_field = 'product_conversion_rate' then
    update public.shipments
    set product_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'cargo_conversion_rate' then
    update public.shipments
    set cargo_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'cargo_rate' then
    update public.shipments
    set cargo_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'weight' then
    update public.shipments
    set weight = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'received_weight' then
    update public.shipments
    set received_weight = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'transaction_rate' then
    update public.shipments
    set transaction_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  else
    raise exception 'unsupported shipment field: %', p_field;
  end if;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."update_shipment"("p_id" bigint, "p_field" "text", "p_value" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shipment_investment_cost_share"("p_shipment_investment_id" bigint, "p_cost_share_pct" numeric) RETURNS "public"."shipment_investments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.shipment_investments;
  v_total numeric(5,2);
begin
  select * into v_row from public.shipment_investments where id = p_shipment_investment_id;
  if v_row.id is null then raise exception 'investment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_row.tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_cost_share_pct < 0 or p_cost_share_pct > 100 then
    raise exception 'cost_share_pct must be between 0 and 100';
  end if;

  select coalesce(sum(cost_share_pct), 0) into v_total
  from public.shipment_investments
  where shipment_id = v_row.shipment_id
    and id <> p_shipment_investment_id
    and cost_share_pct is not null;

  if v_total + p_cost_share_pct > 100 then
    raise exception 'total cost_share_pct cannot exceed 100';
  end if;

  update public.shipment_investments
  set cost_share_pct = p_cost_share_pct
  where id = p_shipment_investment_id
  returning * into v_row;

  perform public.refresh_shipment_investor_profits(v_row.shipment_id);

  return v_row;
end;
$$;


ALTER FUNCTION "public"."update_shipment_investment_cost_share"("p_shipment_investment_id" bigint, "p_cost_share_pct" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shipment_progress_flow"("p_flow_id" bigint, "p_name" "text" DEFAULT NULL::"text") RETURNS "public"."shipment_progress_flows"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_flow public.shipment_progress_flows;
  v_slug text;
begin
  select * into v_flow
  from public.shipment_progress_flows
  where id = p_flow_id
  for update;

  if not found then
    raise exception 'flow not found';
  end if;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    return v_flow;
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  update public.shipment_progress_flows
  set
    name = trim(p_name),
    slug = v_slug
  where id = p_flow_id
  returning * into v_flow;

  return v_flow;
end;
$$;


ALTER FUNCTION "public"."update_shipment_progress_flow"("p_flow_id" bigint, "p_name" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shipment_progress_flow_stage"("p_flow_stage_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_color" "text" DEFAULT NULL::"text") RETURNS TABLE("flow_stage_id" bigint, "flow_id" bigint, "tag_id" bigint, "sort_order" integer, "name" "text", "slug" "text", "color" "text", "is_active" boolean)
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stage public.shipment_progress_flow_stages;
  v_flow public.shipment_progress_flows;
  v_tag public.tags;
  v_slug text;
begin
  select * into v_stage
  from public.shipment_progress_flow_stages
  where id = p_flow_stage_id
  for update;

  if not found then
    raise exception 'flow stage not found';
  end if;

  select * into v_flow
  from public.shipment_progress_flows
  where id = v_stage.flow_id;

  if not public.has_active_tenant_membership(v_flow.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  select * into v_tag
  from public.tags
  where id = v_stage.tag_id
  for update;

  if p_name is not null and trim(p_name) <> '' then
    v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));
  else
    v_slug := v_tag.slug;
  end if;

  update public.tags
  set
    name = coalesce(nullif(trim(p_name), ''), name),
    slug = v_slug,
    color = coalesce(p_color, color)
  where id = v_stage.tag_id
  returning * into v_tag;

  return query
  select
    v_stage.id,
    v_stage.flow_id,
    v_stage.tag_id,
    v_stage.sort_order,
    v_tag.name,
    v_tag.slug,
    v_tag.color,
    v_tag.is_active;
end;
$$;


ALTER FUNCTION "public"."update_shipment_progress_flow_stage"("p_flow_stage_id" bigint, "p_name" "text", "p_color" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_shipment_progress_tag"("p_tag_id" bigint, "p_name" "text" DEFAULT NULL::"text", "p_color" "text" DEFAULT NULL::"text", "p_sort_order" integer DEFAULT NULL::integer) RETURNS "public"."tags"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tag public.tags;
  v_result public.tags;
  v_new_slug text;
begin
  select * into v_tag
  from public.tags
  where id = p_tag_id
  for update;

  if not found then
    raise exception 'tag not found';
  end if;

  if v_tag.group_name is distinct from 'shipment_progress' then
    raise exception 'tag is not a shipment_progress tag';
  end if;

  if not public.has_active_tenant_membership(v_tag.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if v_tag.is_system then
    raise exception 'system tags cannot be updated via this RPC';
  end if;

  if p_name is not null and trim(p_name) <> '' then
    v_new_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));
    if exists (
      select 1 from public.tags t
      where t.tenant_id = v_tag.tenant_id
        and t.group_name = 'shipment_progress'
        and t.slug = v_new_slug
        and t.id <> p_tag_id
    ) then
      raise exception 'a progress tag with this name already exists';
    end if;
  else
    v_new_slug := v_tag.slug;
  end if;

  update public.tags
  set
    name       = coalesce(nullif(trim(p_name), ''), name),
    slug       = v_new_slug,
    color      = coalesce(p_color, color),
    sort_order = coalesce(p_sort_order, sort_order)
  where id = p_tag_id
  returning * into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."update_shipment_progress_tag"("p_tag_id" bigint, "p_name" "text", "p_color" "text", "p_sort_order" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_type" "public"."global_shipment_cost_type", "p_amount" numeric, "p_exchange_rate" numeric DEFAULT 1.0, "p_currency_id" bigint DEFAULT NULL::bigint, "p_payment_source" "text" DEFAULT NULL::"text", "p_entity_type" "text" DEFAULT NULL::"text", "p_entity_id" bigint DEFAULT NULL::bigint, "p_allocation" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_id" bigint DEFAULT NULL::bigint) RETURNS "public"."global_shipment_cost_entries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_row public.global_shipment_cost_entries%rowtype;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.stock_ready = true or v_ship.status = 'received' then
    raise exception 'shipment finalized; use revise_global_shipment_costs';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'amount must be >= 0';
  end if;

  if p_exchange_rate is null or p_exchange_rate <= 0 then
    raise exception 'exchange_rate must be > 0';
  end if;

  if p_id is not null then
    update public.global_shipment_cost_entries e
    set
      cost_type = p_cost_type,
      amount = p_amount,
      exchange_rate = p_exchange_rate,
      currency_id = p_currency_id,
      payment_source = p_payment_source,
      entity_type = p_entity_type,
      entity_id = p_entity_id,
      allocation = p_allocation,
      metadata = coalesce(p_metadata, '{}'::jsonb),
      updated_at = now()
    where e.id = p_id
      and e.shipment_id = p_shipment_id
    returning * into v_row;

    if not found then
      raise exception 'cost entry % not found on shipment %', p_id, p_shipment_id;
    end if;
  else
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_type,
      amount,
      currency_id,
      exchange_rate,
      payment_source,
      entity_type,
      entity_id,
      allocation,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      p_cost_type,
      p_amount,
      p_currency_id,
      p_exchange_rate,
      p_payment_source,
      p_entity_type,
      p_entity_id,
      p_allocation,
      coalesce(p_metadata, '{}'::jsonb)
    )
    returning * into v_row;
  end if;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_type" "public"."global_shipment_cost_type", "p_amount" numeric, "p_exchange_rate" numeric, "p_currency_id" bigint, "p_payment_source" "text", "p_entity_type" "text", "p_entity_id" bigint, "p_allocation" "text", "p_metadata" "jsonb", "p_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_global_stock_allocation"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return jsonb_build_object('status', 'retired');
end;
$$;


ALTER FUNCTION "public"."upsert_global_stock_allocation"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_pbc_backlog_from_item"("p_costing_item_id" bigint) RETURNS "public"."product_based_costing_backlog_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_item public.product_based_costing_items%ROWTYPE;
  v_file public.product_based_costing_files%ROWTYPE;
  v_prod RECORD;
  v_confirmed_qty numeric;
  v_open_qty numeric;
  v_backlog_row public.product_based_costing_backlog_items;
  v_tenant_id bigint;
  v_price_gbp numeric;
BEGIN
  SELECT * INTO v_item
  FROM public.product_based_costing_items
  WHERE id = p_costing_item_id;

  IF v_item.id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = v_item.product_based_costing_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', v_item.product_based_costing_file_id;
  END IF;

  v_tenant_id := v_file.tenant_id;
  IF v_tenant_id IS NULL AND v_file.billing_profile_id IS NOT NULL THEN
    SELECT tenant_id INTO v_tenant_id
    FROM public.billing_profiles
    WHERE id = v_file.billing_profile_id;
  END IF;

  IF v_tenant_id IS NOT NULL AND NOT (
    public.can_admin_manage_costing_file(v_tenant_id)
    OR public.can_staff_access_costing_file(v_tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_tenant_id;
  END IF;

  IF v_tenant_id IS NULL OR v_file.billing_profile_id IS NULL OR v_item.product_id IS NULL THEN
    RETURN NULL;
  END IF;

  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_open_qty := case
    when v_item.assigned_shipment_id is not null then 0
    when coalesce(v_file.status, 'pending') in ('pending', 'offered') then v_confirmed_qty
    else 0
  end;

  IF v_confirmed_qty <= 0 OR v_open_qty <= 0 THEN
    DELETE FROM public.product_based_costing_backlog_items
    WHERE tenant_id = v_tenant_id
      AND billing_profile_id = v_file.billing_profile_id
      AND product_id = v_item.product_id;
    RETURN NULL;
  END IF;

  SELECT
    p.name,
    p.image_url,
    p.list_price_amount,
    p.product_weight,
    p.package_weight,
    p.barcode,
    p.product_code,
    p.brand,
    gc.code AS list_price_currency_code
  INTO v_prod
  FROM public.products p
  LEFT JOIN public.global_currencies gc ON gc.id = p.list_price_currency_id
  WHERE p.id = v_item.product_id;

  v_price_gbp := coalesce(
    v_item.price_gbp,
    CASE
      WHEN v_prod.list_price_currency_code IS NULL OR v_prod.list_price_currency_code = 'GBP'
        THEN v_prod.list_price_amount
      ELSE NULL
    END
  );

  INSERT INTO public.product_based_costing_backlog_items (
    tenant_id,
    billing_profile_id,
    product_id,
    open_quantity,
    name,
    image_url,
    barcode,
    product_code,
    price_gbp,
    product_weight,
    package_weight,
    last_costing_file_id,
    last_costing_item_id,
    updated_at
  )
  VALUES (
    v_tenant_id,
    v_file.billing_profile_id,
    v_item.product_id,
    v_open_qty,
    coalesce(v_item.name, v_prod.name),
    coalesce(v_item.image_url, v_prod.image_url),
    coalesce(v_item.barcode, v_prod.barcode),
    coalesce(v_item.product_code, v_prod.product_code),
    v_price_gbp,
    coalesce(v_item.product_weight::numeric, v_prod.product_weight),
    coalesce(v_item.package_weight::numeric, v_prod.package_weight),
    v_file.id,
    v_item.id,
    now()
  )
  ON CONFLICT (tenant_id, billing_profile_id, product_id)
  DO UPDATE SET
    open_quantity = EXCLUDED.open_quantity,
    name = EXCLUDED.name,
    image_url = EXCLUDED.image_url,
    barcode = EXCLUDED.barcode,
    product_code = EXCLUDED.product_code,
    price_gbp = EXCLUDED.price_gbp,
    product_weight = EXCLUDED.product_weight,
    package_weight = EXCLUDED.package_weight,
    last_costing_file_id = EXCLUDED.last_costing_file_id,
    last_costing_item_id = EXCLUDED.last_costing_item_id,
    updated_at = now()
  RETURNING * INTO v_backlog_row;

  RETURN v_backlog_row;
END;
$$;


ALTER FUNCTION "public"."upsert_pbc_backlog_from_item"("p_costing_item_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_shipment_investment"("p_id" bigint, "p_tenant_id" bigint, "p_global_shipment_id" bigint, "p_investor_id" bigint, "p_cost_share_pct" numeric) RETURNS "public"."shipment_investments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total_cost_share numeric;
  v_row public.shipment_investments;
  v_action text;
begin
  v_action := case when p_id is null then 'create' else 'edit' end;
  if not public.membership_has_module_action(p_tenant_id, 'investor_shipment_share', v_action) then
    raise exception 'not allowed';
  end if;

  if p_cost_share_pct < 0 or p_cost_share_pct > 100 then
    raise exception 'cost share percentage must be between 0 and 100';
  end if;

  select coalesce(sum(cost_share_pct), 0) into v_total_cost_share
  from public.shipment_investments
  where global_shipment_id = p_global_shipment_id
    and status = 'active'
    and (p_id is null or id <> p_id);

  if v_total_cost_share + p_cost_share_pct > 100 then
    raise exception 'total cost share percentage cannot exceed 100%%';
  end if;

  if p_id is not null then
    update public.shipment_investments
    set
      cost_share_pct = p_cost_share_pct,
      updated_at = now()
    where id = p_id and tenant_id = p_tenant_id
    returning * into v_row;
  else
    insert into public.shipment_investments (
      tenant_id, global_shipment_id, investor_id, cost_share_pct, status
    ) values (
      p_tenant_id, p_global_shipment_id, p_investor_id, p_cost_share_pct, 'active'
    )
    returning * into v_row;
  end if;

  perform public.refresh_shipment_investor_profits(p_global_shipment_id);

  select * into v_row from public.shipment_investments where id = v_row.id;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."upsert_shipment_investment"("p_id" bigint, "p_tenant_id" bigint, "p_global_shipment_id" bigint, "p_investor_id" bigint, "p_cost_share_pct" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upsert_stock_location"("p_parent_tenant_id" bigint, "p_code" "text", "p_name" "text", "p_kind" "public"."stock_location_kind" DEFAULT 'box'::"public"."stock_location_kind", "p_is_pickable" boolean DEFAULT true, "p_sort_order" integer DEFAULT 0, "p_is_active" boolean DEFAULT true, "p_is_default" boolean DEFAULT false, "p_id" bigint DEFAULT NULL::bigint, "p_parent_location_id" bigint DEFAULT NULL::bigint) RETURNS "public"."stock_locations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_code text;
  v_name text;
  v_row public.stock_locations%rowtype;
  v_action text;
  v_is_leaf boolean;
  v_want_default boolean;
begin
  perform public._assert_parent_warehouse_tenant(p_parent_tenant_id);

  v_action := case when p_id is null then 'create' else 'edit' end;

  if not (
    public.user_can_manage_parent_tenant(p_parent_tenant_id)
    or public.membership_has_module_action(p_parent_tenant_id, 'global_stock_location', v_action)
  ) then
    raise exception 'not allowed';
  end if;

  v_code := upper(trim(coalesce(p_code, '')));
  v_name := trim(coalesce(p_name, ''));

  if length(v_code) = 0 then
    raise exception 'code is required';
  end if;
  if length(v_name) = 0 then
    raise exception 'name is required';
  end if;
  if p_kind is null then
    raise exception 'kind is required';
  end if;

  perform public._validate_stock_location_nesting(
    p_kind, p_parent_location_id, p_parent_tenant_id
  );

  if p_id is not null and p_parent_location_id = p_id then
    raise exception 'location cannot be its own parent';
  end if;

  v_want_default := coalesce(p_is_default, false) and coalesce(p_is_active, true);

  if p_id is null then
    if v_want_default then
      update public.stock_locations
      set is_default = false
      where parent_tenant_id = p_parent_tenant_id
        and is_default = true;
    end if;

    insert into public.stock_locations (
      parent_tenant_id,
      parent_location_id,
      code,
      name,
      kind,
      is_default,
      is_pickable,
      sort_order,
      is_active
    )
    values (
      p_parent_tenant_id,
      p_parent_location_id,
      v_code,
      v_name,
      p_kind,
      v_want_default,
      coalesce(p_is_pickable, true),
      coalesce(p_sort_order, 0),
      coalesce(p_is_active, true)
    )
    returning * into v_row;

    if p_parent_location_id is not null then
      update public.stock_locations
      set is_default = false
      where id = p_parent_location_id
        and is_default = true;
    end if;
  else
    update public.stock_locations
    set
      parent_location_id = p_parent_location_id,
      code = v_code,
      name = v_name,
      kind = p_kind,
      is_pickable = coalesce(p_is_pickable, is_pickable),
      sort_order = coalesce(p_sort_order, sort_order),
      is_active = coalesce(p_is_active, is_active)
    where id = p_id
      and parent_tenant_id = p_parent_tenant_id
    returning * into v_row;

    if not found then
      raise exception 'location not found';
    end if;

    v_is_leaf := public._stock_location_is_leaf(v_row.id);

    if v_want_default and not v_is_leaf then
      raise exception 'only leaf locations can be the default put-away';
    end if;

    if v_want_default then
      update public.stock_locations
      set is_default = false
      where parent_tenant_id = p_parent_tenant_id
        and is_default = true
        and id <> p_id;

      update public.stock_locations
      set is_default = true
      where id = p_id;
    elsif coalesce(p_is_default, false) = false and coalesce(p_is_active, true) = false then
      update public.stock_locations
      set is_default = false
      where id = p_id;
    elsif p_is_default is not null and p_is_default = false then
      update public.stock_locations
      set is_default = false
      where id = p_id;
    end if;

    if p_parent_location_id is not null then
      update public.stock_locations
      set is_default = false
      where id = p_parent_location_id
        and is_default = true;
    end if;
  end if;

  -- Optional: keep one leaf default if any leaves remain
  if not exists (
    select 1 from public.stock_locations l
    where l.parent_tenant_id = p_parent_tenant_id
      and l.is_default = true
      and l.is_active = true
      and public._stock_location_is_leaf(l.id)
  ) then
    update public.stock_locations
    set is_default = true
    where id = (
      select l.id from public.stock_locations l
      where l.parent_tenant_id = p_parent_tenant_id
        and l.is_active = true
        and public._stock_location_is_leaf(l.id)
      order by l.sort_order, l.id
      limit 1
    );
  end if;

  select * into v_row from public.stock_locations where id = v_row.id;
  return v_row;
end;
$$;


ALTER FUNCTION "public"."upsert_stock_location"("p_parent_tenant_id" bigint, "p_code" "text", "p_name" "text", "p_kind" "public"."stock_location_kind", "p_is_pickable" boolean, "p_sort_order" integer, "p_is_active" boolean, "p_is_default" boolean, "p_id" bigint, "p_parent_location_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."validate_costing_file_customer_group"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
declare
  v_group_tenant_id bigint;
begin
  select cg.tenant_id
  into v_group_tenant_id
  from public.customer_groups cg
  where cg.id = new.customer_group_id;

  if v_group_tenant_id is null then
    raise exception 'customer_group_id % does not exist', new.customer_group_id;
  end if;

  if v_group_tenant_id <> new.tenant_id then
    raise exception 'customer_group_id % does not belong to tenant_id %', new.customer_group_id, new.tenant_id;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."validate_costing_file_customer_group"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."calculate_landed_unit_cost"("p_shipment_item_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stamp numeric;
  v_shipment_id bigint;
  v_shipment_type public.global_shipment_type;

  v_purchase_price numeric;
  v_product_weight numeric;
  v_package_weight numeric;
  v_qty numeric;

  v_total_packaging_weight_kg numeric := 0;
  v_line_gross_weight_kg numeric;
  v_line_cargo_share numeric := 0;
  v_line_purchase_base numeric;
  v_effective_rate numeric := 1;
  v_landed_cost numeric;
  v_total_qty numeric;

  v_product_amount numeric := 0;
  v_cargo_amount numeric := 0;
  v_goods_bdt numeric := 0;
  v_cargo_bdt numeric := 0;
begin
  select
    shipment_id,
    purchase_price,
    product_weight,
    package_weight,
    ordered_quantity,
    landed_cost_bdt
  into
    v_shipment_id,
    v_purchase_price,
    v_product_weight,
    v_package_weight,
    v_qty,
    v_stamp
  from public.global_shipment_items
  where id = p_shipment_item_id;

  if v_shipment_id is null then
    return 0.00;
  end if;

  if v_stamp is not null then
    return round(v_stamp::numeric, 4);
  end if;

  select type
  into v_shipment_type
  from public.global_shipments
  where id = v_shipment_id;

  select
    coalesce(sum(amount) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount) filter (where cost_type != 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type != 'product'), 0)
  into v_product_amount, v_goods_bdt, v_cargo_amount, v_cargo_bdt
  from public.global_shipment_cost_entries
  where shipment_id = v_shipment_id;

  select coalesce(sum(((product_weight + package_weight) * ordered_quantity) / 1000.0), 0)
  into v_total_packaging_weight_kg
  from public.global_shipment_items
  where shipment_id = v_shipment_id;

  v_line_gross_weight_kg := ((coalesce(v_product_weight, 0) + coalesce(v_package_weight, 0)) * coalesce(v_qty, 0)) / 1000.0;

  if v_qty > 0 and v_cargo_amount > 0 then
    if v_total_packaging_weight_kg > 0 then
      v_line_cargo_share := ((v_line_gross_weight_kg / v_total_packaging_weight_kg) * v_cargo_amount) / v_qty;
    else
      select coalesce(sum(ordered_quantity), 0) into v_total_qty
      from public.global_shipment_items
      where shipment_id = v_shipment_id;
      if v_total_qty > 0 then
        v_line_cargo_share := ((v_qty / v_total_qty) * v_cargo_amount) / v_qty;
      end if;
    end if;
  end if;

  v_line_purchase_base := coalesce(v_purchase_price, 0) + coalesce(v_line_cargo_share, 0);

  if v_shipment_type::text in ('local', 'domestic') then
    return round(v_line_purchase_base::numeric, 4);
  end if;

  if (v_product_amount + v_cargo_amount) > 0 then
    v_effective_rate := (v_goods_bdt + v_cargo_bdt) / (v_product_amount + v_cargo_amount);
  else
    v_effective_rate := 1.0;
  end if;

  v_landed_cost := v_line_purchase_base * v_effective_rate;
  return round(v_landed_cost::numeric, 4);
end;
$$;


ALTER FUNCTION "public"."calculate_landed_unit_cost"("p_shipment_item_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."calculate_landed_unit_cost"("p_shipment_item_id" bigint) IS 'Unit cost: prefer global_shipment_items.landed_cost_bdt stamp; else legacy header-rate formula for drafts.';



CREATE OR REPLACE FUNCTION "public"."get_allocation_reconciliation"("p_stock_id" bigint) RETURNS TABLE("stock_id" bigint, "global_qty" integer, "allocated_qty" integer, "unallocated_qty" integer, "is_reconciled" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_global_qty integer;
  v_allocated_qty integer;
begin
  select quantity into v_global_qty
  from public.global_stocks
  where id = p_stock_id;

  select coalesce(sum(quantity), 0)::integer into v_allocated_qty
  from public.global_stock_allocations
  where stock_id = p_stock_id;

  return query
  select
    p_stock_id,
    coalesce(v_global_qty, 0),
    coalesce(v_allocated_qty, 0),
    greatest(coalesce(v_global_qty, 0) - coalesce(v_allocated_qty, 0), 0),
    coalesce(v_allocated_qty, 0) <= coalesce(v_global_qty, 0);
end;
$$;


ALTER FUNCTION "public"."get_allocation_reconciliation"("p_stock_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_child_allocation_summary"("p_stock_id" bigint) RETURNS TABLE("child_tenant_id" bigint, "child_tenant_name" "text", "allocation_id" bigint, "allocated_qty" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return query
  select
    t.id as child_tenant_id,
    t.name as child_tenant_name,
    coalesce(gsa.id, 0)::bigint as allocation_id,
    coalesce(gsa.quantity, 0)::integer as allocated_qty
  from public.tenants t
  left join public.global_stock_allocations gsa on gsa.child_tenant_id = t.id and gsa.stock_id = p_stock_id
  where t.parent_id = (select parent_tenant_id from public.global_stocks where id = p_stock_id)
  order by t.name asc;
end;
$$;


ALTER FUNCTION "public"."list_child_allocation_summary"("p_stock_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_child_procurement_lines"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0) RETURNS TABLE("source_type" "text", "source_id" bigint, "child_tenant_id" bigint, "child_tenant_name" "text", "name" "text", "product_id" bigint, "quantity" integer, "cost_bdt" numeric, "price_gbp" numeric, "image_url" "text", "barcode" "text", "product_code" "text", "reference_label" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT public.user_can_manage_parent_tenant(p_parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  RETURN QUERY
  (
    SELECT
      'costing_item'::text AS source_type,
      pci.id AS source_id,
      pcf.tenant_id AS child_tenant_id,
      t.name AS child_tenant_name,
      pci.name,
      pci.product_id,
      greatest(coalesce(pci.confirmed_quantity, pci.quantity::integer, 0), 0)::integer AS quantity,
      pci.offer_price AS cost_bdt,
      pci.price_gbp,
      pci.image_url,
      pci.barcode,
      pci.product_code,
      ('Costing #' || pcf.id::text || ' — ' || coalesce(pcf.name, 'Untitled')) AS reference_label
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files pcf ON pcf.id = pci.product_based_costing_file_id
    INNER JOIN public.tenants t ON t.id = pcf.tenant_id
    WHERE t.parent_id = p_parent_tenant_id
      AND (p_child_tenant_id IS NULL OR pcf.tenant_id = p_child_tenant_id)
      AND pcf.status = 'ready_for_shipment'
      AND pci.assigned_shipment_id IS NULL
      AND pci.product_id IS NOT NULL
      AND coalesce(pci.confirmed_quantity, pci.quantity::integer, 0) > 0
      AND (
        p_search IS NULL OR trim(p_search) = ''
        OR pci.name ILIKE '%' || trim(p_search) || '%'
        OR pcf.name ILIKE '%' || trim(p_search) || '%'
      )
  )
  UNION ALL
  (
    SELECT
      'shop_order_item'::text AS source_type,
      oi.id AS source_id,
      o.tenant_id AS child_tenant_id,
      t.name AS child_tenant_name,
      oi.name,
      oi.product_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer AS quantity,
      CASE WHEN gc.code = 'BDT' THEN oi.final_price_amount ELSE NULL::numeric END AS cost_bdt,
      CASE WHEN gc.code = 'GBP' THEN oi.final_price_amount ELSE NULL::numeric END AS price_gbp,
      oi.image_url,
      p.barcode,
      p.product_code,
      ('Shop Order #' || o.order_no || ' — ' || o.name) AS reference_label
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    INNER JOIN public.tenants t ON t.id = o.tenant_id
    LEFT JOIN public.products p ON p.id = oi.product_id
    LEFT JOIN public.global_currencies gc ON gc.id = oi.final_price_currency_id
    WHERE o.status = 'placed'
      AND oi.procurement_pulled = false
      AND o.shop_type_snapshot = 'vendor_catalog'
      AND t.parent_id = p_parent_tenant_id
      AND (p_child_tenant_id IS NULL OR o.tenant_id = p_child_tenant_id)
      AND (
        p_search IS NULL OR trim(p_search) = ''
        OR oi.name ILIKE '%' || trim(p_search) || '%'
        OR o.name ILIKE '%' || trim(p_search) || '%'
      )
  )
  ORDER BY child_tenant_name, source_type, source_id
  LIMIT greatest(coalesce(p_limit, 100), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;


ALTER FUNCTION "public"."list_child_procurement_lines"("p_parent_tenant_id" bigint, "p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_reactive_adjust_child_listing_cost"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_new_landed_cost numeric;
begin
  if new.purchase_price <> old.purchase_price or coalesce(new.landed_cost_bdt, -1) <> coalesce(old.landed_cost_bdt, -1) then
    v_new_landed_cost := coalesce(new.landed_cost_bdt, round(new.purchase_price, 2));

    update public.shop_product_listings spl
    set
      minimum_sell_price_amount = case
        when spl.is_price_locked is true then spl.minimum_sell_price_amount
        else v_new_landed_cost
      end,
      sell_price_amount = case
        when spl.is_price_locked is true then spl.sell_price_amount
        else greatest(spl.sell_price_amount, v_new_landed_cost)
      end,
      updated_at = now()
    from public.global_stocks gs
    where spl.global_stock_id = gs.id
      and gs.shipment_item_id = new.id;
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."trg_reactive_adjust_child_listing_cost"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_shipment_overview_details"("p_shipment_id" bigint) RETURNS jsonb
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
declare
  v_parent bigint;
  v_ship jsonb;
  v_sections jsonb;
  v_items jsonb;
  v_boxes jsonb;
  v_cost_entries jsonb;
  v_flow_stages jsonb;
  v_progress_flow_id bigint;
begin
  select parent_tenant_id, progress_flow_id, to_jsonb(s.*)
  into v_parent, v_progress_flow_id, v_ship
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_ship is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  -- Ensure cost entries from header are synced
  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  -- 1. Sections with vendor info
  select coalesce(
    jsonb_agg(
      to_jsonb(sec.*) || jsonb_build_object('vendor', to_jsonb(v.*))
      order by sec.sort_order asc, sec.id asc
    ),
    '[]'::jsonb
  )
  into v_sections
  from public.global_shipment_sections sec
  left join public.vendors v on v.id = sec.vendor_id
  where sec.shipment_id = p_shipment_id;

  -- 2. Items
  select coalesce(
    jsonb_agg(
      to_jsonb(i.*)
      order by coalesce(i.sort_order, 0) asc, i.id asc
    ),
    '[]'::jsonb
  )
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = p_shipment_id;

  -- 3. Boxes
  select coalesce(
    jsonb_agg(
      to_jsonb(b.*)
      order by b.box_number asc, b.id asc
    ),
    '[]'::jsonb
  )
  into v_boxes
  from public.global_shipment_boxes b
  where b.shipment_id = p_shipment_id;

  -- 4. Cost entries
  select coalesce(
    jsonb_agg(
      to_jsonb(ce.*)
      order by ce.cost_type asc, ce.id asc
    ),
    '[]'::jsonb
  )
  into v_cost_entries
  from public.global_shipment_cost_entries ce
  where ce.shipment_id = p_shipment_id;

  -- 5. Flow stages if flow assigned
  if v_progress_flow_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'flow_stage_id', st.id,
          'flow_id', st.flow_id,
          'tag_id', st.tag_id,
          'sort_order', st.sort_order,
          'name', coalesce(t.name, ''),
          'slug', coalesce(t.slug, ''),
          'color', t.color,
          'is_active', coalesce(st.is_active, true)
        )
        order by st.sort_order asc
      ),
      '[]'::jsonb
    )
    into v_flow_stages
    from public.shipment_progress_flow_stages st
    join public.tags t on t.id = st.tag_id
    where st.flow_id = v_progress_flow_id and st.is_active = true;
  else
    v_flow_stages := '[]'::jsonb;
  end if;

  return jsonb_build_object(
    'shipment', v_ship,
    'sections', v_sections,
    'items', v_items,
    'boxes', v_boxes,
    'cost_entries', v_cost_entries,
    'flow_stages', v_flow_stages
  );
end;
$$;


ALTER FUNCTION "public"."get_shipment_overview_details"("p_shipment_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."bulk_delete_global_shipment_items"(
  "p_shipment_id" bigint,
  "p_item_ids" bigint[]
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_parent bigint;
  v_deleted_count bigint;
  v_ref_count bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if p_item_ids is null or array_length(p_item_ids, 1) is null or array_length(p_item_ids, 1) = 0 then
    return 0;
  end if;

  -- 1. Check parent tenant & permissions
  select parent_tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  -- 2. Verify none of the items are referenced in warehouse stocks
  select count(*) into v_ref_count
  from public.global_stocks
  where shipment_item_id = any(p_item_ids);

  if v_ref_count > 0 then
    raise exception 'One or more selected items cannot be deleted because they are referenced in Warehouse Stock.';
  end if;

  -- 3. Delete items in bulk atomically
  with deleted as (
    delete from public.global_shipment_items
    where shipment_id = p_shipment_id
      and id = any(p_item_ids)
    returning id
  )
  select count(*) into v_deleted_count from deleted;

  return v_deleted_count;
end;
$$;


ALTER FUNCTION "public"."bulk_delete_global_shipment_items"("p_shipment_id" bigint, "p_item_ids" bigint[]) OWNER TO "postgres";




