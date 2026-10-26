-- Product inserts look up tenants.parent_id. authenticated has no SELECT on tenants.
-- Run this trigger as the function owner so the REST API does not need table grants.

create or replace function public.set_parent_tenant_id_from_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_id bigint;
begin
  if new.tenant_id is not null then
    select parent_id into v_parent_id
    from public.tenants
    where id = new.tenant_id;

    new.parent_tenant_id := coalesce(v_parent_id, new.tenant_id);
  end if;

  return new;
end;
$$;
