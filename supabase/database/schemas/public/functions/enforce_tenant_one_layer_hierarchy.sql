CREATE FUNCTION public.enforce_tenant_one_layer_hierarchy()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
declare
  v_parent_parent_id bigint;
begin
  if new.parent_id is not null then
    if new.parent_id = new.id then
      raise exception 'tenant cannot be its own parent';
    end if;

    select parent_id into v_parent_parent_id
    from public.tenants
    where id = new.parent_id;

    if v_parent_parent_id is not null then
      raise exception 'parent tenant must be a top-level company (one layer only)';
    end if;

    if exists (
      select 1
      from public.tenants c
      where c.parent_id = new.id
    ) then
      raise exception 'tenant with child companies cannot be assigned a parent';
    end if;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.enforce_tenant_one_layer_hierarchy() TO anon;

GRANT ALL ON FUNCTION public.enforce_tenant_one_layer_hierarchy() TO authenticated;

GRANT ALL ON FUNCTION public.enforce_tenant_one_layer_hierarchy() TO service_role;