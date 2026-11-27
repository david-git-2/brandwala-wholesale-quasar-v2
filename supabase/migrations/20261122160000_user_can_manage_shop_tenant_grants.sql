-- upsert_shop and other shop RPCs gate on user_can_manage_shop_tenant, which still
-- required legacy memberships.role in ('admin','staff'). Shop RLS uses shop_config grants.

CREATE OR REPLACE FUNCTION public.user_can_manage_shop_tenant(p_tenant_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  select
    p_tenant_id is not null
    and (
      public.is_superadmin()
      or public.membership_has_module_action(p_tenant_id, 'shop_config', 'edit')
      or public.membership_has_module_action(p_tenant_id, 'shop_config', 'create')
      or public.membership_has_module_action(
        public.resolve_books_tenant_id(p_tenant_id),
        'shop_config',
        'edit'
      )
      or public.membership_has_module_action(
        public.resolve_books_tenant_id(p_tenant_id),
        'shop_config',
        'create'
      )
    );
$$;