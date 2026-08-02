-- =========================================================
-- Remove unused thrift_stock actions (never wired in UI/RLS).
-- Keep only: view, create, edit, delete
-- =========================================================

begin;

delete from public.system_role_templates
where module_key = 'thrift_stock'
  and action in ('receive', 'edit_price', 'edit_quantity', 'view_cost');

delete from public.tenant_role_grants
where module_key = 'thrift_stock'
  and action in ('receive', 'edit_price', 'edit_quantity', 'view_cost');

delete from public.membership_grants
where module_key = 'thrift_stock'
  and action in ('receive', 'edit_price', 'edit_quantity', 'view_cost');

update public.module_actions
set is_active = false
where module_key = 'thrift_stock'
  and action in ('receive', 'edit_price', 'edit_quantity', 'view_cost');

commit;
