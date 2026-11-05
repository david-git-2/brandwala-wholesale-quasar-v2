CREATE FUNCTION public.sync_shop_cart_item_reservation()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  AS $function$
begin
  if tg_op = 'DELETE' then
    delete from public.shop_stock_reservations where cart_item_id = old.id;
    return old;
  end if;

  if new.quantity > 0 and new.global_stock_id is not null then
    insert into public.shop_stock_reservations (cart_item_id, global_stock_id, global_stock_allocation_id, quantity)
    values (new.id, new.global_stock_id, null, new.quantity)
    on conflict (cart_item_id) do update set
      global_stock_id = excluded.global_stock_id,
      global_stock_allocation_id = null,
      quantity = excluded.quantity;
  else
    delete from public.shop_stock_reservations where cart_item_id = new.id;
  end if;

  return new;
end;
$function$;

GRANT ALL ON FUNCTION public.sync_shop_cart_item_reservation() TO anon;

GRANT ALL ON FUNCTION public.sync_shop_cart_item_reservation() TO authenticated;

GRANT ALL ON FUNCTION public.sync_shop_cart_item_reservation() TO service_role;