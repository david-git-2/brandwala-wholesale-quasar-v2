-- Update RLS policy for costing_files update to allow both admin and staff
drop policy if exists "costing_files_update" on public.costing_files;

create policy "costing_files_update"
on public.costing_files
for update
to authenticated
using (
  public.can_admin_manage_costing_file(tenant_id)
  or public.can_staff_access_costing_file(tenant_id)
)
with check (
  public.can_admin_manage_costing_file(tenant_id)
  or public.can_staff_access_costing_file(tenant_id)
);
