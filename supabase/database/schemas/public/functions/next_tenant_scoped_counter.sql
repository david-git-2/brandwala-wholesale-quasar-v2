CREATE FUNCTION public.next_tenant_scoped_counter (
  p_tenant_id bigint,
  p_scope     text
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_next bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  if p_scope not in ('shipment', 'order') then
    raise exception 'invalid scope: %', p_scope;
  end if;

  insert into public.tenant_scoped_counters (tenant_id, scope, last_value)
  values (p_tenant_id, p_scope, 1)
  on conflict (tenant_id, scope)
  do update
    set last_value = public.tenant_scoped_counters.last_value + 1
  returning last_value into v_next;

  return v_next;
end;
$function$;

GRANT ALL ON FUNCTION public.next_tenant_scoped_counter(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.next_tenant_scoped_counter(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.next_tenant_scoped_counter(bigint, text) TO service_role;