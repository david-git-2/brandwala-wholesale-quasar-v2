begin;

-- =========================================================
-- Shipment-level purchase + cost currencies
-- =========================================================

alter table public.thrift_shipments
  add column if not exists purchase_currency_id bigint
    references public.thrift_currencies(id),
  add column if not exists cost_currency_id bigint
    references public.thrift_currencies(id);

-- Backfill from tenant settings, fallback GBP / BDT
update public.thrift_shipments sh
set
  purchase_currency_id = coalesce(
    sh.purchase_currency_id,
    ts.default_purchase_currency_id,
    (select id from public.thrift_currencies where code = 'GBP')
  ),
  cost_currency_id = coalesce(
    sh.cost_currency_id,
    ts.default_sold_currency_id,
    (select id from public.thrift_currencies where code = 'BDT')
  )
from public.thrift_settings ts
where ts.tenant_id = sh.tenant_id;

update public.thrift_shipments sh
set
  purchase_currency_id = coalesce(
    sh.purchase_currency_id,
    (select id from public.thrift_currencies where code = 'GBP')
  ),
  cost_currency_id = coalesce(
    sh.cost_currency_id,
    (select id from public.thrift_currencies where code = 'BDT')
  )
where sh.purchase_currency_id is null
   or sh.cost_currency_id is null;

-- Drop settings currency FKs before reseeding catalog
alter table public.thrift_settings
  drop column if exists default_purchase_currency_id,
  drop column if exists default_sold_currency_id;

-- =========================================================
-- Reseed popular currencies (preserve shipment links via codes)
-- =========================================================

alter table public.thrift_shipments
  add column if not exists purchase_currency_code text,
  add column if not exists cost_currency_code text;

update public.thrift_shipments sh
set
  purchase_currency_code = pc.code,
  cost_currency_code = cc.code
from public.thrift_currencies pc,
     public.thrift_currencies cc
where pc.id = sh.purchase_currency_id
  and cc.id = sh.cost_currency_id;

alter table public.thrift_shipments
  drop constraint if exists thrift_shipments_purchase_currency_id_fkey,
  drop constraint if exists thrift_shipments_cost_currency_id_fkey;

alter table public.thrift_shipments
  alter column purchase_currency_id drop not null,
  alter column cost_currency_id drop not null;

delete from public.thrift_currencies;

insert into public.thrift_currencies (name, country, code, symbol) values
  ('US Dollar', 'United States', 'USD', '$'),
  ('Euro', 'Eurozone', 'EUR', '€'),
  ('British Pound', 'United Kingdom', 'GBP', '£'),
  ('Japanese Yen', 'Japan', 'JPY', '¥'),
  ('Chinese Yuan', 'China', 'CNY', '¥'),
  ('Australian Dollar', 'Australia', 'AUD', 'A$'),
  ('Canadian Dollar', 'Canada', 'CAD', 'C$'),
  ('Swiss Franc', 'Switzerland', 'CHF', 'CHF'),
  ('Hong Kong Dollar', 'Hong Kong', 'HKD', 'HK$'),
  ('Singapore Dollar', 'Singapore', 'SGD', 'S$'),
  ('Swedish Krona', 'Sweden', 'SEK', 'kr'),
  ('Norwegian Krone', 'Norway', 'NOK', 'kr'),
  ('Danish Krone', 'Denmark', 'DKK', 'kr'),
  ('New Zealand Dollar', 'New Zealand', 'NZD', 'NZ$'),
  ('Indian Rupee', 'India', 'INR', '₹'),
  ('Bangladeshi Taka', 'Bangladesh', 'BDT', '৳'),
  ('Pakistani Rupee', 'Pakistan', 'PKR', '₨'),
  ('UAE Dirham', 'United Arab Emirates', 'AED', 'د.إ'),
  ('Saudi Riyal', 'Saudi Arabia', 'SAR', '﷼'),
  ('Qatari Riyal', 'Qatar', 'QAR', '﷼'),
  ('Kuwaiti Dinar', 'Kuwait', 'KWD', 'د.ك'),
  ('Bahraini Dinar', 'Bahrain', 'BHD', '.د.ب'),
  ('Omani Rial', 'Oman', 'OMR', '﷼'),
  ('Egyptian Pound', 'Egypt', 'EGP', 'E£'),
  ('South African Rand', 'South Africa', 'ZAR', 'R'),
  ('Brazilian Real', 'Brazil', 'BRL', 'R$'),
  ('Mexican Peso', 'Mexico', 'MXN', '$'),
  ('South Korean Won', 'South Korea', 'KRW', '₩'),
  ('Thai Baht', 'Thailand', 'THB', '฿'),
  ('Malaysian Ringgit', 'Malaysia', 'MYR', 'RM'),
  ('Indonesian Rupiah', 'Indonesia', 'IDR', 'Rp'),
  ('Philippine Peso', 'Philippines', 'PHP', '₱'),
  ('Vietnamese Dong', 'Vietnam', 'VND', '₫'),
  ('Turkish Lira', 'Turkey', 'TRY', '₺'),
  ('Polish Zloty', 'Poland', 'PLN', 'zł'),
  ('Czech Koruna', 'Czech Republic', 'CZK', 'Kč'),
  ('Hungarian Forint', 'Hungary', 'HUF', 'Ft'),
  ('Israeli Shekel', 'Israel', 'ILS', '₪'),
  ('Russian Ruble', 'Russia', 'RUB', '₽'),
  ('Taiwan Dollar', 'Taiwan', 'TWD', 'NT$'),
  ('Nigerian Naira', 'Nigeria', 'NGN', '₦'),
  ('Kenyan Shilling', 'Kenya', 'KES', 'KSh'),
  ('Colombian Peso', 'Colombia', 'COP', '$'),
  ('Argentine Peso', 'Argentina', 'ARS', '$'),
  ('Chilean Peso', 'Chile', 'CLP', '$'),
  ('Romanian Leu', 'Romania', 'RON', 'lei'),
  ('Ukrainian Hryvnia', 'Ukraine', 'UAH', '₴');

update public.thrift_shipments sh
set purchase_currency_id = pc.id
from public.thrift_currencies pc
where pc.code = coalesce(sh.purchase_currency_code, 'GBP');

update public.thrift_shipments sh
set cost_currency_id = cc.id
from public.thrift_currencies cc
where cc.code = coalesce(sh.cost_currency_code, 'BDT');

alter table public.thrift_shipments
  drop column if exists purchase_currency_code,
  drop column if exists cost_currency_code;

alter table public.thrift_shipments
  alter column purchase_currency_id set not null,
  alter column cost_currency_id set not null;

alter table public.thrift_shipments
  add constraint thrift_shipments_purchase_currency_id_fkey
    foreign key (purchase_currency_id) references public.thrift_currencies(id),
  add constraint thrift_shipments_cost_currency_id_fkey
    foreign key (cost_currency_id) references public.thrift_currencies(id);

-- =========================================================
-- Enable thrift_currency module for thrift_stock tenants
-- =========================================================

insert into public.modules (key, name, description, is_active)
values (
  'thrift_currency',
  'Thrift Currency',
  'View the global currency catalog used by shipments and stock pricing.',
  true
)
on conflict (key) do update
set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active;

insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'thrift_currency', true
from public.tenant_modules tm
where tm.module_key = 'thrift_stock'
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'thrift_currency'
  );

commit;
