CREATE FUNCTION public.trg_fn_memberships_owner_placement()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_parent_id bigint;
begin
  if new.role = 'admin'::public.app_role then
    raise exception 'app_role admin is retired; use owner, manager, staff, or viewer';
  end if;

  if new.role = 'owner'::public.app_role then
    select t.parent_id into v_parent_id
    from public.tenants t
    where t.id = new.tenant_id;

    if v_parent_id is not null then
      raise exception 'Owner membership must be on the parent or standalone tenant, not a child desk';
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_fn_memberships_owner_placement() TO anon;

GRANT ALL ON FUNCTION public.trg_fn_memberships_owner_placement() TO authenticated;

GRANT ALL ON FUNCTION public.trg_fn_memberships_owner_placement() TO service_role;