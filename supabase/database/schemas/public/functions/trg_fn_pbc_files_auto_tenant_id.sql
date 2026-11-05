CREATE FUNCTION public.trg_fn_pbc_files_auto_tenant_id()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if new.tenant_id is not null then
    select coalesce(t.parent_id, t.id)
    into new.tenant_id
    from public.tenants t
    where t.id = new.tenant_id;
  elsif new.profile_id is not null then
    select coalesce(t.parent_id, t.id)
    into new.tenant_id
    from public.profiles pr
    inner join public.tenants t on t.id = pr.operating_tenant_id
    where pr.id = new.profile_id;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_auto_tenant_id() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_auto_tenant_id() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_pbc_files_auto_tenant_id() TO service_role;