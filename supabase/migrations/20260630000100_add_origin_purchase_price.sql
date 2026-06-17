begin;

-- Add origin_purchase_price to thrift_stocks
alter table public.thrift_stocks
add column origin_purchase_price numeric(12, 2) null check (origin_purchase_price >= 0);

-- Add default_origin_purchase_price to thrift_stock_settings
alter table public.thrift_stock_settings
add column default_origin_purchase_price numeric(12, 2) not null default 0.00 check (default_origin_purchase_price >= 0);

commit;
