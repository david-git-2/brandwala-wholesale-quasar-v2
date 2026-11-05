CREATE FUNCTION public.trg_sync_catalog_weights_from_global_shipment_item()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_ship public.global_shipments%rowtype;
begin
  if new.product_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.product_weight is not distinct from old.product_weight
     and new.package_weight is not distinct from old.package_weight
     and new.product_id is not distinct from old.product_id then
    return new;
  end if;

  select * into v_ship
  from public.global_shipments
  where id = new.shipment_id;

  if not found then
    return new;
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    return new;
  end if;

  update public.products p
  set
    product_weight = new.product_weight,
    package_weight = new.package_weight,
    updated_at = now()
  where p.id = new.product_id;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.trg_sync_catalog_weights_from_global_shipment_item() TO anon;

GRANT ALL ON FUNCTION public.trg_sync_catalog_weights_from_global_shipment_item() TO authenticated;

GRANT ALL ON FUNCTION public.trg_sync_catalog_weights_from_global_shipment_item() TO service_role;