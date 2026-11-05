CREATE FUNCTION public.apply_cart_item_inventory_reservation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'INSERT' then
    if new.product_id is null then
      return new;
    end if;

    select tenant_id into v_tenant_id from public.carts where id = new.cart_id;
    perform public.adjust_inventory_reserved_for_product(v_tenant_id, new.product_id, new.quantity);
    return new;
  end if;

  if tg_op = 'UPDATE' then
    select tenant_id into v_tenant_id from public.carts where id = new.cart_id;

    if old.product_id is not null then
      perform public.adjust_inventory_reserved_for_product(v_tenant_id, old.product_id, -old.quantity);
    end if;

    if new.product_id is not null then
      perform public.adjust_inventory_reserved_for_product(v_tenant_id, new.product_id, new.quantity);
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.product_id is null then
      return old;
    end if;

    select tenant_id into v_tenant_id from public.carts where id = old.cart_id;
    perform public.adjust_inventory_reserved_for_product(v_tenant_id, old.product_id, -old.quantity);
    return old;
  end if;

  return null;
end;
$function$;

GRANT ALL ON FUNCTION public.apply_cart_item_inventory_reservation() TO anon;

GRANT ALL ON FUNCTION public.apply_cart_item_inventory_reservation() TO authenticated;

GRANT ALL ON FUNCTION public.apply_cart_item_inventory_reservation() TO service_role;