begin;

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values
  (
    'thrift_shipment',
    'Thrift Shipment',
    'Coordinate shipment logs and transport records within thrift workflows.',
    true
  ),
  (
    'thrift_box',
    'Thrift Box',
    'Manage container boxes and weights under specific shipments.',
    true
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

commit;
