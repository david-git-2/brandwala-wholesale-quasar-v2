CREATE FUNCTION public.trg_fn_bump_tenant_modules_version()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  else
    perform public.bump_tenant_permission_version(new.tenant_id);
    return new;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_bump_tenant_modules_version() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_bump_tenant_modules_version() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_bump_tenant_modules_version() TO service_role;