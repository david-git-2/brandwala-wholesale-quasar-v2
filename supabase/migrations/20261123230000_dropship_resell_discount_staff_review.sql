-- Staff resell discount review: staff read fields, finalize RPC, cancel from review.

CREATE OR REPLACE FUNCTION public.get_shop_order_for_staff (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_items_limit integer DEFAULT NULL::integer,
  p_items_cursor_created_at timestamp with time zone DEFAULT NULL::timestamp with time zone,
  p_items_cursor_id bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
  v_items_limit integer;
  v_items_fetch integer;
  v_items_has_more boolean := false;
  v_items_next_cursor jsonb := null;
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

  if p_items_limit is not null then
    v_items_limit := greatest(1, least(p_items_limit, 100));
    v_items_fetch := v_items_limit + 1;
  end if;

  with item_source as (
    select
      soi.created_at as item_created_at,
      soi.id as item_id,
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
          ),
          'customer_sell', jsonb_build_object(
            'amount', soi.customer_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.customer_sell_price_currency_id
              limit 1
            )
          )
        ),
        'resell_discount', case
          when soi.requested_resell_discount_price_amount is not null then jsonb_build_object(
            'requested_amount', soi.requested_resell_discount_price_amount,
            'requested_currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.requested_resell_discount_price_currency_id
              limit 1
            ),
            'reason', soi.resell_discount_request_reason,
            'requested_at', soi.resell_discount_requested_at
          )
          else null
        end,
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
      ) as item_json
    from public.shop_order_items soi
    left join public.products p on p.id = soi.product_id
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments gship on gship.id = gsi.shipment_id
    where soi.order_id = v_order.id
      and (
        p_items_cursor_created_at is null
        or (soi.created_at, soi.id) > (p_items_cursor_created_at, p_items_cursor_id)
      )
    order by soi.created_at, soi.id
    limit case when v_items_fetch is not null then v_items_fetch end
  ),
  item_page as (
    select *
    from item_source
    order by item_created_at, item_id
    limit case when v_items_limit is not null then v_items_limit end
  ),
  item_tail as (
    select item_created_at, item_id
    from item_page
    order by item_created_at desc, item_id desc
    limit 1
  )
  select
    coalesce(
      (select jsonb_agg(ip.item_json order by ip.item_created_at, ip.item_id) from item_page ip),
      '[]'::jsonb
    ),
    case
      when v_items_limit is not null then (select count(*) > v_items_limit from item_source)
      else false
    end,
    case
      when v_items_limit is not null and (select count(*) from item_source) > v_items_limit then
        (select jsonb_build_object('created_at', item_created_at, 'id', item_id) from item_tail)
      else null
    end
  into v_items, v_items_has_more, v_items_next_cursor;

  v_order_json := jsonb_build_object(
    'id', v_order.id,
    'tenant_id', v_order.tenant_id,
    'order_no', v_order.order_no,
    'name', v_order.name,
    'cart_id', v_order.cart_id,
    'created_by_email', v_order.created_by_email,
    'placement_scope', v_order.placement_scope,
    'created_at', v_order.created_at,
    'updated_at', v_order.updated_at,
    'placed_at', v_order.placed_at,
    'fulfilled_at', v_order.fulfilled_at,
    'global_invoice_id', v_order.global_invoice_id,
    'collection_source', v_collection_source,
    'hidden_from_customer', v_order.hidden_from_customer,
    'catalog_manual_price_entry', v_order.catalog_manual_price_entry,
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
    'items', v_items,
    'items_meta', case
      when p_items_limit is not null then jsonb_build_object(
        'limit', v_items_limit,
        'has_more', v_items_has_more,
        'next_cursor', v_items_next_cursor
      )
      else null
    end
  );
end;
$function$;

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
        'updated_at', soi.updated_at,
        'requested_resell_discount_price_amount', soi.requested_resell_discount_price_amount,
        'requested_resell_discount_price_currency_id', soi.requested_resell_discount_price_currency_id,
        'resell_discount_request_reason', soi.resell_discount_request_reason,
        'resell_discount_requested_at', soi.resell_discount_requested_at
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

ALTER FUNCTION public.get_dropship_order_detail_v2(bigint, bigint) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.finalize_dropship_resell_discount_review (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_lines     jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_line jsonb;
  v_item public.shop_order_items%rowtype;
  v_resolution text;
  v_approved numeric;
  v_currency_id bigint;
  v_required_count integer;
  v_matched_count integer;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'p_lines must be a jsonb array';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  if v_order.status <> 'resell_discount_requested' then
    raise exception 'order is not pending resell discount review';
  end if;

  select count(*) into v_required_count
  from public.shop_order_items soi
  where soi.order_id = p_order_id
    and soi.requested_resell_discount_price_amount is not null;

  select count(*) into v_matched_count
  from jsonb_array_elements(p_lines) el
  join public.shop_order_items soi on soi.id = (el->>'order_item_id')::bigint
  where soi.order_id = p_order_id
    and soi.requested_resell_discount_price_amount is not null
    and el->>'resolution' in ('use_requested', 'use_listed', 'custom');

  if v_matched_count <> v_required_count then
    raise exception 'every line with a discount request must have a resolution';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_item
    from public.shop_order_items
    where id = (v_line->>'order_item_id')::bigint
      and order_id = p_order_id
    for update;

    if not found or v_item.requested_resell_discount_price_amount is null then
      continue;
    end if;

    v_resolution := v_line->>'resolution';
    v_currency_id := coalesce(
      v_item.customer_sell_price_currency_id,
      v_item.requested_resell_discount_price_currency_id,
      v_item.unit_sell_price_currency_id
    );

    if v_resolution = 'use_requested' then
      v_approved := v_item.requested_resell_discount_price_amount;
    elsif v_resolution = 'use_listed' then
      v_approved := coalesce(v_item.customer_sell_price_amount, v_item.unit_sell_price_amount);
    elsif v_resolution = 'custom' then
      v_approved := (v_line->>'approved_resell_amount')::numeric;
      if v_approved is null then
        raise exception 'approved_resell_amount required for custom resolution on item %', v_item.id;
      end if;
    else
      raise exception 'invalid resolution for item %', v_item.id;
    end if;

    if coalesce(v_item.unit_minimum_sell_price_amount, 0) > 0
      and v_approved < v_item.unit_minimum_sell_price_amount then
      raise exception 'price floor violation on item %', v_item.id;
    end if;

    update public.shop_order_items
    set
      customer_sell_price_amount = v_approved,
      customer_sell_price_currency_id = v_currency_id,
      final_price_amount = v_approved,
      final_price_currency_id = v_currency_id,
      confirmed_quantity = v_item.quantity,
      requested_resell_discount_price_amount = null,
      requested_resell_discount_price_currency_id = null,
      resell_discount_request_reason = null,
      resell_discount_requested_at = null,
      updated_at = now()
    where id = v_item.id;
  end loop;

  update public.shop_order_items soi
  set
    final_price_amount = coalesce(
      soi.final_price_amount,
      soi.customer_sell_price_amount,
      soi.unit_sell_price_amount
    ),
    final_price_currency_id = coalesce(
      soi.final_price_currency_id,
      soi.customer_sell_price_currency_id,
      soi.unit_sell_price_currency_id
    ),
    confirmed_quantity = case
      when coalesce(soi.confirmed_quantity, 0) = 0 then soi.quantity
      else soi.confirmed_quantity
    end,
    updated_at = now()
  where soi.order_id = p_order_id
    and soi.final_price_amount is null;

  update public.shop_orders
  set status = 'confirmed'::public.shop_order_status, updated_at = now()
  where id = p_order_id;

  perform public.recompute_dropship_cod_collect_amount(p_order_id);

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$function$;

ALTER FUNCTION public.finalize_dropship_resell_discount_review(bigint, bigint, jsonb) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.finalize_dropship_resell_discount_review(bigint, bigint, jsonb) TO authenticated;

create or replace function public.cancel_shop_order_dropship(p_order_id bigint, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_order public.shop_orders%rowtype;
  v_invoice public.bills%rowtype;
  v_allowed boolean := false;
  v_pick_count integer := 0;
  v_released_picks integer := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_allowed := v_order.status in (
    'submitted', 'draft', 'placed', 'confirmed', 'processing', 'ready_for_pickup',
    'resell_discount_requested'
  );

  if not v_allowed then
    return jsonb_build_object(
      'success', false,
      'error', format('cannot cancel order in status %s', v_order.status)
    );
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks where order_id = p_order_id;

  if v_order.status = 'ready_for_pickup' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.cashbook_entries
    where source_type = 'shop_order'
      and (
        source_id = p_order_id::text
        or source_id = v_order.order_no
        or source_id = v_invoice.invoice_no
      )
      and tenant_id = v_order.tenant_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.bills where id = v_order.global_invoice_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;
  elsif v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.bills where id = v_order.global_invoice_id;
      update public.shop_orders set global_invoice_id = null, updated_at = now() where id = p_order_id;
    end if;
  end if;

  perform public.release_dropship_order_stock(p_order_id, true);
  v_released_picks := v_pick_count;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = false,
    unavailable_reason = null,
    unavailable_at = null,
    unavailable_by_email = null,
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'cancelled'::public.shop_order_status,
    cancel_reason = nullif(trim(p_reason), ''),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'new_status', 'cancelled',
    'cancel_reason', nullif(trim(p_reason), ''),
    'restock_summary', jsonb_build_object(
      'pick_rows_released', v_released_picks,
      'reason', nullif(trim(p_reason), '')
    )
  );
end;
$function$;

ALTER FUNCTION public.get_dropship_order_detail_v2(bigint, bigint) OWNER TO postgres;

CREATE OR REPLACE FUNCTION public.finalize_dropship_resell_discount_review (
  p_tenant_id bigint,
  p_order_id  bigint,
  p_lines     jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_line jsonb;
  v_item public.shop_order_items%rowtype;
  v_resolution text;
  v_approved numeric;
  v_currency_id bigint;
  v_required_count integer;
  v_matched_count integer;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;
  if p_lines is null or jsonb_typeof(p_lines) <> 'array' then
    raise exception 'p_lines must be a jsonb array';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  if v_order.status <> 'resell_discount_requested' then
    raise exception 'order is not pending resell discount review';
  end if;

  select count(*) into v_required_count
  from public.shop_order_items soi
  where soi.order_id = p_order_id
    and soi.requested_resell_discount_price_amount is not null;

  select count(*) into v_matched_count
  from jsonb_array_elements(p_lines) el
  join public.shop_order_items soi on soi.id = (el->>'order_item_id')::bigint
  where soi.order_id = p_order_id
    and soi.requested_resell_discount_price_amount is not null
    and el->>'resolution' in ('use_requested', 'use_listed', 'custom');

  if v_matched_count <> v_required_count then
    raise exception 'every line with a discount request must have a resolution';
  end if;

  for v_line in select * from jsonb_array_elements(p_lines) loop
    select * into v_item
    from public.shop_order_items
    where id = (v_line->>'order_item_id')::bigint
      and order_id = p_order_id
    for update;

    if not found or v_item.requested_resell_discount_price_amount is null then
      continue;
    end if;

    v_resolution := v_line->>'resolution';
    v_currency_id := coalesce(
      v_item.customer_sell_price_currency_id,
      v_item.requested_resell_discount_price_currency_id,
      v_item.unit_sell_price_currency_id
    );

    if v_resolution = 'use_requested' then
      v_approved := v_item.requested_resell_discount_price_amount;
    elsif v_resolution = 'use_listed' then
      v_approved := coalesce(v_item.customer_sell_price_amount, v_item.unit_sell_price_amount);
    elsif v_resolution = 'custom' then
      v_approved := (v_line->>'approved_resell_amount')::numeric;
      if v_approved is null then
        raise exception 'approved_resell_amount required for custom resolution on item %', v_item.id;
      end if;
    else
      raise exception 'invalid resolution for item %', v_item.id;
    end if;

    if coalesce(v_item.unit_minimum_sell_price_amount, 0) > 0
      and v_approved < v_item.unit_minimum_sell_price_amount then
      raise exception 'price floor violation on item %', v_item.id;
    end if;

    update public.shop_order_items
    set
      customer_sell_price_amount = v_approved,
      customer_sell_price_currency_id = v_currency_id,
      final_price_amount = v_approved,
      final_price_currency_id = v_currency_id,
      confirmed_quantity = v_item.quantity,
      requested_resell_discount_price_amount = null,
      requested_resell_discount_price_currency_id = null,
      resell_discount_request_reason = null,
      resell_discount_requested_at = null,
      updated_at = now()
    where id = v_item.id;
  end loop;

  update public.shop_order_items soi
  set
    final_price_amount = coalesce(
      soi.final_price_amount,
      soi.customer_sell_price_amount,
      soi.unit_sell_price_amount
    ),
    final_price_currency_id = coalesce(
      soi.final_price_currency_id,
      soi.customer_sell_price_currency_id,
      soi.unit_sell_price_currency_id
    ),
    confirmed_quantity = case
      when coalesce(soi.confirmed_quantity, 0) = 0 then soi.quantity
      else soi.confirmed_quantity
    end,
    updated_at = now()
  where soi.order_id = p_order_id
    and soi.final_price_amount is null;

  update public.shop_orders
  set status = 'confirmed'::public.shop_order_status, updated_at = now()
  where id = p_order_id;

  perform public.recompute_dropship_cod_collect_amount(p_order_id);

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$function$;

ALTER FUNCTION public.finalize_dropship_resell_discount_review(bigint, bigint, jsonb) OWNER TO postgres;
GRANT EXECUTE ON FUNCTION public.finalize_dropship_resell_discount_review(bigint, bigint, jsonb) TO authenticated;

create or replace function public.cancel_shop_order_dropship(p_order_id bigint, p_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_order public.shop_orders%rowtype;
  v_invoice public.bills%rowtype;
  v_allowed boolean := false;
  v_pick_count integer := 0;
  v_released_picks integer := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_allowed := v_order.status in (
    'submitted', 'draft', 'placed', 'confirmed', 'processing', 'ready_for_pickup',
    'resell_discount_requested'
  );

  if not v_allowed then
    return jsonb_build_object(
      'success', false,
      'error', format('cannot cancel order in status %s', v_order.status)
    );
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks where order_id = p_order_id;

  if v_order.status = 'ready_for_pickup' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.cashbook_entries
    where source_type = 'shop_order'
      and (
        source_id = p_order_id::text
        or source_id = v_order.order_no
        or source_id = v_invoice.invoice_no
      )
      and tenant_id = v_order.tenant_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.bills where id = v_order.global_invoice_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;
  elsif v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.bills where id = v_order.global_invoice_id;
      update public.shop_orders set global_invoice_id = null, updated_at = now() where id = p_order_id;
    end if;
  end if;

  perform public.release_dropship_order_stock(p_order_id, true);
  v_released_picks := v_pick_count;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = false,
    unavailable_reason = null,
    unavailable_at = null,
    unavailable_by_email = null,
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set
    status = 'cancelled'::public.shop_order_status,
    cancel_reason = nullif(trim(p_reason), ''),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'new_status', 'cancelled',
    'cancel_reason', nullif(trim(p_reason), ''),
    'restock_summary', jsonb_build_object(
      'pick_rows_released', v_released_picks,
      'reason', nullif(trim(p_reason), '')
    )
  );
end;
$function$;
