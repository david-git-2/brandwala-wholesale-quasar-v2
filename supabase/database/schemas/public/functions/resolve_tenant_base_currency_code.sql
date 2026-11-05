CREATE FUNCTION public.resolve_tenant_base_currency_code (
  p_tenant_id bigint
)
  RETURNS text
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select upper(trim(coalesce(t.base_currency_code, 'BDT')))
  from public.tenants t
  where t.id = public.resolve_parent_tenant_id(p_tenant_id);
$function$;

GRANT ALL ON FUNCTION public.resolve_tenant_base_currency_code(bigint) TO anon;

GRANT ALL ON FUNCTION public.resolve_tenant_base_currency_code(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.resolve_tenant_base_currency_code(bigint) TO service_role;