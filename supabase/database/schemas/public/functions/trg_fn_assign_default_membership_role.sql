CREATE FUNCTION public.trg_fn_assign_default_membership_role()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_role_slug text;
  v_role_id bigint;
begin
  if new.tenant_role_id is null and new.tenant_id is not null and new.role is not null then
    v_role_slug := case new.role
      when 'owner' then 'owner'
      when 'manager' then 'manager'
      when 'staff' then 'staff'
      when 'viewer' then 'viewer'
      else 'viewer'
    end;

    select id into v_role_id
    from public.tenant_roles
    where tenant_id = new.tenant_id
      and scope = 'app'
      and slug = v_role_slug;

    new.tenant_role_id := v_role_id;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_assign_default_membership_role() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_assign_default_membership_role() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_assign_default_membership_role() TO service_role;