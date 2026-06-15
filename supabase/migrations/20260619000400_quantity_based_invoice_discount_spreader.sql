-- Migration: Quantity-based Invoice Discount Spreader
begin;

create or replace function public.trg_fn_spread_invoice_discount()
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
  from public.invoice_items
  where invoice_id = NEW.id;

  if v_item_count = 0 or v_total_quantity <= 0 or coalesce(NEW.subtotal_amount, 0) <= 0 then
    update public.invoice_items
    set line_discount_amount = 0,
        line_total_amount = round(quantity * sell_price_amount, 2),
        updated_at = now()
    where invoice_id = NEW.id;
    return NEW;
  end if;

  -- Loop through items ordered by ID
  for v_item in (
    select id, quantity, sell_price_amount, cost_amount, return_normal_quantity, return_open_box_quantity, return_damaged_quantity, return_amount
    from public.invoice_items
    where invoice_id = NEW.id
    order by id asc
  ) loop
    v_current_index := v_current_index + 1;
    v_line_subtotal := v_item.quantity * v_item.sell_price_amount;

    if v_current_index = v_item_count then
      -- For the last item, assign all remaining discount to prevent rounding issues
      v_line_discount := greatest(0, NEW.discount_amount - v_total_distributed);
    else
      v_line_discount := round((v_item.quantity / v_total_quantity) * NEW.discount_amount, 2);
      v_total_distributed := v_total_distributed + v_line_discount;
    end if;

    -- Ensure line discount doesn't exceed line subtotal to prevent violating check constraints
    v_line_discount := least(v_line_subtotal, v_line_discount);

    update public.invoice_items
    set line_discount_amount = v_line_discount,
        line_total_amount = round(v_line_subtotal - v_line_discount, 2),
        updated_at = now()
    where id = v_item.id;

    -- Update corresponding inventory_accounting_entries
    -- Sell price is realized unit price after discount: (line_subtotal - line_discount) / quantity
    -- Total sell amount is net of returns and line discount: (v_item.sell_price_amount * quantity) - v_line_discount - return_amount
    update public.inventory_accounting_entries
    set total_sell_amount = greatest(0, round(v_line_subtotal - v_line_discount - coalesce(v_item.return_amount, 0), 2)),
        sell_price_amount = case when v_item.quantity > 0 then greatest(0, round((v_line_subtotal - v_line_discount) / v_item.quantity, 2)) else sell_price_amount end,
        gross_profit_amount = greatest(0, round(v_line_subtotal - v_line_discount - coalesce(v_item.return_amount, 0), 2)) - coalesce(total_cost_amount, 0),
        updated_at = now()
    where invoice_item_id = v_item.id;
  end loop;

  return NEW;
end;
$$;

drop trigger if exists trg_invoice_discount_spreader on public.invoices;
create trigger trg_invoice_discount_spreader
after update of discount_amount, subtotal_amount on public.invoices
for each row
execute function public.trg_fn_spread_invoice_discount();

commit;
