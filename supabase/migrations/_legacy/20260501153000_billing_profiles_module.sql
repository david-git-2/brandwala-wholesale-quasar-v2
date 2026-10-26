create table if not exists public.billing_profiles (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  email text null,
  customer_group_id bigint null references public.customer_groups(id) on delete set null,
  phone text null,
  address text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists billing_profiles_tenant_id_idx
  on public.billing_profiles (tenant_id);

create index if not exists billing_profiles_customer_group_id_idx
  on public.billing_profiles (customer_group_id);

create index if not exists billing_profiles_name_idx
  on public.billing_profiles (name);

drop trigger if exists trg_billing_profiles_set_updated_at on public.billing_profiles;
create trigger trg_billing_profiles_set_updated_at
before update on public.billing_profiles
for each row execute function public.set_updated_at();

alter table public.billing_profiles enable row level security;

drop policy if exists billing_profiles_select on public.billing_profiles;
create policy billing_profiles_select
on public.billing_profiles
for select
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists billing_profiles_insert on public.billing_profiles;
create policy billing_profiles_insert
on public.billing_profiles
for insert
to authenticated
with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists billing_profiles_update on public.billing_profiles;
create policy billing_profiles_update
on public.billing_profiles
for update
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists billing_profiles_delete on public.billing_profiles;
create policy billing_profiles_delete
on public.billing_profiles
for delete
to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

grant select, insert, update, delete on table public.billing_profiles to authenticated;
grant usage, select on sequence public.billing_profiles_id_seq to authenticated;
