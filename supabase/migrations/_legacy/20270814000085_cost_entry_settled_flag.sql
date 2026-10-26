-- Phase 13A: cost entry settled marker

begin;

alter table public.global_shipment_cost_entries
  add column if not exists settled_at timestamptz,
  add column if not exists settlement_ledger_id uuid;

create index if not exists global_shipment_cost_entries_settled_idx
  on public.global_shipment_cost_entries (shipment_id)
  where settled_at is null;

commit;
