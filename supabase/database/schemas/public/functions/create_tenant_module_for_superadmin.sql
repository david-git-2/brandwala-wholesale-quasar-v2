CREATE FUNCTION public.create_tenant_module_for_superadmin (
  p_tenant_id  bigint,
  p_module_key text,
  p_is_active  boolean DEFAULT true
)
  RETURNS TABLE (
    id         bigint,
    tenant_id  bigint,
    module_key text,
    is_active  boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
  )
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_key text := lower(trim(p_module_key));
  v_parent text;
begin
  if not public.is_superadmin() then
    return;
  end if;

  select mo.parent_module_key into v_parent
  from public.modules mo
  where mo.key = v_key;

  if v_parent is not null then
    raise exception 'Child submodules cannot be enabled independently. Please assign the main parent feature "%" instead.', v_parent;
  end if;

  if v_key = 'shop_order' and exists (
    select 1 from public.tenants child where child.parent_id = p_tenant_id
  ) then
    raise exception 'Shop & Order cannot be assigned to a parent company. Assign it on a sister concern or a standalone tenant.';
  end if;

  return query
  insert into public.tenant_modules as tm (tenant_id, module_key, is_active)
  values (p_tenant_id, v_key, coalesce(p_is_active, true))
  returning
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at;
end;
$function$;

GRANT ALL ON FUNCTION public.create_tenant_module_for_superadmin(bigint, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.create_tenant_module_for_superadmin(bigint, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.create_tenant_module_for_superadmin(bigint, text, boolean) TO service_role;