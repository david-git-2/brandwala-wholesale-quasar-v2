-- =========================================================
-- thrift_shipment details fine-grained actions rename
-- view_cost/edit_price/edit_quantity → clear details keys
-- =========================================================

begin;

-- 1. Seed new module actions
insert into public.module_actions (module_key, action, scope, tenant_configurable, is_active)
values
  ('thrift_shipment', 'view_landed_cost', 'app', true, true),
  ('thrift_shipment', 'edit_landed_cost', 'app', true, true),
  ('thrift_shipment', 'view_measurements', 'app', true, true),
  ('thrift_shipment', 'edit_measurements', 'app', true, true),
  ('thrift_shipment', 'edit_listed_price', 'app', true, true)
on conflict (module_key, action, scope) do update set
  is_active = true,
  tenant_configurable = true;

-- 2. Migrate tenant_role_grants (behavior-preserving)
-- view_cost → view_landed_cost + edit_landed_cost
insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
select tenant_role_id, 'thrift_shipment', 'view_landed_cost', allowed
from public.tenant_role_grants
where module_key = 'thrift_shipment' and action = 'view_cost'
on conflict (tenant_role_id, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
select tenant_role_id, 'thrift_shipment', 'edit_landed_cost', allowed
from public.tenant_role_grants
where module_key = 'thrift_shipment' and action = 'view_cost'
on conflict (tenant_role_id, module_key, action) do update set
  allowed = excluded.allowed;

-- edit_price → edit_listed_price
insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
select tenant_role_id, 'thrift_shipment', 'edit_listed_price', allowed
from public.tenant_role_grants
where module_key = 'thrift_shipment' and action = 'edit_price'
on conflict (tenant_role_id, module_key, action) do update set
  allowed = excluded.allowed;

-- edit_quantity → view_measurements + edit_measurements
insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
select tenant_role_id, 'thrift_shipment', 'view_measurements', allowed
from public.tenant_role_grants
where module_key = 'thrift_shipment' and action = 'edit_quantity'
on conflict (tenant_role_id, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.tenant_role_grants (tenant_role_id, module_key, action, allowed)
select tenant_role_id, 'thrift_shipment', 'edit_measurements', allowed
from public.tenant_role_grants
where module_key = 'thrift_shipment' and action = 'edit_quantity'
on conflict (tenant_role_id, module_key, action) do update set
  allowed = excluded.allowed;

-- 3. Migrate membership_grants the same way
insert into public.membership_grants (membership_id, module_key, action, effect)
select membership_id, 'thrift_shipment', 'view_landed_cost', effect
from public.membership_grants
where module_key = 'thrift_shipment' and action = 'view_cost'
on conflict (membership_id, module_key, action) do update set
  effect = excluded.effect;

insert into public.membership_grants (membership_id, module_key, action, effect)
select membership_id, 'thrift_shipment', 'edit_landed_cost', effect
from public.membership_grants
where module_key = 'thrift_shipment' and action = 'view_cost'
on conflict (membership_id, module_key, action) do update set
  effect = excluded.effect;

insert into public.membership_grants (membership_id, module_key, action, effect)
select membership_id, 'thrift_shipment', 'edit_listed_price', effect
from public.membership_grants
where module_key = 'thrift_shipment' and action = 'edit_price'
on conflict (membership_id, module_key, action) do update set
  effect = excluded.effect;

insert into public.membership_grants (membership_id, module_key, action, effect)
select membership_id, 'thrift_shipment', 'view_measurements', effect
from public.membership_grants
where module_key = 'thrift_shipment' and action = 'edit_quantity'
on conflict (membership_id, module_key, action) do update set
  effect = excluded.effect;

insert into public.membership_grants (membership_id, module_key, action, effect)
select membership_id, 'thrift_shipment', 'edit_measurements', effect
from public.membership_grants
where module_key = 'thrift_shipment' and action = 'edit_quantity'
on conflict (membership_id, module_key, action) do update set
  effect = excluded.effect;

-- 4. Update system_role_templates
insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
select scope, role_slug, 'thrift_shipment', 'view_landed_cost', allowed
from public.system_role_templates
where module_key = 'thrift_shipment' and action = 'view_cost'
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
select scope, role_slug, 'thrift_shipment', 'edit_landed_cost', allowed
from public.system_role_templates
where module_key = 'thrift_shipment' and action = 'view_cost'
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
select scope, role_slug, 'thrift_shipment', 'edit_listed_price', allowed
from public.system_role_templates
where module_key = 'thrift_shipment' and action = 'edit_price'
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
select scope, role_slug, 'thrift_shipment', 'view_measurements', allowed
from public.system_role_templates
where module_key = 'thrift_shipment' and action = 'edit_quantity'
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
select scope, role_slug, 'thrift_shipment', 'edit_measurements', allowed
from public.system_role_templates
where module_key = 'thrift_shipment' and action = 'edit_quantity'
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Staff defaults if no prior edit_quantity template row
insert into public.system_role_templates (scope, role_slug, module_key, action, allowed)
values
  ('app', 'staff', 'thrift_shipment', 'view_measurements', true),
  ('app', 'staff', 'thrift_shipment', 'edit_measurements', true)
on conflict (scope, role_slug, module_key, action) do update set
  allowed = excluded.allowed;

-- Remove obsolete thrift_shipment template rows
delete from public.system_role_templates
where module_key = 'thrift_shipment'
  and action in ('view_cost', 'edit_price', 'edit_quantity');

-- 5. Remove obsolete grant rows, deactivate old module actions
delete from public.tenant_role_grants
where module_key = 'thrift_shipment'
  and action in ('view_cost', 'edit_price', 'edit_quantity');

delete from public.membership_grants
where module_key = 'thrift_shipment'
  and action in ('view_cost', 'edit_price', 'edit_quantity');

update public.module_actions
set is_active = false
where module_key = 'thrift_shipment'
  and action in ('view_cost', 'edit_price', 'edit_quantity');

-- 6. Backfill from templates for tenants missing the new grants
select public.seed_tenant_roles_and_grants(id) from public.tenants;

commit;
