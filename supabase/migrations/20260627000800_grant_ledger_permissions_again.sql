-- Migration: Regrant SELECT permissions on v_shipment_accounting_ledger after recreation
begin;

grant select on table public.v_shipment_accounting_ledger to authenticated, anon;

commit;
