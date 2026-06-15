-- Migration: Invoice Brand, Boxes and Customization fields

create table if not exists public.invoice_brands (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  address text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, name)
);

create table if not exists public.invoice_boxes (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.invoices(id) on delete cascade,
  box_number text not null,
  weight numeric(10,2) not null check (weight >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (invoice_id, box_number)
);

-- Add customization columns to invoices
alter table public.invoices
  add column if not exists brand_name text null,
  add column if not exists brand_address text null,
  add column if not exists total_boxes integer null,
  add column if not exists delivery_charge numeric(12,2) not null default 0,
  add column if not exists advance_amount numeric(12,2) not null default 0,
  add column if not exists previous_due numeric(12,2) not null default 0,
  add column if not exists thank_you_message text null;

-- Add customization columns to invoice_items
alter table public.invoice_items
  add column if not exists unit text not null default 'pcs',
  add column if not exists rate numeric(12,2) null;

-- Triggers for setting updated_at
drop trigger if exists trg_invoice_brands_set_updated_at on public.invoice_brands;
create trigger trg_invoice_brands_set_updated_at before update on public.invoice_brands
for each row execute function public.set_updated_at();

drop trigger if exists trg_invoice_boxes_set_updated_at on public.invoice_boxes;
create trigger trg_invoice_boxes_set_updated_at before update on public.invoice_boxes
for each row execute function public.set_updated_at();

-- Enable RLS
alter table public.invoice_brands enable row level security;
alter table public.invoice_boxes enable row level security;

-- Brand RLS Policies
drop policy if exists invoice_brands_select on public.invoice_brands;
create policy invoice_brands_select on public.invoice_brands for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_brands.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists invoice_brands_insert on public.invoice_brands;
create policy invoice_brands_insert on public.invoice_brands for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_brands.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists invoice_brands_update on public.invoice_brands;
create policy invoice_brands_update on public.invoice_brands for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_brands.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_brands.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists invoice_brands_delete on public.invoice_brands;
create policy invoice_brands_delete on public.invoice_brands for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_brands.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

-- Box RLS Policies
drop policy if exists invoice_boxes_select on public.invoice_boxes;
create policy invoice_boxes_select on public.invoice_boxes for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists invoice_boxes_insert on public.invoice_boxes;
create policy invoice_boxes_insert on public.invoice_boxes for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists invoice_boxes_update on public.invoice_boxes;
create policy invoice_boxes_update on public.invoice_boxes for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists invoice_boxes_delete on public.invoice_boxes;
create policy invoice_boxes_delete on public.invoice_boxes for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_boxes.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

-- Grants
grant select, insert, update, delete on table public.invoice_brands to authenticated;
grant select, insert, update, delete on table public.invoice_boxes to authenticated;
grant usage, select on sequence public.invoice_brands_id_seq to authenticated;
grant usage, select on sequence public.invoice_boxes_id_seq to authenticated;
