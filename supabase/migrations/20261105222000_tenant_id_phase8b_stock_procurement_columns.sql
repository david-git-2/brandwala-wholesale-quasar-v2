-- Phase 8b: rename parent_tenant_id -> tenant_id on stock/procurement tables.

ALTER TABLE public.global_stocks RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.global_shipments RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.global_shipment_boxes RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.global_shipment_cost_entries RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.global_shipment_item_outcomes RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.global_shipment_outcome_vendor_credits RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.global_shipment_sections RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.stock_locations RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.cargo_companies RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.batch_code_lists RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.global_stock_types RENAME COLUMN parent_tenant_id TO tenant_id;
DO $$
BEGIN
  ALTER TABLE public.global_stock_allocations RENAME COLUMN parent_tenant_id TO tenant_id;
EXCEPTION
  WHEN undefined_table OR undefined_column THEN
    NULL;
END $$;

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

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_source_type = 'order_item' then
    -- Legacy Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.tenant_id = v_shipment.tenant_id
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
      and t.parent_id = v_shipment.tenant_id
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
      and t.parent_id = v_shipment.tenant_id
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

-- add_global_invoice_item

CREATE OR REPLACE FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric DEFAULT 0, "p_recipient_price_amount" numeric DEFAULT NULL::numeric) RETURNS "public"."bill_lines"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_stock public.global_stocks;
  v_row public.bill_lines;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_line_total numeric;
  v_product_id bigint;
  v_unit_cost numeric;
  v_qty_remaining numeric;
  v_avail numeric;
  v_take numeric;
  v_existing_qty numeric;
  v_curr_stock_id bigint;
  v_shipment_item_id bigint;
  v_assigned_child bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id;
  if v_invoice.id is null then
    raise exception 'invoice not found';
  end if;

  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot add items to a non-draft invoice';
  end if;

  select * into v_stock from public.global_stocks where id = p_global_stock_id;
  if v_stock.id is null then
    raise exception 'stock not found';
  end if;

  if v_stock.tenant_id <> v_invoice.parent_tenant_id then
    raise exception 'stock must belong to the same parent tenant group';
  end if;

  select product_id into v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  v_qty_remaining := p_quantity;
  v_curr_stock_id := p_global_stock_id;

  v_avail := public.global_stock_atp_qty(v_curr_stock_id);

  select coalesce(sum(quantity), 0) into v_existing_qty
  from public.bill_lines
  where invoice_id = p_invoice_id and global_stock_id = v_curr_stock_id;

  v_avail := greatest(v_avail - v_existing_qty, 0);

  if v_avail > 0 then
    v_take := least(v_qty_remaining, v_avail);

    select gsi.name, gsi.barcode, gsi.product_code, gsi.id, sh.assigned_child_tenant_id
    into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_shipment_item_id, v_assigned_child
    from public.global_shipment_items gsi
    join public.global_shipments sh on sh.id = gsi.shipment_id
    where gsi.id = (select shipment_item_id from public.global_stocks where id = v_curr_stock_id);

    v_line_total := greatest((v_take * p_sell_price_amount) - coalesce(p_line_discount_amount, 0.00), 0.00);
    v_unit_cost := coalesce(public.calculate_landed_unit_cost(v_shipment_item_id), 0.00);

    insert into public.bill_lines (
      parent_tenant_id,
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
      return_quantity,
      assigned_child_tenant_id
    )
    values (
      v_invoice.parent_tenant_id,
      p_invoice_id,
      v_curr_stock_id,
      v_shipment_item_id,
      v_product_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_take,
      p_sell_price_amount,
      coalesce(p_line_discount_amount, 0.00),
      v_line_total,
      0.00,
      v_assigned_child
    )
    returning * into v_row;

    v_qty_remaining := v_qty_remaining - v_take;
  end if;

  if v_qty_remaining > 0 then
    raise exception 'insufficient stock: requested %, available %', p_quantity, (p_quantity - v_qty_remaining);
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;


ALTER FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric, "p_recipient_price_amount" numeric) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."sales_return_items" (
    "id" bigint NOT NULL,
    "parent_tenant_id" bigint NOT NULL,
    "invoice_id" bigint NOT NULL,
    "invoice_item_id" bigint NOT NULL,
    "global_stock_id" bigint,
    "quantity" numeric(12,3) NOT NULL,
    "return_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "note" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "global_return_items_quantity_check" CHECK (("quantity" > (0)::numeric)),
    CONSTRAINT "global_return_items_return_charge_amount_check" CHECK (("return_charge_amount" >= (0)::numeric))
);


ALTER TABLE "public"."sales_return_items" OWNER TO "postgres";

-- add_global_shipment_item

CREATE OR REPLACE FUNCTION "public"."add_global_shipment_item"("p_shipment_id" bigint, "p_item" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_next_sort integer;
  v_section_id bigint;
  v_product_id bigint;
  v_row public.global_shipment_items;
  v_outcome public.global_shipment_item_outcomes;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  v_section_id := nullif((p_item->>'section_id'), '')::bigint;
  v_product_id := nullif((p_item->>'product_id'), '')::bigint;

  if public.global_shipment_item_conflicts_in_section(
    p_shipment_id,
    v_section_id,
    v_product_id,
    p_item->>'barcode',
    p_item->>'product_code',
    null
  ) then
    raise exception 'This product is already on this shipment section';
  end if;

  select s.tenant_id
  into v_parent_tenant_id
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_parent_tenant_id is null then
    raise exception 'Shipment not found';
  end if;

  select coalesce(max(sort_order), 0) + 10
  into v_next_sort
  from public.global_shipment_items
  where shipment_id = p_shipment_id;

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
    v_section_id,
    v_product_id,
    nullif((p_item->>'vendor_id'), '')::bigint,
    coalesce(p_item->>'name', 'Unnamed Item'),
    greatest(1, coalesce((p_item->>'ordered_quantity')::integer, 1)),
    p_item->>'image_url',
    coalesce((p_item->>'add_method')::public.global_shipment_item_add_method, 'manual'::public.global_shipment_item_add_method),
    greatest(0, coalesce((p_item->>'purchase_price')::numeric, 0)),
    greatest(0, coalesce((p_item->>'product_weight')::numeric, 0)),
    greatest(0, coalesce((p_item->>'package_weight')::numeric, 0)),
    p_item->>'barcode',
    p_item->>'product_code',
    nullif((p_item->>'source_child_tenant_id'), '')::bigint,
    p_item->>'source_type',
    nullif((p_item->>'source_id'), '')::bigint,
    coalesce((p_item->>'sort_order')::integer, v_next_sort)
  )
  returning * into v_row;

  insert into public.global_shipment_item_outcomes (
    parent_tenant_id,
    shipment_item_id,
    quantity,
    kind,
    reason,
    purchase_price,
    cost
  )
  values (
    v_parent_tenant_id,
    v_row.id,
    v_row.ordered_quantity,
    'sellable'::public.global_shipment_outcome_kind,
    'ordered'::public.global_shipment_outcome_reason,
    greatest(0, coalesce(v_row.purchase_price, 0)),
    v_row.landed_cost_bdt
  )
  returning * into v_outcome;

  return jsonb_build_object(
    'item', to_jsonb(v_row),
    'ordered_outcome', to_jsonb(v_outcome)
  );
end;
$$;


ALTER FUNCTION "public"."add_global_shipment_item"("p_shipment_id" bigint, "p_item" "jsonb") OWNER TO "postgres";

-- add_shop_order_item_stock_pick

CREATE OR REPLACE FUNCTION "public"."add_shop_order_item_stock_pick"("p_order_item_id" bigint, "p_global_stock_id" bigint, "p_quantity" integer, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_held_stock_id bigint;
  v_parent_tenant_id bigint;
  v_existing_qty integer := 0;
  v_total_picked integer := 0;
  v_pick_id bigint;
  v_grade_tag_id bigint;
  v_confirmed_qty numeric;
  v_fulfillment_resolved boolean;
  v_pick_list jsonb;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'stock pick is only allowed while order is processing';
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is marked unavailable';
  end if;

  v_grade_tag_id := coalesce(v_item.grade_tag_id, public.default_stock_grade_tag_id());

  select * into v_stock
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = p_global_stock_id
    and gsi.product_id = v_item.product_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
  for update of gs;

  if v_stock.id is null then
    raise exception 'stock not found or does not match line product/grade';
  end if;

  if v_stock.availability <> 'sellable'::public.stock_availability then
    raise exception 'stock is not sellable';
  end if;

  if public.global_stock_atp_qty(v_stock.id) < p_quantity then
    raise exception 'insufficient ATP (requested %, available %)', p_quantity, public.global_stock_atp_qty(v_stock.id);
  end if;

  select coalesce(sum(sp.quantity), 0)
  into v_total_picked
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  select coalesce(sp.quantity, 0)
  into v_existing_qty
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id
    and sp.global_stock_id = p_global_stock_id;

  if v_total_picked - v_existing_qty + p_quantity > v_item.quantity then
    raise exception 'pick quantity exceeds ordered qty (ordered %, would pick %)',
      v_item.quantity, v_total_picked - v_existing_qty + p_quantity;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  perform public.create_and_post_stock_movement(
    p_tenant_id => v_parent_tenant_id,
    p_stock_id => v_stock.id,
    p_quantity => p_quantity,
    p_to_location_id => v_stock.location_id,
    p_to_availability => 'held'::public.stock_availability,
    p_to_grade_tag_id => v_stock.grade_tag_id,
    p_movement_type => 'availability_transfer'::public.stock_movement_type,
    p_notes => 'Dropship processing pick',
    p_reference_type => 'shop_order',
    p_reference_id => v_order.id::text
  );

  select gs.id into v_held_stock_id
  from public.global_stocks gs
  where gs.shipment_item_id = v_stock.shipment_item_id
    and gs.tenant_id = v_parent_tenant_id
    and gs.availability = 'held'::public.stock_availability
    and gs.location_id is not distinct from v_stock.location_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  order by gs.id desc
  limit 1;

  insert into public.shop_order_item_stock_picks (
    tenant_id, order_id, order_item_id, global_stock_id,
    shipment_item_id, shipment_id, quantity, held_stock_id, created_by_email
  )
  values (
    v_order.tenant_id, v_order.id, v_item.id, v_stock.id,
    v_stock.shipment_item_id,
    (select shipment_id from public.global_shipment_items where id = v_stock.shipment_item_id),
    p_quantity, v_held_stock_id, public.current_user_email()
  )
  on conflict (order_item_id, global_stock_id) do update
  set
    quantity = public.shop_order_item_stock_picks.quantity + excluded.quantity,
    held_stock_id = excluded.held_stock_id,
    updated_at = now()
  returning id into v_pick_id;

  perform public._recompute_shop_order_item_fulfillment(p_order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  select
    soi.confirmed_quantity,
    coalesce(soi.is_fulfillment_unavailable, false)
      or coalesce(soi.confirmed_quantity, 0) > 0
      or (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'customer_stock'
        and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
      )
      or (coalesce(soi.is_gift, false) and soi.gift_source = 'stock')
  into v_confirmed_qty, v_fulfillment_resolved
  from public.shop_order_items soi
  where soi.id = p_order_item_id;

  v_pick_list := public.list_stock_for_order_item_pick(
    p_order_item_id,
    p_search,
    p_limit,
    p_offset
  );

  return jsonb_build_object(
    'success', true,
    'pick_id', v_pick_id,
    'confirmed_quantity', v_confirmed_qty,
    'cod_collect_amount', (select cod_collect_amount from public.shop_orders where id = v_order.id),
    'order_line', jsonb_build_object(
      'id', p_order_item_id,
      'confirmed_quantity', v_confirmed_qty,
      'fulfillment_resolved', v_fulfillment_resolved
    ),
    'pick_list', v_pick_list
  );
end;
$$;


ALTER FUNCTION "public"."add_shop_order_item_stock_pick"("p_order_item_id" bigint, "p_global_stock_id" bigint, "p_quantity" integer, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- apply_shipment_outcome_vendor_discount

CREATE OR REPLACE FUNCTION "public"."apply_shipment_outcome_vendor_discount"("p_shipment_id" bigint, "p_source_outcome_id" bigint, "p_quantity" integer, "p_new_purchase_price" numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_src public.global_shipment_item_outcomes%rowtype;
  v_parent bigint;
  v_prev_price numeric;
  v_credit numeric;
  v_row_id bigint;
begin
  if p_quantity is null or p_quantity < 1 then
    raise exception 'quantity must be at least 1';
  end if;

  if p_new_purchase_price is null or p_new_purchase_price < 0 then
    raise exception 'purchase price must be >= 0';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.tenant_id;
  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  if v_ship.status <> 'received' then
    raise exception 'shipment must be received to record vendor credit';
  end if;

  select o.* into v_src
  from public.global_shipment_item_outcomes o
  inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
  where o.id = p_source_outcome_id
    and gsi.shipment_id = p_shipment_id;

  if not found then
    raise exception 'outcome not found on shipment';
  end if;

  if v_src.reason = 'ordered'::public.global_shipment_outcome_reason then
    raise exception 'cannot credit ordered row';
  end if;

  if v_src.kind <> 'sellable'::public.global_shipment_outcome_kind then
    raise exception 'outcome must be sellable';
  end if;

  if p_quantity > v_src.quantity then
    raise exception 'quantity % exceeds split qty %', p_quantity, v_src.quantity;
  end if;

  v_prev_price := coalesce(v_src.purchase_price, 0);
  v_credit := round((v_prev_price - p_new_purchase_price) * p_quantity, 4);

  insert into public.global_shipment_outcome_vendor_credits (
    parent_tenant_id,
    shipment_id,
    shipment_item_id,
    outcome_id,
    quantity,
    previous_purchase_price,
    new_purchase_price,
    credit_amount,
    created_by_email
  ) values (
    v_parent,
    p_shipment_id,
    v_src.shipment_item_id,
    v_src.id,
    p_quantity,
    v_prev_price,
    p_new_purchase_price,
    v_credit,
    public.current_user_email()
  )
  returning id into v_row_id;

  return jsonb_build_object(
    'mode', 'record',
    'id', v_row_id,
    'shipment_id', p_shipment_id,
    'outcome_id', v_src.id,
    'quantity', p_quantity,
    'previous_purchase_price', v_prev_price,
    'new_purchase_price', p_new_purchase_price,
    'credit_amount', v_credit
  );
end;
$$;


ALTER FUNCTION "public"."apply_shipment_outcome_vendor_discount"("p_shipment_id" bigint, "p_source_outcome_id" bigint, "p_quantity" integer, "p_new_purchase_price" numeric) OWNER TO "postgres";

-- archive_shipment

CREATE OR REPLACE FUNCTION "public"."archive_shipment"("p_id" bigint) RETURNS "public"."global_shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.global_shipments
  set is_archived = true,
      archived_at = now(),
      updated_at = now()
  where id = p_id
  returning * into v_ship;

  perform public._set_global_stocks_archived_for_shipment(p_id, true);

  return v_ship;
end;
$$;


ALTER FUNCTION "public"."archive_shipment"("p_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shipment_progress_flows" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "slug" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."shipment_progress_flows" OWNER TO "postgres";

-- backfill_document_number_counters_from_tenant_shipments

CREATE OR REPLACE FUNCTION "public"."backfill_document_number_counters_from_tenant_shipments"() RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.document_number_counters (tenant_id, doc_type, sub_type, period_key, last_value)
  SELECT
    h.tenant_id,
    'shipment',
    '',
    '',
    GREATEST(
      h.max_shipment_id,
      coalesce((
        SELECT tsc.last_value
        FROM public.tenant_scoped_counters tsc
        WHERE tsc.tenant_id = h.tenant_id
          AND tsc.scope = 'shipment'
      ), 0)
    )
  FROM (
    SELECT u.tenant_id, max(u.max_shipment_id) AS max_shipment_id
    FROM (
      SELECT gs.tenant_id AS tenant_id, max(gs.tenant_shipment_id)::bigint AS max_shipment_id
      FROM public.global_shipments gs
      WHERE gs.tenant_id IS NOT NULL
        AND gs.tenant_shipment_id IS NOT NULL
      GROUP BY gs.tenant_id
      UNION ALL
      SELECT s.tenant_id, max(s.tenant_shipment_id)::bigint AS max_shipment_id
      FROM public.shipments s
      GROUP BY s.tenant_id
    ) u
    GROUP BY u.tenant_id
  ) h
  ON CONFLICT (tenant_id, doc_type, sub_type, period_key)
  DO UPDATE SET last_value = GREATEST(public.document_number_counters.last_value, EXCLUDED.last_value);

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;


ALTER FUNCTION "public"."backfill_document_number_counters_from_tenant_shipments"() OWNER TO "postgres";

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

-- bulk_add_global_shipment_items

CREATE OR REPLACE FUNCTION "public"."bulk_add_global_shipment_items"("p_shipment_id" bigint, "p_items" "jsonb") RETURNS SETOF "public"."global_shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item jsonb;
  v_next_sort integer;
  v_parent_tenant_id bigint;
  v_section_id bigint;
  v_product_id bigint;
  v_new_item public.global_shipment_items;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select s.tenant_id
  into v_parent_tenant_id
  from public.global_shipments s
  where s.id = p_shipment_id;

  if v_parent_tenant_id is null then
    raise exception 'Shipment not found';
  end if;

  select coalesce(max(sort_order), 0) + 10
  into v_next_sort
  from public.global_shipment_items
  where shipment_id = p_shipment_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_section_id := nullif((v_item->>'section_id'), '')::bigint;
    v_product_id := nullif((v_item->>'product_id'), '')::bigint;

    if public.global_shipment_item_conflicts_in_section(
      p_shipment_id,
      v_section_id,
      v_product_id,
      v_item->>'barcode',
      v_item->>'product_code',
      null
    ) then
      continue;
    end if;

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
      v_section_id,
      v_product_id,
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
    )
    returning * into v_new_item;

    insert into public.global_shipment_item_outcomes (
      parent_tenant_id,
      shipment_item_id,
      quantity,
      kind,
      reason,
      purchase_price,
      cost
    )
    values (
      v_parent_tenant_id,
      v_new_item.id,
      v_new_item.ordered_quantity,
      'sellable'::public.global_shipment_outcome_kind,
      'ordered'::public.global_shipment_outcome_reason,
      greatest(0, coalesce(v_new_item.purchase_price, 0)),
      v_new_item.landed_cost_bdt
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

-- bulk_allocate_shipment_stock

CREATE OR REPLACE FUNCTION "public"."bulk_allocate_shipment_stock"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_child_tenant_id" bigint) RETURNS integer
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
    where id = p_child_tenant_id and parent_id = p_tenant_id
  ) then
    raise exception 'Child tenant % does not belong to parent tenant %', p_child_tenant_id, p_tenant_id;
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
    where gs.tenant_id = p_tenant_id
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
      insert into public.global_stock_allocations (tenant_id, child_tenant_id, stock_id, quantity)
      values (p_tenant_id, p_child_tenant_id, v_rec.stock_id, v_remaining_qty)
      on conflict (child_tenant_id, stock_id)
      do update set quantity = v_remaining_qty, updated_at = now();

      v_updated_count := v_updated_count + 1;
    end if;
  end loop;

  return v_updated_count;
end;
$$;


ALTER FUNCTION "public"."bulk_allocate_shipment_stock"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_child_tenant_id" bigint) OWNER TO "postgres";

-- bulk_update_global_shipment_items

CREATE OR REPLACE FUNCTION "public"."bulk_update_global_shipment_items"("p_shipment_id" bigint, "p_updates" "jsonb") RETURNS SETOF "public"."global_shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_update jsonb;
  v_id bigint;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  IF p_shipment_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id is required';
  END IF;

  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  PERFORM set_config('app.skip_item_landed_restamp', '1', true);

  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    v_id := (v_update->>'id')::bigint;
    IF v_id IS NOT NULL THEN
      UPDATE public.global_shipment_items
      SET
        section_id = CASE
          WHEN v_update ? 'section_id' THEN nullif((v_update->>'section_id'), '')::bigint
          ELSE section_id
        END,
        vendor_id = CASE
          WHEN v_update ? 'vendor_id' THEN nullif((v_update->>'vendor_id'), '')::bigint
          ELSE vendor_id
        END,
        ordered_quantity = CASE
          WHEN v_update ? 'ordered_quantity' AND (v_update->>'ordered_quantity') IS NOT NULL THEN greatest(1, (v_update->>'ordered_quantity')::integer)
          ELSE ordered_quantity
        END,
        purchase_price = CASE
          WHEN v_update ? 'purchase_price' AND (v_update->>'purchase_price') IS NOT NULL THEN greatest(0, (v_update->>'purchase_price')::numeric)
          ELSE purchase_price
        END,
        product_weight = CASE
          WHEN v_update ? 'product_weight' AND (v_update->>'product_weight') IS NOT NULL THEN greatest(0, (v_update->>'product_weight')::numeric)
          ELSE product_weight
        END,
        package_weight = CASE
          WHEN v_update ? 'package_weight' AND (v_update->>'package_weight') IS NOT NULL THEN greatest(0, (v_update->>'package_weight')::numeric)
          ELSE package_weight
        END,
        barcode = CASE
          WHEN v_update ? 'barcode' THEN v_update->>'barcode'
          ELSE barcode
        END,
        product_code = CASE
          WHEN v_update ? 'product_code' THEN v_update->>'product_code'
          ELSE product_code
        END,
        name = CASE
          WHEN v_update ? 'name' AND (v_update->>'name') IS NOT NULL THEN v_update->>'name'
          ELSE name
        END,
        updated_at = now()
      WHERE id = v_id AND shipment_id = p_shipment_id;
    END IF;
  END LOOP;

  PERFORM set_config('app.skip_item_landed_restamp', '0', true);

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = p_shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.global_shipment_items
  WHERE shipment_id = p_shipment_id
  ORDER BY sort_order ASC, id ASC;
END;
$$;


ALTER FUNCTION "public"."bulk_update_global_shipment_items"("p_shipment_id" bigint, "p_updates" "jsonb") OWNER TO "postgres";

-- close_global_shipment

CREATE OR REPLACE FUNCTION "public"."close_global_shipment"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if v_ship.id is null then
    return jsonb_build_object('success', false, 'error', 'shipment not found');
  end if;
  if not public.is_tenant_staff(v_ship.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;
  if coalesce(v_ship.is_closed, false) then
    return jsonb_build_object('success', true, 'message', 'already closed');
  end if;
  update public.global_shipments
  set is_closed = true, updated_at = now()
  where id = p_shipment_id;
  return jsonb_build_object('success', true, 'is_closed', true);
end;
$$;


ALTER FUNCTION "public"."close_global_shipment"("p_shipment_id" bigint) OWNER TO "postgres";

-- create_cargo_company_with_wallet

CREATE OR REPLACE FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.cargo_companies;
  v_wallet public.cashbook_accounts;
  v_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

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

  if exists (
    select 1 from public.tenants t where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'cargo companies belong on parent tenants only';
  end if;

  v_code := upper(trim(p_code));
  if v_code is null or v_code = '' then
    raise exception 'code is required';
  end if;

  if v_code = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default cargo company';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  insert into public.cargo_companies (
    parent_tenant_id,
    name,
    code,
    email,
    phone,
    address,
    notes,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_code,
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_notes), ''),
    false,
    true
  )
  returning * into v_row;

  insert into public.cashbook_accounts (
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
    'cargo_company',
    v_row.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'cargo_company', to_jsonb(v_row),
    'wallet', to_jsonb(v_wallet)
  );
end;
$$;


ALTER FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text", "p_phone" "text", "p_address" "text", "p_notes" "text") OWNER TO "postgres";

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
      gs.tenant_id,
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

-- create_shipment_draft

CREATE OR REPLACE FUNCTION "public"."create_shipment_draft"("p_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint DEFAULT NULL::bigint, "p_cargo_company_id" bigint DEFAULT NULL::bigint) RETURNS "public"."global_shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stock_parent bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_row public.global_shipments%rowtype;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if p_type is null then
    raise exception 'type is required';
  end if;

  v_stock_parent := public.resolve_parent_tenant_id(p_tenant_id);

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
        and v.parent_tenant_id = v_stock_parent
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
        and c.parent_tenant_id = v_stock_parent
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

  perform public.ensure_global_shipment_default_section(v_row.id);

  return v_row;
end;
$$;


ALTER FUNCTION "public"."create_shipment_draft"("p_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint, "p_cargo_company_id" bigint) OWNER TO "postgres";

-- default_putaway_stock_location_id

CREATE OR REPLACE FUNCTION "public"."default_putaway_stock_location_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_loc bigint;
begin
  select sl.id into v_loc
  from public.stock_locations sl
  where sl.tenant_id = p_tenant_id
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

-- default_returns_stock_location_id

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
  where sl.tenant_id = p_tenant_id
    and sl.is_active = true
    and sl.kind = 'returns'::public.stock_location_kind
  order by sl.sort_order, sl.id
  limit 1;

  if v_loc is not null then
    return v_loc;
  end if;

  insert into public.stock_locations (
    tenant_id, parent_location_id, code, name, kind,
    is_default, is_pickable, sort_order, is_active
  ) values (
    p_tenant_id, null, 'RETURNS', 'Returns', 'returns',
    false, false, 100, true
  )
  on conflict (tenant_id, code) do update
    set kind = 'returns'::public.stock_location_kind,
        is_active = true,
        is_pickable = false
  returning id into v_loc;

  return v_loc;
end;
$$;


ALTER FUNCTION "public"."default_returns_stock_location_id"("p_tenant_id" bigint) OWNER TO "postgres";

-- default_sellable_global_stock_type_id

CREATE OR REPLACE FUNCTION "public"."default_sellable_global_stock_type_id"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select gst.id
  from public.global_stock_types gst
  where (gst.tenant_id is null or gst.tenant_id = p_tenant_id)
    and gst.is_sellable = true
    and (
      lower(trim(gst.description)) = 'standard sellable'
      or gst.description ilike '%Standard%Sellable%'
      or gst.description ilike 'Standard%'
    )
  order by gst.tenant_id nulls first, gst.sort_order, gst.id
  limit 1;
$$;


ALTER FUNCTION "public"."default_sellable_global_stock_type_id"("p_tenant_id" bigint) OWNER TO "postgres";

-- delete_global_shipment_cost_entry

CREATE OR REPLACE FUNCTION "public"."delete_global_shipment_cost_entry"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_entry public.global_shipment_cost_entries%ROWTYPE;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM public.global_shipment_cost_entries WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'cost entry not found';
  END IF;

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = v_entry.shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  DELETE FROM public.global_shipment_cost_entries WHERE id = p_id;

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = v_entry.shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(v_entry.shipment_id);
  END IF;
END;
$$;


ALTER FUNCTION "public"."delete_global_shipment_cost_entry"("p_id" bigint) OWNER TO "postgres";

-- delete_shipment_outcome_vendor_credit

CREATE OR REPLACE FUNCTION "public"."delete_shipment_outcome_vendor_credit"("p_credit_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_credit public.global_shipment_outcome_vendor_credits%rowtype;
  v_ship public.global_shipments%rowtype;
begin
  if p_credit_id is null then
    raise exception 'credit id required';
  end if;

  select * into v_credit
  from public.global_shipment_outcome_vendor_credits
  where id = p_credit_id;

  if not found then
    raise exception 'vendor credit not found';
  end if;

  select * into v_ship
  from public.global_shipments
  where id = v_credit.shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  if v_ship.status <> 'received' then
    raise exception 'shipment must be received to remove vendor credit';
  end if;

  delete from public.global_shipment_outcome_vendor_credits
  where id = p_credit_id;
end;
$$;


ALTER FUNCTION "public"."delete_shipment_outcome_vendor_credit"("p_credit_id" bigint) OWNER TO "postgres";

-- ensure_default_cargo_company

CREATE OR REPLACE FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_id bigint;
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

  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_cargo_company requires a parent tenant (got child %)', p_tenant_id;
  end if;

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

  select id into v_id
  from public.cargo_companies
  where parent_tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  select id into v_id
  from public.cargo_companies
  where parent_tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_id is not null then
    update public.cargo_companies
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Cargo Company'),
        is_active = true,
        updated_at = now()
    where id = v_id;
    return v_id;
  end if;

  insert into public.cargo_companies (
    parent_tenant_id,
    name,
    code,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    'Default Cargo Company',
    'DEFAULT',
    true,
    true
  )
  returning id into v_id;

  insert into public.cashbook_accounts (
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
    'cargo_company',
    v_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_id;
end;
$$;


ALTER FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) OWNER TO "postgres";

-- ensure_default_stock_location

CREATE OR REPLACE FUNCTION "public"."ensure_default_stock_location"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant public.tenants%rowtype;
  v_loc_id bigint;
  v_wh bigint;
  v_zone bigint;
  v_shelf bigint;
  v_level bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant from public.tenants where id = p_tenant_id;
  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    return public.ensure_default_stock_location(v_tenant.parent_id);
  end if;

  select sl.id into v_loc_id
  from public.stock_locations sl
  where sl.tenant_id = p_tenant_id
    and sl.is_active = true
    and public._stock_location_is_leaf(sl.id)
  order by sl.is_default desc, sl.is_pickable desc, sl.sort_order, sl.id
  limit 1;

  if v_loc_id is not null then
    return v_loc_id;
  end if;

  insert into public.stock_locations (
    tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, null, 'MAIN', 'Main warehouse', 'warehouse',
    false, false, true, 10
  )
  on conflict (tenant_id, code) do update
    set kind = 'warehouse'::public.stock_location_kind,
        name = excluded.name,
        is_active = true
  returning id into v_wh;

  if v_wh is null then
    select id into v_wh from public.stock_locations
    where tenant_id = p_tenant_id and code = 'MAIN';
  end if;

  insert into public.stock_locations (
    tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_wh, 'MAIN-ZONE', 'Default zone', 'zone',
    false, false, true, 20
  )
  on conflict (tenant_id, code) do update
    set parent_location_id = v_wh,
        kind = 'zone'::public.stock_location_kind,
        is_active = true
  returning id into v_zone;

  if v_zone is null then
    select id into v_zone from public.stock_locations
    where tenant_id = p_tenant_id and code = 'MAIN-ZONE';
  end if;

  insert into public.stock_locations (
    tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_zone, 'MAIN-SHELF', 'Default shelf', 'shelf',
    false, false, true, 30
  )
  on conflict (tenant_id, code) do update
    set parent_location_id = v_zone,
        kind = 'shelf'::public.stock_location_kind,
        is_active = true
  returning id into v_shelf;

  if v_shelf is null then
    select id into v_shelf from public.stock_locations
    where tenant_id = p_tenant_id and code = 'MAIN-SHELF';
  end if;

  insert into public.stock_locations (
    tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_shelf, 'MAIN-LEVEL', 'Default level', 'level',
    false, false, true, 40
  )
  on conflict (tenant_id, code) do update
    set parent_location_id = v_shelf,
        kind = 'level'::public.stock_location_kind,
        is_active = true
  returning id into v_level;

  if v_level is null then
    select id into v_level from public.stock_locations
    where tenant_id = p_tenant_id and code = 'MAIN-LEVEL';
  end if;

  insert into public.stock_locations (
    tenant_id, parent_location_id, code, name, kind,
    is_pickable, is_default, is_active, sort_order
  ) values (
    p_tenant_id, v_level, 'MAIN-BIN', 'Default bin', 'bin',
    true, true, true, 50
  )
  on conflict (tenant_id, code) do update
    set parent_location_id = v_level,
        kind = 'bin'::public.stock_location_kind,
        is_pickable = true,
        is_default = true,
        is_active = true
  returning id into v_loc_id;

  if v_loc_id is null then
    select id into v_loc_id from public.stock_locations
    where tenant_id = p_tenant_id and code = 'MAIN-BIN';
  end if;

  return v_loc_id;
end;
$$;


ALTER FUNCTION "public"."ensure_default_stock_location"("p_tenant_id" bigint) OWNER TO "postgres";

-- ensure_global_shipment_cost_entries_from_header

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
    parent_tenant_id,
    shipment_id,
    cost_bucket,
    cost_component,
    is_capitalizable,
    amount,
    currency_id,
    metadata
  ) values (
    v_ship.tenant_id,
    p_shipment_id,
    'material',
    'subtotal',
    true,
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    jsonb_build_object('source', 'header_backfill')
  );

  if v_cargo_amt > 0 then
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.tenant_id,
      p_shipment_id,
      'freight',
      'subtotal',
      true,
      v_cargo_amt,
      v_ship.shipment_cost_currency_id,
      jsonb_build_object('source', 'header_backfill')
    );
  end if;
end;
$$;


ALTER FUNCTION "public"."ensure_global_shipment_cost_entries_from_header"("p_shipment_id" bigint) OWNER TO "postgres";

-- ensure_global_shipment_default_section

CREATE OR REPLACE FUNCTION "public"."ensure_global_shipment_default_section"("p_shipment_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_section_id bigint;
  v_vendor_id bigint;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if not found then
    raise exception 'shipment not found';
  end if;

  select s.id into v_section_id
  from public.global_shipment_sections s
  where s.shipment_id = p_shipment_id
  order by s.sort_order asc, s.id asc
  limit 1;

  if v_section_id is not null then
    return v_section_id;
  end if;

  v_vendor_id := v_ship.vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_ship.tenant_id);
  end if;

  insert into public.global_shipment_sections (
    parent_tenant_id,
    shipment_id,
    vendor_id,
    title,
    sort_order,
    metadata
  )
  values (
    v_ship.tenant_id,
    p_shipment_id,
    v_vendor_id,
    'Section 1',
    0,
    '{}'::jsonb
  )
  returning id into v_section_id;

  return v_section_id;
end;
$$;


ALTER FUNCTION "public"."ensure_global_shipment_default_section"("p_shipment_id" bigint) OWNER TO "postgres";

-- fill_preorder_demand_oldest_stock_for_document

CREATE OR REPLACE FUNCTION "public"."fill_preorder_demand_oldest_stock_for_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_parent_tenant_id bigint;
  v_updated integer := 0;
  v_skipped integer := 0;
  r record;
  v_stock record;
  v_total_avail integer := 0;
  v_remaining integer;
  v_avail integer;
  v_take integer;
  v_picks jsonb;
  v_delivered integer;
  v_db_reserved integer;
  v_run_reserved integer;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  create temp table if not exists fifo_run_pick_reserve (
    global_stock_id bigint primary key,
    reserved_qty integer not null default 0
  ) on commit delete rows;
  delete from fifo_run_pick_reserve where true;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status not in ('procuring', 'packed') then
    raise exception 'document is not open for stock pick updates';
  end if;

  select coalesce(t.parent_id, t.id) into v_parent_tenant_id
  from public.tenants t
  where t.id = v_line_tenant_id;

  for r in
    select
      q.source_type,
      q.source_id,
      q.tenant_id,
      q.product_id,
      q.need_qty
    from (
      select
        'shop_order_item'::public.preorder_demand_source_type as source_type,
        oi.id as source_id,
        o.tenant_id,
        oi.product_id,
        greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as need_qty
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where v_doc_type = 'shop_order'
        and o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
      union all
      select
        'pbc_costing_item'::public.preorder_demand_source_type,
        pci.id,
        f.tenant_id,
        pci.product_id,
        greatest(
          case
            when pci.assigned_shipment_id is not null then 0
            else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
          end,
          0
        )::integer
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where v_doc_type = 'pbc_costing_file'
        and f.id = p_document_id
        and f.profile_id is not null
    ) q
    order by q.source_id
  loop
    if r.product_id is null or r.need_qty <= 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if exists (
      select 1
      from public.preorder_demand pd
      where pd.source_type = r.source_type
        and pd.source_id = r.source_id
        and public.sum_preorder_stock_picks(pd.stock_picks) > 0
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_total_avail := 0;
    for v_stock in
      select
        gs.id as global_stock_id,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.tenant_id = v_parent_tenant_id
        and gs.is_archived = false
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      v_total_avail := v_total_avail + v_avail;
    end loop;

    if v_total_avail < r.need_qty then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_picks := '[]'::jsonb;
    v_remaining := r.need_qty;

    for v_stock in
      select
        gs.id as global_stock_id,
        sh.name as shipment_name,
        sl.name as location_name,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      inner join public.global_shipments sh on sh.id = gsi.shipment_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.tenant_id = v_parent_tenant_id
        and gs.is_archived = false
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      if v_avail <= 0 then
        continue;
      end if;

      v_take := least(v_avail, v_remaining);
      v_picks := v_picks || jsonb_build_array(
        jsonb_build_object(
          'global_stock_id', v_stock.global_stock_id,
          'quantity', v_take,
          'shipment_name', coalesce(v_stock.shipment_name, ''),
          'location_name', coalesce(v_stock.location_name, '')
        )
      );

      insert into fifo_run_pick_reserve (global_stock_id, reserved_qty)
      values (v_stock.global_stock_id, v_take)
      on conflict (global_stock_id) do update
        set reserved_qty = fifo_run_pick_reserve.reserved_qty + excluded.reserved_qty;

      v_remaining := v_remaining - v_take;
      if v_remaining <= 0 then
        exit;
      end if;
    end loop;

    if v_remaining > 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_delivered := public.sum_preorder_stock_picks(v_picks);

    insert into public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      placed_quantity,
      delivered_quantity,
      stock_picks,
      updated_by_user_id
    ) values (
      r.tenant_id,
      r.source_type,
      r.source_id,
      0,
      v_delivered,
      v_picks,
      auth.uid()
    )
    on conflict (source_type, source_id) do update set
      delivered_quantity = excluded.delivered_quantity,
      stock_picks = excluded.stock_picks,
      updated_by_user_id = auth.uid(),
      updated_at = now();

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'updated_count', v_updated,
    'skipped_count', v_skipped
  );
end;
$$;


ALTER FUNCTION "public"."fill_preorder_demand_oldest_stock_for_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) OWNER TO "postgres";

-- generate_shipment_tracking_token

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

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_token := replace(gen_random_uuid()::text, '-', '');

  update public.global_shipments
  set public_tracking_token = v_token, updated_at = now()
  where id = p_shipment_id;

  return v_token;
end;
$$;


ALTER FUNCTION "public"."generate_shipment_tracking_token"("p_shipment_id" bigint) OWNER TO "postgres";

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
  where gs.tenant_id = p_tenant_id
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

-- get_procurement_dashboard_metrics

CREATE OR REPLACE FUNCTION "public"."get_procurement_dashboard_metrics"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_sellable bigint := 0;
  v_held bigint := 0;
  v_unsellable bigint := 0;
  v_total bigint := 0;
  v_value numeric := 0;
  v_in_transit bigint := 0;
  v_draft bigint := 0;
  v_received bigint := 0;
  v_grades jsonb := '[]'::jsonb;
  v_pipeline jsonb := '[]'::jsonb;
  v_locations jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'global_stock', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'sellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'held'::public.stock_availability), 0),
    coalesce(sum(gs.quantity) FILTER (WHERE gs.availability = 'unsellable'::public.stock_availability), 0),
    coalesce(sum(gs.quantity), 0),
    coalesce(
      sum(gs.quantity * coalesce(gsi.landed_cost_bdt, 0))
        FILTER (WHERE gs.availability = 'sellable'::public.stock_availability),
      0
    )
  INTO v_sellable, v_held, v_unsellable, v_total, v_value
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  WHERE gs.tenant_id = v_books_id
    AND gs.is_archived = false;

  SELECT
    coalesce(count(*) FILTER (WHERE s.status = 'in_transit'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'draft'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'received'), 0)
  INTO v_in_transit, v_draft, v_received
  FROM public.global_shipments s
  WHERE s.tenant_id = v_books_id
    AND s.is_archived = false;

  SELECT coalesce(jsonb_agg(row_to_json(g) ORDER BY g.qty DESC), '[]'::jsonb)
  INTO v_grades
  FROM (
    SELECT coalesce(t.name, 'Ungraded') AS name, sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.tags t ON t.id = gs.grade_tag_id
    WHERE gs.tenant_id = v_books_id
      AND gs.is_archived = false
      AND gs.quantity > 0
    GROUP BY coalesce(t.name, 'Ungraded')
  ) g;

  SELECT coalesce(jsonb_agg(row_to_json(p) ORDER BY p.sort_key), '[]'::jsonb)
  INTO v_pipeline
  FROM (
    SELECT
      s.status,
      count(*)::bigint AS count,
      CASE s.status
        WHEN 'draft' THEN 1
        WHEN 'in_transit' THEN 2
        WHEN 'received' THEN 3
        ELSE 4
      END AS sort_key
    FROM public.global_shipments s
    WHERE s.tenant_id = v_books_id
      AND s.is_archived = false
      AND s.status <> 'cancelled'
    GROUP BY s.status
  ) p;

  SELECT coalesce(jsonb_agg(row_to_json(l) ORDER BY l.qty DESC), '[]'::jsonb)
  INTO v_locations
  FROM (
    SELECT
      coalesce(sl.name, 'Unlocated') AS name,
      sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gs.tenant_id = v_books_id
      AND gs.is_archived = false
      AND gs.quantity > 0
    GROUP BY coalesce(sl.name, 'Unlocated')
  ) l;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'sellable_qty', v_sellable,
    'held_qty', v_held,
    'unsellable_qty', v_unsellable,
    'total_qty', v_total,
    'sellable_pct', CASE WHEN v_total > 0 THEN round((v_sellable::numeric / v_total) * 100, 1) ELSE 0 END,
    'sellable_value_bdt', round(v_value, 2),
    'in_transit_count', v_in_transit,
    'draft_count', v_draft,
    'received_count', v_received,
    'grades', v_grades,
    'pipeline', v_pipeline,
    'locations', v_locations
  );
END;
$$;


ALTER FUNCTION "public"."get_procurement_dashboard_metrics"("p_tenant_id" bigint) OWNER TO "postgres";

-- get_shipment_pnl

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
  if public.resolve_parent_tenant_id(p_tenant_id) <> (select tenant_id from public.global_shipments where id = p_shipment_id) then
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
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_cost,
      coalesce(sum(
        ii.sell_price_amount * (ii.quantity - coalesce(ii.return_quantity, 0))
        - case
          when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
          else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.written_off_amount, 0.00))
            * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        end
      ), 0) as revenue,
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
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
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
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_cost,
      coalesce(sum(
        ii.sell_price_amount * (ii.quantity - coalesce(ii.return_quantity, 0))
        - case
          when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
          else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.written_off_amount, 0.00))
            * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        end
      ), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      (si.ordered_quantity - coalesce(sum(ii.quantity - ii.return_quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
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

-- get_shipment_settings_finance_bundle

CREATE OR REPLACE FUNCTION "public"."get_shipment_settings_finance_bundle"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_parent bigint;
  v_cost_entries jsonb;
  v_ap_bills jsonb;
  v_ap_fx jsonb;
  v_sid text;
BEGIN
  SELECT gs.tenant_id INTO v_parent
  FROM public.global_shipments gs
  WHERE gs.id = p_shipment_id;

  IF v_parent IS NULL THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT (
    public.user_can_manage_parent_tenant(v_parent)
    OR EXISTS (
      SELECT 1 FROM public.memberships m
      WHERE m.tenant_id = v_parent
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    )
  ) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  PERFORM public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);
  PERFORM public.sync_shipment_ap_bills(p_shipment_id);

  v_sid := p_shipment_id::text;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', ce.id,
        'shipment_id', ce.shipment_id,
        'cost_bucket', ce.cost_bucket,
        'cost_component', ce.cost_component,
        'is_capitalizable', ce.is_capitalizable,
        'description', ce.description,
        'amount', ce.amount,
        'currency_id', ce.currency_id,
        'metadata', ce.metadata,
        'section_id', ce.section_id
      )
      ORDER BY ce.cost_bucket, ce.cost_component, ce.id
    ),
    '[]'::jsonb
  )
  INTO v_cost_entries
  FROM public.global_shipment_cost_entries ce
  WHERE ce.shipment_id = p_shipment_id;

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', b.id,
        'invoice_no', b.invoice_no,
        'ap_kind', b.ap_kind,
        'source_type', b.source_type,
        'source_id', b.source_id,
        'source_key', b.source_key,
        'invoice_status', b.invoice_status,
        'payment_status', b.payment_status,
        'total_amount', b.total_amount,
        'due_amount', b.due_amount
      )
      ORDER BY b.id
    ),
    '[]'::jsonb
  )
  INTO v_ap_bills
  FROM public.bills b
  WHERE b.invoice_type = 'ap'
    AND b.document_kind = 'standard'
    AND b.invoice_status <> 'voided'
    AND (
      (b.source_type = 'shipment_cost' AND b.source_id = v_sid)
      OR b.ap_shipment_id = p_shipment_id
    )
    AND coalesce(b.source_key, b.ap_kind) IN (
      'material', 'freight', 'customs', 'handling', 'finance', 'other',
      'vendor', 'cargo', 'local'
    );

  v_ap_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_ap_fx := v_ap_fx - 'blended_rate';

  RETURN jsonb_build_object(
    'cost_entries', v_cost_entries,
    'ap_bills', v_ap_bills,
    'ap_fx', v_ap_fx
  );
END;
$$;


ALTER FUNCTION "public"."get_shipment_settings_finance_bundle"("p_shipment_id" bigint) OWNER TO "postgres";

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
      AND gs.tenant_id = public.resolve_parent_tenant_id(v_tenant_id)
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

-- get_tenant_shipment_profit_report

CREATE OR REPLACE FUNCTION "public"."get_tenant_shipment_profit_report"("p_tenant_id" bigint, "p_shipment_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_summary jsonb;
  v_rows jsonb;
  v_total_count integer := 0;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 20), 1);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  SELECT coalesce(t.parent_id, t.id)
  INTO v_books_id
  FROM public.tenants t
  WHERE t.id = p_tenant_id;

  IF v_books_id IS NULL THEN
    RAISE EXCEPTION 'Tenant not found';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'global_shipment', 'view')
    OR public.membership_has_module_action(v_books_id, 'global_shipment', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH shipment_metrics AS (
    SELECT
      s.id AS shipment_id,
      s.name AS shipment_name,
      s.tenant_shipment_id::text AS shipment_code,
      s.status AS shipment_status,
      s.created_at,
      s.shipment_cost_currency_id AS currency_id,
      
      -- Inbound Quantities & Landed Cost (ordered manifest, not sold-only received)
      coalesce(sum(gsi.ordered_quantity), 0)::int AS inbound_quantity,
      coalesce(sum(gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS total_landed_cost,
      
      -- Sales & Returns from Issued Sales Invoices (invoice_status = 'issued')
      coalesce(sum(sales.sold_qty), 0)::int AS sold_quantity,
      coalesce(sum(sales.returned_qty), 0)::int AS returned_quantity,
      coalesce(sum(sales.net_sold_qty), 0)::int AS net_sold_quantity,
      coalesce(sum(sales.sold_revenue), 0)::numeric(18,4) AS gross_sold_revenue,
      coalesce(sum(sales.cogs), 0)::numeric(18,4) AS cogs_amount,
      coalesce(sum(sales.sold_revenue - sales.cogs), 0)::numeric(18,4) AS realized_gross_profit,
      
      -- Inventory Valuation & Damage
      coalesce(sum(inv.sellable_qty), 0)::int AS sellable_stock_qty,
      coalesce(sum(inv.held_qty), 0)::int AS held_stock_qty,
      coalesce(sum(inv.unsellable_qty), 0)::int AS damaged_stock_qty,
      coalesce(sum(
        greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
        * coalesce(gsi.landed_cost_bdt, 0)
      ), 0)::numeric(18,4) AS unsold_stock_value,
      coalesce(sum(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS damage_loss_value,

      -- Item details array if single shipment requested
      CASE WHEN p_shipment_id IS NOT NULL THEN
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'item_id', gsi.id,
              'product_name', coalesce(gsi.name, 'Item #' || gsi.id),
              'barcode', gsi.barcode,
              'inbound_qty', gsi.ordered_quantity,
              'unit_cost_bdt', gsi.landed_cost_bdt,
              'total_cost_bdt', (gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)),
              'sold_qty', coalesce(sales.net_sold_qty, 0),
              'sold_revenue', coalesce(sales.sold_revenue, 0),
              'cogs', coalesce(sales.cogs, 0),
              'gross_profit', coalesce(sales.sold_revenue - sales.cogs, 0),
              'sellable_qty', coalesce(inv.sellable_qty, 0),
              'unsold_stock_value', coalesce(
                greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
                * coalesce(gsi.landed_cost_bdt, 0),
                0
              ),
              'damaged_qty', coalesce(inv.unsellable_qty, 0),
              'damage_loss_value', coalesce(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0), 0)
            )
          ) FILTER (WHERE gsi.id IS NOT NULL),
          '[]'::jsonb
        )
      ELSE NULL END AS items

    FROM public.global_shipments s
    LEFT JOIN public.global_shipment_items gsi ON gsi.shipment_id = s.id
    
    -- Subquery for aggregated sales per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(gii.quantity), 0) AS sold_qty,
        coalesce(sum(gii.return_quantity), 0) AS returned_qty,
        coalesce(sum(gii.quantity - gii.return_quantity), 0) AS net_sold_qty,
        coalesce(sum(
          gii.sell_price_amount * (gii.quantity - coalesce(gii.return_quantity, 0))
          - coalesce(gii.line_discount_amount, 0) * (greatest(gii.quantity - gii.return_quantity, 0) / nullif(gii.quantity, 0))
          - CASE
            WHEN si.invoice_type = 'dropship'::public.global_invoice_type THEN 0.00
            ELSE (coalesce(si.discount_amount, 0.00) + coalesce(si.written_off_amount, 0.00))
              * (gii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
          END
        ), 0) AS sold_revenue,
        coalesce(sum((gii.quantity - gii.return_quantity) * coalesce(gsi.landed_cost_bdt, 0)), 0) AS cogs
      FROM public.global_invoice_items gii
      JOIN public.bills si ON si.id = gii.invoice_id
      LEFT JOIN LATERAL (
        SELECT coalesce(sum(x.line_total_amount), 0.00) AS inv_line_subtotal
        FROM public.global_invoice_items x
        WHERE x.invoice_id = gii.invoice_id
      ) invagg ON true
      WHERE gii.shipment_item_id = gsi.id
        AND si.invoice_status = 'issued'
    ) sales ON true

    -- Subquery for inventory breakdown per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(CASE WHEN gs.availability = 'sellable' THEN gs.quantity ELSE 0 END), 0) AS sellable_qty,
        coalesce(sum(CASE WHEN gs.availability = 'held' THEN gs.quantity ELSE 0 END), 0) AS held_qty,
        coalesce(sum(CASE WHEN gs.availability = 'unsellable' THEN gs.quantity ELSE 0 END), 0) AS unsellable_qty
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = gsi.id
    ) inv ON true

    WHERE s.tenant_id = v_books_id
      AND (p_shipment_id IS NULL OR s.id = p_shipment_id)
      AND (p_start_date IS NULL OR s.created_at >= p_start_date)
      AND (p_end_date IS NULL OR s.created_at <= p_end_date)
      AND (
        p_search IS NULL 
        OR btrim(p_search) = ''
        OR s.name ILIKE ('%' || btrim(p_search) || '%')
        OR (s.tenant_shipment_id IS NOT NULL AND s.tenant_shipment_id::text ILIKE ('%' || btrim(p_search) || '%'))
      )
    GROUP BY s.id, s.name, s.tenant_shipment_id, s.status, s.created_at, s.shipment_cost_currency_id
  ),
  counted AS (
    SELECT count(*) AS total_count FROM shipment_metrics
  ),
  summary_calc AS (
    SELECT
      coalesce(sum(inbound_quantity), 0)::int AS total_inbound_units,
      coalesce(sum(total_landed_cost), 0)::numeric(18,4) AS total_landed_cost,
      coalesce(sum(net_sold_quantity), 0)::int AS total_net_sold_units,
      coalesce(sum(gross_sold_revenue), 0)::numeric(18,4) AS total_gross_sold_revenue,
      coalesce(sum(cogs_amount), 0)::numeric(18,4) AS total_cogs,
      coalesce(sum(realized_gross_profit), 0)::numeric(18,4) AS total_realized_gross_profit,
      CASE
        WHEN coalesce(sum(gross_sold_revenue), 0) > 0
        THEN round((coalesce(sum(realized_gross_profit), 0) / sum(gross_sold_revenue) * 100)::numeric, 2)
        ELSE 0.00
      END AS overall_realized_gp_margin_pct,
      coalesce(sum(unsold_stock_value), 0)::numeric(18,4) AS total_unsold_stock_value,
      coalesce(sum(damage_loss_value), 0)::numeric(18,4) AS total_damage_loss_value,
      count(*)::int AS total_shipments_count
    FROM shipment_metrics
  ),
  paginated_rows AS (
    SELECT
      sm.*,
      CASE
        WHEN sm.gross_sold_revenue > 0
        THEN round((sm.realized_gross_profit / sm.gross_sold_revenue * 100)::numeric, 2)
        ELSE 0.00
      END AS realized_gp_margin_pct,
      CASE
        WHEN sm.inbound_quantity > 0
        THEN round((sm.net_sold_quantity::numeric / sm.inbound_quantity::numeric * 100)::numeric, 1)
        ELSE 0.0
      END AS batch_sold_pct
    FROM shipment_metrics sm
    ORDER BY sm.created_at DESC, sm.shipment_id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  )
  SELECT
    to_jsonb(s),
    coalesce((SELECT total_count FROM counted), 0),
    coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_summary, v_total_count, v_rows
  FROM summary_calc s
  CROSS JOIN paginated_rows r
  GROUP BY to_jsonb(s);

  RETURN jsonb_build_object(
    'summary', coalesce(v_summary, jsonb_build_object(
      'total_inbound_units', 0,
      'total_landed_cost', 0,
      'total_net_sold_units', 0,
      'total_gross_sold_revenue', 0,
      'total_cogs', 0,
      'total_realized_gross_profit', 0,
      'overall_realized_gp_margin_pct', 0,
      'total_unsold_stock_value', 0,
      'total_damage_loss_value', 0,
      'total_shipments_count', 0
    )),
    'shipments', coalesce(v_rows, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', CASE WHEN v_total_count = 0 THEN 1 ELSE ceil(v_total_count::numeric / v_page_size::numeric)::int END
    )
  );
END;
$$;


ALTER FUNCTION "public"."get_tenant_shipment_profit_report"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_search" "text", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_page" integer, "p_page_size" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "public"."get_tenant_shipment_profit_report"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_search" "text", "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone, "p_page" integer, "p_page_size" integer) IS 'Consolidated batch shipment profit, landed cost, COGS, realized gross profit, remaining stock valuation and damage reporting.';

-- hold_shop_grade_stock_for_order

CREATE OR REPLACE FUNCTION "public"."hold_shop_grade_stock_for_order"("p_tenant_id" bigint, "p_shop_tenant_id" bigint, "p_product_id" bigint, "p_grade_tag_id" bigint, "p_quantity" integer, "p_order_id" bigint, "p_notes" "text" DEFAULT NULL::"text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_grade_tag_id bigint;
  v_remaining integer;
  v_stock record;
  v_take integer;
  v_primary_held bigint := NULL;
  v_held_stock_id bigint;
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'quantity must be positive';
  END IF;

  v_grade_tag_id := coalesce(p_grade_tag_id, public.default_stock_grade_tag_id());
  v_remaining := p_quantity;

  FOR v_stock IN
    SELECT
      gs.id,
      gs.location_id,
      gs.grade_tag_id,
      gs.shipment_item_id,
      greatest(0, floor(public.global_stock_atp_qty(gs.id)))::integer AS atp
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    WHERE gsi.product_id = p_product_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      AND gs.tenant_id = p_tenant_id
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = TRUE)
    ORDER BY gs.id
    FOR UPDATE OF gs
  LOOP
    IF v_remaining <= 0 THEN
      EXIT;
    END IF;

    v_take := least(v_remaining, v_stock.atp);
    IF v_take <= 0 THEN
      CONTINUE;
    END IF;

    PERFORM public.create_and_post_stock_movement(
      p_tenant_id,
      v_stock.id,
      v_take,
      v_stock.location_id,
      'held'::public.stock_availability,
      v_stock.grade_tag_id,
      'availability_transfer'::public.stock_movement_type,
      coalesce(p_notes, 'Shop order hold'),
      'shop_order',
      p_order_id::text
    );

    SELECT gs.id
    INTO v_held_stock_id
    FROM public.global_stocks gs
    WHERE gs.shipment_item_id = v_stock.shipment_item_id
      AND gs.tenant_id = p_tenant_id
      AND gs.availability = 'held'::public.stock_availability
      AND gs.location_id IS NOT DISTINCT FROM v_stock.location_id
      AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
        = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
    ORDER BY gs.id DESC
    LIMIT 1;

    v_primary_held := coalesce(v_primary_held, v_held_stock_id);
    v_remaining := v_remaining - v_take;
  END LOOP;

  IF v_remaining > 0 THEN
    RAISE EXCEPTION 'insufficient sellable stock for product % (grade %): short by %',
      p_product_id, v_grade_tag_id, v_remaining;
  END IF;

  RETURN v_primary_held;
END;
$$;


ALTER FUNCTION "public"."hold_shop_grade_stock_for_order"("p_tenant_id" bigint, "p_shop_tenant_id" bigint, "p_product_id" bigint, "p_grade_tag_id" bigint, "p_quantity" integer, "p_order_id" bigint, "p_notes" "text") OWNER TO "postgres";

-- issue_shipment_ap_bills

CREATE OR REPLACE FUNCTION "public"."issue_shipment_ap_bills"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
  v_count integer := 0;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select gs.tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills b
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;


ALTER FUNCTION "public"."issue_shipment_ap_bills"("p_shipment_id" bigint) OWNER TO "postgres";

-- list_allocatable_stock_paginated

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
  where gs.tenant_id = p_tenant_id
    and gs.is_archived = false
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
      gs.tenant_id,
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
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
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
  WHERE gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
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
    WHERE gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
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

-- list_child_stock_atp

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
        'tenant_id', s.tenant_id,
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
    group by s.id, s.name, s.tenant_shipment_id, s.tenant_id, s.status, s.received_date
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

-- list_global_shipments_paginated

CREATE OR REPLACE FUNCTION "public"."list_global_shipments_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_is_archived" boolean DEFAULT false, "p_vendor_id" bigint DEFAULT NULL::bigint, "p_cargo_company_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_total_count bigint;
  v_archived_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  select count(*)
  into v_total_count
  from public.global_shipments s
  where s.tenant_id = p_tenant_id
    and (p_is_archived is null or s.is_archived = p_is_archived)
    and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
    and (
      p_search is null or p_search = '' or (
        s.name ilike '%' || p_search || '%'
        or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
      )
    )
    and (p_vendor_id is null or s.vendor_id = p_vendor_id)
    and (p_cargo_company_id is null or s.cargo_company_id = p_cargo_company_id);

  select count(*)
  into v_archived_count
  from public.global_shipments s
  where s.tenant_id = p_tenant_id
    and s.is_archived = true;

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      (
        to_jsonb(s)
        || jsonb_build_object(
          'vendor_name', v.name,
          'vendor_code', v.code,
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
    left join public.vendors v
      on v.id = s.vendor_id
    left join public.tags t
      on t.id = s.progress_tag_id
     and t.group_name = 'shipment_progress'
    where s.tenant_id = p_tenant_id
      and (p_is_archived is null or s.is_archived = p_is_archived)
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
      and (p_vendor_id is null or s.vendor_id = p_vendor_id)
      and (p_cargo_company_id is null or s.cargo_company_id = p_cargo_company_id)
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
      'total_pages', v_total_pages,
      'archived_total', v_archived_count
    )
  );
end;
$_$;


ALTER FUNCTION "public"."list_global_shipments_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_status" "text", "p_is_archived" boolean, "p_vendor_id" bigint, "p_cargo_company_id" bigint) OWNER TO "postgres";

-- list_global_stock_allocations_paginated

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
    (v_is_parent and gsa.tenant_id = p_tenant_id)
    or (not v_is_parent and gsa.child_tenant_id = p_tenant_id)
  )
  and (p_child_tenant_id is null or gsa.child_tenant_id = p_child_tenant_id)
  and gs.is_archived = false
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
      (v_is_parent and gsa.tenant_id = p_tenant_id)
      or (not v_is_parent and gsa.child_tenant_id = p_tenant_id)
    )
    and (p_child_tenant_id is null or gsa.child_tenant_id = p_child_tenant_id)
    and gs.is_archived = false
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

-- list_global_stocks_cursor

CREATE OR REPLACE FUNCTION "public"."list_global_stocks_cursor"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_cursor_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_stock_type_id" bigint DEFAULT NULL::bigint, "p_is_sellable" boolean DEFAULT NULL::boolean, "p_shipment_status" "text" DEFAULT NULL::"text", "p_hide_zero_stock" boolean DEFAULT true, "p_location_id" bigint DEFAULT NULL::bigint, "p_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_shipment_id" bigint DEFAULT NULL::bigint, "p_include_total" boolean DEFAULT false, "p_grade_tag_id" bigint DEFAULT NULL::bigint, "p_group_by" "text" DEFAULT NULL::"text", "p_group_key" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 20), 100));
  v_fetch integer := v_limit + 1;
  v_data jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_id bigint;
  v_total bigint := null;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if coalesce(p_include_total, false) and p_cursor_id is null then
    select count(*)
    into v_total
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
      and (
        p_group_by is null or p_group_key is null or p_group_key = ''
        or case p_group_by
          when 'shipment' then gsi.shipment_id::text = p_group_key
          when 'product' then coalesce(nullif(trim(gsi.product_code), ''), 'si:' || gsi.id::text) = p_group_key
          when 'location' then gs.location_id::text = p_group_key
          when 'grade' then coalesce(gs.grade_tag_id::text, '') = p_group_key
          when 'availability' then gs.availability::text = p_group_key
          else true
        end
      );
  end if;

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id,
      gs.tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      gs.grade_tag_id,
      gs.outcome_id,
      sl.name as location_name,
      o.kind as outcome_kind,
      o.reason as outcome_reason,
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
    left join public.global_shipment_item_outcomes o on o.id = gs.outcome_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
      and (
        p_group_by is null or p_group_key is null or p_group_key = ''
        or case p_group_by
          when 'shipment' then gsi.shipment_id::text = p_group_key
          when 'product' then coalesce(nullif(trim(gsi.product_code), ''), 'si:' || gsi.id::text) = p_group_key
          when 'location' then gs.location_id::text = p_group_key
          when 'grade' then coalesce(gs.grade_tag_id::text, '') = p_group_key
          when 'availability' then gs.availability::text = p_group_key
          else true
        end
      )
      and (p_cursor_id is null or gs.id < p_cursor_id)
    order by gs.id desc
    limit v_fetch
  ) r;

  v_n := coalesce(jsonb_array_length(v_data), 0);

  if v_n > v_limit then
    v_has_more := true;
    v_data := (
      select coalesce(jsonb_agg(elem), '[]'::jsonb)
      from (
        select elem
        from jsonb_array_elements(v_data) with ordinality as t(elem, ord)
        where ord <= v_limit
      ) s
    );
  end if;

  if coalesce(jsonb_array_length(v_data), 0) > 0 then
    v_last_id := (v_data->(jsonb_array_length(v_data) - 1)->>'id')::bigint;
    if v_has_more then
      v_next_cursor := jsonb_build_object('id', v_last_id);
    end if;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'has_more', v_has_more,
      'next_cursor', v_next_cursor,
      'total', v_total
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_global_stocks_cursor"("p_tenant_id" bigint, "p_limit" integer, "p_cursor_id" bigint, "p_search" "text", "p_stock_type_id" bigint, "p_is_sellable" boolean, "p_shipment_status" "text", "p_hide_zero_stock" boolean, "p_location_id" bigint, "p_availability" "public"."stock_availability", "p_shipment_id" bigint, "p_include_total" boolean, "p_grade_tag_id" bigint, "p_group_by" "text", "p_group_key" "text") OWNER TO "postgres";

-- list_global_stocks_groups

CREATE OR REPLACE FUNCTION "public"."list_global_stocks_groups"("p_tenant_id" bigint, "p_group_by" "text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_search" "text" DEFAULT NULL::"text", "p_stock_type_id" bigint DEFAULT NULL::bigint, "p_is_sellable" boolean DEFAULT NULL::boolean, "p_shipment_status" "text" DEFAULT NULL::"text", "p_hide_zero_stock" boolean DEFAULT true, "p_location_id" bigint DEFAULT NULL::bigint, "p_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_shipment_id" bigint DEFAULT NULL::bigint, "p_grade_tag_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb;
  v_total bigint;
  v_has_more boolean;
begin
  if not public._can_view_parent_warehouse_stock(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_group_by is null or p_group_by not in ('shipment', 'product', 'location', 'grade', 'availability') then
    raise exception 'invalid p_group_by';
  end if;

  with filtered as (
    select
      gs.id,
      gs.quantity,
      gs.availability,
      gs.location_id,
      gs.grade_tag_id,
      gsi.id as shipment_item_id,
      gsi.shipment_id,
      gsi.name as item_name,
      gsi.product_code,
      gship.name as shipment_name,
      sl.name as location_name,
      tg.name as grade_name
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
      and (
        p_search is null or p_search = '' or (
          gsi.name ilike '%' || p_search || '%'
          or gsi.product_code ilike '%' || p_search || '%'
          or gsi.barcode ilike '%' || p_search || '%'
          or gship.name ilike '%' || p_search || '%'
        )
      )
  ),
  keyed as (
    select
      case p_group_by
        when 'shipment' then f.shipment_id::text
        when 'product' then coalesce(nullif(trim(f.product_code), ''), 'si:' || f.shipment_item_id::text)
        when 'location' then coalesce(f.location_id::text, '')
        when 'grade' then coalesce(f.grade_tag_id::text, '')
        when 'availability' then f.availability::text
      end as key,
      case p_group_by
        when 'shipment' then coalesce(f.shipment_name, 'Shipment')
        when 'product' then coalesce(nullif(trim(f.product_code), ''), f.item_name, 'Product')
        when 'location' then coalesce(f.location_name, 'No location')
        when 'grade' then coalesce(f.grade_name, 'Standard')
        when 'availability' then initcap(f.availability::text)
      end as label,
      f.quantity
    from filtered f
  ),
  agg as (
    select
      key,
      max(label) as label,
      sum(quantity)::bigint as quantity,
      count(*)::bigint as lot_count
    from keyed
    where key is not null and key <> ''
    group by key
  ),
  counted as (
    select count(*)::bigint as total from agg
  )
  select
    (select total from counted),
    coalesce(
      (
        select jsonb_agg(row_to_json(g))
        from (
          select key, label, quantity, lot_count
          from agg
          order by quantity desc, label asc
          limit v_limit + 1
          offset v_offset
        ) g
      ),
      '[]'::jsonb
    )
  into v_total, v_groups;

  if coalesce(jsonb_array_length(v_groups), 0) > v_limit then
    v_has_more := true;
    v_groups := (
      select coalesce(jsonb_agg(elem), '[]'::jsonb)
      from (
        select elem
        from jsonb_array_elements(v_groups) with ordinality as t(elem, ord)
        where ord <= v_limit
      ) s
    );
  else
    v_has_more := false;
  end if;

  return jsonb_build_object(
    'groups', v_groups,
    'meta', jsonb_build_object(
      'total', v_total,
      'has_more', v_has_more
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_global_stocks_groups"("p_tenant_id" bigint, "p_group_by" "text", "p_limit" integer, "p_offset" integer, "p_search" "text", "p_stock_type_id" bigint, "p_is_sellable" boolean, "p_shipment_status" "text", "p_hide_zero_stock" boolean, "p_location_id" bigint, "p_availability" "public"."stock_availability", "p_shipment_id" bigint, "p_grade_tag_id" bigint) OWNER TO "postgres";

-- list_global_stocks_paginated

CREATE OR REPLACE FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text", "p_stock_type_id" bigint DEFAULT NULL::bigint, "p_is_sellable" boolean DEFAULT NULL::boolean, "p_shipment_status" "text" DEFAULT NULL::"text", "p_hide_zero_stock" boolean DEFAULT true, "p_location_id" bigint DEFAULT NULL::bigint, "p_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_shipment_id" bigint DEFAULT NULL::bigint, "p_grade_tag_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
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
  where gs.tenant_id = p_tenant_id
    and gs.is_archived = false
    and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
    and (
      p_is_sellable is null
      or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
      or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
    )
    and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
    and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
    and public.stock_location_matches_filter(gs.location_id, p_location_id)
    and (p_availability is null or gs.availability = p_availability)
    and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
    and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
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
      gs.tenant_id,
      gs.shipment_item_id,
      gs.stock_type_id,
      gs.quantity,
      gs.is_usable,
      gs.availability,
      gs.location_id,
      gs.grade_tag_id,
      gs.outcome_id,
      sl.name as location_name,
      o.kind as outcome_kind,
      o.reason as outcome_reason,
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
    left join public.global_shipment_item_outcomes o on o.id = gs.outcome_id
    where gs.tenant_id = p_tenant_id
      and gs.is_archived = false
      and (p_stock_type_id is null or gs.stock_type_id = p_stock_type_id)
      and (
        p_is_sellable is null
        or (p_is_sellable = true and gs.availability = 'sellable'::public.stock_availability)
        or (p_is_sellable = false and gs.availability <> 'sellable'::public.stock_availability)
      )
      and (p_shipment_status is null or p_shipment_status = '' or p_shipment_status = '__all__' or gship.status = p_shipment_status)
      and (not coalesce(p_hide_zero_stock, true) or gs.quantity > 0)
      and public.stock_location_matches_filter(gs.location_id, p_location_id)
      and (p_availability is null or gs.availability = p_availability)
      and (p_shipment_id is null or gsi.shipment_id = p_shipment_id)
      and (p_grade_tag_id is null or gs.grade_tag_id = p_grade_tag_id)
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


ALTER FUNCTION "public"."list_global_stocks_paginated"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_search" "text", "p_stock_type_id" bigint, "p_is_sellable" boolean, "p_shipment_status" "text", "p_hide_zero_stock" boolean, "p_location_id" bigint, "p_availability" "public"."stock_availability", "p_shipment_id" bigint, "p_grade_tag_id" bigint) OWNER TO "postgres";

-- list_inbound_shipments_workspace

CREATE OR REPLACE FUNCTION "public"."list_inbound_shipments_workspace"("p_tenant_id" bigint, "p_page_size" integer DEFAULT 20, "p_cursor" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_is_archived" boolean DEFAULT false, "p_vendor_id" bigint DEFAULT NULL::bigint, "p_cargo_company_id" bigint DEFAULT NULL::bigint, "p_include_reference_data" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_books_id bigint;
  v_archived_count bigint;
  v_data jsonb;
  v_vendors jsonb := '[]'::jsonb;
  v_cargo jsonb := '[]'::jsonb;
  v_limit integer;
  v_fetched integer;
  v_has_more boolean := false;
  v_next_cursor bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_limit := greatest(coalesce(p_page_size, 20), 1);

  select count(*)
  into v_archived_count
  from public.global_shipments s
  where s.tenant_id = v_books_id
    and s.is_archived = true;

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      s.id as sort_id,
      jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'tenant_shipment_id', s.tenant_shipment_id,
        'vendor_id', s.vendor_id,
        'vendor_name', v.name,
        'vendor_code', v.code,
        'type', s.type,
        'status', s.status,
        'created_at', s.created_at,
        'cargo_company_id', s.cargo_company_id
      ) as row_json
    from public.global_shipments s
    left join public.vendors v on v.id = s.vendor_id
    where s.tenant_id = v_books_id
      and (p_is_archived is null or s.is_archived = p_is_archived)
      and (p_status is null or p_status = '' or p_status = '__all__' or s.status = p_status)
      and (
        p_search is null or p_search = '' or (
          s.name ilike '%' || p_search || '%'
          or (p_search ~ '^[0-9]+$' and s.tenant_shipment_id = p_search::integer)
        )
      )
      and (p_vendor_id is null or s.vendor_id = p_vendor_id)
      and (p_cargo_company_id is null or s.cargo_company_id = p_cargo_company_id)
      and (p_cursor is null or s.id < p_cursor)
    order by s.id desc
    limit v_limit + 1
  ) q;

  v_fetched := coalesce(jsonb_array_length(v_data), 0);
  if v_fetched > v_limit then
    v_has_more := true;
    v_data := coalesce(
      (
        select jsonb_agg(elem order by (elem->>'id')::bigint desc)
        from (
          select elem
          from jsonb_array_elements(v_data) as elem
          limit v_limit
        ) trimmed
      ),
      '[]'::jsonb
    );
  end if;

  if coalesce(jsonb_array_length(v_data), 0) > 0 then
    v_next_cursor := (v_data->(jsonb_array_length(v_data) - 1)->>'id')::bigint;
  else
    v_next_cursor := null;
  end if;

  if not v_has_more then
    v_next_cursor := null;
  end if;

  if coalesce(p_include_reference_data, true) then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', ven.id,
          'name', ven.name,
          'code', ven.code,
          'market_code', ven.market_code,
          'parent_tenant_id', ven.parent_tenant_id,
          'is_default', ven.is_default
        )
        order by ven.id asc
      ),
      '[]'::jsonb
    )
    into v_vendors
    from public.vendors ven
    where ven.parent_tenant_id = v_books_id;

    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'id', cc.id,
          'name', cc.name,
          'code', cc.code,
          'is_default', cc.is_default
        )
        order by cc.is_default desc, cc.name asc
      ),
      '[]'::jsonb
    )
    into v_cargo
    from public.cargo_companies cc
    where cc.tenant_id = v_books_id
      and cc.is_active = true;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'page_size', v_limit,
      'next_cursor', v_next_cursor,
      'has_more', v_has_more,
      'archived_total', v_archived_count
    ),
    'vendors', v_vendors,
    'cargo_companies', v_cargo
  );
end;
$_$;


ALTER FUNCTION "public"."list_inbound_shipments_workspace"("p_tenant_id" bigint, "p_page_size" integer, "p_cursor" bigint, "p_search" "text", "p_status" "text", "p_is_archived" boolean, "p_vendor_id" bigint, "p_cargo_company_id" bigint, "p_include_reference_data" boolean) OWNER TO "postgres";

-- list_listable_stock_for_shop

CREATE OR REPLACE FUNCTION "public"."list_listable_stock_for_shop"("p_shop_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
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

  SELECT count(DISTINCT gs.id)
  INTO v_total_count
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
  WHERE gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = true)
    AND public.global_stock_atp_qty(gs.id) > 0
    AND NOT EXISTS (
      SELECT 1
      FROM public.shop_product_listings spl
      WHERE spl.shop_id = p_shop_id
        AND spl.global_stock_id = gs.id
        AND spl.is_active = true
    )
    AND (
      p_search IS NULL OR p_search = '' OR (
        gsi.name ILIKE '%' || p_search || '%'
        OR gsi.product_code ILIKE '%' || p_search || '%'
        OR gsi.barcode ILIKE '%' || p_search || '%'
        OR gship.name ILIKE '%' || p_search || '%'
        OR tg.name ILIKE '%' || p_search || '%'
        OR tg.slug ILIKE '%' || p_search || '%'
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
        'available_atp', public.global_stock_atp_qty(gs.id),
        'total_stock_qty', gs.quantity,
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'stock_grade', CASE
          WHEN tg.slug IS NOT NULL THEN jsonb_build_object(
            'slug', tg.slug,
            'label', tg.name,
            'color', tg.color
          )
          ELSE jsonb_build_object(
            'slug', 'standard',
            'label', 'Standard',
            'color', '#22c55e'
          )
        END
      ) AS row_json
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
    LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
    LEFT JOIN public.tags tg ON tg.id = gs.grade_tag_id
    WHERE gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      AND gship.status = 'received'
      AND gs.availability = 'sellable'::public.stock_availability
      AND (gs.location_id IS NULL OR sl.is_pickable = true)
      AND public.global_stock_atp_qty(gs.id) > 0
      AND NOT EXISTS (
        SELECT 1
        FROM public.shop_product_listings spl
        WHERE spl.shop_id = p_shop_id
          AND spl.global_stock_id = gs.id
          AND spl.is_active = true
      )
      AND (
        p_search IS NULL OR p_search = '' OR (
          gsi.name ILIKE '%' || p_search || '%'
          OR gsi.product_code ILIKE '%' || p_search || '%'
          OR gsi.barcode ILIKE '%' || p_search || '%'
          OR gship.name ILIKE '%' || p_search || '%'
          OR tg.name ILIKE '%' || p_search || '%'
          OR tg.slug ILIKE '%' || p_search || '%'
        )
      )
    ORDER BY gs.id DESC
    LIMIT p_limit
    OFFSET p_offset
  ) q;

  RETURN jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
END;
$$;


ALTER FUNCTION "public"."list_listable_stock_for_shop"("p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

-- list_shipment_items_for_shipments

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
      public.user_can_manage_parent_tenant(gs.tenant_id)
      or exists (
        select 1 from public.memberships m
        where m.tenant_id = gs.tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.is_active = true
      )
    )
  order by gsi.shipment_id, gsi.sort_order, gsi.id;
end;
$$;


ALTER FUNCTION "public"."list_shipment_items_for_shipments"("p_shipment_ids" bigint[]) OWNER TO "postgres";

-- list_shipment_payee_settlements

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

  IF NOT public.has_active_tenant_membership(v_ship.tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  RETURN jsonb_build_object(
    'vendor', public.get_payee_settlement_summary(v_ship.tenant_id, p_shipment_id, 'vendor', v_ship.vendor_id),
    'cargo_company', public.get_payee_settlement_summary(v_ship.tenant_id, p_shipment_id, 'cargo_company', v_ship.cargo_company_id)
  );
END;
$$;


ALTER FUNCTION "public"."list_shipment_payee_settlements"("p_shipment_id" bigint) OWNER TO "postgres";

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

-- list_stock_for_order_item_pick

CREATE OR REPLACE FUNCTION "public"."list_stock_for_order_item_pick"("p_order_item_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_total_count bigint;
  v_data jsonb;
  v_limit integer;
  v_offset integer;
  v_grade_tag_id bigint;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'stock pick is only allowed while order is processing';
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is marked unavailable';
  end if;

  v_shop_id := v_order.shop_id;
  v_shop_tenant_id := v_order.tenant_id;
  v_grade_tag_id := coalesce(v_item.grade_tag_id, public.default_stock_grade_tag_id());
  v_limit := greatest(1, least(coalesce(p_limit, 50), 200));
  v_offset := greatest(0, coalesce(p_offset, 0));

  select count(distinct gs.id)
  into v_total_count
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.stock_locations sl on sl.id = gs.location_id
  left join public.tags tg on tg.id = gs.grade_tag_id
  where gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
    and gsi.product_id = v_item.product_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
    and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
    and gship.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and (gs.location_id is null or sl.is_pickable = true)
    and (
      p_search is null or p_search = ''
      or gsi.name ilike '%' || p_search || '%'
      or gsi.product_code ilike '%' || p_search || '%'
      or gsi.barcode ilike '%' || p_search || '%'
      or gship.name ilike '%' || p_search || '%'
      or tg.name ilike '%' || p_search || '%'
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      gs.id as sort_id,
      jsonb_build_object(
        'global_stock_id', gs.id,
        'shipment_item_id', gsi.id,
        'shipment_id', gship.id,
        'shipment_name', gship.name,
        'item_name', gsi.name,
        'product_id', gsi.product_id,
        'product_code', gsi.product_code,
        'barcode', gsi.barcode,
        'available_atp', public.global_stock_atp_qty(gs.id),
        'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
        'already_picked', coalesce((
          select sp.quantity from public.shop_order_item_stock_picks sp
          where sp.order_item_id = p_order_item_id and sp.global_stock_id = gs.id
        ), 0),
        'pick_id', (
          select sp.id from public.shop_order_item_stock_picks sp
          where sp.order_item_id = p_order_item_id and sp.global_stock_id = gs.id
          limit 1
        ),
        'stock_grade', case
          when tg.slug is not null then jsonb_build_object('slug', tg.slug, 'label', tg.name, 'color', tg.color)
          else null
        end
      ) as row_json
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    left join public.stock_locations sl on sl.id = gs.location_id
    left join public.tags tg on tg.id = gs.grade_tag_id
    where gs.tenant_id = public.resolve_parent_tenant_id(v_shop_tenant_id)
      and gsi.product_id = v_item.product_id
      and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
      and public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, v_shop_tenant_id)
      and gship.status = 'received'
      and gs.availability = 'sellable'::public.stock_availability
      and (gs.location_id is null or sl.is_pickable = true)
      and (
        p_search is null or p_search = ''
        or gsi.name ilike '%' || p_search || '%'
        or gsi.product_code ilike '%' || p_search || '%'
        or gsi.barcode ilike '%' || p_search || '%'
        or gship.name ilike '%' || p_search || '%'
        or tg.name ilike '%' || p_search || '%'
      )
    order by gs.id desc
    limit v_limit offset v_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(1, ceil(v_total_count::numeric / v_limit::numeric)),
      'already_picked_total', coalesce((
        select sum(sp.quantity) from public.shop_order_item_stock_picks sp
        where sp.order_item_id = p_order_item_id
      ), 0),
      'ordered_quantity', v_item.quantity,
      'remaining_to_pick', greatest(
        v_item.quantity - coalesce((
          select sum(sp.quantity) from public.shop_order_item_stock_picks sp
          where sp.order_item_id = p_order_item_id
        ), 0),
        0
      ),
      'active_picks', coalesce((
        select jsonb_agg(
          jsonb_build_object(
            'id', sp.id,
            'global_stock_id', sp.global_stock_id,
            'shipment_id', sp.shipment_id,
            'shipment_name', gship.name,
            'item_name', gsi.name,
            'product_code', gsi.product_code,
            'barcode', gsi.barcode,
            'quantity', sp.quantity,
            'unit_cost_amount', coalesce(public.calculate_landed_unit_cost(gsi.id), 0.00),
            'created_at', sp.created_at
          )
          order by sp.id asc
        )
        from public.shop_order_item_stock_picks sp
        join public.global_shipments gship on gship.id = sp.shipment_id
        join public.global_shipment_items gsi on gsi.id = sp.shipment_item_id
        where sp.order_item_id = p_order_item_id
      ), '[]'::jsonb)
    )
  );
end;
$$;


ALTER FUNCTION "public"."list_stock_for_order_item_pick"("p_order_item_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."stock_locations" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "kind" "public"."stock_location_kind" DEFAULT 'bin'::"public"."stock_location_kind" NOT NULL,
    "is_default" boolean DEFAULT false NOT NULL,
    "is_pickable" boolean DEFAULT true NOT NULL,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "parent_location_id" bigint,
    CONSTRAINT "stock_locations_code_not_blank" CHECK (("length"(TRIM(BOTH FROM "code")) > 0)),
    CONSTRAINT "stock_locations_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0))
);


ALTER TABLE "public"."stock_locations" OWNER TO "postgres";

-- lock_global_shipment_costs

CREATE OR REPLACE FUNCTION "public"."lock_global_shipment_costs"("p_shipment_id" bigint) RETURNS "public"."global_shipments"
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

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment stock is not posted; receive before locking costs';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are already locked';
  end if;

  perform set_config('app.allow_costs_lock', '1', true);

  update public.global_shipments
  set costs_locked = true,
      costs_locked_at = now(),
      costs_locked_by = auth.uid(),
      updated_at = now()
  where id = p_shipment_id
  returning * into v_ship;

  perform public.sync_shipment_ap_bills(p_shipment_id);
  perform public.issue_shipment_ap_bills(p_shipment_id);

  return v_ship;
end;
$$;


ALTER FUNCTION "public"."lock_global_shipment_costs"("p_shipment_id" bigint) OWNER TO "postgres";

-- migrate_legacy_inventory_to_global_stock

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

-- post_shipment_outcome_stock

CREATE OR REPLACE FUNCTION "public"."post_shipment_outcome_stock"("p_shipment_id" bigint, "p_stock_rows" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_stamped integer;
  v_stock_count integer := 0;
  v_parent bigint;
  v_loc bigint;
  v_grade_tag bigint;
  v_avail public.stock_availability;
  v_stock_id bigint;
  v_mov_id bigint;
  v_mov_no text;
  v_posted int;
  v_delta int;
  r_out record;
  v_stock_type bigint;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.tenant_id;

  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if v_ship.status = 'cancelled' then
    raise exception 'shipment is cancelled';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  if not exists (
    select 1 from public.global_shipment_cost_entries where shipment_id = p_shipment_id
  ) then
    raise exception 'shipment has no cost entries';
  end if;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  v_mov_no := public.next_stock_movement_number(v_parent, 'receive_putaway');

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
    'Outcome receive put-away for shipment ' || p_shipment_id::text,
    public.current_user_email(),
    true,
    now()
  )
  returning id into v_mov_id;

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
    order by o.id
  loop
    if r_out.kind = 'unsellable'::public.global_shipment_outcome_kind then
      continue;
    end if;

    select coalesce(sum(gs.quantity), 0)::int into v_posted
    from public.global_stocks gs where gs.outcome_id = r_out.id;

    v_delta := r_out.quantity - v_posted;
    if v_delta <= 0 then
      continue;
    end if;

    v_loc := null;
    if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'outcome_id')::bigint = r_out.id
      limit 1;
    end if;

    if v_loc is null and p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'location_id')::bigint into v_loc
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
      limit 1;
    end if;

    v_loc := coalesce(v_loc, public.default_putaway_stock_location_id(v_parent));

    if v_loc is null then
      raise exception 'no put-away location configured';
    end if;

    if not exists (
      select 1 from public.stock_locations sl
      where sl.id = v_loc and sl.tenant_id = v_parent and sl.is_active = true
        and public._stock_location_is_leaf(v_loc)
    ) then
      raise exception 'invalid put-away location';
    end if;

    v_avail := 'sellable'::public.stock_availability;
    v_grade_tag := public.default_stock_grade_tag_id();

    v_stock_type := null;
    if p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'stock_type_id')::bigint into v_stock_type
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'outcome_id')::bigint = r_out.id
        and nullif(elem->>'stock_type_id', '') is not null
      limit 1;
    end if;

    if v_stock_type is null and p_stock_rows is not null and jsonb_typeof(p_stock_rows) = 'array' then
      select (elem->>'stock_type_id')::bigint into v_stock_type
      from jsonb_array_elements(p_stock_rows) elem
      where (elem->>'shipment_item_id')::bigint = r_out.shipment_item_id
        and nullif(elem->>'stock_type_id', '') is not null
      limit 1;
    end if;

    if v_stock_type is null then
      select gs.stock_type_id into v_stock_type
      from public.global_stocks gs
      where gs.shipment_item_id = r_out.shipment_item_id
        and gs.stock_type_id is not null
      order by gs.quantity desc, gs.id
      limit 1;
    end if;

    if v_stock_type is null then
      v_stock_type := public.default_sellable_global_stock_type_id(v_parent);
    end if;

    if v_stock_type is null then
      raise exception 'no sellable stock type configured';
    end if;

    insert into public.global_stocks (
      parent_tenant_id, shipment_item_id, outcome_id, stock_type_id, quantity,
      is_usable, availability, location_id, grade_tag_id
    ) values (
      v_parent, r_out.shipment_item_id, r_out.id, v_stock_type, v_delta,
      true, v_avail, v_loc, v_grade_tag
    )
    on conflict (outcome_id, availability, location_id, grade_tag_id)
    do update set quantity = public.global_stocks.quantity + excluded.quantity, updated_at = now()
    returning id into v_stock_id;

    insert into public.stock_movement_lines (
      movement_id, stock_id, quantity, to_location_id, to_availability
    ) values (v_mov_id, v_stock_id, v_delta, v_loc, v_avail);

    v_stock_count := v_stock_count + 1;
  end loop;

  update public.global_shipment_items gsi
  set received_quantity = coalesce(extra_totals.total_qty, 0), updated_at = now()
  from (
    select o.shipment_item_id as item_id, sum(o.quantity)::int as total_qty
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi2 on gsi2.id = o.shipment_item_id
    where gsi2.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
    group by o.shipment_item_id
  ) extra_totals
  where gsi.id = extra_totals.item_id and gsi.shipment_id = p_shipment_id;

  if v_stock_count > 0 then
    update public.global_shipments
    set status = 'received',
        stock_ready = true, inventory_added = true, updated_at = now()
    where id = p_shipment_id;
  end if;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'stock_rows_posted', v_stock_count,
    'stock_ready', (select stock_ready from public.global_shipments where id = p_shipment_id),
    'movement_id', v_mov_id
  );
end;
$$;


ALTER FUNCTION "public"."post_shipment_outcome_stock"("p_shipment_id" bigint, "p_stock_rows" "jsonb") OWNER TO "postgres";

-- post_stock_movement

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

  if not public.can_act_on_stock_movement_context(
    v_mov.tenant_id,
    v_mov.reference_type,
    v_mov.reference_id
  ) then
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
                v_stock.tenant_id,
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
            public.default_returns_stock_location_id(v_stock.tenant_id)
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
              v_stock.tenant_id,
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

-- purge_archived_shipment

CREATE OR REPLACE FUNCTION "public"."purge_archived_shipment"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.is_archived is not true then
    raise exception 'shipment must be archived before it can be permanently deleted';
  end if;

  delete from public.shop_order_item_stock_picks sp
  where sp.shipment_id = p_id
     or sp.shipment_item_id in (
       select id from public.global_shipment_items where shipment_id = p_id
     )
     or sp.global_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     )
     or sp.held_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     );

  update public.bill_lines bl
  set
    line_meta = bl.line_meta - 'stock_ref',
    shipment_item_id = null,
    updated_at = now()
  where bl.shipment_item_id in (
    select id from public.global_shipment_items where shipment_id = p_id
  )
  or nullif(bl.line_meta->'stock_ref'->>'global_stock_id', '')::bigint in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  update public.sales_return_items sri
  set
    global_stock_id = null,
    updated_at = now()
  where sri.global_stock_id in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  delete from public.global_shipments where id = p_id;
end;
$$;


ALTER FUNCTION "public"."purge_archived_shipment"("p_id" bigint) OWNER TO "postgres";

-- recalc_shop_display_quantities

CREATE OR REPLACE FUNCTION "public"."recalc_shop_display_quantities"("p_shop_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
  v_display_add integer;
  v_updated integer;
begin
  if p_shop_id is null then
    raise exception 'shop required';
  end if;

  select s.tenant_id, coalesce(s.display_quantity_add, 6)
  into v_tenant_id, v_display_add
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

  with updated as (
    update public.shop_product_listings l
    set
      display_quantity_override = public.shop_padded_display_quantity(
        public.shop_product_grade_available_units(
          v_tenant_id,
          l.product_id,
          (
            select gs.grade_tag_id
            from public.global_stocks gs
            where gs.id = l.global_stock_id
          )
        ),
        v_display_add
      ),
      updated_at = now()
    where l.shop_id = p_shop_id
      and not l.is_quantity_locked
    returning l.id
  )
  select count(*)::integer into v_updated from updated;

  return coalesce(v_updated, 0);
end;
$$;


ALTER FUNCTION "public"."recalc_shop_display_quantities"("p_shop_id" bigint) OWNER TO "postgres";

-- refresh_shipment_investor_profits

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

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  v_pnl := public.get_shipment_pnl(v_shipment.tenant_id, p_global_shipment_id);
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
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
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
        select 1 from public.cashbook_entries
        where tenant_id = v_shipment.tenant_id
          and entity_type = 'investor'
          and entity_id = v_inv.investor_id
          and source_type = 'vendor_purchase'
          and source_id = p_global_shipment_id::text
          and metadata->>'purpose' = 'shipment_investor_profit'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_shipment.tenant_id, p_operating_tenant_id => coalesce(v_shipment.assigned_child_tenant_id, v_shipment.tenant_id),
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

-- reorder_shipment_sections

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

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id)
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

-- restamp_global_shipment_on_hand

CREATE OR REPLACE FUNCTION "public"."restamp_global_shipment_on_hand"("p_shipment_id" bigint DEFAULT NULL::bigint, "p_outcome_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_parent bigint;
  v_on_hand int;
  r_out record;
  v_updated int := 0;
begin
  if p_outcome_id is not null then
    select gsi.shipment_id into p_shipment_id
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where o.id = p_outcome_id;
  end if;

  if p_shipment_id is null then
    raise exception 'shipment_id or outcome_id required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  v_parent := v_ship.tenant_id;
  if not public.user_can_manage_parent_tenant(v_parent) then
    raise exception 'not allowed';
  end if;

  if coalesce(v_ship.is_closed, false) then
    raise exception 'shipment is closed';
  end if;

  perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
      and (p_outcome_id is null or o.id = p_outcome_id)
  loop
    select coalesce(sum(gs.quantity), 0)::int
    into v_on_hand
    from public.global_stocks gs
    where gs.outcome_id = r_out.id;

    if v_on_hand > r_out.quantity then
      raise exception 'outcome qty % below on-hand % for outcome %', r_out.quantity, v_on_hand, r_out.id;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'outcomes_checked', v_updated
  );
end;
$$;


ALTER FUNCTION "public"."restamp_global_shipment_on_hand"("p_shipment_id" bigint, "p_outcome_id" bigint) OWNER TO "postgres";

-- return_shipment_to_vendor

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

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  v_vendor_id := v_ship.vendor_id;

  insert into public.stock_movements (
    tenant_id, movement_no, movement_type, reference_type, reference_id, notes, created_by_email
  ) values (
    v_ship.tenant_id,
    public.next_stock_movement_number(v_ship.tenant_id, 'vendor_return'),
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
        and gs.tenant_id = v_ship.tenant_id
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
      select sum(coalesce(e.amount, 0))
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id and e.cost_bucket = 'material'::public.global_shipment_cost_bucket
    ), 0);
  end if;

  if p_outcome = 'cash_refund' then
    v_ledger := public.record_ledger_transaction(
      p_tenant_id => v_ship.tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_ship.tenant_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_source_type => 'shipment_return',
      p_source_id => p_shipment_id::text,
      p_metadata => jsonb_build_object('outcome', 'cash_refund', 'movement_id', v_mov_id)
    );
    if v_vendor_id is not null then
      perform public.record_ledger_transaction(
        p_tenant_id => v_ship.tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.tenant_id),
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
      p_tenant_id => v_ship.tenant_id, p_operating_tenant_id => coalesce(v_ship.assigned_child_tenant_id, v_ship.tenant_id),
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

-- revise_global_shipment_costs

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

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment not finalized; use upsert_global_shipment_cost_entry';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception 'p_entries must be a non-empty array';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'cost_bucket', e.cost_bucket,
    'cost_component', e.cost_component,
    'amount', e.amount,
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
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.tenant_id,
      p_shipment_id,
      (v_entry->>'cost_bucket')::public.global_shipment_cost_bucket,
      (v_entry->>'cost_component')::public.global_shipment_cost_component,
      coalesce((v_entry->>'is_capitalizable')::boolean, true),
      (v_entry->>'amount')::numeric,
      nullif(v_entry->>'currency_id', '')::bigint,
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

-- revoke_shipment_tracking_token

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

  if not public.has_active_tenant_membership(v_ship.tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  update public.global_shipments
  set public_tracking_token = null, updated_at = now()
  where id = p_shipment_id;
end;
$$;


ALTER FUNCTION "public"."revoke_shipment_tracking_token"("p_shipment_id" bigint) OWNER TO "postgres";

-- save_global_shipment_cost_entries

CREATE OR REPLACE FUNCTION "public"."save_global_shipment_cost_entries"("p_shipment_id" bigint, "p_entries" "jsonb", "p_delete_ids" bigint[] DEFAULT '{}'::bigint[], "p_received_weight" numeric DEFAULT NULL::numeric, "p_total_weight_kg" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_row public.global_shipment_cost_entries%rowtype;
  v_id bigint;
  v_amount numeric;
  v_stamped integer := 0;
  v_cost_entries jsonb;
  v_items jsonb;
  v_cost_bucket public.global_shipment_cost_bucket;
  v_cost_component public.global_shipment_cost_component;
  v_is_capitalizable boolean;
  v_description text;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '1', true);

  if p_received_weight is not null or p_total_weight_kg is not null then
    update public.global_shipments
    set
      received_weight = coalesce(p_received_weight, received_weight),
      total_weight_kg = coalesce(p_total_weight_kg, total_weight_kg),
      updated_at = now()
    where id = p_shipment_id
    returning * into v_ship;
  end if;

  if p_delete_ids is not null and cardinality(p_delete_ids) > 0 then
    delete from public.global_shipment_cost_entries e
    where e.shipment_id = p_shipment_id
      and e.id = any(p_delete_ids);
  end if;

  if p_entries is not null and jsonb_typeof(p_entries) = 'array' then
    for v_entry in select value from jsonb_array_elements(p_entries)
    loop
      v_amount := nullif(v_entry->>'amount', '')::numeric;
      v_id := nullif(v_entry->>'id', '')::bigint;

      if v_amount is null or v_amount < 0 then
        raise exception 'amount must be >= 0';
      end if;

      v_cost_bucket := nullif(v_entry->>'cost_bucket', '')::public.global_shipment_cost_bucket;
      v_cost_component := nullif(v_entry->>'cost_component', '')::public.global_shipment_cost_component;
      if v_cost_bucket is null or v_cost_component is null then
        raise exception 'cost_bucket and cost_component are required';
      end if;

      v_is_capitalizable := case
        when v_entry ? 'is_capitalizable' then (v_entry->>'is_capitalizable')::boolean
        else null
      end;
      v_description := nullif(trim(v_entry->>'description'), '');

      if v_id is not null then
        update public.global_shipment_cost_entries e
        set
          cost_bucket = v_cost_bucket,
          cost_component = v_cost_component,
          is_capitalizable = coalesce(v_is_capitalizable, e.is_capitalizable),
          description = coalesce(v_description, e.description),
          amount = v_amount,
          currency_id = nullif(v_entry->>'currency_id', '')::bigint,
          metadata = coalesce(v_entry->'metadata', '{}'::jsonb),
          section_id = nullif(v_entry->>'section_id', '')::bigint,
          updated_at = now()
        where e.id = v_id
          and e.shipment_id = p_shipment_id
        returning * into v_row;

        if not found then
          raise exception 'cost entry % not found on shipment %', v_id, p_shipment_id;
        end if;
      else
        insert into public.global_shipment_cost_entries (
          parent_tenant_id,
          shipment_id,
          cost_bucket,
          cost_component,
          is_capitalizable,
          description,
          amount,
          currency_id,
          metadata,
          section_id
        ) values (
          v_ship.tenant_id,
          p_shipment_id,
          v_cost_bucket,
          v_cost_component,
          coalesce(v_is_capitalizable, true),
          v_description,
          v_amount,
          nullif(v_entry->>'currency_id', '')::bigint,
          coalesce(v_entry->'metadata', '{}'::jsonb),
          nullif(v_entry->>'section_id', '')::bigint
        )
        returning * into v_row;
      end if;
    end loop;
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '0', true);

  if exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.id), '[]'::jsonb)
  into v_cost_entries
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order, i.id), '[]'::jsonb)
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'items', v_items,
    'items_stamped', v_stamped,
    'shipment', jsonb_build_object(
      'id', v_ship.id,
      'received_weight', v_ship.received_weight,
      'total_weight_kg', v_ship.total_weight_kg,
      'updated_at', v_ship.updated_at
    )
  );
end;
$$;


ALTER FUNCTION "public"."save_global_shipment_cost_entries"("p_shipment_id" bigint, "p_entries" "jsonb", "p_delete_ids" bigint[], "p_received_weight" numeric, "p_total_weight_kg" numeric) OWNER TO "postgres";

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
  where gs.tenant_id = v_parent_id
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

-- search_stock_network

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
    gs.tenant_id,
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
  where gs.tenant_id = v_parent_id
    and gs.is_archived = false
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

-- set_shipment_progress_flow

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

  if v_flow.tenant_id <> v_ship.tenant_id then
    raise exception 'flow tenant mismatch';
  end if;

  if not public.has_active_tenant_membership(v_ship.tenant_id)
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

-- set_shipment_progress_stage

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

  if not public.has_active_tenant_membership(v_ship.tenant_id)
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

-- settle_shipment_payee

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

  IF NOT public.has_active_tenant_membership(v_ship.tenant_id)
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
      p_tenant_id => v_ship.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_ship.tenant_id,
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
      p_tenant_id => v_ship.tenant_id,
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
      p_tenant_id => v_ship.tenant_id,
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

-- shop_product_grade_available_units

CREATE OR REPLACE FUNCTION "public"."shop_product_grade_available_units"("p_shop_tenant_id" bigint, "p_product_id" bigint, "p_grade_tag_id" bigint DEFAULT NULL::bigint) RETURNS integer
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT coalesce(
    sum(greatest(0, floor(public.global_stock_atp_qty(gs.id))))::integer,
    0
  )
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  WHERE gsi.product_id = p_product_id
    AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(p_grade_tag_id, public.default_stock_grade_tag_id())
    AND gs.tenant_id = public.resolve_parent_tenant_id(p_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = true);
$$;


ALTER FUNCTION "public"."shop_product_grade_available_units"("p_shop_tenant_id" bigint, "p_product_id" bigint, "p_grade_tag_id" bigint) OWNER TO "postgres";

-- shop_product_grade_avg_landed_cost

CREATE OR REPLACE FUNCTION "public"."shop_product_grade_avg_landed_cost"("p_shop_tenant_id" bigint, "p_product_id" bigint, "p_grade_tag_id" bigint) RETURNS numeric
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  SELECT coalesce(
    avg(coalesce(gsi.landed_cost_bdt, public.calculate_landed_unit_cost(gsi.id))),
    0
  )::numeric
  FROM public.global_stocks gs
  JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
  JOIN public.global_shipments gship ON gship.id = gsi.shipment_id
  LEFT JOIN public.stock_locations sl ON sl.id = gs.location_id
  WHERE gsi.product_id = p_product_id
    AND coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(p_grade_tag_id, public.default_stock_grade_tag_id())
    AND gs.tenant_id = public.resolve_parent_tenant_id(p_shop_tenant_id)
    AND public.shop_shipment_alloc_visible_to_tenant(gship.assigned_child_tenant_id, p_shop_tenant_id)
    AND gship.status = 'received'
    AND gs.availability = 'sellable'::public.stock_availability
    AND (gs.location_id IS NULL OR sl.is_pickable = TRUE);
$$;


ALTER FUNCTION "public"."shop_product_grade_avg_landed_cost"("p_shop_tenant_id" bigint, "p_product_id" bigint, "p_grade_tag_id" bigint) OWNER TO "postgres";

-- sync_shipment_ap_bills

CREATE OR REPLACE FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_tenant_name text;
  v_bucket public.global_shipment_cost_bucket;
  v_bucket_text text;
  v_paper jsonb;
  v_amt numeric(12, 2);
  v_profile bigint;
  v_bill_id bigint;
  v_bills jsonb := '{}'::jsonb;
  v_keep_as_draft boolean := false;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := v_ship.tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'cargo'::public.profile_party_type
      and pr.subject_id = v_ship.cargo_company_id;
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_parent;

  v_local_profile := public.upsert_profile_for_party(
    v_parent,
    'company'::public.profile_party_type,
    v_parent,
    coalesce(v_tenant_name, 'Local opex'),
    null, null, '+880', null, false, null, true, null
  );

  v_keep_as_draft := not coalesce(v_ship.costs_locked, false);

  if v_ship.status = 'cancelled' then
    update public.bills
    set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
    where parent_tenant_id = v_parent
      and ap_shipment_id = p_shipment_id
      and invoice_type = 'ap'::public.global_invoice_type
      and document_kind = 'standard'::public.bill_document_kind
      and invoice_status in (
        'issued'::public.global_invoice_status,
        'draft'::public.global_invoice_status
      )
      and coalesce(paid_amount, 0) = 0;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_amt := coalesce(
      (v_paper->>'foreign_total')::numeric,
      (v_paper->>'bdt_amount')::numeric,
      0
    );

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    v_bill_id := public._upsert_shipment_ap_bill(
      v_parent,
      v_issued_by,
      p_shipment_id,
      v_ship.name,
      v_bucket::text,
      v_profile,
      v_amt,
      v_paper,
      v_keep_as_draft
    );

    if v_bill_id is not null then
      v_bills := v_bills || jsonb_build_object(v_bucket::text, v_bill_id);
    end if;
  end loop;

  update public.bills
  set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
  where parent_tenant_id = v_parent
    and ap_shipment_id = p_shipment_id
    and invoice_type = 'ap'::public.global_invoice_type
    and document_kind = 'standard'::public.bill_document_kind
    and ap_kind in ('vendor', 'cargo', 'local')
    and invoice_status = 'issued'::public.global_invoice_status
    and coalesce(paid_amount, 0) = 0;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;


ALTER FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) OWNER TO "postgres";

-- trg_auto_publish_dropship_listing

CREATE OR REPLACE FUNCTION "public"."trg_auto_publish_dropship_listing"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop record;
  v_rule record;
  v_landed_cost numeric;
  v_currency_id bigint;
  v_product_id bigint;
  v_stock_id bigint;
  v_sell_price numeric;
begin
  -- For each shop owned by the target child tenant that has auto_publish enabled
  for v_shop in (
    select s.id as shop_id, s.tenant_id
    from public.shops s
    where s.tenant_id = new.tenant_id
  ) loop
    select * into v_rule
    from public.shop_pricing_rules
    where shop_id = v_shop.shop_id;

    if v_rule.is_auto_publish is true then
      -- Calculate parent landed cost for minimum_sell_price
      select
        (gsi.purchase_price * coalesce(gship.product_conversion_rate, 1.0)),
        gsi.purchase_price_currency_id,
        gsi.product_id,
        gs.id
      into v_landed_cost, v_currency_id, v_product_id, v_stock_id
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      join public.global_shipments gship on gship.id = gsi.shipment_id
      where gs.id = new.stock_id;

      if v_landed_cost is not null and v_currency_id is not null then
        v_sell_price := round(v_landed_cost * (1 + (coalesce(v_rule.markup_percentage, 0.00) / 100.0)), 2);

        insert into public.shop_product_listings (
          tenant_id,
          shop_id,
          global_stock_allocation_id,
          global_stock_id,
          product_id,
          sell_price_amount,
          sell_price_currency_id,
          minimum_sell_price_amount,
          minimum_sell_price_currency_id,
          is_active
        )
        values (
          v_shop.tenant_id,
          v_shop.shop_id,
          new.id,
          v_stock_id,
          v_product_id,
          v_sell_price,
          v_currency_id,
          round(v_landed_cost, 2),
          v_currency_id,
          true
        )
        on conflict (shop_id, global_stock_allocation_id) do update set
          minimum_sell_price_amount = excluded.minimum_sell_price_amount,
          minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
          sell_price_amount = case
            when shop_product_listings.sell_price_amount < excluded.minimum_sell_price_amount then excluded.sell_price_amount
            else shop_product_listings.sell_price_amount
          end,
          updated_at = now();
      end if;
    end if;
  end loop;

  return new;
end;
$$;


ALTER FUNCTION "public"."trg_auto_publish_dropship_listing"() OWNER TO "postgres";

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

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
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

-- unarchive_shipment

CREATE OR REPLACE FUNCTION "public"."unarchive_shipment"("p_id" bigint) RETURNS "public"."global_shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.global_shipments
  set is_archived = false,
      archived_at = null,
      updated_at = now()
  where id = p_id
  returning * into v_ship;

  perform public._set_global_stocks_archived_for_shipment(p_id, false);

  return v_ship;
end;
$$;


ALTER FUNCTION "public"."unarchive_shipment"("p_id" bigint) OWNER TO "postgres";

-- update_global_shipment_item

CREATE OR REPLACE FUNCTION "public"."update_global_shipment_item"("p_item_id" bigint, "p_patch" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.global_shipment_items;
  v_ship public.global_shipments;
  v_outcome public.global_shipment_item_outcomes;
  v_items jsonb;
  v_sync_outcome boolean := false;
begin
  if p_item_id is null then
    raise exception 'item_id is required';
  end if;
  if p_patch is null or jsonb_typeof(p_patch) <> 'object' then
    raise exception 'patch object is required';
  end if;

  select i.* into v_item
  from public.global_shipment_items i
  where i.id = p_item_id;

  if not found then
    raise exception 'shipment item not found';
  end if;

  select * into v_ship
  from public.global_shipments
  where id = v_item.shipment_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  v_sync_outcome := (
    p_patch ? 'ordered_quantity'
    or p_patch ? 'purchase_price'
    or p_patch ? 'landed_cost_bdt'
  );

  perform set_config('app.skip_item_landed_restamp', '1', true);

  update public.global_shipment_items
  set
    section_id = case
      when p_patch ? 'section_id' then nullif((p_patch->>'section_id'), '')::bigint
      else section_id
    end,
    vendor_id = case
      when p_patch ? 'vendor_id' then nullif((p_patch->>'vendor_id'), '')::bigint
      else vendor_id
    end,
    ordered_quantity = case
      when p_patch ? 'ordered_quantity' and (p_patch->>'ordered_quantity') is not null
        then greatest(1, (p_patch->>'ordered_quantity')::integer)
      else ordered_quantity
    end,
    purchase_price = case
      when p_patch ? 'purchase_price' and (p_patch->>'purchase_price') is not null
        then greatest(0, (p_patch->>'purchase_price')::numeric)
      else purchase_price
    end,
    product_weight = case
      when p_patch ? 'product_weight' and (p_patch->>'product_weight') is not null
        then greatest(0, (p_patch->>'product_weight')::numeric)
      else product_weight
    end,
    package_weight = case
      when p_patch ? 'package_weight' and (p_patch->>'package_weight') is not null
        then greatest(0, (p_patch->>'package_weight')::numeric)
      else package_weight
    end,
    landed_cost_bdt = case
      when p_patch ? 'landed_cost_bdt' then nullif((p_patch->>'landed_cost_bdt'), '')::numeric
      else landed_cost_bdt
    end,
    barcode = case
      when p_patch ? 'barcode' then p_patch->>'barcode'
      else barcode
    end,
    product_code = case
      when p_patch ? 'product_code' then p_patch->>'product_code'
      else product_code
    end,
    name = case
      when p_patch ? 'name' and (p_patch->>'name') is not null then p_patch->>'name'
      else name
    end,
    image_url = case
      when p_patch ? 'image_url' then p_patch->>'image_url'
      else image_url
    end,
    updated_at = now()
  where id = p_item_id and shipment_id = v_item.shipment_id
  returning * into v_item;

  if v_sync_outcome then
    update public.global_shipment_item_outcomes o
    set
      quantity = case
        when p_patch ? 'ordered_quantity' and (p_patch->>'ordered_quantity') is not null
          then greatest(1, (p_patch->>'ordered_quantity')::integer)
        else o.quantity
      end,
      purchase_price = case
        when p_patch ? 'purchase_price' and (p_patch->>'purchase_price') is not null
          then greatest(0, (p_patch->>'purchase_price')::numeric)
        else o.purchase_price
      end,
      cost = case
        when p_patch ? 'landed_cost_bdt' then nullif((p_patch->>'landed_cost_bdt'), '')::numeric
        else o.cost
      end,
      updated_at = now()
    where o.shipment_item_id = p_item_id
      and o.reason = 'ordered'::public.global_shipment_outcome_reason
    returning * into v_outcome;
  end if;

  perform set_config('app.skip_item_landed_restamp', '0', true);

  if exists (select 1 from public.global_shipment_items where shipment_id = v_item.shipment_id) then
    perform public.stamp_global_shipment_landed_costs(v_item.shipment_id);
  end if;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order asc, i.id asc), '[]'::jsonb)
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = v_item.shipment_id;

  return jsonb_build_object(
    'items', v_items,
    'ordered_outcome', case when v_outcome.id is not null then to_jsonb(v_outcome) else null end
  );
end;
$$;


ALTER FUNCTION "public"."update_global_shipment_item"("p_item_id" bigint, "p_patch" "jsonb") OWNER TO "postgres";

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
          gs.tenant_id,
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

-- upsert_global_shipment_cost_entry

CREATE OR REPLACE FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_bucket" "public"."global_shipment_cost_bucket", "p_cost_component" "public"."global_shipment_cost_component", "p_amount" numeric, "p_currency_id" bigint DEFAULT NULL::bigint, "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_section_id" bigint DEFAULT NULL::bigint, "p_id" bigint DEFAULT NULL::bigint, "p_description" "text" DEFAULT NULL::"text", "p_is_capitalizable" boolean DEFAULT true) RETURNS "public"."global_shipment_cost_entries"
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

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'amount must be >= 0';
  end if;

  if p_id is not null then
    update public.global_shipment_cost_entries e
    set
      cost_bucket = p_cost_bucket,
      cost_component = p_cost_component,
      is_capitalizable = coalesce(p_is_capitalizable, e.is_capitalizable),
      description = coalesce(p_description, e.description),
      amount = p_amount,
      currency_id = p_currency_id,
      metadata = coalesce(p_metadata, '{}'::jsonb),
      section_id = p_section_id,
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
      cost_bucket,
      cost_component,
      is_capitalizable,
      description,
      amount,
      currency_id,
      metadata,
      section_id
    ) values (
      v_ship.tenant_id,
      p_shipment_id,
      p_cost_bucket,
      p_cost_component,
      coalesce(p_is_capitalizable, true),
      p_description,
      p_amount,
      p_currency_id,
      coalesce(p_metadata, '{}'::jsonb),
      p_section_id
    )
    returning * into v_row;
  end if;

  if coalesce(v_row.is_capitalizable, true)
     and exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  return v_row;
end;
$$;


ALTER FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_bucket" "public"."global_shipment_cost_bucket", "p_cost_component" "public"."global_shipment_cost_component", "p_amount" numeric, "p_currency_id" bigint, "p_metadata" "jsonb", "p_section_id" bigint, "p_id" bigint, "p_description" "text", "p_is_capitalizable" boolean) OWNER TO "postgres";

-- upsert_stock_location

CREATE OR REPLACE FUNCTION "public"."upsert_stock_location"("p_tenant_id" bigint, "p_code" "text", "p_name" "text", "p_kind" "public"."stock_location_kind" DEFAULT 'bin'::"public"."stock_location_kind", "p_is_pickable" boolean DEFAULT true, "p_sort_order" integer DEFAULT 0, "p_is_active" boolean DEFAULT true, "p_is_default" boolean DEFAULT false, "p_id" bigint DEFAULT NULL::bigint, "p_parent_location_id" bigint DEFAULT NULL::bigint) RETURNS "public"."stock_locations"
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
  perform public._assert_parent_warehouse_tenant(p_tenant_id);

  v_action := case when p_id is null then 'create' else 'edit' end;

  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or public.membership_has_module_action(p_tenant_id, 'global_stock_location', v_action)
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
    p_kind, p_parent_location_id, p_tenant_id
  );

  if p_id is not null and p_parent_location_id = p_id then
    raise exception 'location cannot be its own parent';
  end if;

  v_want_default := coalesce(p_is_default, false) and coalesce(p_is_active, true);

  if p_id is null then
    if v_want_default then
      update public.stock_locations
      set is_default = false
      where parent_tenant_id = p_tenant_id
        and is_default = true;
    end if;

    insert into public.stock_locations (
      tenant_id,
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
      p_tenant_id,
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
      and tenant_id = p_tenant_id
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
      where parent_tenant_id = p_tenant_id
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

  if not exists (
    select 1 from public.stock_locations l
    where l.tenant_id = p_tenant_id
      and l.is_default = true
      and l.is_active = true
      and public._stock_location_is_leaf(l.id)
  ) then
    update public.stock_locations
    set is_default = true
    where id = (
      select l.id from public.stock_locations l
      where l.tenant_id = p_tenant_id
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


ALTER FUNCTION "public"."upsert_stock_location"("p_tenant_id" bigint, "p_code" "text", "p_name" "text", "p_kind" "public"."stock_location_kind", "p_is_pickable" boolean, "p_sort_order" integer, "p_is_active" boolean, "p_is_default" boolean, "p_id" bigint, "p_parent_location_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."tenant_role_grants" (
    "id" bigint NOT NULL,
    "tenant_role_id" bigint NOT NULL,
    "module_key" "text" NOT NULL,
    "action" "text" NOT NULL,
    "allowed" boolean NOT NULL,
    "updated_by_email" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."tenant_role_grants" OWNER TO "postgres";


-- RLS policies (8b tables)

DROP POLICY IF EXISTS "batch_code_lists_all" ON public.batch_code_lists;
DROP POLICY IF EXISTS "batch_code_lists_select" ON public.batch_code_lists;
DROP POLICY IF EXISTS "cargo_companies_delete_policy" ON public.cargo_companies;
DROP POLICY IF EXISTS "cargo_companies_insert_policy" ON public.cargo_companies;
DROP POLICY IF EXISTS "cargo_companies_select_policy" ON public.cargo_companies;
DROP POLICY IF EXISTS "cargo_companies_update_policy" ON public.cargo_companies;
DROP POLICY IF EXISTS "global_shipment_boxes_all" ON public.global_shipment_boxes;
DROP POLICY IF EXISTS "global_shipment_boxes_select" ON public.global_shipment_boxes;
DROP POLICY IF EXISTS "global_shipment_cost_entries_all" ON public.global_shipment_cost_entries;
DROP POLICY IF EXISTS "global_shipment_cost_entries_select" ON public.global_shipment_cost_entries;
DROP POLICY IF EXISTS "global_shipment_item_outcomes_all" ON public.global_shipment_item_outcomes;
DROP POLICY IF EXISTS "global_shipment_outcome_vendor_credits_all" ON public.global_shipment_outcome_vendor_credits;
DROP POLICY IF EXISTS "global_shipment_sections_all" ON public.global_shipment_sections;
DROP POLICY IF EXISTS "global_shipment_sections_select" ON public.global_shipment_sections;
DROP POLICY IF EXISTS "global_shipments_all" ON public.global_shipments;
DROP POLICY IF EXISTS "global_shipments_select" ON public.global_shipments;
DROP POLICY IF EXISTS "global_stock_types_all" ON public.global_stock_types;
DROP POLICY IF EXISTS "global_stock_types_select" ON public.global_stock_types;
DROP POLICY IF EXISTS "global_stocks_all" ON public.global_stocks;
DROP POLICY IF EXISTS "stock_locations_all" ON public.stock_locations;
DROP POLICY IF EXISTS "stock_locations_select" ON public.stock_locations;

CREATE POLICY "batch_code_lists_all" ON "public"."batch_code_lists" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "batch_code_lists_select" ON "public"."batch_code_lists" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "batch_code_lists"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "cargo_companies_delete_policy" ON "public"."cargo_companies" FOR DELETE USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "cargo_companies_insert_policy" ON "public"."cargo_companies" FOR INSERT WITH CHECK (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "cargo_companies_select_policy" ON "public"."cargo_companies" FOR SELECT USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "cargo_companies_update_policy" ON "public"."cargo_companies" FOR UPDATE USING (("tenant_id" = "public"."current_tenant_id"()));

CREATE POLICY "global_shipment_boxes_all" ON "public"."global_shipment_boxes" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "global_shipment_boxes_select" ON "public"."global_shipment_boxes" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_boxes"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_shipment_cost_entries_all" ON "public"."global_shipment_cost_entries" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "global_shipment_cost_entries_select" ON "public"."global_shipment_cost_entries" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_cost_entries"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_shipment_item_outcomes_all" ON "public"."global_shipment_item_outcomes" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "global_shipment_outcome_vendor_credits_all" ON "public"."global_shipment_outcome_vendor_credits" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "global_shipment_sections_all" ON "public"."global_shipment_sections" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "global_shipment_sections_select" ON "public"."global_shipment_sections" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipment_sections"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_shipments_all" ON "public"."global_shipments" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "global_shipments_select" ON "public"."global_shipments" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "global_shipments"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));

CREATE POLICY "global_stock_types_all" ON "public"."global_stock_types" TO "authenticated" USING (("public"."is_superadmin"() OR ("tenant_id" IS NULL) OR "public"."user_can_manage_parent_tenant"("tenant_id"))) WITH CHECK (("public"."is_superadmin"() OR ("tenant_id" IS NULL) OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "global_stock_types_select" ON "public"."global_stock_types" FOR SELECT TO "authenticated" USING (true);

CREATE POLICY "global_stocks_all" ON "public"."global_stocks" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "stock_locations_all" ON "public"."stock_locations" TO "authenticated" USING ("public"."user_can_manage_parent_tenant"("tenant_id")) WITH CHECK ("public"."user_can_manage_parent_tenant"("tenant_id"));

CREATE POLICY "stock_locations_select" ON "public"."stock_locations" FOR SELECT TO "authenticated" USING (("public"."user_can_manage_parent_tenant"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "stock_locations"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."is_active" = true))))));
