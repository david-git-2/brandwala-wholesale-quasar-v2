-- Migration: Add cross-tenant accounting support
begin;

-- 1. Add sold_in_tenant_id column to inventory_accounting_entries table
alter table public.inventory_accounting_entries
  add column if not exists sold_in_tenant_id bigint references public.tenants(id) on delete set null;

-- 2. Drop and recreate v_shipment_accounting_ledger view to include sold_in_tenant_id
drop view if exists public.v_shipment_accounting_ledger cascade;

create or replace view public.v_shipment_accounting_ledger
with (security_invoker = true) as
select
  type,
  id,
  tenant_id,
  sold_in_tenant_id,
  coalesce(invoice_id, commerce_invoice_id) as invoice_id,
  invoice_item_id,
  inventory_item_id,
  product_id,
  quantity,
  cost_amount,
  sell_price_amount,
  total_cost_amount,
  total_sell_amount,
  gross_profit_amount,
  status,
  shipment_id,
  shipment_item_id,
  entry_date,
  note,
  created_at
from public.inventory_accounting_entries;

-- Grant permissions back
grant select on table public.v_shipment_accounting_ledger to authenticated;

-- 3. Update the trigger function public.fn_sync_commerce_accounting_entry
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
  v_inventory_tenant_id bigint;
  v_invoice_tenant_id bigint;
begin
  if new.inventory_item_id is not null then
    select product_id, tenant_id into v_product_id, v_inventory_tenant_id
    from public.inventory_items
    where id = new.inventory_item_id;

    -- Map the accounting entry to the owner tenant of the product/item
    new.sold_in_tenant_id := coalesce(new.sold_in_tenant_id, new.tenant_id);
    new.tenant_id := coalesce(v_inventory_tenant_id, new.tenant_id);
  end if;

  if new.type = 'commerce' and new.commerce_order_item_id is not null then
    -- Resolve quantity and parent product id/invoice/shipment from commerce_order_items
    select quantity, invoice_id into v_quantity, v_invoice_id
    from public.commerce_order_items
    where id = new.commerce_order_item_id;

    v_quantity := coalesce(v_quantity, 1);

    if new.shipment_item_id is not null then
      select shipment_id into v_shipment_id
      from public.shipment_items
      where id = new.shipment_item_id;
    end if;

    if v_invoice_id is not null then
      select tenant_id into v_invoice_tenant_id
      from public.commerce_invoices
      where id = v_invoice_id;
      
      new.sold_in_tenant_id := coalesce(new.sold_in_tenant_id, v_invoice_tenant_id);
    end if;

    new.commerce_invoice_id := coalesce(new.commerce_invoice_id, v_invoice_id);
    new.product_id := coalesce(new.product_id, v_product_id);
    new.quantity := v_quantity;
    new.shipment_id := coalesce(new.shipment_id, v_shipment_id);
    
    new.total_cost_amount := (new.cost_amount * v_quantity);
    new.total_sell_amount := (new.sell_price_amount * v_quantity);
    new.gross_profit_amount := ((new.sell_price_amount - new.cost_amount) * v_quantity);
  end if;

  -- For normal invoices
  if new.type = 'normal' and new.invoice_id is not null then
    select tenant_id into v_invoice_tenant_id
    from public.invoices
    where id = new.invoice_id;

    new.sold_in_tenant_id := coalesce(new.sold_in_tenant_id, v_invoice_tenant_id);
  end if;

  return new;
end;
$$;

commit;
