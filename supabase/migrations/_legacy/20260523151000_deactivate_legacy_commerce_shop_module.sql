update public.tenant_modules
set is_active = false
where module_key = 'commerce_shop';

update public.modules
set is_active = false
where key = 'commerce_shop';
