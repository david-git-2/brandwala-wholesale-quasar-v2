-- Migration: 20270916000100_invoice_brands_parent_tenant_id.sql
-- Change invoice_brands tenant_id to parent_tenant_id and update RLS/constraints

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'invoice_brands'
      and column_name = 'tenant_id'
  ) then
    alter table public.invoice_brands rename column tenant_id to parent_tenant_id;
  end if;
end $$;

alter table public.invoice_brands
  alter column parent_tenant_id set not null;

alter table public.invoice_brands drop constraint if exists invoice_brands_tenant_id_fkey;
alter table public.invoice_brands drop constraint if exists invoice_brands_tenant_id_name_key;
drop index if exists public.invoice_brands_tenant_id_idx;

alter table public.invoice_brands drop constraint if exists invoice_brands_parent_tenant_id_fkey;
alter table public.invoice_brands
  add constraint invoice_brands_parent_tenant_id_fkey
  foreign key (parent_tenant_id) references public.tenants(id) on delete cascade;

alter table public.invoice_brands drop constraint if exists invoice_brands_parent_tenant_id_name_key;
alter table public.invoice_brands
  add constraint invoice_brands_parent_tenant_id_name_key
  unique (parent_tenant_id, name);

create index if not exists invoice_brands_parent_tenant_id_idx
  on public.invoice_brands(parent_tenant_id);

-- Refresh RLS Policies
drop policy if exists invoice_brands_select on public.invoice_brands;
drop policy if exists invoice_brands_insert on public.invoice_brands;
drop policy if exists invoice_brands_update on public.invoice_brands;
drop policy if exists invoice_brands_delete on public.invoice_brands;
drop policy if exists invoice_brands_write on public.invoice_brands;

create policy invoice_brands_select on public.invoice_brands
  for select to authenticated using (
    public.has_active_tenant_membership(parent_tenant_id)
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  );

create policy invoice_brands_insert on public.invoice_brands
  for insert to authenticated with check (
    public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text)
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  );

create policy invoice_brands_update on public.invoice_brands
  for update to authenticated using (
    public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text)
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  ) with check (
    public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text)
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  );

create policy invoice_brands_delete on public.invoice_brands
  for delete to authenticated using (
    public.membership_has_module_action(parent_tenant_id, 'invoice_brand'::text, 'edit'::text)
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  );
