-- Phase 2 (W5 Step 2.1): Shop schema migration for global_stock_id only listings, cart, and reservations

begin;

-- 1. shop_product_listings updates
alter table public.shop_product_listings
  add column if not exists global_stock_id bigint references public.global_stocks(id) on delete cascade;

-- Backfill global_stock_id from global_stock_allocations if missing
update public.shop_product_listings spl
set global_stock_id = gsa.stock_id
from public.global_stock_allocations gsa
where spl.global_stock_allocation_id = gsa.id
  and spl.global_stock_id is null;

-- Make global_stock_allocation_id nullable
alter table public.shop_product_listings
  alter column global_stock_allocation_id drop not null;

-- Deduplicate listings by (shop_id, global_stock_id) keeping max(id)
do $$
declare
  v_rec record;
  v_survivor_id bigint;
begin
  for v_rec in (
    select shop_id, global_stock_id, count(*) as cnt
    from public.shop_product_listings
    where global_stock_id is not null
    group by shop_id, global_stock_id
    having count(*) > 1
  ) loop
    select max(id) into v_survivor_id
    from public.shop_product_listings
    where shop_id = v_rec.shop_id
      and global_stock_id = v_rec.global_stock_id;

    delete from public.shop_product_listings
    where shop_id = v_rec.shop_id
      and global_stock_id = v_rec.global_stock_id
      and id <> v_survivor_id;
  end loop;
end;
$$;

-- Add unique constraint on (shop_id, global_stock_id)
alter table public.shop_product_listings drop constraint if exists shop_product_listings_shop_stock_unique;

alter table public.shop_product_listings add constraint shop_product_listings_shop_stock_unique
  unique (shop_id, global_stock_id);

-- 2. shop_cart_items updates
alter table public.shop_cart_items
  add column if not exists global_stock_id bigint references public.global_stocks(id) on delete cascade;

-- Backfill global_stock_id on cart items
update public.shop_cart_items sci
set global_stock_id = gsa.stock_id
from public.global_stock_allocations gsa
where sci.global_stock_allocation_id = gsa.id
  and sci.global_stock_id is null;

alter table public.shop_cart_items
  alter column global_stock_allocation_id drop not null;

-- 3. shop_stock_reservations updates
alter table public.shop_stock_reservations
  add column if not exists global_stock_id bigint references public.global_stocks(id) on delete cascade;

-- Backfill global_stock_id on reservations
update public.shop_stock_reservations ssr
set global_stock_id = gsa.stock_id
from public.global_stock_allocations gsa
where ssr.global_stock_allocation_id = gsa.id
  and ssr.global_stock_id is null;

update public.shop_stock_reservations ssr
set global_stock_id = sci.global_stock_id
from public.shop_cart_items sci
where ssr.cart_item_id = sci.id
  and ssr.global_stock_id is null;

alter table public.shop_stock_reservations
  alter column global_stock_allocation_id drop not null;

-- 4. Update sync_shop_cart_item_reservation trigger function
create or replace function public.sync_shop_cart_item_reservation()
returns trigger language plpgsql as $$
begin
  if tg_op = 'DELETE' then
    delete from public.shop_stock_reservations where cart_item_id = old.id;
    return old;
  end if;

  if new.quantity > 0 and (new.global_stock_id is not null or new.global_stock_allocation_id is not null) then
    insert into public.shop_stock_reservations (cart_item_id, global_stock_id, global_stock_allocation_id, quantity)
    values (new.id, new.global_stock_id, new.global_stock_allocation_id, new.quantity)
    on conflict (cart_item_id) do update set
      global_stock_id = excluded.global_stock_id,
      global_stock_allocation_id = excluded.global_stock_allocation_id,
      quantity = excluded.quantity;
  else
    delete from public.shop_stock_reservations where cart_item_id = new.id;
  end if;

  return new;
end;
$$;

commit;
