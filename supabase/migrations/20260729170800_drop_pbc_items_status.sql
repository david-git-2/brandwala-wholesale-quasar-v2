-- Migration: Drop stored status column from product_based_costing_items table
-- Fresh-reset note: upsert_pbc_backlog_from_item RETURNS product_based_costing_backlog_items,
-- which is only created in 20260905000100. Function body is reintroduced there + 20260905000200.
-- Keep the real schema change (drop status) here.

do $$ begin
  raise notice 'skipped upsert_pbc_backlog_from_item recreate (needs backlog table; see 20260905000200)';
end $$;

-- Recreate trigger without column 'status' (table exists from earlier PBC migrations)
do $$
begin
  if to_regclass('public.product_based_costing_items') is null then
    raise notice 'product_based_costing_items missing — skip trigger/status drop';
    return;
  end if;

  execute 'drop trigger if exists trg_pbc_items_auto_backlog on public.product_based_costing_items';

  if to_regprocedure('public.trg_fn_auto_upsert_pbc_backlog()') is not null then
    execute $sql$
      create trigger trg_pbc_items_auto_backlog
      after insert or update of quantity, confirmed_quantity, ordered_quantity, product_id or delete
      on public.product_based_costing_items
      for each row
      execute function public.trg_fn_auto_upsert_pbc_backlog()
    $sql$;
  end if;

  execute 'alter table public.product_based_costing_items drop column if exists status';
end $$;
