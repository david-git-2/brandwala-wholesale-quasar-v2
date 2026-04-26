begin;

alter table public.shipments
  add column if not exists status text;

update public.shipments
set status = 'Draft'
where status is null or btrim(status) = '';

alter table public.shipments
  alter column status set default 'Draft';

alter table public.shipments
  alter column status set not null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'shipments_status_check'
      and conrelid = 'public.shipments'::regclass
  ) then
    alter table public.shipments
      add constraint shipments_status_check
      check (
        status in (
          'Draft',
          'Order Placed',
          'Proforma Generated',
          'Payment Done',
          'Delivery Date Received',
          'Uk Warehouse Delivery Received',
          'Air Shipment Date Set',
          'Airport Arrival',
          'Airport Released',
          'Warehouse Received'
        )
      );
  end if;
end
$$;

create index if not exists shipments_status_idx
  on public.shipments (status);

commit;
