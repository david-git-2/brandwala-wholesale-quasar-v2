CREATE FUNCTION public.auto_enable_investor_capital_for_root_tenant()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if NEW.parent_id is null then
    insert into public.tenant_modules (tenant_id, module_key, is_active)
    values (NEW.id, 'investor_capital', true)
    on conflict (tenant_id, module_key) do update set is_active = true;

    perform public.seed_tenant_roles_and_grants(NEW.id);
  end if;

  return NEW;
end;
$function$;

GRANT ALL ON FUNCTION public.auto_enable_investor_capital_for_root_tenant() TO anon;

GRANT ALL ON FUNCTION public.auto_enable_investor_capital_for_root_tenant() TO authenticated;

GRANT ALL ON FUNCTION public.auto_enable_investor_capital_for_root_tenant() TO service_role;