CREATE FUNCTION public.auto_enable_customer_module_for_new_tenant()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  insert into public.tenant_modules (tenant_id, module_key, is_active)
  values (NEW.id, 'customer', true)
  on conflict (tenant_id, module_key) do update set is_active = true;
  return NEW;
end;
$function$;

GRANT ALL ON FUNCTION public.auto_enable_customer_module_for_new_tenant() TO anon;

GRANT ALL ON FUNCTION public.auto_enable_customer_module_for_new_tenant() TO authenticated;

GRANT ALL ON FUNCTION public.auto_enable_customer_module_for_new_tenant() TO service_role;