-- Migration: Support parent_tenant_id across shop and order operations
-- Enables parent tenant staff to view, manage, and process orders and shops belonging to child tenants under the parent company.

-- 1. Update is_tenant_staff to recognize parent tenant staff for child tenant actions
CREATE OR REPLACE FUNCTION "public"."is_tenant_staff"("p_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.memberships m
    where (m.tenant_id = p_tenant_id or m.tenant_id = public.resolve_parent_tenant_id(p_tenant_id))
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'superadmin'::public.app_role
        or m.role = 'admin'::public.app_role
        or public.has_module_action(m.tenant_id, 'shop_order_mgmt', 'view')
      )
  );
$$;

ALTER FUNCTION "public"."is_tenant_staff"("p_tenant_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."is_tenant_staff"("p_tenant_id" bigint) TO "authenticated";

-- 2. Update list_shop_orders_for_staff
DROP FUNCTION IF EXISTS public.list_shop_orders_for_staff(bigint, integer, integer, text, text, bigint) CASCADE;
DROP FUNCTION IF EXISTS public.list_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, bigint) CASCADE;

CREATE OR REPLACE FUNCTION "public"."list_shop_orders_for_staff"(
  "p_tenant_id" bigint,
  "p_parent_tenant_id" bigint DEFAULT NULL::bigint,
  "p_limit" integer DEFAULT 20,
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
  "item_count" bigint
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
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  join public.customer_groups cg on cg.id = o.customer_group_id
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
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

ALTER FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."list_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_search" "text", "p_status" "text", "p_shop_id" bigint) TO "authenticated";

-- 3. Update list_dropship_shop_orders_for_staff
DROP FUNCTION IF EXISTS public.list_dropship_shop_orders_for_staff(bigint, integer, integer, text, text, text[]) CASCADE;
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
  "payout_settlement_status" "text"
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
    o.payout_settlement_status
  from public.shop_orders o
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.courier_services cs on cs.id::text = o.courier_service_id::text
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
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$$;

ALTER FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text", "p_statuses" "text"[]) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."list_dropship_shop_orders_for_staff"("p_tenant_id" bigint, "p_parent_tenant_id" bigint, "p_limit" integer, "p_offset" integer, "p_status" "text", "p_search" "text", "p_statuses" "text"[]) TO "authenticated";

-- 4. Update get_shop_order_for_staff
CREATE OR REPLACE FUNCTION "public"."get_shop_order_for_staff"(
  p_tenant_id bigint,
  p_order_id bigint
)
RETURNS "jsonb"
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO 'public'
STABLE
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

  if v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id then
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
    from public.sales_invoices inv
    where inv.id = v_order.global_invoice_id;
  end if;
  if v_collection_source is null and v_order.is_prepaid_snapshot then
    v_collection_source := 'billing_profile'::public.collection_source_type;
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
      'group_name', v_customer_group_name
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
      'billing_profile_id', v_order.billing_profile_id,
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
GRANT ALL ON FUNCTION "public"."get_shop_order_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";

-- 5. Update get_dropship_order_detail_v2
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
  v_courier_services jsonb;
  v_items_resell_total numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_recipient_grand_total numeric := 0;
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

  if v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id then
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
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'global_stock_id', soi.global_stock_id,
        'product_id', soi.product_id,
        'product_name', p.name,
        'product_image_url', p.image_url,
        'product_barcode', p.barcode,
        'product_code', p.product_code,
        'product_brand', p.brand,
        'product_category', p.category,
        'quantity', soi.quantity,
        'confirmed_quantity', soi.confirmed_quantity,
        'returned_quantity', soi.returned_quantity,
        'unit_list_price_amount', soi.unit_list_price_amount,
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_buy_price_amount', soi.unit_buy_price_amount,
        'customer_offer_amount', soi.customer_offer_amount,
        'staff_offer_amount', soi.staff_offer_amount,
        'final_price_amount', soi.final_price_amount,
        'pricing_notes', soi.pricing_notes,
        'grade_tag_id', soi.grade_tag_id,
        'is_fulfillment_unavailable', coalesce(soi.is_fulfillment_unavailable, false),
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        soi.unit_list_price_amount
      ) * soi.quantity
    ),
    0
  )
  into v_items_resell_total
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  v_recipient_charge_total := coalesce(v_order.recipient_delivery_charge, 0)
    + coalesce(v_order.recipient_print_charge, 0)
    + coalesce(v_order.recipient_packing_charge, 0)
    + coalesce(v_order.recipient_other_charge, 0);

  v_recipient_grand_total := v_items_resell_total + v_recipient_charge_total;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', cs.id,
        'code', cs.code,
        'name', cs.name,
        'inside_dhaka_fee', cs.inside_dhaka_fee,
        'outside_dhaka_fee', cs.outside_dhaka_fee,
        'cod_fee_percent', cs.cod_fee_percent
      )
      order by cs.name
    ),
    '[]'::jsonb
  )
  into v_courier_services
  from public.courier_services cs
  where cs.is_active = true
    and (cs.tenant_id is null or cs.tenant_id = v_order.tenant_id or cs.tenant_id = v_order.parent_tenant_id);

  return jsonb_build_object(
    'order', to_jsonb(v_order) || jsonb_build_object(
      'shop_name', v_shop_name,
      'customer_group_name', v_customer_group_name,
      'currency_symbol', v_sell_symbol,
      'items_resell_total', v_items_resell_total,
      'recipient_charge_total', v_recipient_charge_total,
      'recipient_grand_total', v_recipient_grand_total
    ),
    'items', v_items,
    'courier_services', v_courier_services
  );
end;
$$;

ALTER FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";

-- 6. Update get_dropship_management_order
CREATE OR REPLACE FUNCTION "public"."get_dropship_management_order"(
  p_tenant_id bigint,
  p_order_id bigint
)
RETURNS "jsonb"
LANGUAGE "plpgsql"
STABLE
SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
declare
  v_detail jsonb;
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_charge_lines jsonb;
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_order_item_quantity integer;
  v_company_procurement_cost numeric(15,2);
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_courier_name text;
  v_has_settlement boolean := false;
  v_invoice jsonb;
  v_is_returned boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id);

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  v_is_returned := v_order.status = 'returned'::public.shop_order_status;

  if v_order.status not in ('shipped', 'delivered', 'payment_received', 'reseller_paid', 'returned') then
    raise exception 'order status % is not eligible for dropship management desk', v_order.status;
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);

  select coalesce(cs.name, v_order.courier_name)
  into v_courier_name
  from public.courier_services cs
  where cs.id::text = v_order.courier_service_id::text;

  select * into v_settlement
  from public.dropship_order_settlements
  where order_id = p_order_id;

  if v_settlement.id is not null then
    v_has_settlement := true;
    v_reseller_purchase_cost := v_settlement.reseller_purchase_cost;
    v_company_procurement_cost := v_settlement.company_procurement_cost;
    v_calculated_cod := v_settlement.calculated_cod_amount;
    v_collected_cod := v_settlement.actual_cod_collected;
  else
    select
      coalesce(sum(coalesce(soi.unit_buy_price_amount, 0) * soi.quantity), 0),
      coalesce(sum(soi.quantity), 0)
    into v_reseller_purchase_cost, v_order_item_quantity
    from public.shop_order_items soi
    where soi.order_id = p_order_id;

    if v_order_item_quantity > 0 then
      v_reseller_unit_purchase_cost := round(v_reseller_purchase_cost / v_order_item_quantity, 2);
    else
      v_reseller_unit_purchase_cost := 0;
    end if;

    select coalesce(sum(coalesce(gsa.cost_bdt, 0) * soisp.quantity), 0)
    into v_company_procurement_cost
    from public.shop_order_item_stock_picks soisp
    join public.global_stock_allocations gsa on gsa.id = soisp.global_stock_allocation_id
    where soisp.order_id = p_order_id;

    v_calculated_cod := coalesce(v_order.cod_collect_amount, (v_detail->'order'->>'recipient_grand_total')::numeric, 0);
    v_collected_cod := v_calculated_cod;
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', cl.id,
        'charge_type', cl.charge_type,
        'amount', cl.amount,
        'deduct_from_reseller', cl.deduct_from_reseller,
        'order_id', cl.order_id,
        'description', cl.description
      )
      order by cl.id
    ),
    '[]'::jsonb
  )
  into v_charge_lines
  from public.dropship_settlement_charge_lines cl
  where cl.order_id = p_order_id;

  if v_order.global_invoice_id is not null then
    select jsonb_build_object(
      'id', inv.id,
      'invoice_no', inv.invoice_number,
      'status', inv.status,
      'total_amount', inv.total_amount,
      'issued_at', inv.issued_at
    )
    into v_invoice
    from public.sales_invoices inv
    where inv.id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object(
    'order_id', p_order_id,
    'order_no', v_order.order_no,
    'order_status', v_order.status,
    'created_at', v_order.created_at,
    'recipient_name', v_order.recipient_name,
    'recipient_phone', v_order.recipient_phone,
    'recipient_address', v_order.recipient_address,
    'courier_name', v_courier_name,
    'courier_awb_number', v_order.courier_awb_number,
    'reseller_name', v_detail->'order'->>'customer_group_name',
    'reseller_email', v_order.created_by_email,
    'items', v_detail->'items',
    'recipient_grand_total', (v_detail->'order'->>'recipient_grand_total')::numeric,
    'cod_collect_amount', coalesce(v_order.cod_collect_amount, (v_detail->'order'->>'recipient_grand_total')::numeric),
    'reseller_purchase_cost', v_reseller_purchase_cost,
    'reseller_unit_purchase_cost', coalesce(v_reseller_unit_purchase_cost, 0),
    'company_procurement_cost', v_company_procurement_cost,
    'calculated_cod_amount', v_calculated_cod,
    'actual_cod_collected', v_collected_cod,
    'charge_lines', v_charge_lines,
    'has_settlement', v_has_settlement,
    'invoice', v_invoice,
    'courier_remittance_ref', v_order.courier_remittance_ref,
    'collection_source', v_order.collection_source,
    'payout_settlement_status', v_order.payout_settlement_status,
    'is_returned', v_is_returned
  );
end;
$$;

ALTER FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."get_dropship_management_order"("p_tenant_id" bigint, "p_order_id" bigint) TO "authenticated";

-- 7. Update browse_shop_catalog_for_admin
CREATE OR REPLACE FUNCTION "public"."browse_shop_catalog_for_admin"(
  "p_tenant_id" bigint,
  "p_shop_id" bigint,
  "p_search" "text" DEFAULT NULL::"text",
  "p_limit" integer DEFAULT 24,
  "p_offset" integer DEFAULT 0,
  "p_include_below_min_units" boolean DEFAULT false
) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop record;
  v_parent_tenant_id bigint;
  v_limit integer;
  v_offset integer;
  v_min_units integer;
  v_result jsonb;
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
    and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id)
    and deleted_at is null;

  if v_shop.id is null then
    raise exception 'shop not found';
  end if;

  if v_shop.shop_type <> 'vendor_catalog' then
    return jsonb_build_object(
      'data', '[]'::jsonb,
      'meta', jsonb_build_object(
        'total', 0,
        'page', 1,
        'page_size', coalesce(p_limit, 24),
        'total_pages', 1
      )
    );
  end if;

  v_limit := greatest(coalesce(p_limit, 24), 1);
  v_offset := greatest(coalesce(p_offset, 0), 0);
  v_min_units := case
    when coalesce(p_include_below_min_units, false) then 0
    else greatest(coalesce(v_shop.min_available_units, 0), 0)
  end;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_shop.tenant_id);

  with scope_rows as (
    select
      v.id as vendor_id,
      v.name as vendor_name,
      v.code as vendor_code,
      b.id as brand_id,
      b.name as brand_name,
      c.id as category_id,
      c.name as category_name
    from (
      select
        (elem->>'vendor_code') as vendor_code,
        jsonb_array_elements_text(coalesce(elem->'brands', '[]'::jsonb)) as brand_name
      from jsonb_array_elements(
        case
          when v_shop.vendor_filters is not null and jsonb_typeof(v_shop.vendor_filters) = 'array' and jsonb_array_length(v_shop.vendor_filters) > 0
            then v_shop.vendor_filters
          when v_shop.vendor_code is not null and length(trim(v_shop.vendor_code)) > 0
            then jsonb_build_array(jsonb_build_object('vendor_code', v_shop.vendor_code, 'brands', '[]'::jsonb))
          else '[]'::jsonb
        end
      ) as elem
    ) scope
    inner join public.vendors v on v.code = scope.vendor_code
      and (v.tenant_id = v_parent_tenant_id or v.tenant_id = v_shop.tenant_id)
      and v.is_active = true
      and v.deleted_at is null
    left join public.brands b on b.vendor_id = v.id
      and (scope.brand_name is null or scope.brand_name = '' or b.name = scope.brand_name)
      and b.is_active = true
      and b.deleted_at is null
    left join public.categories c on c.brand_id = b.id
      and c.is_active = true
      and c.deleted_at is null
  ),
  catalog_units as (
    select
      p.id as product_id,
      coalesce(
        sum(
          greatest(
            coalesce(
              case
                when si.received_quantity is not null then si.received_quantity
                when si.order_quantity is not null then si.order_quantity
                else si.quantity
              end,
              0
            ) - coalesce(si.allocated_quantity, 0),
            0
          )
        ),
        0
      )::integer as available_units
    from public.products p
    inner join scope_rows sr on sr.vendor_id = p.vendor_id
      and (sr.brand_id is null or sr.brand_id = p.brand_id)
      and (sr.category_id is null or sr.category_id = p.category_id)
    inner join public.shipment_items si on si.product_id = p.id
    inner join public.global_shipments gs on gs.id = si.shipment_id
    where gs.parent_tenant_id = v_parent_tenant_id
      and p.is_active = true
      and p.deleted_at is null
    group by p.id
  ),
  scoped_products as (
    select distinct on (p.id)
      p.id as product_id,
      p.name as product_name,
      p.image_url,
      p.barcode,
      p.product_code,
      sr.brand_name,
      sr.category_name,
      sr.vendor_name,
      sr.vendor_code,
      coalesce(cu.available_units, 0) as available_units,
      p.created_at
    from public.products p
    inner join scope_rows sr on sr.vendor_id = p.vendor_id
      and (sr.brand_id is null or sr.brand_id = p.brand_id)
      and (sr.category_id is null or sr.category_id = p.category_id)
    left join catalog_units cu on cu.product_id = p.id
    where p.is_active = true
      and p.deleted_at is null
      and coalesce(cu.available_units, 0) >= v_min_units
      and (
        p_search is null
        or length(trim(p_search)) = 0
        or p.name ilike ('%' || trim(p_search) || '%')
        or p.product_code ilike ('%' || trim(p_search) || '%')
        or p.barcode ilike ('%' || trim(p_search) || '%')
        or sr.brand_name ilike ('%' || trim(p_search) || '%')
        or sr.vendor_name ilike ('%' || trim(p_search) || '%')
      )
  ),
  counted as (
    select count(*)::integer as total_count from scoped_products
  ),
  paged_rows as (
    select *
    from scoped_products
    order by created_at desc, product_id desc
    limit v_limit
    offset v_offset
  )
  select jsonb_build_object(
    'data', coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'product_id', r.product_id,
          'product_name', r.product_name,
          'image_url', r.image_url,
          'barcode', r.barcode,
          'product_code', r.product_code,
          'brand_name', r.brand_name,
          'category_name', r.category_name,
          'vendor_name', r.vendor_name,
          'vendor_code', r.vendor_code,
          'available_units', r.available_units
        )
      )
      from paged_rows r
    ), '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', coalesce((select total_count from counted), 0),
      'page', (v_offset / v_limit) + 1,
      'page_size', v_limit,
      'total_pages', greatest(ceil(coalesce((select total_count from counted), 0)::numeric / v_limit)::integer, 1)
    )
  ) into v_result;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."browse_shop_catalog_for_admin"("p_tenant_id" bigint, "p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer, "p_include_below_min_units" boolean) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."browse_shop_catalog_for_admin"("p_tenant_id" bigint, "p_shop_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer, "p_include_below_min_units" boolean) TO "authenticated";

-- 8. Update delete_shop
CREATE OR REPLACE FUNCTION "public"."delete_shop"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  update public.shops
  set
    deleted_at = now(),
    deleted_by = public.current_user_email(),
    is_active = false
  where id = p_shop_id
    and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id)
    and deleted_at is null;

  if not found then
    raise exception 'shop not found or already deleted';
  end if;
end;
$$;

ALTER FUNCTION "public"."delete_shop"("p_shop_id" bigint, "p_tenant_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."delete_shop"("p_shop_id" bigint, "p_tenant_id" bigint) TO "authenticated";

-- 9. Update delete_shop_order
CREATE OR REPLACE FUNCTION "public"."delete_shop_order"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_item record;
  v_allocation_id bigint;
  v_stock_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) and not (v_order.parent_tenant_id is not null and public.is_tenant_staff(v_order.parent_tenant_id)) then
    raise exception 'Access denied';
  end if;

  if v_order.status = 'fulfilled' then
    raise exception 'Cannot delete a fulfilled order';
  end if;

  if exists (
    select 1
    from public.shop_orders o
    where o.replacement_of_order_id = p_order_id
  ) then
    raise exception 'Cannot delete order: a replacement order references it';
  end if;

  perform public.purge_shop_order_financial_artifacts(p_order_id);

  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    v_allocation_id := v_item.global_stock_allocation_id;
    v_stock_id := v_item.global_stock_id;

    if v_allocation_id is not null then
      update public.global_stock_allocations
      set
        allocated_quantity = greatest(0, allocated_quantity - v_item.quantity),
        updated_at = now()
      where id = v_allocation_id;
    end if;

    if v_stock_id is not null then
      update public.global_stocks
      set
        allocated_quantity = greatest(0, allocated_quantity - v_item.quantity),
        updated_at = now()
      where id = v_stock_id;
    end if;

    delete from public.shop_stock_reservations where cart_item_id = v_item.id;
  end loop;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;
  delete from public.shop_order_items where order_id = p_order_id;
  delete from public.shop_orders where id = p_order_id;
end;
$$;

ALTER FUNCTION "public"."delete_shop_order"("p_order_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."delete_shop_order"("p_order_id" bigint) TO "authenticated";

-- 10. Update update_shop_order_status_for_staff
CREATE OR REPLACE FUNCTION "public"."update_shop_order_status_for_staff"(
  p_tenant_id bigint,
  p_order_id bigint,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null or p_status is null then
    raise exception 'tenant, order, and status required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or (v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    status = p_status::public.shop_order_status,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;

ALTER FUNCTION "public"."update_shop_order_status_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_status" text) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."update_shop_order_status_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_status" text) TO "authenticated";

-- 11. Update update_shop_order_charges_for_staff
CREATE OR REPLACE FUNCTION "public"."update_shop_order_charges_for_staff"(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or (v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    recipient_delivery_charge = coalesce((p_payload->>'recipient_delivery_charge')::numeric, o.recipient_delivery_charge),
    recipient_print_charge = coalesce((p_payload->>'recipient_print_charge')::numeric, o.recipient_print_charge),
    recipient_packing_charge = coalesce((p_payload->>'recipient_packing_charge')::numeric, o.recipient_packing_charge),
    recipient_other_charge = coalesce((p_payload->>'recipient_other_charge')::numeric, o.recipient_other_charge),
    cod_collect_amount = coalesce((p_payload->>'cod_collect_amount')::numeric, o.cod_collect_amount),
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;

ALTER FUNCTION "public"."update_shop_order_charges_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" jsonb) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."update_shop_order_charges_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" jsonb) TO "authenticated";
