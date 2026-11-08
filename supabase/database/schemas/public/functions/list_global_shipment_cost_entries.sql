CREATE FUNCTION public.list_global_shipment_cost_entries (
  p_shipment_id bigint
)
  RETURNS SETOF public.global_shipment_cost_entries
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent bigint;
begin
  select tenant_id into v_parent
  from public.global_shipments
  where id = p_shipment_id;

  if v_parent is null then
    raise exception 'shipment not found';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_parent
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  return query
  select e.*
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
  order by e.cost_bucket, e.cost_component, e.id;
end;
$function$;

GRANT ALL ON FUNCTION public.list_global_shipment_cost_entries(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_global_shipment_cost_entries(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_global_shipment_cost_entries(bigint) TO service_role;