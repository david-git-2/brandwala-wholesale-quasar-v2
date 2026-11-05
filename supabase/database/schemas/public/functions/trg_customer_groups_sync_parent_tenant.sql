CREATE FUNCTION public.trg_customer_groups_sync_parent_tenant()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SET search_path TO 'public'
  AS $function$
begin
  new.parent_tenant_id := coalesce(
    new.parent_tenant_id,
    public.resolve_parent_tenant_id(new.tenant_id)
  );
  new.tenant_id := new.parent_tenant_id;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_customer_groups_sync_parent_tenant() TO anon;

GRANT ALL ON FUNCTION public.trg_customer_groups_sync_parent_tenant() TO authenticated;

GRANT ALL ON FUNCTION public.trg_customer_groups_sync_parent_tenant() TO service_role;