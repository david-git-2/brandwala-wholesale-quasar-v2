-- Migration: Complete cleanup of legacy accounting references and triggers blocking billing profile deletion

do $$
declare
  r record;
begin
  -- 1. Drop known legacy triggers on commerce_invoices if table exists
  if to_regclass('public.commerce_invoices') is not null then
    execute 'drop trigger if exists trg_sync_commerce_invoice_charges on public.commerce_invoices';
    execute 'drop trigger if exists trg_commerce_invoice_discount_spreader on public.commerce_invoices';
    execute 'drop trigger if exists trg_commerce_invoice_payment_status_sync on public.commerce_invoices';
    execute 'drop trigger if exists trg_recalculate_commerce_invoice_totals on public.commerce_invoices';
  end if;

  -- 2. Drop known legacy triggers on billing_profiles and inventory_accounting_entries if tables exist
  if to_regclass('public.billing_profiles') is not null then
    execute 'drop trigger if exists trg_sync_commerce_accounting_entry on public.billing_profiles';
  end if;

  if to_regclass('public.inventory_accounting_entries') is not null then
    execute 'drop trigger if exists trg_sync_commerce_accounting_entry on public.inventory_accounting_entries';
  end if;

  -- 3. Drop legacy functions referencing inventory_accounting_entries
  execute 'drop function if exists public.trg_fn_sync_commerce_invoice_charges() cascade';
  execute 'drop function if exists public.trg_fn_spread_commerce_invoice_discount() cascade';
  execute 'drop function if exists public.trg_fn_sync_commerce_invoice_payment_status() cascade';
  execute 'drop function if exists public.fn_sync_commerce_accounting_entry() cascade';
  execute 'drop function if exists public.recompute_invoice_payment_status(bigint) cascade';
  execute 'drop function if exists public.recompute_invoice_payment_status() cascade';
  execute 'drop function if exists public.add_commerce_invoice_item_transactional cascade';
  execute 'drop function if exists public.delete_commerce_invoice_item_transactional cascade';
  execute 'drop function if exists public.cancel_commerce_invoice_transactional cascade';
  execute 'drop function if exists public.update_commerce_invoice_charges cascade';
  execute 'drop function if exists public.sync_commerce_invoice_discount_and_print_charges cascade';

  -- 4. Drop FK constraints on billing_profiles and other tables referencing inventory_accounting_entries
  if to_regclass('public.billing_profiles') is not null then
    execute 'alter table public.billing_profiles drop constraint if exists inventory_accounting_entries_billing_profile_id_fkey';
  end if;

  for r in (
    select tc.table_schema, tc.table_name, tc.constraint_name
    from information_schema.table_constraints tc
    where tc.constraint_name like '%inventory_accounting_entries%'
  ) loop
    execute format('alter table %I.%I drop constraint if exists %I', r.table_schema, r.table_name, r.constraint_name);
  end loop;

  -- 5. Dynamically drop any remaining function whose definition body references inventory_accounting_entries
  for r in (
    select n.nspname as schema_name, p.proname as function_name, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.prosrc ilike '%inventory_accounting_entries%'
  ) loop
    execute format('drop function if exists %I.%I(%s) cascade', r.schema_name, r.function_name, r.args);
  end loop;

end $$;
