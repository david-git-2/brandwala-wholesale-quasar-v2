begin;

-- Drop the broken policies that reference auth.users
drop policy if exists "Users can read retail settings for their tenant" on public.koba_retail_settings;
drop policy if exists "Users can update retail settings for their tenant" on public.koba_retail_settings;

-- Create correct SELECT policy: Any active member of the tenant (or superadmin) can read
create policy "Users can read retail settings for their tenant"
  on public.koba_retail_settings
  for select
  to authenticated
  using (
    public.is_superadmin() or
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.tenant_id = koba_retail_settings.tenant_id
        and m.is_active = true
    )
  );

-- Create correct UPDATE policy: Only tenant admins (or superadmin) can update
create policy "Users can update retail settings for their tenant"
  on public.koba_retail_settings
  for update
  to authenticated
  using (
    public.is_superadmin() or public.is_tenant_admin(tenant_id)
  )
  with check (
    public.is_superadmin() or public.is_tenant_admin(tenant_id)
  );

commit;
