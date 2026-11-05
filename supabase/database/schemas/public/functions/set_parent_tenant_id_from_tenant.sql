CREATE FUNCTION public.set_parent_tenant_id_from_tenant()
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

    new.parent_tenant_id := coalesce(v_parent_id, new.tenant_id);
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.set_parent_tenant_id_from_tenant() TO anon;

GRANT ALL ON FUNCTION public.set_parent_tenant_id_from_tenant() TO authenticated;

GRANT ALL ON FUNCTION public.set_parent_tenant_id_from_tenant() TO service_role;