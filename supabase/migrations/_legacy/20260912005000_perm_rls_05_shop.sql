begin;

-- =========================================================
-- Shop admin + customer domain RLS / helper cutover
-- =========================================================

create or replace function public.is_tenant_staff(p_tenant_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and (
        m.role = 'superadmin'::public.app_role
        or m.role = 'admin'::public.app_role
        or public.has_module_action(p_tenant_id, 'shop_order_mgmt', 'view')
      )
  );
$$;

do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'shops'
  ) then
    execute 'drop policy if exists "shops_insert_tenant_admin_staff" on public.shops';
    execute $policy$
      create policy "shops_insert_tenant_admin_staff"
        on public.shops for insert
        with check (public.membership_has_module_action(tenant_id, 'shop_config', 'create'))
    $policy$;

    execute 'drop policy if exists "shops_update_tenant_admin_staff" on public.shops';
    execute $policy$
      create policy "shops_update_tenant_admin_staff"
        on public.shops for update
        using (public.membership_has_module_action(tenant_id, 'shop_config', 'edit'))
    $policy$;

    execute 'drop policy if exists "shops_delete_tenant_admin" on public.shops';
    execute $policy$
      create policy "shops_delete_tenant_admin"
        on public.shops for delete
        using (public.membership_has_module_action(tenant_id, 'shop_config', 'delete'))
    $policy$;
  end if;

  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'shop_customer_group_access'
  ) then
    execute 'drop policy if exists "shop_cg_access_write_tenant_admin_staff" on public.shop_customer_group_access';
    execute $policy$
      create policy "shop_cg_access_write_tenant_admin_staff"
        on public.shop_customer_group_access for all
        using (
          exists (
            select 1 from public.shops s
            where s.id = shop_id
              and public.membership_has_module_action(s.tenant_id, 'shop_permissions', 'configure')
          )
        )
        with check (
          exists (
            select 1 from public.shops s
            where s.id = shop_id
              and public.membership_has_module_action(s.tenant_id, 'shop_permissions', 'configure')
          )
        )
    $policy$;
  end if;
end $$;

commit;
