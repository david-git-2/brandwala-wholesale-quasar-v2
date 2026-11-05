CREATE FUNCTION public._assert_parent_warehouse_tenant (
  p_parent_tenant_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
begin
  if p_parent_tenant_id is null then
    raise exception 'parent_tenant_id is required';
  end if;

  select parent_id into v_parent_id
  from public.tenants
  where id = p_parent_tenant_id;

  if not found then
    raise exception 'tenant not found';
  end if;

  if v_parent_id is not null then
    raise exception 'stock locations are only for parent warehouse tenants';
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public._assert_parent_warehouse_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public._assert_parent_warehouse_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public._assert_parent_warehouse_tenant(bigint) TO service_role;