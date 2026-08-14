-- Phase 9A + 10A: Shared ATP with holds; pickable sellable filter

begin;

create or replace function public.global_stock_hold_qty(p_global_stock_id bigint)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce((
      select sum(gii.quantity - coalesce(gii.return_quantity, 0))
      from public.global_invoice_items gii
      join public.global_invoices gi on gi.id = gii.invoice_id
      where gii.global_stock_id = p_global_stock_id
        and gi.invoice_status = 'draft'::public.global_invoice_status
    ), 0)
    + coalesce((
      select sum(sci.quantity)
      from public.shop_cart_items sci
      where sci.global_stock_id = p_global_stock_id
    ), 0);
$$;

grant execute on function public.global_stock_hold_qty(bigint) to authenticated;

create or replace function public.global_stock_atp_qty(p_global_stock_id bigint)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select greatest(
    coalesce((
      select sum(gs.quantity)
      from public.global_stocks gs
      join public.global_stock_types gst on gst.id = gs.stock_type_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.id = p_global_stock_id
        and gst.is_sellable = true
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
    ), 0) - public.global_stock_hold_qty(p_global_stock_id),
    0
  );
$$;

grant execute on function public.global_stock_atp_qty(bigint) to authenticated;

create or replace function public.list_child_stock_atp(
  p_child_tenant_id bigint,
  p_search text default null,
  p_limit integer default 50,
  p_offset integer default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
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
          where gst.is_sellable = true
            and gs.availability = 'sellable'::public.stock_availability
            and (gs.location_id is null or sl.is_pickable = true)
        ), 0),
        'atp_qty', coalesce(sum(public.global_stock_atp_qty(gs.id)), 0)
      ) as row_json
    from public.global_shipments s
    left join public.global_shipment_items gsi on gsi.shipment_id = s.id
    left join public.global_stocks gs on gs.shipment_item_id = gsi.id
    left join public.global_stock_types gst on gst.id = gs.stock_type_id
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
$$;

grant execute on function public.list_child_stock_atp(bigint, text, integer, integer) to authenticated;

commit;
