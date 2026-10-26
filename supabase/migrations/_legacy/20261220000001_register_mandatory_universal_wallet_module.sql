-- ====================================================================
-- Migration: Register 'universal_wallet' module in catalog and auto-enable for all tenants
-- ====================================================================

begin;

-- 1. Register 'universal_wallet' core module in public.modules catalog
insert into public.modules (key, name, description, is_active)
values (
  'universal_wallet',
  'Universal Wallet Ledger',
  'Mandatory multi-currency double/single-entry financial ledger system for all tenants.',
  true
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

-- 2. Insert standard module actions into public.module_actions catalog
insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('universal_wallet', 'view', 'app', true, true),
  ('universal_wallet', 'adjust', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true;

-- 3. Auto-enable 'universal_wallet' for all existing tenants in public.tenant_modules
insert into public.tenant_modules (tenant_id, module_key, is_active)
select id, 'universal_wallet', true
from public.tenants
on conflict (tenant_id, module_key) do update
set is_active = true;

-- 4. Create trigger function to automatically assign 'universal_wallet' to any NEW tenant created in the future
create or replace function public.auto_enable_universal_wallet_for_new_tenant()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.tenant_modules (tenant_id, module_key, is_active)
  values (NEW.id, 'universal_wallet', true)
  on conflict (tenant_id, module_key) do update set is_active = true;
  return NEW;
end;
$$;

-- Attach trigger to public.tenants
drop trigger if exists trg_auto_enable_universal_wallet on public.tenants;
create trigger trg_auto_enable_universal_wallet
  after insert on public.tenants
  for each row
  execute function public.auto_enable_universal_wallet_for_new_tenant();

commit;
