-- =========================================================
-- RLS for product lookup tables
-- =========================================================

alter table public.product_brands enable row level security;
alter table public.product_categories enable row level security;

drop policy if exists product_brands_read_authenticated on public.product_brands;
create policy product_brands_read_authenticated
on public.product_brands
for select
to authenticated
using (true);

drop policy if exists product_categories_read_authenticated on public.product_categories;
create policy product_categories_read_authenticated
on public.product_categories
for select
to authenticated
using (true);

grant select on table public.product_brands to authenticated;
grant select on table public.product_categories to authenticated;
