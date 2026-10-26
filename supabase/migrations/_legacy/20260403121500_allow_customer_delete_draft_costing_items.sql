drop policy if exists "costing_file_items_delete" on public.costing_file_items;

create policy "costing_file_items_delete"
on public.costing_file_items
for delete
to authenticated
using (
  exists (
    select 1
    from public.costing_files cf
    where cf.id = costing_file_id
      and (
        public.can_admin_manage_costing_file(cf.tenant_id)
        or (
          cf.status = 'draft'
          and public.can_customer_access_costing_file(cf.customer_group_id)
        )
      )
  )
);
