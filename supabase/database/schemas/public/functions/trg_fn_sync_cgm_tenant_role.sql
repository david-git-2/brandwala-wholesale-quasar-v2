CREATE FUNCTION public.trg_fn_sync_cgm_tenant_role()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_target_slug text;
  v_role_id bigint;
  v_role_books bigint;
  v_cg_books bigint;
begin
  if new.tenant_role_id is not null then
    select public.resolve_parent_tenant_id(tr.tenant_id)
    into v_role_books
    from public.tenant_roles tr
    where tr.id = new.tenant_role_id;

    select coalesce(cg.parent_tenant_id, public.resolve_parent_tenant_id(cg.tenant_id))
    into v_cg_books
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_role_books is not distinct from v_cg_books
       and not (tg_op = 'UPDATE' and old.role is distinct from new.role) then
      return new;
    end if;
  end if;

  if new.tenant_role_id is null or (tg_op = 'UPDATE' and old.role is distinct from new.role) then
    select coalesce(cg.parent_tenant_id, cg.tenant_id)
    into v_tenant_id
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_tenant_id is not null then
      v_target_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'manager' then 'manager'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select tr.id into v_role_id
      from public.tenant_roles tr
      where tr.tenant_id = v_tenant_id
        and tr.scope = 'shop'
        and (tr.slug = v_target_slug or (new.role = 'admin' and tr.is_admin = true))
      order by tr.is_admin desc, tr.id asc
      limit 1;

      if v_role_id is not null then
        new.tenant_role_id := v_role_id;
      end if;
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_sync_cgm_tenant_role() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_sync_cgm_tenant_role() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_sync_cgm_tenant_role() TO service_role;