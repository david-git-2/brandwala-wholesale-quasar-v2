create or replace function public.apply_invoice_item_return(
  p_tenant_id bigint,
  p_invoice_item_id bigint,
  p_return_normal_quantity numeric,
  p_return_open_box_quantity numeric,
  p_return_amount numeric,
  p_actor uuid default null
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
  v_accounting public.inventory_accounting_entries;
  v_return_normal numeric(12,3) := greatest(coalesce(p_return_normal_quantity, 0), 0);
  v_return_open numeric(12,3) := greatest(coalesce(p_return_open_box_quantity, 0), 0);
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

  v_return_qty := v_return_normal + v_return_open;
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

  v_existing_return_qty := coalesce(v_item.return_normal_quantity, 0) + coalesce(v_item.return_open_box_quantity, 0);
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
      return_amount = v_next_return_amount,
      updated_at = now()
  where id = v_item.id;

  update public.inventory_stocks
  set available_quantity = coalesce(available_quantity, 0) + v_return_qty,
      open_box_quantity = coalesce(open_box_quantity, 0) + v_return_open,
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
      coalesce(v_stock.available_quantity, 0) + v_return_qty,
      format(
        'Invoice return on #%s (normal: %s, open box: %s)',
        v_invoice.invoice_no,
        v_return_normal,
        v_return_open
      ),
      p_actor
    );
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
    v_total_sell := greatest(0, coalesce(v_item.quantity, 0) * coalesce(v_item.sell_price_amount, 0) - v_next_return_amount);
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

grant execute on function public.apply_invoice_item_return(
  bigint,
  bigint,
  numeric,
  numeric,
  numeric,
  uuid
) to authenticated;
