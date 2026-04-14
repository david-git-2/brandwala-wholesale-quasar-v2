-- =========================================================
-- Cart policies: open to authenticated users
-- Aligns repo migrations with the currently working DB behavior.
-- =========================================================

-- Grants
grant select, insert, update, delete on table public.carts to authenticated;
grant select, insert, update, delete on table public.cart_items to authenticated;
grant usage, select on sequence public.carts_id_seq to authenticated;
grant usage, select on sequence public.cart_items_id_seq to authenticated;

-- Carts policies
drop policy if exists carts_select on public.carts;
drop policy if exists carts_insert on public.carts;
drop policy if exists carts_update on public.carts;
drop policy if exists carts_delete on public.carts;
drop policy if exists carts_insert_public on public.carts;

create policy carts_select
on public.carts
for select
to authenticated
using (true);

create policy carts_insert_public
on public.carts
for insert
to authenticated
with check (true);

create policy carts_update
on public.carts
for update
to authenticated
using (true)
with check (true);

create policy carts_delete
on public.carts
for delete
to authenticated
using (true);

-- Cart items policies
drop policy if exists cart_items_select on public.cart_items;
drop policy if exists cart_items_insert on public.cart_items;
drop policy if exists cart_items_update on public.cart_items;
drop policy if exists cart_items_delete on public.cart_items;
drop policy if exists cart_items_insert_public on public.cart_items;

create policy cart_items_select
on public.cart_items
for select
to authenticated
using (true);

create policy cart_items_insert_public
on public.cart_items
for insert
to authenticated
with check (true);

create policy cart_items_update
on public.cart_items
for update
to authenticated
using (true)
with check (true);

create policy cart_items_delete
on public.cart_items
for delete
to authenticated
using (true);
