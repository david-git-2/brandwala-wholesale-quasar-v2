-- =========================================================
-- Simple cart insert policies (no JWT-claim dependency)
-- =========================================================

-- Carts insert
-- Keep it simple as requested: insert allowed for authenticated role.
drop policy if exists carts_insert on public.carts;
drop policy if exists carts_insert_public on public.carts;
create policy carts_insert_public
on public.carts
for insert
to authenticated
with check (true);

-- Cart items insert
-- Allow insert for authenticated role when referencing an existing cart.
drop policy if exists cart_items_insert on public.cart_items;
drop policy if exists cart_items_insert_public on public.cart_items;
create policy cart_items_insert_public
on public.cart_items
for insert
to authenticated
with check (
  cart_id is not null
);
