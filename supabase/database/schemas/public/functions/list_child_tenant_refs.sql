CREATE FUNCTION public.list_child_tenant_refs (
  p_parent_tenant_ids bigint[]
)
  RETURNS TABLE (
    id        bigint,
    parent_id bigint,
    name      text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select t.id, t.parent_id, t.name
  from public.tenants t
  where t.parent_id = any (coalesce(p_parent_tenant_ids, array[]::bigint[]))
    and (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(t.parent_id)
    )
  order by t.parent_id, t.id;
$function$;

GRANT ALL ON FUNCTION public.list_child_tenant_refs(bigint[]) TO anon;

GRANT ALL ON FUNCTION public.list_child_tenant_refs(bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.list_child_tenant_refs(bigint[]) TO service_role;