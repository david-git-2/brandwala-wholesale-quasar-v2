-- Add global_shipment module catalog entry and migrate tenant assignments from legacy shipment.

begin;

insert into public.modules (key, name, description, is_active)
values (
  'global_shipment',
  'Global Shipment',
  'Parent-coordinated dispatch, logistics, and delivery across sister concerns.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'global_shipment', tm.is_active
from public.tenant_modules tm
where tm.module_key = 'shipment'
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'global_shipment'
  );

commit;
