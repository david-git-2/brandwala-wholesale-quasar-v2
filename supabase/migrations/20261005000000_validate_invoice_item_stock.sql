begin;

-- =========================================================
-- 1. One-time Self-Healing Migration Block (Posted Invoices)
-- =========================================================
do $$
declare
  v_over_sold record;
  v_item record;
  v_alt record;
  v_excess numeric;
  v_shift numeric;
begin
  -- Loop through all stock entries that are over-sold on posted invoices
  for v_over_sold in
    select 
      gs.id as stock_id,
      gsi.product_id,
      gs.parent_tenant_id,
      gsi.ordered_quantity as total_received,
      coalesce(sum(gii.quantity), 0) as total_sold,
      (coalesce(sum(gii.quantity), 0) - gsi.ordered_quantity) as excess_qty
    from public.global_stocks gs
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_invoice_items gii on gii.global_stock_id = gs.id
    left join public.global_invoices gi on gi.id = gii.invoice_id
    where gi.invoice_status = 'posted'
    group by gs.id, gsi.product_id, gs.parent_tenant_id, gsi.ordered_quantity
    having coalesce(sum(gii.quantity), 0) > gsi.ordered_quantity
  loop
    v_excess := v_over_sold.excess_qty;
    
    -- Loop through posted invoice items for this over-sold stock to shift the excess
    for v_item in
      select gii.*, gi.tenant_id
      from public.global_invoice_items gii
      join public.global_invoices gi on gi.id = gii.invoice_id
      where gii.global_stock_id = v_over_sold.stock_id
        and gi.invoice_status = 'posted'
      order by gii.id desc
    loop
      if v_excess <= 0 then
        exit;
      end if;

      -- Find alternative stock entries for the same product in the same parent tenant group that have remaining capacity
      for v_alt in
        select 
          gs.id as stock_id,
          gsi.id as shipment_item_id,
          gsi.ordered_quantity - coalesce(sum(gii_alt.quantity), 0) as capacity
        from public.global_stocks gs
        join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
        left join public.global_invoice_items gii_alt on gii_alt.global_stock_id = gs.id
        left join public.global_invoices gi_alt on gi_alt.id = gii_alt.invoice_id and gi_alt.invoice_status = 'posted'
        where gsi.product_id = v_over_sold.product_id
          and gs.parent_tenant_id = v_over_sold.parent_tenant_id
          and gs.id <> v_over_sold.stock_id
          and gs.is_usable = true
        group by gs.id, gsi.id, gsi.ordered_quantity
        having gsi.ordered_quantity > coalesce(sum(gii_alt.quantity), 0)
        order by gs.id asc
      loop
        if v_excess <= 0 or v_item.quantity <= 0 then
          exit;
        end if;

        v_shift := least(v_excess, v_alt.capacity, v_item.quantity);

        if v_shift > 0 then
          -- If the shift quantity is equal to the item's quantity, we just re-point the item
          if v_shift = v_item.quantity then
            update public.global_invoice_items
            set 
              global_stock_id = v_alt.stock_id,
              shipment_item_id = v_alt.shipment_item_id,
              unit_cost_price = coalesce(public.calculate_landed_unit_cost(v_alt.shipment_item_id), 0.00)
            where id = v_item.id;
          else
            -- Reduce quantity of current item and insert a new split item
            update public.global_invoice_items
            set 
              quantity = quantity - v_shift,
              line_total_amount = greatest((quantity - v_shift) * sell_price_amount - line_discount_amount, 0),
              line_face_total_amount = greatest((quantity - v_shift) * recipient_price_amount - line_discount_amount, 0)
            where id = v_item.id;

            insert into public.global_invoice_items (
              tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
              name_snapshot, barcode_snapshot, product_code_snapshot, quantity, unit_cost_price,
              sell_price_amount, recipient_price_amount, line_discount_amount, line_total_amount, line_face_total_amount, return_quantity
            )
            values (
              v_item.tenant_id, v_item.parent_tenant_id, v_item.invoice_id, v_alt.stock_id, v_alt.shipment_item_id, v_item.product_id,
              v_item.name_snapshot, v_item.barcode_snapshot, v_item.product_code_snapshot, v_shift, 
              coalesce(public.calculate_landed_unit_cost(v_alt.shipment_item_id), 0.00),
              v_item.sell_price_amount, v_item.recipient_price_amount, 0.00, 
              v_shift * v_item.sell_price_amount, v_shift * v_item.recipient_price_amount, 0.00
            );
          end if;

          -- Adjust current stock quantities (restore to over_sold, deduct from alternative)
          update public.global_stocks
          set quantity = quantity + v_shift
          where id = v_over_sold.stock_id;

          update public.global_stocks
          set quantity = quantity - v_shift
          where id = v_alt.stock_id;

          -- Update allocations if they exist
          if exists (
            select 1 from public.global_stock_allocations
            where child_tenant_id = v_item.tenant_id and stock_id = v_over_sold.stock_id
          ) then
            update public.global_stock_allocations
            set quantity = quantity + v_shift
            where child_tenant_id = v_item.tenant_id and stock_id = v_over_sold.stock_id;
          end if;

          if exists (
            select 1 from public.global_stock_allocations
            where child_tenant_id = v_item.tenant_id and stock_id = v_alt.stock_id
          ) then
            update public.global_stock_allocations
            set quantity = quantity - v_shift
            where child_tenant_id = v_item.tenant_id and stock_id = v_alt.stock_id;
          end if;

          perform public.recompute_global_invoice_totals(v_item.invoice_id);

          v_excess := v_excess - v_shift;
        end if;
      end loop;
    end loop;
  end loop;
end $$;


-- =========================================================
-- 2. One-time Stock Deduction Backfill (Draft Invoices)
-- =========================================================
do $$
declare
  v_draft_item record;
  v_invoice_tenant_id bigint;
  v_qty integer;
begin
  -- Deduct stock for all existing draft invoice items to align with immediate reservation model
  for v_draft_item in 
    select gii.global_stock_id, gii.quantity, gii.invoice_id
    from public.global_invoice_items gii
    join public.global_invoices gi on gi.id = gii.invoice_id
    where gi.invoice_status = 'draft'::public.global_invoice_status
  loop
    select tenant_id into v_invoice_tenant_id from public.global_invoices where id = v_draft_item.invoice_id;
    v_qty := ceil(v_draft_item.quantity)::integer;
    
    update public.global_stocks
    set quantity = greatest(quantity - v_qty, 0)
    where id = v_draft_item.global_stock_id;

    if exists (
      select 1 from public.global_stock_allocations
      where child_tenant_id = v_invoice_tenant_id and stock_id = v_draft_item.global_stock_id
    ) then
      update public.global_stock_allocations
      set quantity = greatest(quantity - v_qty, 0)
      where child_tenant_id = v_invoice_tenant_id and stock_id = v_draft_item.global_stock_id;
    end if;
  end loop;
end $$;


-- =========================================================
-- 3. Create public.get_available_stock function
-- =========================================================
create or replace function public.get_available_stock(
  p_stock_id bigint,
  p_tenant_id bigint
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_parent_tenant_id bigint;
  v_global_qty integer;
  v_other_allocated integer;
begin
  select parent_tenant_id, quantity
  into v_parent_tenant_id, v_global_qty
  from public.global_stocks
  where id = p_stock_id;

  if v_parent_tenant_id is null then
    return 0;
  end if;

  -- Parent tenant can sell up to the entire global quantity
  if p_tenant_id = v_parent_tenant_id then
    return v_global_qty;
  end if;

  -- Child tenant can sell: global quantity - sum of allocations to OTHER child tenants
  select coalesce(sum(quantity), 0)
  into v_other_allocated
  from public.global_stock_allocations
  where stock_id = p_stock_id
    and child_tenant_id <> p_tenant_id;

  return greatest(v_global_qty - v_other_allocated, 0);
end;
$$;

grant execute on function public.get_available_stock(bigint, bigint) to authenticated;


-- =========================================================
-- 4. Redefine add_global_invoice_item with stock check & splits
-- =========================================================
create or replace function public.add_global_invoice_item(
  p_invoice_id bigint,
  p_global_stock_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_recipient_price_amount numeric default 0,
  p_line_discount_amount numeric default 0
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_stock public.global_stocks;
  v_row public.global_invoice_items;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_recipient_price numeric;
  v_line_total numeric;
  v_line_face_total numeric;
  v_product_id bigint;
  v_unit_cost numeric;
  
  -- Splitting variables
  v_qty_remaining numeric;
  v_avail integer;
  v_take numeric;
  v_existing_qty numeric;
  v_curr_stock_id bigint;
  
  r_stock record;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot add items to a non-draft invoice';
  end if;

  select * into v_stock from public.global_stocks where id = p_global_stock_id;
  if v_stock.id is null then raise exception 'stock not found'; end if;
  if v_stock.parent_tenant_id <> v_invoice.parent_tenant_id then
    raise exception 'stock must belong to the same parent tenant group';
  end if;

  -- Load product_id from the selected shipment item
  select product_id into v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  v_qty_remaining := p_quantity;
  v_curr_stock_id := p_global_stock_id;

  -- 1. Try to allocate from the selected stock first
  v_avail := public.get_available_stock(v_curr_stock_id, v_invoice.tenant_id);
  select coalesce(sum(quantity), 0) into v_existing_qty
  from public.global_invoice_items
  where invoice_id = p_invoice_id and global_stock_id = v_curr_stock_id;

  v_avail := greatest(v_avail - v_existing_qty, 0);

  if v_avail > 0 then
    v_take := least(v_qty_remaining, v_avail);
    
    select name, barcode, product_code
    into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot
    from public.global_shipment_items
    where id = (select shipment_item_id from public.global_stocks where id = v_curr_stock_id);

    if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
      v_recipient_price := coalesce(p_recipient_price_amount, 0.00);
    else
      v_recipient_price := p_sell_price_amount;
    end if;

    v_line_total := greatest((v_take * p_sell_price_amount) - coalesce(p_line_discount_amount, 0.00), 0.00);
    v_line_face_total := greatest((v_take * v_recipient_price) - coalesce(p_line_discount_amount, 0.00), 0.00);
    v_unit_cost := coalesce(public.calculate_landed_unit_cost(
      (select shipment_item_id from public.global_stocks where id = v_curr_stock_id)
    ), 0.00);

    insert into public.global_invoice_items (
      tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity, unit_cost_price,
      sell_price_amount, recipient_price_amount, line_discount_amount, line_total_amount, line_face_total_amount, return_quantity
    )
    values (
      v_invoice.tenant_id, v_invoice.parent_tenant_id, p_invoice_id, v_curr_stock_id,
      (select shipment_item_id from public.global_stocks where id = v_curr_stock_id), v_product_id,
      v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_take, v_unit_cost,
      p_sell_price_amount, v_recipient_price, coalesce(p_line_discount_amount, 0.00), v_line_total, v_line_face_total, 0.00
    )
    returning * into v_row;

    v_qty_remaining := v_qty_remaining - v_take;
  end if;

  -- 2. If there is still quantity remaining and product_id is not null, try other stock entries of the same product
  if v_qty_remaining > 0 and v_product_id is not null then
    for r_stock in
      select gs.id as stock_id, gs.shipment_item_id
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      where gsi.product_id = v_product_id
        and gs.parent_tenant_id = v_invoice.parent_tenant_id
        and gs.id <> p_global_stock_id
        and gs.is_usable = true
      order by gs.id asc
    loop
      v_avail := public.get_available_stock(r_stock.stock_id, v_invoice.tenant_id);
      select coalesce(sum(quantity), 0) into v_existing_qty
      from public.global_invoice_items
      where invoice_id = p_invoice_id and global_stock_id = r_stock.stock_id;

      v_avail := greatest(v_avail - v_existing_qty, 0);

      if v_avail > 0 then
        v_take := least(v_qty_remaining, v_avail);

        select name, barcode, product_code
        into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot
        from public.global_shipment_items
        where id = r_stock.shipment_item_id;

        if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
          v_recipient_price := coalesce(p_recipient_price_amount, 0.00);
        else
          v_recipient_price := p_sell_price_amount;
        end if;

        v_line_total := greatest(v_take * p_sell_price_amount, 0.00);
        v_line_face_total := greatest(v_take * v_recipient_price, 0.00);
        v_unit_cost := coalesce(public.calculate_landed_unit_cost(r_stock.shipment_item_id), 0.00);

        insert into public.global_invoice_items (
          tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
          name_snapshot, barcode_snapshot, product_code_snapshot, quantity, unit_cost_price,
          sell_price_amount, recipient_price_amount, line_discount_amount, line_total_amount, line_face_total_amount, return_quantity
        )
        values (
          v_invoice.tenant_id, v_invoice.parent_tenant_id, p_invoice_id, r_stock.stock_id,
          r_stock.shipment_item_id, v_product_id,
          v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_take, v_unit_cost,
          p_sell_price_amount, v_recipient_price, 0.00, v_line_total, v_line_face_total, 0.00
        );

        v_qty_remaining := v_qty_remaining - v_take;
        
        if v_qty_remaining = 0 then
          exit;
        end if;
      end if;
    end loop;
  end if;

  -- 3. If there is still quantity remaining, raise an exception
  if v_qty_remaining > 0 then
    raise exception 'insufficient stock: requested %, available %', 
      p_quantity, (p_quantity - v_qty_remaining);
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

grant execute on function public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric, numeric) to authenticated;


-- =========================================================
-- 5. Redefine update_global_invoice_item with stock check & splits
-- =========================================================
create or replace function public.update_global_invoice_item(
  p_item_id bigint,
  p_quantity numeric,
  p_sell_price_amount numeric,
  p_recipient_price_amount numeric default null
)
returns public.global_invoice_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.global_invoice_items;
  v_invoice public.global_invoices;
  v_recipient_price numeric;
  v_line_total numeric;
  v_line_face_total numeric;
  
  -- Splitting variables
  v_qty_remaining numeric;
  v_avail integer;
  v_take numeric;
  v_existing_qty numeric;
  v_product_id bigint;
  
  r_stock record;
begin
  select * into v_item from public.global_invoice_items where id = p_item_id;
  if v_item.id is null then raise exception 'Invoice item not found'; end if;

  select * into v_invoice from public.global_invoices where id = v_item.invoice_id;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'Cannot edit items on a non-draft invoice';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than 0';
  end if;

  if p_sell_price_amount < 0 then
    raise exception 'Sell price cannot be negative';
  end if;

  v_product_id := v_item.product_id;
  v_qty_remaining := p_quantity;

  -- 1. Try to allocate from current stock entry first
  v_avail := public.get_available_stock(v_item.global_stock_id, v_invoice.tenant_id);
  select coalesce(sum(quantity), 0) into v_existing_qty
  from public.global_invoice_items
  where invoice_id = v_invoice.id 
    and global_stock_id = v_item.global_stock_id 
    and id <> p_item_id;

  v_avail := greatest(v_avail - v_existing_qty, 0);

  if v_avail > 0 then
    v_take := least(v_qty_remaining, v_avail);

    if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
      v_recipient_price := coalesce(p_recipient_price_amount, p_sell_price_amount);
    else
      v_recipient_price := p_sell_price_amount;
    end if;

    v_line_total := greatest((v_take * p_sell_price_amount) - coalesce(v_item.line_discount_amount, 0.00), 0.00);
    v_line_face_total := greatest((v_take * v_recipient_price) - coalesce(v_item.line_discount_amount, 0.00), 0.00);

    update public.global_invoice_items
    set
      quantity = v_take,
      sell_price_amount = p_sell_price_amount,
      recipient_price_amount = v_recipient_price,
      line_total_amount = v_line_total,
      line_face_total_amount = v_line_face_total
    where id = p_item_id
    returning * into v_item;

    v_qty_remaining := v_qty_remaining - v_take;
  end if;

  -- 2. Try to allocate remainder from other stock entries
  if v_qty_remaining > 0 and v_product_id is not null then
    for r_stock in
      select gs.id as stock_id, gs.shipment_item_id
      from public.global_stocks gs
      join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      where gsi.product_id = v_product_id
        and gs.parent_tenant_id = v_invoice.parent_tenant_id
        and gs.id <> v_item.global_stock_id
        and gs.is_usable = true
      order by gs.id asc
    loop
      v_avail := public.get_available_stock(r_stock.stock_id, v_invoice.tenant_id);
      select coalesce(sum(quantity), 0) into v_existing_qty
      from public.global_invoice_items
      where invoice_id = v_invoice.id and global_stock_id = r_stock.stock_id;

      v_avail := greatest(v_avail - v_existing_qty, 0);

      if v_avail > 0 then
        v_take := least(v_qty_remaining, v_avail);

        if v_qty_remaining = p_quantity then
          -- Swap the stock_id of the current line since the original stock entry had 0 available
          if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
            v_recipient_price := coalesce(p_recipient_price_amount, p_sell_price_amount);
          else
            v_recipient_price := p_sell_price_amount;
          end if;

          v_line_total := greatest((v_take * p_sell_price_amount) - coalesce(v_item.line_discount_amount, 0.00), 0.00);
          v_line_face_total := greatest((v_take * v_recipient_price) - coalesce(v_item.line_discount_amount, 0.00), 0.00);

          update public.global_invoice_items
          set
            global_stock_id = r_stock.stock_id,
            shipment_item_id = r_stock.shipment_item_id,
            quantity = v_take,
            sell_price_amount = p_sell_price_amount,
            recipient_price_amount = v_recipient_price,
            line_total_amount = v_line_total,
            line_face_total_amount = v_line_face_total
          where id = p_item_id
          returning * into v_item;

          v_qty_remaining := v_qty_remaining - v_take;
        else
          -- Insert new split line
          declare
            v_new_name text;
            v_new_barcode text;
            v_new_product_code text;
            v_new_unit_cost numeric;
          begin
            select name, barcode, product_code
            into v_new_name, v_new_barcode, v_new_product_code
            from public.global_shipment_items
            where id = r_stock.shipment_item_id;

            if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
              v_recipient_price := coalesce(p_recipient_price_amount, p_sell_price_amount);
            else
              v_recipient_price := p_sell_price_amount;
            end if;

            v_line_total := greatest(v_take * p_sell_price_amount, 0.00);
            v_line_face_total := greatest(v_take * v_recipient_price, 0.00);
            v_new_unit_cost := coalesce(public.calculate_landed_unit_cost(r_stock.shipment_item_id), 0.00);

            insert into public.global_invoice_items (
              tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
              name_snapshot, barcode_snapshot, product_code_snapshot, quantity, unit_cost_price,
              sell_price_amount, recipient_price_amount, line_discount_amount, line_total_amount, line_face_total_amount, return_quantity
            )
            values (
              v_invoice.tenant_id, v_invoice.parent_tenant_id, v_invoice.id, r_stock.stock_id,
              r_stock.shipment_item_id, v_product_id,
              v_new_name, v_new_barcode, v_new_product_code, v_take, v_new_unit_cost,
              p_sell_price_amount, v_recipient_price, 0.00, v_line_total, v_line_face_total, 0.00
            );

            v_qty_remaining := v_qty_remaining - v_take;
          end;
        end if;

        if v_qty_remaining = 0 then
          exit;
        end if;
      end if;
    end loop;
  end if;

  -- 3. If there is still quantity remaining, raise an exception
  if v_qty_remaining > 0 then
    raise exception 'insufficient stock: requested %, available %', 
      p_quantity, (p_quantity - v_qty_remaining);
  end if;

  perform public.recompute_global_invoice_totals(v_invoice.id);

  return v_item;
end;
$$;

grant execute on function public.update_global_invoice_item(bigint, numeric, numeric, numeric) to authenticated;


-- =========================================================
-- 6. Redefine post_global_invoice (W/O manual stock deduct)
-- =========================================================
drop function if exists public.post_global_invoice(bigint) cascade;

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

  -- Process line items: snapshot unit cost only (stock is already deducted)
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  -- Mark invoice as posted
  update public.global_invoices
  set invoice_status = 'posted'::public.global_invoice_status
  where id = p_invoice_id;
end;
$$;

grant execute on function public.post_global_invoice(bigint) to authenticated;


-- =========================================================
-- 7. Redefine unpost_global_invoice (W/O manual stock restore)
-- =========================================================
drop function if exists public.unpost_global_invoice(bigint) cascade;

create or replace function public.unpost_global_invoice(
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
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'only posted invoices can be unposted';
  end if;
  
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot unpost a paid or partially paid invoice; reverse collections/payments first';
  end if;

  if exists (select 1 from public.global_return_items where invoice_id = p_invoice_id) then
    raise exception 'cannot unpost an invoice with return items; remove return items first';
  end if;

  -- Recalculate unit costs (stock stays deducted since status transitions back to draft)
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := coalesce(public.calculate_landed_unit_cost(v_item.shipment_item_id), 0.00);
    
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  -- Mark invoice as draft
  update public.global_invoices
  set invoice_status = 'draft'::public.global_invoice_status
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$$;

grant execute on function public.unpost_global_invoice(bigint) to authenticated;


-- =========================================================
-- 8. Redefine void_global_invoice (W/O manual stock restore)
-- =========================================================
drop function if exists public.void_global_invoice(bigint) cascade;

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
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'only posted invoices can be voided';
  end if;
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot void a paid or partially paid invoice; reverse collections/payments first';
  end if;

  -- Mark invoice as voided (Trigger on global_invoices handles restoring stock)
  update public.global_invoices
  set
    invoice_status = 'voided'::public.global_invoice_status,
    due_amount = 0.00
  where id = p_invoice_id;
end;
$$;

grant execute on function public.void_global_invoice(bigint) to authenticated;


-- =========================================================
-- 9. Create Trigger functions and attach triggers
-- =========================================================

-- Trigger function for global_invoice_items
create or replace function public.trg_fn_global_invoice_items_stock_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_status public.global_invoice_status;
  v_qty integer;
  v_diff integer;
  v_target_tenant_id bigint;
begin
  if TG_OP = 'INSERT' then
    select invoice_status, tenant_id into v_status, v_target_tenant_id
    from public.global_invoices where id = NEW.invoice_id;
    
    if v_status in ('draft'::public.global_invoice_status, 'posted'::public.global_invoice_status) then
      v_qty := ceil(NEW.quantity)::integer;
      
      update public.global_stocks
      set quantity = quantity - v_qty
      where id = NEW.global_stock_id;

      if exists (
        select 1 from public.global_stock_allocations
        where child_tenant_id = v_target_tenant_id and stock_id = NEW.global_stock_id
      ) then
        update public.global_stock_allocations
        set quantity = quantity - v_qty
        where child_tenant_id = v_target_tenant_id and stock_id = NEW.global_stock_id;
      end if;
    end if;
    
  elsif TG_OP = 'UPDATE' then
    select invoice_status, tenant_id into v_status, v_target_tenant_id
    from public.global_invoices where id = NEW.invoice_id;
    
    if v_status in ('draft'::public.global_invoice_status, 'posted'::public.global_invoice_status) then
      if NEW.global_stock_id <> OLD.global_stock_id then
        -- Return old quantity to OLD stock ID
        v_qty := ceil(OLD.quantity)::integer;
        update public.global_stocks
        set quantity = quantity + v_qty
        where id = OLD.global_stock_id;

        if exists (
          select 1 from public.global_stock_allocations
          where child_tenant_id = v_target_tenant_id and stock_id = OLD.global_stock_id
        ) then
          update public.global_stock_allocations
          set quantity = quantity + v_qty
          where child_tenant_id = v_target_tenant_id and stock_id = OLD.global_stock_id;
        end if;

        -- Deduct new quantity from NEW stock ID
        v_qty := ceil(NEW.quantity)::integer;
        update public.global_stocks
        set quantity = quantity - v_qty
        where id = NEW.global_stock_id;

        if exists (
          select 1 from public.global_stock_allocations
          where child_tenant_id = v_target_tenant_id and stock_id = NEW.global_stock_id
        ) then
          update public.global_stock_allocations
          set quantity = quantity - v_qty
          where child_tenant_id = v_target_tenant_id and stock_id = NEW.global_stock_id;
        end if;
      else
        -- Adjust by the quantity difference
        v_diff := ceil(NEW.quantity)::integer - ceil(OLD.quantity)::integer;
        if v_diff <> 0 then
          update public.global_stocks
          set quantity = quantity - v_diff
          where id = NEW.global_stock_id;

          if exists (
            select 1 from public.global_stock_allocations
            where child_tenant_id = v_target_tenant_id and stock_id = NEW.global_stock_id
          ) then
            update public.global_stock_allocations
            set quantity = quantity - v_diff
            where child_tenant_id = v_target_tenant_id and stock_id = NEW.global_stock_id;
          end if;
        end if;
      end if;
    end if;
    
  elsif TG_OP = 'DELETE' then
    select invoice_status, tenant_id into v_status, v_target_tenant_id
    from public.global_invoices where id = OLD.invoice_id;
    
    if v_status in ('draft'::public.global_invoice_status, 'posted'::public.global_invoice_status) then
      v_qty := ceil(OLD.quantity)::integer;
      
      update public.global_stocks
      set quantity = quantity + v_qty
      where id = OLD.global_stock_id;

      if exists (
        select 1 from public.global_stock_allocations
        where child_tenant_id = v_target_tenant_id and stock_id = OLD.global_stock_id
      ) then
        update public.global_stock_allocations
        set quantity = quantity + v_qty
        where child_tenant_id = v_target_tenant_id and stock_id = OLD.global_stock_id;
      end if;
    end if;
  end if;
  
  return null;
end;
$$;

drop trigger if exists trg_global_invoice_items_stock_sync on public.global_invoice_items;
create trigger trg_global_invoice_items_stock_sync
after insert or update or delete on public.global_invoice_items
for each row execute function public.trg_fn_global_invoice_items_stock_sync();


-- Trigger function for global_invoices
create or replace function public.trg_fn_global_invoices_stock_sync()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item record;
  v_qty integer;
begin
  -- Detect transition from active (draft, posted) to voided
  if (OLD.invoice_status in ('draft'::public.global_invoice_status, 'posted'::public.global_invoice_status)) 
     and (NEW.invoice_status = 'voided'::public.global_invoice_status) then
     
    for v_item in 
      select global_stock_id, quantity
      from public.global_invoice_items
      where invoice_id = NEW.id
    loop
      v_qty := ceil(v_item.quantity)::integer;
      
      update public.global_stocks
      set quantity = quantity + v_qty
      where id = v_item.global_stock_id;

      if exists (
        select 1 from public.global_stock_allocations
        where child_tenant_id = NEW.tenant_id and stock_id = v_item.global_stock_id
      ) then
        update public.global_stock_allocations
        set quantity = quantity + v_qty
        where child_tenant_id = NEW.tenant_id and stock_id = v_item.global_stock_id;
      end if;
    end loop;
  end if;
  
  return null;
end;
$$;

drop trigger if exists trg_global_invoices_stock_sync on public.global_invoices;
create trigger trg_global_invoices_stock_sync
after update on public.global_invoices
for each row execute function public.trg_fn_global_invoices_stock_sync();


commit;
