CREATE FUNCTION public.set_products_catalog_parent_tenant_id()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if new.parent_tenant_id is not null then
    new.parent_tenant_id := public.resolve_parent_tenant_id(new.parent_tenant_id);
  elsif new.inserted_by_tenant_id is not null then
    new.parent_tenant_id := public.resolve_parent_tenant_id(new.inserted_by_tenant_id);
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.set_products_catalog_parent_tenant_id() TO anon;

GRANT ALL ON FUNCTION public.set_products_catalog_parent_tenant_id() TO authenticated;

GRANT ALL ON FUNCTION public.set_products_catalog_parent_tenant_id() TO service_role;