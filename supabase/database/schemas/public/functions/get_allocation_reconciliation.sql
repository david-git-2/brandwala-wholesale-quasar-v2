CREATE FUNCTION public.get_allocation_reconciliation (
  p_stock_id bigint
)
  RETURNS TABLE (
    stock_id        bigint,
    global_qty      integer,
    allocated_qty   integer,
    unallocated_qty integer,
    is_reconciled   boolean
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_global_qty integer;
  v_allocated_qty integer;
begin
  select quantity into v_global_qty
  from public.global_stocks
  where id = p_stock_id;

  select coalesce(sum(quantity), 0)::integer into v_allocated_qty
  from public.global_stock_allocations
  where stock_id = p_stock_id;

  return query
  select
    p_stock_id,
    coalesce(v_global_qty, 0),
    coalesce(v_allocated_qty, 0),
    greatest(coalesce(v_global_qty, 0) - coalesce(v_allocated_qty, 0), 0),
    coalesce(v_allocated_qty, 0) <= coalesce(v_global_qty, 0);
end;
$function$;

GRANT ALL ON FUNCTION public.get_allocation_reconciliation(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_allocation_reconciliation(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_allocation_reconciliation(bigint) TO service_role;