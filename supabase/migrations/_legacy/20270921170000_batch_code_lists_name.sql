-- Batch code lists: required name; shipment stays optional.
begin;

alter table public.batch_code_lists
  add column if not exists name text;

update public.batch_code_lists bcl
set name = coalesce(
  (
    select gs.name
    from public.global_shipments gs
    where gs.id = bcl.shipment_id
  ),
  'Batch file #' || bcl.id::text
)
where bcl.name is null or btrim(bcl.name) = '';

alter table public.batch_code_lists
  alter column name set not null;

commit;
