-- =========================================================
-- Cart table/function grants for authenticated clients
-- =========================================================

grant select, insert, update, delete on table public.carts to authenticated;
grant select, insert, update, delete on table public.cart_items to authenticated;

grant usage, select on sequence public.carts_id_seq to authenticated;
grant usage, select on sequence public.cart_items_id_seq to authenticated;

grant execute on function public.get_cart(bigint) to authenticated;
grant execute on function public.get_cart_details(bigint) to authenticated;
