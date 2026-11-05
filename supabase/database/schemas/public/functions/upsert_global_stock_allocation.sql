CREATE FUNCTION public.upsert_global_stock_allocation (
  p_parent_tenant_id bigint,
  p_child_tenant_id  bigint,
  p_stock_id         bigint,
  p_quantity         integer
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return jsonb_build_object('status', 'retired');
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_global_stock_allocation(bigint, bigint, bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.upsert_global_stock_allocation(bigint, bigint, bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_global_stock_allocation(bigint, bigint, bigint, integer) TO service_role;