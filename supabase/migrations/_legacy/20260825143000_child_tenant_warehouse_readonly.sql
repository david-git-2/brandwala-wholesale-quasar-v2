-- Stub: body moved to 20270814000046_deferred_child_tenant_warehouse_readonly.sql (needs membership_has_module_action + stock_availability).
do $$ begin
  raise notice 'skipped child tenant warehouse readonly RPCs (deferred to 20270814000046)';
end $$;
