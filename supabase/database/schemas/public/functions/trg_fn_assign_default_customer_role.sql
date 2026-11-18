CREATE FUNCTION public.trg_fn_assign_default_customer_role()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_role_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null and new.customer_group_id is not null and new.role is not null then
    select cg.tenant_id
    into v_tenant_id
    from public.customer_groups cg
    where cg.id = new.customer_group_id;

    if v_tenant_id is not null then
      v_role_slug := case new.role
        when 'admin' then 'customer-admin'
        when 'manager' then 'manager'
        when 'staff' then 'customer-staff'
        else 'customer-staff'
      end;

      select tr.id into v_role_id
      from public.tenant_roles tr
      where tr.tenant_id = v_tenant_id
        and tr.scope = 'shop'
        and (tr.slug = v_role_slug or (new.role = 'admin' and tr.is_admin = true))
      order by tr.is_admin desc, tr.id asc
      limit 1;

      new.tenant_role_id := v_role_id;
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_assign_default_customer_role() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_assign_default_customer_role() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_assign_default_customer_role() TO service_role;