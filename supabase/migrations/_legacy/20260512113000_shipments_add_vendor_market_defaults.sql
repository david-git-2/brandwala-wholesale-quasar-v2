alter table public.shipments
  add column if not exists vendor_code text null,
  add column if not exists market_code text null;

create index if not exists shipments_vendor_code_idx
  on public.shipments (vendor_code);

create index if not exists shipments_market_code_idx
  on public.shipments (market_code);

alter table public.shipments
  drop constraint if exists shipments_vendor_code_fkey;

alter table public.shipments
  add constraint shipments_vendor_code_fkey
  foreign key (vendor_code)
  references public.vendors(code)
  on update cascade
  on delete set null;

alter table public.shipments
  drop constraint if exists shipments_market_code_fkey;

alter table public.shipments
  add constraint shipments_market_code_fkey
  foreign key (market_code)
  references public.markets(code)
  on update cascade
  on delete set null;
