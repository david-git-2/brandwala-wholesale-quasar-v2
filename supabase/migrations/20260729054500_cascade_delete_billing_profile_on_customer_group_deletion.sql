-- Migration: Cascade delete billing profiles when customer group is deleted

alter table public.billing_profiles
  drop constraint if exists billing_profiles_customer_group_id_fkey;

alter table public.billing_profiles
  add constraint billing_profiles_customer_group_id_fkey
  foreign key (customer_group_id)
  references public.customer_groups(id)
  on delete cascade;
