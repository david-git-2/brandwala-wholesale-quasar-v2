-- =========================================================
-- Migration: Create merchant_profiles table and APIs for dropship merchants
-- =========================================================

begin;

-- 1. Create merchant_profiles table
create table if not exists public.merchant_profiles (
  id uuid primary key default gen_random_uuid(),
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  merchant_name text not null,
  store_name text,
  phone_primary text not null,
  phone_secondary text,
  pickup_address text not null,
  district text not null default 'Dhaka',
  thana text not null,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for tenant lookups
create index if not exists idx_merchant_profiles_tenant on public.merchant_profiles(tenant_id);

-- Enable RLS
alter table public.merchant_profiles enable row level security;

-- Grants
grant all on public.merchant_profiles to authenticated;
grant all on public.merchant_profiles to service_role;

-- RLS Policy: Authenticated users can view merchant profiles in their tenant scope
create policy "Authenticated users can select tenant merchant profiles"
  on public.merchant_profiles for select
  to authenticated
  using (
    tenant_id = (select current_setting('app.current_tenant_id', true)::bigint)
    or exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = public.merchant_profiles.tenant_id
      and m.is_active = true
    )
  );

-- RLS Policy: Members can insert merchant profiles
create policy "Members can insert merchant profiles"
  on public.merchant_profiles for insert
  to authenticated
  with check (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = public.merchant_profiles.tenant_id
      and m.is_active = true
    )
  );

-- RLS Policy: Members can update merchant profiles
create policy "Members can update merchant profiles"
  on public.merchant_profiles for update
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = public.merchant_profiles.tenant_id
      and m.is_active = true
    )
  )
  with check (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = public.merchant_profiles.tenant_id
      and m.is_active = true
    )
  );

-- RLS Policy: Members can delete merchant profiles
create policy "Members can delete merchant profiles"
  on public.merchant_profiles for delete
  to authenticated
  using (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = public.merchant_profiles.tenant_id
      and m.is_active = true
    )
  );

commit;
