-- Migration: Invoice Payments, Discount Spreading, and Returns Policy
begin;

-- 1. Add discount_amount to commerce_invoices table
alter table public.commerce_invoices
  add column if not exists discount_amount numeric(12,2) not null default 0.00 check (discount_amount >= 0);

-- 2. Commerce Invoice Payment Status Sync Trigger
create or replace function public.trg_fn_sync_commerce_invoice_payment_status()
returns trigger
language plpgsql
security definer
as $$
begin
  update public.commerce_accounting
  set is_customer_group_paid = NEW.is_customer_group_paid,
      updated_at = now()
  where order_item_id in (
    select id from public.commerce_order_items
    where invoice_id = NEW.id
  );
  return NEW;
end;
$$;

drop trigger if exists trg_commerce_invoice_payment_status_sync on public.commerce_invoices;
create trigger trg_commerce_invoice_payment_status_sync
after insert or update of is_customer_group_paid on public.commerce_invoices
for each row
execute function public.trg_fn_sync_commerce_invoice_payment_status();

-- 3. Normal Invoice Discount Spreader Trigger
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
begin
  -- Get total number of items
  select count(*) into v_item_count
  from public.invoice_items
  where invoice_id = NEW.id;

  if v_item_count = 0 or coalesce(NEW.subtotal_amount, 0) <= 0 then
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
      v_line_discount := round((v_line_subtotal / NEW.subtotal_amount) * NEW.discount_amount, 2);
      v_total_distributed := v_total_distributed + v_line_discount;
    end if;

    update public.invoice_items
    set line_discount_amount = v_line_discount,
        line_total_amount = round(v_line_subtotal - v_line_discount, 2),
        updated_at = now()
    where id = v_item.id;

    -- Update corresponding inventory_accounting_entries
    -- Sell price is realized unit price before return: (line_subtotal - line_discount) / total_sold_qty
    -- Total sell amount is net of returns and line discount: (v_item.sell_price_amount * quantity) - v_line_discount - return_amount
    update public.inventory_accounting_entries
    set total_sell_amount = greatest(0, round((v_item.quantity * v_item.sell_price_amount) - v_line_discount - coalesce(v_item.return_amount, 0), 2)),
        sell_price_amount = case when v_item.quantity > 0 then greatest(0, round(((v_item.quantity * v_item.sell_price_amount) - v_line_discount) / v_item.quantity, 2)) else sell_price_amount end,
        gross_profit_amount = greatest(0, round((v_item.quantity * v_item.sell_price_amount) - v_line_discount - coalesce(v_item.return_amount, 0), 2)) - coalesce(total_cost_amount, 0),
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

-- 4. Commerce Invoice Discount Spreader Trigger
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
  v_subtotal numeric(12,2) := 0;
begin
  -- Compute the commerce invoice subtotal
  select coalesce(sum(quantity * recipient_price_bdt), 0)
  into v_subtotal
  from public.commerce_order_items
  where invoice_id = NEW.id;

  select count(*) into v_item_count
  from public.commerce_order_items
  where invoice_id = NEW.id;

  if v_item_count = 0 or v_subtotal <= 0 then
    update public.commerce_accounting ca
    set sell_price_bdt = coi.sell_price_bdt,
        updated_at = now()
    from public.commerce_order_items coi
    where coi.id = ca.order_item_id
      and coi.invoice_id = NEW.id;
    return NEW;
  end if;

  -- Loop through items
  for v_item in (
    select id, quantity, sell_price_bdt, recipient_price_bdt
    from public.commerce_order_items
    where invoice_id = NEW.id
    order by id asc
  ) loop
    v_current_index := v_current_index + 1;
    v_line_subtotal := v_item.quantity * v_item.recipient_price_bdt;

    if v_current_index = v_item_count then
      v_line_discount := greatest(0, NEW.discount_amount - v_total_distributed);
    else
      v_line_discount := round((v_line_subtotal / v_subtotal) * NEW.discount_amount, 2);
      v_total_distributed := v_total_distributed + v_line_discount;
    end if;

    update public.commerce_accounting
    set sell_price_bdt = greatest(0, round(((v_item.sell_price_bdt * v_item.quantity) - v_line_discount) / v_item.quantity, 2)),
        updated_at = now()
    where order_item_id = v_item.id;
  end loop;

  return NEW;
end;
$$;

drop trigger if exists trg_commerce_invoice_discount_spreader on public.commerce_invoices;
create trigger trg_commerce_invoice_discount_spreader
after update of discount_amount on public.commerce_invoices
for each row
execute function public.trg_fn_spread_commerce_invoice_discount();

-- 5. Unified View for Shipment Accounting Ledger
create or replace view public.v_shipment_accounting_ledger as
select
  'normal'::text as type,
  iae.id,
  iae.tenant_id,
  iae.invoice_id,
  iae.invoice_item_id,
  iae.inventory_item_id,
  iae.product_id,
  iae.quantity,
  iae.cost_amount,
  iae.sell_price_amount,
  iae.total_cost_amount,
  iae.total_sell_amount,
  iae.gross_profit_amount,
  iae.status,
  iae.shipment_id,
  iae.shipment_item_id,
  iae.entry_date,
  iae.note,
  iae.created_at
from public.inventory_accounting_entries iae

union all

select
  'commerce'::text as type,
  ca.id,
  ca.tenant_id,
  coi.invoice_id,
  null::bigint as invoice_item_id,
  ca.inventory_item_id,
  coi.product_id,
  coi.quantity::numeric(12,3) as quantity,
  ca.cost_bdt as cost_amount,
  ca.sell_price_bdt as sell_price_amount,
  (ca.cost_bdt * coi.quantity) as total_cost_amount,
  (ca.sell_price_bdt * coi.quantity) as total_sell_amount,
  ((ca.sell_price_bdt - ca.cost_bdt) * coi.quantity) as gross_profit_amount,
  case when ca.is_customer_group_paid then 'paid'::text else 'due'::text end as status,
  si.shipment_id,
  ca.shipment_item_id,
  ca.created_at::date as entry_date,
  'Commerce Invoice Item'::text as note,
  ca.created_at
from public.commerce_accounting ca
join public.commerce_order_items coi on coi.id = ca.order_item_id
left join public.shipment_items si on si.id = ca.shipment_item_id;

grant select on table public.v_shipment_accounting_ledger to authenticated;

-- 6. Redefine apply_invoice_item_return RPC to support flexible returned stock grouping
drop function if exists public.apply_invoice_item_return(bigint, bigint, numeric, numeric, numeric, uuid);
drop function if exists public.apply_invoice_item_return(bigint, bigint, numeric, numeric, numeric, numeric, text, uuid);

create or replace function public.apply_invoice_item_return(
  p_tenant_id bigint,
  p_invoice_item_id bigint,
  p_return_normal_quantity numeric,
  p_return_open_box_quantity numeric,
  p_return_damaged_quantity numeric,
  p_return_amount numeric,
  p_note text default null,
  p_actor uuid default null,
  p_return_to_new_batch boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.invoice_items;
  v_invoice public.invoices;
  v_stock public.inventory_stocks;
  v_orig_item public.inventory_items;
  v_accounting public.inventory_accounting_entries;
  v_return_normal numeric(12,3) := greatest(coalesce(p_return_normal_quantity, 0), 0);
  v_return_open numeric(12,3) := greatest(coalesce(p_return_open_box_quantity, 0), 0);
  v_return_damaged numeric(12,3) := greatest(coalesce(p_return_damaged_quantity, 0), 0);
  v_return_amount numeric(12,2) := greatest(coalesce(p_return_amount, 0), 0);
  v_return_qty numeric(12,3);
  v_existing_return_qty numeric(12,3);
  v_next_return_qty numeric(12,3);
  v_next_return_amount numeric(12,2);
  v_max_sell_amount numeric(12,2);
  v_net_quantity numeric(12,3);
  v_total_sell numeric(12,2);
  v_total_cost numeric(12,2);
  v_subtotal numeric(12,2);
  v_total numeric(12,2);
  v_movement_id bigint;
  v_new_item_id bigint;
  v_new_stock_id bigint;
begin
  if p_tenant_id is null or p_invoice_item_id is null then
    raise exception 'Tenant and invoice item are required.';
  end if;

  if not exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  ) then
    raise exception 'Not authorized to apply invoice return.';
  end if;

  v_return_qty := v_return_normal + v_return_open + v_return_damaged;
  if v_return_qty <= 0 and v_return_amount <= 0 then
    raise exception 'Return quantity or return amount must be greater than zero.';
  end if;

  select *
  into v_item
  from public.invoice_items
  where id = p_invoice_item_id
    and tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'Invoice item not found.';
  end if;

  if v_item.inventory_item_id is null then
    raise exception 'Inventory item is missing for this invoice item.';
  end if;

  select *
  into v_invoice
  from public.invoices
  where id = v_item.invoice_id
    and tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'Invoice not found.';
  end if;

  select *
  into v_stock
  from public.inventory_stocks
  where inventory_item_id = v_item.inventory_item_id
  for update;

  if not found then
    raise exception 'Stock record not found.';
  end if;

  v_existing_return_qty := coalesce(v_item.return_normal_quantity, 0) + coalesce(v_item.return_open_box_quantity, 0) + coalesce(v_item.return_damaged_quantity, 0);
  v_next_return_qty := v_existing_return_qty + v_return_qty;
  if v_next_return_qty > coalesce(v_item.quantity, 0) then
    raise exception 'Return quantity exceeds sold quantity.';
  end if;

  v_next_return_amount := coalesce(v_item.return_amount, 0) + v_return_amount;
  v_max_sell_amount := coalesce(v_item.quantity, 0) * coalesce(v_item.sell_price_amount, 0);
  if v_next_return_amount > v_max_sell_amount then
    raise exception 'Return amount exceeds sold amount.';
  end if;

  update public.invoice_items
  set return_normal_quantity = coalesce(return_normal_quantity, 0) + v_return_normal,
      return_open_box_quantity = coalesce(return_open_box_quantity, 0) + v_return_open,
      return_damaged_quantity = coalesce(return_damaged_quantity, 0) + v_return_damaged,
      return_amount = v_next_return_amount,
      updated_at = now()
  where id = v_item.id;

  if p_return_to_new_batch then
    -- Create new inventory batch group
    select * into v_orig_item
    from public.inventory_items
    where id = v_item.inventory_item_id;

    insert into public.inventory_items (
      tenant_id,
      source_type,
      source_id,
      name,
      image_url,
      cost,
      manufacturing_date,
      expire_date,
      status
    )
    values (
      v_orig_item.tenant_id,
      v_orig_item.source_type,
      v_orig_item.source_id,
      v_orig_item.name || ' returned',
      v_orig_item.image_url,
      v_orig_item.cost,
      v_orig_item.manufacturing_date,
      v_orig_item.expire_date,
      'active'
    )
    returning id into v_new_item_id;

    insert into public.inventory_stocks (
      inventory_item_id,
      available_quantity,
      reserved_quantity,
      damaged_quantity,
      stolen_quantity,
      expired_quantity,
      open_box_quantity
    )
    values (
      v_new_item_id,
      v_return_normal,
      0,
      v_return_damaged,
      0,
      0,
      v_return_open
    )
    returning id into v_new_stock_id;

    if v_return_qty > 0 then
      insert into public.inventory_movements (
        inventory_item_id,
        type,
        quantity,
        previous_quantity,
        new_quantity,
        note,
        created_by
      )
      values (
        v_new_item_id,
        'received',
        v_return_qty,
        0,
        v_return_qty,
        format(
          'Received invoice return on #%s to new batch (normal: %s, open box: %s, damaged: %s)',
          v_invoice.invoice_no,
          v_return_normal,
          v_return_open,
          v_return_damaged
        ),
        p_actor
      )
      returning id into v_movement_id;

      if p_note is not null and length(trim(p_note)) > 0 then
        insert into public.inventory_notes (
          tenant_id,
          inventory_item_id,
          movement_id,
          category,
          content,
          created_by
        )
        values (
          p_tenant_id,
          v_new_item_id,
          v_movement_id,
          'return_reason',
          trim(p_note),
          p_actor
        );
      end if;
    end if;

  else
    -- Normal return to existing batch (fixing double-counting by setting disjoint pool sums)
    update public.inventory_stocks
    set available_quantity = coalesce(available_quantity, 0) + v_return_normal,
        open_box_quantity = coalesce(open_box_quantity, 0) + v_return_open,
        damaged_quantity = coalesce(damaged_quantity, 0) + v_return_damaged,
        updated_at = now()
    where id = v_stock.id;

    if v_return_qty > 0 then
      insert into public.inventory_movements (
        inventory_item_id,
        type,
        quantity,
        previous_quantity,
        new_quantity,
        note,
        created_by
      )
      values (
        v_item.inventory_item_id,
        'adjustment',
        v_return_qty,
        coalesce(v_stock.available_quantity, 0),
        coalesce(v_stock.available_quantity, 0) + v_return_normal, -- new available quantity represents normal pool
        format(
          'Invoice return on #%s (normal: %s, open box: %s, damaged: %s)',
          v_invoice.invoice_no,
          v_return_normal,
          v_return_open,
          v_return_damaged
        ),
        p_actor
      )
      returning id into v_movement_id;

      if p_note is not null and length(trim(p_note)) > 0 then
        insert into public.inventory_notes (
          tenant_id,
          inventory_item_id,
          movement_id,
          category,
          content,
          created_by
        )
        values (
          p_tenant_id,
          v_item.inventory_item_id,
          v_movement_id,
          'return_reason',
          trim(p_note),
          p_actor
        );
      end if;
    end if;
  end if;

  select *
  into v_accounting
  from public.inventory_accounting_entries
  where tenant_id = p_tenant_id
    and invoice_item_id = v_item.id
  order by id desc
  limit 1
  for update;

  if found then
    v_net_quantity := greatest(0, coalesce(v_item.quantity, 0) - v_next_return_qty);
    -- Sync accounting with current return quantities & amounts
    v_total_sell := greatest(0, coalesce(v_item.quantity, 0) * coalesce(v_item.sell_price_amount, 0) - coalesce(v_item.line_discount_amount, 0) - v_next_return_amount);
    v_total_cost := v_net_quantity * coalesce(v_item.cost_amount, 0);

    update public.inventory_accounting_entries
    set quantity = v_net_quantity,
        return_quantity = v_next_return_qty,
        return_amount = v_next_return_amount,
        total_sell_amount = v_total_sell,
        total_cost_amount = v_total_cost,
        gross_profit_amount = v_total_sell - v_total_cost,
        updated_at = now()
    where id = v_accounting.id;
  end if;

  select coalesce(
    sum(greatest(0, coalesce(quantity, 0) * coalesce(sell_price_amount, 0) - coalesce(return_amount, 0))),
    0
  )
  into v_subtotal
  from public.invoice_items
  where invoice_id = v_invoice.id;

  v_total := greatest(0, v_subtotal - coalesce(v_invoice.discount_amount, 0));

  update public.invoices
  set subtotal_amount = v_subtotal,
      total_amount = v_total,
      updated_at = now()
  where id = v_invoice.id;

  perform public.recompute_invoice_payment_status(v_invoice.id);

  return jsonb_build_object(
    'invoice_id', v_invoice.id,
    'invoice_item_id', v_item.id,
    'return_quantity', v_next_return_qty,
    'return_amount', v_next_return_amount
  );
end;
$$;

grant execute on function public.apply_invoice_item_return(bigint, bigint, numeric, numeric, numeric, numeric, text, uuid, boolean) to authenticated;

commit;
