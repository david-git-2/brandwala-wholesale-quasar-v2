-- Migration: Remove commerce_billing_profiles table and use billing_profiles
begin;

-- 1. Drop old foreign keys pointing to commerce_billing_profiles
alter table public.commerce_invoices
  drop constraint if exists commerce_invoices_billing_profile_id_fkey;

alter table public.inventory_accounting_entries
  drop constraint if exists inventory_accounting_entries_billing_profile_id_fkey;

-- 2. Add new foreign keys pointing to public.billing_profiles
alter table public.commerce_invoices
  add constraint commerce_invoices_billing_profile_id_fkey
  foreign key (billing_profile_id) references public.billing_profiles(id) on delete set null;

alter table public.inventory_accounting_entries
  add constraint inventory_accounting_entries_billing_profile_id_fkey
  foreign key (billing_profile_id) references public.billing_profiles(id) on delete set null;

-- 3. Drop public.commerce_billing_profiles table
drop table if exists public.commerce_billing_profiles cascade;

commit;
