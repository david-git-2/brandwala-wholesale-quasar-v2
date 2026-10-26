begin;

-- Create thrift_boxes table
create table if not exists public.thrift_boxes (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  name text not null,
  weight numeric(12, 3) null,
  received_weight numeric(12, 3) null,
  inserted_by text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Enable RLS
alter table public.thrift_boxes enable row level security;

-- RLS policies
create policy select_thrift_boxes on public.thrift_boxes for select to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_boxes.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true));

create policy write_thrift_boxes on public.thrift_boxes for all to authenticated
  using (exists (select 1 from public.memberships m where m.tenant_id = thrift_boxes.tenant_id and lower(trim(m.email)) = public.current_user_email() and m.is_active = true and m.role in ('admin', 'staff')));

-- Grants
grant select, insert, update, delete on table public.thrift_boxes to authenticated;
grant usage, select on sequence public.thrift_boxes_id_seq to authenticated;

-- updated_at trigger
create trigger trg_thrift_boxes_updated_at
before update on public.thrift_boxes
for each row execute function public.set_updated_at();

-- Update thrift_stocks table structure
alter table public.thrift_stocks
add column box_id bigint references public.thrift_boxes(id) on delete set null,
add column product_weight numeric(12, 3) null check (product_weight >= 0),
add column extra_weight numeric(12, 3) null check (extra_weight >= 0),
drop column if exists weight_gm;

commit;
