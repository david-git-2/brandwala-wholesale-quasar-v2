begin;

-- Simplify settings to a single default purchase price (GBP)
alter table public.thrift_stock_settings
  drop constraint if exists thrift_stock_settings_default_shipment_id_fkey;

alter table public.thrift_stock_settings
  drop constraint if exists thrift_stock_settings_default_box_id_fkey;

alter table public.thrift_stock_settings
  drop column if exists default_shipment_id,
  drop column if exists default_box_id,
  drop column if exists default_origin_purchase_price;

alter table public.thrift_stock_settings
  rename column default_purchase_price to default_purchase_price_gbp;

alter table public.thrift_stock_settings rename to thrift_settings;

alter table public.thrift_settings
  rename constraint thrift_stock_settings_tenant_id_fkey to thrift_settings_tenant_id_fkey;

alter trigger trg_thrift_stock_settings_updated_at on public.thrift_settings
  rename to trg_thrift_settings_updated_at;

alter policy select_thrift_stock_settings on public.thrift_settings
  rename to select_thrift_settings;

alter policy write_thrift_stock_settings on public.thrift_settings
  rename to write_thrift_settings;

-- Module catalog
insert into public.modules (key, name, description, is_active)
values (
  'thrift_settings',
  'Thrift Settings',
  'Configure default purchase price for stock entries.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

commit;
