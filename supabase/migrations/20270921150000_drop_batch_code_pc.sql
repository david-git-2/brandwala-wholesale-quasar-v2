-- Drop unused legacy batch_code_pc table (PBC shipments only; never wired to global_shipments).
begin;

drop table if exists public.batch_code_pc cascade;

commit;
