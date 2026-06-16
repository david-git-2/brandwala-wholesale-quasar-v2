-- Migration: Add Invoice Charges to Accounting entries
begin;

-- 1. Drop NOT NULL constraint on inventory_item_id to allow invoice-level entries
alter table public.inventory_accounting_entries
  alter column inventory_item_id drop not null;

-- 2. Add charge-specific columns to inventory_accounting_entries
alter table public.inventory_accounting_entries
  add column if not exists delivery_charge numeric(12, 2) not null default 0.00,
  add column if not exists wrapping_charge numeric(12, 2) not null default 0.00,
  add column if not exists cod numeric(12, 2) not null default 0.00,
  add column if not exists discount_amount numeric(12, 2) not null default 0.00;

-- 3. Create unique index for the invoice charges row to enable UPSERT
create unique index if not exists inventory_accounting_entries_commerce_invoice_charges_unique_idx
  on public.inventory_accounting_entries (commerce_invoice_id)
  where (type = 'commerce' and inventory_item_id is null);

-- 4. Create trigger function to sync invoice charges
create or replace function public.fn_sync_commerce_invoice_charges_to_accounting()
returns trigger
language plpgsql
security definer
as $$
declare
  v_shipment_id bigint;
  v_total_charges numeric;
  v_tenant_id bigint;
begin
  v_tenant_id := new.tenant_id;

  -- Resolve shipment_id: query the first order item's shipment_id
  select si.shipment_id into v_shipment_id
  from public.commerce_order_items coi
  join public.shipment_items si on si.id = coi.shipment_item_id
  where coi.invoice_id = new.id
  limit 1;

  -- Calculate net charges amount (delivery + wrapping + cod - discount)
  v_total_charges := coalesce(new.delivery_charge, 0) + coalesce(new.wrapping_charge, 0) + coalesce(new.cod, 0) - coalesce(new.discount_amount, 0);

  -- Only maintain the entry if tenant_id is set and charges/discounts are non-zero
  if v_tenant_id is not null and (
     coalesce(new.delivery_charge, 0) <> 0 or 
     coalesce(new.wrapping_charge, 0) <> 0 or 
     coalesce(new.cod, 0) <> 0 or 
     coalesce(new.discount_amount, 0) <> 0
  ) then
    insert into public.inventory_accounting_entries (
      type,
      tenant_id,
      commerce_invoice_id,
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
      entry_date,
      note,
      delivery_charge,
      wrapping_charge,
      cod,
      discount_amount
    )
    values (
      'commerce',
      v_tenant_id,
      new.id,
      null,
      null,
      1,
      0,
      v_total_charges,
      0,
      v_total_charges,
      v_total_charges,
      case when new.is_customer_group_paid then 'paid'::text else 'due'::text end,
      v_shipment_id,
      coalesce(new.invoice_date, current_date),
      'Invoice Charges & Discounts',
      coalesce(new.delivery_charge, 0),
      coalesce(new.wrapping_charge, 0),
      coalesce(new.cod, 0),
      coalesce(new.discount_amount, 0)
    )
    on conflict (commerce_invoice_id) where (type = 'commerce' and inventory_item_id is null)
    do update set
      tenant_id = excluded.tenant_id,
      sell_price_amount = excluded.sell_price_amount,
      total_sell_amount = excluded.total_sell_amount,
      gross_profit_amount = excluded.gross_profit_amount,
      status = excluded.status,
      shipment_id = coalesce(excluded.shipment_id, inventory_accounting_entries.shipment_id),
      entry_date = excluded.entry_date,
      delivery_charge = excluded.delivery_charge,
      wrapping_charge = excluded.wrapping_charge,
      cod = excluded.cod,
      discount_amount = excluded.discount_amount,
      updated_at = now();
  else
    -- Delete the charges entry if all charges are zero
    delete from public.inventory_accounting_entries
    where commerce_invoice_id = new.id
      and type = 'commerce'
      and inventory_item_id is null;
  end if;

  return new;
end;
$$;

-- 5. Create trigger on commerce_invoices
drop trigger if exists trg_sync_commerce_invoice_charges on public.commerce_invoices;
create trigger trg_sync_commerce_invoice_charges
after insert or update on public.commerce_invoices
for each row
execute function public.fn_sync_commerce_invoice_charges_to_accounting();

-- 6. Recreate the simplified view to include new columns
drop view if exists public.v_shipment_accounting_ledger;
create or replace view public.v_shipment_accounting_ledger
with (security_invoker = true) as
select
  type,
  id,
  tenant_id,
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
  created_at,
  delivery_charge,
  wrapping_charge,
  cod,
  discount_amount
from public.inventory_accounting_entries;

-- 7. Backfill existing commerce invoices
insert into public.inventory_accounting_entries (
  type,
  tenant_id,
  commerce_invoice_id,
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
  entry_date,
  note,
  delivery_charge,
  wrapping_charge,
  cod,
  discount_amount
)
select
  'commerce',
  ci.tenant_id,
  ci.id,
  null,
  null,
  1,
  0,
  (coalesce(ci.delivery_charge, 0) + coalesce(ci.wrapping_charge, 0) + coalesce(ci.cod, 0) - coalesce(ci.discount_amount, 0)),
  0,
  (coalesce(ci.delivery_charge, 0) + coalesce(ci.wrapping_charge, 0) + coalesce(ci.cod, 0) - coalesce(ci.discount_amount, 0)),
  (coalesce(ci.delivery_charge, 0) + coalesce(ci.wrapping_charge, 0) + coalesce(ci.cod, 0) - coalesce(ci.discount_amount, 0)),
  case when ci.is_customer_group_paid then 'paid'::text else 'due'::text end,
  (
    select si.shipment_id
    from public.commerce_order_items coi
    join public.shipment_items si on si.id = coi.shipment_item_id
    where coi.invoice_id = ci.id
    limit 1
  ),
  coalesce(ci.invoice_date, current_date),
  'Invoice Charges & Discounts',
  coalesce(ci.delivery_charge, 0),
  coalesce(ci.wrapping_charge, 0),
  coalesce(ci.cod, 0),
  coalesce(ci.discount_amount, 0)
from public.commerce_invoices ci
where (
  coalesce(ci.delivery_charge, 0) <> 0 or 
  coalesce(ci.wrapping_charge, 0) <> 0 or 
  coalesce(ci.cod, 0) <> 0 or 
  coalesce(ci.discount_amount, 0) <> 0
)
on conflict (commerce_invoice_id) where (type = 'commerce' and inventory_item_id is null)
do nothing;

commit;
