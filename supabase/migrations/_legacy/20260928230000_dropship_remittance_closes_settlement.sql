-- Stub: record_dropship_courier_remittance and get_dropship_management_order need
-- process_dropship_courier_remittance_uwl and related helpers (20270129000003+,
-- 20270831210000+). Settlement row backfills need universal_wallet_ledger.parent_tenant_id
-- (20270832000000+) — see 20270832000001_deferred_dropship_remittance_settlement_backfills.sql.

do $$ begin
  raise notice 'skipped dropship_remittance_closes_settlement RPCs and backfills (deferred to later migrations)';
end $$;
