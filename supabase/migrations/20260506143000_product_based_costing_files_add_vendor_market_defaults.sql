alter table public.product_based_costing_files
  add column if not exists vendor_code text null,
  add column if not exists market_code text null;

create index if not exists product_based_costing_files_vendor_code_idx
  on public.product_based_costing_files (vendor_code);

create index if not exists product_based_costing_files_market_code_idx
  on public.product_based_costing_files (market_code);

alter table public.product_based_costing_files
  add constraint product_based_costing_files_vendor_code_fkey
  foreign key (vendor_code) references public.vendors(code) on delete set null;

alter table public.product_based_costing_files
  add constraint product_based_costing_files_market_code_fkey
  foreign key (market_code) references public.markets(code) on delete set null;
