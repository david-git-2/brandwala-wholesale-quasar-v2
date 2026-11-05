CREATE FUNCTION public.purge_popped_demand_bucket_items (
  p_tenant_id      bigint,
  p_retention_days integer DEFAULT 90
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_cutoff timestamptz;
  v_deleted integer;
  v_is_parent boolean;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent
  from public.tenants t
  where t.id = p_tenant_id;

  if coalesce(v_is_parent, false) then
    if not public.user_can_manage_parent_tenant(p_tenant_id) then
      raise exception 'access denied';
    end if;
  elsif not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_cutoff := now() - make_interval(days => greatest(coalesce(p_retention_days, 90), 1));

  delete from public.customer_demand_bucket_items b
  where b.status = 'popped'
    and b.popped_at is not null
    and b.popped_at < v_cutoff
    and (
      b.tenant_id = p_tenant_id
      or exists (
        select 1
        from public.tenants t
        where t.id = b.tenant_id
          and t.parent_id = p_tenant_id
      )
    );

  get diagnostics v_deleted = row_count;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'retention_days', greatest(coalesce(p_retention_days, 90), 1),
    'deleted_count', v_deleted
  );
end;
$function$;

GRANT ALL ON FUNCTION public.purge_popped_demand_bucket_items(bigint, integer) TO anon;

GRANT ALL ON FUNCTION public.purge_popped_demand_bucket_items(bigint, integer) TO authenticated;

GRANT ALL ON FUNCTION public.purge_popped_demand_bucket_items(bigint, integer) TO service_role;