-- Migration: Restrict v_shipment_accounting_ledger access to authenticated only
begin;

-- Revoke select permissions from anon and public roles
revoke select on table public.v_shipment_accounting_ledger from anon;
revoke select on table public.v_shipment_accounting_ledger from public;

-- Ensure authenticated role has select access
grant select on table public.v_shipment_accounting_ledger to authenticated;

-- Notify PostgREST to reload schema cache
notify pgrst, 'reload schema';

commit;
