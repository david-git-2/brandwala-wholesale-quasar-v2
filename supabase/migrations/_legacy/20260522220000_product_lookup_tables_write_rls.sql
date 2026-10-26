-- =========================================================
-- RLS Write Policies for product lookup tables
-- =========================================================

-- Grant sequence usage
grant usage, select on sequence public.product_brands_id_seq to authenticated;
grant usage, select on sequence public.product_categories_id_seq to authenticated;

-- Grant DML operations
grant insert, update, delete on table public.product_brands to authenticated;
grant insert, update, delete on table public.product_categories to authenticated;

-- Policies for product_brands
drop policy if exists product_brands_insert_authenticated on public.product_brands;
create policy product_brands_insert_authenticated
on public.product_brands
for insert
to authenticated
with check (true);

drop policy if exists product_brands_update_authenticated on public.product_brands;
create policy product_brands_update_authenticated
on public.product_brands
for update
to authenticated
using (true)
with check (true);

drop policy if exists product_brands_delete_authenticated on public.product_brands;
create policy product_brands_delete_authenticated
on public.product_brands
for delete
to authenticated
using (true);

-- Policies for product_categories
drop policy if exists product_categories_insert_authenticated on public.product_categories;
create policy product_categories_insert_authenticated
on public.product_categories
for insert
to authenticated
with check (true);

drop policy if exists product_categories_update_authenticated on public.product_categories;
create policy product_categories_update_authenticated
on public.product_categories
for update
to authenticated
using (true)
with check (true);

drop policy if exists product_categories_delete_authenticated on public.product_categories;
create policy product_categories_delete_authenticated
on public.product_categories
for delete
to authenticated
using (true);
