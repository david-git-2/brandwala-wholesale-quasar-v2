CREATE FUNCTION public.trg_fn_bump_grant_tenant_version()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.tenant_roles where id = old.tenant_role_id;
  else
    select tenant_id into v_tenant_id from public.tenant_roles where id = new.tenant_role_id;
  end if;
  if v_tenant_id is not null then
    perform public.bump_tenant_permission_version(v_tenant_id);
  end if;
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_bump_grant_tenant_version() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_bump_grant_tenant_version() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_bump_grant_tenant_version() TO service_role;