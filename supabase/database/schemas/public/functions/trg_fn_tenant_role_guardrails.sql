CREATE FUNCTION public.trg_fn_tenant_role_guardrails()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_count int;
begin
  if tg_op = 'DELETE' then
    if old.is_admin = true and old.is_active = true then
      raise exception 'Cannot delete the final active admin role for this scope';
    end if;
    return old;
  elsif tg_op = 'UPDATE' then
    if old.is_admin = true and old.is_active = true and (new.is_admin = false or new.is_active = false) then
      select count(*) into v_count
      from public.tenant_roles
      where tenant_id = old.tenant_id
        and scope = old.scope
        and is_admin = true
        and is_active = true
        and id <> old.id;
      if v_count = 0 then
        raise exception 'Cannot deactivate or downgrade the final active admin role for this scope';
      end if;
    end if;
    return new;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_tenant_role_guardrails() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_tenant_role_guardrails() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_tenant_role_guardrails() TO service_role;