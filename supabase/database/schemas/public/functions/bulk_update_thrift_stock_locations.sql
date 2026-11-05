CREATE FUNCTION public.bulk_update_thrift_stock_locations (
  p_tenant_id bigint,
  p_stock_ids bigint[],
  p_shelf_id  bigint   DEFAULT NULL::bigint,
  p_box_id    bigint   DEFAULT NULL::bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
BEGIN
  UPDATE thrift_stocks
  SET shelf_id = p_shelf_id, box_id = p_box_id, updated_at = now()
  WHERE tenant_id = p_tenant_id AND id = ANY(p_stock_ids);
END; $function$;

GRANT ALL ON FUNCTION public.bulk_update_thrift_stock_locations(bigint, bigint[], bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.bulk_update_thrift_stock_locations(bigint, bigint[], bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_update_thrift_stock_locations(bigint, bigint[], bigint, bigint) TO service_role;