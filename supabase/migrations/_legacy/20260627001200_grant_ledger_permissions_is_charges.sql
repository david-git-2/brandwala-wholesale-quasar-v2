-- Migration: Grant SELECT on v_shipment_accounting_ledger after adding is_charges
begin;

grant select on table public.v_shipment_accounting_ledger to authenticated, anon;

commit;
