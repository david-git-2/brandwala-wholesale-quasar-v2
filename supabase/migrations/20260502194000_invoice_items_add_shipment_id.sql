alter table public.invoice_items
  add column if not exists shipment_id bigint null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'invoice_items_shipment_id_fkey'
      and conrelid = 'public.invoice_items'::regclass
  ) then
    alter table public.invoice_items
      add constraint invoice_items_shipment_id_fkey
      foreign key (shipment_id)
      references public.shipments(id)
      on delete set null;
  end if;
end $$;

create index if not exists invoice_items_shipment_id_idx
  on public.invoice_items (shipment_id);
