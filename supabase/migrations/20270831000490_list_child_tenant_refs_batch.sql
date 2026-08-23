-- Batch child-tenant lookup for workspace hierarchy (replaces N parallel list_child_tenant_ids calls)
begin;

create or replace function public.list_child_tenant_refs(p_parent_tenant_ids bigint[])
returns table (
  id bigint,
  parent_id bigint
)
language sql
stable
security definer
set search_path = public
as $$
  select t.id, t.parent_id
  from public.tenants t
  where t.parent_id = any (coalesce(p_parent_tenant_ids, array[]::bigint[]))
  order by t.parent_id, t.id;
$$;

grant execute on function public.list_child_tenant_refs(bigint[]) to authenticated;

commit;
