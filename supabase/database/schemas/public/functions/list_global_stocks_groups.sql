CREATE FUNCTION public.list_global_stocks_groups (
  p_tenant_id       bigint,
  p_group_by        text,
  p_limit           integer                   DEFAULT 50,
  p_offset          integer                   DEFAULT 0,
  p_search          text                      DEFAULT NULL::text,
  p_stock_type_id   bigint                    DEFAULT NULL::bigint,
  p_is_sellable     boolean                   DEFAULT NULL::boolean,
  p_shipment_status text                      DEFAULT NULL::text,
  p_hide_zero_stock boolean                   DEFAULT true,
  p_location_id     bigint                    DEFAULT NULL::bigint,
  p_availability    public.stock_availability DEFAULT NULL::public.stock_availability,
  p_shipment_id     bigint                    DEFAULT NULL::bigint,
  p_grade_tag_id    bigint                    DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.list_global_stocks_groups(bigint, text, integer, integer, text, bigint, boolean, text, boolean, bigint, public.stock_availability, bigint, bigint) TO
  anon;

GRANT ALL ON FUNCTION public.list_global_stocks_groups(bigint, text, integer, integer, text, bigint, boolean, text, boolean, bigint, public.stock_availability, bigint, bigint) TO
  authenticated;

GRANT ALL ON FUNCTION public.list_global_stocks_groups(bigint, text, integer, integer, text, bigint, boolean, text, boolean, bigint, public.stock_availability, bigint, bigint) TO
  service_role;