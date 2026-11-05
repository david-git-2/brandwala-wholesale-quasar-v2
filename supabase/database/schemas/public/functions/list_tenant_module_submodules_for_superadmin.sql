CREATE FUNCTION public.list_tenant_module_submodules_for_superadmin (
  p_tenant_id         bigint,
  p_parent_module_key text
)
  RETURNS TABLE (
    id                bigint,
    tenant_id         bigint,
    parent_module_key text,
    submodule_key     text,
    is_enabled        boolean,
    created_at        timestamp with time zone,
    updated_at        timestamp with time zone
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    tms.id,
    tms.tenant_id,
    tms.parent_module_key,
    tms.submodule_key,
    tms.is_enabled,
    tms.created_at,
    tms.updated_at
  from public.tenant_module_submodules tms
  where public.is_superadmin()
    and p_tenant_id is not null
    and tms.tenant_id = p_tenant_id
    and tms.parent_module_key = lower(trim(p_parent_module_key))
  order by tms.submodule_key asc;
$function$;

GRANT ALL ON FUNCTION public.list_tenant_module_submodules_for_superadmin(bigint, text) TO anon;

GRANT ALL ON FUNCTION public.list_tenant_module_submodules_for_superadmin(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.list_tenant_module_submodules_for_superadmin(bigint, text) TO service_role;