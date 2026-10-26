-- Follow-up fix: avoid ambiguous output-column references in PL/pgSQL.

create or replace function public.create_costing_file(
  p_customer_group_id bigint,
  p_market text,
  p_name text,
  p_status public.costing_file_status default 'draft',
  p_tenant_id bigint default null
)
returns table(
  id bigint,
  name text,
  market text,
  status public.costing_file_status,
  customer_group_id bigint,
  tenant_id bigint,
  created_by_email text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
security definer
set search_path = public
volatile
as $$
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required.';
  end if;

  if trim(coalesce(p_name, '')) = '' then
    raise exception 'Costing file name is required.';
  end if;

  if not exists (
    select 1
    from public.customer_groups cg
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
  ) then
    raise exception 'Customer group does not belong to this tenant.';
  end if;

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or public.can_staff_access_costing_file(p_tenant_id)
    or public.can_customer_access_costing_file(p_customer_group_id)
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files as cf (
      tenant_id,
      customer_group_id,
      name,
      market,
      status
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), ''),
      coalesce(p_status, 'draft')
    )
    returning
      cf.id,
      cf.name,
      cf.market,
      cf.status,
      cf.customer_group_id,
      cf.tenant_id,
      cf.created_by_email,
      cf.created_at,
      cf.updated_at;
end;
$$;

grant execute on function public.create_costing_file(
  bigint,
  text,
  text,
  public.costing_file_status,
  bigint
)
to authenticated;
