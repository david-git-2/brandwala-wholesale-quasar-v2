-- Phase 12A: Patch desk/shop stock RPCs after header-rate drop + assign gate

begin;

-- search_stock_network: remove references to dropped columns; received status; assign gate for child context
do $$
declare
  r record;
  def text;
  new_def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'search_stock_network'
      and p.prokind = 'f'
  loop
    def := pg_get_functiondef(r.oid);
    new_def := def;
    new_def := replace(new_def, 'sh.product_conversion_rate', '1.0');
    new_def := replace(new_def, 'sh.cargo_conversion_rate', '1.0');
    new_def := replace(new_def, 'sh.cargo_rate', '0');
    new_def := replace(new_def, 'sh.transaction_rate', '1.0');
    new_def := replace(new_def, 'sh.status = ''Ready Stock''', 'sh.status = ''received''');
    if new_def is distinct from def then
      execute new_def;
      raise notice 'Patched search_stock_network';
    end if;
  end loop;
end $$;

-- browse_shop_catalog stock-backed path: only assigned shipments for shop tenant
do $$
declare
  r record;
  def text;
  new_def text;
begin
  for r in
    select p.oid
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'browse_shop_catalog'
      and p.prokind = 'f'
  loop
    def := pg_get_functiondef(r.oid);
    new_def := def;
    if new_def like '%global_stock_allocations%' and new_def not like '%assigned_child_tenant_id%' then
      new_def := replace(
        new_def,
        'inner join public.global_shipments gship on gship.id = gsi.shipment_id',
        'inner join public.global_shipments gship on gship.id = gsi.shipment_id and gship.assigned_child_tenant_id = v_tenant_id'
      );
    end if;
    if new_def is distinct from def then
      execute new_def;
      raise notice 'Patched browse_shop_catalog assign gate';
    end if;
  end loop;
end $$;

commit;
