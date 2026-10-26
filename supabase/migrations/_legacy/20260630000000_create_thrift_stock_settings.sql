begin;

-- Create thrift_stock_settings table
create table if not exists public.thrift_stock_settings (
  tenant_id bigint primary key,
  default_shipment_id bigint references public.shipments(id) on delete set null,
  default_box_id bigint references public.thrift_boxes(id) on delete set null,
  default_purchase_price numeric(12, 2) not null default 0.00 check (default_purchase_price >= 0),
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint thrift_stock_settings_tenant_id_fkey
    foreign key (tenant_id)
    references public.tenants (id)
    on delete cascade
);

-- Enable RLS
alter table public.thrift_stock_settings enable row level security;

-- Policies
create policy select_thrift_stock_settings on public.thrift_stock_settings for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_stock_settings.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));

create policy write_thrift_stock_settings on public.thrift_stock_settings for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_stock_settings.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Grant privileges
grant select, insert, update, delete on table public.thrift_stock_settings to authenticated;

-- Function/Trigger for updated_at
create trigger trg_thrift_stock_settings_updated_at
before update on public.thrift_stock_settings
for each row
execute function public.set_updated_at();

commit;
