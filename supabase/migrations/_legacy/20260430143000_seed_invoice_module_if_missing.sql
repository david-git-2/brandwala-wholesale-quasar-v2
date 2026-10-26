insert into public.modules (
  key,
  name,
  description,
  is_active
)
values (
  'invoice',
  'Invoice',
  'Manage invoice creation, status, and reconciliation flow.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;
