-- Migration: Add parent_tenant_id (default NULL) to billing_profiles and recipient_profiles,
-- and ensure phone is unique per child tenant (tenant_id, phone), not parent_tenant_id.

begin;

-- 1. billing_profiles
alter table public.billing_profiles
  add column if not exists parent_tenant_id bigint null references public.tenants(id) on delete set null;

create index if not exists billing_profiles_parent_tenant_id_idx
  on public.billing_profiles (parent_tenant_id);

-- Unique phone per child tenant (ignoring NULL/empty phones)
create unique index if not exists billing_profiles_tenant_phone_uidx
  on public.billing_profiles (tenant_id, phone)
  where phone is not null and phone <> '';

-- 2. recipient_profiles
alter table public.recipient_profiles
  add column if not exists parent_tenant_id bigint null references public.tenants(id) on delete set null;

create index if not exists recipient_profiles_parent_tenant_id_idx
  on public.recipient_profiles (parent_tenant_id);

-- recipient_profiles already has recipient_profiles_tenant_phone_uidx on (tenant_id, phone)
create unique index if not exists recipient_profiles_tenant_phone_uidx
  on public.recipient_profiles (tenant_id, phone);

commit;
