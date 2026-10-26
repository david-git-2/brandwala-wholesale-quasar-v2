-- Shipment archive cascades to global_stocks; hide archived stock from operational queries.

alter table public.global_stocks
  add column if not exists is_archived boolean not null default false,
  add column if not exists archived_at timestamptz;

comment on column public.global_stocks.is_archived is
  'When true, stock is hidden from operational warehouse views (e.g. archived shipment).';

create index if not exists global_stocks_parent_tenant_is_archived_idx
  on public.global_stocks using btree (parent_tenant_id, is_archived);

update public.global_stocks gs
set
  is_archived = true,
  archived_at = coalesce(s.archived_at, now()),
  updated_at = now()
from public.global_shipment_items gsi
join public.global_shipments s on s.id = gsi.shipment_id
where gsi.id = gs.shipment_item_id
  and s.is_archived = true
  and gs.is_archived = false;

CREATE OR REPLACE FUNCTION "public"."_set_global_stocks_archived_for_shipment"("p_shipment_id" bigint, "p_archive" boolean) RETURNS "void"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  update public.global_stocks gs
  set
    is_archived = p_archive,
    archived_at = case when p_archive then now() else null end,
    updated_at = now()
  from public.global_shipment_items gsi
  where gsi.id = gs.shipment_item_id
    and gsi.shipment_id = p_shipment_id;
end;
$$;


ALTER FUNCTION "public"."_set_global_stocks_archived_for_shipment"(bigint, boolean) OWNER TO "postgres";

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

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
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


ALTER FUNCTION "public"."archive_shipment"(bigint) OWNER TO "postgres";

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

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
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


ALTER FUNCTION "public"."unarchive_shipment"(bigint) OWNER TO "postgres";

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
        and gs.is_archived = false
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
    ), 0) - public.global_stock_hold_qty(p_global_stock_id),
    0
  );
$$;


ALTER FUNCTION "public"."global_stock_atp_qty"(bigint) OWNER TO "postgres";

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
      (v_is_parent and gsa.parent_tenant_id = p_tenant_id)
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


ALTER FUNCTION "public"."list_global_stock_allocations_paginated"(bigint, integer, integer, text, bigint, bigint) OWNER TO "postgres";

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


ALTER FUNCTION "public"."list_allocatable_stock_paginated"(bigint, integer, integer, text, bigint, bigint) OWNER TO "postgres";

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
    and gs.is_archived = false
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
    left join public.global_shipment_item_outcomes o on o.id = gs.outcome_id
    where gs.parent_tenant_id = p_tenant_id
      and gs.is_archived = false
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


ALTER FUNCTION "public"."list_global_stocks_paginated"(bigint, integer, integer, text, bigint, boolean, text, boolean, bigint, public.stock_availability) OWNER TO "postgres";

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
    where gs.parent_tenant_id = p_tenant_id
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


ALTER FUNCTION "public"."list_global_stocks_cursor"(bigint, integer, bigint, text, bigint, boolean, text, boolean, bigint, public.stock_availability, bigint, boolean, bigint, text, text) OWNER TO "postgres";

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
    where gs.parent_tenant_id = p_tenant_id
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


ALTER FUNCTION "public"."list_global_stocks_groups"(bigint, text, integer, integer, text, bigint, boolean, text, boolean, bigint, public.stock_availability, bigint, bigint) OWNER TO "postgres";

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


ALTER FUNCTION "public"."search_stock_network"(bigint, text, text, text, bigint, text, bigint, boolean, integer, integer) OWNER TO "postgres";

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
      and f.billing_profile_id is not null;

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
        and f.billing_profile_id is not null
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
      where gs.parent_tenant_id = v_parent_tenant_id
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
      where gs.parent_tenant_id = v_parent_tenant_id
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


ALTER FUNCTION "public"."fill_preorder_demand_oldest_stock_for_document"(bigint, text, bigint) OWNER TO "postgres";

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
    and gs.is_archived = false
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
    left join public.global_shipment_item_outcomes o on o.id = gs.outcome_id
    where gs.parent_tenant_id = p_tenant_id
      and gs.is_archived = false
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
  where gs.parent_tenant_id = p_tenant_id
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


CREATE OR REPLACE FUNCTION public.get_procurement_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
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
  WHERE gs.parent_tenant_id = v_books_id
    AND gs.is_archived = false;

  SELECT
    coalesce(count(*) FILTER (WHERE s.status = 'in_transit'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'draft'), 0),
    coalesce(count(*) FILTER (WHERE s.status = 'received'), 0)
  INTO v_in_transit, v_draft, v_received
  FROM public.global_shipments s
  WHERE s.parent_tenant_id = v_books_id
    AND s.is_archived = false;

  SELECT coalesce(jsonb_agg(row_to_json(g) ORDER BY g.qty DESC), '[]'::jsonb)
  INTO v_grades
  FROM (
    SELECT coalesce(t.name, 'Ungraded') AS name, sum(gs.quantity)::bigint AS qty
    FROM public.global_stocks gs
    LEFT JOIN public.tags t ON t.id = gs.grade_tag_id
    WHERE gs.parent_tenant_id = v_books_id
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
    WHERE s.parent_tenant_id = v_books_id
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
    WHERE gs.parent_tenant_id = v_books_id
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

ALTER FUNCTION public.get_procurement_dashboard_metrics(bigint) OWNER TO postgres;

