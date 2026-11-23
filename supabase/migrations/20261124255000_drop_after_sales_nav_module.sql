-- Remove deprecated after_sales navigation module and its grants/actions.
DELETE FROM public.role_grants WHERE module_key = 'after_sales';
DELETE FROM public.tenant_modules WHERE module_key = 'after_sales';
DELETE FROM public.module_actions WHERE module_key = 'after_sales';
DELETE FROM public.modules WHERE key = 'after_sales';
