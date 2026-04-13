-- =========================================================
-- Store module schema + RPC + RLS
-- =========================================================

create table if not exists public.stores (
  id bigserial primary key,
  name text not null,
  vendor_code text,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint stores_name_not_blank check (length(trim(name)) > 0)
);

create table if not exists public.store_access (
  id bigserial primary key,
  store_id bigint not null references public.stores(id) on delete cascade,
  customer_group_id bigint not null references public.customer_groups(id) on delete cascade,
  status boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint store_access_store_customer_group_unique unique (store_id, customer_group_id)
);

create index if not exists stores_tenant_id_idx on public.stores(tenant_id);
create index if not exists stores_vendor_code_idx on public.stores(vendor_code);
create index if not exists store_access_store_id_idx on public.store_access(store_id);
create index if not exists store_access_customer_group_id_idx on public.store_access(customer_group_id);
create index if not exists customer_group_members_email_active_idx
  on public.customer_group_members (lower(trim(email)), is_active);

drop trigger if exists trg_stores_updated_at on public.stores;
create trigger trg_stores_updated_at
before update on public.stores
for each row execute function public.set_updated_at();

drop trigger if exists trg_store_access_updated_at on public.store_access;
create trigger trg_store_access_updated_at
before update on public.store_access
for each row execute function public.set_updated_at();

create or replace function public.can_manage_store(p_tenant_id bigint)
returns boolean
language sql
stable
as $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
$$;

create or replace function public.can_customer_access_store(p_store_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.store_access sa
    join public.customer_group_members cgm
      on cgm.customer_group_id = sa.customer_group_id
    where sa.store_id = p_store_id
      and sa.status = true
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
  )
$$;

grant execute on function public.can_customer_access_store(bigint)
to authenticated;

create or replace function public.create_store(
  p_name text,
  p_vendor_code text,
  p_tenant_id bigint
)
returns public.stores
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.stores;
begin
  if not public.can_manage_store(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.stores (name, vendor_code, tenant_id)
  values (trim(p_name), nullif(trim(p_vendor_code), ''), p_tenant_id)
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_store(text, text, bigint)
to authenticated;

create or replace function public.update_store(
  p_id bigint,
  p_name text,
  p_vendor_code text
)
returns public.stores
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.stores;
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.stores
  set
    name = trim(p_name),
    vendor_code = nullif(trim(p_vendor_code), '')
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.update_store(bigint, text, text)
to authenticated;

create or replace function public.delete_store(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.stores where id = p_id;
end;
$$;

grant execute on function public.delete_store(bigint)
to authenticated;

create or replace function public.get_stores_admin(p_tenant_id bigint)
returns setof public.stores
language sql
security definer
set search_path = public
stable
as $$
  select *
  from public.stores
  where tenant_id = p_tenant_id
    and public.can_manage_store(p_tenant_id)
$$;

grant execute on function public.get_stores_admin(bigint)
to authenticated;

create or replace function public.create_store_access(
  p_store_id bigint,
  p_customer_group_id bigint,
  p_status boolean default true
)
returns public.store_access
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.store_access;
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.stores
  where id = p_store_id;

  if v_tenant_id is null then
    raise exception 'store not found';
  end if;

  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.store_access (
    store_id,
    customer_group_id,
    status
  )
  values (
    p_store_id,
    p_customer_group_id,
    p_status
  )
  on conflict (store_id, customer_group_id)
  do update
  set
    status = excluded.status,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_store_access(bigint, bigint, boolean)
to authenticated;

create or replace function public.update_store_access(
  p_id bigint,
  p_status boolean
)
returns public.store_access
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.store_access;
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where sa.id = p_id;

  if v_tenant_id is null then
    raise exception 'store access not found';
  end if;

  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.store_access
  set status = p_status
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.update_store_access(bigint, boolean)
to authenticated;

create or replace function public.delete_store_access(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select s.tenant_id into v_tenant_id
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where sa.id = p_id;

  if v_tenant_id is null then
    raise exception 'store access not found';
  end if;

  if not public.can_manage_store(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.store_access where id = p_id;
end;
$$;

grant execute on function public.delete_store_access(bigint)
to authenticated;

create or replace function public.get_store_access_admin(p_store_id bigint)
returns setof public.store_access
language sql
security definer
set search_path = public
stable
as $$
  select sa.*
  from public.store_access sa
  join public.stores s on s.id = sa.store_id
  where sa.store_id = p_store_id
    and public.can_manage_store(s.tenant_id)
$$;

grant execute on function public.get_store_access_admin(bigint)
to authenticated;

create or replace function public.get_stores_for_customer()
returns setof public.stores
language sql
security definer
set search_path = public
stable
as $$
  select s.*
  from public.stores s
  where public.can_customer_access_store(s.id)
$$;

grant execute on function public.get_stores_for_customer()
to authenticated;

create or replace function public.check_store_access(p_store_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.can_customer_access_store(p_store_id)
$$;

grant execute on function public.check_store_access(bigint)
to authenticated;

alter table public.stores enable row level security;
alter table public.store_access enable row level security;

drop policy if exists "stores_select" on public.stores;
create policy "stores_select"
on public.stores
for select
to authenticated
using (
  public.can_manage_store(tenant_id)
  or public.can_customer_access_store(id)
);

drop policy if exists "stores_modify" on public.stores;
create policy "stores_modify"
on public.stores
for all
to authenticated
using (false)
with check (false);

drop policy if exists "store_access_select" on public.store_access;
create policy "store_access_select"
on public.store_access
for select
to authenticated
using (true);

drop policy if exists "store_access_modify" on public.store_access;
create policy "store_access_modify"
on public.store_access
for all
to authenticated
using (false)
with check (false);
