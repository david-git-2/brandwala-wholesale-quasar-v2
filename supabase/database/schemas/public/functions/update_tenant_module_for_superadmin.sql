CREATE FUNCTION public.update_tenant_module_for_superadmin (
  p_id         bigint,
  p_tenant_id  bigint  DEFAULT NULL::bigint,
  p_module_key text    DEFAULT NULL::text,
  p_is_active  boolean DEFAULT NULL::boolean
)
  RETURNS TABLE (
    id         bigint,
    tenant_id  bigint,
    module_key text,
    is_active  boolean,
    created_at timestamp with time zone,
    updated_at timestamp with time zone
  )
  LANGUAGE sql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  with permission as (
    select public.is_superadmin() as allowed
  ),
  updated as (
    update public.tenant_modules tm
    set
      tenant_id = coalesce(p_tenant_id, tm.tenant_id),
      module_key = coalesce(lower(trim(p_module_key)), tm.module_key),
      is_active = coalesce(p_is_active, tm.is_active)
    from permission
    where allowed
      and tm.id = p_id
    returning
      tm.id,
      tm.tenant_id,
      tm.module_key,
      tm.is_active,
      tm.created_at,
      tm.updated_at
  )
  select
    id,
    tenant_id,
    module_key,
    is_active,
    created_at,
    updated_at
  from updated;
$function$;

GRANT ALL ON FUNCTION public.update_tenant_module_for_superadmin(bigint, bigint, text, boolean) TO anon;

GRANT ALL ON FUNCTION public.update_tenant_module_for_superadmin(bigint, bigint, text, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.update_tenant_module_for_superadmin(bigint, bigint, text, boolean) TO service_role;