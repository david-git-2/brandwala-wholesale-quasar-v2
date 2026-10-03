-- Warehouse list: location subtree filter, grade filter, group-by headers

drop function if exists public.list_global_stocks_cursor(
  bigint, integer, bigint, text, bigint, boolean, text, boolean, bigint,
  public.stock_availability, bigint, boolean
);

drop function if exists public.list_global_stocks_paginated(
  bigint, integer, integer, text, bigint, boolean, text, boolean, bigint,
  public.stock_availability, bigint
);

create or replace function public.stock_location_matches_filter(
  p_location_id bigint,
  p_filter_id bigint
)
returns boolean
language sql
stable
set search_path = public
as $$
  select
    p_filter_id is null
    or p_location_id is null
    or p_location_id = p_filter_id
    or exists (
      with recursive descendants as (
        select id
        from public.stock_locations
        where id = p_filter_id
        union all
        select sl.id
        from public.stock_locations sl
        inner join descendants d on sl.parent_location_id = d.id
      )
      select 1
      from descendants
      where id = p_location_id
    );
$$;

create or replace function public.list_global_stocks_paginated(
  p_tenant_id bigint,
  p_page integer default 1,
  p_page_size integer default 20,
  p_search text default null,
  p_stock_type_id bigint default null,
  p_is_sellable boolean default null,
  p_shipment_status text default null,
  p_hide_zero_stock boolean default true,
  p_location_id bigint default null,
  p_availability public.stock_availability default null,
  p_shipment_id bigint default null,
  p_grade_tag_id bigint default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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
  where gs.parent_tenant_id = p_tenant_id
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

create or replace function public.list_global_stocks_cursor(
  p_tenant_id bigint,
  p_limit integer default 20,
  p_cursor_id bigint default null,
  p_search text default null,
  p_stock_type_id bigint default null,
  p_is_sellable boolean default null,
  p_shipment_status text default null,
  p_hide_zero_stock boolean default true,
  p_location_id bigint default null,
  p_availability public.stock_availability default null,
  p_shipment_id bigint default null,
  p_include_total boolean default false,
  p_grade_tag_id bigint default null,
  p_group_by text default null,
  p_group_key text default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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

create or replace function public.list_global_stocks_groups(
  p_tenant_id bigint,
  p_group_by text,
  p_limit integer default 50,
  p_offset integer default 0,
  p_search text default null,
  p_stock_type_id bigint default null,
  p_is_sellable boolean default null,
  p_shipment_status text default null,
  p_hide_zero_stock boolean default true,
  p_location_id bigint default null,
  p_availability public.stock_availability default null,
  p_shipment_id bigint default null,
  p_grade_tag_id bigint default null
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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

revoke all on function public.stock_location_matches_filter(bigint, bigint) from public;
grant execute on function public.stock_location_matches_filter(bigint, bigint) to authenticated;

revoke all on function public.list_global_stocks_groups(
  bigint, text, integer, integer, text, bigint, boolean, text, boolean, bigint,
  public.stock_availability, bigint, bigint
) from public;
grant execute on function public.list_global_stocks_groups(
  bigint, text, integer, integer, text, bigint, boolean, text, boolean, bigint,
  public.stock_availability, bigint, bigint
) to authenticated;
