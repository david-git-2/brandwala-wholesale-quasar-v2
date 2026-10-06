-- Stub: original body uses sales_invoice_items; table renamed to bill_lines in 20271006120000_bills_pays_backend_pack.sql.
-- Full definitions live in 20271006120000 (preorder_demand_invoice_items_stale, build_preorder_demand_invoice_items, etc.).
do $$ begin
  raise notice 'skipped fulfill_invoice_sync (deferred to 20271006120000_bills_pays_backend_pack)';
end $$;
