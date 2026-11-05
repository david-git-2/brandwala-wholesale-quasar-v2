-- Phase 6: stock/procurement RPC args p_parent_tenant_id -> p_tenant_id (columns unchanged).

DROP FUNCTION IF EXISTS public._assert_parent_warehouse_tenant(bigint);
DROP FUNCTION IF EXISTS public._can_view_parent_warehouse_stock(bigint);
DROP FUNCTION IF EXISTS public._can_view_stock_locations(bigint);
DROP FUNCTION IF EXISTS public._validate_stock_location_nesting(public.stock_location_kind, bigint, bigint);
DROP FUNCTION IF EXISTS public.assign_shipment_to_child(bigint, bigint, bigint);
DROP FUNCTION IF EXISTS public.bulk_allocate_shipment_stock(bigint, bigint, bigint);
DROP FUNCTION IF EXISTS public.can_act_on_parent_tenant_stock(bigint);
DROP FUNCTION IF EXISTS public.can_act_on_stock_movement_context(bigint, text, text);
DROP FUNCTION IF EXISTS public.create_shipment_draft(bigint, text, public.global_shipment_type, bigint, bigint);
DROP FUNCTION IF EXISTS public.list_child_procurement_lines(bigint, bigint, text, integer, integer);
DROP FUNCTION IF EXISTS public.list_procurement_shop_order_lines(bigint, bigint, text, integer, integer);
DROP FUNCTION IF EXISTS public.list_stock_locations(bigint, boolean);
DROP FUNCTION IF EXISTS public.upsert_global_stock_allocation(bigint, bigint, bigint, integer);
DROP FUNCTION IF EXISTS public.hold_shop_grade_stock_for_order(bigint, bigint, bigint, bigint, integer, bigint, text);
DROP FUNCTION IF EXISTS public.upsert_stock_location(bigint, text, text, public.stock_location_kind, boolean, integer, boolean, boolean, bigint, bigint);
DROP FUNCTION IF EXISTS public._stock_spine_upsert_receive_lot(bigint, bigint, bigint, bigint, integer, bigint, public.stock_availability, bigint);




-- Phase 6 functions from public.sql


CREATE OR REPLACE FUNCTION "public"."_assert_parent_warehouse_tenant"("p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;

  select parent_id into v_parent_id
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant not found';
  end if;

  if v_parent_id is not null then
    raise exception 'stock locations are only for parent warehouse tenants';
  end if;
end;
$$;


ALTER FUNCTION "public"."_assert_parent_warehouse_tenant"("p_tenant_id" bigint) OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."courier_wallet_entity_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."courier_wallet_entity_id_seq" OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."courier_services" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "tenant_id" bigint,
    "code" "text" NOT NULL,
    "name" "text" NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "cod_fee_mode" "text" DEFAULT 'percent_of_collect'::"text" NOT NULL,
    "cod_fee_percent" numeric(5,2) DEFAULT 0.00,
    "cod_fee_flat_amount" numeric(12,2) DEFAULT 0.00,
    "cod_fee_notes" "text",
    "deduct_cod_from_margin_default" boolean DEFAULT false NOT NULL,
    "inside_dhaka_fee" numeric(12,2) DEFAULT 60.00 NOT NULL,
    "outside_dhaka_fee" numeric(12,2) DEFAULT 120.00 NOT NULL,
    "inside_dhaka_return_fee" numeric(12,2) DEFAULT 30.00,
    "outside_dhaka_return_fee" numeric(12,2) DEFAULT 60.00,
    "return_fee_mode" "text" DEFAULT 'flat'::"text" NOT NULL,
    "return_fee_percent" numeric(5,2) DEFAULT 0.00,
    "delivery_attempt_count" integer DEFAULT 2 NOT NULL,
    "hub_hold_days" integer DEFAULT 3 NOT NULL,
    "open_box_default_allowed" boolean DEFAULT false NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "tracking_url_template" "text",
    "wallet_entity_id" bigint DEFAULT "nextval"('"public"."courier_wallet_entity_id_seq"'::"regclass") NOT NULL,
    CONSTRAINT "courier_services_cod_fee_mode_check" CHECK (("cod_fee_mode" = ANY (ARRAY['none'::"text", 'percent_of_collect'::"text", 'flat'::"text", 'tiered_manual'::"text"]))),
    CONSTRAINT "courier_services_return_fee_mode_check" CHECK (("return_fee_mode" = ANY (ARRAY['none'::"text", 'percent_of_forward'::"text", 'flat'::"text", 'tiered_manual'::"text"])))
);


ALTER TABLE "public"."courier_services" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."shop_orders" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "shop_id" bigint NOT NULL,
    "customer_group_id" bigint,
    "cart_id" bigint,
    "order_no" "text" NOT NULL,
    "name" "text" NOT NULL,
    "shop_type_snapshot" "public"."shop_type_enum" NOT NULL,
    "order_mode_snapshot" "public"."shop_order_mode_enum" NOT NULL,
    "is_negotiable_snapshot" boolean DEFAULT false NOT NULL,
    "status" "public"."shop_order_status" DEFAULT 'submitted'::"public"."shop_order_status" NOT NULL,
    "negotiate_round" integer DEFAULT 0 NOT NULL,
    "cargo_rate" numeric(12,4),
    "conversion_rate" numeric(12,4),
    "profit_rate" numeric(12,4),
    "recipient_name" "text",
    "recipient_phone" "text",
    "shipping_address" "text",
    "profile_id" bigint,
    "placed_at" timestamp with time zone,
    "fulfilled_at" timestamp with time zone,
    "global_invoice_id" bigint,
    "created_by_email" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "cod_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "delivery_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "print_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "packing_charge_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "discount_amount" numeric(12,2) DEFAULT 0 NOT NULL,
    "is_prepaid_snapshot" boolean DEFAULT false NOT NULL,
    "delivery_instructions" "text",
    "deduct_charges_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_cod_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_delivery_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_print_from_margin" boolean DEFAULT false NOT NULL,
    "deduct_packing_from_margin" boolean DEFAULT false NOT NULL,
    "recipient_phone_secondary" "text",
    "shipping_district" "text",
    "shipping_thana" "text",
    "cod_collect_amount" numeric(15,2),
    "package_weight_kg" numeric(8,2),
    "sender_name" "text",
    "pickup_phone" "text",
    "pickup_address" "text",
    "allow_open_box" boolean DEFAULT false,
    "driver_notes" "text",
    "courier_service_id" "uuid",
    "courier_name" "text",
    "courier_awb_number" "text",
    "tracking_url" "text",
    "delivered_at" timestamp with time zone,
    "returned_at" timestamp with time zone,
    "default_sender_name" "text",
    "default_pickup_phone" "text",
    "default_pickup_address" "text",
    "default_payout_account_type" "text",
    "default_payout_account_info" "text",
    "package_weight_band" "text" DEFAULT 'under_1kg'::"text",
    "item_category" "text",
    "parcel_description" "text",
    "courier_order_ref" "text",
    "delivery_zone" "text",
    "payout_account_type" "text" DEFAULT 'bank'::"text",
    "payout_account_info" "text",
    "delivery_instruction_notes" "text",
    "courier_tracking_number" "text",
    "courier_consignment_id" "text",
    "courier_cost_amount" numeric(12,2) DEFAULT 0.00,
    "middle_man_reference" "text",
    "courier_remittance_ref" "text",
    "courier_bank_trx_id" "text",
    "replacement_of_order_id" bigint,
    "return_charge_amount" numeric(12,2) DEFAULT 0.00,
    "deduct_return_charge_from_middle_man" boolean DEFAULT true,
    "recipient_profile_id" bigint,
    "return_sub_state" "text",
    "return_override_reason" "text",
    "return_ref" "text",
    "collection_source" "public"."collection_source_type",
    "payout_settlement_status" "text",
    "profit_basis" "text" DEFAULT 'total_cost'::"text",
    "first_offer_rate" numeric,
    "final_offer_rate" numeric,
    "recipient_call_attempt_count" integer DEFAULT 0 NOT NULL,
    "recipient_verified_at" timestamp with time zone,
    "cancel_reason" "text",
    "auto_gifts_applied_at" timestamp with time zone,
    "auto_gifts_apply_result" "jsonb",
    CONSTRAINT "shop_orders_delivery_zone_check" CHECK (("delivery_zone" = ANY (ARRAY['inside_dhaka'::"text", 'outside_dhaka'::"text"]))),
    CONSTRAINT "shop_orders_payout_settlement_status_check" CHECK ((("payout_settlement_status" IS NULL) OR ("payout_settlement_status" = ANY (ARRAY['unpaid'::"text", 'partial'::"text", 'paid'::"text"])))),
    CONSTRAINT "shop_orders_profit_basis_check" CHECK (("profit_basis" = ANY (ARRAY['purchase'::"text", 'total_cost'::"text"]))),
    CONSTRAINT "shop_orders_return_sub_state_check" CHECK (("return_sub_state" = ANY (ARRAY['return_requested'::"text", 'return_finalized'::"text"])))
);


ALTER TABLE "public"."shop_orders" OWNER TO "postgres";


COMMENT ON COLUMN "public"."shop_orders"."collection_source" IS 'Dropship: recipient = courier COD remittance; billing_profile = merchant prepaid. Not the merchant invoice collection_source.';



COMMENT ON COLUMN "public"."shop_orders"."payout_settlement_status" IS 'Merchant profit settlement: unpaid | partial | paid (order-level)';

CREATE OR REPLACE FUNCTION "public"."_can_view_parent_warehouse_stock"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or public.membership_has_module_action(p_tenant_id, 'global_stock', 'view')
    or exists (
      select 1
      from public.tenants child
      inner join public.memberships m on m.tenant_id = child.id
      where child.parent_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and public.membership_has_module_action(child.id, 'global_stock', 'view')
    );
$$;


ALTER FUNCTION "public"."_can_view_parent_warehouse_stock"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_can_view_stock_locations"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public._can_view_parent_warehouse_stock(p_tenant_id)
    or public.membership_has_module_action(p_tenant_id, 'global_stock_location', 'view')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    );
$$;


ALTER FUNCTION "public"."_can_view_stock_locations"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_validate_stock_location_nesting"("p_kind" "public"."stock_location_kind", "p_parent_location_id" bigint, "p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent public.stock_locations%rowtype;
begin
  if p_kind in ('warehouse', 'returns') then
    if p_parent_location_id is not null then
      raise exception 'warehouse and returns must be top-level (no parent)';
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

  if v_parent.parent_tenant_id <> p_tenant_id then
    raise exception 'parent location belongs to another tenant';
  end if;

  if p_kind = 'zone' then
    if v_parent.kind not in ('warehouse', 'returns') then
      raise exception 'zone parent must be a warehouse or returns area';
    end if;
  elsif p_kind = 'shelf' then
    if v_parent.kind <> 'zone' then
      raise exception 'shelf parent must be a zone';
    end if;
  elsif p_kind = 'level' then
    if v_parent.kind <> 'shelf' then
      raise exception 'level parent must be a shelf';
    end if;
  elsif p_kind = 'bin' then
    if v_parent.kind <> 'level' then
      raise exception 'bin parent must be a level';
    end if;
  end if;
end;
$$;


ALTER FUNCTION "public"."_validate_stock_location_nesting"("p_kind" "public"."stock_location_kind", "p_parent_location_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."global_shipment_items" (
    "id" bigint NOT NULL,
    "shipment_id" bigint NOT NULL,
    "product_id" bigint,
    "name" "text" NOT NULL,
    "ordered_quantity" integer NOT NULL,
    "image_url" "text",
    "add_method" "public"."global_shipment_item_add_method" DEFAULT 'manual'::"public"."global_shipment_item_add_method" NOT NULL,
    "purchase_price" numeric DEFAULT 0.0 NOT NULL,
    "product_weight" numeric DEFAULT 0.0 NOT NULL,
    "package_weight" numeric DEFAULT 0.0 NOT NULL,
    "barcode" "text",
    "product_code" "text",
    "source_child_tenant_id" bigint,
    "source_type" "text",
    "source_id" bigint,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "vendor_id" bigint,
    "sort_order" integer DEFAULT 0 NOT NULL,
    "landed_cost_bdt" numeric,
    "received_quantity" integer,
    "section_id" bigint,
    CONSTRAINT "global_shipment_items_name_not_blank" CHECK (("length"(TRIM(BOTH FROM "name")) > 0)),
    CONSTRAINT "global_shipment_items_ordered_quantity_check" CHECK (("ordered_quantity" >= 0)),
    CONSTRAINT "global_shipment_items_received_quantity_check" CHECK ((("received_quantity" IS NULL) OR ("received_quantity" >= 0)))
);


ALTER TABLE "public"."global_shipment_items" OWNER TO "postgres";


COMMENT ON COLUMN "public"."global_shipment_items"."landed_cost_bdt" IS 'Authoritative per-unit landed BDT. Written only by finalize/revision stamp RPCs. Null while draft.';

CREATE OR REPLACE FUNCTION "public"."assign_shipment_to_child"("p_tenant_id" bigint, "p_child_tenant_id" bigint, "p_shipment_id" bigint) RETURNS "jsonb"
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
    and parent_tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'shipment not found or tenant mismatch';
  end if;

  if v_ship.status is distinct from 'received' then
    raise exception 'shipment must be received before assignment';
  end if;

  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_child_tenant_id is not null then
    select exists(
      select 1 from public.tenants t
      where t.id = p_child_tenant_id
        and (t.id = p_tenant_id or t.parent_id = p_tenant_id)
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


ALTER FUNCTION "public"."assign_shipment_to_child"("p_tenant_id" bigint, "p_child_tenant_id" bigint, "p_shipment_id" bigint) OWNER TO "postgres";

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
    where gs.parent_tenant_id = p_tenant_id
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

CREATE OR REPLACE FUNCTION "public"."bulk_allocate_shipment_stock"("p_shipment_id" bigint, "p_child_tenant_id" bigint, "p_allocations" "jsonb" DEFAULT NULL::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return jsonb_build_object('status', 'retired');
end;
$$;


ALTER FUNCTION "public"."bulk_allocate_shipment_stock"("p_shipment_id" bigint, "p_child_tenant_id" bigint, "p_allocations" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_act_on_parent_tenant_stock"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select
    public.has_active_tenant_membership(p_tenant_id)
    or public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      inner join public.tenants t on t.id = m.tenant_id
      where t.parent_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
    or exists (
      select 1
      from public.customer_group_members cgm
      inner join public.customer_groups cg on cg.id = cgm.customer_group_id
      inner join public.shop_customer_group_access scga on scga.customer_group_id = cg.id
      inner join public.shops s on s.id = scga.shop_id
      where public.resolve_parent_tenant_id(s.tenant_id) = p_tenant_id
        and cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
        and scga.status = true
        and s.is_active = true
        and s.deleted_at is null
    )
    or exists (
      select 1
      from public.shops s
      join lateral public.get_shop_permissions_for_customer(s.id) perms on true
      where public.resolve_parent_tenant_id(s.tenant_id) = p_tenant_id
        and s.is_active = true
        and s.deleted_at is null
        and coalesce(perms.can_place_order, false)
    );
$$;


ALTER FUNCTION "public"."can_act_on_parent_tenant_stock"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."can_act_on_stock_movement_context"("p_tenant_id" bigint, "p_reference_type" "text" DEFAULT NULL::"text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
  select
    public.can_act_on_parent_tenant_stock(p_tenant_id)
    or (
      coalesce(p_reference_type, '') = 'shop_order'
      and p_reference_id ~ '^[0-9]+$'
      and exists (
        select 1
        from public.shop_orders o
        join public.shops s on s.id = o.shop_id
        where o.id = p_reference_id::bigint
          and public.resolve_parent_tenant_id(coalesce(s.tenant_id, o.tenant_id)) = p_tenant_id
          and (
            public.is_cart_owner(o.customer_group_id, o.tenant_id)
            or public.has_active_tenant_membership(o.tenant_id)
            or public.has_active_tenant_membership(public.resolve_parent_tenant_id(o.tenant_id))
            or public.is_superadmin()
          )
      )
    );
$_$;


ALTER FUNCTION "public"."can_act_on_stock_movement_context"("p_tenant_id" bigint, "p_reference_type" "text", "p_reference_id" "text") OWNER TO "postgres";

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
      AND gs.parent_tenant_id = p_tenant_id
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
      AND gs.parent_tenant_id = p_tenant_id
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

CREATE OR REPLACE FUNCTION "public"."list_stock_locations"("p_tenant_id" bigint, "p_include_inactive" boolean DEFAULT false) RETURNS SETOF "public"."stock_locations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public._assert_parent_warehouse_tenant(p_tenant_id);

  if not public._can_view_stock_locations(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select l.*
  from public.stock_locations l
  where l.tenant_id = p_tenant_id
    and (p_include_inactive or l.is_active = true)
  order by l.sort_order asc, l.code asc, l.id asc;
end;
$$;


ALTER FUNCTION "public"."list_stock_locations"("p_tenant_id" bigint, "p_include_inactive" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."upsert_global_stock_allocation"("p_tenant_id" bigint, "p_child_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return jsonb_build_object('status', 'retired');
end;
$$;


ALTER FUNCTION "public"."upsert_global_stock_allocation"("p_tenant_id" bigint, "p_child_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer) OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."investors" (
    "id" bigint NOT NULL,
    "tenant_id" bigint NOT NULL,
    "name" "text" NOT NULL,
    "phone" "text",
    "email" "text",
    "address" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "is_active" boolean DEFAULT true NOT NULL,
    "currency_code" "text" DEFAULT 'BDT'::"text" NOT NULL,
    "notes" "text"
);


ALTER TABLE "public"."investors" OWNER TO "postgres";

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
      and parent_tenant_id = p_tenant_id
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



-- _stock_spine_upsert_receive_lot


CREATE OR REPLACE FUNCTION public._stock_spine_upsert_receive_lot(
  p_tenant_id bigint,
  p_shipment_item_id bigint,
  p_outcome_id bigint,
  p_stock_type_id bigint,
  p_delta integer,
  p_location_id bigint,
  p_availability public.stock_availability,
  p_grade_tag_id bigint
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock_id bigint;
BEGIN
  IF p_delta IS NULL OR p_delta <= 0 THEN
    RAISE EXCEPTION 'receive lot delta must be > 0';
  END IF;

  INSERT INTO public.global_stocks (
    parent_tenant_id,
    shipment_item_id,
    outcome_id,
    stock_type_id,
    quantity,
    is_usable,
    availability,
    location_id,
    grade_tag_id
  ) VALUES (
    p_tenant_id,
    p_shipment_item_id,
    p_outcome_id,
    p_stock_type_id,
    p_delta,
    true,
    p_availability,
    p_location_id,
    p_grade_tag_id
  )
  ON CONFLICT (outcome_id, availability, location_id, grade_tag_id)
  DO UPDATE SET
    quantity = public.global_stocks.quantity + excluded.quantity,
    updated_at = now()
  RETURNING id INTO v_stock_id;

  RETURN v_stock_id;
END;
$$;
