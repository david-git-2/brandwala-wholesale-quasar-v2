begin;

alter table public.batch_code_pc
  alter column shipment_item_id drop not null;

commit;
