begin;

-- =========================================================
-- Redefine post_global_invoice to remove ledger writes
-- =========================================================
create or replace function public.post_global_invoice(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_qty_to_deduct integer;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft invoices can be posted';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  -- Validate required fields and profiles per invoice type
  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if v_invoice.cod_charge > 0 or v_invoice.wrapping_charge > 0 or v_invoice.print_charge > 0 then
      raise exception 'wholesale invoices only support shipping charges';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  -- Process line items: snapshot unit cost & deduct stock
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    -- 1. Snapshot landed cost
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;

    -- 2. Deduct quantities from allocations and parent stock
    v_qty_to_deduct := ceil(v_item.quantity)::integer;

    -- Decrement global stock pool
    update public.global_stocks
    set quantity = greatest(quantity - v_qty_to_deduct, 0)
    where id = v_item.global_stock_id;

    -- Decrement child tenant allocation if it exists
    if exists (
      select 1 from public.global_stock_allocations
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id
    ) then
      update public.global_stock_allocations
      set quantity = greatest(quantity - v_qty_to_deduct, 0)
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id;
    end if;
  end loop;

  -- Mark invoice as posted
  update public.global_invoices
  set invoice_status = 'posted'::public.global_invoice_status
  where id = p_invoice_id;
end;
$$;

-- =========================================================
-- Redefine void_global_invoice to remove ledger writes
-- =========================================================
create or replace function public.void_global_invoice(
  p_invoice_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_qty_to_restore integer;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'only posted invoices can be voided';
  end if;
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot void a paid or partially paid invoice; reverse collections/payments first';
  end if;

  -- Restore stock quantities
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_qty_to_restore := ceil(v_item.quantity)::integer;
    
    update public.global_stocks
    set quantity = quantity + v_qty_to_restore
    where id = v_item.global_stock_id;
    
    if exists (
      select 1 from public.global_stock_allocations
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id
    ) then
      update public.global_stock_allocations
      set quantity = quantity + v_qty_to_restore
      where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id;
    end if;
  end loop;

  -- Mark invoice as voided and zero out remaining due balance
  update public.global_invoices
  set
    invoice_status = 'voided'::public.global_invoice_status,
    due_amount = 0.00
  where id = p_invoice_id;
end;
$$;

-- =========================================================
-- Redefine add_global_return_item to remove ledger writes
-- =========================================================
create or replace function public.add_global_return_item(
  p_invoice_id bigint,
  p_invoice_item_id bigint,
  p_quantity numeric,
  p_return_face_amount numeric,
  p_return_accounting_amount numeric,
  p_return_charge_amount numeric default 0,
  p_note text default null
)
returns public.global_return_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_qty_to_restore integer;
begin
  -- Load and lock invoice
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot return items on a non-posted invoice';
  end if;

  -- Load and lock invoice item
  select * into v_item from public.global_invoice_items where id = p_invoice_item_id for update;
  if v_item.id is null then raise exception 'invoice item not found'; end if;
  if v_item.invoice_id <> p_invoice_id then
    raise exception 'invoice item does not belong to the selected invoice';
  end if;

  -- Check quantity limit
  if v_item.return_quantity + p_quantity > v_item.quantity then
    raise exception 'return quantity exceeds available item quantity';
  end if;

  -- Insert return record
  insert into public.global_return_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
    return_face_amount,
    return_accounting_amount,
    return_charge_amount,
    note
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_invoice_item_id,
    v_item.global_stock_id,
    p_quantity,
    p_return_face_amount,
    p_return_accounting_amount,
    coalesce(p_return_charge_amount, 0.00),
    nullif(trim(p_note), '')
  )
  returning * into v_row;

  -- Update snapshot return_quantity on invoice item
  update public.global_invoice_items
  set return_quantity = return_quantity + p_quantity
  where id = p_invoice_item_id;

  -- Restore stock
  v_qty_to_restore := ceil(p_quantity)::integer;
  
  update public.global_stocks
  set quantity = quantity + v_qty_to_restore
  where id = v_item.global_stock_id;
  
  if exists (
    select 1 from public.global_stock_allocations
    where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id
  ) then
    update public.global_stock_allocations
    set quantity = quantity + v_qty_to_restore
    where child_tenant_id = v_invoice.tenant_id and stock_id = v_item.global_stock_id;
  end if;

  -- Recompute totals (recompute_global_invoice_totals will call recompute_global_invoice_payment_status)
  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

-- =========================================================
-- Rewrite get_parent_cash_circulation
-- =========================================================
create or replace function public.get_parent_cash_circulation(
  p_parent_tenant_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_deposits numeric(12,2);
  v_withdrawals numeric(12,2);
  v_deployed numeric(12,2);
  v_ar_due numeric(12,2);
  v_ar_paid numeric(12,2);
  v_stock_cost numeric(12,2);
  v_profit_mtd numeric(12,2);
  v_payouts numeric(12,2);
begin
  if not public.user_can_manage_parent_tenant(p_parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Aligned capital deposit & adjustment types
  select
    coalesce(sum(case when type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_parent_tenant_id;

  -- Use allocated_cost / invested_amount
  select coalesce(sum(coalesce(allocated_cost, invested_amount)), 0) into v_deployed
  from public.shipment_investments
  where tenant_id = p_parent_tenant_id and status = 'active';

  select
    coalesce(sum(due_amount), 0),
    coalesce(sum(paid_amount), 0)
  into v_ar_due, v_ar_paid
  from public.global_invoices
  where parent_tenant_id = p_parent_tenant_id;

  select coalesce(sum(gs.cost * q.quantity), 0) into v_stock_cost
  from public.global_stocks gs
  inner join public.global_stock_quantities q on q.stock_id = gs.id
  where gs.parent_tenant_id = p_parent_tenant_id
    and q.status in ('excellent', 'box_less');

  -- Calculate profit MTD dynamically from invoices, items, and returns
  with invoice_line_margin as (
    select
      ii.invoice_id,
      sum((ii.sell_price_amount - ii.unit_cost_price) * ii.quantity - ii.line_discount_amount) as lines_margin
    from public.global_invoice_items ii
    join public.global_invoices i on i.id = ii.invoice_id
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ii.invoice_id
  ),
  invoice_return_margin as (
    select
      ri.invoice_id,
      sum(ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)) as returns_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    join public.global_invoices i on i.id = ri.invoice_id
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ri.invoice_id
  )
  select coalesce(sum(
    coalesce(lm.lines_margin, 0.00) 
      - i.discount_amount 
      + (case 
           when i.invoice_type = 'wholesale' or i.invoice_type = 'dropship' then i.shipping_charge
           when i.invoice_type = 'retail' then i.shipping_charge + i.cod_charge + i.print_charge + i.wrapping_charge
           else 0.00 
         end)
      - coalesce(rm.returns_margin, 0.00)
  ), 0) into v_profit_mtd
  from public.global_invoices i
  left join invoice_line_margin lm on lm.invoice_id = i.id
  left join invoice_return_margin rm on rm.invoice_id = i.id
  where i.parent_tenant_id = p_parent_tenant_id
    and i.invoice_status = 'posted'::public.global_invoice_status
    and i.invoice_date >= date_trunc('month', current_date)::date;

  -- Aligned profit payouts
  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where tenant_id = p_parent_tenant_id
    and type in ('profit_payout', 'profit_reinvest');

  return jsonb_build_object(
    'investor_capital_in', v_deposits,
    'investor_capital_withdrawn', v_withdrawals,
    'investor_capital_deployed', v_deployed,
    'investor_capital_available', v_deposits - v_withdrawals - v_deployed,
    'customer_ar_due', v_ar_due,
    'customer_ar_paid', v_ar_paid,
    'stock_cost_in_circulation', v_stock_cost,
    'realized_profit_mtd', v_profit_mtd,
    'profit_distributed', v_payouts
  );
end;
$$;

grant execute on function public.get_parent_cash_circulation(bigint) to authenticated;

-- =========================================================
-- Drop ledger-based helper RPCs
-- =========================================================
drop function if exists public.list_global_accounting_ledger(bigint, bigint, integer, integer) cascade;
drop function if exists public.list_global_accounting_ledger_by_shipment(bigint, bigint, integer, integer) cascade;

-- =========================================================
-- Drop ledger and rollup tables
-- =========================================================
drop table if exists public.global_shipment_accounting cascade;
drop table if exists public.global_invoice_accounting cascade;
drop table if exists public.global_accounting_ledger cascade;

commit;
