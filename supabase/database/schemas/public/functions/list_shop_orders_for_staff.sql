CREATE FUNCTION public.list_shop_orders_for_staff (
  p_tenant_id        bigint,
  p_parent_tenant_id bigint  DEFAULT NULL::bigint,
  p_limit            integer DEFAULT 50,
  p_offset           integer DEFAULT 0,
  p_search           text    DEFAULT NULL::text,
  p_status           text    DEFAULT NULL::text,
  p_shop_id          bigint  DEFAULT NULL::bigint
)
  RETURNS TABLE (
    id                     bigint,
    tenant_id              bigint,
    shop_id                bigint,
    shop_name              text,
    customer_group_id      bigint,
    customer_group_name    text,
    order_no               text,
    name                   text,
    shop_type_snapshot     public.shop_type_enum,
    is_negotiable_snapshot boolean,
    status                 public.shop_order_status,
    created_at             timestamp with time zone,
    updated_at             timestamp with time zone,
    item_count             bigint,
    tenant_name            text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_is_parent_query boolean;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_is_parent_query := (p_parent_tenant_id is not null and p_parent_tenant_id = p_tenant_id);

  return query
  select
    o.id,
    o.tenant_id,
    o.shop_id,
    s.name as shop_name,
    o.customer_group_id,
    cg.name as customer_group_name,
    o.order_no,
    o.name,
    o.shop_type_snapshot,
    o.is_negotiable_snapshot,
    o.status,
    o.created_at,
    o.updated_at,
    (select count(*)::bigint from public.shop_order_items where order_id = o.id) as item_count,
    coalesce(t.name, '')::text as tenant_name
  from public.shop_orders o
  join public.shops s on s.id = o.shop_id
  join public.customer_groups cg on cg.id = o.customer_group_id
  left join public.tenants t on t.id = o.tenant_id
  where (
    (v_is_parent_query and (o.parent_tenant_id = p_parent_tenant_id or o.tenant_id = p_parent_tenant_id))
    or (not v_is_parent_query and o.tenant_id = p_tenant_id)
  )
    and (p_status is null or o.status::text = p_status)
    and (p_shop_id is null or o.shop_id = p_shop_id)
    and (
      p_search is null
      or o.order_no ilike ('%' || p_search || '%')
      or o.name ilike ('%' || p_search || '%')
      or s.name ilike ('%' || p_search || '%')
      or cg.name ilike ('%' || p_search || '%')
      or t.name ilike ('%' || p_search || '%')
    )
  order by o.created_at desc
  limit p_limit
  offset p_offset;
end;
$function$;

GRANT ALL ON FUNCTION public.list_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_shop_orders_for_staff(bigint, bigint, integer, integer, text, text, bigint) TO service_role;