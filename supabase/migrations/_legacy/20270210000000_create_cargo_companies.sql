-- =========================================================
-- Cargo Companies Table Migration
-- Dedicated table for cargo & freight logistics providers with
-- multi-tenant scoping, wallet linkage support, RLS policies & grants.
-- =========================================================

create table if not exists public.cargo_companies (
  id bigserial primary key,
  tenant_id bigint references public.tenants(id) on delete cascade,
  parent_tenant_id bigint references public.tenants(id) on delete cascade,
  name text not null,
  code text not null,
  phone text,
  email text,
  address text,
  notes text,
  wallet_entity_id bigint,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint cargo_companies_name_not_blank check (length(trim(name)) > 0),
  constraint cargo_companies_code_not_blank check (length(trim(code)) > 0)
);

-- Indexes
create index if not exists cargo_companies_tenant_id_idx on public.cargo_companies(tenant_id);
create index if not exists cargo_companies_parent_tenant_id_idx on public.cargo_companies(parent_tenant_id);
create unique index if not exists cargo_companies_tenant_code_idx on public.cargo_companies(tenant_id, upper(trim(code))) where tenant_id is not null;

-- Trigger for auto-updating updated_at timestamp
create trigger trg_cargo_companies_updated_at
before update on public.cargo_companies
for each row execute function public.set_updated_at();

-- Enable Row Level Security (RLS)
alter table public.cargo_companies enable row level security;

-- Security Policies
create policy cargo_companies_select_policy on public.cargo_companies
  for select using (
    tenant_id is null 
    or tenant_id = public.current_tenant_id() 
    or parent_tenant_id = public.current_tenant_id()
  );

create policy cargo_companies_insert_policy on public.cargo_companies
  for insert with check (
    tenant_id = public.current_tenant_id()
    or parent_tenant_id = public.current_tenant_id()
  );

create policy cargo_companies_update_policy on public.cargo_companies
  for update using (
    tenant_id = public.current_tenant_id()
    or parent_tenant_id = public.current_tenant_id()
  );

create policy cargo_companies_delete_policy on public.cargo_companies
  for delete using (
    tenant_id = public.current_tenant_id()
    or parent_tenant_id = public.current_tenant_id()
  );

-- Table Grants
grant select, insert, update, delete on public.cargo_companies to authenticated;
grant select, insert, update, delete on public.cargo_companies to service_role;
