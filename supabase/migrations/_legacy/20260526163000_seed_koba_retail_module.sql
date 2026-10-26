-- Seed the koba_retail module key in public.modules and link it for all tenants.
begin;

insert into public.modules (
  key,
  name,
  description,
  is_active
)
values
  (
    'koba_retail',
    'Koba Retail',
    'Browse scraped Koba Retail products catalog.',
    true
  )
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- Enable the module for all tenants (including tenant 12)
insert into public.tenant_modules (tenant_id, module_key)
select id, 'koba_retail'
from public.tenants
on conflict do nothing;

commit;
