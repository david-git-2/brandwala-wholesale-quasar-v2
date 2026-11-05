CREATE FUNCTION public.get_available_stock (
  p_stock_id  bigint,
  p_tenant_id bigint
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_tenant_id bigint;
  v_global_qty integer;
  v_other_allocated integer;
begin
  select parent_tenant_id, quantity
  into v_parent_tenant_id, v_global_qty
  from public.global_stocks
  where id = p_stock_id;

  if v_parent_tenant_id is null then
    return 0;
  end if;

  -- Parent tenant can sell up to the entire global quantity
  if p_tenant_id = v_parent_tenant_id then
    return v_global_qty;
  end if;

  -- Child tenant can sell: global quantity - sum of allocations to OTHER child tenants
  select coalesce(sum(quantity), 0)
  into v_other_allocated
  from public.global_stock_allocations
  where stock_id = p_stock_id
    and child_tenant_id <> p_tenant_id;

  return greatest(v_global_qty - v_other_allocated, 0);
end;
$function$;

GRANT ALL ON FUNCTION public.get_available_stock(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_available_stock(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_available_stock(bigint, bigint) TO service_role;