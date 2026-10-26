-- Migration: Update commerce_invoices statuses and add custom branding/boxes fields
begin;

-- 1. Update status constraint on commerce_invoices
alter table public.commerce_invoices
  drop constraint if exists commerce_invoice_status_check;

alter table public.commerce_invoices
  add constraint commerce_invoice_status_check
  check (status in ('draft', 'invoicing', 'issued', 'partially_paid', 'paid', 'overdue', 'cancelled'));

-- 2. Add customization/branding columns to commerce_invoices
alter table public.commerce_invoices
  add column if not exists brand_name text null,
  add column if not exists brand_address text null,
  add column if not exists total_boxes integer null,
  add column if not exists advance_amount numeric(12,2) not null default 0,
  add column if not exists previous_due numeric(12,2) not null default 0,
  add column if not exists thank_you_message text null,
  add column if not exists client_name text null,
  add column if not exists client_tr text null;

-- 3. Add unit column to commerce_order_items
alter table public.commerce_order_items
  add column if not exists unit text not null default 'pcs';

-- 4. Create commerce_invoice_boxes table
create table if not exists public.commerce_invoice_boxes (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.commerce_invoices(id) on delete cascade,
  box_number text not null,
  weight numeric(10,2) not null check (weight >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (invoice_id, box_number)
);

-- Triggers for setting updated_at on boxes
drop trigger if exists trg_commerce_invoice_boxes_set_updated_at on public.commerce_invoice_boxes;
create trigger trg_commerce_invoice_boxes_set_updated_at before update on public.commerce_invoice_boxes
for each row execute function public.set_updated_at();

-- Enable RLS on boxes
alter table public.commerce_invoice_boxes enable row level security;

-- RLS policies for boxes
drop policy if exists commerce_invoice_boxes_select on public.commerce_invoice_boxes;
create policy commerce_invoice_boxes_select on public.commerce_invoice_boxes for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists commerce_invoice_boxes_insert on public.commerce_invoice_boxes;
create policy commerce_invoice_boxes_insert on public.commerce_invoice_boxes for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists commerce_invoice_boxes_update on public.commerce_invoice_boxes;
create policy commerce_invoice_boxes_update on public.commerce_invoice_boxes for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists commerce_invoice_boxes_delete on public.commerce_invoice_boxes;
create policy commerce_invoice_boxes_delete on public.commerce_invoice_boxes for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

-- Grants
grant select, insert, update, delete on table public.commerce_invoice_boxes to authenticated;
grant usage, select on sequence public.commerce_invoice_boxes_id_seq to authenticated;

commit;
