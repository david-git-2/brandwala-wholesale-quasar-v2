-- Dropship gifts: sync RPC bodies
CREATE OR REPLACE FUNCTION "public"."advance_dropship_order_status"("p_order_id" bigint, "p_target_status" "public"."shop_order_status", "p_remittance_ref" "text" DEFAULT NULL::"text", "p_bank_trx_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  end if;

  if p_target_status in ('shipped'::public.shop_order_status, 'delivered'::public.shop_order_status) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Use ship_dropship_order_and_issue_merchant_bill or mark_dropship_order_delivered instead of advance to %s',
        p_target_status
      )
    );
  end if;

  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed')
     and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in (
      'processing', 'ready_for_pickup', 'returned', 'payment_received', 'cancelled'
    ) then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Invalid status transition for dropship order from %s to %s',
        v_current_status,
        p_target_status
      )
    );
  end if;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.payment_status in ('paid', 'partially_paid') then
      return jsonb_build_object(
        'success', false,
        'error', 'Cannot rollback: merchant bill has payments allocated'
      );
    end if;
  end if;

  if p_target_status = 'processing'::public.shop_order_status
     and v_current_status = 'confirmed'::public.shop_order_status
     and v_order.recipient_verified_at is null then
    return jsonb_build_object(
      'success', false,
      'error', 'Recipient must confirm by phone before processing'
    );
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status = 'cancelled' then
    perform public.release_dropship_order_stock(p_order_id, true);
  end if;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
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

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.bills where id = v_order.global_invoice_id;
  end if;

  if p_target_status = 'processing'::public.shop_order_status then
    perform public.apply_shop_auto_gift_items(p_order_id);
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

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
      and coalesce((
        select sum(sp.quantity) from public.shop_order_item_stock_picks sp where sp.order_item_id = soi.id
      ), 0) >= soi.quantity
    )
  ), true)
  into v_all_lines_resolved
  from public.shop_order_items soi
  where soi.order_id = v_order.id and soi.quantity > 0;

  select coalesce(sum(coalesce(soi.confirmed_quantity, 0)), 0)
  into v_total_delivered_qty
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    jsonb_agg(
      to_jsonb(cs.*)
      order by cs.created_at, cs.id
    ),
    '[]'::jsonb
  )
  into v_courier_services
  from public.courier_services cs
  where cs.is_active = true
    and (cs.tenant_id is null or cs.tenant_id = v_order.tenant_id);

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
        'billing_profile_id', v_order.billing_profile_id,
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
        'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
        'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total),
        'item_count', jsonb_array_length(v_items),
        'delivery_zone', v_order.delivery_zone,
        'courier_name', v_order.courier_name,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'recipient_call_attempt_count', coalesce(v_order.recipient_call_attempt_count, 0),
        'recipient_verified_at', v_order.recipient_verified_at,
        'cancel_reason', v_order.cancel_reason
      ) || jsonb_build_object(
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
    'lookups', jsonb_build_object(
      'courier_services', v_courier_services
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
CREATE OR REPLACE FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint DEFAULT NULL::bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_billing_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_billing_profile_id bigint;
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

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required on the order');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_channel_meta := jsonb_strip_nulls(jsonb_build_object(
    'cod_collect_amount', v_order.cod_collect_amount,
    'collection_source', 'billing_profile',
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
      v_item_sell_price := coalesce(v_pick.gift_cost_amount, 0);
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
      'name_snapshot', coalesce(v_pick.stock_name, v_pick.line_name),
      'barcode_snapshot', v_pick.stock_barcode,
      'product_code_snapshot', v_pick.stock_product_code,
      'quantity', v_pick.pick_quantity,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_pick.stock_assigned_child,
      'line_meta', jsonb_build_object('resell_price_amount', v_resell_price)
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

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
        'billing_profile_id', v_billing_profile_id,
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
        'collection_source', 'billing_profile'::public.collection_source_type,
        'channel_meta', v_channel_meta
      )),
      'items', v_items,
      'shop_order_id', p_order_id
    )
  );
end;
$$;

ALTER FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") OWNER TO "postgres";
