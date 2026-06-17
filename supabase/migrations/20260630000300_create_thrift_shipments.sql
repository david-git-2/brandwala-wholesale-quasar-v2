begin;

-- Create thrift_shipments table
create table if not exists public.thrift_shipments (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  cargo_conversion_rate numeric(12, 4) null,
  cargo_rate numeric(12, 4) null,
  product_conversion_rate numeric(12, 4) null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable RLS
alter table public.thrift_shipments enable row level security;

-- RLS policies
create policy select_thrift_shipments on public.thrift_shipments for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_shipments.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));

create policy write_thrift_shipments on public.thrift_shipments for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_shipments.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Grants
grant select, insert, update, delete on table public.thrift_shipments to authenticated;
grant usage, select on sequence public.thrift_shipments_id_seq to authenticated;

-- updated_at trigger
create trigger trg_thrift_shipments_updated_at
before update on public.thrift_shipments
for each row execute function public.set_updated_at();

-- Redirect thrift_boxes foreign key to thrift_shipments
alter table public.thrift_boxes drop constraint if exists thrift_boxes_shipment_id_fkey;
alter table public.thrift_boxes add constraint thrift_boxes_shipment_id_fkey foreign key (shipment_id) references public.thrift_shipments(id) on delete cascade;

-- Redirect thrift_stocks foreign key to thrift_shipments
alter table public.thrift_stocks drop constraint if exists thrift_stocks_shipment_id_fkey;
alter table public.thrift_stocks add constraint thrift_stocks_shipment_id_fkey foreign key (shipment_id) references public.thrift_shipments(id) on delete cascade;

-- Redirect thrift_stock_settings foreign key to thrift_shipments
alter table public.thrift_stock_settings drop constraint if exists thrift_stock_settings_default_shipment_id_fkey;
alter table public.thrift_stock_settings add constraint thrift_stock_settings_default_shipment_id_fkey foreign key (default_shipment_id) references public.thrift_shipments(id) on delete set null;

commit;
