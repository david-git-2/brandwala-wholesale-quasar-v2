-- Rename legacy dropship "merchant" RPC and report payload keys to "dropshipper".

CREATE OR REPLACE FUNCTION "public"."get_dropship_dropshipper_billable_charges"("p_order_id" bigint)
RETURNS TABLE("delivery" numeric, "print" numeric, "packing" numeric, "cod" numeric)
LANGUAGE "plpgsql" STABLE
SET "search_path" TO 'public'
AS $$
declare
  v_order public.shop_orders;
  v_settlement_id bigint;
  v_lines jsonb;
  v_line jsonb;
  v_delivery numeric := 0;
  v_print numeric := 0;
  v_packing numeric := 0;
  v_cod numeric := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    delivery := 0;
    print := 0;
    packing := 0;
    cod := 0;
    return next;
    return;
  end if;

  select s.id into v_settlement_id
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if v_settlement_id is not null then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'charge_type', cl.charge_type,
          'amount', cl.amount,
          'payer', cl.payer
        )
      ),
      '[]'::jsonb
    )
    into v_lines
    from public.dropship_settlement_charge_lines cl
    where cl.settlement_id = v_settlement_id
      and cl.charge_type in ('delivery', 'print', 'packing', 'cod');
  else
    v_lines := public.build_default_dropship_settlement_charge_lines(v_order);
  end if;

  for v_line in
    select value from jsonb_array_elements(coalesce(v_lines, '[]'::jsonb))
  loop
    if coalesce(v_line->>'payer', '') = 'merchant' then
      case v_line->>'charge_type'
        when 'delivery' then
          v_delivery := coalesce((v_line->>'amount')::numeric, 0);
        when 'print' then
          v_print := coalesce((v_line->>'amount')::numeric, 0);
        when 'packing' then
          v_packing := coalesce((v_line->>'amount')::numeric, 0);
        when 'cod' then
          v_cod := coalesce((v_line->>'amount')::numeric, 0);
        else
          null;
      end case;
    end if;
  end loop;

  delivery := v_delivery;
  print := v_print;
  packing := v_packing;
  cod := v_cod;
  return next;
end;
$$;

ALTER FUNCTION "public"."get_dropship_dropshipper_billable_charges"("p_order_id" bigint) OWNER TO "postgres";
GRANT ALL ON FUNCTION "public"."get_dropship_dropshipper_billable_charges"("p_order_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "public"."get_dropship_dropshipper_billable_charges"("p_order_id" bigint) TO "authenticated";
GRANT ALL ON FUNCTION "public"."get_dropship_dropshipper_billable_charges"("p_order_id" bigint) TO "service_role";

CREATE OR REPLACE FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"(
  "p_order_id" bigint,
  "p_invoice_id" bigint DEFAULT NULL::bigint,
  "p_invoice_no" "text" DEFAULT NULL::"text",
  "p_profile_id" bigint DEFAULT NULL::bigint,
  "p_note" "text" DEFAULT NULL::"text"
) RETURNS "jsonb"
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
  from public.get_dropship_dropshipper_billable_charges(p_order_id);

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
      from public.global_invoice_items sii
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
        'note', coalesce(p_note, 'Dropshipper bill from dropship order #' || v_order.order_no),
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

CREATE OR REPLACE FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"(
  "p_order_id" bigint,
  "p_delivery_override" numeric DEFAULT NULL::numeric,
  "p_cod_override" numeric DEFAULT NULL::numeric
) RETURNS "jsonb"
LANGUAGE "plpgsql" STABLE SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
declare
  v_order public.shop_orders;
  v_ar public.bills;
  v_ap public.bills;
  v_charges record;
  v_ar_bal jsonb;
  v_ap_bal jsonb;
  v_net_ar numeric(12, 2);
  v_net_ap numeric(12, 2);
  v_old_ar_charges numeric(12, 2);
  v_wanted_ar numeric(12, 2);
  v_wanted_ap numeric(12, 2);
  v_diff numeric(12, 2);
  v_reason text;
  v_parts text[] := array[]::text[];
  v_ar_adj jsonb;
  v_ap_adj jsonb;
  v_books_tenant_id bigint;
  v_has_adjustments boolean := false;
  v_courier_name text;
  v_delivery_merchant numeric(12, 2);
  v_cod_merchant numeric(12, 2);
  v_delivery_payer text;
  v_cod_payer text;
  v_delivery_for_ap numeric(12, 2);
  v_cod_for_ap numeric(12, 2);
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice is required');
  end if;

  select * into v_ar from public.bills where id = v_order.global_invoice_id;
  if v_ar.id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice not found');
  end if;

  if v_ar.invoice_status <> 'issued'::public.global_invoice_status then
    return jsonb_build_object(
      'success', true,
      'has_adjustments', false,
      'skipped', true,
      'reason', 'customer invoice not issued'
    );
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  select * into v_ap
  from public.bills b
  where b.tenant_id = v_books_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
    and b.invoice_status <> 'voided'::public.global_invoice_status
  order by b.id
  limit 1;

  if v_order.courier_service_id is not null then
    select cs.name into v_courier_name
    from public.courier_services cs
    where cs.id = v_order.courier_service_id;
  end if;

  select * into v_charges from public.get_dropship_dropshipper_billable_charges(p_order_id);

  v_delivery_merchant := coalesce(v_charges.delivery, 0);
  v_cod_merchant := coalesce(v_charges.cod, 0);

  if p_delivery_override is not null then
    select coalesce(cl.payer::text, 'recipient')
    into v_delivery_payer
    from public.dropship_order_settlements s
    inner join public.dropship_settlement_charge_lines cl
      on cl.settlement_id = s.id and cl.charge_type = 'delivery'::public.dropship_settlement_charge_type
    where s.shop_order_id = p_order_id
    limit 1;

    if not found then
      v_delivery_payer := case
        when coalesce(v_order.deduct_delivery_from_margin, false) then 'merchant'
        else 'recipient'
      end;
    end if;

    if v_delivery_payer = 'merchant' then
      v_delivery_merchant := round(coalesce(p_delivery_override, 0), 2);
    end if;
  end if;

  if p_cod_override is not null then
    select coalesce(cl.payer::text, 'recipient')
    into v_cod_payer
    from public.dropship_order_settlements s
    inner join public.dropship_settlement_charge_lines cl
      on cl.settlement_id = s.id and cl.charge_type = 'cod'::public.dropship_settlement_charge_type
    where s.shop_order_id = p_order_id
    limit 1;

    if not found then
      v_cod_payer := case
        when coalesce(v_order.deduct_cod_from_margin, false) then 'merchant'
        else 'recipient'
      end;
    end if;

    if v_cod_payer = 'merchant' then
      v_cod_merchant := round(coalesce(p_cod_override, 0), 2);
    end if;
  end if;

  v_ar_bal := public.get_bill_net_balances(v_ar.id);
  v_net_ar := round(
    coalesce((v_ar_bal->>'original_total')::numeric, 0)
    + coalesce((v_ar_bal->>'debits_issued')::numeric, 0)
    - coalesce((v_ar_bal->>'credits_issued')::numeric, 0),
    2
  );

  v_old_ar_charges := round(
    coalesce(v_ar.shipping_charge, 0)
    + coalesce(v_ar.print_charge, 0)
    + coalesce(v_ar.wrapping_charge, 0)
    + coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
    2
  );

  v_wanted_ar := round(
    v_net_ar
    - v_old_ar_charges
    + coalesce(v_delivery_merchant, 0)
    + coalesce(v_charges.print, 0)
    + coalesce(v_charges.packing, 0)
    + coalesce(v_cod_merchant, 0),
    2
  );

  v_diff := round(v_wanted_ar - v_net_ar, 2);

  if abs(v_diff) >= 0.01 then
    v_parts := array[]::text[];
    if coalesce(v_delivery_merchant, 0) is distinct from coalesce(v_ar.shipping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Delivery %s→%s', coalesce(v_ar.shipping_charge, 0), coalesce(v_delivery_merchant, 0))
      );
    end if;
    if coalesce(v_charges.print, 0) is distinct from coalesce(v_ar.print_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Print %s→%s', coalesce(v_ar.print_charge, 0), coalesce(v_charges.print, 0))
      );
    end if;
    if coalesce(v_charges.packing, 0) is distinct from coalesce(v_ar.wrapping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Packing %s→%s', coalesce(v_ar.wrapping_charge, 0), coalesce(v_charges.packing, 0))
      );
    end if;
    if coalesce(v_cod_merchant, 0) is distinct from coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0) then
      v_parts := array_append(
        v_parts,
        format(
          'Courier COD fee %s→%s',
          coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
          coalesce(v_cod_merchant, 0)
        )
      );
    end if;

    v_reason := format(
      'Dropship %s at deliver: %s',
      v_order.order_no,
      coalesce(array_to_string(v_parts, '; '), 'charge adjustment')
    );

    v_ar_adj := jsonb_build_object(
      'bill_id', v_ar.id,
      'invoice_no', v_ar.invoice_no,
      'display_name', coalesce(nullif(trim(v_ar.recipient_name), ''), 'End customer'),
      'invoice_type', v_ar.invoice_type::text,
      'label', 'customer_invoice',
      'adjustment_kind', case when v_diff > 0 then 'debit_note' else 'credit_note' end,
      'amount', abs(v_diff),
      'current_net', v_net_ar,
      'wanted_net', v_wanted_ar,
      'reason', v_reason,
      'detail_parts', to_jsonb(v_parts)
    );
    v_has_adjustments := true;
  end if;

  if v_ap.id is not null and v_ap.invoice_status = 'issued'::public.global_invoice_status then
    v_delivery_for_ap := coalesce(p_delivery_override, v_order.delivery_charge_amount, 0);
    v_cod_for_ap := coalesce(p_cod_override, v_order.cod_charge_amount, 0);
    v_wanted_ap := round(coalesce(v_delivery_for_ap, 0) + coalesce(v_cod_for_ap, 0), 2);

    v_ap_bal := public.get_bill_net_balances(v_ap.id);
    v_net_ap := round(
      coalesce((v_ap_bal->>'original_total')::numeric, 0)
      + coalesce((v_ap_bal->>'debits_issued')::numeric, 0)
      - coalesce((v_ap_bal->>'credits_issued')::numeric, 0),
      2
    );

    v_diff := round(v_wanted_ap - v_net_ap, 2);

    if abs(v_diff) >= 0.01 then
      v_parts := array[]::text[];
      if coalesce(v_delivery_for_ap, 0) is distinct from coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Delivery %s→%s',
            coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0),
            coalesce(v_delivery_for_ap, 0)
          )
        );
      end if;
      if coalesce(v_cod_for_ap, 0) is distinct from coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Courier COD fee %s→%s',
            coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0),
            coalesce(v_cod_for_ap, 0)
          )
        );
      end if;

      v_reason := format(
        'Dropship %s at deliver: %s',
        v_order.order_no,
        coalesce(array_to_string(v_parts, '; '), 'courier charge adjustment')
      );

      v_ap_adj := jsonb_build_object(
        'bill_id', v_ap.id,
        'invoice_no', v_ap.invoice_no,
        'display_name', coalesce(v_courier_name, nullif(trim(v_ap.recipient_name), ''), 'Courier'),
        'invoice_type', v_ap.invoice_type::text,
        'label', 'courier_ap',
        'adjustment_kind', case when v_diff > 0 then 'debit_note' else 'credit_note' end,
        'amount', abs(v_diff),
        'current_net', v_net_ap,
        'wanted_net', v_wanted_ap,
        'reason', v_reason,
        'detail_parts', to_jsonb(v_parts)
      );
      v_has_adjustments := true;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'has_adjustments', v_has_adjustments,
    'customer_invoice', v_ar_adj,
    'courier_ap', v_ap_adj
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."sync_dropship_tenant_b2b_invoice_from_order"("p_order_id" bigint)
RETURNS "jsonb"
LANGUAGE "plpgsql" SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_pick record;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_charges record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'No tenant B2B invoice linked to order');
  end if;

  select * into v_invoice
  from public.bills
  where id = v_order.global_invoice_id
  for update;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'Linked invoice not found');
  end if;

  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    return jsonb_build_object('success', false, 'error', 'Linked invoice is not a dropship B2B invoice');
  end if;

  if v_invoice.invoice_status = 'voided'::public.global_invoice_status then
    return jsonb_build_object('success', false, 'error', 'Cannot sync a voided invoice');
  end if;

  if v_invoice.payment_status in ('paid', 'partially_paid') then
    raise exception
      'Cannot sync dropship B2B invoice after payment (invoice %). Use scripts/sql/backfill_dropship_invoice_charge_payer_mismatch.sql',
      v_invoice.id;
  end if;

  select * into v_charges
  from public.get_dropship_dropshipper_billable_charges(p_order_id);

  for v_pick in (
    select
      sp.quantity as pick_quantity,
      sp.held_stock_id,
      soi.product_id,
      soi.unit_sell_price_amount,
      soi.final_price_amount,
      gs.shipment_item_id as stock_shipment_item_id
    from public.shop_order_item_stock_picks sp
    join public.shop_order_items soi on soi.id = sp.order_item_id
    left join public.global_stocks gs on gs.id = sp.held_stock_id
    where sp.order_id = v_order.id
      and sp.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
  ) loop
    v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
    v_item_line_total := v_pick.pick_quantity * v_item_sell_price;

    update public.global_invoice_items gii
    set
      quantity = v_pick.pick_quantity,
      sell_price_amount = v_item_sell_price,
      line_total_amount = v_item_line_total,
      updated_at = now()
    where gii.invoice_id = v_invoice.id
      and gii.global_stock_id = v_pick.held_stock_id;
  end loop;

  update public.bills
  set
    shipping_charge = coalesce(v_charges.delivery, 0),
    print_charge = coalesce(v_charges.print, 0),
    wrapping_charge = coalesce(v_charges.packing, 0),
    channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(v_charges.cod, 0)),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = 'billing_profile'::public.collection_source_type,
    updated_at = now()
  where id = v_invoice.id;

  perform public.recompute_global_invoice_totals(v_invoice.id);
  perform public.recompute_global_invoice_payment_status(v_invoice.id);

  select * into v_invoice from public.bills where id = v_invoice.id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'total_amount', v_invoice.total_amount,
    'due_amount', v_invoice.due_amount
  );
end;
$$;

DROP FUNCTION IF EXISTS "public"."get_dropship_merchant_billable_charges"(bigint);

CREATE OR REPLACE FUNCTION "public"."get_tenant_month_snapshot_report"("p_tenant_id" bigint, "p_month" "date")
RETURNS "jsonb"
LANGUAGE "plpgsql" STABLE SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
DECLARE
  v_books_id bigint;
  v_start date;
  v_end date;
  v_start_ts timestamptz;
  v_end_ts timestamptz;
  v_net_sales numeric(18,4) := 0;
  v_cogs numeric(18,4) := 0;
  v_gross_profit numeric(18,4) := 0;
  v_cash_collected numeric(18,4) := 0;
  v_ar_outstanding numeric(18,4) := 0;
  v_dropshipper_payable numeric(18,4) := 0;
  v_tenant_cash numeric(18,4) := 0;
  v_ledger_cash numeric(18,4);
  v_courier_holding numeric(18,4) := 0;
  v_cod_unremitted numeric(18,4) := 0;
  v_ap_payable numeric(18,4) := 0;
  v_customer_store_credit numeric(18,4) := 0;
  v_dropshipper_leftover numeric(18,4) := 0;
  v_net_buffer numeric(18,4) := 0;
  v_sales_by_invoice_type jsonb := '{}'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_month IS NULL THEN
    RAISE EXCEPTION 'Tenant ID and month are required';
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  v_start := date_trunc('month', p_month)::date;
  v_end := (date_trunc('month', p_month) + interval '1 month' - interval '1 day')::date;
  v_start_ts := v_start::timestamptz;
  v_end_ts := (v_end + interval '1 day' - interval '1 microsecond');

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH invoice_returned AS (
    SELECT sii.invoice_id, coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii GROUP BY sii.invoice_id
  ),
  month_invoices AS (
    SELECT si.id, si.invoice_type::text AS invoice_type, si.total_amount, coalesce(ir.returned, 0) AS returned
    FROM public.bills si
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    WHERE si.tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  line_metrics AS (
    SELECT
      round(coalesce(sum(
        greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
        - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0))
      ), 0), 2) AS net_revenue,
      0::numeric AS cogs
    FROM public.bill_lines sii
    JOIN public.bills si ON si.id = sii.invoice_id
    WHERE si.tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  sales_by_type AS (
    SELECT invoice_type, round(coalesce(sum(total_amount), 0), 2) AS sales
    FROM month_invoices
    GROUP BY invoice_type
  )
  SELECT
    round(coalesce((SELECT sum(total_amount) FROM month_invoices), 0), 2),
    round(coalesce((SELECT cogs FROM line_metrics), 0), 2),
    coalesce((SELECT jsonb_object_agg(invoice_type, sales) FROM sales_by_type), '{}'::jsonb)
  INTO v_net_sales, v_cogs, v_sales_by_invoice_type;

  v_gross_profit := round(v_net_sales - v_cogs, 2);

  SELECT round(coalesce(sum(gp.amount), 0), 2)
  INTO v_cash_collected
  FROM public.pays gp
  WHERE gp.tenant_id = v_books_id
    AND gp.voided_at IS NULL
    AND coalesce(gp.method::text, '') <> 'wallet_credit'
    AND coalesce(gp.payment_date::timestamptz, gp.created_at) BETWEEN v_start_ts AND v_end_ts;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ar_outstanding
  FROM public.bills si
  WHERE si.tenant_id = v_books_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_type <> 'ap'::public.global_invoice_type
    AND si.profile_id IS NOT NULL
    AND si.due_amount > 0;

  SELECT round(
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0)
    + coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    2
  )
  INTO v_dropshipper_payable
  FROM public.cashbook_accounts
  WHERE tenant_id = v_books_id;

  SELECT coalesce(w.available_balance, 0.0000)
  INTO v_tenant_cash
  FROM public.cashbook_accounts w
  WHERE w.tenant_id = v_books_id
    AND w.entity_type = 'tenant'
    AND w.entity_id = v_books_id
    AND w.currency_code = 'BDT'
  LIMIT 1;

  SELECT l.balance_after
  INTO v_ledger_cash
  FROM public.cashbook_entries l
  WHERE l.tenant_id = v_books_id
    AND l.entity_type = 'tenant'
    AND l.entity_id = v_books_id
    AND coalesce(l.currency_code, 'BDT') = 'BDT'
  ORDER BY l.id DESC
  LIMIT 1;

  IF coalesce(v_tenant_cash, 0) = 0 AND coalesce(v_ledger_cash, 0) <> 0 THEN
    v_tenant_cash := v_ledger_cash;
  END IF;

  SELECT round(coalesce(sum(pending_balance + available_balance), 0), 2)
  INTO v_courier_holding
  FROM public.cashbook_accounts
  WHERE tenant_id = v_books_id
    AND entity_type = 'courier';

  WITH delivered_orders AS (
    SELECT
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      round(coalesce((
        SELECT l.amount
        FROM public.cashbook_entries l
        WHERE l.tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    WHERE public.resolve_books_tenant_id(so.tenant_id) = v_books_id
      AND so.status IN ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status)
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
  )
  SELECT round(coalesce(sum(greatest(cod_collect_amount - remitted_amount, 0)), 0), 2)
  INTO v_cod_unremitted
  FROM delivered_orders;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ap_payable
  FROM public.bills si
  WHERE si.tenant_id = v_books_id
    AND si.invoice_type = 'ap'::public.global_invoice_type
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.due_amount > 0;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'middleman' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_dropshipper_leftover
  FROM public.cashbook_accounts
  WHERE tenant_id = v_books_id;

  v_net_buffer := round(
    coalesce(v_tenant_cash, 0)
    + coalesce(v_courier_holding, 0)
    + coalesce(v_ar_outstanding, 0)
    + coalesce(v_cod_unremitted, 0)
    - coalesce(v_ap_payable, 0)
    - coalesce(v_dropshipper_leftover, 0)
    - coalesce(v_customer_store_credit, 0),
    2
  );

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'month', v_start,
    'start_date', v_start,
    'end_date', v_end,
    'sales_by_invoice_type', v_sales_by_invoice_type,
    'kpis', jsonb_build_object(
      'net_sales', v_net_sales,
      'cogs', v_cogs,
      'gross_profit', v_gross_profit,
      'cash_collected', v_cash_collected,
      'ar_outstanding', v_ar_outstanding,
      'dropshipper_payable', v_dropshipper_payable
    ),
    'position', jsonb_build_object(
      'tenant_cash', round(coalesce(v_tenant_cash, 0), 2),
      'courier_holding', coalesce(v_courier_holding, 0),
      'ar_outstanding', v_ar_outstanding,
      'cod_unremitted', coalesce(v_cod_unremitted, 0),
      'ap_payable', coalesce(v_ap_payable, 0),
      'dropshipper_payable', coalesce(v_dropshipper_leftover, 0),
      'customer_store_credit', coalesce(v_customer_store_credit, 0),
      'net_buffer', v_net_buffer
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_tenant_wallet_liability_report"(
  "p_tenant_id" bigint,
  "p_start_date" "date" DEFAULT NULL::"date",
  "p_end_date" "date" DEFAULT NULL::"date",
  "p_search" "text" DEFAULT NULL::"text",
  "p_page" integer DEFAULT 1,
  "p_page_size" integer DEFAULT 50,
  "p_skip_count" boolean DEFAULT true
) RETURNS "jsonb"
LANGUAGE "plpgsql" STABLE SECURITY DEFINER
SET "search_path" TO 'public'
AS $$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
  v_customer_store_credit numeric(18,4) := 0;
  v_dropshipper_payable numeric(18,4) := 0;
  v_courier numeric(18,4) := 0;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance + available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'courier' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_dropshipper_payable, v_courier
  FROM public.cashbook_accounts
  WHERE tenant_id = v_books_id;

  WITH ledger_agg AS (
    SELECT
      l.entity_id AS profile_id,
      round(
        coalesce(sum(CASE
          WHEN l.type = 'credit'
            AND coalesce(l.metadata->>'reversed_by', '') = ''
            AND coalesce(l.metadata->>'purpose', '') IN ('customer_ar_reduction', 'store_credit')
          THEN l.amount
          ELSE 0
        END), 0)
        - coalesce(sum(CASE
          WHEN l.type = 'debit'
            AND coalesce(l.metadata->>'purpose', '') IN ('reverse_customer_ar_reduction', 'void_store_credit')
          THEN l.amount
          ELSE 0
        END), 0),
        4
      ) AS credit_issued,
      round(coalesce(sum(CASE
        WHEN l.type = 'debit' AND coalesce(l.metadata->>'purpose', '') = 'apply_store_credit' THEN l.amount
        ELSE 0 END), 0), 4) AS credit_applied
    FROM public.cashbook_entries l
    WHERE l.tenant_id = v_books_id
      AND l.entity_type = 'customer'
      AND (v_start_ts IS NULL OR l.created_at >= v_start_ts)
      AND (v_end_ts IS NULL OR l.created_at <= v_end_ts)
    GROUP BY l.entity_id
  ),
  base AS (
    SELECT
      wa.entity_id AS profile_id,
      bp.name,
      bp.phone,
      round(coalesce(la.credit_issued, 0), 2) AS credit_issued,
      round(coalesce(la.credit_applied, 0), 2) AS credit_applied,
      round(coalesce(wa.available_balance, 0), 2) AS outstanding
    FROM public.cashbook_accounts wa
    JOIN public.profiles bp ON bp.id = wa.entity_id
    LEFT JOIN ledger_agg la ON la.profile_id = wa.entity_id
    WHERE wa.tenant_id = v_books_id
      AND wa.entity_type = 'customer'
      AND (
        coalesce(wa.available_balance, 0) > 0
        OR coalesce(la.credit_issued, 0) > 0
        OR coalesce(la.credit_applied, 0) > 0
      )
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(credit_issued), 0), 2) AS credit_issued,
      round(coalesce(sum(credit_applied), 0), 2) AS credit_applied,
      round(coalesce(sum(outstanding), 0), 2) AS outstanding,
      count(*)::bigint AS customer_count
    FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY outstanding DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object(
      'credit_issued', credit_issued, 'credit_applied', credit_applied,
      'outstanding', outstanding, 'customer_count', customer_count,
      'customer_store_credit', v_customer_store_credit,
      'dropshipper_payable', v_dropshipper_payable,
      'courier', v_courier
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'profile_id', profile_id, 'name', name, 'phone', phone,
      'credit_issued', credit_issued, 'credit_applied', credit_applied, 'outstanding', outstanding
    ) ORDER BY outstanding DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;
