-- Stub: original body moved to 20261110000010_deferred_create_dual_invoice_from_dropship_order.sql for correct ordering on fresh `db reset`.
-- Production already applied this version historically.
do $$ begin
  raise notice 'skipped create_dual_invoice (deferred to 20261110000010)';
end $$;
