-- =========================================================
-- Products module: switch vendor_id / market_id to codes
-- Backfills existing rows and replaces numeric references with
-- vendor_code / market_code text references.
-- =========================================================

alter table public.products
  add column if not exists vendor_code text null,
  add column if not exists market_code text null;

update public.products p
set vendor_code = v.code
from public.vendors v
where p.vendor_id = v.id
  and (p.vendor_code is null or trim(p.vendor_code) = '');

update public.products p
set market_code = m.code
from public.markets m
where p.market_id = m.id
  and (p.market_code is null or trim(p.market_code) = '');

update public.products
set vendor_code = upper(trim(vendor_code))
where vendor_code is not null;

update public.products
set market_code = upper(trim(market_code))
where market_code is not null;

create index if not exists products_vendor_code_idx
  on public.products (vendor_code);

create index if not exists products_market_code_idx
  on public.products (market_code);

alter table public.products
  drop constraint if exists products_vendor_id_fkey,
  drop constraint if exists products_market_id_fkey;

alter table public.products
  add constraint products_vendor_code_fkey
    foreign key (vendor_code) references public.vendors(code) on delete set null,
  add constraint products_market_code_fkey
    foreign key (market_code) references public.markets(code) on delete set null;

drop index if exists products_vendor_id_idx;
drop index if exists products_market_id_idx;

alter table public.products
  drop column if exists vendor_id,
  drop column if exists market_id;

