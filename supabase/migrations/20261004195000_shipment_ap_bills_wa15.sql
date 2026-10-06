-- Stub: WA15 body needs public.bills / public.pays (renamed in 20271006120000_bills_pays_backend_pack.sql).
-- Full migration: 20271006120100_deferred_shipment_ap_bills_wa15.sql
do $$ begin
  raise notice 'skipped shipment_ap_bills_wa15 (deferred to 20271006120100)';
end $$;
