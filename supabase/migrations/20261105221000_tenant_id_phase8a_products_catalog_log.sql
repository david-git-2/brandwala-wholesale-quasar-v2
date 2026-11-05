-- Phase 8a: rename parent_tenant_id -> tenant_id on products and catalog_refresh_log.

ALTER TABLE public.products RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.catalog_refresh_log RENAME COLUMN parent_tenant_id TO tenant_id;

ALTER INDEX IF EXISTS public.products_parent_tenant_id_idx RENAME TO products_tenant_id_idx;
ALTER INDEX IF EXISTS public.products_parent_tenant_name_id_idx RENAME TO products_tenant_name_id_idx;
ALTER TABLE public.products RENAME CONSTRAINT products_parent_tenant_id_fkey TO products_tenant_id_fkey;

DROP FUNCTION IF EXISTS public.list_catalog_refresh_log(bigint, integer);

-- add_child_line_to_parent_shipment

CREATE OR REPLACE FUNCTION "public"."add_child_line_to_parent_shipment"("p_parent_shipment_id" bigint, "p_source_type" "text", "p_source_id" bigint) RETURNS "public"."global_shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shipment public.global_shipments;
  v_row public.global_shipment_items;
  v_source_type text;
  v_child_tenant_id bigint;
  v_prod record;
  v_vendor_id bigint;
begin
  v_source_type := lower(trim(coalesce(p_source_type, '')));

  if v_source_type not in ('order_item', 'costing_item', 'shop_order_item') then
    raise exception 'invalid source_type: %', p_source_type;
  end if;

  select * into v_shipment
  from public.global_shipments
  where id = p_parent_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_source_type = 'order_item' then
    -- Legacy Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.parent_tenant_id = v_shipment.parent_tenant_id
      and oi.shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.order_items where id = p_source_id);

    insert into public.global_shipment_items (
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
    select
      p_parent_shipment_id,
      oi.product_id,
      oi.name,
      greatest(coalesce(oi.ordered_quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'order_item',
      oi.id
    from public.order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.order_items
    set shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'costing_item' then
    -- Costing Pull
    select pcf.tenant_id into v_child_tenant_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where pci.id = p_source_id
      and t.parent_id = v_shipment.parent_tenant_id
      and pci.assigned_shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'costing item not available for procurement';
    end if;

    select product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.product_based_costing_items where id = p_source_id);

    insert into public.global_shipment_items (
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
    select
      p_parent_shipment_id,
      pci.product_id,
      pci.name,
      greatest(coalesce(pci.quantity, 0), 0),
      pci.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(pci.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      pci.barcode,
      pci.product_code,
      v_child_tenant_id,
      'costing_item',
      pci.id
    from public.product_based_costing_items pci
    where pci.id = p_source_id
    returning * into v_row;

    update public.product_based_costing_items
    set assigned_shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'shop_order_item' then
    -- Shop Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    where oi.id = p_source_id
      and t.parent_id = v_shipment.parent_tenant_id
      and oi.procurement_pulled = false
      and o.status = 'placed';

    if v_child_tenant_id is null then
      raise exception 'shop order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.shop_order_items where id = p_source_id);

    -- Try to match vendor by vendor_code of the shop
    select v.id into v_vendor_id
    from public.shop_order_items oi
    join public.shop_orders o on o.id = oi.order_id
    join public.shops s on s.id = o.shop_id
    join public.vendors v on v.code = s.vendor_code and v.parent_tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
    where oi.id = p_source_id
    limit 1;

    insert into public.global_shipment_items (
      shipment_id,
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
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      v_vendor_id,
      oi.name,
      greatest(coalesce(oi.quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.final_price_amount, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'shop_order_item',
      oi.id
    from public.shop_order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.shop_order_items
    set procurement_pulled = true
    where id = p_source_id;

  end if;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."add_child_line_to_parent_shipment"("p_parent_shipment_id" bigint, "p_source_type" "text", "p_source_id" bigint) OWNER TO "postgres";

-- add_dropship_order_gift_item

CREATE OR REPLACE FUNCTION "public"."add_dropship_order_gift_item"("p_order_id" bigint, "p_product_id" bigint, "p_quantity" integer, "p_gift_source" "text", "p_gift_cost_amount" numeric DEFAULT 0, "p_gift_cost_charged_to" "text" DEFAULT NULL::"text", "p_gift_added_by" "text" DEFAULT 'manual'::"text", "p_shop_customer_stock_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders%rowtype;
  v_product public.products%rowtype;
  v_cust_stock public.shop_customer_stocks%rowtype;
  v_item_id bigint;
  v_cost numeric(12,4);
  v_charged_to text;
  v_item_name text;
  v_item_image text;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('success', false, 'error', 'quantity must be positive');
  end if;

  if p_gift_source not in ('stock', 'customer_stock') then
    return jsonb_build_object('success', false, 'error', 'invalid gift_source');
  end if;

  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    return jsonb_build_object('success', false, 'error', 'gifts can only be added while processing');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_cost := coalesce(p_gift_cost_amount, 0);
  v_charged_to := p_gift_cost_charged_to;

  if p_gift_source = 'customer_stock' then
    v_cost := 0;
    v_charged_to := null;

    if p_shop_customer_stock_id is not null then
      select * into v_cust_stock
      from public.shop_customer_stocks
      where id = p_shop_customer_stock_id
        and shop_id = v_order.shop_id
      for update;
    else
      if p_product_id is null then
        return jsonb_build_object('success', false, 'error', 'product_id or shop_customer_stock_id required');
      end if;

      select * into v_product from public.products where id = p_product_id;
      if v_product.id is null then
        return jsonb_build_object('success', false, 'error', 'product not found');
      end if;

      select * into v_cust_stock
      from public.shop_customer_stocks
      where shop_id = v_order.shop_id
        and customer_group_id = v_order.customer_group_id
        and product_id = p_product_id
      for update;
    end if;

    if v_cust_stock.id is null or v_cust_stock.quantity_on_hand < p_quantity then
      return jsonb_build_object('success', false, 'error', 'insufficient customer stock for this product');
    end if;

    if v_cust_stock.customer_group_id is distinct from v_order.customer_group_id then
      return jsonb_build_object('success', false, 'error', 'customer stock does not belong to this order reseller');
    end if;

    update public.shop_customer_stocks
    set quantity_on_hand = quantity_on_hand - p_quantity, updated_at = now()
    where id = v_cust_stock.id;

    if v_cust_stock.product_id is not null then
      select * into v_product from public.products where id = v_cust_stock.product_id;
      v_item_name := v_product.name;
      v_item_image := v_product.image_url;
    else
      v_item_name := coalesce(v_cust_stock.item_label, 'Gift item');
      v_item_image := null;
    end if;

    insert into public.shop_order_items (
      order_id, product_id, name, image_url, quantity,
      unit_sell_price_amount, final_price_amount, customer_sell_price_amount,
      is_gift, gift_source, gift_cost_amount, gift_cost_charged_to,
      shop_customer_stock_id, gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, v_cust_stock.product_id, v_item_name, v_item_image, p_quantity,
      0, 0, 0,
      true, 'customer_stock', 0, null,
      v_cust_stock.id, coalesce(p_gift_added_by, 'manual'), p_quantity
    )
    returning id into v_item_id;

  else
    select * into v_product from public.products where id = p_product_id;
    if v_product.id is null then
      return jsonb_build_object('success', false, 'error', 'product not found');
    end if;

    if v_cost > 0 and v_charged_to is null then
      return jsonb_build_object('success', false, 'error', 'gift_cost_charged_to required when cost > 0');
    end if;
    if v_cost <= 0 then
      v_charged_to := null;
    end if;
    if v_charged_to is not null and v_charged_to not in ('reseller', 'tenant') then
      return jsonb_build_object('success', false, 'error', 'invalid gift_cost_charged_to');
    end if;

    insert into public.shop_order_items (
      order_id, product_id, name, image_url, quantity,
      unit_sell_price_amount, final_price_amount, customer_sell_price_amount,
      is_gift, gift_source, gift_cost_amount, gift_cost_charged_to,
      shop_customer_stock_id, gift_added_by, confirmed_quantity
    )
    values (
      p_order_id, p_product_id, v_product.name, v_product.image_url, p_quantity,
      0, 0, 0,
      true, 'stock', v_cost, v_charged_to,
      null, coalesce(p_gift_added_by, 'manual'), 0
    )
    returning id into v_item_id;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true, 'order_item_id', v_item_id);
end;
$$;


ALTER FUNCTION "public"."add_dropship_order_gift_item"("p_order_id" bigint, "p_product_id" bigint, "p_quantity" integer, "p_gift_source" "text", "p_gift_cost_amount" numeric, "p_gift_cost_charged_to" "text", "p_gift_added_by" "text", "p_shop_customer_stock_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bill_lines" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "global_stock_id" bigint,
    "shipment_item_id" bigint,
    "product_id" bigint,
    "name_snapshot" "text" NOT NULL,
    "barcode_snapshot" "text",
    "product_code_snapshot" "text",
    "quantity" numeric(12,3) NOT NULL,
    "sell_price_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "line_discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "line_total_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "return_quantity" numeric(12,3) DEFAULT 0 NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "assigned_child_tenant_id" bigint,
    "line_meta" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "line_kind" "text" DEFAULT 'stock'::"text" NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "books_amount" numeric(12,2),
    CONSTRAINT "bill_lines_line_kind_check" CHECK (("line_kind" = ANY (ARRAY['stock'::"text", 'description'::"text", 'charge'::"text"]))),
    CONSTRAINT "global_invoice_items_line_discount_amount_check" CHECK (("line_discount_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_line_total_amount_check" CHECK (("line_total_amount" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "global_invoice_items_return_qty_check" CHECK (("return_quantity" <= "quantity")),
    CONSTRAINT "global_invoice_items_return_quantity_check" CHECK (("return_quantity" >= (0)::numeric)),
    CONSTRAINT "global_invoice_items_sell_price_amount_check" CHECK (("sell_price_amount" >= (0)::numeric))
);


ALTER TABLE "public"."bill_lines" OWNER TO "postgres";

-- add_shipment_item_from_product

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
    and p.tenant_id = v_parent;

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

-- add_to_shop_cart

CREATE OR REPLACE FUNCTION "public"."add_to_shop_cart"("p_shop_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint DEFAULT NULL::bigint, "p_quantity" integer DEFAULT 1, "p_customer_sell_price_amount" numeric DEFAULT NULL::numeric, "p_customer_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_global_stock_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cart_res jsonb;
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_buy_currency_id bigint;
  v_prod_name text;
  v_prod_image text;
  v_prod_vendor text;
  v_prod_is_available boolean;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_display_qty_override integer;
  v_landed_cost numeric;
  v_available_to_sell integer;
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  v_can_add_to_cart boolean;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
begin
  v_cart_res := public.get_or_create_shop_cart(p_shop_id);
  v_cart_id := (v_cart_res->'cart'->>'id')::bigint;

  select tenant_id, shop_type, pricing_method, markup_percentage, buy_currency_id
  into v_tenant_id, v_shop_type, v_pricing_method, v_markup_percentage, v_buy_currency_id
  from public.shops
  where id = p_shop_id;

  select can_add_to_cart, can_set_dropship_price
  into v_can_add_to_cart, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(p_shop_id);

  if coalesce(v_can_add_to_cart, false) is not true then
    raise exception 'cart additions not allowed';
  end if;

  select name, image_url, vendor_code, is_available, list_price_amount, list_price_currency_id
  into v_prod_name, v_prod_image, v_prod_vendor, v_prod_is_available, v_prod_price_amount, v_prod_price_currency_id
  from public.products
  where id = p_product_id;

  if v_prod_name is null then
    raise exception 'product not found';
  end if;

  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_shop_type in ('fixed_price', 'dropship') then
    if v_global_stock_id is null then
      raise exception 'global stock required for this shop type';
    end if;

    select
      l.id, l.global_stock_id, l.sell_price_amount, l.sell_price_currency_id,
      l.minimum_sell_price_amount, l.minimum_sell_price_currency_id, l.display_quantity_override
    into
      v_listing_id, v_global_stock_id, v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id, v_display_qty_override
    from public.shop_product_listings l
    where l.shop_id = p_shop_id
      and l.global_stock_id = v_global_stock_id
      and l.product_id = p_product_id
      and l.is_active = true;

    if v_listing_id is null then
      raise exception 'active product listing not found on this shop';
    end if;

    if v_shop_type = 'dropship' and exists (
      select 1
      from public.shop_listing_group_hides h
      where h.listing_id = v_listing_id
        and h.customer_group_id = public.current_customer_group_id(v_tenant_id)
    ) then
      raise exception 'product not available for this customer';
    end if;

    select coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
    into v_landed_cost
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gs.id = v_global_stock_id;

    if v_shop_type = 'fixed_price' then
      if v_pricing_method = 'markup' then
        v_sell_price_amount := v_landed_cost * (1 + v_markup_percentage / 100.0);
      elsif v_pricing_method = 'direct_cost' then
        v_sell_price_amount := v_landed_cost;
      end if;
    end if;

    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and global_stock_id = v_global_stock_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
    v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);

    if v_target_qty > v_available_to_sell then
      raise exception 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
    end if;

    if v_shop_type = 'dropship' then
      if coalesce(v_can_set_dropship_price, false) then
        if p_customer_sell_price_amount is not null then
          v_customer_sell_price_amount := p_customer_sell_price_amount;
          v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
        else
          if v_sell_price_currency_id = v_min_sell_price_currency_id then
            v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
          else
            v_customer_sell_price_amount := v_sell_price_amount;
          end if;
          v_customer_sell_price_currency_id := v_sell_price_currency_id;
        end if;

        if v_customer_sell_price_currency_id = v_min_sell_price_currency_id
           and v_customer_sell_price_amount < v_min_sell_price_amount then
          raise exception 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
        end if;
      else
        v_customer_sell_price_amount := v_sell_price_amount;
        v_customer_sell_price_currency_id := v_sell_price_currency_id;
      end if;
    end if;
  else
    select id, quantity into v_existing_item_id, v_existing_item_qty
    from public.shop_cart_items
    where cart_id = v_cart_id
      and product_id = p_product_id;

    v_existing_item_qty := coalesce(v_existing_item_qty, 0);
    v_target_qty := v_existing_item_qty + p_quantity;
  end if;

  if v_existing_item_id is not null then
    update public.shop_cart_items
    set
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    where id = v_existing_item_id;
  else
    insert into public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    values (
      v_cart_id, p_product_id, v_global_stock_id, null,
      p_quantity, 1,
      case when v_shop_type = 'dropship' then coalesce(v_landed_cost, v_prod_price_amount) else v_prod_price_amount end,
      case when v_shop_type = 'dropship' then v_buy_currency_id else v_prod_price_currency_id end,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  end if;

  return public.get_or_create_shop_cart(p_shop_id);
end;
$$;


ALTER FUNCTION "public"."add_to_shop_cart"("p_shop_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint, "p_quantity" integer, "p_customer_sell_price_amount" numeric, "p_customer_sell_price_currency_id" bigint, "p_global_stock_id" bigint) OWNER TO "postgres";

-- browse_dropship_listings_for_staff_order

CREATE OR REPLACE FUNCTION "public"."browse_dropship_listings_for_staff_order"("p_tenant_id" bigint, "p_shop_id" bigint, "p_customer_group_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 24) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_limit integer;
  v_search text;
  v_data jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_shop_id IS NULL OR p_customer_group_id IS NULL THEN
    RAISE EXCEPTION 'tenant, shop, and customer group are required';
  END IF;

  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  v_limit := greatest(1, least(coalesce(p_limit, 24), 100));
  v_search := nullif(trim(coalesce(p_search, '')), '');

  IF v_search IS NULL THEN
    RETURN jsonb_build_object('data', '[]'::jsonb, 'limit', v_limit);
  END IF;

  SELECT coalesce(
    jsonb_agg(row_data ORDER BY row_data->>'product_name'),
    '[]'::jsonb
  )
  INTO v_data
  FROM (
    SELECT jsonb_build_object(
      'listing_id', l.id,
      'product_id', l.product_id,
      'grade_tag_id', coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
      'global_stock_id', l.global_stock_id,
      'product_name', coalesce(nullif(trim(gsi.name), ''), p.name),
      'product_image_url', coalesce(gsi.image_url, p.image_url),
      'product_barcode', coalesce(gsi.barcode, p.barcode),
      'sell_price_amount', l.sell_price_amount,
      'sell_price_currency_id', l.sell_price_currency_id,
      'minimum_sell_price_amount', l.minimum_sell_price_amount,
      'minimum_sell_price_currency_id', l.minimum_sell_price_currency_id,
      'available_to_sell', greatest(
        0,
        floor(
          public.shop_product_grade_available_units(
            s.tenant_id,
            p.id,
            coalesce(l.grade_tag_id, gs.grade_tag_id)
          )
        )::integer
      )
    ) AS row_data
    FROM public.shop_product_listings l
    JOIN public.shops s ON s.id = l.shop_id
    JOIN public.products p ON p.id = l.product_id
    LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
    LEFT JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE l.shop_id = p_shop_id
      AND s.shop_type = 'dropship'
      AND l.is_active = true
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
      AND NOT EXISTS (
        SELECT 1 FROM public.shop_listing_group_hides h
        WHERE h.listing_id = l.id AND h.customer_group_id = p_customer_group_id
      )
      AND (
        p.name ILIKE '%' || v_search || '%'
        OR p.product_code ILIKE '%' || v_search || '%'
        OR p.barcode ILIKE '%' || v_search || '%'
      )
    ORDER BY coalesce(nullif(trim(gsi.name), ''), p.name) ASC
    LIMIT v_limit
  ) sub;

  RETURN jsonb_build_object('data', coalesce(v_data, '[]'::jsonb), 'limit', v_limit);
END;
$$;


ALTER FUNCTION "public"."browse_dropship_listings_for_staff_order"("p_tenant_id" bigint, "p_shop_id" bigint, "p_customer_group_id" bigint, "p_search" "text", "p_limit" integer) OWNER TO "postgres";

-- browse_shop_catalog_for_admin

CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_admin"("p_tenant_id" bigint, "p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 24, "p_cursor_name" "text" DEFAULT NULL::"text", "p_cursor_id" bigint DEFAULT NULL::bigint, "p_include_below_min_units" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    and (tenant_id = p_tenant_id or tenant_id = p_tenant_id)
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
      and p.tenant_id = v_parent_tenant_id
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
$$;


ALTER FUNCTION "public"."browse_shop_catalog_for_admin"("p_tenant_id" bigint, "p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_cursor_name" "text", "p_cursor_id" bigint, "p_include_below_min_units" boolean) OWNER TO "postgres";

-- browse_shop_catalog_for_customer

CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text" DEFAULT NULL::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 20, "p_cursor_name" "text" DEFAULT NULL::"text", "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_shop_id bigint;
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_display_quantity_add integer;
  v_vendor_filters jsonb;
  v_min_available_units integer;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_can_see_catalog_price boolean;
  v_limit integer;
  v_fetch_limit integer;
  v_cursor_name text;
  v_result jsonb;
  v_parent_tenant_id bigint;
  v_data jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_name text;
  v_last_id bigint;
  v_group_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    display_quantity_add, vendor_filters, min_available_units
  into
    v_shop_id, v_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_display_quantity_add, v_vendor_filters, v_min_available_units
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
  v_display_quantity_add := coalesce(v_display_quantity_add, 6);
  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));
  v_fetch_limit := v_limit + 1;
  v_cursor_name := coalesce(p_cursor_name, '');
  v_can_see_catalog_price := coalesce(v_can_see_buy_price, false);

  if v_shop_type = 'vendor_catalog' then
    execute format(
      $sql$
        with filtered as (
          select p.*
          from public.products p
          where p.is_available = true
            and coalesce(p.hazardous, false) = false
            and p.tenant_id = $2
            and (
              (($9 is null or jsonb_array_length($9) = 0) and p.vendor_code = $1)
              or
              ($9 is not null and jsonb_array_length($9) > 0 and exists (
                select 1
                from jsonb_to_recordset($9) as vf(vendor_code text, brands text[])
                where vf.vendor_code = p.vendor_code
                  and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
              ))
            )
            and ($3 is null or trim($3) = '' or p.name ilike ('%%' || trim($3) || '%%') or p.product_code ilike ('%%' || trim($3) || '%%') or p.barcode ilike ('%%' || trim($3) || '%%'))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.category, '')) = lower(trim($4)))
            and ($5 is null or trim($5) = '' or lower(coalesce(p.brand, '')) = lower(trim($5)))
            and ($11 = 0 or coalesce(p.available_units, 0) >= $11)
            and ($8 is null or (coalesce(p.name, ''), p.id) > (coalesce($7, ''), $8))
        ),
        paged as (
          select f.*
          from filtered f
          order by f.name asc, f.id asc
          limit $6
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
                  'product_code', p.product_code,
                  'product_brand', p.brand,
                  'product_category', p.category,
                  'vendor_code', p.vendor_code,
                  'is_available', p.is_available,
                  'unit_price', case
                    when $10 then jsonb_build_object(
                      'amount', p.list_price_amount,
                      'currency_id', p.list_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.list_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    )
                    else null
                  end,
                  'unit_price_amount', case when $10 then p.list_price_amount else null end,
                  'unit_price_currency_id', case when $10 then p.list_price_currency_id else null end,
                  'unit_price_currency_code', case
                    when $10 then (select code from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'unit_price_currency_symbol', case
                    when $10 then (select symbol from public.global_currencies where id = p.list_price_currency_id)
                    else null
                  end,
                  'sell_price', null,
                  'resell_minimum_price', null,
                  'available_units', null,
                  'global_stock_allocation_id', null,
                  'global_stock_id', null,
                  'minimum_order_quantity', p.minimum_order_quantity
                )
                order by p.name asc, p.id asc
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta', jsonb_build_object('limit', $6 - 1)
        )
      $sql$
    )
    into v_result
    using
      v_vendor_code,
      v_parent_tenant_id,
      p_search,
      p_category,
      p_brand,
      v_fetch_limit,
      v_cursor_name,
      p_cursor_id,
      v_vendor_filters,
      v_can_see_catalog_price,
      coalesce(v_min_available_units, 0);
  else
    execute format(
      $sql$
        with filtered as (
          select
            l.id as listing_id,
            l.global_stock_id,
            case
              when $9 = 'fixed_price' and $12 = 'markup' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + $13 / 100.0)
              when $9 = 'fixed_price' and $12 = 'direct_cost' then
                coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
              else
                l.sell_price_amount
            end as computed_sell_price,
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) as computed_unit_cost,
            l.sell_price_amount as listing_sell_price_amount,
            l.sell_price_currency_id as listing_sell_price_currency_id,
            l.sell_price_currency_id,
            l.minimum_sell_price_amount,
            l.minimum_sell_price_currency_id,
            l.show_quantity as listing_show_quantity,
            l.display_quantity_override,
            p.id as product_id,
            p.name as product_name,
            p.image_url as product_image_url,
            p.barcode as product_barcode,
            p.product_code as product_code,
            p.brand as product_brand,
            p.category as product_category,
            p.vendor_code as product_vendor_code,
            p.is_available as product_is_available,
            p.minimum_order_quantity as product_moq,
            public.shop_product_grade_available_units(
              $15,
              p.id,
              coalesce(l.grade_tag_id, gs.grade_tag_id)
            ) as available_qty,
            tg.slug as grade_slug,
            tg.name as grade_label,
            tg.color as grade_color
          from public.shop_product_listings l
          join public.products p on p.id = l.product_id
          left join public.global_stocks gs on gs.id = l.global_stock_id
          left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
          left join public.tags tg on tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
          where l.shop_id = $1
            and l.is_active = true
            and p.is_available = true
            and coalesce(p.hazardous, false) = false
            and ($2 is null or trim($2) = '' or p.name ilike ('%%' || trim($2) || '%%') or p.product_code ilike ('%%' || trim($2) || '%%') or p.barcode ilike ('%%' || trim($2) || '%%'))
            and ($3 is null or trim($3) = '' or lower(coalesce(p.category, '')) = lower(trim($3)))
            and ($4 is null or trim($4) = '' or lower(coalesce(p.brand, '')) = lower(trim($4)))
            and ($7 is null or (coalesce(p.name, ''), l.id) > (coalesce($6, ''), $7))
            and not exists (
              select 1
              from public.shop_listing_group_hides h
              where h.listing_id = l.id
                and h.customer_group_id = $20
            )
        ),
        paged as (
          select f.*
          from filtered f
          order by f.product_name asc, f.listing_id asc
          limit $5
        )
        select jsonb_build_object(
          'data',
          coalesce(
            (
              select jsonb_agg(
                jsonb_build_object(
                  'product_id', p.product_id,
                  'product_name', p.product_name,
                  'product_image_url', p.product_image_url,
                  'product_barcode', p.product_barcode,
                  'product_code', p.product_code,
                  'product_brand', p.product_brand,
                  'product_category', p.product_category,
                  'vendor_code', p.product_vendor_code,
                  'is_available', p.product_is_available,
                  'unit_price', case
                    when $9 = 'dropship' and $16 then jsonb_build_object(
                      'amount', p.computed_unit_cost,
                      'currency_id', $17,
                      'code', (select code from public.global_currencies where id = $17),
                      'symbol', (select symbol from public.global_currencies where id = $17)
                    )
                    else null
                  end,
                  'sell_price', case
                    when $8 and $9 = 'fixed_price' then jsonb_build_object(
                      'amount', p.computed_sell_price,
                      'currency_id', p.sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.sell_price_currency_id)
                    )
                    when $8 and $9 = 'dropship' then jsonb_build_object(
                      'amount', p.listing_sell_price_amount,
                      'currency_id', p.listing_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.listing_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.listing_sell_price_currency_id)
                    )
                    else null
                  end,
                  'resell_minimum_price', case
                    when $18 and $9 = 'dropship' then jsonb_build_object(
                      'amount', p.minimum_sell_price_amount,
                      'currency_id', p.minimum_sell_price_currency_id,
                      'code', (select code from public.global_currencies where id = p.minimum_sell_price_currency_id),
                      'symbol', (select symbol from public.global_currencies where id = p.minimum_sell_price_currency_id)
                    )
                    else null
                  end,
                  'available_units', case
                    when not $10 or not coalesce(p.listing_show_quantity, $11) then null
                    when $14 = 'original' then greatest(0, p.available_qty)
                    when p.display_quantity_override is not null
                      and not (p.display_quantity_override = 0 and p.available_qty > 0)
                      then p.display_quantity_override
                    else public.shop_padded_display_quantity(p.available_qty, $19)
                  end,
                  'listing_id', p.listing_id,
                  'stock_grade', case
                    when p.grade_slug is not null then jsonb_build_object(
                      'slug', p.grade_slug,
                      'label', p.grade_label,
                      'color', p.grade_color
                    )
                    else null
                  end,
                  'global_stock_allocation_id', p.global_stock_id,
                  'global_stock_id', p.global_stock_id,
                  'minimum_order_quantity', p.product_moq
                )
                order by p.product_name asc, p.listing_id asc
              )
              from paged p
            ),
            '[]'::jsonb
          ),
          'meta', jsonb_build_object('limit', $5 - 1)
        )
      $sql$
    )
    into v_result
    using
      v_shop_id,
      p_search,
      p_category,
      p_brand,
      v_fetch_limit,
      v_cursor_name,
      p_cursor_id,
      v_can_see_sell_price,
      v_shop_type,
      v_can_view_quantity,
      v_show_stock_quantity,
      v_pricing_method,
      v_markup_percentage,
      v_quantity_display_mode,
      v_tenant_id,
      v_can_see_buy_price,
      v_buy_currency_id,
      v_can_see_resell_minimum_price,
      v_display_quantity_add,
      v_group_id;
  end if;

  v_data := coalesce(v_result->'data', '[]'::jsonb);
  v_n := jsonb_array_length(v_data);
  if v_n > v_limit then
    v_has_more := true;
    select
      coalesce(t.elem->>'product_name', ''),
      case
        when v_shop_type = 'vendor_catalog' then (t.elem->>'product_id')::bigint
        else (t.elem->>'listing_id')::bigint
      end
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
    coalesce(v_result->'meta', '{}'::jsonb)
      || jsonb_build_object(
        'has_more', v_has_more,
        'next_cursor', v_next_cursor,
        'limit', v_limit
      )
  );

  if v_cursor_name = '' and p_cursor_id is null then
    v_result := jsonb_set(v_result, '{meta, shop}', jsonb_build_object(
      'id', v_shop_id,
      'name', v_shop_name,
      'slug', p_shop_slug,
      'shop_type', v_shop_type,
      'vendor_code', v_vendor_code,
      'order_mode', v_order_mode,
      'is_negotiable', v_is_negotiable,
      'show_stock_quantity', v_show_stock_quantity,
      'default_currency_id', v_default_currency_id,
      'is_active', v_is_active,
      'buy_currency_id', v_buy_currency_id,
      'sell_currency_id', v_sell_currency_id,
      'pricing_method', v_pricing_method,
      'markup_percentage', v_markup_percentage,
      'quantity_display_mode', v_quantity_display_mode,
      'vendor_filters', v_vendor_filters
    ));
    v_result := jsonb_set(v_result, '{meta, permissions}', jsonb_build_object(
      'can_browse', v_can_browse,
      'can_see_buy_price', v_can_see_buy_price,
      'can_see_sell_price', v_can_see_sell_price,
      'can_see_resell_minimum_price', v_can_see_resell_minimum_price,
      'can_add_to_cart', v_can_add_to_cart,
      'can_place_order', v_can_place_order,
      'can_negotiate', v_can_negotiate,
      'can_view_quantity', v_can_view_quantity,
      'can_set_dropship_price', v_can_set_dropship_price
    ));
  end if;

  return v_result;
end;
$_$;


ALTER FUNCTION "public"."browse_shop_catalog_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_search" "text", "p_category" "text", "p_brand" "text", "p_limit" integer, "p_cursor_name" "text", "p_cursor_id" bigint) OWNER TO "postgres";

-- build_dropship_tenant_b2b_invoice_payload

CREATE OR REPLACE FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint DEFAULT NULL::bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_profile_id bigint;
  v_invoice_no text;
  v_pick record;
  v_items jsonb := '[]'::jsonb;
  v_item_json jsonb;
  v_item_sell_price numeric(12,2);
  v_resell_price numeric(12,2);
  v_unit_cost numeric(12,2);
  v_line_id bigint;
  v_held public.global_stocks;
  v_charges record;
  v_channel_meta jsonb;
  v_gift record;
  v_gift_stock_id bigint;
  v_gift_shipment_item_id bigint;
  v_gift_name text;
  v_gift_barcode text;
  v_gift_product_code text;
  v_gift_assigned_child bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'ready_for_pickup'::public.shop_order_status,
    'shipped'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'tenant B2B invoice requires ready_for_pickup, shipped, or delivered (current: %s)',
        v_order.status
      )
    );
  end if;

  v_profile_id := coalesce(p_profile_id, v_order.profile_id);
  if v_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required on the order');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := public.next_document_number(v_order.tenant_id, 'dropship_b2b_invoice', null::text, now());
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_channel_meta := jsonb_strip_nulls(jsonb_build_object(
    'cod_collect_amount', v_order.cod_collect_amount,
    'collection_source', 'profile',
    'recipient_name', coalesce(v_order.recipient_name, v_order.name),
    'recipient_phone', v_order.recipient_phone,
    'recipient_address', v_order.shipping_address
  ));

  select * into v_charges
  from public.get_dropship_merchant_billable_charges(p_order_id);

  for v_pick in (
    select
      sp.id as pick_id,
      sp.order_item_id,
      sp.quantity as pick_quantity,
      sp.held_stock_id,
      sp.global_stock_id as source_stock_id,
      soi.product_id,
      soi.name as line_name,
      soi.unit_sell_price_amount,
      soi.final_price_amount,
      soi.customer_sell_price_amount,
      coalesce(soi.is_gift, false) as is_gift,
      soi.gift_source,
      coalesce(soi.gift_cost_amount, 0) as gift_cost_amount,
      soi.gift_cost_charged_to,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_item_stock_picks sp
    join public.shop_order_items soi on soi.id = sp.order_item_id
    left join public.global_stocks gs on gs.id = sp.held_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where sp.order_id = v_order.id
      and sp.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
  ) loop
    if v_pick.held_stock_id is null then
      return jsonb_build_object(
        'success', false,
        'error', format('pick %s is missing held_stock_id', v_pick.pick_id)
      );
    end if;

    select * into v_held from public.global_stocks where id = v_pick.held_stock_id;
    if v_held.id is null then
      return jsonb_build_object(
        'success', false,
        'error', format('held stock %s not found for pick %s', v_pick.held_stock_id, v_pick.pick_id)
      );
    end if;

    if v_held.availability <> 'held'::public.stock_availability then
      return jsonb_build_object(
        'success', false,
        'error', format('held stock %s must be held before issue (current: %s)', v_pick.held_stock_id, v_held.availability)
      );
    end if;

    if coalesce(v_pick.is_gift, false) and v_pick.gift_source = 'stock' and v_pick.gift_cost_charged_to = 'reseller' then
      v_item_sell_price := case
        when coalesce(v_pick.pick_quantity, 0) > 0 then
          round(coalesce(v_pick.gift_cost_amount, 0) / v_pick.pick_quantity, 2)
        else coalesce(v_pick.gift_cost_amount, 0)
      end;
    else
      v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
    end if;
    v_resell_price := coalesce(
      v_pick.customer_sell_price_amount,
      v_pick.final_price_amount,
      v_pick.unit_sell_price_amount,
      0
    );
    v_unit_cost := coalesce(v_pick.stock_cost, 0);
    v_line_id := null;

    if p_invoice_id is not null then
      select sii.id into v_line_id
      from public.bill_lines sii
      where sii.invoice_id = p_invoice_id
        and sii.global_stock_id = v_pick.held_stock_id
      order by sii.id
      limit 1;
    end if;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'id', v_line_id,
      'global_stock_id', v_pick.held_stock_id,
      'product_id', v_pick.product_id,
      'shipment_item_id', v_pick.stock_shipment_item_id,
      'name_snapshot',
        coalesce(v_pick.stock_name, v_pick.line_name)
        || case
          when coalesce(v_pick.is_gift, false)
            and v_pick.gift_source = 'stock'
            and v_pick.gift_cost_charged_to = 'reseller'
          then ' (Gift)'
          else ''
        end,
      'barcode_snapshot', v_pick.stock_barcode,
      'product_code_snapshot', v_pick.stock_product_code,
      'quantity', v_pick.pick_quantity,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_pick.stock_assigned_child,
      'line_meta',
        jsonb_build_object('resell_price_amount', v_resell_price)
        || case
          when coalesce(v_pick.is_gift, false)
            and v_pick.gift_source = 'stock'
            and v_pick.gift_cost_charged_to = 'reseller'
          then jsonb_build_object(
            'gift_line_total_amount', coalesce(v_pick.gift_cost_amount, 0),
            'is_warehouse_gift', true
          )
          else '{}'::jsonb
        end
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  for v_gift in
    select
      soi.id as order_item_id,
      soi.product_id,
      soi.name as line_name,
      soi.quantity,
      coalesce(soi.gift_cost_amount, 0) as gift_cost_amount,
      p.barcode as product_barcode,
      p.product_code as product_code
    from public.shop_order_items soi
    left join public.products p on p.id = soi.product_id
    where soi.order_id = v_order.id
      and coalesce(soi.is_gift, false)
      and soi.gift_source = 'stock'
      and soi.gift_cost_charged_to = 'reseller'
      and coalesce(soi.gift_cost_amount, 0) > 0
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  loop
    v_gift_shipment_item_id := null;
    v_gift_name := v_gift.line_name;
    v_gift_barcode := v_gift.product_barcode;
    v_gift_product_code := v_gift.product_code;
    v_gift_assigned_child := null;

    select
      gs.shipment_item_id,
      coalesce(gsi.name, v_gift.line_name),
      gsi.barcode,
      gsi.product_code,
      sh.assigned_child_tenant_id
    into
      v_gift_shipment_item_id,
      v_gift_name,
      v_gift_barcode,
      v_gift_product_code,
      v_gift_assigned_child
    from public.global_stock_allocations gsa
    inner join public.global_stocks gs on gs.id = gsa.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where gsa.shop_id = v_order.shop_id
      and gs.product_id = v_gift.product_id
    order by public.global_stock_atp_qty(gs.id) desc, gs.id
    limit 1;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'product_id', v_gift.product_id,
      'shipment_item_id', v_gift_shipment_item_id,
      'name_snapshot', v_gift_name || ' (Gift)',
      'barcode_snapshot', v_gift_barcode,
      'product_code_snapshot', v_gift_product_code,
      'quantity', v_gift.quantity,
      'sell_price_amount', case
        when coalesce(v_gift.quantity, 0) > 0 then
          round(coalesce(v_gift.gift_cost_amount, 0) / v_gift.quantity, 2)
        else coalesce(v_gift.gift_cost_amount, 0)
      end,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_gift_assigned_child,
      'line_meta', jsonb_build_object(
        'resell_price_amount', 0,
        'is_warehouse_gift', true,
        'gift_line_total_amount', coalesce(v_gift.gift_cost_amount, 0),
        'order_item_id', v_gift.order_item_id
      )
    ));

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  if jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'no billable picked lines for merchant invoice');
  end if;

  return jsonb_build_object(
    'success', true,
    'payload', jsonb_build_object(
      'invoice', jsonb_strip_nulls(jsonb_build_object(
        'invoice_type', 'dropship',
        'invoice_no', v_invoice_no,
        'profile_id', v_profile_id,
        'recipient_profile_id', v_order.recipient_profile_id,
        'recipient_name', coalesce(v_order.recipient_name, v_order.name),
        'recipient_phone', v_order.recipient_phone,
        'recipient_address', v_order.shipping_address,
        'note', coalesce(p_note, 'Merchant bill from dropship order #' || v_order.order_no),
        'discount_amount', coalesce(v_order.discount_amount, 0),
        'shipping_charge', coalesce(v_charges.delivery, 0),
        'cod_charge_amount', coalesce(v_charges.cod, 0),
        'print_charge', coalesce(v_charges.print, 0),
        'wrapping_charge', coalesce(v_charges.packing, 0),
        'collection_source', 'profile'::public.collection_source_type,
        'channel_meta', v_channel_meta
      )),
      'items', v_items,
      'shop_order_id', p_order_id
    )
  );
end;
$$;


ALTER FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_note" "text") OWNER TO "postgres";

-- create_sales_invoice_from_payload

CREATE OR REPLACE FUNCTION "public"."create_sales_invoice_from_payload"("p_tenant_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_inv jsonb;
  v_item_elem jsonb;
  v_invoice public.bills;
  v_invoice_id bigint;
  v_parent_id bigint;
  v_invoice_type public.global_invoice_type;
  v_retail_mode public.retail_billing_mode;
  v_issue boolean;
  v_shop_order_id bigint;
  v_items jsonb;
  v_item_ids bigint[] := '{}';
  v_created_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_stock_parent bigint;
  v_has_charges boolean;
  v_cod_charge numeric(12,2);
  v_line_meta jsonb;
  v_channel_meta jsonb;
  v_delivery_kind text;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object');
  end if;

  v_inv := coalesce(p_payload->'invoice', '{}'::jsonb);
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_issue := coalesce((p_payload->>'issue')::boolean, false);
  v_shop_order_id := nullif(p_payload->>'shop_order_id', '')::bigint;
  v_channel_meta := coalesce(v_inv->'channel_meta', '{}'::jsonb);
  v_delivery_kind := lower(trim(coalesce(v_channel_meta->>'delivery_kind', 'take')));
  if v_delivery_kind not in ('take', 'condition') then
    return jsonb_build_object('success', false, 'error', 'channel_meta.delivery_kind must be take or condition');
  end if;

  if v_inv->>'invoice_type' is null or trim(v_inv->>'invoice_type') = '' then
    return jsonb_build_object('success', false, 'error', 'invoice.invoice_type is required');
  end if;

  v_invoice_type := (v_inv->>'invoice_type')::public.global_invoice_type;

  if jsonb_typeof(v_items) <> 'array' then
    return jsonb_build_object('success', false, 'error', 'items must be a JSON array');
  end if;

  if v_issue and jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'at least one item is required when issue is true');
  end if;

  v_retail_mode := case
    when v_inv->>'retail_billing_mode' is null or trim(v_inv->>'retail_billing_mode') = '' then null
    else (v_inv->>'retail_billing_mode')::public.retail_billing_mode
  end;

  if v_delivery_kind = 'condition' then
    if v_invoice_type <> 'wholesale'::public.global_invoice_type then
      return jsonb_build_object('success', false, 'error', 'condition bills require wholesale invoice_type');
    end if;
    if v_retail_mode = 'direct'::public.retail_billing_mode then
      return jsonb_build_object('success', false, 'error', 'walk-in bills cannot be condition');
    end if;
  end if;

  v_channel_meta := coalesce(v_channel_meta, '{}'::jsonb) || jsonb_build_object('delivery_kind', v_delivery_kind);

  select * into v_invoice
  from public.create_sales_invoice(
    p_tenant_id => p_tenant_id,
    p_invoice_no => coalesce(nullif(trim(v_inv->>'invoice_no'), ''), ''),
    p_invoice_type => v_invoice_type,
    p_profile_id => nullif(v_inv->>'profile_id', '')::bigint,
    p_recipient_profile_id => nullif(v_inv->>'recipient_profile_id', '')::bigint,
    p_recipient_name => nullif(trim(v_inv->>'recipient_name'), ''),
    p_recipient_phone => nullif(trim(v_inv->>'recipient_phone'), ''),
    p_recipient_address => nullif(trim(v_inv->>'recipient_address'), ''),
    p_retail_billing_mode => v_retail_mode,
    p_due_date => nullif(v_inv->>'due_date', '')::date,
    p_note => nullif(trim(v_inv->>'note'), ''),
    p_invoice_date => nullif(v_inv->>'invoice_date', '')::date
  );

  v_invoice_id := v_invoice.id;
  v_parent_id := v_invoice.parent_tenant_id;

  update public.bills
  set
    shop_order_id = v_shop_order_id,
    channel_meta = v_channel_meta,
    settlement_kind = v_delivery_kind::public.bill_settlement_kind,
    updated_at = now()
  where id = v_invoice_id;

  perform public.stamp_bill_kernel_fields(v_invoice_id);

  for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
    v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
    v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
    v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
    v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);
    v_line_meta := coalesce(v_item_elem->'line_meta', '{}'::jsonb);

    if v_quantity is null or v_quantity <= 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires quantity > 0');
    end if;
    if v_sell_price is null or v_sell_price < 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires sell_price_amount >= 0');
    end if;

    if v_global_stock_id is null
       and coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
      v_product_id := nullif(v_item_elem->>'product_id', '')::bigint;
      v_shipment_item_id := nullif(v_item_elem->>'shipment_item_id', '')::bigint;
      v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), 'Gift item');
      v_barcode_snapshot := nullif(trim(v_item_elem->>'barcode_snapshot'), '');
      v_product_code_snapshot := nullif(trim(v_item_elem->>'product_code_snapshot'), '');
      v_assigned_child := nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint;
      v_line_total := coalesce(
        nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
        greatest((v_quantity * v_sell_price) - v_line_discount, 0)
      );

      insert into public.bill_lines (
        tenant_id,
        invoice_id,
        global_stock_id,
        shipment_item_id,
        product_id,
        name_snapshot,
        barcode_snapshot,
        product_code_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        assigned_child_tenant_id,
        line_meta
      )
      values (
        v_parent_id,
        v_invoice_id,
        null,
        v_shipment_item_id,
        v_product_id,
        v_name_snapshot,
        v_barcode_snapshot,
        v_product_code_snapshot,
        v_quantity,
        v_sell_price,
        v_line_discount,
        v_line_total,
        v_assigned_child,
        v_line_meta
      );

      continue;
    end if;

    if v_global_stock_id is null then
      return jsonb_build_object('success', false, 'error', 'each item requires global_stock_id');
    end if;

    select
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gsi.name,
      gsi.barcode,
      gsi.product_code,
      sh.assigned_child_tenant_id,
      p.id
    into
      v_stock_parent,
      v_shipment_item_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_assigned_child,
      v_product_id
    from public.global_stocks gs
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    left join public.products p on p.id = gsi.product_id
    where gs.id = v_global_stock_id;

    if v_stock_parent is null then
      return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id));
    end if;

    if v_stock_parent <> v_parent_id then
      return jsonb_build_object('success', false, 'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id));
    end if;

    v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
    v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
    v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
    v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
    v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
    v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);

    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest((v_quantity * v_sell_price) - v_line_discount, 0)
    );

    insert into public.bill_lines (
      tenant_id,
      invoice_id,
      global_stock_id,
      shipment_item_id,
      product_id,
      name_snapshot,
      barcode_snapshot,
      product_code_snapshot,
      quantity,
      sell_price_amount,
      line_discount_amount,
      line_total_amount,
      assigned_child_tenant_id,
      line_meta
    )
    values (
      v_parent_id,
      v_invoice_id,
      v_global_stock_id,
      v_shipment_item_id,
      v_product_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_quantity,
      v_sell_price,
      v_line_discount,
      v_line_total,
      v_assigned_child,
      v_line_meta
    )
    returning id into v_created_item_id;

    v_item_ids := array_append(v_item_ids, v_created_item_id);
  end loop;

  v_cod_charge := case
    when v_invoice_type = 'wholesale'::public.global_invoice_type then null
    when v_inv ? 'cod_charge_amount' then nullif(v_inv->>'cod_charge_amount', '')::numeric
    when v_inv ? 'cod_charge' then nullif(v_inv->>'cod_charge', '')::numeric
    else null
  end;

  v_has_charges := (
    v_inv ? 'discount_amount'
    or v_inv ? 'shipping_charge'
    or v_inv ? 'print_charge'
    or v_inv ? 'wrapping_charge'
    or (
      v_invoice_type <> 'wholesale'::public.global_invoice_type
      and (v_inv ? 'cod_charge_amount' or v_inv ? 'cod_charge')
    )
  );

  if v_has_charges then
    perform public.update_global_invoice_header(
      p_invoice_id => v_invoice_id,
      p_discount_amount => case when v_inv ? 'discount_amount' then nullif(v_inv->>'discount_amount', '')::numeric else null end,
      p_shipping_charge => case when v_inv ? 'shipping_charge' then nullif(v_inv->>'shipping_charge', '')::numeric else null end,
      p_cod_charge => v_cod_charge,
      p_wrapping_charge => case when v_inv ? 'wrapping_charge' then nullif(v_inv->>'wrapping_charge', '')::numeric else null end,
      p_print_charge => case when v_inv ? 'print_charge' then nullif(v_inv->>'print_charge', '')::numeric else null end,
      p_recipient_name => null,
      p_recipient_phone => null,
      p_recipient_address => null,
      p_note => null,
      p_invoice_no => null,
      p_invoice_date => null
    );
  else
    perform public.recompute_global_invoice_totals(v_invoice_id);
  end if;

  if v_issue then
    perform public.post_sales_invoice(v_invoice_id);
    perform public.sync_sales_invoice_charges_from_header(v_invoice_id);
  end if;

  if v_shop_order_id is not null then
    if not exists (
      select 1 from public.shop_orders o
      where o.id = v_shop_order_id
        and o.tenant_id = p_tenant_id
        and o.shop_type_snapshot = 'dropship'
    ) then
      return jsonb_build_object('success', false, 'error', 'shop_order_id must be a dropship order for this tenant');
    end if;

    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = v_shop_order_id
      and tenant_id = p_tenant_id
      and global_invoice_id is null;
  end if;

  select * into v_invoice from public.bills where id = v_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'subtotal_amount', v_invoice.subtotal_amount,
    'discount_amount', v_invoice.discount_amount,
    'shipping_charge', v_invoice.shipping_charge,
    'cod_charge_amount', coalesce((v_invoice.channel_meta->>'cod_charge_amount')::numeric, 0),
    'print_charge', v_invoice.print_charge,
    'wrapping_charge', v_invoice.wrapping_charge,
    'total_amount', v_invoice.total_amount,
    'paid_amount', v_invoice.paid_amount,
    'due_amount', v_invoice.due_amount,
    'profile_id', v_invoice.profile_id,
    'collection_source', v_invoice.collection_source,
    'item_ids', to_jsonb(v_item_ids),
    'issued', v_issue,
    'shop_order_id', v_shop_order_id
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;


ALTER FUNCTION "public"."create_sales_invoice_from_payload"("p_tenant_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shipments" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "product_conversion_rate" numeric(12,4),
    "cargo_conversion_rate" numeric(12,4),
    "cargo_rate" numeric(12,4),
    "received_weight" numeric(12,3),
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "status" "text" DEFAULT 'Draft'::"text" NOT NULL,
    "inventory_added" boolean DEFAULT false NOT NULL,
    "market_code" "text",
    "tenant_shipment_id" bigint NOT NULL,
    "transaction_rate" numeric(12,4),
    "shipment_type" "text" DEFAULT 'international'::"text" NOT NULL,
    CONSTRAINT "shipments_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "shipments_shipment_type_check" CHECK (("shipment_type" = ANY (ARRAY['local'::"text", 'international'::"text"]))),
    CONSTRAINT "shipments_status_check" CHECK (("status" = ANY (ARRAY['Draft'::"text", 'Order Placed'::"text", 'Proforma Generated'::"text", 'Payment Done'::"text", 'Delivery Date Received'::"text", 'Uk Warehouse Delivery Received'::"text", 'Air Shipment Date Set'::"text", 'Airport Arrival'::"text", 'Airport Released'::"text", 'Warehouse Received'::"text", 'Added to Inventory'::"text"])))
);


ALTER TABLE "public"."shipments" OWNER TO "postgres";

-- customer_accessible_catalog_glance

CREATE OR REPLACE FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
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
  ),
  parent_tenant AS (
    SELECT public.resolve_parent_tenant_id(p_tenant_id) AS parent_tenant_id
  ),
  vendor_catalog_products AS (
    SELECT DISTINCT
      p.id AS product_id,
      p.brand AS product_brand
    FROM accessible_shops s
    CROSS JOIN parent_tenant pt
    JOIN public.products p ON p.tenant_id = pt.parent_tenant_id
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


ALTER FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

-- fetch_customer_shop_categories

CREATE OR REPLACE FUNCTION "public"."fetch_customer_shop_categories"("p_tenant_id" bigint) RETURNS TABLE("name" "text", "count" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
begin
  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  with accessible_shops as (
    select distinct s.id, s.shop_type, s.vendor_code, s.vendor_filters
    from public.shops s
    join public.shop_customer_group_access access on access.shop_id = s.id
    join public.customer_groups cg on cg.id = access.customer_group_id
    join public.customer_group_members cgm on cgm.customer_group_id = cg.id
    left join public.customer_group_shop_profiles profile
      on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
    where s.is_active = true
      and cg.is_active = true
      and cgm.is_active = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and s.tenant_id = p_tenant_id
      and access.status = true
      and coalesce(profile.is_active, true) = true
      and coalesce(access.can_browse, profile.default_can_browse, false) = true
  ),
  vendor_products as (
    select distinct p.id, p.category
    from public.products p
    join accessible_shops s on s.shop_type = 'vendor_catalog'
    where p.is_available = true
      and p.tenant_id = v_parent_tenant_id
      and (
        ((s.vendor_filters is null or jsonb_array_length(s.vendor_filters) = 0) and p.vendor_code = s.vendor_code)
        or
        (s.vendor_filters is not null and jsonb_array_length(s.vendor_filters) > 0 and exists (
          select 1 
          from jsonb_to_recordset(s.vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
  ),
  listing_products as (
    select distinct p.id, p.category
    from public.shop_product_listings l
    join accessible_shops s on s.id = l.shop_id and s.shop_type <> 'vendor_catalog'
    join public.products p on p.id = l.product_id
    where l.is_active = true
      and p.is_available = true
  ),
  combined_products as (
    select id, category from vendor_products
    union
    select id, category from listing_products
  )
  select 
    coalesce(nullif(trim(cp.category), ''), 'Uncategorized') as name,
    count(cp.id)::bigint as count
  from combined_products cp
  group by coalesce(nullif(trim(cp.category), ''), 'Uncategorized')
  order by count(cp.id) desc, name asc;
end;
$$;


ALTER FUNCTION "public"."fetch_customer_shop_categories"("p_tenant_id" bigint) OWNER TO "postgres";

-- get_customer_shop_order

CREATE OR REPLACE FUNCTION "public"."get_customer_shop_order"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_group_id bigint;
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_shop_slug text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_symbol text;
  v_buy_symbol text;
  v_item_count bigint;
  v_total_amount numeric;
  v_items jsonb;
  v_order_json jsonb;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.customer_group_id is distinct from v_group_id then
    raise exception 'order not found';
  end if;

  select
    s.name,
    s.slug,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.symbol,
    buy_gc.symbol
  into
    v_shop_name,
    v_shop_slug,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_symbol,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  if v_order.shop_type_snapshot = 'dropship'::public.shop_type_enum then
    v_can_see_buy_price := true;
    v_can_see_sell_price := true;
  else
    select
      case
        when v_order.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, perm.can_see_buy_price, false)
        else coalesce(perm.can_see_buy_price, false)
      end,
      case
        when v_order.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, perm.can_see_sell_price, false)
        else coalesce(perm.can_see_sell_price, false)
      end
    into v_can_see_buy_price, v_can_see_sell_price
    from public.get_shop_permissions_for_customer(v_order.shop_id) perm
    left join public.shop_carts c on c.id = v_order.cart_id;
  end if;

  v_can_see_buy_price := coalesce(v_can_see_buy_price, false);
  v_can_see_sell_price := coalesce(v_can_see_sell_price, false);

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        case
          when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null
          else soi.unit_list_price_amount
        end
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'unit_list_price_amount', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_amount end,
        'unit_list_price_currency_id', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_currency_id end,
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount', soi.customer_sell_price_amount,
        'customer_sell_price_currency_id', soi.customer_sell_price_currency_id,
        'customer_offer_amount', soi.customer_offer_amount,
        'customer_offer_currency_id', soi.customer_offer_currency_id,
        'staff_offer_amount', soi.staff_offer_amount,
        'staff_offer_currency_id', soi.staff_offer_currency_id,
        'is_first_offer_manual', soi.is_first_offer_manual,
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'final_offer_amount', soi.final_price_amount,
        'is_final_offer_manual', soi.is_final_offer_manual,
        'confirmed_quantity', soi.confirmed_quantity,
        'weight_kg', soi.weight_kg,
        'customer_decision_status', soi.customer_decision_status,
        'customer_decision_at', soi.customer_decision_at,
        'negotiation_status', soi.negotiation_status,
        'staff_offer_at', soi.staff_offer_at,
        'customer_counter_at', soi.customer_counter_at,
        'final_offer_at', soi.final_offer_at,
        'returned_quantity', soi.returned_quantity,
        'sku', p.product_code,
        'brand', p.brand,
        'barcode', p.barcode,
        'minimum_order_quantity', p.minimum_order_quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  v_order_json :=
    jsonb_build_object(
      'id', v_order.id,
      'tenant_id', v_order.tenant_id,
      'shop_id', v_order.shop_id,
      'shop_name', v_shop_name,
      'shop_slug', v_shop_slug,
      'customer_group_id', v_order.customer_group_id,
      'cart_id', v_order.cart_id,
      'order_no', v_order.order_no,
      'name', v_order.name,
      'shop_type_snapshot', v_order.shop_type_snapshot,
      'order_mode_snapshot', v_order.order_mode_snapshot,
      'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
      'status', v_order.status,
      'negotiate_round', v_order.negotiate_round,
      'cargo_rate', v_order.cargo_rate,
      'conversion_rate', v_order.conversion_rate,
      'profit_rate', v_order.profit_rate,
      'first_offer_rate', v_order.first_offer_rate,
      'final_offer_rate', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_phone_secondary', v_order.recipient_phone_secondary,
      'shipping_address', v_order.shipping_address,
      'shipping_district', v_order.shipping_district,
      'shipping_thana', v_order.shipping_thana,
      'recipient_profile_id', v_order.recipient_profile_id,
      'profile_id', v_order.profile_id,
      'placed_at', v_order.placed_at,
      'fulfilled_at', v_order.fulfilled_at,
      'shop_sell_currency_id', v_sell_currency_id,
      'shop_buy_currency_id', v_buy_currency_id,
      'shop_sell_currency_symbol', v_sell_symbol,
      'shop_buy_currency_symbol', v_buy_symbol,
      'can_see_buy_price', v_can_see_buy_price,
      'can_see_sell_price', v_can_see_sell_price
    )
    || jsonb_build_object(
      'created_at', v_order.created_at,
      'updated_at', v_order.updated_at,
      'cod_charge_amount', v_order.cod_charge_amount,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'print_charge_amount', v_order.print_charge_amount,
      'packing_charge_amount', v_order.packing_charge_amount,
      'discount_amount', v_order.discount_amount,
      'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
      'delivery_instructions', v_order.delivery_instructions,
      'deduct_charges_from_margin', v_order.deduct_charges_from_margin,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'item_count', v_item_count,
      'total_amount', case
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and not v_can_see_sell_price then null
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and v_total_amount = 0 then null
        else v_total_amount
      end,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'payout_settlement_status', v_order.payout_settlement_status,
      'cancel_reason', v_order.cancel_reason,
      'recipient_call_attempt_count', coalesce(v_order.recipient_call_attempt_count, 0),
      'recipient_verified_at', v_order.recipient_verified_at
    );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$$;


ALTER FUNCTION "public"."get_customer_shop_order"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";

-- get_dropship_order_detail_v2

CREATE OR REPLACE FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_customer_group_name text;
  v_sell_symbol text;
  v_buy_currency_id bigint;
  v_items jsonb;
  v_courier_ap_bill_id bigint;
  v_items_resell_total numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_recipient_grand_total numeric := 0;
  v_all_lines_resolved boolean := false;
  v_total_delivered_qty numeric := 0;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select o.*
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  select s.name, gc.symbol, s.buy_currency_id
  into v_shop_name, v_sell_symbol, v_buy_currency_id
  from public.shops s
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'cost_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'cost_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_list_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'unit_list_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount',
          coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount),
        'customer_sell_price_currency_id',
          coalesce(soi.customer_sell_price_currency_id, soi.final_price_currency_id, soi.unit_sell_price_currency_id),
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'returned_quantity', coalesce(soi.returned_quantity, 0),
        'confirmed_quantity', soi.confirmed_quantity,
        'is_fulfillment_unavailable', coalesce(soi.is_fulfillment_unavailable, false),
        'unavailable_reason', soi.unavailable_reason,
        'fulfillment_resolved', (
          coalesce(soi.is_fulfillment_unavailable, false)
          or coalesce(soi.confirmed_quantity, 0) > 0
          or (coalesce(soi.is_gift, false) and soi.gift_source = 'customer_stock' and coalesce(soi.confirmed_quantity, 0) >= soi.quantity)
          or (coalesce(soi.is_gift, false) and soi.gift_source = 'stock')
        ),
        'is_gift', coalesce(soi.is_gift, false),
        'gift_source', soi.gift_source,
        'gift_cost_amount', coalesce(soi.gift_cost_amount, 0),
        'gift_cost_charged_to', soi.gift_cost_charged_to,
        'gift_added_by', soi.gift_added_by,
        'shop_customer_stock_id', soi.shop_customer_stock_id,
        'sku', p.product_code,
        'barcode', p.barcode,
        'brand', p.brand,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)
      * soi.quantity
    ),
    0
  )
  into v_items_resell_total
  from public.shop_order_items soi
  where soi.order_id = v_order.id
    and not coalesce(soi.is_gift, false);

  v_recipient_charge_total :=
    case when not coalesce(v_order.deduct_delivery_from_margin, false)
      then coalesce(v_order.delivery_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_cod_from_margin, false)
      then coalesce(v_order.cod_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_print_from_margin, false)
      then coalesce(v_order.print_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_packing_from_margin, false)
      then coalesce(v_order.packing_charge_amount, 0) else 0 end;

  v_recipient_grand_total :=
    v_items_resell_total + v_recipient_charge_total - coalesce(v_order.discount_amount, 0);

  select coalesce(bool_and(
    coalesce(soi.is_fulfillment_unavailable, false)
    or coalesce(soi.confirmed_quantity, 0) > 0
    or (
      coalesce(soi.is_gift, false)
      and soi.gift_source = 'customer_stock'
      and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
    )
    or (
      coalesce(soi.is_gift, false)
      and soi.gift_source = 'stock'
    )
  ), true)
  into v_all_lines_resolved
  from public.shop_order_items soi
  where soi.order_id = v_order.id and soi.quantity > 0;

  select coalesce(sum(coalesce(soi.confirmed_quantity, 0)), 0)
  into v_total_delivered_qty
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select b.id
  into v_courier_ap_bill_id
  from public.bills b
  where b.source_id = p_order_id::text
    and b.invoice_type = 'ap'
    and b.invoice_status is distinct from 'voided'
    and (
      b.source_type = 'dropship_courier'
      or (b.source_type = 'shop_order' and b.source_key = 'courier')
    )
  order by case when b.source_type = 'dropship_courier' then 0 else 1 end, b.id
  limit 1;

  return jsonb_build_object(
    'success', true,
    'order', (
      jsonb_build_object(
        'id', v_order.id,
        'tenant_id', v_order.tenant_id,
        'shop_id', v_order.shop_id,
        'shop_name', v_shop_name,
        'customer_group_id', v_order.customer_group_id,
        'customer_group_name', v_customer_group_name,
        'cart_id', v_order.cart_id,
        'order_no', v_order.order_no,
        'name', v_order.name,
        'shop_type_snapshot', v_order.shop_type_snapshot,
        'order_mode_snapshot', v_order.order_mode_snapshot,
        'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
        'status', v_order.status,
        'negotiate_round', v_order.negotiate_round,
        'placed_at', v_order.placed_at,
        'fulfilled_at', v_order.fulfilled_at,
        'global_invoice_id', v_order.global_invoice_id,
        'created_by_email', v_order.created_by_email,
        'created_at', v_order.created_at,
        'updated_at', v_order.updated_at,
        'shop_sell_currency_symbol', v_sell_symbol,
        'recipient_name', v_order.recipient_name,
        'recipient_phone', v_order.recipient_phone,
        'recipient_phone_secondary', v_order.recipient_phone_secondary,
        'shipping_address', v_order.shipping_address,
        'shipping_thana', v_order.shipping_thana,
        'shipping_district', v_order.shipping_district,
        'shipping_post_code', null,
        'recipient_profile_id', v_order.recipient_profile_id,
        'profile_id', v_order.profile_id,
        'delivery_instructions', v_order.delivery_instructions,
        'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
        'cod_charge_amount', v_order.cod_charge_amount,
        'delivery_charge_amount', v_order.delivery_charge_amount,
        'print_charge_amount', v_order.print_charge_amount,
        'packing_charge_amount', v_order.packing_charge_amount,
        'discount_amount', v_order.discount_amount,
        'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
        'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
        'deduct_print_from_margin', v_order.deduct_print_from_margin,
        'deduct_packing_from_margin', v_order.deduct_packing_from_margin
      ) || jsonb_build_object(
        'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total),
        'item_count', jsonb_array_length(v_items),
        'delivery_zone', v_order.delivery_zone,
        'courier_name', v_order.courier_name,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'courier_ap_bill_id', v_courier_ap_bill_id,
        'recipient_call_attempt_count', coalesce(v_order.recipient_call_attempt_count, 0),
        'recipient_verified_at', v_order.recipient_verified_at,
        'cancel_reason', v_order.cancel_reason,
        'auto_gifts_applied_at', v_order.auto_gifts_applied_at,
        'auto_gifts_apply_result', v_order.auto_gifts_apply_result
      )
    ),
    'items', v_items,
    'summary', jsonb_build_object(
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'cod_charge_amount', v_order.cod_charge_amount,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'print_charge_amount', v_order.print_charge_amount,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'packing_charge_amount', v_order.packing_charge_amount,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'discount_amount', v_order.discount_amount,
      'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total)
    ),
    'computed', jsonb_build_object(
      'items_resell_total', v_items_resell_total,
      'recipient_charge_total', v_recipient_charge_total,
      'recipient_grand_total', v_recipient_grand_total,
      'all_lines_resolved', v_all_lines_resolved,
      'total_delivered_qty', v_total_delivered_qty,
      'delivery_zone_label',
        case v_order.delivery_zone
          when 'inside_dhaka' then 'Inside Dhaka'
          when 'outside_dhaka' then 'Outside Dhaka'
          else null
        end
    ),
    'fulfillment', jsonb_build_object(
      'pickup', jsonb_build_object(
        'merchant_id', null,
        'sender_name', coalesce(v_order.sender_name, v_order.default_sender_name),
        'pickup_phone', coalesce(v_order.pickup_phone, v_order.default_pickup_phone),
        'pickup_address', coalesce(v_order.pickup_address, v_order.default_pickup_address)
      ),
      'courier', jsonb_build_object(
        'courier_service_id', v_order.courier_service_id,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'allow_open_box', coalesce(v_order.allow_open_box, false),
        'cod_charge', v_order.cod_charge_amount
      )
    ),
    'permissions', jsonb_build_object(
      'can_show_invoice_paper', v_order.status = 'confirmed',
      'can_start_processing', false,
      'can_confirm_recipient_call', v_order.status = 'confirmed' and v_order.recipient_verified_at is null,
      'can_mark_ready_for_pickup', v_order.status = 'processing',
      'can_mark_shipped', v_order.status = 'ready_for_pickup',
      'can_print_customer_invoice', v_order.status in ('ready_for_pickup', 'shipped', 'delivered')
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";

-- get_dropship_review_cart

CREATE OR REPLACE FUNCTION "public"."get_dropship_review_cart"("p_shop_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_type public.shop_type_enum;
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_cart_id bigint;
  v_result jsonb;
  v_resell_subtotal numeric := 0;
  v_has_floor_violation boolean := false;
  v_delivery_min numeric := 60;
  v_delivery_max numeric := 130;
  v_cod_percent_min numeric := 1;
  v_cod_percent_max numeric := 1;
  v_delivery_mid numeric;
  v_cod_charge_preview numeric;
  v_recipient_grand_total numeric;
begin
  select tenant_id, shop_type into v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id
    and access.status = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  end if;

  select c.id into v_cart_id
  from public.shop_carts c
  where c.tenant_id = v_tenant_id
    and c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id
    and c.status = 'active'
  order by c.id desc
  limit 1;

  if v_cart_id is null then
    raise exception 'cart not found';
  end if;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'shop_name', s.name,
      'shop_slug', s.slug,
      'customer_group_id', c.customer_group_id,
      'status', c.status,
      'allow_delivery', s.allow_delivery,
      'currency', jsonb_build_object(
        'id', s.sell_currency_id,
        'code', gc.code,
        'symbol', gc.symbol
      ),
      'charges', jsonb_build_object(
        'cod_charge_amount', c.cod_charge_amount,
        'delivery_charge_amount', c.delivery_charge_amount,
        'print_charge_amount', coalesce(nullif(c.print_charge_amount, 0), s.default_print_charge_amount),
        'packing_charge_amount', coalesce(nullif(c.packing_charge_amount, 0), s.default_packing_charge_amount),
        'discount_amount', c.discount_amount,
        'is_prepaid', c.is_prepaid,
        'delivery_instructions', c.delivery_instructions
      ),
      'margin_deductions', jsonb_build_object(
        'deduct_charges_from_margin', c.deduct_charges_from_margin,
        'deduct_print_from_margin', c.deduct_print_from_margin,
        'deduct_packing_from_margin', c.deduct_packing_from_margin
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'permissions', (
      select jsonb_build_object(
        'can_browse', p.can_browse,
        'can_see_buy_price', p.can_see_buy_price,
        'can_see_sell_price', p.can_see_sell_price,
        'can_see_resell_minimum_price', p.can_see_resell_minimum_price,
        'can_add_to_cart', p.can_add_to_cart,
        'can_place_order', p.can_place_order,
        'can_negotiate', p.can_negotiate,
        'can_view_quantity', p.can_view_quantity,
        'can_set_dropship_price', p.can_set_dropship_price
      )
      from public.get_shop_permissions_for_customer(p_shop_id) p
      limit 1
    ),
    'items', coalesce(items.items, '[]'::jsonb),
    'totals', coalesce(items.totals, jsonb_build_object(
      'item_count', 0,
      'line_count', 0,
      'purchase_subtotal', 0,
      'resell_subtotal', 0,
      'estimated_profit', 0
    ))
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select
      jsonb_agg(
        jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'global_stock_id', ci.global_stock_id,
          'name', ci.name,
          'image_url', ci.image_url,
          'quantity', ci.quantity,
          'minimum_quantity', ci.minimum_quantity,
          'minimum_order_quantity', p.minimum_order_quantity,
          'purchase_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'listing_sell_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'resell_price', jsonb_build_object(
            'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
            'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
            'code', coalesce(cust_gc.code, sell_gc.code),
            'symbol', coalesce(cust_gc.symbol, sell_gc.symbol)
          ),
          'min_resell_price', jsonb_build_object(
            'amount', ci.unit_minimum_sell_price_amount,
            'currency_id', ci.unit_minimum_sell_price_currency_id,
            'code', min_gc.code,
            'symbol', min_gc.symbol
          ),
          'line_totals', jsonb_build_object(
            'purchase_subtotal', ci.quantity * coalesce(ci.unit_sell_price_amount, 0),
            'resell_subtotal', ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
          ),
          'is_resell_below_floor', (
            coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
            and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
              < ci.unit_minimum_sell_price_amount
          )
        )
        order by ci.id
      ) as items,
      jsonb_build_object(
        'item_count', coalesce(sum(ci.quantity), 0),
        'line_count', count(ci.id),
        'purchase_subtotal', coalesce(sum(ci.quantity * coalesce(ci.unit_sell_price_amount, 0)), 0),
        'resell_subtotal', coalesce(sum(
          ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        ), 0),
        'estimated_profit', coalesce(sum(
          ci.quantity * (
            coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
            - coalesce(ci.unit_sell_price_amount, 0)
          )
        ), 0)
      ) as totals
    from public.shop_cart_items ci
    left join public.products p on p.id = ci.product_id
    left join public.global_currencies sell_gc on sell_gc.id = ci.unit_sell_price_currency_id
    left join public.global_currencies cust_gc on cust_gc.id = ci.customer_sell_price_currency_id
    left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
    where ci.cart_id = c.id
  ) items on true
  where c.id = v_cart_id;

  if coalesce(jsonb_array_length(v_result->'items'), 0) = 0 then
    raise exception 'cart is empty';
  end if;

  v_resell_subtotal := coalesce((v_result->'totals'->>'resell_subtotal')::numeric, 0);

  select bool_or((item->>'is_resell_below_floor')::boolean)
  into v_has_floor_violation
  from jsonb_array_elements(v_result->'items') item;

  select
    coalesce(min(least(cs.inside_dhaka_fee, cs.outside_dhaka_fee)), 60),
    coalesce(max(greatest(cs.inside_dhaka_fee, cs.outside_dhaka_fee)), 130),
    coalesce(min(cs.cod_fee_percent) filter (where cs.cod_fee_mode = 'percent_of_collect'), 1),
    coalesce(max(cs.cod_fee_percent) filter (where cs.cod_fee_mode = 'percent_of_collect'), 1)
  into v_delivery_min, v_delivery_max, v_cod_percent_min, v_cod_percent_max
  from public.courier_services cs
  where cs.tenant_id = v_tenant_id
    and cs.is_active = true;

  v_delivery_mid := (v_delivery_min + v_delivery_max) / 2;
  v_cod_charge_preview := round(v_resell_subtotal * coalesce(v_cod_percent_min, 1) / 100, 2);
  v_recipient_grand_total := v_resell_subtotal + v_delivery_mid + v_cod_charge_preview;

  return v_result || jsonb_build_object(
    'charge_estimates', jsonb_build_object(
      'delivery_min', v_delivery_min,
      'delivery_max', v_delivery_max,
      'delivery_mid', v_delivery_mid,
      'cod_percent_min', v_cod_percent_min,
      'cod_percent_max', v_cod_percent_max,
      'cod_charge_preview', v_cod_charge_preview
    ),
    'review_summary', jsonb_build_object(
      'total_units', coalesce((v_result->'totals'->>'item_count')::int, 0),
      'has_floor_violation', coalesce(v_has_floor_violation, false),
      'recipient_grand_total', v_recipient_grand_total,
      'can_continue', not coalesce(v_has_floor_violation, false)
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_dropship_review_cart"("p_shop_id" bigint) OWNER TO "postgres";

-- get_dropship_shop_cart

CREATE OR REPLACE FUNCTION "public"."get_dropship_shop_cart"("p_shop_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_type public.shop_type_enum;
  v_cart_id bigint;
  v_result jsonb;
begin
  select shop_type into v_shop_type
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_shop_type is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  v_cart_id := (public.get_or_create_shop_cart(p_shop_id)->'cart'->>'id')::bigint;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'shop_name', s.name,
      'shop_slug', s.slug,
      'customer_group_id', c.customer_group_id,
      'status', c.status,
      'allow_delivery', s.allow_delivery,
      'currency', jsonb_build_object(
        'id', s.sell_currency_id,
        'code', gc.code,
        'symbol', gc.symbol
      ),
      'charges', jsonb_build_object(
        'cod_charge_amount', c.cod_charge_amount,
        'delivery_charge_amount', c.delivery_charge_amount,
        'print_charge_amount', coalesce(nullif(c.print_charge_amount, 0), s.default_print_charge_amount),
        'packing_charge_amount', coalesce(nullif(c.packing_charge_amount, 0), s.default_packing_charge_amount),
        'discount_amount', c.discount_amount,
        'is_prepaid', c.is_prepaid,
        'delivery_instructions', c.delivery_instructions
      ),
      'margin_deductions', jsonb_build_object(
        'deduct_charges_from_margin', c.deduct_charges_from_margin,
        'deduct_print_from_margin', c.deduct_print_from_margin,
        'deduct_packing_from_margin', c.deduct_packing_from_margin
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'permissions', (
      select jsonb_build_object(
        'can_browse', p.can_browse,
        'can_see_buy_price', p.can_see_buy_price,
        'can_see_sell_price', p.can_see_sell_price,
        'can_see_resell_minimum_price', p.can_see_resell_minimum_price,
        'can_add_to_cart', p.can_add_to_cart,
        'can_place_order', p.can_place_order,
        'can_negotiate', p.can_negotiate,
        'can_view_quantity', p.can_view_quantity,
        'can_set_dropship_price', p.can_set_dropship_price
      )
      from public.get_shop_permissions_for_customer(p_shop_id) p
      limit 1
    ),
    'items', coalesce(items.items, '[]'::jsonb),
    'totals', coalesce(items.totals, jsonb_build_object(
      'item_count', 0,
      'line_count', 0,
      'purchase_subtotal', 0,
      'resell_subtotal', 0,
      'estimated_profit', 0
    ))
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select
      jsonb_agg(
        jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'global_stock_id', ci.global_stock_id,
          'name', ci.name,
          'image_url', ci.image_url,
          'quantity', ci.quantity,
          'minimum_quantity', ci.minimum_quantity,
          'minimum_order_quantity', p.minimum_order_quantity,
          'purchase_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'listing_sell_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'resell_price', jsonb_build_object(
            'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
            'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
            'code', coalesce(cust_gc.code, sell_gc.code),
            'symbol', coalesce(cust_gc.symbol, sell_gc.symbol)
          ),
          'min_resell_price', jsonb_build_object(
            'amount', ci.unit_minimum_sell_price_amount,
            'currency_id', ci.unit_minimum_sell_price_currency_id,
            'code', min_gc.code,
            'symbol', min_gc.symbol
          ),
          'line_totals', jsonb_build_object(
            'purchase_subtotal', ci.quantity * coalesce(ci.unit_sell_price_amount, 0),
            'resell_subtotal', ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
          ),
          'is_resell_below_floor', (
            coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
            and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
              < ci.unit_minimum_sell_price_amount
          )
        )
        order by ci.id
      ) as items,
      jsonb_build_object(
        'item_count', coalesce(sum(ci.quantity), 0),
        'line_count', count(ci.id),
        'purchase_subtotal', coalesce(sum(ci.quantity * coalesce(ci.unit_sell_price_amount, 0)), 0),
        'resell_subtotal', coalesce(sum(
          ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        ), 0),
        'estimated_profit', coalesce(sum(
          ci.quantity * (
            coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
            - coalesce(ci.unit_sell_price_amount, 0)
          )
        ), 0)
      ) as totals
    from public.shop_cart_items ci
    left join public.products p on p.id = ci.product_id
    left join public.global_currencies sell_gc on sell_gc.id = ci.unit_sell_price_currency_id
    left join public.global_currencies cust_gc on cust_gc.id = ci.customer_sell_price_currency_id
    left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
    where ci.cart_id = c.id
  ) items on true
  where c.id = v_cart_id;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."get_dropship_shop_cart"("p_shop_id" bigint) OWNER TO "postgres";

-- get_or_create_shop_cart

CREATE OR REPLACE FUNCTION "public"."get_or_create_shop_cart"("p_shop_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_cart_id bigint;
  v_result jsonb;
  v_perm record;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id
    and access.status = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  end if;

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_perm
  from public.get_shop_permissions_for_customer(p_shop_id)
  limit 1;

  v_can_see_buy_price_snapshot := coalesce(v_perm.can_see_buy_price, false);
  v_can_see_sell_price_snapshot := coalesce(v_perm.can_see_sell_price, false);

  select id into v_cart_id
  from public.shop_carts
  where tenant_id = v_tenant_id
    and shop_id = p_shop_id
    and customer_group_id = v_customer_group_id
    and status = 'active'
  order by id desc
  limit 1;

  if v_cart_id is null then
    insert into public.shop_carts (
      tenant_id, shop_id, customer_group_id,
      can_see_buy_price_snapshot, can_see_sell_price_snapshot, status,
      deduct_charges_from_margin, deduct_print_from_margin, deduct_packing_from_margin
    )
    values (
      v_tenant_id, p_shop_id, v_customer_group_id,
      v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot, 'active',
      (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      (select deduct_print_from_margin from public.shops where id = p_shop_id),
      (select deduct_packing_from_margin from public.shops where id = p_shop_id)
    )
    returning id into v_cart_id;
  else
    update public.shop_carts
    set
      deduct_charges_from_margin = (select deduct_charges_from_margin from public.shops where id = p_shop_id),
      deduct_print_from_margin = (select deduct_print_from_margin from public.shops where id = p_shop_id),
      deduct_packing_from_margin = (select deduct_packing_from_margin from public.shops where id = p_shop_id),
      can_see_buy_price_snapshot = v_can_see_buy_price_snapshot,
      can_see_sell_price_snapshot = v_can_see_sell_price_snapshot
    where id = v_cart_id;
  end if;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'can_see_buy_price_snapshot', v_can_see_buy_price_snapshot,
      'can_see_sell_price_snapshot', v_can_see_sell_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
      'deduct_print_from_margin', s.deduct_print_from_margin,
      'deduct_packing_from_margin', s.deduct_packing_from_margin
    ),
    'items', coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'listing_id', ci.listing_id,
            'grade_tag_id', ci.grade_tag_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'minimum_order_quantity', p.minimum_order_quantity,
            'unit_list_price_amount', case when v_can_see_buy_price_snapshot then ci.unit_list_price_amount else null end,
            'unit_list_price_currency_id', case when v_can_see_buy_price_snapshot then ci.unit_list_price_currency_id else null end,
            'unit_sell_price_amount', case when v_can_see_sell_price_snapshot then ci.unit_sell_price_amount else null end,
            'unit_sell_price_currency_id', case when v_can_see_sell_price_snapshot then ci.unit_sell_price_currency_id else null end,
            'unit_minimum_sell_price_amount', case when v_can_see_sell_price_snapshot then ci.unit_minimum_sell_price_amount else null end,
            'unit_minimum_sell_price_currency_id', case when v_can_see_sell_price_snapshot then ci.unit_minimum_sell_price_currency_id else null end,
            'customer_sell_price_amount', case when v_can_see_sell_price_snapshot then ci.customer_sell_price_amount else null end,
            'customer_sell_price_currency_id', case when v_can_see_sell_price_snapshot then ci.customer_sell_price_currency_id else null end,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        from public.shop_cart_items ci
        left join public.products p on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    ),
    'permissions', jsonb_build_object(
      'can_browse', coalesce(v_perm.can_browse, false),
      'can_see_buy_price', coalesce(v_perm.can_see_buy_price, false),
      'can_see_sell_price', coalesce(v_perm.can_see_sell_price, false),
      'can_see_resell_minimum_price', coalesce(v_perm.can_see_resell_minimum_price, false),
      'can_add_to_cart', coalesce(v_perm.can_add_to_cart, false),
      'can_place_order', coalesce(v_perm.can_place_order, false),
      'can_negotiate', coalesce(v_perm.can_negotiate, false),
      'can_view_quantity', coalesce(v_perm.can_view_quantity, false),
      'can_set_dropship_price', coalesce(v_perm.can_set_dropship_price, false)
    ),
    'currency', case
      when gc.id is not null then jsonb_build_object(
        'id', gc.id,
        'code', gc.code,
        'symbol', gc.symbol
      )
      else null
    end
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where c.id = v_cart_id;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."get_or_create_shop_cart"("p_shop_id" bigint) OWNER TO "postgres";

-- get_product_for_tenant

CREATE OR REPLACE FUNCTION "public"."get_product_for_tenant"("p_id" bigint, "p_tenant_id" bigint) RETURNS "public"."products"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.products;
  v_scope_tenant_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.products
  where id = p_id
    and tenant_id = v_scope_tenant_id;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."get_product_for_tenant"("p_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";

-- get_shop_catalog_product_for_customer

CREATE OR REPLACE FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_parent_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_display_quantity_add integer;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_can_see_catalog_price boolean;
  v_min_available_units integer;
  v_product jsonb;
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
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    display_quantity_add, vendor_filters, min_available_units
  into
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_display_quantity_add, v_vendor_filters, v_min_available_units
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop_tenant_id);
  v_display_quantity_add := coalesce(v_display_quantity_add, 6);
  v_can_see_catalog_price := coalesce(v_can_see_buy_price, false);

  if v_shop_type = 'vendor_catalog' then
    select jsonb_build_object(
      'product_id', p.id,
      'product_name', p.name,
      'product_image_url', p.image_url,
      'product_barcode', p.barcode,
      'product_code', p.product_code,
      'product_brand', p.brand,
      'product_category', p.category,
      'vendor_code', p.vendor_code,
      'is_available', p.is_available,
      'country_of_origin', p.country_of_origin,
      'expire_date', p.expire_date,
      'unit_price_amount', case when v_can_see_catalog_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_catalog_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_catalog_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_catalog_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
      'minimum_sell_price_amount', null,
      'minimum_sell_price_currency_id', null,
      'minimum_sell_price_currency_code', null,
      'minimum_sell_price_currency_symbol', null,
      'available_units', null,
      'global_stock_allocation_id', null,
      'global_stock_id', null,
      'minimum_order_quantity', p.minimum_order_quantity
    )
    into v_product
    from public.products p
    where p.id = p_product_id
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and p.tenant_id = v_parent_tenant_id
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
      and public.shop_catalog_meets_min_available_units(v_min_available_units, p.available_units)
    limit 1;
  else
    select jsonb_build_object(
      'product_id', row.product_id,
      'product_name', row.product_name,
      'product_image_url', row.product_image_url,
      'product_barcode', row.product_barcode,
      'product_code', row.product_code,
      'product_brand', row.product_brand,
      'product_category', row.product_category,
      'vendor_code', row.product_vendor_code,
      'is_available', row.product_is_available,
      'country_of_origin', row.country_of_origin,
      'expire_date', row.expire_date,
      'unit_price_amount', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.computed_sell_price
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.computed_sell_price
        else null
      end,
      'unit_price_currency_id', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.sell_price_currency_id
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.sell_price_currency_id
        else null
      end,
      'unit_price_currency_code', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'unit_price_currency_symbol', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'minimum_sell_price_amount', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_amount else null end,
      'minimum_sell_price_currency_id', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_currency_id else null end,
      'minimum_sell_price_currency_code', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select code from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'minimum_sell_price_currency_symbol', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select symbol from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'available_units', case
        when not v_can_view_quantity or not coalesce(row.listing_show_quantity, v_show_stock_quantity) then null
        when v_quantity_display_mode = 'original' then greatest(0, row.available_qty)
        when row.display_quantity_override is not null
          and not (row.display_quantity_override = 0 and row.available_qty > 0)
          then row.display_quantity_override
        else public.shop_padded_display_quantity(row.available_qty, v_display_quantity_add)
      end,
      'listing_id', row.listing_id,
      'stock_grade', case
        when row.grade_slug is not null then jsonb_build_object(
          'slug', row.grade_slug,
          'label', row.grade_label,
          'color', row.grade_color
        )
        else null
      end,
      'global_stock_allocation_id', row.global_stock_id,
      'global_stock_id', row.global_stock_id,
      'minimum_order_quantity', row.product_moq
    )
    into v_product
    from (
      select
        l.id as listing_id,
        l.global_stock_id,
        case
          when v_shop_type = 'fixed_price' and v_pricing_method = 'markup' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + v_markup_percentage / 100.0)
          when v_shop_type = 'fixed_price' and v_pricing_method = 'direct_cost' then
            coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
          else
            l.sell_price_amount
        end as computed_sell_price,
        l.sell_price_currency_id,
        l.minimum_sell_price_amount,
        l.minimum_sell_price_currency_id,
        l.show_quantity as listing_show_quantity,
        l.display_quantity_override,
        p.id as product_id,
        p.name as product_name,
        p.image_url as product_image_url,
        p.barcode as product_barcode,
        p.product_code as product_code,
        p.brand as product_brand,
        p.category as product_category,
        p.vendor_code as product_vendor_code,
        p.is_available as product_is_available,
        p.country_of_origin,
        p.expire_date,
        p.minimum_order_quantity as product_moq,
        public.shop_product_grade_available_units(
          v_shop_tenant_id,
          p.id,
          coalesce(l.grade_tag_id, gs.grade_tag_id)
        ) as available_qty,
        tg.slug as grade_slug,
        tg.name as grade_label,
        tg.color as grade_color
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      left join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.tags tg on tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
      where l.shop_id = v_shop_id
        and l.product_id = p_product_id
        and l.is_active = true
        and p.is_available = true
        and coalesce(p.hazardous, false) = false
        and not exists (
          select 1
          from public.shop_listing_group_hides h
          where h.listing_id = l.id
            and h.customer_group_id = public.current_customer_group_id(p_tenant_id)
        )
      order by l.id asc
      limit 1
    ) row;
  end if;

  if v_product is null then
    raise exception 'product not found';
  end if;

  return jsonb_build_object(
    'data', v_product,
    'meta', jsonb_build_object(
      'shop', jsonb_build_object(
        'id', v_shop_id,
        'name', v_shop_name,
        'slug', p_shop_slug,
        'shop_type', v_shop_type,
        'vendor_code', v_vendor_code,
        'order_mode', v_order_mode,
        'is_negotiable', v_is_negotiable,
        'show_stock_quantity', v_show_stock_quantity,
        'default_currency_id', v_default_currency_id,
        'is_active', v_is_active,
        'buy_currency_id', v_buy_currency_id,
        'sell_currency_id', v_sell_currency_id,
        'pricing_method', v_pricing_method,
        'markup_percentage', v_markup_percentage,
        'quantity_display_mode', v_quantity_display_mode,
        'vendor_filters', v_vendor_filters
      ),
      'permissions', jsonb_build_object(
        'can_browse', v_can_browse,
        'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
        'can_add_to_cart', v_can_add_to_cart,
        'can_place_order', v_can_place_order,
        'can_negotiate', v_can_negotiate,
        'can_view_quantity', v_can_view_quantity,
        'can_set_dropship_price', v_can_set_dropship_price
      )
    )
  );
end;
$$;


ALTER FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint) OWNER TO "postgres";

-- get_shop_order_for_staff

CREATE OR REPLACE FUNCTION "public"."get_shop_order_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_code text;
  v_sell_symbol text;
  v_buy_code text;
  v_buy_symbol text;
  v_customer_group_name text;
  v_item_count bigint;
  v_total_amount numeric;
  v_collection_source public.collection_source_type;
  v_items jsonb;
  v_invoices jsonb;
  v_shipments jsonb;
  v_order_json jsonb;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  select
    s.name,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.code,
    sell_gc.symbol,
    buy_gc.code,
    buy_gc.symbol
  into
    v_shop_name,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_code,
    v_sell_symbol,
    v_buy_code,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  v_collection_source := v_order.collection_source;
  if v_collection_source is null and v_order.global_invoice_id is not null then
    select inv.collection_source
    into v_collection_source
    from public.bills inv
    where inv.id = v_order.global_invoice_id;
  end if;
  if v_collection_source is null and v_order.is_prepaid_snapshot then
    v_collection_source := 'profile'::public.collection_source_type;
  end if;

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.staff_offer_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        soi.unit_list_price_amount
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  if v_order.global_invoice_id is not null then
    v_invoices := jsonb_build_array(jsonb_build_object('id', v_order.global_invoice_id));
  else
    v_invoices := '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('id', x.shipment_id) order by x.shipment_id),
    '[]'::jsonb
  )
  into v_shipments
  from (
    select distinct gship.id as shipment_id
    from public.shop_order_items soi
    join public.global_stocks gs on gs.id = soi.global_stock_id
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) x;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at,
        'product', jsonb_build_object(
          'id', soi.product_id,
          'sku', p.product_code,
          'brand', p.brand,
          'barcode', p.barcode,
          'weight_gm', p.product_weight,
          'package_weight_gm', p.package_weight,
          'minimum_order_quantity', coalesce(p.minimum_order_quantity, 1)
        ),
        'pricing', jsonb_build_object(
          'cost', jsonb_build_object(
            'amount', coalesce(soi.cost_price_amount, soi.unit_list_price_amount, p.reference_cost_amount),
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = coalesce(
                soi.cost_price_currency_id,
                soi.unit_list_price_currency_id
              )
              limit 1
            )
          ),
          'list', jsonb_build_object(
            'amount', soi.unit_list_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_list_price_currency_id
              limit 1
            )
          ),
          'sell', jsonb_build_object(
            'amount', soi.unit_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_sell_price_currency_id
              limit 1
            )
          ),
          'minimum_sell', jsonb_build_object(
            'amount', soi.unit_minimum_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_minimum_sell_price_currency_id
              limit 1
            )
          )
        ),
        'negotiation', jsonb_build_object(
          'status', soi.negotiation_status,
          'customer_decision', soi.customer_decision_status,
          'staff_offer', case
            when soi.staff_offer_amount is not null then jsonb_build_object(
              'amount', soi.staff_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.staff_offer_currency_id
                limit 1
              ),
              'at', soi.staff_offer_at,
              'is_manual', soi.is_first_offer_manual
            )
            else null
          end,
          'customer_offer', case
            when soi.customer_offer_amount is not null then jsonb_build_object(
              'amount', soi.customer_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.customer_offer_currency_id
                limit 1
              ),
              'at', soi.customer_counter_at
            )
            else null
          end,
          'final_offer', case
            when soi.final_price_amount is not null then jsonb_build_object(
              'amount', soi.final_price_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.final_price_currency_id
                limit 1
              ),
              'at', soi.final_offer_at,
              'is_manual', soi.is_final_offer_manual
            )
            else null
          end,
          'weight_kg', soi.weight_kg,
          'confirmed_quantity', soi.confirmed_quantity
        ),
        'fulfillment', jsonb_build_object(
          'returned', soi.returned_quantity,
          'procurement_pulled', soi.procurement_pulled
        ),
        'stock', case
          when soi.global_stock_id is not null then jsonb_build_object(
            'global_stock_id', soi.global_stock_id,
            'global_stock_allocation_id', soi.global_stock_allocation_id,
            'shipment_item_id', gsi.id,
            'shipment_id', gship.id
          )
          else null
        end
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  left join public.global_stocks gs on gs.id = soi.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  where soi.order_id = v_order.id;

  v_order_json := jsonb_build_object(
    'id', v_order.id,
    'tenant_id', v_order.tenant_id,
    'order_no', v_order.order_no,
    'name', v_order.name,
    'cart_id', v_order.cart_id,
    'created_by_email', v_order.created_by_email,
    'created_at', v_order.created_at,
    'updated_at', v_order.updated_at,
    'placed_at', v_order.placed_at,
    'fulfilled_at', v_order.fulfilled_at,
    'global_invoice_id', v_order.global_invoice_id,
    'collection_source', v_collection_source,
    'shop', jsonb_build_object(
      'id', v_order.shop_id,
      'name', v_shop_name,
      'type', v_order.shop_type_snapshot,
      'order_mode', v_order.order_mode_snapshot,
      'is_negotiable', v_order.is_negotiable_snapshot,
      'sell_currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end,
      'buy_currency', case
        when v_buy_currency_id is not null then jsonb_build_object(
          'id', v_buy_currency_id,
          'code', v_buy_code,
          'symbol', v_buy_symbol
        )
        else null
      end
    ),
    'customer', jsonb_build_object(
      'group_id', v_order.customer_group_id,
      'group_name', v_customer_group_name,
      'profile_id', v_order.profile_id
    ),
    'status', jsonb_build_object(
      'value', v_order.status,
      'negotiate_round', v_order.negotiate_round
    ),
    'rates', jsonb_build_object(
      'cargo', v_order.cargo_rate,
      'conversion', v_order.conversion_rate,
      'profit', v_order.profit_rate,
      'first_offer', v_order.first_offer_rate,
      'final_offer', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg
    ),
    'recipient', jsonb_build_object(
      'name', v_order.recipient_name,
      'phone', v_order.recipient_phone,
      'phone_secondary', v_order.recipient_phone_secondary,
      'address', v_order.shipping_address,
      'district', v_order.shipping_district,
      'thana', v_order.shipping_thana,
      'profile_id', v_order.recipient_profile_id,
      'delivery_instructions', v_order.delivery_instructions,
      'is_prepaid', v_order.is_prepaid_snapshot
    ),
    'charges', jsonb_build_object(
      'cod', v_order.cod_charge_amount,
      'delivery', v_order.delivery_charge_amount,
      'print', v_order.print_charge_amount,
      'packing', v_order.packing_charge_amount,
      'discount', v_order.discount_amount,
      'deduct_from_margin', jsonb_build_object(
        'charges', v_order.deduct_charges_from_margin,
        'cod', v_order.deduct_cod_from_margin,
        'delivery', v_order.deduct_delivery_from_margin,
        'print', v_order.deduct_print_from_margin,
        'packing', v_order.deduct_packing_from_margin
      )
    ),
    'totals', jsonb_build_object(
      'item_count', v_item_count,
      'amount', v_total_amount,
      'currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end
    ),
    'courier', jsonb_build_object(
      'service_id', v_order.courier_service_id,
      'name', v_order.courier_name,
      'awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'order_ref', v_order.courier_order_ref,
      'tracking_number', v_order.courier_tracking_number,
      'consignment_id', v_order.courier_consignment_id,
      'cost_amount', v_order.courier_cost_amount,
      'delivered_at', v_order.delivered_at,
      'returned_at', v_order.returned_at
    ),
    'pickup', jsonb_build_object(
      'sender_name', v_order.sender_name,
      'phone', v_order.pickup_phone,
      'address', v_order.pickup_address,
      'default_sender_name', v_order.default_sender_name,
      'default_phone', v_order.default_pickup_phone,
      'default_address', v_order.default_pickup_address
    ),
    'payout', jsonb_build_object(
      'account_type', v_order.payout_account_type,
      'account_info', v_order.payout_account_info,
      'default_account_type', v_order.default_payout_account_type,
      'default_account_info', v_order.default_payout_account_info,
      'settlement_status', v_order.payout_settlement_status,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_remittance_ref', v_order.courier_remittance_ref,
      'courier_bank_trx_id', v_order.courier_bank_trx_id
    ),
    'parcel', jsonb_build_object(
      'weight_band', v_order.package_weight_band,
      'item_category', v_order.item_category,
      'description', v_order.parcel_description,
      'delivery_zone', v_order.delivery_zone,
      'allow_open_box', v_order.allow_open_box,
      'driver_notes', v_order.driver_notes,
      'delivery_instruction_notes', v_order.delivery_instruction_notes
    ),
    'return_info', jsonb_build_object(
      'sub_state', v_order.return_sub_state,
      'override_reason', v_order.return_override_reason,
      'ref', v_order.return_ref,
      'charge_amount', v_order.return_charge_amount,
      'deduct_charge_from_middle_man', v_order.deduct_return_charge_from_middle_man,
      'replacement_of_order_id', v_order.replacement_of_order_id,
      'middle_man_reference', v_order.middle_man_reference
    ),
    'links', jsonb_build_object(
      'invoices', v_invoices,
      'shipments', v_shipments
    )
  );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$$;


ALTER FUNCTION "public"."get_shop_order_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";

-- get_shop_storefront_listing_price_calculation

CREATE OR REPLACE FUNCTION "public"."get_shop_storefront_listing_price_calculation"("p_shop_id" bigint, "p_listing_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_listing record;
  v_product_id bigint;
  v_grade_tag_id bigint;
  v_cost_currency_id bigint;
  v_result jsonb;
BEGIN
  SELECT
    s.tenant_id,
    s.shop_type,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage
  INTO
    v_tenant_id,
    v_shop_type,
    v_buy_currency_id,
    v_sell_currency_id,
    v_pricing_method,
    v_markup_percentage
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_tenant_id)
     AND NOT public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  SELECT
    l.id,
    l.shop_id,
    l.product_id,
    l.global_stock_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.display_quantity_override,
    l.is_active,
    l.is_price_locked,
    l.show_quantity,
    p.name AS product_name,
    p.product_code,
    p.image_url AS product_image_url,
    tg.slug AS grade_slug,
    tg.name AS grade_label,
    tg.color AS grade_color,
    gs.grade_tag_id
  INTO v_listing
  FROM public.shop_product_listings l
  JOIN public.products p ON p.id = l.product_id
  LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
  LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
  WHERE l.id = p_listing_id
    AND l.shop_id = p_shop_id;

  IF v_listing.id IS NULL THEN
    RAISE EXCEPTION 'listing not found';
  END IF;

  v_product_id := v_listing.product_id;
  v_grade_tag_id := coalesce(v_listing.grade_tag_id, public.default_stock_grade_tag_id());
  v_cost_currency_id := CASE
    WHEN v_shop_type = 'dropship'::public.shop_type_enum THEN v_buy_currency_id
    ELSE v_sell_currency_id
  END;

  WITH stock_lines AS (
    SELECT
      gship.id AS shipment_id,
      gship.name AS shipment_name,
      greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer AS quantity,
      coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)::numeric AS unit_cost_amount
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gsi.product_id = v_product_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      AND gs.parent_tenant_id = public.resolve_parent_tenant_id(v_tenant_id)
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = true)
      AND public.global_stock_atp_qty(gs.id) > 0
  ),
  shipment_agg AS (
    SELECT
      sl.shipment_id,
      sl.shipment_name,
      sum(sl.quantity)::integer AS quantity,
      CASE
        WHEN sum(sl.quantity) > 0 THEN round(sum(sl.quantity * sl.unit_cost_amount) / sum(sl.quantity), 4)
        ELSE 0::numeric
      END AS unit_cost_amount
    FROM stock_lines sl
    GROUP BY sl.shipment_id, sl.shipment_name
  ),
  totals AS (
    SELECT
      coalesce(sum(sa.quantity), 0)::integer AS total_quantity,
      CASE
        WHEN coalesce(sum(sa.quantity), 0) > 0 THEN round(
          (
            SELECT sum(sl.quantity * sl.unit_cost_amount)
            FROM stock_lines sl
          ) / sum(sa.quantity),
          4
        )
        ELSE 0::numeric
      END AS weighted_avg_cost
    FROM shipment_agg sa
  )
  SELECT
    jsonb_build_object(
      'listing',
      jsonb_build_object(
        'listing_id', v_listing.id,
        'shop_id', v_listing.shop_id,
        'product_id', v_product_id,
        'product_name', v_listing.product_name,
        'product_code', v_listing.product_code,
        'product_image_url', v_listing.product_image_url,
        'global_stock_id', v_listing.global_stock_id,
        'grade_tag_id', v_grade_tag_id,
        'stock_grade',
        CASE
          WHEN v_listing.grade_slug IS NOT NULL THEN jsonb_build_object(
            'slug', v_listing.grade_slug,
            'label', v_listing.grade_label,
            'color', v_listing.grade_color
          )
          ELSE NULL
        END,
        'is_active', v_listing.is_active,
        'is_price_locked', v_listing.is_price_locked
      ),
      'shipment_costs',
      coalesce(
        (
          SELECT jsonb_agg(
            jsonb_build_object(
              'shipment_id', sa.shipment_id,
              'shipment_no', 'SHP-' || sa.shipment_id::text,
              'shipment_name', sa.shipment_name,
              'quantity', sa.quantity,
              'unit_cost_amount', sa.unit_cost_amount
            )
            ORDER BY sa.shipment_name ASC, sa.shipment_id ASC
          )
          FROM shipment_agg sa
        ),
        '[]'::jsonb
      ),
      'totals',
      (
        SELECT jsonb_build_object(
          'total_quantity', t.total_quantity,
          'real_available_units', t.total_quantity,
          'weighted_avg_cost',
          jsonb_build_object(
            'amount', t.weighted_avg_cost,
            'currency_id', v_cost_currency_id,
            'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_cost_currency_id),
            'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_cost_currency_id)
          )
        )
        FROM totals t
      ),
      'pricing',
      jsonb_build_object(
        'display_quantity_override', v_listing.display_quantity_override,
        'suggested_display_quantity', coalesce((SELECT t.total_quantity FROM totals t), 0),
        'sell_price',
        jsonb_build_object(
          'amount', v_listing.sell_price_amount,
          'currency_id', v_listing.sell_price_currency_id,
          'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id),
          'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id)
        ),
        'suggested_sell_price',
        CASE
          WHEN v_shop_type = 'fixed_price'::public.shop_type_enum
            AND v_pricing_method = 'markup'
            AND (SELECT t.weighted_avg_cost FROM totals t) IS NOT NULL THEN jsonb_build_object(
            'amount',
            round((SELECT t.weighted_avg_cost FROM totals t) * (1 + coalesce(v_markup_percentage, 0) / 100.0), 4),
            'currency_id', v_listing.sell_price_currency_id,
            'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id),
            'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_listing.sell_price_currency_id)
          )
          ELSE NULL
        END,
        'resell_minimum_price',
        CASE
          WHEN v_shop_type = 'dropship'::public.shop_type_enum
            AND v_listing.minimum_sell_price_amount IS NOT NULL THEN jsonb_build_object(
            'amount', v_listing.minimum_sell_price_amount,
            'currency_id', v_listing.minimum_sell_price_currency_id,
            'code', (SELECT gc.code FROM public.global_currencies gc WHERE gc.id = v_listing.minimum_sell_price_currency_id),
            'symbol', (SELECT gc.symbol FROM public.global_currencies gc WHERE gc.id = v_listing.minimum_sell_price_currency_id)
          )
          ELSE NULL
        END
      ),
      'shop',
      jsonb_build_object(
        'id', p_shop_id,
        'shop_type', v_shop_type,
        'pricing_method', v_pricing_method,
        'markup_percentage', v_markup_percentage,
        'sell_currency_id', v_sell_currency_id,
        'buy_currency_id', v_buy_currency_id
      )
    )
  INTO v_result;

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."get_shop_storefront_listing_price_calculation"("p_shop_id" bigint, "p_listing_id" bigint) OWNER TO "postgres";

-- list_allocated_stock_for_shop

CREATE OR REPLACE FUNCTION "public"."list_allocated_stock_for_shop"("p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 200, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
  v_limit integer;
  v_offset integer;
BEGIN
  SELECT s.tenant_id INTO v_shop_tenant_id
  FROM public.shops s
  WHERE s.id = p_shop_id
    AND s.deleted_at IS NULL;

  IF v_shop_tenant_id IS NULL THEN
    RAISE EXCEPTION 'shop not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_shop_tenant_id)
     AND NOT public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_shop_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));
  v_offset := greatest(0, coalesce(p_offset, 0));

  SELECT count(DISTINCT gs.id)
  INTO v_total_count
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
  WHERE gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = true)
    AND (
      p_search IS NULL
      OR p_search = ''
      OR (
        gsi.name ILIKE '%' || p_search || '%'
        OR gsi.product_code ILIKE '%' || p_search || '%'
        OR gsi.barcode ILIKE '%' || p_search || '%'
        OR gship.name ILIKE '%' || p_search || '%'
        OR tg.name ILIKE '%' || p_search || '%'
      )
    );

  SELECT coalesce(jsonb_agg(row_json ORDER BY sort_id DESC), '[]'::jsonb)
  INTO v_data
  FROM (
    SELECT
      gs.id AS sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'image_url', gsi.image_url,
        'product_brand', p.brand,
        'product_category', p.category,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'stock_grade', CASE
          WHEN tg.slug IS NOT NULL THEN jsonb_build_object(
            'slug', tg.slug,
            'label', tg.name,
            'color', tg.color
          )
          ELSE NULL
        END,
        'is_listed_on_shop', EXISTS (
          SELECT 1
          FROM public.shop_product_listings spl
          WHERE spl.shop_id = p_shop_id
            AND spl.global_stock_id = gs.id
        ),
        'listing_id', (
          SELECT spl.id
          FROM public.shop_product_listings spl
          WHERE spl.shop_id = p_shop_id
            AND spl.global_stock_id = gs.id
          LIMIT 1
        )
      ) AS row_json
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    JOIN public.products p ON p.id = gsi.product_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
    WHERE gs.parent_tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = true)
      AND (
        p_search IS NULL
        OR p_search = ''
        OR (
          gsi.name ILIKE '%' || p_search || '%'
          OR gsi.product_code ILIKE '%' || p_search || '%'
          OR gsi.barcode ILIKE '%' || p_search || '%'
          OR gship.name ILIKE '%' || p_search || '%'
          OR tg.name ILIKE '%' || p_search || '%'
        )
      )
    ORDER BY gs.id DESC
    LIMIT v_limit
    OFFSET v_offset
  ) q;

  RETURN jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil(v_total_count::numeric / v_limit::numeric))
    )
  );
END;
$$;


ALTER FUNCTION "public"."list_allocated_stock_for_shop"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- list_allocations_for_shop_pick

CREATE OR REPLACE FUNCTION "public"."list_allocations_for_shop_pick"("p_tenant_id" bigint, "p_shop_id" bigint) RETURNS TABLE("allocation_id" bigint, "stock_id" bigint, "product_id" bigint, "product_name" "text", "product_image_url" "text", "product_barcode" "text", "product_code" "text", "product_brand" "text", "product_category" "text", "allocated_quantity" integer, "minimum_sell_price_amount" numeric, "minimum_sell_price_currency_id" bigint, "unit_cost_amount" numeric, "shipment_item_id" bigint, "shipment_id" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  -- Caller must be member of this tenant
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select
    gsa.id as allocation_id,
    gsa.stock_id,
    gsi.product_id,
    p.name as product_name,
    p.image_url as product_image_url,
    p.barcode as product_barcode,
    p.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gsa.quantity as allocated_quantity,
    coalesce(
      public.calculate_landed_unit_cost(gs.shipment_item_id),
      gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0),
      0.00
    )::numeric as minimum_sell_price_amount,
    (select default_currency_id from public.shops where id = p_shop_id) as minimum_sell_price_currency_id,
    coalesce(
      public.calculate_landed_unit_cost(gs.shipment_item_id),
      gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0),
      0.00
    )::numeric as unit_cost_amount,
    gs.shipment_item_id,
    gsi.shipment_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  join public.products p on p.id = gsi.product_id
  where gsa.child_tenant_id = p_tenant_id
    and not exists (
      select 1 from public.shop_product_listings spl
      where spl.shop_id = p_shop_id
        and spl.global_stock_allocation_id = gsa.id
    )
  order by p.name asc;
end;
$$;


ALTER FUNCTION "public"."list_allocations_for_shop_pick"("p_tenant_id" bigint, "p_shop_id" bigint) OWNER TO "postgres";

-- list_catalog_refresh_log

CREATE OR REPLACE FUNCTION "public"."list_catalog_refresh_log"("p_tenant_id" bigint, "p_limit" integer DEFAULT 50) RETURNS TABLE("id" bigint, "tenant_id" bigint, "source" "text", "event_kind" "text", "source_url" "text", "file_name" "text", "ran_at" timestamp with time zone, "products_updated" integer, "duration_seconds" integer)
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

-- list_child_procurement_lines

CREATE OR REPLACE FUNCTION "public"."list_child_procurement_lines"("p_tenant_id" bigint, "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0) RETURNS TABLE("source_type" "text", "source_id" bigint, "child_tenant_id" bigint, "child_tenant_name" "text", "name" "text", "product_id" bigint, "quantity" integer, "cost_bdt" numeric, "price_gbp" numeric, "image_url" "text", "barcode" "text", "product_code" "text", "reference_label" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
BEGIN
  IF NOT public.user_can_manage_parent_tenant(p_tenant_id) THEN
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
    WHERE t.parent_id = p_tenant_id
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
      AND t.parent_id = p_tenant_id
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


ALTER FUNCTION "public"."list_child_procurement_lines"("p_tenant_id" bigint, "p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- list_global_invoice_items

CREATE OR REPLACE FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) RETURNS TABLE("id" bigint, "invoice_id" bigint, "global_stock_id" bigint, "name_snapshot" "text", "quantity" numeric, "sell_price_amount" numeric, "recipient_price_amount" numeric, "line_face_total_amount" numeric, "line_discount_amount" numeric, "line_total_amount" numeric, "return_quantity" numeric, "image_url" "text", "shipment_id" bigint, "shipment_item_id" bigint, "purchase_price" numeric, "product_weight" numeric, "package_weight" numeric, "ordered_quantity" integer, "shipment_type" "text", "product_conversion_rate" numeric, "cargo_conversion_rate" numeric, "cargo_rate" numeric, "received_weight" numeric, "transaction_rate" numeric, "available_atp" numeric, "unit_cost_price" numeric)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_issued_by bigint;
  v_invoice_status public.global_invoice_status;
begin
  select tenant_id, issued_by_tenant_id, invoice_status
  into v_parent_tenant_id, v_issued_by, v_invoice_status
  from public.bills
  where public.bills.id = p_invoice_id;

  if not found then
    raise exception 'Invoice with ID % not found', p_invoice_id;
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or public.has_active_tenant_membership(v_issued_by)
    or public.membership_has_module_action(v_issued_by, 'global_invoice', 'view')
  ) then
    raise exception 'Access denied for invoice with ID %', p_invoice_id;
  end if;

  return query
  select
    gii.id,
    gii.invoice_id,
    gii.global_stock_id,
    gii.name_snapshot,
    gii.quantity,
    gii.sell_price_amount,
    nullif(gii.line_meta->>'resell_price_amount', '')::numeric as recipient_price_amount,
    (gii.quantity * nullif(gii.line_meta->>'resell_price_amount', '')::numeric) as line_face_total_amount,
    gii.line_discount_amount,
    gii.line_total_amount,
    gii.return_quantity,
    case
      when gii.line_kind = 'stock'::text then coalesce(gsi.image_url, p.image_url)
      else null::text
    end as image_url,
    gsi.shipment_id,
    gsi.id as shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text as shipment_type,
    null::numeric as product_conversion_rate,
    null::numeric as cargo_conversion_rate,
    null::numeric as cargo_rate,
    gship.received_weight,
    null::numeric as transaction_rate,
    case
      when gii.global_stock_id is null then 0::numeric
      when v_invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status)
        then (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0) + gii.quantity)::numeric
      else (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0))::numeric
    end as available_atp,
    coalesce(gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric as unit_cost_price
  from public.bill_lines gii
  left join public.global_stocks gs on gs.id = gii.global_stock_id
  left join public.global_shipment_items gsi
    on gsi.id = coalesce(gii.shipment_item_id, gs.shipment_item_id)
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.products p on p.id = gii.product_id
  where gii.invoice_id = p_invoice_id
  order by gii.id;
end;
$$;


ALTER FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_shipment_cost_entries" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "amount" numeric NOT NULL,
    "currency_id" bigint,
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "section_id" bigint,
    "cost_bucket" "public"."global_shipment_cost_bucket" NOT NULL,
    "cost_component" "public"."global_shipment_cost_component" NOT NULL,
    "is_capitalizable" boolean DEFAULT true NOT NULL,
    "description" "text",
    CONSTRAINT "global_shipment_cost_entries_amount_check" CHECK (("amount" >= (0)::numeric))
);


ALTER TABLE "public"."global_shipment_cost_entries" OWNER TO "postgres";


COMMENT ON COLUMN "public"."global_shipment_cost_entries"."cost_bucket" IS 'Operational category: material, freight, customs, handling, finance, other.';



COMMENT ON COLUMN "public"."global_shipment_cost_entries"."cost_component" IS 'Voucher line axis: subtotal, carriage, vat_tax, misc.';



COMMENT ON COLUMN "public"."global_shipment_cost_entries"."is_capitalizable" IS 'When true, amount flows into landed unit cost (BDT stamp). When false, P&L / local opex only.';

-- list_procurement_demand_group_items

CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_group_items"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_cursor_source_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_items jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_source_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;

  if v_doc_type not in ('shop_order', 'pbc_costing_file') then
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      nullif(trim(coalesce(p.vendor_code, '')), '') as vendor_code,
      nullif(trim(coalesce(p.market_code, '')), '') as market_code,
      nullif(trim(coalesce(p.brand, '')), '') as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where v_doc_type = 'shop_order'
      and o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog'
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      coalesce(
        nullif(trim(coalesce(pci.vendor_code, '')), ''),
        nullif(trim(coalesce(p.vendor_code, '')), '')
      ) as vendor_code,
      coalesce(
        nullif(trim(coalesce(pci.market_code, '')), ''),
        nullif(trim(coalesce(p.market_code, '')), '')
      ) as market_code,
      coalesce(
        nullif(trim(coalesce(pci.brand, '')), ''),
        nullif(trim(coalesce(p.brand, '')), '')
      ) as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.products p on p.id = pci.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where v_doc_type = 'pbc_costing_file'
      and f.id = p_document_id
      and f.profile_id is not null
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where (
      dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
    )
      and (
        v_search is null
        or dl.name ilike '%' || v_search || '%'
        or coalesce(dl.barcode, '') ilike '%' || v_search || '%'
        or coalesce(dl.product_code, '') ilike '%' || v_search || '%'
      )
      and (
        p_cursor_source_id is null
        or dl.source_id > p_cursor_source_id
      )
  ),
  paged as (
    select el.*
    from eligible_lines el
    order by el.source_id
    limit v_limit + 1
  ),
  page_count as (
    select count(*)::integer as n from paged
  ),
  page_rows as (
    select p.*
    from paged p
    order by p.source_id
    limit v_limit
  ),
  item_json as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'source_type', row.source_type,
          'source_id', row.source_id,
          'product_id', row.product_id,
          'name', row.name,
          'image_url', row.image_url,
          'barcode', nullif(row.barcode, ''),
          'product_code', nullif(row.product_code, ''),
          'vendor_code', row.vendor_code,
          'market_code', row.market_code,
          'brand', row.brand,
          'category', row.category,
          'available_units', row.available_units,
          'languages', row.languages,
          'country_of_origin', row.country_of_origin,
          'quantity', row.quantity,
          'need_quantity', row.quantity,
          'preorder_demand_id', row.preorder_demand_id,
          'vendor_id', row.vendor_id,
          'placed_quantity', row.placed_quantity,
          'delivered_quantity', row.delivered_quantity,
          'remaining_quantity', row.quantity - row.placed_quantity,
          'remaining_to_deliver', greatest(row.quantity - row.delivered_quantity, 0),
          'stock_picks', row.stock_picks
        )
        order by row.source_id
      ),
      '[]'::jsonb
    ) as items
    from page_rows row
  ),
  cursor_row as (
    select p.source_id
    from paged p
    order by p.source_id
    offset v_limit
    limit 1
  )
  select
    ij.items,
    pc.n,
    cr.source_id
  into v_items, v_n, v_last_source_id
  from item_json ij
  cross join page_count pc
  left join cursor_row cr on true;

  if v_n > v_limit then
    v_has_more := true;
    v_next_cursor := jsonb_build_object('source_id', v_last_source_id);
  end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'document_type', v_doc_type,
      'document_id', p_document_id,
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    ),
    'items', v_items
  );
end;
$$;


ALTER FUNCTION "public"."list_procurement_demand_group_items"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_search" "text", "p_limit" integer, "p_cursor_source_id" bigint) OWNER TO "postgres";

-- list_procurement_demand_groups

CREATE OR REPLACE FUNCTION "public"."list_procurement_demand_groups"("p_tenant_id" bigint, "p_procurement_status" "text" DEFAULT 'procuring'::"text", "p_search" "text" DEFAULT NULL::"text", "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
      and (p_child_tenant_id is null or t.id = p_child_tenant_id)
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      coalesce(pd.profile_id, o.profile_id) as profile_id,
      pr.name as profile_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id,
      nullif(trim(o.order_no), '') as shop_order_no,
      nullif(trim(o.order_no), '') as document_name
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    left join public.profiles pr on pr.id = coalesce(pd.profile_id, o.profile_id)
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
        or coalesce(pr.name, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      coalesce(pd.profile_id, f.profile_id) as profile_id,
      pr.name as profile_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id,
      null::text as shop_order_no,
      nullif(trim(coalesce(f.name, '')), '') as document_name
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    left join public.profiles pr on pr.id = coalesce(pd.profile_id, f.profile_id)
    where f.profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
        or coalesce(pr.name, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      max(el.profile_id) as profile_id,
      max(el.profile_name) as profile_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      max(el.document_name) as document_name,
      max(el.shop_order_no) as shop_order_no,
      jsonb_agg(
        jsonb_build_object(
          'source_type', el.source_type,
          'source_id', el.source_id,
          'product_id', el.product_id,
          'name', el.name,
          'image_url', el.image_url,
          'barcode', nullif(el.barcode, ''),
          'product_code', nullif(el.product_code, ''),
          'quantity', el.quantity,
          'need_quantity', el.quantity,
          'preorder_demand_id', el.preorder_demand_id,
          'vendor_id', el.vendor_id,
          'placed_quantity', el.placed_quantity,
          'delivered_quantity', el.delivered_quantity,
          'remaining_quantity', el.quantity - el.placed_quantity,
          'remaining_to_deliver', greatest(el.quantity - el.delivered_quantity, 0),
          'stock_picks', el.stock_picks
        )
        order by el.source_id
      ) as items,
      count(*)::integer as item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups
    from grouped g
    order by g.document_type, g.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_name', p.document_name,
          'shop_order_no', p.shop_order_no,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'profile_id', p.profile_id,
          'profile_name', p.profile_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'item_count', p.item_count,
          'items', p.items
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;


ALTER FUNCTION "public"."list_procurement_demand_groups"("p_tenant_id" bigint, "p_procurement_status" "text", "p_search" "text", "p_child_tenant_id" bigint, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- list_procurement_fulfill_groups

CREATE OR REPLACE FUNCTION "public"."list_procurement_fulfill_groups"("p_tenant_id" bigint, "p_procurement_status" "text" DEFAULT 'procuring'::"text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      coalesce(pd.profile_id, o.profile_id) as profile_id,
      pr.name as profile_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id,
      nullif(trim(o.order_no), '') as shop_order_no,
      nullif(trim(o.order_no), '') as document_name
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    left join public.profiles pr on pr.id = coalesce(pd.profile_id, o.profile_id)
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
        or coalesce(pr.name, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      coalesce(pd.profile_id, f.profile_id) as profile_id,
      pr.name as profile_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id,
      null::text as shop_order_no,
      nullif(trim(coalesce(f.name, '')), '') as document_name
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    left join public.profiles pr on pr.id = coalesce(pd.profile_id, f.profile_id)
    where f.profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
        or coalesce(pr.name, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      max(el.profile_id) as profile_id,
      max(el.profile_name) as profile_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      max(el.document_name) as document_name,
      max(el.shop_order_no) as shop_order_no,
      count(*)::integer as item_count,
      count(*) filter (where el.quantity > el.delivered_quantity)::integer as unallocated_item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  enriched as (
    select
      g.*,
      inv.invoice_status,
      case
        when g.invoice_id is null then false
        else public.preorder_demand_invoice_items_stale(g.document_type, g.document_id, g.invoice_id)
      end as invoice_stale
    from grouped g
    left join public.bills inv on inv.id = g.invoice_id
  ),
  paged as (
    select e.*, count(*) over ()::integer as total_groups
    from enriched e
    order by e.document_type, e.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_name', p.document_name,
          'shop_order_no', p.shop_order_no,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'profile_id', p.profile_id,
          'profile_name', p.profile_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'invoice_status', p.invoice_status,
          'invoice_stale', coalesce(p.invoice_stale, false),
          'item_count', p.item_count,
          'unallocated_item_count', p.unallocated_item_count
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$$;


ALTER FUNCTION "public"."list_procurement_fulfill_groups"("p_tenant_id" bigint, "p_procurement_status" "text", "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- list_procurement_shop_order_lines

CREATE OR REPLACE FUNCTION "public"."list_procurement_shop_order_lines"("p_tenant_id" bigint, "p_child_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0) RETURNS TABLE("source_type" "text", "source_id" bigint, "child_tenant_id" bigint, "child_tenant_name" "text", "name" "text", "product_id" bigint, "quantity" integer, "cost_bdt" numeric, "price_gbp" numeric, "image_url" "text", "barcode" "text", "product_code" "text", "reference_label" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_parent_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select
    'shop_order_item'::text as source_type,
    oi.id as source_id,
    o.tenant_id as child_tenant_id,
    t.name as child_tenant_name,
    oi.name,
    oi.product_id,
    greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
    case when gc.code = 'BDT' then oi.final_price_amount else null::numeric end as cost_bdt,
    case when gc.code = 'GBP' then oi.final_price_amount else null::numeric end as price_gbp,
    oi.image_url,
    p.barcode,
    p.product_code,
    ('Shop Order #' || o.order_no || ' — ' || o.name) as reference_label
  from public.shop_order_items oi
  inner join public.shop_orders o on o.id = oi.order_id
  inner join public.tenants t on t.id = o.tenant_id
  left join public.products p on p.id = oi.product_id
  left join public.global_currencies gc on gc.id = oi.final_price_currency_id
  where o.status = 'placed'
    and oi.procurement_pulled = false
    and o.shop_type_snapshot = 'vendor_catalog'
    and t.parent_id = p_tenant_id
    and (p_child_tenant_id is null or o.tenant_id = p_child_tenant_id)
    and (
      p_search is null or trim(p_search) = ''
      or oi.name ilike '%' || trim(p_search) || '%'
      or o.name ilike '%' || trim(p_search) || '%'
    )
  order by t.name, oi.id
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."list_procurement_shop_order_lines"("p_tenant_id" bigint, "p_child_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- list_products_paginated

CREATE OR REPLACE FUNCTION "public"."list_products_paginated"("p_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_search_field" "text" DEFAULT 'name'::"text", "p_category" "text" DEFAULT NULL::"text", "p_brand" "text" DEFAULT NULL::"text", "p_vendor_code" "text" DEFAULT NULL::"text", "p_market_code" "text" DEFAULT NULL::"text", "p_is_available" boolean DEFAULT NULL::boolean, "p_sort_dir" "text" DEFAULT 'asc'::"text", "p_limit" integer DEFAULT 20, "p_cursor_name" "text" DEFAULT NULL::"text", "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_limit integer;
  v_sort_dir text;
  v_search_field text;
  v_scope_tenant_id bigint;
  v_rows jsonb;
  v_n integer;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_name text;
  v_last_id bigint;
  v_tokens text[] := '{}'::text[];
  v_cursor_name text;
begin
  if p_tenant_id is not null and not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_scope_tenant_id := case
    when p_tenant_id is null then null
    else public.resolve_parent_tenant_id(p_tenant_id)
  end;

  v_limit := greatest(1, least(coalesce(p_limit, 20), 200));

  v_sort_dir := lower(trim(coalesce(p_sort_dir, 'asc')));
  if v_sort_dir not in ('asc', 'desc') then
    v_sort_dir := 'asc';
  end if;

  v_search_field := lower(trim(coalesce(p_search_field, 'name')));
  if v_search_field not in ('name', 'barcode', 'product_code', 'id') then
    v_search_field := 'name';
  end if;

  if v_search_field = 'name' and p_search is not null and trim(p_search) <> '' then
    select coalesce(array_agg(tok), '{}'::text[])
    into v_tokens
    from unnest(regexp_split_to_array(trim(p_search), E'[^[:alnum:]]+')) as tok
    where tok <> ''
      and length(tok) >= 2
      and lower(tok) not in ('a', 'an', 'the', 'and', 'or', 'of', 'for', 'to', 'in', 'on');

    if cardinality(v_tokens) = 0 then
      v_tokens := array[trim(p_search)];
    end if;
  end if;

  v_cursor_name := coalesce(p_cursor_name, '');

  if v_sort_dir = 'asc' then
    select coalesce(jsonb_agg(to_jsonb(q) ORDER BY q._sort_name ASC, q.id ASC), '[]'::jsonb)
    into v_rows
    from (
      select
        p.*,
        coalesce(p.name, '') as _sort_name
      from public.products p
      where
        (v_scope_tenant_id is null or p.tenant_id = v_scope_tenant_id)
        and (p_search is null or trim(p_search) = '' or (
          (v_search_field = 'name' and (
            cardinality(v_tokens) = 0
            or (
              select coalesce(bool_and(
                coalesce(p.name, '') ilike ('%' || t || '%')
                or coalesce(p.brand, '') ilike ('%' || t || '%')
              ), true)
              from unnest(v_tokens) t
            )
          ))
          or (v_search_field = 'barcode' and p.barcode ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'product_code' and p.product_code ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'id' and trim(p_search) ~ '^[0-9]+$' and p.id = trim(p_search)::bigint)
        ))
        and (p_category is null or trim(p_category) = '' or lower(coalesce(p.category, '')) = lower(trim(p_category)))
        and (p_brand is null or trim(p_brand) = '' or lower(coalesce(p.brand, '')) = lower(trim(p_brand)))
        and (p_vendor_code is null or trim(p_vendor_code) = '' or upper(coalesce(p.vendor_code, '')) = upper(trim(p_vendor_code)))
        and (p_market_code is null or trim(p_market_code) = '' or upper(coalesce(p.market_code, '')) = upper(trim(p_market_code)))
        and (p_is_available is null or p.is_available = p_is_available)
        and (
          p_cursor_id is null
          or (coalesce(p.name, ''), p.id) > (v_cursor_name, p_cursor_id)
        )
      order by coalesce(p.name, '') asc, p.id asc
      limit v_limit + 1
    ) q;
  else
    select coalesce(jsonb_agg(to_jsonb(q) ORDER BY q._sort_name DESC, q.id DESC), '[]'::jsonb)
    into v_rows
    from (
      select
        p.*,
        coalesce(p.name, '') as _sort_name
      from public.products p
      where
        (v_scope_tenant_id is null or p.tenant_id = v_scope_tenant_id)
        and (p_search is null or trim(p_search) = '' or (
          (v_search_field = 'name' and (
            cardinality(v_tokens) = 0
            or (
              select coalesce(bool_and(
                coalesce(p.name, '') ilike ('%' || t || '%')
                or coalesce(p.brand, '') ilike ('%' || t || '%')
              ), true)
              from unnest(v_tokens) t
            )
          ))
          or (v_search_field = 'barcode' and p.barcode ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'product_code' and p.product_code ilike ('%' || trim(p_search) || '%'))
          or (v_search_field = 'id' and trim(p_search) ~ '^[0-9]+$' and p.id = trim(p_search)::bigint)
        ))
        and (p_category is null or trim(p_category) = '' or lower(coalesce(p.category, '')) = lower(trim(p_category)))
        and (p_brand is null or trim(p_brand) = '' or lower(coalesce(p.brand, '')) = lower(trim(p_brand)))
        and (p_vendor_code is null or trim(p_vendor_code) = '' or upper(coalesce(p.vendor_code, '')) = upper(trim(p_vendor_code)))
        and (p_market_code is null or trim(p_market_code) = '' or upper(coalesce(p.market_code, '')) = upper(trim(p_market_code)))
        and (p_is_available is null or p.is_available = p_is_available)
        and (
          p_cursor_id is null
          or (coalesce(p.name, ''), p.id) < (v_cursor_name, p_cursor_id)
        )
      order by coalesce(p.name, '') desc, p.id desc
      limit v_limit + 1
    ) q;
  end if;

  v_n := jsonb_array_length(v_rows);
  if v_n > v_limit then
    v_has_more := true;
    select elem->>'name', (elem->>'id')::bigint
    into v_last_name, v_last_id
    from jsonb_array_elements(v_rows) with ordinality as t(elem, ord)
    where ord = v_limit;

    v_next_cursor := jsonb_build_object(
      'name', coalesce(v_last_name, ''),
      'id', v_last_id
    );

    select coalesce(jsonb_agg(elem - '_sort_name' order by ord), '[]'::jsonb)
    into v_rows
    from (
      select (elem - '_sort_name') as elem, ord
      from jsonb_array_elements(v_rows) with ordinality as t(elem, ord)
      where ord <= v_limit
    ) trimmed;
  else
    select coalesce(jsonb_agg(elem - '_sort_name' order by ord), '[]'::jsonb)
    into v_rows
    from (
      select (elem - '_sort_name') as elem, ord
      from jsonb_array_elements(v_rows) with ordinality as t(elem, ord)
    ) trimmed;
  end if;

  return jsonb_build_object(
    'data', coalesce(v_rows, '[]'::jsonb),
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'limit', v_limit
    )
  );
end;
$_$;


ALTER FUNCTION "public"."list_products_paginated"("p_tenant_id" bigint, "p_search" "text", "p_search_field" "text", "p_category" "text", "p_brand" "text", "p_vendor_code" "text", "p_market_code" "text", "p_is_available" boolean, "p_sort_dir" "text", "p_limit" integer, "p_cursor_name" "text", "p_cursor_id" bigint) OWNER TO "postgres";

-- list_related_shop_catalog_products_for_customer

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
  v_min_available_units integer;
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
    id, tenant_id, shop_type, vendor_code, is_active, vendor_filters, min_available_units
  into
    v_shop_id, v_shop_tenant_id, v_shop_type, v_vendor_code, v_is_active, v_vendor_filters, v_min_available_units
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
    and p.tenant_id = v_parent_tenant_id
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
    and public.shop_catalog_meets_min_available_units(v_min_available_units, p.available_units)
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
          and p.tenant_id = v_parent_tenant_id
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
          and public.shop_catalog_meets_min_available_units(v_min_available_units, p.available_units)
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


ALTER FUNCTION "public"."list_related_shop_catalog_products_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_limit" integer) OWNER TO "postgres";

-- list_shop_customer_stocks

CREATE OR REPLACE FUNCTION "public"."list_shop_customer_stocks"("p_shop_id" bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint) RETURNS TABLE("id" bigint, "shop_id" bigint, "customer_group_id" bigint, "product_id" bigint, "product_name" "text", "product_code" "text", "item_label" "text", "quantity_on_hand" integer, "updated_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop public.shops%rowtype;
begin
  select s.* into v_shop
  from public.shops s
  where s.id = p_shop_id;

  if v_shop.id is null then
    raise exception 'shop not found';
  end if;

  if not public.is_tenant_staff(v_shop.tenant_id) then
    raise exception 'access denied';
  end if;

  return query
  select
    scs.id,
    scs.shop_id,
    scs.customer_group_id,
    scs.product_id,
    coalesce(p.name, scs.item_label) as product_name,
    p.product_code,
    scs.item_label,
    scs.quantity_on_hand,
    scs.updated_at
  from public.shop_customer_stocks scs
  left join public.products p on p.id = scs.product_id
  where scs.shop_id = p_shop_id
    and (
      p_customer_group_id is null
      or scs.customer_group_id = p_customer_group_id
    )
  order by coalesce(p.name, scs.item_label), scs.id;
end;
$$;


ALTER FUNCTION "public"."list_shop_customer_stocks"("p_shop_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

-- list_shop_listing_group_visibility

CREATE OR REPLACE FUNCTION "public"."list_shop_listing_group_visibility"("p_shop_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_data jsonb;
begin
  select s.tenant_id, s.shop_type
  into v_tenant_id, v_shop_type
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if v_shop_type <> 'dropship' then
    return jsonb_build_object('data', '[]'::jsonb);
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'listing_id', l.id,
        'product_id', p.id,
        'product_name', p.name,
        'product_image_url', p.image_url,
        'is_visible', h.listing_id is null
      )
      order by p.name asc, l.id asc
    ),
    '[]'::jsonb
  )
  into v_data
  from public.shop_product_listings l
  join public.products p on p.id = l.product_id
  left join public.shop_listing_group_hides h
    on h.listing_id = l.id
   and h.customer_group_id = p_customer_group_id
  where l.shop_id = p_shop_id
    and l.is_active = true;

  return jsonb_build_object('data', v_data);
end;
$$;


ALTER FUNCTION "public"."list_shop_listing_group_visibility"("p_shop_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

-- list_shop_product_listings

CREATE OR REPLACE FUNCTION "public"."list_shop_product_listings"("p_shop_id" bigint) RETURNS TABLE("id" bigint, "tenant_id" bigint, "shop_id" bigint, "global_stock_allocation_id" bigint, "global_stock_id" bigint, "product_id" bigint, "sell_price_amount" numeric, "sell_price_currency_id" bigint, "minimum_sell_price_amount" numeric, "minimum_sell_price_currency_id" bigint, "show_quantity" boolean, "display_quantity_override" integer, "is_active" boolean, "created_at" timestamp with time zone, "updated_at" timestamp with time zone, "product_name" "text", "product_image_url" "text", "product_barcode" "text", "product_code" "text", "product_brand" "text", "product_category" "text", "allocated_quantity" integer, "available_to_sell" integer, "unit_cost_amount" numeric, "shipment_item_id" bigint, "shipment_id" bigint)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.tenant_id,
    l.shop_id,
    l.global_stock_allocation_id,
    coalesce(l.global_stock_id, gs.id) as global_stock_id,
    l.product_id,
    l.sell_price_amount,
    l.sell_price_currency_id,
    l.minimum_sell_price_amount,
    l.minimum_sell_price_currency_id,
    l.show_quantity,
    l.display_quantity_override,
    l.is_active,
    l.created_at,
    l.updated_at,
    gsi.name as product_name,
    gsi.image_url as product_image_url,
    gsi.barcode as product_barcode,
    gsi.product_code as product_code,
    p.brand as product_brand,
    p.category as product_category,
    gs.quantity::integer as allocated_quantity,
    greatest(0, floor(public.global_stock_atp_qty(coalesce(l.global_stock_id, gs.id))))::integer as available_to_sell,
    coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0.00)::numeric as unit_cost_amount,
    gs.shipment_item_id as shipment_item_id,
    gsi.shipment_id as shipment_id
  from public.shop_product_listings l
  left join public.products p on p.id = l.product_id
  left join public.global_stocks gs on gs.id = l.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where l.shop_id = p_shop_id
  order by gsi.name asc;
end;
$$;


ALTER FUNCTION "public"."list_shop_product_listings"("p_shop_id" bigint) OWNER TO "postgres";

-- list_shop_storefront_listings_for_admin

CREATE OR REPLACE FUNCTION "public"."list_shop_storefront_listings_for_admin"("p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 200, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_shop_name text;
  v_shop_slug text;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_limit integer;
  v_offset integer;
  v_result jsonb;
begin
  select
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode
  into
    v_tenant_id,
    v_shop_name,
    v_shop_slug,
    v_shop_type,
    v_buy_currency_id,
    v_sell_currency_id,
    v_pricing_method,
    v_markup_percentage,
    v_quantity_display_mode
  from public.shops s
  where s.id = p_shop_id
    and s.deleted_at is null;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.has_active_tenant_membership(v_tenant_id)
     and not public.has_active_tenant_membership(public.resolve_parent_tenant_id(v_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  if v_shop_type = 'vendor_catalog' then
    return jsonb_build_object(
      'data',
      '[]'::jsonb,
      'meta',
      jsonb_build_object(
        'total',
        0,
        'page',
        1,
        'page_size',
        0,
        'total_pages',
        1,
        'shop',
        jsonb_build_object(
          'id',
          p_shop_id,
          'name',
          v_shop_name,
          'slug',
          v_shop_slug,
          'shop_type',
          v_shop_type
        )
      )
    );
  end if;

  v_limit := greatest(1, least(coalesce(p_limit, 200), 500));
  v_offset := greatest(0, coalesce(p_offset, 0));

  with filtered as (
    select
      l.id as listing_id,
      l.product_id,
      l.global_stock_id,
      l.global_stock_allocation_id,
      l.sell_price_amount as listing_sell_price_amount,
      l.sell_price_currency_id as listing_sell_price_currency_id,
      l.minimum_sell_price_amount,
      l.minimum_sell_price_currency_id,
      l.show_quantity,
      l.display_quantity_override,
      l.is_active,
      coalesce(
        gsi.landed_cost_bdt,
        public.calculate_landed_unit_cost(gsi.id),
        p.reference_cost_amount,
        0
      )::numeric as unit_cost_amount,
      case
        when l.global_stock_id is null then coalesce(l.sell_price_amount, p.list_price_amount, 0)
        when v_shop_type = 'fixed_price'::public.shop_type_enum
          and v_pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)
          * (1 + coalesce(v_markup_percentage, 0) / 100.0)
        when v_shop_type = 'fixed_price'::public.shop_type_enum
          and v_pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id), 0)
        else
          l.sell_price_amount
      end as computed_sell_price,
      p.name as product_name,
      p.image_url as product_image_url,
      p.barcode as product_barcode,
      p.product_code as product_code,
      p.brand as product_brand,
      p.category as product_category,
      p.vendor_code as vendor_code,
      p.is_available as product_is_available,
      p.minimum_order_quantity as product_moq,
      public.shop_product_grade_available_units(v_tenant_id, l.product_id, gs.grade_tag_id) as real_available_units,
      tg.slug as grade_slug,
      tg.name as grade_label,
      tg.color as grade_color
    from public.shop_product_listings l
    join public.products p on p.id = l.product_id
    left join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where l.shop_id = p_shop_id
      and (
        p_search is null
        or trim(p_search) = ''
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
        or p.brand ilike ('%' || trim(p_search) || '%')
        or p.category ilike ('%' || trim(p_search) || '%')
        or tg.name ilike ('%' || trim(p_search) || '%')
        or tg.slug ilike ('%' || trim(p_search) || '%')
      )
  ),
  paged as (
    select
      f.*
    from filtered f
    order by f.product_name asc, f.grade_slug asc nulls last, f.listing_id asc
    limit v_limit
    offset v_offset
  )
  select
    jsonb_build_object(
      'data',
      coalesce(
        (
          select
            jsonb_agg(
              jsonb_build_object(
                'listing_id',
                p.listing_id,
                'product_id',
                p.product_id,
                'product_name',
                p.product_name,
                'product_image_url',
                p.product_image_url,
                'product_barcode',
                p.product_barcode,
                'product_code',
                p.product_code,
                'product_brand',
                p.product_brand,
                'product_category',
                p.product_category,
                'vendor_code',
                p.vendor_code,
                'is_available',
                p.product_is_available,
                'minimum_order_quantity',
                p.product_moq,
                'global_stock_id',
                p.global_stock_id,
                'global_stock_allocation_id',
                p.global_stock_allocation_id,
                'real_available_units',
                p.real_available_units,
                'display_quantity_override',
                p.display_quantity_override,
                'available_units',
                case
                  when p.display_quantity_override is not null then p.display_quantity_override
                  else p.real_available_units
                end,
                'listing_status',
                case
                  when p.is_active then 'active'
                  else 'inactive'
                end,
                'stock_grade',
                case
                  when p.grade_slug is not null then jsonb_build_object(
                    'slug',
                    p.grade_slug,
                    'label',
                    p.grade_label,
                    'color',
                    p.grade_color
                  )
                  else null
                end,
                'unit_price',
                case
                  when v_shop_type = 'dropship'::public.shop_type_enum then jsonb_build_object(
                    'amount',
                    round(p.unit_cost_amount, 4),
                    'currency_id',
                    v_buy_currency_id,
                    'code',
                    (
                      select gc.code
                      from public.global_currencies gc
                      where gc.id = v_buy_currency_id
                    ),
                    'symbol',
                    (
                      select gc.symbol
                      from public.global_currencies gc
                      where gc.id = v_buy_currency_id
                    )
                  )
                  else null
                end,
                'sell_price',
                jsonb_build_object(
                  'amount',
                  round(p.computed_sell_price, 4),
                  'currency_id',
                  p.listing_sell_price_currency_id,
                  'code',
                  (
                    select gc.code
                    from public.global_currencies gc
                    where gc.id = p.listing_sell_price_currency_id
                  ),
                  'symbol',
                  (
                    select gc.symbol
                    from public.global_currencies gc
                    where gc.id = p.listing_sell_price_currency_id
                  )
                ),
                'resell_minimum_price',
                case
                  when v_shop_type = 'dropship'::public.shop_type_enum
                    and p.minimum_sell_price_amount is not null then jsonb_build_object(
                    'amount',
                    round(p.minimum_sell_price_amount, 4),
                    'currency_id',
                    p.minimum_sell_price_currency_id,
                    'code',
                    (
                      select gc.code
                      from public.global_currencies gc
                      where gc.id = p.minimum_sell_price_currency_id
                    ),
                    'symbol',
                    (
                      select gc.symbol
                      from public.global_currencies gc
                      where gc.id = p.minimum_sell_price_currency_id
                    )
                  )
                  else null
                end,
                'avg_cost',
                jsonb_build_object(
                  'amount',
                  round(p.unit_cost_amount, 4),
                  'currency_id',
                  case
                    when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                    else v_sell_currency_id
                  end,
                  'code',
                  (
                    select gc.code
                    from public.global_currencies gc
                    where gc.id = case
                      when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                      else v_sell_currency_id
                    end
                  ),
                  'symbol',
                  (
                    select gc.symbol
                    from public.global_currencies gc
                    where gc.id = case
                      when v_shop_type = 'dropship'::public.shop_type_enum then v_buy_currency_id
                      else v_sell_currency_id
                    end
                  )
                ),
                'show_quantity',
                p.show_quantity,
                'sell_price_amount',
                p.listing_sell_price_amount,
                'sell_price_currency_id',
                p.listing_sell_price_currency_id,
                'minimum_sell_price_amount',
                p.minimum_sell_price_amount,
                'minimum_sell_price_currency_id',
                p.minimum_sell_price_currency_id
              )
              order by
                p.product_name asc,
                p.grade_slug asc nulls last,
                p.listing_id asc
            )
          from
            paged p
        ),
        '[]'::jsonb
      ),
      'meta',
      jsonb_build_object(
        'total',
        (
          select
            count(*)
          from
            filtered
        ),
        'page',
        (v_offset / v_limit) + 1,
        'page_size',
        v_limit,
        'total_pages',
        greatest(
          1,
          ceil(
            (
              select
                count(*)::numeric
              from
                filtered
            ) / v_limit::numeric
          )
        ),
        'shop',
        jsonb_build_object(
          'id',
          p_shop_id,
          'name',
          v_shop_name,
          'slug',
          v_shop_slug,
          'shop_type',
          v_shop_type,
          'sell_currency_id',
          v_sell_currency_id,
          'buy_currency_id',
          v_buy_currency_id,
          'pricing_method',
          v_pricing_method,
          'markup_percentage',
          v_markup_percentage,
          'quantity_display_mode',
          v_quantity_display_mode
        )
      )
    )
  into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."list_shop_storefront_listings_for_admin"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

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
        l.tenant_id,
        l.source,
        l.event_kind,
        l.source_url,
        l.file_name,
        l.ran_at,
        l.products_updated,
        l.duration_seconds
      FROM public.catalog_refresh_log l
      WHERE l.tenant_id = p_catalog_tenant_id
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

-- list_store_product_pricing

CREATE OR REPLACE FUNCTION "public"."list_store_product_pricing"("p_tenant_id" bigint, "p_store_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 10, "p_search" "text" DEFAULT NULL::"text", "p_shipment_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_result jsonb;
begin
  with target_batches as (
    -- Filter active inventory items
    select ii.id as inventory_item_id, ii.product_id
    from public.inventory_items ii
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.inventory_stocks ist
      on ist.inventory_item_id = ii.id
    where ii.tenant_id = p_tenant_id
      and ii.status = 'active'
      and (p_shipment_id is null or (ii.source_type = 'shipment' and si.shipment_id = p_shipment_id))
      and (ist.stolen_quantity is null or ist.stolen_quantity = 0 or ist.stolen_quantity < ist.available_quantity)
  ),
  batches_with_details as (
    -- Search in batches or parent product details
    select
      tb.inventory_item_id,
      ii.product_id,
      ii.name,
      ii.image_url,
      ii.barcode,
      ii.product_code,
      ii.expire_date,
      ii.cost
    from target_batches tb
    join public.inventory_items ii on ii.id = tb.inventory_item_id
    left join public.products p on p.id = tb.product_id
    where (
      p_search is null
      or trim(p_search) = ''
      or ii.name ilike ('%' || trim(p_search) || '%')
      or ii.product_code ilike ('%' || trim(p_search) || '%')
      or ii.barcode ilike ('%' || trim(p_search) || '%')
      or p.name ilike ('%' || trim(p_search) || '%')
      or p.product_code ilike ('%' || trim(p_search) || '%')
      or p.barcode ilike ('%' || trim(p_search) || '%')
    )
  ),
  counted as (
    select *, count(*) over() as total_count
    from batches_with_details
  ),
  paged_batches as (
    select *
    from counted
    order by name asc, inventory_item_id asc
    limit p_page_size
    offset (p_page - 1) * p_page_size
  ),
  batch_items as (
    -- Construct cost, stock, and shipment info for each batch
    select
      pb.inventory_item_id,
      jsonb_build_object(
        'id', pb.inventory_item_id,
        'cost', pb.cost,
        'quantities', jsonb_build_object(
          'available', coalesce(ist.available_quantity, 0),
          'reserved', coalesce(ist.reserved_quantity, 0),
          'damaged', coalesce(ist.damaged_quantity, 0),
          'stolen', coalesce(ist.stolen_quantity, 0),
          'expired', coalesce(ist.expired_quantity, 0),
          'open_box', coalesce(ist.open_box_quantity, 0)
        ),
        'shipment', case
          when sh.id is null then null
          else jsonb_build_object(
            'shipment', jsonb_build_object(
              'id', sh.id,
              'name', sh.name,
              'tenant_shipment_id', sh.tenant_shipment_id
            )
          )
        end
      ) as item_json
    from paged_batches pb
    left join public.inventory_stocks ist
      on ist.inventory_item_id = pb.inventory_item_id
    left join public.inventory_items ii
      on ii.id = pb.inventory_item_id
    left join public.shipment_items si
      on ii.source_type = 'shipment'
     and ii.source_id = si.id
    left join public.shipments sh
      on sh.id = si.shipment_id
  ),
  final_data as (
    -- Return one row per batch, mapping batch ID to product_id for frontend table compatibility
    select
      pb.inventory_item_id as product_id,
      pb.name,
      pb.image_url,
      pb.barcode,
      pb.product_code,
      spp.stock_override,
      spp.price_bdt,
      spp.minimum_sell_price_bdt,
      jsonb_build_array(bi.item_json) as items
    from paged_batches pb
    join batch_items bi on bi.inventory_item_id = pb.inventory_item_id
    left join public.store_product_prices spp
      on spp.store_id = p_store_id
     and spp.tenant_id = p_tenant_id
     and spp.inventory_item_id = pb.inventory_item_id
     and spp.is_active = true
  )
  select jsonb_build_object(
    'data', coalesce((select jsonb_agg(to_jsonb(fd)) from final_data fd), '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', coalesce((select max(total_count) from counted), 0),
      'page', p_page,
      'page_size', p_page_size,
      'total_pages', case
        when coalesce((select max(total_count) from counted), 0) = 0 then 1
        else ceil(coalesce((select max(total_count) from counted), 0)::numeric / p_page_size)::int
      end
    )
  )
  into v_result;

  return v_result;
end;
$$;


ALTER FUNCTION "public"."list_store_product_pricing"("p_tenant_id" bigint, "p_store_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_shipment_id" bigint) OWNER TO "postgres";

-- receive_shop_customer_stock

CREATE OR REPLACE FUNCTION "public"."receive_shop_customer_stock"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_quantity" integer, "p_product_id" bigint DEFAULT NULL::bigint, "p_item_label" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop public.shops%rowtype;
  v_row public.shop_customer_stocks%rowtype;
  v_label text;
  v_product_id bigint;
begin
  if p_quantity is null or p_quantity <= 0 then
    return jsonb_build_object('success', false, 'error', 'quantity must be positive');
  end if;

  if p_customer_group_id is null then
    return jsonb_build_object('success', false, 'error', 'customer_group_id required');
  end if;

  if p_product_id is null and (p_item_label is null or length(trim(p_item_label)) = 0) then
    return jsonb_build_object('success', false, 'error', 'product or item name required');
  end if;

  select * into v_shop from public.shops where id = p_shop_id for update;
  if v_shop.id is null then
    return jsonb_build_object('success', false, 'error', 'shop not found');
  end if;

  if not public.is_tenant_staff(v_shop.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if not exists (
    select 1
    from public.shop_customer_group_access scga
    where scga.shop_id = p_shop_id
      and scga.customer_group_id = p_customer_group_id
  ) then
    return jsonb_build_object('success', false, 'error', 'customer does not have shop access');
  end if;

  v_product_id := p_product_id;
  v_label := nullif(trim(p_item_label), '');

  if v_product_id is not null then
    if not exists (select 1 from public.products where id = v_product_id) then
      return jsonb_build_object('success', false, 'error', 'product not found');
    end if;

    select * into v_row
    from public.shop_customer_stocks
    where shop_id = p_shop_id
      and customer_group_id = p_customer_group_id
      and product_id = v_product_id
    for update;

    if v_row.id is null then
      insert into public.shop_customer_stocks (
        tenant_id, shop_id, customer_group_id, product_id, item_label, quantity_on_hand
      )
      values (v_shop.tenant_id, p_shop_id, p_customer_group_id, v_product_id, null, p_quantity)
      returning * into v_row;
    else
      update public.shop_customer_stocks
      set
        quantity_on_hand = v_row.quantity_on_hand + p_quantity,
        updated_at = now()
      where id = v_row.id
      returning * into v_row;
    end if;
  else
    select * into v_row
    from public.shop_customer_stocks
    where shop_id = p_shop_id
      and customer_group_id = p_customer_group_id
      and product_id is null
      and lower(trim(item_label)) = lower(v_label)
    for update;

    if v_row.id is null then
      insert into public.shop_customer_stocks (
        tenant_id, shop_id, customer_group_id, product_id, item_label, quantity_on_hand
      )
      values (v_shop.tenant_id, p_shop_id, p_customer_group_id, null, v_label, p_quantity)
      returning * into v_row;
    else
      update public.shop_customer_stocks
      set
        quantity_on_hand = v_row.quantity_on_hand + p_quantity,
        updated_at = now()
      where id = v_row.id
      returning * into v_row;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'row', jsonb_build_object(
      'id', v_row.id,
      'product_id', v_row.product_id,
      'item_label', v_row.item_label,
      'quantity_on_hand', v_row.quantity_on_hand
    )
  );
end;
$$;


ALTER FUNCTION "public"."receive_shop_customer_stock"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_quantity" integer, "p_product_id" bigint, "p_item_label" "text") OWNER TO "postgres";

-- search_sales_invoice_stock

CREATE OR REPLACE FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("global_stock_id" bigint, "shipment_item_id" bigint, "product_id" bigint, "name" "text", "barcode" "text", "product_code" "text", "image_url" "text", "quantity" numeric, "available_atp" numeric, "unit_cost_price" numeric, "suggested_sell_price" numeric, "shipment_id" bigint, "shipment_name" "text", "holding_tenant_id" bigint, "holding_tenant_name" "text", "is_allocated_to_tenant" boolean, "allocation_rank" integer, "location_id" bigint, "location_name" "text", "stock_created_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_is_parent_context boolean;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent_context := (p_tenant_id = v_parent_id);

  -- Verify membership & access (checks active tenant or parent tenant membership)
  if not exists (
    select 1
    from public.memberships m
    where (m.tenant_id = p_tenant_id or m.tenant_id = v_parent_id)
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  return query
  select
    gs.id as global_stock_id,
    gsi.id as shipment_item_id,
    gsi.product_id,
    gsi.name,
    gsi.barcode,
    gsi.product_code,
    gsi.image_url,
    gs.quantity::numeric as quantity,
    public.global_stock_atp_qty(gs.id)::numeric as available_atp,
    coalesce(gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric as unit_cost_price,
    coalesce(p.list_price_amount, 0)::numeric as suggested_sell_price,
    sh.id as shipment_id,
    sh.name as shipment_name,
    coalesce(sh.assigned_child_tenant_id, v_parent_id) as holding_tenant_id,
    coalesce(ht.name, pt.name) as holding_tenant_name,
    (coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_tenant_id) as is_allocated_to_tenant,
    case
      -- 0 = Directly allocated to the requesting child/sister tenant
      when sh.assigned_child_tenant_id = p_tenant_id then 0
      -- 1 = Parent company stock / unallocated to specific child
      when sh.assigned_child_tenant_id is null or sh.assigned_child_tenant_id = v_parent_id then 1
      -- 2 = Allocated to another sister concern (visible in parent context)
      else 2
    end as allocation_rank,
    gs.location_id,
    sl.name as location_name,
    gs.created_at as stock_created_at
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments sh on sh.id = gsi.shipment_id
  inner join public.tenants pt on pt.id = v_parent_id
  left join public.tenants ht on ht.id = coalesce(sh.assigned_child_tenant_id, v_parent_id)
  left join public.stock_locations sl on sl.id = gs.location_id
  left join public.products p on p.id = gsi.product_id
  where gs.parent_tenant_id = v_parent_id
    and (
      v_is_parent_context
      or sh.assigned_child_tenant_id is null
      or sh.assigned_child_tenant_id = p_tenant_id
    )
    and sh.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and gs.quantity > 0
    and (
      p_search is null
      or trim(p_search) = ''
      or (
        select coalesce(bool_and(
          gsi.name ilike '%' || trim(word) || '%'
          or coalesce(gsi.barcode, '') ilike '%' || trim(word) || '%'
          or coalesce(gsi.product_code, '') ilike '%' || trim(word) || '%'
          or coalesce(p.name, '') ilike '%' || trim(word) || '%'
        ), true)
        from unnest(string_to_array(trim(p_search), ' ')) as word
        where trim(word) <> ''
      )
    )
  order by
    -- 1. Show items allocated to the tenant first, then parent/unallocated, then others
    case
      when sh.assigned_child_tenant_id = p_tenant_id then 0
      when sh.assigned_child_tenant_id is null or sh.assigned_child_tenant_id = v_parent_id then 1
      else 2
    end asc,
    -- 2. FIFO Order: Oldest stock (earliest insert date) appears first
    gs.created_at asc,
    gs.id asc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;


ALTER FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- search_shop_catalog_for_customer

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
      s.min_available_units,
      s.tenant_id,
      s.pricing_method,
      s.markup_percentage,
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
      ) as can_see_sell_price
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
      s.min_available_units,
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
      case when s.can_see_buy_price then p.list_price_amount else null end as unit_price_amount,
      case when s.can_see_buy_price then p.list_price_currency_id else null end as unit_price_currency_id,
      case when s.can_see_buy_price then gc.symbol else null end as unit_price_currency_symbol
    from accessible_shops s
    join public.products p on p.tenant_id = v_parent_tenant_id
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
      and public.shop_catalog_meets_min_available_units(s.min_available_units, p.available_units)
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
        when s.shop_type = 'dropship' and not s.can_see_buy_price then null
        when s.shop_type = 'fixed_price' and not s.can_see_sell_price then null
        when s.shop_type = 'fixed_price' and s.pricing_method = 'markup' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id)) * (1 + s.markup_percentage / 100.0)
        when s.shop_type = 'fixed_price' and s.pricing_method = 'direct_cost' then
          coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))
        else l.sell_price_amount
      end as unit_price_amount,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then l.sell_price_currency_id
        when s.shop_type = 'fixed_price' and s.can_see_sell_price then l.sell_price_currency_id
        else null
      end as unit_price_currency_id,
      case
        when s.shop_type = 'dropship' and s.can_see_buy_price then gc.symbol
        when s.shop_type = 'fixed_price' and s.can_see_sell_price then gc.symbol
        else null
      end as unit_price_currency_symbol
    from accessible_shops s
    join public.shop_product_listings l on l.shop_id = s.id
    join public.products p on p.id = l.product_id
    left join public.global_stocks gs on gs.id = l.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_currencies gc on gc.id = l.sell_price_currency_id
    where s.shop_type <> 'vendor_catalog'
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


ALTER FUNCTION "public"."search_shop_catalog_for_customer"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- set_products_catalog_parent_tenant_id

CREATE OR REPLACE FUNCTION "public"."set_products_catalog_parent_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.tenant_id is not null then
    new.tenant_id := public.resolve_parent_tenant_id(new.tenant_id);
  elsif new.inserted_by_tenant_id is not null then
    new.tenant_id := public.resolve_parent_tenant_id(new.inserted_by_tenant_id);
  end if;

  return new;
end;
$$;


ALTER FUNCTION "public"."set_products_catalog_parent_tenant_id"() OWNER TO "postgres";

-- staff_add_to_shop_cart

CREATE OR REPLACE FUNCTION "public"."staff_add_to_shop_cart"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint DEFAULT NULL::bigint, "p_quantity" integer DEFAULT 1, "p_customer_sell_price_amount" numeric DEFAULT NULL::numeric, "p_customer_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_global_stock_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_cart_id bigint;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_buy_currency_id bigint;
  v_prod_name text;
  v_prod_image text;
  v_prod_price_amount numeric;
  v_prod_price_currency_id bigint;
  v_listing_id bigint;
  v_global_stock_id bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_landed_cost numeric;
  v_available_to_sell integer;
  v_existing_item_id bigint;
  v_existing_item_qty integer;
  v_target_qty integer;
  v_can_set_dropship_price boolean;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  v_cart_id := (public.staff_get_or_create_shop_cart(p_shop_id, p_customer_group_id)->'cart'->>'id')::bigint;

  SELECT tenant_id, shop_type, buy_currency_id
  INTO v_tenant_id, v_shop_type, v_buy_currency_id
  FROM public.shops
  WHERE id = p_shop_id;

  IF v_shop_type <> 'dropship' THEN
    RAISE EXCEPTION 'staff manual cart only supports dropship shops';
  END IF;

  SELECT can_set_dropship_price
  INTO v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id);

  SELECT name, image_url, list_price_amount, list_price_currency_id
  INTO v_prod_name, v_prod_image, v_prod_price_amount, v_prod_price_currency_id
  FROM public.products
  WHERE id = p_product_id;

  IF v_prod_name IS NULL THEN
    RAISE EXCEPTION 'product not found';
  END IF;

  v_global_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  IF v_global_stock_id IS NULL THEN
    RAISE EXCEPTION 'global stock required for this shop type';
  END IF;

  SELECT
    l.id, l.sell_price_amount, l.sell_price_currency_id,
    l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
  INTO
    v_listing_id, v_sell_price_amount, v_sell_price_currency_id,
    v_min_sell_price_amount, v_min_sell_price_currency_id
  FROM public.shop_product_listings l
  WHERE l.shop_id = p_shop_id
    AND l.global_stock_id = v_global_stock_id
    AND l.product_id = p_product_id
    AND l.is_active = true;

  IF v_listing_id IS NULL THEN
    RAISE EXCEPTION 'active product listing not found on this shop';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.shop_listing_group_hides h
    WHERE h.listing_id = v_listing_id
      AND h.customer_group_id = p_customer_group_id
  ) THEN
    RAISE EXCEPTION 'product not available for this customer';
  END IF;

  SELECT coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
  INTO v_landed_cost
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  WHERE gs.id = v_global_stock_id;

  SELECT id, quantity INTO v_existing_item_id, v_existing_item_qty
  FROM public.shop_cart_items
  WHERE cart_id = v_cart_id
    AND global_stock_id = v_global_stock_id;

  v_existing_item_qty := coalesce(v_existing_item_qty, 0);
  v_target_qty := v_existing_item_qty + p_quantity;
  v_available_to_sell := greatest(0, floor(public.global_stock_atp_qty(v_global_stock_id))::integer);

  IF v_target_qty > v_available_to_sell THEN
    RAISE EXCEPTION 'insufficient stock: requested %, available %', v_target_qty, v_available_to_sell;
  END IF;

  IF coalesce(v_can_set_dropship_price, true) THEN
    IF p_customer_sell_price_amount IS NOT NULL THEN
      v_customer_sell_price_amount := p_customer_sell_price_amount;
      v_customer_sell_price_currency_id := p_customer_sell_price_currency_id;
    ELSE
      IF v_sell_price_currency_id = v_min_sell_price_currency_id THEN
        v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      ELSE
        v_customer_sell_price_amount := v_sell_price_amount;
      END IF;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    IF v_customer_sell_price_currency_id = v_min_sell_price_currency_id
       AND v_customer_sell_price_amount < v_min_sell_price_amount THEN
      RAISE EXCEPTION 'price cannot be lower than the minimum sell price %', v_min_sell_price_amount;
    END IF;
  ELSE
    v_customer_sell_price_amount := v_sell_price_amount;
    v_customer_sell_price_currency_id := v_sell_price_currency_id;
  END IF;

  IF v_existing_item_id IS NOT NULL THEN
    UPDATE public.shop_cart_items
    SET
      quantity = v_target_qty,
      unit_sell_price_amount = v_sell_price_amount,
      customer_sell_price_amount = coalesce(v_customer_sell_price_amount, customer_sell_price_amount),
      customer_sell_price_currency_id = coalesce(v_customer_sell_price_currency_id, customer_sell_price_currency_id),
      updated_at = now()
    WHERE id = v_existing_item_id;
  ELSE
    INSERT INTO public.shop_cart_items (
      cart_id, product_id, global_stock_id, global_stock_allocation_id,
      quantity, minimum_quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      name, image_url
    )
    VALUES (
      v_cart_id, p_product_id, v_global_stock_id, NULL,
      p_quantity, 1,
      coalesce(v_landed_cost, v_prod_price_amount), v_buy_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_prod_name, v_prod_image
    );
  END IF;

  RETURN public.staff_shop_cart_response_json(v_cart_id);
END;
$$;


ALTER FUNCTION "public"."staff_add_to_shop_cart"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_product_id" bigint, "p_global_stock_allocation_id" bigint, "p_quantity" integer, "p_customer_sell_price_amount" numeric, "p_customer_sell_price_currency_id" bigint, "p_global_stock_id" bigint) OWNER TO "postgres";

-- staff_create_dropship_order

CREATE OR REPLACE FUNCTION "public"."staff_create_dropship_order"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_items" "jsonb", "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text" DEFAULT NULL::"text", "p_shipping_district" "text" DEFAULT NULL::"text", "p_shipping_thana" "text" DEFAULT NULL::"text", "p_shipping_post_code" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_is_prepaid" boolean DEFAULT false, "p_delivery_instructions" "text" DEFAULT NULL::"text", "p_cod_charge_amount" numeric DEFAULT 0, "p_delivery_charge_amount" numeric DEFAULT 0, "p_print_charge_amount" numeric DEFAULT 0, "p_packing_charge_amount" numeric DEFAULT 0, "p_discount_amount" numeric DEFAULT 0, "p_recipient_pays_delivery" boolean DEFAULT true, "p_recipient_pays_cod" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_result jsonb;
  v_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci public.shop_order_items%rowtype;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
  v_billing_profile_warning boolean := false;
  v_elem jsonb;
  v_product_id bigint;
  v_global_stock_id bigint;
  v_qty integer;
  v_prod_name text;
  v_prod_image text;
  v_listing_id_new bigint;
  v_sell_price_amount numeric;
  v_sell_price_currency_id bigint;
  v_min_sell_price_amount numeric;
  v_min_sell_price_currency_id bigint;
  v_customer_sell_price_amount numeric;
  v_customer_sell_price_currency_id bigint;
  v_landed_cost numeric;
  v_can_set_dropship_price boolean;
  v_order_tenant_id bigint;
BEGIN
  PERFORM public.assert_staff_can_place_dropship_order_on_behalf(p_shop_id, p_customer_group_id);

  SELECT * INTO v_shop FROM public.shops WHERE id = p_shop_id AND is_active = true;
  IF v_shop.id IS NULL THEN RAISE EXCEPTION 'shop not found or inactive'; END IF;
  IF v_shop.shop_type <> 'dropship' THEN RAISE EXCEPTION 'shop is not dropship'; END IF;
  v_order_tenant_id := public.resolve_parent_tenant_id(v_shop.tenant_id);

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'order must include at least one item';
  END IF;

  IF nullif(trim(coalesce(p_recipient_name, '')), '') IS NULL THEN RAISE EXCEPTION 'recipient name is required'; END IF;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  IF v_phone IS NULL THEN RAISE EXCEPTION 'recipient phone is required'; END IF;
  IF nullif(trim(coalesce(p_shipping_address, '')), '') IS NULL THEN RAISE EXCEPTION 'shipping address is required'; END IF;

  IF EXISTS (
    SELECT 1
    FROM (
      SELECT
        nullif((e->>'listing_id')::bigint, 0) AS listing_id,
        (e->>'product_id')::bigint AS product_id,
        sum(greatest(1, coalesce((e->>'quantity')::int, 1))) AS qty
      FROM jsonb_array_elements(p_items) AS e
      GROUP BY 1, 2
    ) agg
    JOIN public.shop_product_listings l ON l.id = agg.listing_id AND l.shop_id = p_shop_id
    LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
    WHERE agg.listing_id IS NOT NULL
      AND agg.qty > coalesce(
        l.display_quantity_override,
        public.shop_product_grade_available_units(
          v_shop.tenant_id,
          agg.product_id,
          coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
        )
      )
  ) THEN
    RAISE EXCEPTION 'insufficient stock for one or more items';
  END IF;

  SELECT can_set_dropship_price INTO v_can_set_dropship_price
  FROM public.get_shop_permissions_for_customer_group(p_shop_id, p_customer_group_id)
  LIMIT 1;
  v_can_set_dropship_price := coalesce(v_can_set_dropship_price, true);

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_listing_id_new := nullif((v_elem->>'listing_id')::bigint, 0);
    v_global_stock_id := nullif((v_elem->>'global_stock_id')::bigint, 0);
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));
    IF v_product_id IS NULL OR (v_listing_id_new IS NULL AND v_global_stock_id IS NULL) THEN
      RAISE EXCEPTION 'each item requires product_id and listing_id';
    END IF;

    IF v_listing_id_new IS NOT NULL THEN
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id
      FROM public.shop_product_listings l
      WHERE l.id = v_listing_id_new
        AND l.shop_id = p_shop_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    ELSE
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id
      FROM public.shop_product_listings l
      WHERE l.shop_id = p_shop_id
        AND l.global_stock_id = v_global_stock_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    END IF;

    IF v_listing_id_new IS NULL THEN
      RAISE EXCEPTION 'active product listing not found on this shop';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.shop_listing_group_hides h
      WHERE h.listing_id = v_listing_id_new AND h.customer_group_id = p_customer_group_id
    ) THEN
      RAISE EXCEPTION 'product not available for this customer';
    END IF;

    IF nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_can_set_dropship_price AND v_sell_price_currency_id = v_min_sell_price_currency_id THEN
      v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    ELSE
      v_customer_sell_price_amount := v_sell_price_amount;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    IF coalesce(v_min_sell_price_amount, 0) > 0
       AND v_customer_sell_price_currency_id = v_min_sell_price_currency_id
       AND v_customer_sell_price_amount < v_min_sell_price_amount THEN
      RAISE EXCEPTION 'price floor violation: item priced below minimum sell price';
    END IF;
  END LOOP;

  v_profile_id := p_profile_id;
  IF v_profile_id IS NULL THEN
    v_profile_id := public.resolve_customer_profile_for_group(v_shop.tenant_id, p_customer_group_id);
  END IF;
  IF v_profile_id IS NULL THEN
    v_billing_profile_warning := true;
  END IF;

  IF v_shop.order_mode = 'checkout_fixed' THEN v_order_status := 'confirmed';
  ELSE v_order_status := 'submitted'; END IF;

  v_deduct_delivery_from_margin := NOT coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := NOT coalesce(p_recipient_pays_cod, true);

  SELECT public.generate_shop_order_number(v_order_tenant_id, v_shop.id) INTO v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_shop.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  INSERT INTO public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) VALUES (
    v_order_tenant_id, v_shop.id, p_customer_group_id, NULL, v_order_no,
    'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable, v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_profile_id, public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin, v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  ) RETURNING id INTO v_order_id;

  FOR v_elem IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_elem->>'product_id')::bigint;
    v_listing_id_new := nullif((v_elem->>'listing_id')::bigint, 0);
    v_global_stock_id := nullif((v_elem->>'global_stock_id')::bigint, 0);
    v_qty := greatest(1, coalesce((v_elem->>'quantity')::int, 1));

    SELECT name, image_url INTO v_prod_name, v_prod_image FROM public.products WHERE id = v_product_id;

    IF v_listing_id_new IS NOT NULL THEN
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id,
        coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
        l.global_stock_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id,
        v_grade_tag_id, v_global_stock_id
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.id = v_listing_id_new
        AND l.shop_id = p_shop_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    ELSE
      SELECT
        l.id, l.sell_price_amount, l.sell_price_currency_id,
        l.minimum_sell_price_amount, l.minimum_sell_price_currency_id,
        coalesce(l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
        l.global_stock_id
      INTO
        v_listing_id_new, v_sell_price_amount, v_sell_price_currency_id,
        v_min_sell_price_amount, v_min_sell_price_currency_id,
        v_grade_tag_id, v_global_stock_id
      FROM public.shop_product_listings l
      LEFT JOIN public.global_stocks gs ON gs.id = l.global_stock_id
      WHERE l.shop_id = p_shop_id
        AND l.global_stock_id = v_global_stock_id
        AND l.product_id = v_product_id
        AND l.is_active = true;
    END IF;

    IF v_global_stock_id IS NOT NULL THEN
      SELECT coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gs.shipment_item_id))
      INTO v_landed_cost
      FROM public.global_stocks gs
      JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
      WHERE gs.id = v_global_stock_id;
    ELSE
      v_landed_cost := public.shop_product_grade_avg_landed_cost(
        v_shop.tenant_id, v_product_id, v_grade_tag_id
      );
    END IF;

    IF nullif(v_elem->>'customer_sell_price_amount', '') IS NOT NULL THEN
      v_customer_sell_price_amount := (v_elem->>'customer_sell_price_amount')::numeric;
      v_customer_sell_price_currency_id := coalesce((v_elem->>'customer_sell_price_currency_id')::bigint, v_sell_price_currency_id);
    ELSIF v_can_set_dropship_price AND v_sell_price_currency_id = v_min_sell_price_currency_id THEN
      v_customer_sell_price_amount := greatest(v_sell_price_amount, coalesce(v_min_sell_price_amount, 0));
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    ELSE
      v_customer_sell_price_amount := v_sell_price_amount;
      v_customer_sell_price_currency_id := v_sell_price_currency_id;
    END IF;

    INSERT INTO public.shop_order_items (
      order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
      name, image_url, quantity,
      unit_list_price_amount, unit_list_price_currency_id,
      unit_sell_price_amount, unit_sell_price_currency_id,
      unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
      customer_sell_price_amount, customer_sell_price_currency_id,
      customer_offer_amount, customer_offer_currency_id,
      final_price_amount, final_price_currency_id,
      cost_price_amount, cost_price_currency_id, confirmed_quantity
    ) VALUES (
      v_order_id, v_product_id, v_listing_id_new,
      coalesce(v_grade_tag_id, public.default_stock_grade_tag_id()),
      v_global_stock_id, NULL, v_prod_name, v_prod_image, v_qty,
      coalesce(v_landed_cost, 0), v_shop.buy_currency_id,
      v_sell_price_amount, v_sell_price_currency_id,
      v_min_sell_price_amount, v_min_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      v_customer_sell_price_amount, v_customer_sell_price_currency_id,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_amount ELSE NULL END,
      CASE WHEN v_order_status = 'confirmed' THEN v_customer_sell_price_currency_id ELSE NULL END,
      coalesce(v_landed_cost, public.shop_product_grade_avg_landed_cost(
        v_shop.tenant_id, v_product_id, coalesce(v_grade_tag_id, public.default_stock_grade_tag_id())
      )),
      v_shop.buy_currency_id, 0
    );
  END LOOP;

  FOR v_ci IN SELECT * FROM public.shop_order_items WHERE order_id = v_order_id LOOP
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (SELECT l.grade_tag_id FROM public.shop_product_listings l WHERE l.id = v_ci.listing_id),
      (SELECT gs.grade_tag_id FROM public.global_stocks gs WHERE gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id ORDER BY l.id ASC LIMIT 1),
      (SELECT l.id FROM public.shop_product_listings l WHERE l.shop_id = v_shop.id AND l.product_id = v_ci.product_id
        AND l.global_stock_id = v_ci.global_stock_id LIMIT 1)
    );

    IF v_listing_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE id = v_listing_id AND display_quantity_override IS NOT NULL;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.shop_product_listings
      SET display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      WHERE shop_id = v_shop.id
        AND product_id = v_ci.product_id
        AND global_stock_id = v_ci.global_stock_id
        AND display_quantity_override IS NOT NULL;
    END IF;

    IF v_ci.global_stock_id IS NOT NULL THEN
      UPDATE public.global_stocks
      SET quantity = greatest(0, quantity - v_ci.quantity)
      WHERE id = v_ci.global_stock_id;
    END IF;

    UPDATE public.shop_order_items
    SET listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
    WHERE id = v_ci.id;

    IF v_listing_id IS NOT NULL THEN
      v_available_after := public.shop_product_grade_available_units(v_shop.tenant_id, v_ci.product_id, v_grade_tag_id);
      IF coalesce((SELECT display_quantity_override FROM public.shop_product_listings WHERE id = v_listing_id), v_available_after, 0) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false WHERE id = v_listing_id;
      END IF;
    ELSIF v_ci.global_stock_id IS NOT NULL THEN
      SELECT coalesce(sum(gs.quantity), 0) INTO v_available_after
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = (SELECT shipment_item_id FROM public.global_stocks WHERE id = v_ci.global_stock_id)
        AND gs.availability = 'sellable'::public.stock_availability;
      IF coalesce(
        (SELECT display_quantity_override FROM public.shop_product_listings
         WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id),
        v_available_after,
        0
      ) <= 0 THEN
        UPDATE public.shop_product_listings SET is_active = false
        WHERE shop_id = v_shop.id AND product_id = v_ci.product_id AND global_stock_id = v_ci.global_stock_id;
      END IF;
    END IF;
  END LOOP;

  PERFORM public.recompute_dropship_cod_collect_amount(v_order_id);

  SELECT jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'shop_id', v_shop.id, 'billing_profile_warning', v_billing_profile_warning
  ) INTO v_result;
  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."staff_create_dropship_order"("p_shop_id" bigint, "p_customer_group_id" bigint, "p_items" "jsonb", "p_recipient_name" "text", "p_recipient_phone" "text", "p_shipping_address" "text", "p_recipient_phone_secondary" "text", "p_shipping_district" "text", "p_shipping_thana" "text", "p_shipping_post_code" "text", "p_profile_id" bigint, "p_is_prepaid" boolean, "p_delivery_instructions" "text", "p_cod_charge_amount" numeric, "p_delivery_charge_amount" numeric, "p_print_charge_amount" numeric, "p_packing_charge_amount" numeric, "p_discount_amount" numeric, "p_recipient_pays_delivery" boolean, "p_recipient_pays_cod" boolean) OWNER TO "postgres";

-- staff_price_shop_order

CREATE OR REPLACE FUNCTION "public"."staff_price_shop_order"("p_order_id" bigint, "p_items" "jsonb", "p_profit_basis" "text" DEFAULT NULL::"text", "p_fx_rate" numeric DEFAULT NULL::numeric, "p_cargo_rate" numeric DEFAULT NULL::numeric, "p_profit_pct" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_offer_amount numeric;
  v_offer_currency_id bigint;
  v_weight_kg numeric;
  v_is_manual boolean;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_price_shop_order is only valid for vendor_catalog orders.';
  end if;

  if v_order.status not in ('submitted'::public.shop_order_status, 'costing_pending'::public.shop_order_status) then
    raise exception 'Order % cannot send first offer from status %', p_order_id, v_order.status;
  end if;

  update public.shop_orders
  set
    profit_basis = coalesce(p_profit_basis, profit_basis),
    conversion_rate = coalesce(p_fx_rate, conversion_rate),
    cargo_rate = coalesce(p_cargo_rate, cargo_rate),
    first_offer_rate = coalesce(p_profit_pct, first_offer_rate),
    profit_rate = coalesce(p_profit_pct, profit_rate),
    status = 'priced'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_offer_amount := (v_elem->>'staff_offer_amount')::numeric;
    v_offer_currency_id := (v_elem->>'staff_offer_currency_id')::bigint;
    v_weight_kg := coalesce(
      nullif(v_elem->>'weight_kg', '')::numeric,
      nullif(v_elem->>'gross_weight_kg', '')::numeric,
      null
    );
    v_is_manual := coalesce((v_elem->>'is_first_offer_manual')::boolean, false);
    v_product_weight_gm := nullif(v_elem->>'product_weight_gm', '')::numeric;
    v_package_weight_gm := nullif(v_elem->>'package_weight_gm', '')::numeric;

    update public.shop_order_items
    set
      staff_offer_amount = v_offer_amount,
      staff_offer_currency_id = v_offer_currency_id,
      weight_kg = coalesce(v_weight_kg, weight_kg),
      is_first_offer_manual = v_is_manual,
      negotiation_status = 'priced',
      staff_offer_at = now(),
      updated_at = now()
    where id = v_item_id and order_id = p_order_id;

    select soi.product_id
    into v_product_id
    from public.shop_order_items soi
    where soi.id = v_item_id and soi.order_id = p_order_id;

    if v_product_id is not null
       and (
         (v_product_weight_gm is not null and v_product_weight_gm > 0)
         or (v_package_weight_gm is not null and v_package_weight_gm > 0)
       ) then
      update public.products p
      set
        product_weight = case
          when v_product_weight_gm is not null and v_product_weight_gm > 0 then v_product_weight_gm
          else p.product_weight
        end,
        package_weight = case
          when v_package_weight_gm is not null and v_package_weight_gm > 0 then v_package_weight_gm
          else p.package_weight
        end,
        updated_at = now()
      where p.id = v_product_id;
    end if;
  end loop;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.offer.sent',
    p_title := format('Offer ready for %s', v_order.order_no),
    p_body := 'Open the order to review prices.'
  );

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."staff_price_shop_order"("p_order_id" bigint, "p_items" "jsonb", "p_profit_basis" "text", "p_fx_rate" numeric, "p_cargo_rate" numeric, "p_profit_pct" numeric) OWNER TO "postgres";

-- staff_set_catalog_ordered_qty

CREATE OR REPLACE FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := v_order.tenant_id;

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  if public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' then
    raise exception 'order must be procuring to mark packed';
  end if;

  update public.shop_orders
  set
    status = 'packed'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  for v_item_row in
    select oi.*
    from public.shop_order_items oi
    where oi.order_id = p_order_id
  loop
    v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);

    select coalesce(pd.delivered_quantity, 0)
    into v_allocated
    from public.preorder_demand pd
    where pd.source_type = 'shop_order_item'
      and pd.source_id = v_item_row.id;

    v_shortfall := greatest(v_target_qty - coalesce(v_allocated, 0), 0);

    if v_shortfall > 0 and v_order.profile_id is not null then
        select p.barcode, p.product_code
        into v_product
        from public.products p
        where p.id = v_item_row.product_id;

        perform public.add_demand_bucket_item_internal(
          p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_profile_id => v_order.profile_id,
          p_product_id => v_item_row.product_id,
          p_source_type => 'shop_order_item',
          p_source_id => v_item_row.id,
          p_snapshot => jsonb_build_object(
            'name', coalesce(v_item_row.name, ''),
            'image_url', v_item_row.image_url,
            'barcode', v_product.barcode,
            'product_code', v_product.product_code,
            'note', null
          ),
          p_quantity => v_shortfall
        );

        insert into public.customer_order_backlog_items (
          tenant_id,
          profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) values (
          v_order.tenant_id,
          v_order.profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_row.id,
          v_shortfall,
          0,
          'open'
        )
        on conflict (tenant_id, profile_id, product_id)
        do update set
          requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
    end if;
  end loop;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.packed',
    p_title := format('%s is packing', v_order.order_no),
    p_body := 'We will mark it on the way when it ships.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."staff_set_catalog_ordered_qty"("p_order_id" bigint, "p_items" "jsonb") OWNER TO "postgres";

-- staff_shop_cart_response_json

CREATE OR REPLACE FUNCTION "public"."staff_shop_cart_response_json"("p_cart_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
  v_perm record;
  v_can_see_buy_price_snapshot boolean;
  v_can_see_sell_price_snapshot boolean;
  v_shop_id bigint;
  v_customer_group_id bigint;
BEGIN
  SELECT c.shop_id, c.customer_group_id, c.can_see_buy_price_snapshot, c.can_see_sell_price_snapshot
  INTO v_shop_id, v_customer_group_id, v_can_see_buy_price_snapshot, v_can_see_sell_price_snapshot
  FROM public.shop_carts c
  WHERE c.id = p_cart_id;

  IF v_shop_id IS NULL THEN
    RAISE EXCEPTION 'cart not found';
  END IF;

  SELECT *
  INTO v_perm
  FROM public.get_shop_permissions_for_customer_group(v_shop_id, v_customer_group_id)
  LIMIT 1;

  SELECT jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'customer_group_id', c.customer_group_id,
      'can_see_buy_price_snapshot', v_can_see_buy_price_snapshot,
      'can_see_sell_price_snapshot', v_can_see_sell_price_snapshot,
      'status', c.status,
      'created_at', c.created_at,
      'updated_at', c.updated_at,
      'shop_type', s.shop_type,
      'allow_delivery', s.allow_delivery,
      'default_print_charge_amount', s.default_print_charge_amount,
      'default_packing_charge_amount', s.default_packing_charge_amount,
      'deduct_charges_from_margin', s.deduct_charges_from_margin,
      'deduct_print_from_margin', s.deduct_print_from_margin,
      'deduct_packing_from_margin', s.deduct_packing_from_margin
    ),
    'items', coalesce(
      (
        SELECT jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'listing_id', ci.listing_id,
            'grade_tag_id', ci.grade_tag_id,
            'global_stock_id', ci.global_stock_id,
            'global_stock_allocation_id', ci.global_stock_allocation_id,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'minimum_order_quantity', p.minimum_order_quantity,
            'unit_list_price_amount', CASE WHEN v_can_see_buy_price_snapshot THEN ci.unit_list_price_amount ELSE NULL END,
            'unit_list_price_currency_id', CASE WHEN v_can_see_buy_price_snapshot THEN ci.unit_list_price_currency_id ELSE NULL END,
            'unit_sell_price_amount', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_sell_price_amount ELSE NULL END,
            'unit_sell_price_currency_id', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_sell_price_currency_id ELSE NULL END,
            'unit_minimum_sell_price_amount', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_minimum_sell_price_amount ELSE NULL END,
            'unit_minimum_sell_price_currency_id', CASE WHEN v_can_see_sell_price_snapshot THEN ci.unit_minimum_sell_price_currency_id ELSE NULL END,
            'customer_sell_price_amount', CASE WHEN v_can_see_sell_price_snapshot THEN ci.customer_sell_price_amount ELSE NULL END,
            'customer_sell_price_currency_id', CASE WHEN v_can_see_sell_price_snapshot THEN ci.customer_sell_price_currency_id ELSE NULL END,
            'name', ci.name,
            'image_url', ci.image_url
          )
        )
        FROM public.shop_cart_items ci
        LEFT JOIN public.products p ON p.id = ci.product_id
        WHERE ci.cart_id = c.id
      ),
      '[]'::jsonb
    ),
    'permissions', jsonb_build_object(
      'can_browse', coalesce(v_perm.can_browse, false),
      'can_see_buy_price', coalesce(v_perm.can_see_buy_price, false),
      'can_see_sell_price', coalesce(v_perm.can_see_sell_price, false),
      'can_see_resell_minimum_price', coalesce(v_perm.can_see_resell_minimum_price, false),
      'can_add_to_cart', coalesce(v_perm.can_add_to_cart, false),
      'can_place_order', coalesce(v_perm.can_place_order, false),
      'can_negotiate', coalesce(v_perm.can_negotiate, false),
      'can_view_quantity', coalesce(v_perm.can_view_quantity, false),
      'can_set_dropship_price', coalesce(v_perm.can_set_dropship_price, false)
    ),
    'currency', CASE
      WHEN gc.id IS NOT NULL THEN jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
      ELSE NULL
    END
  )
  INTO v_result
  FROM public.shop_carts c
  JOIN public.shops s ON s.id = c.shop_id
  LEFT JOIN public.global_currencies gc ON gc.id = s.sell_currency_id
  WHERE c.id = p_cart_id;

  RETURN v_result;
END;
$$;


ALTER FUNCTION "public"."staff_shop_cart_response_json"("p_cart_id" bigint) OWNER TO "postgres";

-- trg_fn_auto_upsert_pbc_backlog

CREATE OR REPLACE FUNCTION "public"."trg_fn_auto_upsert_pbc_backlog"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_file public.product_based_costing_files%rowtype;
  v_tenant_id bigint;
  v_other_id bigint;
  v_open_qty numeric;
  v_prod record;
  v_price_gbp numeric;
  v_name text;
begin
  if tg_op = 'DELETE' then
    if old.product_id is not null and old.product_based_costing_file_id is not null then
      select * into v_file
      from public.product_based_costing_files
      where id = old.product_based_costing_file_id;

      if v_file.id is not null then
        v_tenant_id := v_file.tenant_id;
        if v_tenant_id is null and v_file.profile_id is not null then
          select tenant_id into v_tenant_id
          from public.profiles
          where id = v_file.profile_id;
        end if;

        select pci.id into v_other_id
        from public.product_based_costing_items pci
        inner join public.product_based_costing_files pcf
          on pcf.id = pci.product_based_costing_file_id
        where pci.product_id = old.product_id
          and pcf.profile_id is not distinct from v_file.profile_id
        order by pci.updated_at desc nulls last, pci.id desc
        limit 1;

        if v_other_id is not null then
          perform public.upsert_pbc_backlog_from_item(v_other_id);
        elsif v_tenant_id is not null and v_file.profile_id is not null then
          v_open_qty := coalesce(old.confirmed_quantity, old.quantity, 0);

          if coalesce(v_file.status, 'pending') in ('pending', 'offered')
             and v_open_qty > 0
          then
            select
              p.name,
              p.image_url,
              p.list_price_amount,
              p.product_weight,
              p.package_weight,
              p.barcode,
              p.product_code,
              gc.code as list_price_currency_code
            into v_prod
            from public.products p
            left join public.global_currencies gc on gc.id = p.list_price_currency_id
            where p.id = old.product_id;

            v_name := coalesce(old.name, v_prod.name);
            v_price_gbp := coalesce(
              old.price_gbp,
              case
                when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
                  then v_prod.list_price_amount
                else null
              end
            );

            if v_name is not null then
              insert into public.product_based_costing_backlog_items (
                tenant_id,
                profile_id,
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
              values (
                v_tenant_id,
                v_file.profile_id,
                old.product_id,
                round(v_open_qty)::integer,
                v_name,
                coalesce(old.image_url, v_prod.image_url),
                coalesce(old.barcode, v_prod.barcode),
                coalesce(old.product_code, v_prod.product_code),
                v_price_gbp,
                coalesce(old.product_weight::numeric, v_prod.product_weight),
                coalesce(old.package_weight::numeric, v_prod.package_weight),
                v_file.id,
                null,
                now()
              )
              on conflict (tenant_id, profile_id, product_id)
              do update set
                open_quantity = excluded.open_quantity,
                name = excluded.name,
                image_url = excluded.image_url,
                barcode = excluded.barcode,
                product_code = excluded.product_code,
                price_gbp = excluded.price_gbp,
                product_weight = excluded.product_weight,
                package_weight = excluded.package_weight,
                last_costing_file_id = excluded.last_costing_file_id,
                last_costing_item_id = excluded.last_costing_item_id,
                updated_at = now();
            end if;
          else
            delete from public.product_based_costing_backlog_items
            where tenant_id = v_tenant_id
              and profile_id = v_file.profile_id
              and product_id = old.product_id;
          end if;
        end if;
      end if;
    end if;

    return old;
  end if;

  perform public.upsert_pbc_backlog_from_item(new.id);
  return new;
end;
$$;


ALTER FUNCTION "public"."trg_fn_auto_upsert_pbc_backlog"() OWNER TO "postgres";

-- trg_sync_catalog_weights_from_global_shipment_item

CREATE OR REPLACE FUNCTION "public"."trg_sync_catalog_weights_from_global_shipment_item"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  if new.product_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.product_weight is not distinct from old.product_weight
     and new.package_weight is not distinct from old.package_weight
     and new.product_id is not distinct from old.product_id then
    return new;
  end if;

  select * into v_ship
  from public.global_shipments
  where id = new.shipment_id;

  if not found then
    return new;
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    return new;
  end if;

  update public.products p
  set
    product_weight = new.product_weight,
    package_weight = new.package_weight,
    updated_at = now()
  where p.id = new.product_id;

  return new;
end;
$$;


ALTER FUNCTION "public"."trg_sync_catalog_weights_from_global_shipment_item"() OWNER TO "postgres";

-- update_catalog_order_item_for_staff

CREATE OR REPLACE FUNCTION "public"."update_catalog_order_item_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_item_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_product_id bigint;
  v_product_weight_gm numeric;
  v_package_weight_gm numeric;
begin
  if p_tenant_id is null or p_order_id is null or p_item_id is null then
    raise exception 'tenant, order, and item required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_order_items soi
  set
    weight_kg = case when p_payload ? 'weight_kg' then (p_payload->>'weight_kg')::numeric else soi.weight_kg end,
    cost_price_amount = case when p_payload ? 'cost_price_amount' then (p_payload->>'cost_price_amount')::numeric else soi.cost_price_amount end,
    staff_offer_amount = case when p_payload ? 'staff_offer_amount' then (p_payload->>'staff_offer_amount')::numeric else soi.staff_offer_amount end,
    is_first_offer_manual = case when p_payload ? 'is_first_offer_manual' then coalesce((p_payload->>'is_first_offer_manual')::boolean, false) else soi.is_first_offer_manual end,
    customer_offer_amount = case when p_payload ? 'customer_offer_amount' then (p_payload->>'customer_offer_amount')::numeric else soi.customer_offer_amount end,
    customer_offer_currency_id = case when p_payload ? 'customer_offer_currency_id' then nullif(p_payload->>'customer_offer_currency_id', '')::bigint else soi.customer_offer_currency_id end,
    final_price_amount = case when p_payload ? 'final_price_amount' then (p_payload->>'final_price_amount')::numeric else soi.final_price_amount end,
    is_final_offer_manual = case when p_payload ? 'is_final_offer_manual' then coalesce((p_payload->>'is_final_offer_manual')::boolean, false) else soi.is_final_offer_manual end,
    confirmed_quantity = case when p_payload ? 'confirmed_quantity' then (p_payload->>'confirmed_quantity')::integer else soi.confirmed_quantity end,
    quantity = case when p_payload ? 'quantity' then (p_payload->>'quantity')::integer else soi.quantity end,
    updated_at = now()
  where soi.id = p_item_id and soi.order_id = p_order_id;

  select soi.product_id into v_product_id
  from public.shop_order_items soi
  where soi.id = p_item_id and soi.order_id = p_order_id;

  v_product_weight_gm := nullif(p_payload->>'product_weight_gm', '')::numeric;
  v_package_weight_gm := nullif(p_payload->>'package_weight_gm', '')::numeric;

  if v_product_id is not null
     and (
       (v_product_weight_gm is not null and v_product_weight_gm > 0)
       or (v_package_weight_gm is not null and v_package_weight_gm > 0)
     ) then
    update public.products p
    set
      product_weight = case
        when v_product_weight_gm is not null and v_product_weight_gm > 0 then v_product_weight_gm
        else p.product_weight
      end,
      package_weight = case
        when v_package_weight_gm is not null and v_package_weight_gm > 0 then v_package_weight_gm
        else p.package_weight
      end,
      updated_at = now()
    where p.id = v_product_id;
  end if;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;


ALTER FUNCTION "public"."update_catalog_order_item_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_item_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";

-- update_sales_invoice_from_payload

CREATE OR REPLACE FUNCTION "public"."update_sales_invoice_from_payload"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_inv_patch jsonb;
  v_items jsonb;
  v_remove_ids jsonb;
  v_item_elem jsonb;
  v_invoice public.bills;
  v_parent_id bigint;
  v_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_stock_parent bigint;
  v_db_item public.bill_lines;
  v_removed_ids bigint[] := '{}';
  v_remove_id bigint;
  v_result_items jsonb := '[]'::jsonb;
  v_has_changes boolean := false;
  v_recompute boolean := true;
  v_dropship_sync boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied', 'code', 'ACCESS_DENIED');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object', 'code', 'VALIDATION_ERROR');
  end if;

  v_dropship_sync := coalesce((p_payload->'options'->>'dropship_sync')::boolean, false);

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice not found', 'code', 'NOT_FOUND');
  end if;

  if v_invoice.issued_by_tenant_id <> p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'invoice does not belong to tenant', 'code', 'ACCESS_DENIED');
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    if not (
      v_dropship_sync
      and v_invoice.invoice_type = 'dropship'::public.global_invoice_type
      and v_invoice.invoice_status = 'issued'::public.global_invoice_status
    ) then
      return jsonb_build_object(
        'success', false,
        'error', format('invoice is not editable (status: %s)', v_invoice.invoice_status),
        'code', 'INVOICE_NOT_EDITABLE'
      );
    end if;
  end if;

  v_inv_patch := p_payload->'invoice';
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_remove_ids := coalesce(p_payload->'remove_item_ids', '[]'::jsonb);
  v_recompute := coalesce((p_payload->'options'->>'recompute_totals')::boolean, true);

  if v_dropship_sync and v_invoice.invoice_status = 'issued'::public.global_invoice_status then
    v_remove_ids := '[]'::jsonb;
  end if;

  if (v_inv_patch is null or v_inv_patch = '{}'::jsonb)
     and jsonb_array_length(v_items) = 0
     and jsonb_array_length(v_remove_ids) = 0 then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  v_parent_id := v_invoice.parent_tenant_id;

  if v_inv_patch is not null and jsonb_typeof(v_inv_patch) = 'object' and v_inv_patch <> '{}'::jsonb then
    if v_inv_patch ? 'profile_id' and nullif(v_inv_patch->>'profile_id', '') is not null then
      if not exists (
        select 1 from public.profiles pr
        where pr.id = (v_inv_patch->>'profile_id')::bigint
          and pr.operating_tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'billing profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    if v_inv_patch ? 'recipient_profile_id' and nullif(v_inv_patch->>'recipient_profile_id', '') is not null then
      if not exists (
        select 1 from public.recipient_profiles rp
        where rp.id = (v_inv_patch->>'recipient_profile_id')::bigint
          and rp.tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'recipient profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    update public.bills
    set
      invoice_no = case
        when v_inv_patch ? 'invoice_no' then coalesce(nullif(trim(v_inv_patch->>'invoice_no'), ''), invoice_no)
        else invoice_no
      end,
      invoice_date = case
        when v_inv_patch ? 'invoice_date' then coalesce(nullif(v_inv_patch->>'invoice_date', '')::date, invoice_date)
        else invoice_date
      end,
      due_date = case
        when v_inv_patch ? 'due_date' then nullif(v_inv_patch->>'due_date', '')::date
        else due_date
      end,
      profile_id = case
        when v_inv_patch ? 'profile_id' then nullif(v_inv_patch->>'profile_id', '')::bigint
        else profile_id
      end,
      recipient_profile_id = case
        when v_inv_patch ? 'recipient_profile_id' then nullif(v_inv_patch->>'recipient_profile_id', '')::bigint
        else recipient_profile_id
      end,
      recipient_name = case
        when v_inv_patch ? 'recipient_name' then nullif(trim(v_inv_patch->>'recipient_name'), '')
        else recipient_name
      end,
      recipient_phone = case
        when v_inv_patch ? 'recipient_phone' then nullif(trim(v_inv_patch->>'recipient_phone'), '')
        else recipient_phone
      end,
      recipient_address = case
        when v_inv_patch ? 'recipient_address' then nullif(trim(v_inv_patch->>'recipient_address'), '')
        else recipient_address
      end,
      note = case
        when v_inv_patch ? 'note' then nullif(trim(v_inv_patch->>'note'), '')
        else note
      end,
      discount_amount = case
        when v_inv_patch ? 'discount_amount' then coalesce(nullif(v_inv_patch->>'discount_amount', '')::numeric, 0)
        else discount_amount
      end,
      shipping_charge = case
        when v_inv_patch ? 'shipping_charge' then coalesce(nullif(v_inv_patch->>'shipping_charge', '')::numeric, 0)
        else shipping_charge
      end,
      channel_meta = case
        when v_inv_patch ? 'channel_meta' and jsonb_typeof(v_inv_patch->'channel_meta') = 'object'
          then coalesce(channel_meta, '{}'::jsonb) || (v_inv_patch->'channel_meta')
        when v_inv_patch ? 'cod_charge_amount' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge_amount', '')::numeric, 0))
        when v_inv_patch ? 'cod_charge' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge', '')::numeric, 0))
        else channel_meta
      end,
      print_charge = case
        when v_inv_patch ? 'print_charge' then coalesce(nullif(v_inv_patch->>'print_charge', '')::numeric, 0)
        else print_charge
      end,
      wrapping_charge = case
        when v_inv_patch ? 'wrapping_charge' then coalesce(nullif(v_inv_patch->>'wrapping_charge', '')::numeric, 0)
        else wrapping_charge
      end,
      collection_source = case
        when v_inv_patch ? 'collection_source' and nullif(trim(v_inv_patch->>'collection_source'), '') is not null
          then (v_inv_patch->>'collection_source')::public.collection_source_type
        else collection_source
      end,
      updated_at = now()
    where id = p_invoice_id;

    v_has_changes := true;
  end if;

  if jsonb_typeof(v_remove_ids) = 'array' and jsonb_array_length(v_remove_ids) > 0 then
    for v_remove_id in
      select (value::text)::bigint
      from jsonb_array_elements(v_remove_ids) as t(value)
      where value is not null and value::text ~ '^[0-9]+$'
    loop
      delete from public.bill_lines
      where id = v_remove_id
        and invoice_id = p_invoice_id
      returning id into v_item_id;

      if v_item_id is not null then
        v_removed_ids := array_append(v_removed_ids, v_item_id);
        v_has_changes := true;
      end if;
    end loop;
  end if;

  if jsonb_typeof(v_items) = 'array' and jsonb_array_length(v_items) > 0 then
    for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
      v_item_id := nullif(v_item_elem->>'id', '')::bigint;

      if v_item_id is not null then
        select * into v_db_item
        from public.bill_lines
        where id = v_item_id
          and invoice_id = p_invoice_id;

        if v_db_item.id is null then
          return jsonb_build_object(
            'success', false,
            'error', format('invoice item %s not found on invoice', v_item_id),
            'code', 'NOT_FOUND'
          );
        end if;

        v_quantity := coalesce(
          case when v_item_elem ? 'quantity' then nullif(v_item_elem->>'quantity', '')::numeric else null end,
          v_db_item.quantity
        );
        v_sell_price := coalesce(
          case when v_item_elem ? 'sell_price_amount' then nullif(v_item_elem->>'sell_price_amount', '')::numeric else null end,
          v_db_item.sell_price_amount
        );
        v_line_discount := coalesce(
          case when v_item_elem ? 'line_discount_amount' then nullif(v_item_elem->>'line_discount_amount', '')::numeric else null end,
          v_db_item.line_discount_amount,
          0
        );

        if v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'quantity must be > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'sell_price_amount must be >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        update public.bill_lines
        set
          quantity = v_quantity,
          sell_price_amount = v_sell_price,
          line_discount_amount = v_line_discount,
          line_total_amount = v_line_total,
          name_snapshot = case
            when v_item_elem ? 'name_snapshot' then coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), name_snapshot)
            else name_snapshot
          end,
          updated_at = now()
        where id = v_item_id
        returning * into v_db_item;

        v_has_changes := true;
      elsif not v_dropship_sync then
        v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
        v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
        v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
        v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);

        if v_global_stock_id is null then
          return jsonb_build_object('success', false, 'error', 'new items require global_stock_id', 'code', 'VALIDATION_ERROR');
        end if;
        if v_quantity is null or v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'new items require quantity > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price is null or v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'new items require sell_price_amount >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        select
          gs.parent_tenant_id,
          gs.shipment_item_id,
          gsi.name,
          gsi.barcode,
          gsi.product_code,
          sh.assigned_child_tenant_id,
          p.id
        into
          v_stock_parent,
          v_shipment_item_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_assigned_child,
          v_product_id
        from public.global_stocks gs
        left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
        left join public.global_shipments sh on sh.id = gsi.shipment_id
        left join public.products p on p.id = gsi.product_id
        where gs.id = v_global_stock_id;

        if v_stock_parent is null then
          return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id), 'code', 'NOT_FOUND');
        end if;

        if v_stock_parent <> v_parent_id then
          return jsonb_build_object(
            'success', false,
            'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id),
            'code', 'VALIDATION_ERROR'
          );
        end if;

        v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
        v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
        v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
        v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
        v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
        v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);
        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        insert into public.bill_lines (
          tenant_id,
          invoice_id,
          global_stock_id,
          shipment_item_id,
          product_id,
          name_snapshot,
          barcode_snapshot,
          product_code_snapshot,
          quantity,
          sell_price_amount,
          line_discount_amount,
          line_total_amount,
          assigned_child_tenant_id
        )
        values (
          v_parent_id,
          p_invoice_id,
          v_global_stock_id,
          v_shipment_item_id,
          v_product_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_quantity,
          v_sell_price,
          v_line_discount,
          v_line_total,
          v_assigned_child
        )
        returning * into v_db_item;

        v_has_changes := true;
      end if;
    end loop;
  end if;

  if not v_has_changes then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  if v_recompute then
    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  select * into v_invoice from public.bills where id = p_invoice_id;

  if v_dropship_sync then
    if v_invoice.invoice_status in (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) then
      perform public.post_sales_invoice(p_invoice_id);
      select * into v_invoice from public.bills where id = p_invoice_id;
    elsif v_invoice.payment_status not in ('paid', 'partially_paid') then
      update public.bills
      set
        payment_status = 'due',
        due_amount = greatest(coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0), 0),
        updated_at = now()
      where id = p_invoice_id;
      select * into v_invoice from public.bills where id = p_invoice_id;
    end if;
    perform public.recompute_global_invoice_payment_status(p_invoice_id);
    select * into v_invoice from public.bills where id = p_invoice_id;
  end if;

  select coalesce(jsonb_agg(to_jsonb(sii.*) order by sii.id), '[]'::jsonb)
  into v_result_items
  from public.bill_lines sii
  where sii.invoice_id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'tenant_id', v_invoice.parent_tenant_id,
      'issued_by_tenant_id', v_invoice.issued_by_tenant_id,
      'invoice_type', v_invoice.invoice_type,
      'invoice_no', v_invoice.invoice_no,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'profile_id', v_invoice.profile_id,
      'recipient_profile_id', v_invoice.recipient_profile_id,
      'recipient_name', v_invoice.recipient_name,
      'recipient_phone', v_invoice.recipient_phone,
      'recipient_address', v_invoice.recipient_address,
      'collection_source', v_invoice.collection_source,
      'subtotal_amount', v_invoice.subtotal_amount,
      'discount_amount', v_invoice.discount_amount,
      'shipping_charge', v_invoice.shipping_charge,
      'cod_charge_amount', coalesce((v_invoice.channel_meta->>'cod_charge_amount')::numeric, 0),
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'note', v_invoice.note,
      'due_date', v_invoice.due_date,
      'invoice_date', v_invoice.invoice_date
    ),
    'items', v_result_items,
    'removed_item_ids', to_jsonb(v_removed_ids)
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm, 'code', 'VALIDATION_ERROR');
end;
$_$;


ALTER FUNCTION "public"."update_sales_invoice_from_payload"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";

-- upsert_pbc_backlog_from_item

CREATE OR REPLACE FUNCTION "public"."upsert_pbc_backlog_from_item"("p_costing_item_id" bigint) RETURNS "public"."product_based_costing_backlog_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.product_based_costing_items%rowtype;
  v_file public.product_based_costing_files%rowtype;
  v_prod record;
  v_confirmed_qty numeric;
  v_open_qty numeric;
  v_backlog_row public.product_based_costing_backlog_items;
  v_tenant_id bigint;
  v_price_gbp numeric;
begin
  select * into v_item
  from public.product_based_costing_items
  where id = p_costing_item_id;

  if v_item.id is null then
    return null;
  end if;

  select * into v_file
  from public.product_based_costing_files
  where id = v_item.product_based_costing_file_id;

  if v_file.id is null then
    raise exception 'costing file % not found', v_item.product_based_costing_file_id;
  end if;

  v_tenant_id := v_file.tenant_id;
  if v_tenant_id is null and v_file.profile_id is not null then
    select tenant_id into v_tenant_id
    from public.profiles
    where id = v_file.profile_id;
  end if;

  if v_tenant_id is not null and not (
    public.can_admin_manage_costing_file(v_tenant_id)
    or public.can_staff_access_costing_file(v_tenant_id)
  ) then
    raise exception 'access denied for tenant %', v_tenant_id;
  end if;

  if v_tenant_id is null or v_file.profile_id is null or v_item.product_id is null then
    return null;
  end if;

  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_open_qty := case
    when v_item.assigned_shipment_id is not null then 0
    when coalesce(v_file.status, 'pending') in ('pending', 'offered') then v_confirmed_qty
    else 0
  end;

  if v_confirmed_qty <= 0 or v_open_qty <= 0 then
    delete from public.product_based_costing_backlog_items
    where tenant_id = v_tenant_id
      and profile_id = v_file.profile_id
      and product_id = v_item.product_id;
    return null;
  end if;

  select
    p.name,
    p.image_url,
    p.list_price_amount,
    p.product_weight,
    p.package_weight,
    p.barcode,
    p.product_code,
    p.brand,
    gc.code as list_price_currency_code
  into v_prod
  from public.products p
  left join public.global_currencies gc on gc.id = p.list_price_currency_id
  where p.id = v_item.product_id;

  v_price_gbp := coalesce(
    v_item.price_gbp,
    case
      when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
        then v_prod.list_price_amount
      else null
    end
  );

  insert into public.product_based_costing_backlog_items (
    tenant_id,
    profile_id,
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
  values (
    v_tenant_id,
    v_file.profile_id,
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
  on conflict (tenant_id, profile_id, product_id)
  do update set
    open_quantity = excluded.open_quantity,
    name = excluded.name,
    image_url = excluded.image_url,
    barcode = excluded.barcode,
    product_code = excluded.product_code,
    price_gbp = excluded.price_gbp,
    product_weight = excluded.product_weight,
    package_weight = excluded.package_weight,
    last_costing_file_id = excluded.last_costing_file_id,
    last_costing_item_id = excluded.last_costing_item_id,
    updated_at = now()
  returning * into v_backlog_row;

  return v_backlog_row;
end;
$$;


ALTER FUNCTION "public"."upsert_pbc_backlog_from_item"("p_costing_item_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."preorder_demand" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "source_type" "public"."preorder_demand_source_type" NOT NULL,
    "source_id" bigint NOT NULL,
    "vendor_id" bigint,
    "placed_quantity" integer DEFAULT 0 NOT NULL,
    "delivered_quantity" integer DEFAULT 0 NOT NULL,
    "stock_picks" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL,
    "notes" "text",
    "updated_by_user_id" "uuid",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "profile_id" bigint,
    CONSTRAINT "preorder_demand_delivered_quantity_check" CHECK (("delivered_quantity" >= 0)),
    CONSTRAINT "preorder_demand_placed_quantity_check" CHECK (("placed_quantity" >= 0)),
    CONSTRAINT "preorder_demand_stock_picks_is_array" CHECK (("jsonb_typeof"("stock_picks") = 'array'::"text"))
);


ALTER TABLE "public"."preorder_demand" OWNER TO "postgres";

-- upsert_shop_product_listing

CREATE OR REPLACE FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric DEFAULT NULL::numeric, "p_minimum_sell_price_currency_id" bigint DEFAULT NULL::bigint, "p_show_quantity" boolean DEFAULT NULL::boolean, "p_display_quantity_override" integer DEFAULT NULL::integer, "p_is_active" boolean DEFAULT true, "p_id" bigint DEFAULT NULL::bigint) RETURNS SETOF "public"."shop_product_listings"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_global_stock_id bigint;
  v_product_id bigint;
begin
  -- Caller must be admin/staff of this tenant
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Resolve denormalized IDs
  select gsa.stock_id, gsi.product_id
  into v_global_stock_id, v_product_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gsa.id = p_global_stock_allocation_id;

  if v_global_stock_id is null or v_product_id is null then
    raise exception 'invalid global stock allocation';
  end if;

  -- Dropship dual money constraint
  if (p_minimum_sell_price_amount is null) <> (p_minimum_sell_price_currency_id is null) then
    raise exception 'both minimum_sell_price_amount and minimum_sell_price_currency_id must be provided together or be null';
  end if;

  return query
  insert into public.shop_product_listings (
    id,
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active
  )
  overriding system value
  values (
    coalesce(p_id, nextval(pg_get_serial_sequence('public.shop_product_listings', 'id'))),
    p_tenant_id,
    p_shop_id,
    p_global_stock_allocation_id,
    v_global_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    p_is_active
  )
  on conflict (shop_id, global_stock_allocation_id) do update set
    sell_price_amount = excluded.sell_price_amount,
    sell_price_currency_id = excluded.sell_price_currency_id,
    minimum_sell_price_amount = excluded.minimum_sell_price_amount,
    minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
    show_quantity = excluded.show_quantity,
    display_quantity_override = excluded.display_quantity_override,
    is_active = excluded.is_active,
    updated_at = now()
  returning *;
end;
$$;


ALTER FUNCTION "public"."upsert_shop_product_listing"("p_tenant_id" bigint, "p_shop_id" bigint, "p_global_stock_allocation_id" bigint, "p_sell_price_amount" numeric, "p_sell_price_currency_id" bigint, "p_minimum_sell_price_amount" numeric, "p_minimum_sell_price_currency_id" bigint, "p_show_quantity" boolean, "p_display_quantity_override" integer, "p_is_active" boolean, "p_id" bigint) OWNER TO "postgres";


-- products RLS (column refs)

DROP POLICY IF EXISTS "products_delete" ON public.products;
DROP POLICY IF EXISTS "products_insert" ON public.products;
DROP POLICY IF EXISTS "products_select" ON public.products;
DROP POLICY IF EXISTS "products_update" ON public.products;

CREATE POLICY "products_delete" ON "public"."products" FOR DELETE TO "authenticated" USING ("public"."can_manage_products_for_parent"("tenant_id"));

CREATE POLICY "products_insert" ON "public"."products" FOR INSERT TO "authenticated" WITH CHECK ("public"."can_manage_products_for_parent"("tenant_id"));

CREATE POLICY "products_select" ON "public"."products" FOR SELECT TO "authenticated" USING ("public"."can_view_products_for_parent"("tenant_id"));

CREATE POLICY "products_update" ON "public"."products" FOR UPDATE TO "authenticated" USING ("public"."can_manage_products_for_parent"("tenant_id")) WITH CHECK ("public"."can_manage_products_for_parent"("tenant_id"));
