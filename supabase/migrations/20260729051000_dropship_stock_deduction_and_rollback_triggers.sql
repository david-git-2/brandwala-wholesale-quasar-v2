-- Stub: original body moved to 20261110000013_deferred_dropship_stock_deduction_triggers.sql for correct ordering on fresh `db reset`.
-- Production already applied this version historically.
do $$ begin
  raise notice 'skipped dropship stock triggers (deferred to 20261110000013)';
end $$;
