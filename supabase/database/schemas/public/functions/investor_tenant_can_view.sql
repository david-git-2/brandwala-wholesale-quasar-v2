CREATE FUNCTION public.investor_tenant_can_view (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    public.membership_has_module_action(p_tenant_id, 'investor_profiles', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_capital_ledger', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_shipment_share', 'view')
    or public.membership_has_module_action(p_tenant_id, 'investor_reports', 'view');
$function$;

GRANT ALL ON FUNCTION public.investor_tenant_can_view(bigint) TO anon;

GRANT ALL ON FUNCTION public.investor_tenant_can_view(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.investor_tenant_can_view(bigint) TO service_role;