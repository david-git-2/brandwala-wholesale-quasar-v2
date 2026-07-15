-- shops (+ related p1–p4 tables) had RLS but never received table GRANTs.
-- Without these, PostgREST/authenticated gets: permission denied for table shops (42501).

grant select, insert, update, delete on table public.shops to authenticated;
grant select, insert, update, delete on table public.customer_group_shop_profiles to authenticated;
grant select, insert, update, delete on table public.shop_customer_group_access to authenticated;
grant select, insert, update, delete on table public.shop_product_listings to authenticated;
