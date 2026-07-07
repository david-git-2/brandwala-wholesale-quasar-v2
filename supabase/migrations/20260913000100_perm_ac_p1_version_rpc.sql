-- Migration: AC-P1 version query RPC and table permissions
begin;

-- Enable RLS on tenant_permission_versions
alter table public.tenant_permission_versions enable row level security;

-- Policy to allow authenticated users to read versions
create policy "Allow authenticated users to read permission versions"
  on public.tenant_permission_versions
  for select
  to authenticated
  using (true);

-- Grant select to authenticated
grant select on public.tenant_permission_versions to authenticated;

-- RPC: get_tenant_permission_version
create or replace function public.get_tenant_permission_version(p_tenant_id bigint)
returns bigint
language plpgsql
security definer
stable
set search_path = public
as $$
declare
  v_version bigint;
begin
  select version into v_version
  from public.tenant_permission_versions
  where tenant_id = p_tenant_id;
  
  return coalesce(v_version, 1);
end;
$$;

grant execute on function public.get_tenant_permission_version(bigint) to authenticated;

commit;
