CREATE FUNCTION public.set_tenant_id_on_insert()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if new.tenant_id is null then
    new.tenant_id := public.current_tenant_id();
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.set_tenant_id_on_insert() TO anon;

GRANT ALL ON FUNCTION public.set_tenant_id_on_insert() TO authenticated;

GRANT ALL ON FUNCTION public.set_tenant_id_on_insert() TO service_role;