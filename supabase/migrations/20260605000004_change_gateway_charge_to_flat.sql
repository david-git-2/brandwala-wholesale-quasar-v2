begin;

-- 1. Rename column
alter table public.koba_retail_settings
rename column gateway_charge_pct to gateway_charge_flat;

-- 2. Alter column type and default
alter table public.koba_retail_settings
alter column gateway_charge_flat type numeric(12,2),
alter column gateway_charge_flat set default 20.00;

-- 3. Backfill/update existing rows with the new default flat value of 20
update public.koba_retail_settings
set gateway_charge_flat = 20.00;

commit;
