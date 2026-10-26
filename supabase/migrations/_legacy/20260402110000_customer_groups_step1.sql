-- =========================================================
-- Step 1: Customer access tables
-- Adds customer_groups and customer_group_members
-- =========================================================

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typnamespace = 'public'::regnamespace
      and typname = 'customer_group_role'
  ) then
    create type public.customer_group_role as enum (
      'admin',
      'negotiator',
      'staff'
    );
  end if;
end
$$;

create table if not exists public.customer_groups (
  id bigserial primary key,
  name text not null,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.customer_group_members (
  id bigserial primary key,
  customer_group_id bigint not null references public.customer_groups(id) on delete cascade,
  name text not null,
  email text not null,
  role public.customer_group_role not null,
  is_active boolean not null default true,
  added_by bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists customer_groups_tenant_id_idx
  on public.customer_groups (tenant_id);

create index if not exists customer_group_members_group_id_idx
  on public.customer_group_members (customer_group_id);

create index if not exists customer_group_members_email_idx
  on public.customer_group_members (lower(trim(email)));

create unique index if not exists customer_group_members_group_email_unique
  on public.customer_group_members (customer_group_id, lower(trim(email)));

drop trigger if exists trg_customer_groups_updated_at on public.customer_groups;
create trigger trg_customer_groups_updated_at
before update on public.customer_groups
for each row execute function public.set_updated_at();

drop trigger if exists trg_customer_group_members_updated_at on public.customer_group_members;
create trigger trg_customer_group_members_updated_at
before update on public.customer_group_members
for each row execute function public.set_updated_at();
