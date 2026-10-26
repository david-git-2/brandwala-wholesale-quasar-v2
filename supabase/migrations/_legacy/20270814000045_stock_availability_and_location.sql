-- Phase 10: Stock availability enum + location_id column
-- Spec: doc/procurement_stock/task.md Phase 10

begin;

create type public.stock_availability as enum (
  'sellable',
  'damaged',
  'hold',
  'reserved',
  'returned'
);

alter table public.global_stocks
  add column if not exists availability public.stock_availability not null default 'sellable',
  add column if not exists location_id bigint references public.stock_locations(id) on delete set null;

comment on column public.global_stocks.availability is 'Stock pool availability state for warehouse & ATP calculation.';
comment on column public.global_stocks.location_id is 'Warehouse bin / location where stock is located.';

create index if not exists global_stocks_location_id_idx on public.global_stocks(location_id);
create index if not exists global_stocks_availability_idx on public.global_stocks(availability);

commit;
