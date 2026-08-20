-- ====================================================================
-- Migration: Revoke Customer Group access management from shop_order
-- and enforce customer module governance.
-- ====================================================================

begin;

-- 1. Update customer_groups RLS policies to use 'customer' module permissions
create or replace function public.can_manage_customer_group(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
    or public.membership_has_module_action(p_tenant_id, 'customer', 'edit')
    or public.membership_has_module_action(p_tenant_id, 'customer', 'create');
$$;

-- 2. Update description of 'shop_permissions' to clarify it only controls per-shop access flags
update public.modules
set
  name = 'Shop Permissions',
  description = 'Per-shop customer access matrix and storefront capability flags.'
where key = 'shop_permissions';

commit;
