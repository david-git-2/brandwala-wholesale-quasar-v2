CREATE FUNCTION public.global_invoices_default_issued_by_tenant_id()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if new.issued_by_tenant_id is null then
    new.issued_by_tenant_id := new.tenant_id;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.global_invoices_default_issued_by_tenant_id() TO anon;

GRANT ALL ON FUNCTION public.global_invoices_default_issued_by_tenant_id() TO authenticated;

GRANT ALL ON FUNCTION public.global_invoices_default_issued_by_tenant_id() TO service_role;