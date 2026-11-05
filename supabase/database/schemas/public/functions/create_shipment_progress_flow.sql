CREATE FUNCTION public.create_shipment_progress_flow (
  p_tenant_id bigint,
  p_name      text
)
  RETURNS public.shipment_progress_flows
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_slug text;
  v_result public.shipment_progress_flows;
  v_has_default boolean;
begin
  if not public.has_active_tenant_membership(p_tenant_id)
     and not public.is_superadmin() then
    raise exception 'not authorized';
  end if;

  if p_name is null or trim(p_name) = '' then
    raise exception 'name is required';
  end if;

  v_slug := lower(regexp_replace(trim(p_name), '[^a-z0-9]+', '-', 'gi'));

  select exists(
    select 1
    from public.shipment_progress_flows
    where tenant_id = p_tenant_id
      and is_default = true
  ) into v_has_default;

  insert into public.shipment_progress_flows (
    tenant_id, name, slug, is_active, is_default
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_slug,
    true,
    not v_has_default
  )
  returning * into v_result;

  return v_result;
end;
$function$;

GRANT ALL ON FUNCTION public.create_shipment_progress_flow(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.create_shipment_progress_flow(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.create_shipment_progress_flow(bigint, text) TO service_role;