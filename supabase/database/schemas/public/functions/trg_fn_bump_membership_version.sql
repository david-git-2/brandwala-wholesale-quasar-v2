CREATE FUNCTION public.trg_fn_bump_membership_version()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
begin
  if tg_op = 'DELETE' then
    perform public.bump_tenant_permission_version(old.tenant_id);
    return old;
  elsif tg_op = 'INSERT' then
    perform public.bump_tenant_permission_version(new.tenant_id);
    return new;
  elsif coalesce(old.tenant_role_id, 0) <> coalesce(new.tenant_role_id, 0) or old.is_active <> new.is_active or old.role <> new.role then
    perform public.bump_tenant_permission_version(new.tenant_id);
    return new;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_bump_membership_version() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_bump_membership_version() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_bump_membership_version() TO service_role;