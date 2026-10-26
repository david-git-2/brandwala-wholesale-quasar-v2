-- Migration: Add global_shipment_boxes table
begin;

create table if not exists public.global_shipment_boxes (
  id bigserial primary key,
  parent_tenant_id bigint not null references public.tenants(id) on delete cascade,
  shipment_id bigint not null references public.global_shipments(id) on delete cascade,
  box_number text not null,
  weight_kg numeric not null check (weight_kg >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shipment_id, box_number)
);

-- Triggers for setting updated_at on boxes
drop trigger if exists trg_global_shipment_boxes_updated_at on public.global_shipment_boxes;
create trigger trg_global_shipment_boxes_updated_at before update on public.global_shipment_boxes
for each row execute function public.set_updated_at();

-- Indexes for performance
create index if not exists global_shipment_boxes_shipment_idx on public.global_shipment_boxes(shipment_id);
create index if not exists global_shipment_boxes_parent_tenant_idx on public.global_shipment_boxes(parent_tenant_id);

-- Enable RLS
alter table public.global_shipment_boxes enable row level security;

-- RLS policies for global_shipment_boxes
drop policy if exists global_shipment_boxes_select on public.global_shipment_boxes;
create policy global_shipment_boxes_select on public.global_shipment_boxes for select to authenticated using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
  or exists (
    select 1
    from public.memberships m
    where m.tenant_id = global_shipment_boxes.parent_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists global_shipment_boxes_all on public.global_shipment_boxes;
create policy global_shipment_boxes_all on public.global_shipment_boxes for all to authenticated using (
  public.user_can_manage_parent_tenant(parent_tenant_id)
) with check (
  public.user_can_manage_parent_tenant(parent_tenant_id)
);

-- Grants
grant select, insert, update, delete on table public.global_shipment_boxes to authenticated;
grant usage, select on sequence public.global_shipment_boxes_id_seq to authenticated;

commit;
