begin;

-- Tenant 16 (thrift): default purchase = GBP, default cost = BDT
update public.tenants t
set preference = coalesce(t.preference, '{}'::jsonb) || jsonb_build_object(
  'thrift', jsonb_build_object(
    'default_purchase_currency', (
      select gc.id from public.global_currencies gc
      where gc.code = 'GBP' and gc.is_active = true
      limit 1
    ),
    'default_cost_currency', (
      select gc.id from public.global_currencies gc
      where gc.code = 'BDT' and gc.is_active = true
      limit 1
    )
  )
)
where t.id = 16;

commit;
