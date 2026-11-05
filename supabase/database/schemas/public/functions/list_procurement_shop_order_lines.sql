CREATE FUNCTION public.list_procurement_shop_order_lines (
  p_parent_tenant_id bigint,
  p_child_tenant_id  bigint  DEFAULT NULL::bigint,
  p_search           text    DEFAULT NULL::text,
  p_limit            integer DEFAULT 100,
  p_offset           integer DEFAULT 0
)
  RETURNS TABLE (
    source_type       text,
    source_id         bigint,
    child_tenant_id   bigint,
    child_tenant_name text,
    name              text,
    product_id        bigint,
    quantity          integer,
    cost_bdt          numeric,
    price_gbp         numeric,
    image_url         text,
    barcode           text,
    product_code      text,
    reference_label   text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select
    'shop_order_item'::text as source_type,
    oi.id as source_id,
    o.tenant_id as child_tenant_id,
    t.name as child_tenant_name,
    oi.name,
    oi.product_id,
    greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
    case when gc.code = 'BDT' then oi.final_price_amount else null::numeric end as cost_bdt,
    case when gc.code = 'GBP' then oi.final_price_amount else null::numeric end as price_gbp,
    oi.image_url,
    p.barcode,
    p.product_code,
    ('Shop Order #' || o.order_no || ' — ' || o.name) as reference_label
  from public.shop_order_items oi
  inner join public.shop_orders o on o.id = oi.order_id
  inner join public.tenants t on t.id = o.tenant_id
  left join public.products p on p.id = oi.product_id
  left join public.global_currencies gc on gc.id = oi.final_price_currency_id
  where o.status = 'placed'
    and oi.procurement_pulled = false
    and o.shop_type_snapshot = 'vendor_catalog'
    and t.parent_id = p_parent_tenant_id
    and (p_child_tenant_id is null or o.tenant_id = p_child_tenant_id)
    and (
      p_search is null or trim(p_search) = ''
      or oi.name ilike '%' || trim(p_search) || '%'
      or o.name ilike '%' || trim(p_search) || '%'
    )
  order by t.name, oi.id
  limit greatest(coalesce(p_limit, 100), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

GRANT ALL ON FUNCTION public.list_procurement_shop_order_lines(bigint, bigint, text, integer, integer) TO anon;

GRANT ALL ON FUNCTION public.list_procurement_shop_order_lines(bigint, bigint, text, integer, integer) TO authenticated;

GRANT ALL ON FUNCTION public.list_procurement_shop_order_lines(bigint, bigint, text, integer, integer) TO service_role;