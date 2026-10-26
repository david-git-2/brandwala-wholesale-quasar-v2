-- Migration: Optimize Commerce Invoice Totals Recalculation via Trigger
begin;

-- 1. Create the trigger function to automatically calculate invoice totals and sync order charges
create or replace function public.fn_recalculate_commerce_invoice_totals()
returns trigger
language plpgsql
security definer
as $$
declare
  v_subtotal numeric;
  v_is_delivery_charge_inclusive boolean;
begin
  -- 1. Calculate subtotal from commerce_order_items
  select coalesce(sum(quantity * recipient_price_bdt), 0)
  into v_subtotal
  from public.commerce_order_items
  where invoice_id = new.id;

  -- 2. Fetch order delivery inclusive flag
  select is_delivery_charge_inclusive
  into v_is_delivery_charge_inclusive
  from public.commerce_orders
  where id = new.order_id;

  v_is_delivery_charge_inclusive := coalesce(v_is_delivery_charge_inclusive, false);

  -- 3. Calculate total_amount
  if v_is_delivery_charge_inclusive then
    new.total_amount := greatest(0, v_subtotal + coalesce(new.wrapping_charge, 0) + coalesce(new.cod, 0) + coalesce(new.print_charge, 0) - coalesce(new.discount_amount, 0));
  else
    new.total_amount := greatest(0, v_subtotal + coalesce(new.delivery_charge, 0) + coalesce(new.wrapping_charge, 0) + coalesce(new.cod, 0) + coalesce(new.print_charge, 0) - coalesce(new.discount_amount, 0));
  end if;

  -- 4. Calculate amount_due and payment status
  new.amount_due := greatest(0, new.total_amount - coalesce(new.amount_paid, 0));
  new.is_customer_group_paid := coalesce(new.amount_paid, 0) >= new.total_amount;

  -- 5. Update commerce_orders charges & shipment_payment
  update public.commerce_orders
  set delivery_charge = coalesce(new.delivery_charge, 0),
      wrapping_charge = coalesce(new.wrapping_charge, 0),
      cod = coalesce(new.cod, 0),
      invoice_print_charge = coalesce(new.print_charge, 0),
      shipment_payment = new.total_amount
  where id = new.order_id;

  return new;
end;
$$;

-- 2. Create the BEFORE INSERT OR UPDATE trigger on commerce_invoices
drop trigger if exists trg_recalculate_commerce_invoice_totals on public.commerce_invoices;
create trigger trg_recalculate_commerce_invoice_totals
before insert or update on public.commerce_invoices
for each row
execute function public.fn_recalculate_commerce_invoice_totals();

commit;
