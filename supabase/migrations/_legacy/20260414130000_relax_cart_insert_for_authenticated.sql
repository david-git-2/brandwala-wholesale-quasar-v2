-- =========================================================
-- Relax cart insert rules:
-- Any authenticated user can create carts and add cart items.
-- =========================================================

create or replace function public.cart_exists(
  p_cart_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.carts c
    where c.id = p_cart_id
  );
$$;

grant execute on function public.cart_exists(bigint)
to authenticated;

drop policy if exists carts_insert on public.carts;
create policy carts_insert
on public.carts
for insert
to authenticated
with check (auth.uid() is not null);

drop policy if exists cart_items_insert on public.cart_items;
create policy cart_items_insert
on public.cart_items
for insert
to authenticated
with check (
  auth.uid() is not null
  and public.cart_exists(cart_id)
);
