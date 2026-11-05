CREATE FUNCTION public.sync_product_tenant_from_vendor()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
declare
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.parent_tenant_id
    into v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.sync_product_tenant_from_vendor() TO anon;

GRANT ALL ON FUNCTION public.sync_product_tenant_from_vendor() TO authenticated;

GRANT ALL ON FUNCTION public.sync_product_tenant_from_vendor() TO service_role;