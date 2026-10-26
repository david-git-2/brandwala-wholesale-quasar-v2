-- Enable Investor Capital parent module on root tenants so app nav expands
-- investor_profiles (Investors link). Child brand tenants stay excluded per
-- has_module_action / app bootstrap rules.

begin;

-- Ensure catalog row is active (hierarchy migration may have run before some tenants existed)
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'investor_capital',
  'Investor Capital',
  'Parent module for investor profiles, capital ledger, shipment share allocations, and investor portal.',
  true,
  null
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = true,
  parent_module_key = excluded.parent_module_key;

insert into public.modules (key, name, description, is_active, parent_module_key)
values
  (
    'investor_profiles',
    'Investor Profiles',
    'Manage investor profiles and client contact details.',
    true,
    'investor_capital'
  ),
  (
    'investor_capital_ledger',
    'Capital Ledger',
    'Manage capital deposits, adjustments, and withdrawal transactions.',
    true,
    'investor_capital'
  ),
  (
    'investor_shipment_share',
    'Shipment Share Allocations',
    'Assign investor cost-share percentage and track shipment profit allocations.',
    true,
    'investor_capital'
  ),
  (
    'investor_portal',
    'Investor Portal',
    'External read-only dashboard for investors to track their portfolio.',
    true,
    'investor_capital'
  )
on conflict (key) do update set
  is_active = true,
  parent_module_key = excluded.parent_module_key;

-- Root companies only (parent_id is null): assign parent module; submodules expand via get_active_module_keys_for_tenant
insert into public.tenant_modules (tenant_id, module_key, is_active)
select t.id, 'investor_capital', true
from public.tenants t
where t.is_active = true
  and t.parent_id is null
on conflict (tenant_id, module_key) do update set
  is_active = true;

-- Backfill role grants from system templates (investor_profiles view for staff, etc.)
select public.seed_tenant_roles_and_grants(t.id)
from public.tenants t
where t.is_active = true
  and t.parent_id is null;

create or replace function public.auto_enable_investor_capital_for_root_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if NEW.parent_id is null then
    insert into public.tenant_modules (tenant_id, module_key, is_active)
    values (NEW.id, 'investor_capital', true)
    on conflict (tenant_id, module_key) do update set is_active = true;

    perform public.seed_tenant_roles_and_grants(NEW.id);
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_auto_enable_investor_capital on public.tenants;
create trigger trg_auto_enable_investor_capital
  after insert on public.tenants
  for each row
  execute function public.auto_enable_investor_capital_for_root_tenant();

commit;
