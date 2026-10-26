create or replace function public.list_tenant_modules_by_tenant(
  p_tenant_id bigint
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at
  from public.tenant_modules tm
  where tm.tenant_id = p_tenant_id
  order by tm.id asc;
$$;

grant execute on function public.list_tenant_modules_by_tenant(bigint)
to authenticated;


create or replace function public.get_tenant_module_by_id(
  p_id bigint
)
returns table(
  id bigint,
  tenant_id bigint,
  module_key text,
  is_active boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select
    tm.id,
    tm.tenant_id,
    tm.module_key,
    tm.is_active,
    tm.created_at,
    tm.updated_at
  from public.tenant_modules tm
  where tm.id = p_id
  limit 1;
$$;

grant execute on function public.get_tenant_module_by_id(bigint)
to authenticated;