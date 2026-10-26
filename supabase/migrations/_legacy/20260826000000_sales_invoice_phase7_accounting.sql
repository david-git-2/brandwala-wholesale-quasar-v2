begin;

-- =========================================================
-- 1. Redefine refresh_global_invoice_accounting to use inline charges
-- =========================================================
create or replace function public.refresh_global_invoice_accounting(
  p_global_invoice_id bigint
)
returns public.global_invoice_accounting
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_row public.global_invoice_accounting;
  v_charge_total numeric(12,2);
  v_profit numeric(12,2);
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;

  -- Calculate inline charge sum
  v_charge_total := v_invoice.shipping_charge + v_invoice.cod_charge + v_invoice.wrapping_charge + v_invoice.print_charge;

  -- Calculate profit sum from ledger entries
  select coalesce(sum(gross_profit_amount), 0.00) into v_profit
  from public.global_accounting_ledger
  where global_invoice_id = p_global_invoice_id;

  insert into public.global_invoice_accounting (
    parent_tenant_id,
    tenant_id,
    global_invoice_id,
    subtotal_amount,
    charge_total,
    discount_amount,
    total_amount,
    gross_profit_total
  )
  values (
    v_invoice.parent_tenant_id,
    v_invoice.tenant_id,
    p_global_invoice_id,
    v_invoice.subtotal_amount,
    v_charge_total,
    v_invoice.discount_amount,
    v_invoice.total_amount, -- total_amount in global_invoices already includes charges and discounts
    v_profit
  )
  on conflict (global_invoice_id)
  do update set
    subtotal_amount = excluded.subtotal_amount,
    charge_total = excluded.charge_total,
    discount_amount = excluded.discount_amount,
    total_amount = excluded.total_amount,
    gross_profit_total = excluded.gross_profit_total,
    refreshed_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

-- =========================================================
-- 2. Redefine post_global_invoice to book ledger items & charges
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

  -- Process line items: snapshot unit cost & deduct stock & book ledger entries
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

    -- 3. Book item ledger entry
    insert into public.global_accounting_ledger (
      parent_tenant_id,
      tenant_id,
      sold_in_tenant_id,
      global_invoice_id,
      global_invoice_item_id,
      global_stock_id,
      product_id,
      quantity,
      cost_amount,
      sell_price_amount,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount,
      status,
      entry_date,
      note
    )
    values (
      v_invoice.parent_tenant_id,
      v_invoice.tenant_id,
      v_invoice.tenant_id,
      v_invoice.id,
      v_item.id,
      v_item.global_stock_id,
      v_item.product_id,
      v_item.quantity,
      v_unit_cost,
      v_item.sell_price_amount,
      v_unit_cost * v_item.quantity,
      v_item.sell_price_amount * v_item.quantity,
      (v_item.sell_price_amount - v_unit_cost) * v_item.quantity,
      case when v_invoice.payment_status = 'paid' then 'paid' else 'due' end,
      current_date,
      'Global invoice item: posted'
    );
  end loop;

  -- 4. Book inline charges entries to the ledger if greater than zero
  if v_invoice.shipping_charge > 0 then
    insert into public.global_accounting_ledger (
      parent_tenant_id,
      tenant_id,
      sold_in_tenant_id,
      global_invoice_id,
      is_charge,
      charge_type,
      quantity,
      cost_amount,
      sell_price_amount,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount,
      status,
      entry_date,
      note
    )
    values (
      v_invoice.parent_tenant_id,
      v_invoice.tenant_id,
      v_invoice.tenant_id,
      v_invoice.id,
      true,
      'delivery'::public.invoice_charge_type,
      1,
      0.00,
      v_invoice.shipping_charge,
      0.00,
      v_invoice.shipping_charge,
      v_invoice.shipping_charge,
      case when v_invoice.payment_status = 'paid' then 'paid' else 'due' end,
      current_date,
      'Delivery charge'
    );
  end if;

  if v_invoice.cod_charge > 0 then
    insert into public.global_accounting_ledger (
      parent_tenant_id,
      tenant_id,
      sold_in_tenant_id,
      global_invoice_id,
      is_charge,
      charge_type,
      quantity,
      cost_amount,
      sell_price_amount,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount,
      status,
      entry_date,
      note
    )
    values (
      v_invoice.parent_tenant_id,
      v_invoice.tenant_id,
      v_invoice.tenant_id,
      v_invoice.id,
      true,
      'cod'::public.invoice_charge_type,
      1,
      0.00,
      v_invoice.cod_charge,
      0.00,
      v_invoice.cod_charge,
      v_invoice.cod_charge,
      case when v_invoice.payment_status = 'paid' then 'paid' else 'due' end,
      current_date,
      'COD charge'
    );
  end if;

  if v_invoice.wrapping_charge > 0 then
    insert into public.global_accounting_ledger (
      parent_tenant_id,
      tenant_id,
      sold_in_tenant_id,
      global_invoice_id,
      is_charge,
      charge_type,
      quantity,
      cost_amount,
      sell_price_amount,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount,
      status,
      entry_date,
      note
    )
    values (
      v_invoice.parent_tenant_id,
      v_invoice.tenant_id,
      v_invoice.tenant_id,
      v_invoice.id,
      true,
      'packing'::public.invoice_charge_type,
      1,
      0.00,
      v_invoice.wrapping_charge,
      0.00,
      v_invoice.wrapping_charge,
      v_invoice.wrapping_charge,
      case when v_invoice.payment_status = 'paid' then 'paid' else 'due' end,
      current_date,
      'Wrapping charge'
    );
  end if;

  if v_invoice.print_charge > 0 then
    insert into public.global_accounting_ledger (
      parent_tenant_id,
      tenant_id,
      sold_in_tenant_id,
      global_invoice_id,
      is_charge,
      charge_type,
      quantity,
      cost_amount,
      sell_price_amount,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount,
      status,
      entry_date,
      note
    )
    values (
      v_invoice.parent_tenant_id,
      v_invoice.tenant_id,
      v_invoice.tenant_id,
      v_invoice.id,
      true,
      'print'::public.invoice_charge_type,
      1,
      0.00,
      v_invoice.print_charge,
      0.00,
      v_invoice.print_charge,
      v_invoice.print_charge,
      case when v_invoice.payment_status = 'paid' then 'paid' else 'due' end,
      current_date,
      'Print charge'
    );
  end if;

  -- Mark invoice as posted
  update public.global_invoices
  set invoice_status = 'posted'::public.global_invoice_status
  where id = p_invoice_id;

  -- Refresh ledger accounting rollup
  perform public.refresh_global_invoice_accounting(p_invoice_id);
end;
$$;

-- =========================================================
-- 3. Redefine void_global_invoice to wipe ledger entries
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

  -- Remove ledger entries
  delete from public.global_accounting_ledger where global_invoice_id = p_invoice_id;

  -- Mark invoice as voided and zero out remaining due balance
  update public.global_invoices
  set
    invoice_status = 'voided'::public.global_invoice_status,
    due_amount = 0.00
  where id = p_invoice_id;

  -- Refresh ledger accounting rollup
  perform public.refresh_global_invoice_accounting(p_invoice_id);
end;
$$;

-- =========================================================
-- 4. Redefine add_global_return_item to book return ledger entry
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

  -- Book return entry into global_accounting_ledger
  insert into public.global_accounting_ledger (
    parent_tenant_id,
    tenant_id,
    sold_in_tenant_id,
    global_invoice_id,
    global_invoice_item_id,
    global_stock_id,
    product_id,
    return_quantity,
    return_amount,
    cost_amount,
    sell_price_amount,
    total_cost_amount,
    total_sell_amount,
    gross_profit_amount,
    status,
    entry_date,
    note
  )
  values (
    v_invoice.parent_tenant_id,
    v_invoice.tenant_id,
    v_invoice.tenant_id,
    v_invoice.id,
    v_item.id,
    v_item.global_stock_id,
    v_item.product_id,
    p_quantity,
    p_return_accounting_amount,
    v_item.unit_cost_price,
    v_item.sell_price_amount,
    -(v_item.unit_cost_price * p_quantity),
    -p_return_accounting_amount,
    -p_return_accounting_amount - (-(v_item.unit_cost_price * p_quantity)),
    'paid'::text,
    current_date,
    coalesce(nullif(trim(p_note), ''), 'Global invoice item return')
  );

  -- Recompute totals (recompute_global_invoice_totals will call recompute_global_invoice_payment_status)
  perform public.recompute_global_invoice_totals(p_invoice_id);

  -- Refresh ledger accounting rollup
  perform public.refresh_global_invoice_accounting(p_invoice_id);

  return v_row;
end;
$$;

commit;
