-- Migration: Equal Invoice Discount Spreader
begin;

create or replace function public.trg_fn_spread_invoice_discount()
returns trigger
language plpgsql
security definer
as $$
declare
  v_item record;
  v_remaining_discount numeric(12,2) := coalesce(NEW.discount_amount, 0);
  v_item_count integer := 0;
  v_active_count integer;
  v_share numeric(12,2);
  v_actual_share numeric(12,2);
  v_iterations integer := 0;
begin
  -- Get total number of items
  select count(*) into v_item_count
  from public.invoice_items
  where invoice_id = NEW.id;

  if v_item_count = 0 or coalesce(NEW.subtotal_amount, 0) <= 0 or v_remaining_discount <= 0 then
    update public.invoice_items
    set line_discount_amount = 0,
        line_total_amount = round(quantity * sell_price_amount, 2),
        updated_at = now()
    where invoice_id = NEW.id;
    return NEW;
  end if;

  -- Create temp table to hold items and their discount
  drop table if exists temp_discount_items;
  create temp table temp_discount_items (
    id bigint primary key,
    subtotal numeric(12,2) not null,
    discount numeric(12,2) not null default 0.00,
    capped boolean not null default false
  ) on commit drop;

  insert into temp_discount_items (id, subtotal)
  select id, round(quantity * sell_price_amount, 2)
  from public.invoice_items
  where invoice_id = NEW.id;

  -- Distribute remaining discount iteratively
  while v_remaining_discount > 0 and v_iterations < 50 loop
    v_iterations := v_iterations + 1;
    
    select count(*) into v_active_count
    from temp_discount_items
    where not capped and subtotal > discount;

    if v_active_count = 0 then
      exit;
    end if;

    -- Share is the remaining discount divided by active items
    v_share := round(v_remaining_discount / v_active_count, 2);

    for v_item in (
      select id, subtotal, discount
      from temp_discount_items
      where not capped and subtotal > discount
      order by id asc
    ) loop
      -- Update active count within loop to check if this is the last active item
      select count(*) into v_active_count
      from temp_discount_items
      where not capped and subtotal > discount;

      if v_active_count = 1 then
        v_share := v_remaining_discount;
      end if;

      v_actual_share := least(v_share, v_item.subtotal - v_item.discount);
      
      update temp_discount_items
      set discount = discount + v_actual_share,
          capped = case when (discount + v_actual_share) >= subtotal then true else false end
      where id = v_item.id;

      v_remaining_discount := v_remaining_discount - v_actual_share;
      
      if v_remaining_discount <= 0 then
        exit;
      end if;
    end loop;
  end loop;

  -- Update actual invoice_items and inventory_accounting_entries
  for v_item in (
    select ii.id, ii.quantity, ii.sell_price_amount, ii.cost_amount, ii.return_amount, tdi.discount,
           (ii.quantity * ii.sell_price_amount) as line_subtotal
    from public.invoice_items ii
    join temp_discount_items tdi on tdi.id = ii.id
    where ii.invoice_id = NEW.id
  ) loop
    update public.invoice_items
    set line_discount_amount = v_item.discount,
        line_total_amount = round(v_item.line_subtotal - v_item.discount, 2),
        updated_at = now()
    where id = v_item.id;

    update public.inventory_accounting_entries
    set total_sell_amount = greatest(0, round(v_item.line_subtotal - v_item.discount - coalesce(v_item.return_amount, 0), 2)),
        sell_price_amount = case when v_item.quantity > 0 then greatest(0, round((v_item.line_subtotal - v_item.discount) / v_item.quantity, 2)) else sell_price_amount end,
        gross_profit_amount = greatest(0, round(v_item.line_subtotal - v_item.discount - coalesce(v_item.return_amount, 0), 2)) - coalesce(total_cost_amount, 0),
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
