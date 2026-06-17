-- Migration: Remove commerce_accounting view and implement trigger on inventory_accounting_entries
begin;

-- 1. Drop the legacy view and its instead of trigger
drop view if exists public.commerce_accounting cascade;
drop function if exists public.trg_fn_commerce_accounting_instead_of() cascade;

-- 2. Create the before insert/update trigger function on inventory_accounting_entries
create or replace function public.fn_sync_commerce_accounting_entry()
returns trigger
language plpgsql
security definer
as $$
declare
  v_quantity integer;
  v_product_id bigint;
  v_invoice_id bigint;
  v_shipment_id bigint;
begin
  if new.type = 'commerce' and new.commerce_order_item_id is not null then
    -- Resolve quantity and parent product id/invoice/shipment from commerce_order_items
    select quantity, invoice_id into v_quantity, v_invoice_id
    from public.commerce_order_items
    where id = new.commerce_order_item_id;

    v_quantity := coalesce(v_quantity, 1);

    select product_id into v_product_id
    from public.inventory_items
    where id = new.inventory_item_id;

    if new.shipment_item_id is not null then
      select shipment_id into v_shipment_id
      from public.shipment_items
      where id = new.shipment_item_id;
    end if;

    new.commerce_invoice_id := coalesce(new.commerce_invoice_id, v_invoice_id);
    new.product_id := coalesce(new.product_id, v_product_id);
    new.quantity := v_quantity;
    new.shipment_id := coalesce(new.shipment_id, v_shipment_id);
    
    new.total_cost_amount := (new.cost_amount * v_quantity);
    new.total_sell_amount := (new.sell_price_amount * v_quantity);
    new.gross_profit_amount := ((new.sell_price_amount - new.cost_amount) * v_quantity);
  end if;
  return new;
end;
$$;

-- 3. Register trigger on inventory_accounting_entries
drop trigger if exists trg_sync_commerce_accounting_entry on public.inventory_accounting_entries;
create trigger trg_sync_commerce_accounting_entry
  before insert or update on public.inventory_accounting_entries
  for each row
  execute function public.fn_sync_commerce_accounting_entry();

commit;
