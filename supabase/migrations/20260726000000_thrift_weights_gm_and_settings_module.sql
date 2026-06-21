begin;

-- Convert thrift stock weights from kg to grams (values were stored as decimal kg, e.g. 0.25 = 250g)
update public.thrift_stocks
set
  product_weight = round(product_weight * 1000),
  extra_weight = round(extra_weight * 1000)
where product_weight is not null
   or extra_weight is not null;

-- Enable thrift_settings for tenants that already have thrift_stock
insert into public.tenant_modules (tenant_id, module_key, is_active)
select tm.tenant_id, 'thrift_settings', true
from public.tenant_modules tm
where tm.module_key = 'thrift_stock'
  and tm.is_active = true
  and not exists (
    select 1
    from public.tenant_modules existing
    where existing.tenant_id = tm.tenant_id
      and existing.module_key = 'thrift_settings'
  );

commit;
