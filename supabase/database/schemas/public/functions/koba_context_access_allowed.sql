CREATE FUNCTION public.koba_context_access_allowed (
  p_tenant_id         bigint,
  p_customer_group_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
    or (
      p_customer_group_id is not null
      and public.is_customer_group_member(p_customer_group_id)
    );
$function$;

GRANT ALL ON FUNCTION public.koba_context_access_allowed(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.koba_context_access_allowed(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.koba_context_access_allowed(bigint, bigint) TO service_role;