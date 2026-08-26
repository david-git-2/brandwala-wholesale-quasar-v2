-- Enable RLS on costing_file_viewers (policies already exist) and courier_services.

begin;

alter table public.costing_file_viewers enable row level security;

alter table public.courier_services enable row level security;

drop policy if exists courier_services_select_policy on public.courier_services;
create policy courier_services_select_policy
  on public.courier_services
  for select
  to authenticated
  using (
    tenant_id is null
    or public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = courier_services.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

drop policy if exists courier_services_insert_policy on public.courier_services;
create policy courier_services_insert_policy
  on public.courier_services
  for insert
  to authenticated
  with check (
    public.is_superadmin()
    or (
      public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping', 'configure')
      and (tenant_id is null or tenant_id = public.current_tenant_id())
    )
  );

drop policy if exists courier_services_update_policy on public.courier_services;
create policy courier_services_update_policy
  on public.courier_services
  for update
  to authenticated
  using (
    public.is_superadmin()
    or (
      public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping', 'configure')
      and (tenant_id is null or tenant_id = public.current_tenant_id())
    )
  )
  with check (
    public.is_superadmin()
    or (
      public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping', 'configure')
      and (tenant_id is null or tenant_id = public.current_tenant_id())
    )
  );

drop policy if exists courier_services_delete_policy on public.courier_services;
create policy courier_services_delete_policy
  on public.courier_services
  for delete
  to authenticated
  using (
    public.is_superadmin()
    or (
      public.membership_has_module_action(public.current_tenant_id(), 'shop_shipping', 'configure')
      and (tenant_id is null or tenant_id = public.current_tenant_id())
    )
  );

commit;
