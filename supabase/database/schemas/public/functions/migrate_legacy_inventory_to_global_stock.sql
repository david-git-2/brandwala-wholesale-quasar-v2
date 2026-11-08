CREATE FUNCTION public.migrate_legacy_inventory_to_global_stock (
  p_tenant_id bigint DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_item record;
  v_stock_id bigint;
  v_parent_id bigint;
  v_migrated integer := 0;
begin
  for v_item in
    select ii.*
    from public.inventory_items ii
    where (p_tenant_id is null or ii.tenant_id = p_tenant_id)
      and not exists (
        select 1 from public.global_stocks gs
        where gs.legacy_inventory_item_id = ii.id
      )
  loop
    v_parent_id := public.resolve_parent_tenant_id(v_item.tenant_id);

    insert into public.global_stocks (
      tenant_id,
      tenant_id,
      name,
      cost,
      image_url,
      product_code,
      barcode,
      product_id,
      source_module,
      source_type,
      source_id,
      legacy_inventory_item_id
    )
    values (
      v_parent_id,
      v_parent_id,
      v_item.name,
      coalesce(v_item.cost, 0),
      v_item.image_url,
      v_item.product_code,
      v_item.barcode,
      v_item.product_id,
      'wholesale',
      coalesce(v_item.source_type, 'migration'),
      v_item.source_id,
      v_item.id
    )
    returning id into v_stock_id;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'excellent', coalesce(s.available_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.available_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'box_less', coalesce(s.open_box_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.open_box_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'expired', coalesce(s.expired_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.expired_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    insert into public.global_stock_quantities (stock_id, status, quantity)
    select v_stock_id, 'stolen', coalesce(s.stolen_quantity, 0)
    from public.inventory_stocks s
    where s.inventory_item_id = v_item.id
      and coalesce(s.stolen_quantity, 0) > 0
    on conflict (stock_id, status) do update set quantity = excluded.quantity;

    v_migrated := v_migrated + 1;
  end loop;

  return jsonb_build_object('migrated_count', v_migrated);
end;
$function$;

GRANT ALL ON FUNCTION public.migrate_legacy_inventory_to_global_stock(bigint) TO anon;

GRANT ALL ON FUNCTION public.migrate_legacy_inventory_to_global_stock(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.migrate_legacy_inventory_to_global_stock(bigint) TO service_role;