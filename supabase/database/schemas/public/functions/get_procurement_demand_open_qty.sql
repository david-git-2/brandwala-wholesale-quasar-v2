CREATE FUNCTION public.get_procurement_demand_open_qty (
  p_source_type public.preorder_demand_source_type,
  p_source_id   bigint
)
  RETURNS TABLE (
    tenant_id       bigint,
    open_qty        integer,
    document_status text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if p_source_type = 'shop_order_item' then
    return query
    select
      o.tenant_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      public.normalize_shop_order_procurement_status(o.status)
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.shop_type_snapshot = 'vendor_catalog';
  elsif p_source_type = 'pbc_costing_item' then
    return query
    select
      f.tenant_id,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer,
      public.normalize_pbc_procurement_status(f.status)
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = p_source_id
      and f.profile_id is not null;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.get_procurement_demand_open_qty(public.preorder_demand_source_type, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_procurement_demand_open_qty(public.preorder_demand_source_type, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_procurement_demand_open_qty(public.preorder_demand_source_type, bigint) TO service_role;