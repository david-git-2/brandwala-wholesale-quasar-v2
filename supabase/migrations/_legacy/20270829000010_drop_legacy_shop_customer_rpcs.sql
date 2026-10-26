-- T4: drop leaky customer RPCs now that T2 is wired to tenant-scoped names.

drop function if exists public.list_shop_orders_for_customer(bigint, integer, integer);
drop function if exists public.list_active_shop_carts();
drop function if exists public.list_shops_for_customer(bigint);
drop function if exists public.browse_shop_catalog(text, text, text, text, integer, integer);
