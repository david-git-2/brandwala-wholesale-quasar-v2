CREATE FUNCTION public.trg_fn_cgm_permission_guardrails()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_role_scope text;
  v_role_books bigint;
  v_cg_books bigint;
begin
  if new.tenant_role_id is not null then
    select tr.scope, public.resolve_parent_tenant_id(tr.tenant_id)
    into v_role_scope, v_role_books
    from public.tenant_roles tr
    where tr.id = new.tenant_role_id;

    select coalesce(cg.parent_tenant_id, public.resolve_parent_tenant_id(cg.tenant_id))
    into v_cg_books
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_role_books is distinct from v_cg_books then
      raise exception 'Cross-tenant role assignment is not allowed';
    end if;

    if v_role_scope is distinct from 'shop' then
      raise exception 'Scope mismatch: customer group member cannot be assigned a % scoped role', v_role_scope;
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_cgm_permission_guardrails() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_cgm_permission_guardrails() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_cgm_permission_guardrails() TO service_role;