CREATE FUNCTION public.bulk_allocate_shipment_stock (
  p_parent_tenant_id bigint,
  p_shipment_id      bigint,
  p_child_tenant_id  bigint
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_rec record;
  v_updated_count integer := 0;
  v_other_allocated_sum integer;
  v_remaining_qty integer;
begin
  -- Verify child tenant belongs to parent
  if not exists (
    select 1 from public.tenants
    where id = p_child_tenant_id and parent_id = p_parent_tenant_id
  ) then
    raise exception 'Child tenant % does not belong to parent tenant %', p_child_tenant_id, p_parent_tenant_id;
  end if;

  -- Loop through all ready sellable stocks in the given shipment batch
  for v_rec in
    select
      gs.id as stock_id,
      gs.quantity as pool_qty
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    inner join public.global_shipments gship on gship.id = gsi.shipment_id
    inner join public.global_stock_types gst on gst.id = gs.stock_type_id
    where gs.parent_tenant_id = p_parent_tenant_id
      and gship.id = p_shipment_id
      and gship.status = 'received'
      and gst.is_sellable = true
  loop
    -- Calculate sum allocated to OTHER child tenants
    select coalesce(sum(quantity), 0)::integer into v_other_allocated_sum
    from public.global_stock_allocations
    where stock_id = v_rec.stock_id
      and child_tenant_id <> p_child_tenant_id;

    -- Calculate remaining available stock for this stock pool
    v_remaining_qty := greatest(v_rec.pool_qty - v_other_allocated_sum, 0);

    if v_remaining_qty > 0 then
      -- Upsert global_stock_allocations for target child tenant
      insert into public.global_stock_allocations (parent_tenant_id, child_tenant_id, stock_id, quantity)
      values (p_parent_tenant_id, p_child_tenant_id, v_rec.stock_id, v_remaining_qty)
      on conflict (child_tenant_id, stock_id)
      do update set quantity = v_remaining_qty, updated_at = now();

      v_updated_count := v_updated_count + 1;
    end if;
  end loop;

  return v_updated_count;
end;
$function$;

CREATE FUNCTION public.bulk_allocate_shipment_stock (
  p_shipment_id     bigint,
  p_child_tenant_id bigint,
  p_allocations     jsonb  DEFAULT NULL::jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return jsonb_build_object('status', 'retired');
end;
$function$;

GRANT ALL ON FUNCTION public.bulk_allocate_shipment_stock(bigint, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.bulk_allocate_shipment_stock(bigint, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_allocate_shipment_stock(bigint, bigint, bigint) TO service_role;

GRANT ALL ON FUNCTION public.bulk_allocate_shipment_stock(bigint, bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.bulk_allocate_shipment_stock(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_allocate_shipment_stock(bigint, bigint, jsonb) TO service_role;