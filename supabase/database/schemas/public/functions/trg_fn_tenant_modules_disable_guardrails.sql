CREATE FUNCTION public.trg_fn_tenant_modules_disable_guardrails()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_has_grants boolean;
  v_has_overrides boolean;
begin
  if tg_op = 'UPDATE' and old.is_active = true and new.is_active = false then
    if coalesce(current_setting('request.force_module_disable', true), '') <> 'true' then
      select exists (
        select 1 from public.tenant_role_grants tg
        join public.tenant_roles tr on tr.id = tg.tenant_role_id
        where tr.tenant_id = old.tenant_id and tg.module_key = old.module_key
      ) into v_has_grants;

      if v_has_grants then
        raise exception 'Cannot disable module %: active role grants depend on it. Use force to override.', old.module_key;
      end if;

      select exists (
        select 1 from public.membership_grants mg
        join public.memberships m on m.id = mg.membership_id
        where m.tenant_id = old.tenant_id and mg.module_key = old.module_key
      ) into v_has_overrides;

      if v_has_overrides then
        raise exception 'Cannot disable module %: active member overrides depend on it. Use force to override.', old.module_key;
      end if;
    end if;
  end if;
  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_tenant_modules_disable_guardrails() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_tenant_modules_disable_guardrails() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_tenant_modules_disable_guardrails() TO service_role;