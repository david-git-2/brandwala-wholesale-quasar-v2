-- Phase 1 (W4 Step 1.1): Stock grain cutover migration
-- Migrate balances from stock_type_id rows -> (shipment_item_id, availability, location_id) unique grain

begin;

-- 1a. Normalize availability from stock types if needed
update public.global_stocks gs
set availability = case
  when gst.is_sellable and gs.is_usable then 'sellable'::public.stock_availability
  when not gs.is_usable then 'unsellable'::public.stock_availability
  else 'held'::public.stock_availability
end
from public.global_stock_types gst
where gst.id = gs.stock_type_id;

-- 1b. Ensure location_id is not null (fallback to default putaway location if any null)
update public.global_stocks gs
set location_id = public.default_putaway_stock_location_id(gs.parent_tenant_id)
where gs.location_id is null;

-- 1c. Merge duplicate grain rows for (shipment_item_id, availability, location_id)
do $$
declare
  v_rec record;
  v_survivor_id bigint;
  v_total_qty int;
begin
  for v_rec in (
    select shipment_item_id, availability, location_id, count(*) as cnt
    from public.global_stocks
    group by shipment_item_id, availability, location_id
    having count(*) > 1
  ) loop
    -- Select survivor id (min id)
    select min(id) into v_survivor_id
    from public.global_stocks
    where shipment_item_id = v_rec.shipment_item_id
      and availability = v_rec.availability
      and location_id = v_rec.location_id;

    -- Calculate total quantity
    select sum(quantity) into v_total_qty
    from public.global_stocks
    where shipment_item_id = v_rec.shipment_item_id
      and availability = v_rec.availability
      and location_id = v_rec.location_id;

    -- Repoint FK references from merged-away rows to survivor
    update public.global_stock_allocations
    set stock_id = v_survivor_id
    where stock_id in (
      select id from public.global_stocks
      where shipment_item_id = v_rec.shipment_item_id
        and availability = v_rec.availability
        and location_id = v_rec.location_id
        and id <> v_survivor_id
    );

    update public.shop_product_listings
    set global_stock_id = v_survivor_id
    where global_stock_id in (
      select id from public.global_stocks
      where shipment_item_id = v_rec.shipment_item_id
        and availability = v_rec.availability
        and location_id = v_rec.location_id
        and id <> v_survivor_id
    );

    update public.shop_cart_items
    set global_stock_id = v_survivor_id
    where global_stock_id in (
      select id from public.global_stocks
      where shipment_item_id = v_rec.shipment_item_id
        and availability = v_rec.availability
        and location_id = v_rec.location_id
        and id <> v_survivor_id
    );

    update public.shop_order_items
    set global_stock_id = v_survivor_id
    where global_stock_id in (
      select id from public.global_stocks
      where shipment_item_id = v_rec.shipment_item_id
        and availability = v_rec.availability
        and location_id = v_rec.location_id
        and id <> v_survivor_id
    );

    update public.global_invoice_items
    set global_stock_id = v_survivor_id
    where global_stock_id in (
      select id from public.global_stocks
      where shipment_item_id = v_rec.shipment_item_id
        and availability = v_rec.availability
        and location_id = v_rec.location_id
        and id <> v_survivor_id
    );

    update public.stock_movement_lines
    set stock_id = v_survivor_id
    where stock_id in (
      select id from public.global_stocks
      where shipment_item_id = v_rec.shipment_item_id
        and availability = v_rec.availability
        and location_id = v_rec.location_id
        and id <> v_survivor_id
    );

    -- Delete merged-away rows
    delete from public.global_stocks
    where shipment_item_id = v_rec.shipment_item_id
      and availability = v_rec.availability
      and location_id = v_rec.location_id
      and id <> v_survivor_id;

    -- Update survivor total quantity
    update public.global_stocks
    set quantity = v_total_qty, updated_at = now()
    where id = v_survivor_id;
  end loop;
end;
$$;

-- 1d. Swap unique constraint
alter table public.global_stocks drop constraint if exists global_stocks_unique;

alter table public.global_stocks add constraint global_stocks_grain_unique
  unique (shipment_item_id, availability, location_id);

-- 1e. Deprecate stock_type_id column (make nullable)
alter table public.global_stocks alter column stock_type_id drop not null;

commit;
