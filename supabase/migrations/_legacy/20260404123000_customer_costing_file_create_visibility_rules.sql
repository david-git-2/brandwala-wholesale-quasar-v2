-- Customer can create costing files, market can be null for customer-created files,
-- customer can delete own draft files, and customer list visibility is restricted
-- to offered files or files created by the current customer.

alter table public.costing_files
  alter column market drop not null;

alter table public.costing_files
  drop constraint if exists costing_files_market_not_blank;

create or replace function public.normalize_costing_file_market()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if new.market is null then
    return new;
  end if;

  new.market := nullif(upper(trim(new.market)), '');
  return new;
end;
$$;

create or replace function public.list_costing_files_for_actor(
  p_tenant_id bigint default null,
  p_customer_group_id bigint default null,
  p_limit integer default null,
  p_offset integer default 0
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
language sql
security definer
set search_path = public
stable
as $$
  select
    cf.id,
    cf.name,
    cf.market,
    cf.status,
    cf.customer_group_id,
    cf.tenant_id,
    cf.created_by_email,
    cf.created_at,
    cf.updated_at
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  )
  order by cf.id desc
  limit p_limit
  offset greatest(coalesce(p_offset, 0), 0);
$$;

grant execute on function public.list_costing_files_for_actor(bigint, bigint, integer, integer)
to authenticated;

create or replace function public.count_costing_files_for_actor(
  p_tenant_id bigint default null,
  p_customer_group_id bigint default null
)
returns bigint
language sql
security definer
set search_path = public
stable
as $$
  select count(*)
  from public.costing_files cf
  where (
    p_tenant_id is not null
    and cf.tenant_id = p_tenant_id
    and (
      public.can_admin_manage_costing_file(cf.tenant_id)
      or public.can_staff_access_costing_file(cf.tenant_id)
    )
  )
  or (
    p_customer_group_id is not null
    and cf.customer_group_id = p_customer_group_id
    and public.can_customer_access_costing_file(cf.customer_group_id)
    and (
      cf.status = 'offered'
      or cf.created_by_email = public.current_user_email()
    )
  );
$$;

grant execute on function public.count_costing_files_for_actor(bigint, bigint)
to authenticated;

create or replace function public.create_costing_file(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_name text,
  p_market text
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

  if not (
    public.can_admin_manage_costing_file(p_tenant_id)
    or (
      public.can_customer_access_costing_file(p_customer_group_id)
      and exists (
        select 1
        from public.customer_groups cg
        where cg.id = p_customer_group_id
          and cg.tenant_id = p_tenant_id
      )
    )
  ) then
    raise exception 'You do not have permission to create this costing file.';
  end if;

  return query
    insert into public.costing_files (
      tenant_id,
      customer_group_id,
      name,
      market
    )
    values (
      p_tenant_id,
      p_customer_group_id,
      trim(p_name),
      nullif(trim(coalesce(p_market, '')), '')
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

grant execute on function public.create_costing_file(bigint, bigint, text, text)
to authenticated;

drop policy if exists "costing_files_insert" on public.costing_files;
create policy "costing_files_insert"
on public.costing_files
for insert
to authenticated
with check (
  public.can_admin_manage_costing_file(tenant_id)
  or public.can_customer_access_costing_file(customer_group_id)
);

drop policy if exists "costing_files_delete" on public.costing_files;
create policy "costing_files_delete"
on public.costing_files
for delete
to authenticated
using (
  public.can_admin_manage_costing_file(tenant_id)
  or (
    status = 'draft'
    and public.can_customer_access_costing_file(customer_group_id)
    and created_by_email = public.current_user_email()
  )
);
