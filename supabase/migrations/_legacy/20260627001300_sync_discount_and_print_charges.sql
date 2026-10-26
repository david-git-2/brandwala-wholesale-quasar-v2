-- Migration: Sync discount_amount and print_charge to commerce invoice accounting charges entry
begin;

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

  -- Calculate net charges amount (excluding discount to keep calculation unchanged)
  v_total_charges := coalesce(new.delivery_charge, 0) + coalesce(new.wrapping_charge, 0) + coalesce(new.cod, 0) + coalesce(new.print_charge, 0);

  -- Maintain the entry if tenant_id is set and any charge or discount is non-zero
  if v_tenant_id is not null and (
     coalesce(new.delivery_charge, 0) <> 0 or 
     coalesce(new.wrapping_charge, 0) <> 0 or 
     coalesce(new.cod, 0) <> 0 or
     coalesce(new.print_charge, 0) <> 0 or
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
      print_charge,
      discount_amount,
      is_charges
    )
    values (
      'commerce',
      v_tenant_id,
      new.id,
      null,
      null,
      0, -- quantity is 0 for charges
      0,
      v_total_charges,
      0,
      v_total_charges,
      v_total_charges,
      case when new.is_customer_group_paid then 'paid'::text else 'due'::text end,
      v_shipment_id,
      coalesce(new.invoice_date, current_date),
      'Invoice Charges',
      coalesce(new.delivery_charge, 0),
      coalesce(new.wrapping_charge, 0),
      coalesce(new.cod, 0),
      coalesce(new.print_charge, 0),
      coalesce(new.discount_amount, 0),
      true -- denotes this is charges entry
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
      print_charge = excluded.print_charge,
      discount_amount = excluded.discount_amount,
      quantity = 0,
      is_charges = true,
      updated_at = now();
  else
    -- Delete the charges entry if all charges/discounts are zero
    delete from public.inventory_accounting_entries
    where commerce_invoice_id = new.id
      and type = 'commerce'
      and inventory_item_id is null;
  end if;

  return new;
end;
$$;

-- Sync existing invoice charges entries to set discount_amount and print_charge
update public.inventory_accounting_entries iae
set discount_amount = coalesce(ci.discount_amount, 0),
    print_charge = coalesce(ci.print_charge, 0),
    sell_price_amount = coalesce(ci.delivery_charge, 0) + coalesce(ci.wrapping_charge, 0) + coalesce(ci.cod, 0) + coalesce(ci.print_charge, 0),
    total_sell_amount = coalesce(ci.delivery_charge, 0) + coalesce(ci.wrapping_charge, 0) + coalesce(ci.cod, 0) + coalesce(ci.print_charge, 0),
    gross_profit_amount = coalesce(ci.delivery_charge, 0) + coalesce(ci.wrapping_charge, 0) + coalesce(ci.cod, 0) + coalesce(ci.print_charge, 0)
from public.commerce_invoices ci
where iae.commerce_invoice_id = ci.id
  and iae.type = 'commerce'
  and iae.inventory_item_id is null;

commit;
