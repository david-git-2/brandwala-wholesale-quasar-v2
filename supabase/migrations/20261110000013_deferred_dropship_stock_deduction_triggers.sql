-- Deferred from 20260729051000_dropship_stock_deduction_and_rollback_triggers.sql so fresh resets create shop_orders first (20260902000600).
-- On production this re-runs as CREATE OR REPLACE / IF NOT EXISTS — safe.

-- Migration: Dropship Stock Auto Deactivation, Dual Stock Deduction, and Order Delete Rollback Trigger

-- 1. Trigger Function to automatically sync product listing active state based on available/allocation stock
create or replace function public.sync_shop_listing_active_status_on_stock_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available_qty integer;
begin
  -- Calculate available quantity for the allocation (quantity minus active reservations)
  select (gsa.quantity - coalesce((select sum(quantity) from public.shop_stock_reservations where global_stock_allocation_id = gsa.id), 0))
  into v_available_qty
  from public.global_stock_allocations gsa
  where gsa.id = NEW.global_stock_allocation_id;

  -- Auto-deactivate listing if display_quantity_override is <= 0 or available allocation quantity is <= 0
  if (NEW.display_quantity_override is not null and NEW.display_quantity_override <= 0) or coalesce(v_available_qty, 0) <= 0 then
    NEW.is_active := false;
  -- Auto-reactivate listing if stock is restored > 0
  elsif (NEW.display_quantity_override is null or NEW.display_quantity_override > 0) and coalesce(v_available_qty, 0) > 0 then
    NEW.is_active := true;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_sync_shop_listing_active_status on public.shop_product_listings;

create trigger trg_sync_shop_listing_active_status
before insert or update of display_quantity_override, is_active on public.shop_product_listings
for each row
execute function public.sync_shop_listing_active_status_on_stock_change();


-- 2. Trigger Function on global_stock_allocations to update shop_product_listings active status on stock change
create or replace function public.sync_shop_listings_on_allocation_qty_change()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available_qty integer;
begin
  v_available_qty := NEW.quantity - coalesce((select sum(quantity) from public.shop_stock_reservations where global_stock_allocation_id = NEW.id), 0);

  if v_available_qty <= 0 then
    update public.shop_product_listings
    set is_active = false
    where global_stock_allocation_id = NEW.id and is_active = true;
  elsif v_available_qty > 0 then
    update public.shop_product_listings
    set is_active = true
    where global_stock_allocation_id = NEW.id
      and is_active = false
      and (display_quantity_override is null or display_quantity_override > 0);
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_sync_shop_listings_on_allocation_qty on public.global_stock_allocations;

create trigger trg_sync_shop_listings_on_allocation_qty
after insert or update of quantity on public.global_stock_allocations
for each row
execute function public.sync_shop_listings_on_allocation_qty_change();


-- 3. Redefine delete_shop_order to restore/rollback actual and display quantities when an order is deleted
create or replace function public.delete_shop_order(p_order_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_item record;
  v_allocation_id bigint;
  v_stock_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'Access denied';
  end if;

  if v_order.status = 'fulfilled' then
    raise exception 'Cannot delete a fulfilled order';
  end if;

  -- Rollback stock for dropship or confirmed shop orders
  for v_item in select * from public.shop_order_items where order_id = p_order_id loop
    -- Resolve allocation and stock IDs if missing
    v_allocation_id := v_item.global_stock_allocation_id;
    v_stock_id := v_item.global_stock_id;

    -- Rollback display_quantity_override in shop_product_listings
    if v_item.product_id is not null then
      update public.shop_product_listings
      set display_quantity_override = display_quantity_override + v_item.quantity
      where shop_id = v_order.shop_id
        and product_id = v_item.product_id
        and (v_allocation_id is null or global_stock_allocation_id = v_allocation_id)
        and display_quantity_override is not null;
    end if;

    -- Rollback actual quantity in global_stock_allocations
    if v_allocation_id is not null then
      update public.global_stock_allocations
      set quantity = quantity + v_item.quantity
      where id = v_allocation_id;
    end if;

    -- Rollback actual quantity in global_stocks
    if v_stock_id is not null then
      update public.global_stocks
      set quantity = quantity + v_item.quantity
      where id = v_stock_id;
    end if;
  end loop;

  -- Delete the order (cascade deletes items)
  delete from public.shop_orders where id = p_order_id;
end;
$$;

grant execute on function public.delete_shop_order(bigint) to authenticated;
