create or replace function "public"."list_global_stocks_cursor"("p_tenant_id" bigint, "p_limit" integer DEFAULT 20, "p_cursor_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_stock_type_id" bigint DEFAULT NULL::bigint, "p_is_sellable" boolean DEFAULT NULL::boolean, "p_shipment_status" "text" DEFAULT NULL::"text", "p_hide_zero_stock" boolean DEFAULT true, "p_location_id" bigint DEFAULT NULL::bigint, "p_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_shipment_id" bigint DEFAULT NULL::bigint, "p_include_total" boolean DEFAULT false) RETURNS "jsonb"
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
  end if;

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

grant execute on function public.list_global_stocks_cursor(bigint, integer, bigint, text, bigint, boolean, text, boolean, bigint, public.stock_availability, bigint, boolean) to authenticated;
