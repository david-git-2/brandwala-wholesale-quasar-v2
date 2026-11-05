CREATE FUNCTION public.set_shop_parent_tenant_id()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
begin
  if new.tenant_id is not null then
    select parent_id into v_parent_id
    from public.tenants
    where id = new.tenant_id;

    new.parent_tenant_id := v_parent_id;
  else
    new.parent_tenant_id := null;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.set_shop_parent_tenant_id() TO anon;

GRANT ALL ON FUNCTION public.set_shop_parent_tenant_id() TO authenticated;

GRANT ALL ON FUNCTION public.set_shop_parent_tenant_id() TO service_role;