CREATE FUNCTION public.handle_new_tenant_retail_settings()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
begin
  insert into public.koba_retail_settings (tenant_id)
  values (new.id)
  on conflict (tenant_id) do nothing;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.handle_new_tenant_retail_settings() TO anon;

GRANT ALL ON FUNCTION public.handle_new_tenant_retail_settings() TO authenticated;

GRANT ALL ON FUNCTION public.handle_new_tenant_retail_settings() TO service_role;