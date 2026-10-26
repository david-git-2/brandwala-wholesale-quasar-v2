-- Migration: Drop redundant tenant_id from sales_invoices, sales_invoice_items, and sales_return_items.
-- Documented in doc/sales_invoice/invoice/schema.md §0 and §3.
-- Invoices are owned by parent_tenant_id (books/stock owner) with issued_by_tenant_id (selling child branch).

begin;

-- ============================================================================
-- 1. Drop dependent policies and compatibility views FIRST (avoids SQLSTATE 2BP01)
-- ============================================================================
drop policy if exists "global_invoices_select" on public.sales_invoices;
drop policy if exists "global_invoices_write" on public.sales_invoices;
drop policy if exists "global_invoice_items_all" on public.sales_invoice_items;
drop policy if exists "global_return_items_all" on public.sales_return_items;

drop view if exists public.global_invoices cascade;
drop view if exists public.global_invoice_items cascade;
drop view if exists public.global_return_items cascade;

-- ============================================================================
-- 2. Drop trigger aliases & triggers referencing tenant_id
-- ============================================================================
drop trigger if exists trg_global_invoices_parent_tenant_alias on public.sales_invoices;
drop trigger if exists trg_global_invoice_items_parent_tenant_alias on public.sales_invoice_items;
drop trigger if exists trg_global_return_items_parent_tenant_alias on public.sales_return_items;
drop function if exists public.trg_invoice_parent_tenant_alias() cascade;

-- ============================================================================
-- 3. Update Foreign Key constraints & Unique constraints
-- ============================================================================
-- sales_invoices
alter table public.sales_invoices
  drop constraint if exists global_invoices_tenant_id_fkey,
  drop constraint if exists global_invoices_tenant_id_invoice_no_key;

drop index if exists public.global_invoices_tenant_id_idx;
drop index if exists public.idx_global_invoices_scoping;

-- Ensure unique (parent_tenant_id, invoice_no) constraint per canonical schema
alter table public.sales_invoices
  add constraint sales_invoices_parent_tenant_id_invoice_no_key unique (parent_tenant_id, invoice_no);

create index if not exists idx_sales_invoices_scoping
  on public.sales_invoices (parent_tenant_id, issued_by_tenant_id, invoice_status, invoice_date);

-- sales_invoice_items
alter table public.sales_invoice_items
  drop constraint if exists global_invoice_items_tenant_id_fkey;

-- sales_return_items
alter table public.sales_return_items
  drop constraint if exists global_return_items_tenant_id_fkey;

-- ============================================================================
-- 4. Drop tenant_id columns
-- ============================================================================
alter table public.sales_invoices
  drop column if exists tenant_id;

alter table public.sales_invoice_items
  drop column if exists tenant_id;

alter table public.sales_return_items
  drop column if exists tenant_id;

-- ============================================================================
-- 5. Recreate Compatibility Views
-- ============================================================================
create or replace view public.global_invoices with (security_invoker = false) as
  select
    id,
    parent_tenant_id,
    parent_tenant_id as tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    fulfillment_status,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    due_date,
    payment_status,
    total_amount,
    due_amount,
    paid_amount,
    subtotal_amount,
    discount_amount,
    shipping_charge,
    wrapping_charge,
    print_charge,
    note,
    created_by,
    created_at,
    updated_at,
    settlement_discount_amount
  from public.sales_invoices;

alter view public.global_invoices owner to postgres;

create or replace view public.global_invoice_items with (security_invoker = false) as
  select
    id,
    parent_tenant_id,
    parent_tenant_id as tenant_id,
    invoice_id,
    global_stock_id,
    shipment_item_id,
    product_id,
    name_snapshot,
    barcode_snapshot,
    product_code_snapshot,
    quantity,
    unit_cost_price,
    sell_price_amount,
    line_discount_amount,
    line_total_amount,
    return_quantity,
    created_at,
    updated_at,
    assigned_child_tenant_id
  from public.sales_invoice_items;

alter view public.global_invoice_items owner to postgres;

create or replace view public.global_return_items with (security_invoker = false) as
  select
    id,
    parent_tenant_id,
    parent_tenant_id as tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
    return_charge_amount,
    note,
    created_at,
    updated_at
  from public.sales_return_items;

alter view public.global_return_items owner to postgres;

-- ============================================================================
-- 6. Recreate RLS Policies
-- ============================================================================
create policy "global_invoices_select" on public.sales_invoices
  for select to authenticated
  using (
    public.has_active_tenant_membership(issued_by_tenant_id)
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  );

create policy "global_invoices_write" on public.sales_invoices
  for all to authenticated
  using (
    public.membership_has_module_action(issued_by_tenant_id, 'global_invoice', 'edit')
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  )
  with check (
    public.membership_has_module_action(issued_by_tenant_id, 'global_invoice', 'edit')
    or public.user_can_manage_parent_tenant(parent_tenant_id)
  );

create policy "global_invoice_items_all" on public.sales_invoice_items
  to authenticated
  using (
    exists (
      select 1 from public.sales_invoices gi
      where gi.id = sales_invoice_items.invoice_id
    )
  )
  with check (
    exists (
      select 1 from public.sales_invoices gi
      where gi.id = sales_invoice_items.invoice_id
    )
  );

create policy "global_return_items_all" on public.sales_return_items
  to authenticated
  using (
    exists (
      select 1 from public.sales_invoices gi
      where gi.id = sales_return_items.invoice_id
    )
  )
  with check (
    exists (
      select 1 from public.sales_invoices gi
      where gi.id = sales_return_items.invoice_id
    )
  );

-- Update comment
comment on table public.sales_invoices is 'Sales invoices. parent_tenant_id = parent books/stock, issued_by_tenant_id = selling child.';

commit;
