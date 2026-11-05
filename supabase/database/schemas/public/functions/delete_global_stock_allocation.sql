CREATE FUNCTION public.delete_global_stock_allocation (
  p_allocation_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  delete from public.global_stock_allocations where id = p_allocation_id;
end;
$function$;

GRANT ALL ON FUNCTION public.delete_global_stock_allocation(bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_global_stock_allocation(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_global_stock_allocation(bigint) TO service_role;