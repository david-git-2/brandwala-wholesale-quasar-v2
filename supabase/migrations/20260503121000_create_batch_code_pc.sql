begin;

create table if not exists public.batch_code_pc (
  id bigserial primary key,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  shipment_item_id bigint not null references public.shipment_items(id) on delete cascade,
  product_code text null,
  batch_id text null,
  manufacturing_date date null,
  expire_date date null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists batch_code_pc_shipment_id_idx
  on public.batch_code_pc (shipment_id);

create index if not exists batch_code_pc_shipment_item_id_idx
  on public.batch_code_pc (shipment_item_id);

create index if not exists batch_code_pc_product_code_idx
  on public.batch_code_pc (product_code);

create index if not exists batch_code_pc_batch_id_idx
  on public.batch_code_pc (batch_id);

drop trigger if exists trg_batch_code_pc_set_updated_at on public.batch_code_pc;
create trigger trg_batch_code_pc_set_updated_at
before update on public.batch_code_pc
for each row
execute function public.set_updated_at();

grant select, insert, update, delete
on public.batch_code_pc
to authenticated;

grant usage, select
on sequence public.batch_code_pc_id_seq
to authenticated;

alter table public.batch_code_pc enable row level security;

drop policy if exists batch_code_pc_select on public.batch_code_pc;
create policy batch_code_pc_select
on public.batch_code_pc
for select
to authenticated
using (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists batch_code_pc_insert on public.batch_code_pc;
create policy batch_code_pc_insert
on public.batch_code_pc
for insert
to authenticated
with check (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists batch_code_pc_update on public.batch_code_pc;
create policy batch_code_pc_update
on public.batch_code_pc
for update
to authenticated
using (public.can_manage_shipment_by_id(shipment_id))
with check (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists batch_code_pc_delete on public.batch_code_pc;
create policy batch_code_pc_delete
on public.batch_code_pc
for delete
to authenticated
using (public.can_manage_shipment_by_id(shipment_id));

commit;
