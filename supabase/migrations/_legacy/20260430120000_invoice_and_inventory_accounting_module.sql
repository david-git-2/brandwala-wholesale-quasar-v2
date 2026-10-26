create table if not exists public.invoices (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_no text not null,
  source_type text not null check (source_type in ('order', 'product_based_costing_file')),
  source_id bigint not null,
  payment_status text not null default 'due' check (payment_status in ('due', 'partially_paid', 'paid')),
  invoice_date date not null default current_date,
  due_date date null,
  subtotal_amount numeric(12,2) not null default 0 check (subtotal_amount >= 0),
  discount_amount numeric(12,2) not null default 0 check (discount_amount >= 0),
  total_amount numeric(12,2) not null default 0 check (total_amount >= 0),
  paid_amount numeric(12,2) not null default 0 check (paid_amount >= 0),
  note text null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tenant_id, invoice_no)
);

create table if not exists public.invoice_items (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint not null references public.invoices(id) on delete cascade,
  source_item_type text not null check (source_item_type in ('order_item', 'product_based_costing_item')),
  source_item_id bigint not null,
  inventory_item_id bigint null references public.inventory_items(id) on delete set null,
  product_id bigint null references public.products(id) on delete set null,
  name_snapshot text not null,
  barcode_snapshot text null,
  product_code_snapshot text null,
  quantity numeric(12,3) not null check (quantity > 0),
  cost_amount numeric(12,2) not null default 0 check (cost_amount >= 0),
  sell_price_amount numeric(12,2) not null default 0 check (sell_price_amount >= 0),
  line_discount_amount numeric(12,2) not null default 0 check (line_discount_amount >= 0),
  line_tax_amount numeric(12,2) not null default 0 check (line_tax_amount >= 0),
  line_total_amount numeric(12,2) not null default 0 check (line_total_amount >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_accounting_entries (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  invoice_id bigint null references public.invoices(id) on delete set null,
  invoice_item_id bigint null references public.invoice_items(id) on delete set null,
  inventory_item_id bigint not null references public.inventory_items(id) on delete cascade,
  product_id bigint null references public.products(id) on delete set null,
  quantity numeric(12,3) not null check (quantity > 0),
  cost_amount numeric(12,2) not null default 0 check (cost_amount >= 0),
  sell_price_amount numeric(12,2) not null default 0 check (sell_price_amount >= 0),
  total_cost_amount numeric(12,2) not null default 0 check (total_cost_amount >= 0),
  total_sell_amount numeric(12,2) not null default 0 check (total_sell_amount >= 0),
  gross_profit_amount numeric(12,2) not null default 0,
  status text not null default 'due' check (status in ('due', 'paid')),
  entry_date date not null default current_date,
  note text null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.invoice_accounting_payments (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  inventory_accounting_entry_id bigint not null references public.inventory_accounting_entries(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  payment_date date not null default current_date,
  payment_method text null check (payment_method in ('cash', 'bank', 'mobile_banking', 'other') or payment_method is null),
  reference_no text null,
  note text null,
  created_by uuid null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists invoices_tenant_id_idx on public.invoices (tenant_id);
create index if not exists invoices_payment_status_idx on public.invoices (tenant_id, payment_status);
create index if not exists invoice_items_tenant_id_idx on public.invoice_items (tenant_id);
create index if not exists invoice_items_invoice_id_idx on public.invoice_items (invoice_id);
create index if not exists inventory_accounting_entries_tenant_id_idx on public.inventory_accounting_entries (tenant_id);
create index if not exists inventory_accounting_entries_inventory_item_id_idx on public.inventory_accounting_entries (inventory_item_id);
create index if not exists invoice_accounting_payments_tenant_id_idx on public.invoice_accounting_payments (tenant_id);

drop trigger if exists trg_invoices_set_updated_at on public.invoices;
create trigger trg_invoices_set_updated_at before update on public.invoices
for each row execute function public.set_updated_at();
drop trigger if exists trg_invoice_items_set_updated_at on public.invoice_items;
create trigger trg_invoice_items_set_updated_at before update on public.invoice_items
for each row execute function public.set_updated_at();
drop trigger if exists trg_inventory_accounting_entries_set_updated_at on public.inventory_accounting_entries;
create trigger trg_inventory_accounting_entries_set_updated_at before update on public.inventory_accounting_entries
for each row execute function public.set_updated_at();
drop trigger if exists trg_invoice_accounting_payments_set_updated_at on public.invoice_accounting_payments;
create trigger trg_invoice_accounting_payments_set_updated_at before update on public.invoice_accounting_payments
for each row execute function public.set_updated_at();

alter table public.invoices enable row level security;
alter table public.invoice_items enable row level security;
alter table public.inventory_accounting_entries enable row level security;
alter table public.invoice_accounting_payments enable row level security;

drop policy if exists invoices_select on public.invoices;
create policy invoices_select on public.invoices for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);
drop policy if exists invoices_insert on public.invoices;
create policy invoices_insert on public.invoices for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists invoices_update on public.invoices;
create policy invoices_update on public.invoices for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists invoices_delete on public.invoices;
create policy invoices_delete on public.invoices for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoices.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists invoice_items_select on public.invoice_items;
create policy invoice_items_select on public.invoice_items for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);
drop policy if exists invoice_items_insert on public.invoice_items;
create policy invoice_items_insert on public.invoice_items for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists invoice_items_update on public.invoice_items;
create policy invoice_items_update on public.invoice_items for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists invoice_items_delete on public.invoice_items;
create policy invoice_items_delete on public.invoice_items for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_items.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists iae_select on public.inventory_accounting_entries;
create policy iae_select on public.inventory_accounting_entries for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_accounting_entries.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);
drop policy if exists iae_insert on public.inventory_accounting_entries;
create policy iae_insert on public.inventory_accounting_entries for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_accounting_entries.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists iae_update on public.inventory_accounting_entries;
create policy iae_update on public.inventory_accounting_entries for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_accounting_entries.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_accounting_entries.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists iae_delete on public.inventory_accounting_entries;
create policy iae_delete on public.inventory_accounting_entries for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = inventory_accounting_entries.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists iap_select on public.invoice_accounting_payments;
create policy iap_select on public.invoice_accounting_payments for select to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_accounting_payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);
drop policy if exists iap_insert on public.invoice_accounting_payments;
create policy iap_insert on public.invoice_accounting_payments for insert to authenticated with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_accounting_payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists iap_update on public.invoice_accounting_payments;
create policy iap_update on public.invoice_accounting_payments for update to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_accounting_payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
) with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_accounting_payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);
drop policy if exists iap_delete on public.invoice_accounting_payments;
create policy iap_delete on public.invoice_accounting_payments for delete to authenticated using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = invoice_accounting_payments.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

grant select, insert, update, delete on table public.invoices to authenticated;
grant select, insert, update, delete on table public.invoice_items to authenticated;
grant select, insert, update, delete on table public.inventory_accounting_entries to authenticated;
grant select, insert, update, delete on table public.invoice_accounting_payments to authenticated;

grant usage, select on sequence public.invoices_id_seq to authenticated;
grant usage, select on sequence public.invoice_items_id_seq to authenticated;
grant usage, select on sequence public.inventory_accounting_entries_id_seq to authenticated;
grant usage, select on sequence public.invoice_accounting_payments_id_seq to authenticated;
