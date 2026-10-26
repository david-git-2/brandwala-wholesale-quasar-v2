-- Allow tenant staff to create costing files, add items, and move draft files into review.

create or replace function public.create_costing_file(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_name text,
  p_market text,
  p_status public.costing_file_status default 'draft'
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
    insert into public.costing_files (
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
      id,
      name,
      market,
      status,
      customer_group_id,
      tenant_id,
      created_by_email,
      created_at,
      updated_at;
end;
$$;

grant execute on function public.create_costing_file(bigint, bigint, text, text, public.costing_file_status)
to authenticated;

drop policy if exists "costing_files_insert" on public.costing_files;
create policy "costing_files_insert"
on public.costing_files
for insert
to authenticated
with check (
  public.can_admin_manage_costing_file(tenant_id)
  or public.can_staff_access_costing_file(tenant_id)
  or public.can_customer_access_costing_file(customer_group_id)
);

drop policy if exists "costing_file_items_insert" on public.costing_file_items;
create policy "costing_file_items_insert"
on public.costing_file_items
for insert
to authenticated
with check (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or public.can_staff_access_costing_file(cf.tenant_id)
        or public.can_customer_access_costing_file(cf.customer_group_id)
      )
  )
);

create or replace function public.update_costing_file_status(
  p_id bigint,
  p_status public.costing_file_status
)
returns table(
  id bigint,
  status public.costing_file_status,
  updated_at timestamptz
)
language sql
security definer
set search_path = public
volatile
as $$
  with updated as (
    update public.costing_files cf
    set status = p_status
    where cf.id = p_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          p_status = 'in_review'
          and cf.status in ('draft', 'customer_submitted')
          and public.can_staff_access_costing_file(cf.tenant_id)
        )
        or (
          p_status = 'customer_submitted'
          and cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
    returning
      cf.id,
      cf.status,
      cf.updated_at
  )
  select *
  from updated;
$$;

grant execute on function public.update_costing_file_status(bigint, public.costing_file_status)
to authenticated;
