-- Phase 4: products RLS and write triggers follow parent_tenant_id.
-- inserted_by_tenant_id stays audit-only.

create or replace function public.set_products_catalog_parent_tenant_id()
returns trigger
language plpgsql
security definer
set search_path to public
as $$
begin
  if new.parent_tenant_id is not null then
    new.parent_tenant_id := public.resolve_parent_tenant_id(new.parent_tenant_id);
  elsif new.inserted_by_tenant_id is not null then
    new.parent_tenant_id := public.resolve_parent_tenant_id(new.inserted_by_tenant_id);
  elsif new.tenant_id is not null then
    new.parent_tenant_id := public.resolve_parent_tenant_id(new.tenant_id);
  end if;

  return new;
end;
$$;

create or replace function public.can_view_products_for_parent(p_parent_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path to public
as $$
  select
    p_parent_tenant_id is not null
    and (
      public.can_view_products_internal(p_parent_tenant_id)
      or public.can_view_products_customer(p_parent_tenant_id)
      or public.user_can_manage_parent_tenant(p_parent_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_parent_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'view')
      )
      or exists (
        select 1
        from public.customer_group_members cgm
        join public.customer_groups cg on cg.id = cgm.customer_group_id
        join public.tenants t on t.id = cg.tenant_id
        where cgm.is_active = true
          and cg.is_active = true
          and lower(trim(cgm.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_parent_tenant_id
      )
    );
$$;

create or replace function public.can_manage_products_for_parent(p_parent_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path to public
as $$
  select
    p_parent_tenant_id is not null
    and (
      public.can_manage_products(p_parent_tenant_id)
      or exists (
        select 1
        from public.memberships m
        join public.tenants t on t.id = m.tenant_id
        where m.is_active = true
          and lower(trim(m.email)) = public.current_user_email()
          and coalesce(t.parent_id, t.id) = p_parent_tenant_id
          and public.membership_has_module_action(m.tenant_id, 'products', 'edit')
      )
    );
$$;

create or replace function public.sync_product_tenant_from_vendor()
returns trigger
language plpgsql
as $$
declare
  v_tenant_id bigint;
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.tenant_id, v.parent_tenant_id
    into v_tenant_id, v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    elsif v_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_tenant_id);
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_products_set_parent_tenant_id on public.products;

create trigger trg_products_set_parent_tenant_id
before insert or update on public.products
for each row
execute function public.set_products_catalog_parent_tenant_id();

drop policy if exists products_select on public.products;
drop policy if exists products_insert on public.products;
drop policy if exists products_update on public.products;
drop policy if exists products_delete on public.products;

create policy products_select
  on public.products
  for select
  to authenticated
  using (public.can_view_products_for_parent(parent_tenant_id));

create policy products_insert
  on public.products
  for insert
  to authenticated
  with check (public.can_manage_products_for_parent(parent_tenant_id));

create policy products_update
  on public.products
  for update
  to authenticated
  using (public.can_manage_products_for_parent(parent_tenant_id))
  with check (public.can_manage_products_for_parent(parent_tenant_id));

create policy products_delete
  on public.products
  for delete
  to authenticated
  using (public.can_manage_products_for_parent(parent_tenant_id));

grant all on function public.set_products_catalog_parent_tenant_id() to authenticated;
grant all on function public.can_view_products_for_parent(bigint) to authenticated;
grant all on function public.can_manage_products_for_parent(bigint) to authenticated;
