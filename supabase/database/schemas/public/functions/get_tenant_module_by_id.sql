CREATE FUNCTION public.get_tenant_module_by_id (
  p_id bigint
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
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at
  from public.tenant_modules tm
  where tm.id = p_id
    and public.can_view_tenant_modules(tm.tenant_id)
  limit 1;
$function$;

GRANT ALL ON FUNCTION public.get_tenant_module_by_id(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_tenant_module_by_id(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_tenant_module_by_id(bigint) TO service_role;