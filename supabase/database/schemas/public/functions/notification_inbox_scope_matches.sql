CREATE FUNCTION public.notification_inbox_scope_matches (
  p_tenant_id           bigint,
  p_parent_tenant_id    bigint,
  p_operating_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  SELECT
    p_parent_tenant_id = public.resolve_parent_tenant_id(p_tenant_id)
    AND (
      NOT EXISTS (
        SELECT 1
        FROM public.tenants t
        WHERE t.id = p_tenant_id
          AND t.parent_id IS NOT NULL
      )
      OR p_operating_tenant_id IS NULL
      OR p_operating_tenant_id = p_tenant_id
    );
$function$;

GRANT ALL ON FUNCTION public.notification_inbox_scope_matches(bigint, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.notification_inbox_scope_matches(bigint, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.notification_inbox_scope_matches(bigint, bigint, bigint) TO service_role;