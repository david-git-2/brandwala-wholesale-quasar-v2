-- Migration: Update Foreign Keys on billing_profiles to ON DELETE CASCADE / SET NULL

-- 1. global_payments: Change payments_billing_profile_id_fkey to ON DELETE CASCADE
alter table public.global_payments
  drop constraint if exists payments_billing_profile_id_fkey;

alter table public.global_payments
  add constraint payments_billing_profile_id_fkey
  foreign key (billing_profile_id)
  references public.billing_profiles(id)
  on delete cascade;

-- 2. global_invoices: Change global_invoices_billing_profile_id_fkey to ON DELETE SET NULL / CASCADE
alter table public.global_invoices
  drop constraint if exists global_invoices_billing_profile_id_fkey;

alter table public.global_invoices
  add constraint global_invoices_billing_profile_id_fkey
  foreign key (billing_profile_id)
  references public.billing_profiles(id)
  on delete set null;

-- 3. shop_orders: Change shop_orders_billing_profile_id_fkey to ON DELETE SET NULL
alter table public.shop_orders
  drop constraint if exists shop_orders_billing_profile_id_fkey;

alter table public.shop_orders
  add constraint shop_orders_billing_profile_id_fkey
  foreign key (billing_profile_id)
  references public.billing_profiles(id)
  on delete set null;
