CREATE FUNCTION public.trg_fn_memberships_permission_guardrails()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  AS $function$
declare
  v_role_scope text;
  v_role_tenant bigint;
begin
  if new.tenant_role_id is not null then
    select scope, tenant_id into v_role_scope, v_role_tenant
    from public.tenant_roles
    where id = new.tenant_role_id;

    if v_role_tenant <> new.tenant_id then
      raise exception 'Cross-tenant role assignment is not allowed';
    end if;

    if v_role_scope <> 'app' then
      raise exception 'Scope mismatch: app membership cannot be assigned a % scoped role', v_role_scope;
    end if;
  end if;

  if tg_op = 'UPDATE' and old.is_active = true then
    declare
      v_was_owner boolean;
      v_is_owner boolean;
      v_active_owners int;
    begin
      v_was_owner := old.role = 'owner'::public.app_role;
      v_is_owner := new.is_active = true and new.role = 'owner'::public.app_role;

      if v_was_owner and not v_is_owner then
        select count(*) into v_active_owners
        from public.memberships m
        where m.tenant_id = old.tenant_id
          and m.is_active = true
          and m.id <> old.id
          and m.role = 'owner'::public.app_role;

        if v_active_owners = 0 then
          raise exception 'Cannot downgrade or deactivate the last active owner for this tenant';
        end if;
      end if;
    end;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_memberships_permission_guardrails() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_memberships_permission_guardrails() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_memberships_permission_guardrails() TO service_role;