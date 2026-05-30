-- Drop trigger that checks stock and reserves inventory for cart items
drop trigger if exists trg_cart_items_inventory_reservation on public.cart_items;
