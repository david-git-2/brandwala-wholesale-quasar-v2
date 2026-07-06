begin;

-- =========================================================
-- Verticals: products, vendor helpers, thrift, koba, tasks gate
-- =========================================================

create or replace function public.can_manage_products(p_tenant_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or public.membership_has_module_action(p_tenant_id, 'products', 'edit');
$$;

create or replace function public.can_view_products_internal(p_tenant_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or public.membership_has_module_action(p_tenant_id, 'products', 'view');
$$;

-- Thrift write policies (skip tables absent on this tenant DB)
do $$
begin
  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_categories') then
    execute 'drop policy if exists write_thrift_categories on public.thrift_categories';
    execute $p$ create policy write_thrift_categories on public.thrift_categories for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_category', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_types') then
    execute 'drop policy if exists write_thrift_types on public.thrift_types';
    execute $p$ create policy write_thrift_types on public.thrift_types for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_type', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_shelves') then
    execute 'drop policy if exists write_thrift_shelves on public.thrift_shelves';
    execute $p$ create policy write_thrift_shelves on public.thrift_shelves for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_shelf', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_stocks') then
    execute 'drop policy if exists write_thrift_stocks on public.thrift_stocks';
    execute $p$ create policy write_thrift_stocks on public.thrift_stocks for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_stock', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_stock_images') then
    execute 'drop policy if exists write_thrift_stock_images on public.thrift_stock_images';
    execute $p$
      create policy write_thrift_stock_images on public.thrift_stock_images
      for all to authenticated
      using (
        exists (
          select 1 from public.thrift_stocks s
          where s.id = thrift_stock_images.stock_id
            and public.membership_has_module_action(s.tenant_id, 'thrift_stock', 'edit')
        )
      )
    $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_pricings') then
    execute 'drop policy if exists write_thrift_pricings on public.thrift_pricings';
    execute $p$
      create policy write_thrift_pricings on public.thrift_pricings
      for all to authenticated
      using (
        exists (
          select 1 from public.thrift_stocks s
          where s.id = thrift_pricings.stock_id
            and public.membership_has_module_action(s.tenant_id, 'thrift_stock', 'edit')
        )
      )
    $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_boxes') then
    execute 'drop policy if exists write_thrift_boxes on public.thrift_boxes';
    execute $p$ create policy write_thrift_boxes on public.thrift_boxes for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_box', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_shipments') then
    execute 'drop policy if exists write_thrift_shipments on public.thrift_shipments';
    execute $p$ create policy write_thrift_shipments on public.thrift_shipments for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_shipment', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_stock_measurements') then
    execute 'drop policy if exists write_thrift_stock_measurements on public.thrift_stock_measurements';
    execute $p$ create policy write_thrift_stock_measurements on public.thrift_stock_measurements for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_stock', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_stock_settings') then
    execute 'drop policy if exists write_thrift_stock_settings on public.thrift_stock_settings';
    execute $p$ create policy write_thrift_stock_settings on public.thrift_stock_settings for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_settings', 'edit')) $p$;
  end if;

  if exists (select 1 from information_schema.tables where table_schema = 'public' and table_name = 'thrift_barcodes') then
    execute 'drop policy if exists write_thrift_barcodes on public.thrift_barcodes';
    execute $p$ create policy write_thrift_barcodes on public.thrift_barcodes for all to authenticated using (public.membership_has_module_action(tenant_id, 'thrift_barcode', 'edit')) $p$;
  end if;
end $$;

-- Tasks: root-level item create requires tasks.create grant
do $$
begin
  if exists (
    select 1 from information_schema.tables
    where table_schema = 'public' and table_name = 'items'
  ) then
    execute 'drop policy if exists items_insert on public.items';
    execute $policy$
      create policy items_insert on public.items
      for insert to authenticated
      with check (
        (
          parent_id is null
          and (
            tenant_id is null
            or (
              public.has_active_tenant_membership(tenant_id)
              and public.membership_has_module_action(tenant_id, 'tasks', 'create')
            )
          )
        )
        or (
          parent_id is not null
          and public.get_effective_item_role(parent_id, public.current_user_email()) in ('owner', 'manager', 'editor')
        )
      )
    $policy$;
  end if;
end $$;

commit;
