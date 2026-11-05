CREATE FUNCTION public.parent_tenant_has_module_action (
  p_parent_tenant_id bigint,
  p_module_key       text,
  p_action           text
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.membership_has_module_action(p_parent_tenant_id, p_module_key, p_action);
$function$;

GRANT ALL ON FUNCTION public.parent_tenant_has_module_action(bigint, text, text) TO anon;

GRANT ALL ON FUNCTION public.parent_tenant_has_module_action(bigint, text, text) TO authenticated;

GRANT ALL ON FUNCTION public.parent_tenant_has_module_action(bigint, text, text) TO service_role;