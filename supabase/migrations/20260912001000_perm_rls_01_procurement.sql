begin;

-- =========================================================
-- Procurement + stock: replace enum role checks with grants
-- =========================================================

-- business_parties (vendor module)
drop policy if exists business_parties_write on public.business_parties;
create policy business_parties_write on public.business_parties
for all to authenticated
using (public.membership_has_module_action(business_parties.tenant_id, 'vendor', 'edit'))
with check (public.membership_has_module_action(business_parties.tenant_id, 'vendor', 'edit'));

-- Legacy inventory tables (dropped in B7 — skip when absent)
do $$
begin
  if not exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'inventory_items'
  ) then
    return;
  end if;

  execute 'drop policy if exists inventory_items_insert on public.inventory_items';
  execute $policy$
    create policy inventory_items_insert on public.inventory_items
    for insert to authenticated
    with check (public.membership_has_module_action(tenant_id, 'inventory', 'allocate'))
  $policy$;

  execute 'drop policy if exists inventory_items_update on public.inventory_items';
  execute $policy$
    create policy inventory_items_update on public.inventory_items
    for update to authenticated
    using (public.membership_has_module_action(tenant_id, 'inventory', 'allocate'))
    with check (public.membership_has_module_action(tenant_id, 'inventory', 'allocate'))
  $policy$;

  execute 'drop policy if exists inventory_items_delete on public.inventory_items';
  execute $policy$
    create policy inventory_items_delete on public.inventory_items
    for delete to authenticated
    using (public.membership_has_module_action(tenant_id, 'inventory', 'allocate'))
  $policy$;

  execute 'drop policy if exists inventory_stocks_insert on public.inventory_stocks';
  execute $policy$
    create policy inventory_stocks_insert on public.inventory_stocks
    for insert to authenticated
    with check (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_stocks.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
  $policy$;

  execute 'drop policy if exists inventory_stocks_update on public.inventory_stocks';
  execute $policy$
    create policy inventory_stocks_update on public.inventory_stocks
    for update to authenticated
    using (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_stocks.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
    with check (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_stocks.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
  $policy$;

  execute 'drop policy if exists inventory_stocks_delete on public.inventory_stocks';
  execute $policy$
    create policy inventory_stocks_delete on public.inventory_stocks
    for delete to authenticated
    using (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_stocks.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
  $policy$;

  execute 'drop policy if exists inventory_movements_insert on public.inventory_movements';
  execute $policy$
    create policy inventory_movements_insert on public.inventory_movements
    for insert to authenticated
    with check (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_movements.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
  $policy$;

  execute 'drop policy if exists inventory_movements_update on public.inventory_movements';
  execute $policy$
    create policy inventory_movements_update on public.inventory_movements
    for update to authenticated
    using (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_movements.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
    with check (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_movements.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
  $policy$;

  execute 'drop policy if exists inventory_movements_delete on public.inventory_movements';
  execute $policy$
    create policy inventory_movements_delete on public.inventory_movements
    for delete to authenticated
    using (
      exists (
        select 1 from public.inventory_items ii
        where ii.id = inventory_movements.inventory_item_id
          and public.membership_has_module_action(ii.tenant_id, 'inventory', 'allocate')
      )
    )
  $policy$;
end $$;

-- global_shipment_boxes
drop policy if exists global_shipment_boxes_all on public.global_shipment_boxes;
create policy global_shipment_boxes_all on public.global_shipment_boxes
for all to authenticated
using (public.user_can_manage_parent_tenant(parent_tenant_id))
with check (public.user_can_manage_parent_tenant(parent_tenant_id));

commit;
