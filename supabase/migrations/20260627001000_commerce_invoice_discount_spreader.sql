-- Migration: Commerce Invoice Discount Spreader and Charges accounting adjustment
begin;

-- 1. Redefine fn_sync_commerce_invoice_charges_to_accounting to exclude discounts from separate charges entry
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

  -- Calculate net charges amount (excluding discount_amount now!)
  v_total_charges := coalesce(new.delivery_charge, 0) + coalesce(new.wrapping_charge, 0) + coalesce(new.cod, 0);

  -- Only maintain the entry if tenant_id is set and charges are non-zero
  if v_tenant_id is not null and (
     coalesce(new.delivery_charge, 0) <> 0 or 
     coalesce(new.wrapping_charge, 0) <> 0 or 
     coalesce(new.cod, 0) <> 0
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
      'Invoice Charges',
      coalesce(new.delivery_charge, 0),
      coalesce(new.wrapping_charge, 0),
      coalesce(new.cod, 0),
      0.00 -- discount is 0 on the separate charges entry
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
      discount_amount = 0.00,
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

-- 2. Create the Commerce Invoice Discount Spreader Trigger function
create or replace function public.trg_fn_spread_commerce_invoice_discount()
returns trigger
language plpgsql
security definer
as $$
declare
  v_item record;
  v_total_distributed numeric(12,2) := 0;
  v_item_count integer := 0;
  v_current_index integer := 0;
  v_line_discount numeric(12,2);
  v_line_subtotal numeric(12,2);
  v_total_quantity numeric(12,3) := 0;
begin
  -- Get total number of items and total quantity
  select count(*), coalesce(sum(quantity), 0)
  into v_item_count, v_total_quantity
  from public.commerce_order_items
  where invoice_id = NEW.id;

  if v_item_count = 0 or v_total_quantity <= 0 then
    return NEW;
  end if;

  -- Loop through items ordered by ID
  for v_item in (
    select id, quantity, recipient_price_bdt, cost_bdt
    from public.commerce_order_items
    where invoice_id = NEW.id
    order by id asc
  ) loop
    v_current_index := v_current_index + 1;
    v_line_subtotal := v_item.quantity * v_item.recipient_price_bdt;

    if v_current_index = v_item_count then
      -- For the last item, assign all remaining discount to prevent rounding issues
      v_line_discount := greatest(0, coalesce(NEW.discount_amount, 0) - v_total_distributed);
    else
      v_line_discount := round((v_item.quantity / v_total_quantity) * coalesce(NEW.discount_amount, 0), 2);
      v_total_distributed := v_total_distributed + v_line_discount;
    end if;

    -- Ensure line discount doesn't exceed line subtotal
    v_line_discount := least(v_line_subtotal, v_line_discount);

    -- Update corresponding inventory_accounting_entries
    update public.inventory_accounting_entries
    set total_sell_amount = greatest(0, round(v_line_subtotal - v_line_discount, 2)),
        recipient_sell_price_amount = case when quantity > 0 then greatest(0, round((v_line_subtotal - v_line_discount) / quantity, 2)) else recipient_sell_price_amount end,
        gross_profit_amount = greatest(0, round(v_line_subtotal - v_line_discount, 2)) - coalesce(total_cost_amount, 0),
        updated_at = now()
    where commerce_order_item_id = v_item.id;
  end loop;

  return NEW;
end;
$$;

-- 3. Create AFTER INSERT OR UPDATE trigger on commerce_invoices for discount spreading
drop trigger if exists trg_commerce_invoice_discount_spreader on public.commerce_invoices;
create trigger trg_commerce_invoice_discount_spreader
after insert or update on public.commerce_invoices
for each row
execute function public.trg_fn_spread_commerce_invoice_discount();

commit;
