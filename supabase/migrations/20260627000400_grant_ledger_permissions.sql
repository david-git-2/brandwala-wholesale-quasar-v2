-- Migration: Grant SELECT permissions on v_shipment_accounting_ledger
begin;

grant select on table public.v_shipment_accounting_ledger to authenticated, anon;

commit;
