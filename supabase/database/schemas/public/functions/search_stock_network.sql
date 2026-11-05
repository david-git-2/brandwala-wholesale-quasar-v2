CREATE FUNCTION public.search_stock_network (
  p_context_tenant_id bigint,
  p_mode              text    DEFAULT 'search'::text,
  p_search            text    DEFAULT NULL::text,
  p_search_field      text    DEFAULT NULL::text,
  p_product_id        bigint  DEFAULT NULL::bigint,
  p_status            text    DEFAULT 'excellent'::text,
  p_shipment_id       bigint  DEFAULT NULL::bigint,
  p_exclude_zero_qty  boolean DEFAULT true,
  p_limit             integer DEFAULT 50,
  p_offset            integer DEFAULT 0
)
  RETURNS TABLE (
    global_stock_id         bigint,
    product_id              bigint,
    name                    text,
    barcode                 text,
    product_code            text,
    image_url               text,
    shipment_item_id        bigint,
    ordered_quantity        integer,
    purchase_price          numeric,
    product_weight          numeric,
    package_weight          numeric,
    shipment_type           text,
    product_conversion_rate numeric,
    cargo_conversion_rate   numeric,
    cargo_rate              numeric,
    received_weight         numeric,
    transaction_rate        numeric,
    shipment_id             bigint,
    shipment_name           text,
    parent_tenant_id        bigint,
    holding_tenant_id       bigint,
    holding_tenant_name     text,
    allocated_qty           integer,
    global_qty              integer,
    excellent_qty           integer,
    box_less_qty            integer,
    box_damage_qty          integer,
    expired_qty             integer,
    stolen_qty              integer,
    reserved_qty            integer,
    total_qty               integer,
    is_own_tenant           boolean,
    is_pickable             boolean,
    sort_rank               integer,
    product_group_key       text,
    available_atp           numeric,
    location_id             bigint,
    location_name           text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
$function$;

GRANT ALL ON FUNCTION public.search_stock_network(bigint, text, text, text, bigint, text, bigint, boolean, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.search_stock_network(bigint, text, text, text, bigint, text, bigint, boolean, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.search_stock_network(bigint, text, text, text, bigint, text, bigint, boolean, integer, integer) TO service_role;