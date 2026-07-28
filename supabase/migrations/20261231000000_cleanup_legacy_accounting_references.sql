-- Migration: Cleanup any remaining foreign key constraints or functions referencing dropped legacy table inventory_accounting_entries

do $$
declare
  r record;
begin
  -- 1. Drop foreign key constraint on billing_profiles if it exists
  execute 'alter table public.billing_profiles drop constraint if exists inventory_accounting_entries_billing_profile_id_fkey';

  -- 2. Dynamically drop any foreign key constraints on any table that reference inventory_accounting_entries
  for r in (
    select tc.table_schema, tc.table_name, tc.constraint_name
    from information_schema.table_constraints tc
    where tc.constraint_name like '%inventory_accounting_entries%'
  ) loop
    execute format('alter table %I.%I drop constraint if exists %I', r.table_schema, r.table_name, r.constraint_name);
  end loop;

  -- 3. Drop legacy triggers and functions referencing inventory_accounting_entries
  execute 'drop trigger if exists trg_sync_commerce_accounting_entry on public.billing_profiles';
  execute 'drop function if exists public.trg_fn_sync_commerce_invoice_payment_status() cascade';

end $$;
