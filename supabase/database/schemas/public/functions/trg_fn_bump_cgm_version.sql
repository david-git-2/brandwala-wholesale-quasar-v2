CREATE FUNCTION public.trg_fn_bump_cgm_version()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'DELETE' then
    select tenant_id into v_tenant_id from public.customer_groups where id = old.customer_group_id;
  else
    select tenant_id into v_tenant_id from public.customer_groups where id = new.customer_group_id;
  end if;
  if v_tenant_id is not null then
    if tg_op = 'DELETE' or tg_op = 'INSERT' or coalesce(old.tenant_role_id, 0) <> coalesce(new.tenant_role_id, 0) or old.is_active <> new.is_active or old.role <> new.role then
      perform public.bump_tenant_permission_version(v_tenant_id);
    end if;
  end if;
  if tg_op = 'DELETE' then
    return old;
  else
    return new;
  end if;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_bump_cgm_version() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_bump_cgm_version() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_bump_cgm_version() TO service_role;