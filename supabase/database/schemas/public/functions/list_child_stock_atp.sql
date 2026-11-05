CREATE FUNCTION public.list_child_stock_atp (
  p_child_tenant_id bigint,
  p_search          text    DEFAULT NULL::text,
  p_limit           integer DEFAULT 50,
  p_offset          integer DEFAULT 0
)
  RETURNS jsonb
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
        'parent_tenant_id', s.parent_tenant_id,
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
    group by s.id, s.name, s.tenant_shipment_id, s.parent_tenant_id, s.status, s.received_date
    order by s.id desc
    limit p_limit
    offset p_offset
  ) q;

  return jsonb_build_object(
    'data', v_data,
    'total', v_total_count
  );
end;
$function$;

GRANT ALL ON FUNCTION public.list_child_stock_atp(bigint, text, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_child_stock_atp(bigint, text, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_child_stock_atp(bigint, text, integer, integer) TO service_role;