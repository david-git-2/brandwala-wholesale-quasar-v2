CREATE FUNCTION public.list_tenant_modules_by_tenant (
  p_tenant_id bigint DEFAULT NULL::bigint
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
  where p_tenant_id is not null
    and tm.tenant_id = p_tenant_id
    and public.can_view_tenant_modules(tm.tenant_id)
  order by tm.id asc;
$function$;

GRANT ALL ON FUNCTION public.list_tenant_modules_by_tenant(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_tenant_modules_by_tenant(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_tenant_modules_by_tenant(bigint) TO service_role;