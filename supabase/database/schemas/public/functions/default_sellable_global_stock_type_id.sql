CREATE FUNCTION public.default_sellable_global_stock_type_id (
  p_tenant_id bigint
)
  RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select gst.id
  from public.global_stock_types gst
  where (gst.parent_tenant_id is null or gst.parent_tenant_id = p_tenant_id)
    and gst.is_sellable = true
    and (
      lower(trim(gst.description)) = 'standard sellable'
      or gst.description ilike '%Standard%Sellable%'
      or gst.description ilike 'Standard%'
    )
  order by gst.parent_tenant_id nulls first, gst.sort_order, gst.id
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.default_sellable_global_stock_type_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.default_sellable_global_stock_type_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.default_sellable_global_stock_type_id(bigint) TO service_role;