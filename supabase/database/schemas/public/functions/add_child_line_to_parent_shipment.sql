CREATE FUNCTION public.add_child_line_to_parent_shipment (
  p_parent_shipment_id bigint,
  p_source_type        text,
  p_source_id          bigint
)
  RETURNS public.global_shipment_items
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shipment public.global_shipments;
  v_row public.global_shipment_items;
  v_source_type text;
  v_child_tenant_id bigint;
  v_prod record;
  v_vendor_id bigint;
begin
  v_source_type := lower(trim(coalesce(p_source_type, '')));

  if v_source_type not in ('order_item', 'costing_item', 'shop_order_item') then
    raise exception 'invalid source_type: %', p_source_type;
  end if;

  select * into v_shipment
  from public.global_shipments
  where id = p_parent_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_source_type = 'order_item' then
    -- Legacy Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.parent_tenant_id = v_shipment.tenant_id
      and oi.shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.order_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      oi.name,
      greatest(coalesce(oi.ordered_quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'order_item',
      oi.id
    from public.order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.order_items
    set shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'costing_item' then
    -- Costing Pull
    select pcf.tenant_id into v_child_tenant_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where pci.id = p_source_id
      and t.parent_id = v_shipment.tenant_id
      and pci.assigned_shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'costing item not available for procurement';
    end if;

    select product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.product_based_costing_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      pci.product_id,
      pci.name,
      greatest(coalesce(pci.quantity, 0), 0),
      pci.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(pci.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      pci.barcode,
      pci.product_code,
      v_child_tenant_id,
      'costing_item',
      pci.id
    from public.product_based_costing_items pci
    where pci.id = p_source_id
    returning * into v_row;

    update public.product_based_costing_items
    set assigned_shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'shop_order_item' then
    -- Shop Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    where oi.id = p_source_id
      and t.parent_id = v_shipment.tenant_id
      and oi.procurement_pulled = false
      and o.status = 'placed';

    if v_child_tenant_id is null then
      raise exception 'shop order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.shop_order_items where id = p_source_id);

    -- Try to match vendor by vendor_code of the shop
    select v.id into v_vendor_id
    from public.shop_order_items oi
    join public.shop_orders o on o.id = oi.order_id
    join public.shops s on s.id = o.shop_id
    join public.vendors v on v.code = s.vendor_code and v.parent_tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
    where oi.id = p_source_id
    limit 1;

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      v_vendor_id,
      oi.name,
      greatest(coalesce(oi.quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.final_price_amount, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'shop_order_item',
      oi.id
    from public.shop_order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.shop_order_items
    set procurement_pulled = true
    where id = p_source_id;

  end if;

  return v_row;
end;
$function$;

GRANT ALL ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO anon;

GRANT ALL ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO service_role;