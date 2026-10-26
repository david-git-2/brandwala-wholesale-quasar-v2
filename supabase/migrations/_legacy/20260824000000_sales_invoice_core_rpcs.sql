begin;

-- =========================================================
-- 1. Helper function: calculate_landed_unit_cost
-- =========================================================
create or replace function public.calculate_landed_unit_cost(p_shipment_item_id bigint)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_shipment_id bigint;
  v_shipment_type public.global_shipment_type;
  v_product_conversion_rate numeric;
  v_cargo_conversion_rate numeric;
  v_cargo_rate numeric;
  v_received_weight numeric;
  v_transaction_rate numeric;
  
  v_purchase_price numeric;
  v_product_weight numeric;
  v_package_weight numeric;
  v_qty numeric;
  
  v_total_packaging_weight_kg numeric := 0;
  v_cargo_weight_kg numeric;
  v_cargo_purchase_total numeric;
  v_line_gross_weight_kg numeric;
  v_line_cargo_share numeric := 0;
  v_line_purchase_base numeric;
  v_raw_tx_rate numeric;
  v_effective_rate numeric;
  v_landed_cost numeric;
begin
  -- Load item details
  select shipment_id, purchase_price, product_weight, package_weight, ordered_quantity
  into v_shipment_id, v_purchase_price, v_product_weight, v_package_weight, v_qty
  from public.global_shipment_items
  where id = p_shipment_item_id;
  
  if v_shipment_id is null then
    return 0.00;
  end if;

  -- Load shipment details
  select type, product_conversion_rate, cargo_conversion_rate, cargo_rate, received_weight, transaction_rate
  into v_shipment_type, v_product_conversion_rate, v_cargo_conversion_rate, v_cargo_rate, v_received_weight, v_transaction_rate
  from public.global_shipments
  where id = v_shipment_id;

  -- Calculate total packaging weight of the shipment
  select coalesce(sum(((product_weight + package_weight) * ordered_quantity) / 1000.0), 0)
  into v_total_packaging_weight_kg
  from public.global_shipment_items
  where shipment_id = v_shipment_id;

  -- Calculate cargo weight kg
  if v_received_weight is not null and v_received_weight > 0 then
    v_cargo_weight_kg := round(v_received_weight::numeric, 2);
  else
    v_cargo_weight_kg := v_total_packaging_weight_kg;
  end if;

  -- Calculate total cargo purchase
  v_cargo_purchase_total := v_cargo_weight_kg * v_cargo_rate;

  -- Calculate line gross weight kg
  v_line_gross_weight_kg := ((v_product_weight + v_package_weight) * v_qty) / 1000.0;

  -- Calculate line cargo share per unit
  if v_qty > 0 and v_cargo_purchase_total > 0 then
    if v_total_packaging_weight_kg > 0 then
      v_line_cargo_share := ((v_line_gross_weight_kg / v_total_packaging_weight_kg) * v_cargo_purchase_total) / v_qty;
    else
      declare
        v_total_qty numeric;
      begin
        select coalesce(sum(ordered_quantity), 0) into v_total_qty
        from public.global_shipment_items
        where shipment_id = v_shipment_id;
        
        if v_total_qty > 0 then
          v_line_cargo_share := ((v_qty / v_total_qty) * v_cargo_purchase_total) / v_qty;
        end if;
      end;
    end if;
  else
    -- Fallback weight basis calculation for single unit
    v_line_cargo_share := ((v_product_weight + v_package_weight) / 1000.0) * v_cargo_rate;
  end if;

  -- Purchase base
  v_line_purchase_base := v_purchase_price + v_line_cargo_share;

  if v_shipment_type = 'domestic' then
    return round(v_line_purchase_base, 2);
  end if;

  -- Effective conversion rate
  declare
    v_goods_purchase numeric;
    v_cargo_purchase numeric;
    v_denominator numeric;
  begin
    select coalesce(sum(purchase_price * ordered_quantity), 0) into v_goods_purchase
    from public.global_shipment_items
    where shipment_id = v_shipment_id;
    
    v_cargo_purchase := v_cargo_weight_kg * v_cargo_rate;
    v_denominator := v_goods_purchase + v_cargo_purchase;
    
    if v_denominator > 0 then
      v_raw_tx_rate := ((v_goods_purchase * v_product_conversion_rate) + (v_cargo_purchase * v_cargo_conversion_rate)) / v_denominator;
    else
      v_raw_tx_rate := (v_product_conversion_rate + v_cargo_conversion_rate) / 2.0;
    end if;
  end;

  if v_raw_tx_rate is not null and v_raw_tx_rate > 0 then
    v_effective_rate := v_raw_tx_rate;
  elsif v_transaction_rate is not null and v_transaction_rate > 0 then
    v_effective_rate := v_transaction_rate;
  else
    v_effective_rate := (v_product_conversion_rate + v_cargo_conversion_rate) / 2.0;
  end if;

  v_landed_cost := v_line_purchase_base * v_effective_rate;
  return round(v_landed_cost, 2);
end;
$$;

-- =========================================================
-- 2. create_global_invoice
-- =========================================================
create or replace function public.create_global_invoice(
  p_tenant_id bigint,
  p_invoice_no text,
  p_invoice_type public.global_invoice_type,
  p_billing_profile_id bigint default null,
  p_recipient_profile_id bigint default null,
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_retail_billing_mode public.retail_billing_mode default null,
  p_due_date date default null,
  p_note text default null
)
returns public.global_invoices
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_rec_name text;
  v_rec_phone text;
  v_rec_address text;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_bill_name text;
  v_bill_phone text;
  v_bill_address text;
  v_collection_source public.collection_source_type;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  -- Authorization check
  if not (
    public.user_can_manage_parent_tenant(v_parent_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'not allowed';
  end if;

  -- Validate profile matching (trigger checks this too, but we raise clean messages here)
  if p_billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles
      where id = p_billing_profile_id and tenant_id = p_tenant_id
    ) then
      raise exception 'billing profile must belong to the same tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles
      where id = p_recipient_profile_id and tenant_id = p_tenant_id
    ) then
      raise exception 'recipient profile must belong to the same tenant';
    end if;
  end if;

  -- Resolve collection source and enforce business rules per invoice type
  if p_invoice_type = 'wholesale'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for wholesale invoices';
    end if;
    v_collection_source := 'billing_profile'::public.collection_source_type;

  elsif p_invoice_type = 'retail'::public.global_invoice_type then
    if p_retail_billing_mode is null then
      raise exception 'retail billing mode (account or direct) is required for retail invoices';
    end if;
    
    if p_retail_billing_mode = 'account'::public.retail_billing_mode then
      if p_billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
      v_collection_source := 'billing_profile'::public.collection_source_type;
    else
      if p_billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
      v_collection_source := 'recipient'::public.collection_source_type;
    end if;

  elsif p_invoice_type = 'dropship'::public.global_invoice_type then
    if p_billing_profile_id is null then
      raise exception 'billing profile (middle man) is required for dropship invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for dropship invoices';
    end if;
    v_collection_source := 'recipient'::public.collection_source_type;
  end if;

  -- Fetch recipient details from profile if provided
  if p_recipient_profile_id is not null then
    select name, phone, address
    into v_rec_name, v_rec_phone, v_rec_address
    from public.recipient_profiles
    where id = p_recipient_profile_id;
  end if;

  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_rec_name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_rec_phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_rec_address);

  -- For wholesale, fall back to billing profile address if recipient is still empty
  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_billing_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.billing_profiles
    where id = p_billing_profile_id;
    
    v_recipient_name := coalesce(v_recipient_name, v_bill_name);
    v_recipient_phone := coalesce(v_recipient_phone, v_bill_phone);
    v_recipient_address := coalesce(v_recipient_address, v_bill_address);
  end if;

  -- Insert invoice header
  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    fulfillment_status,
    billing_profile_id,
    recipient_profile_id,
    recipient_name,
    recipient_phone,
    recipient_address,
    collection_source,
    due_date,
    payment_status,
    note
  )
  values (
    p_tenant_id,
    v_parent_id,
    trim(p_invoice_no),
    p_invoice_type,
    current_date,
    p_retail_billing_mode,
    'draft'::public.global_invoice_status,
    'pending'::public.global_fulfillment_status,
    p_billing_profile_id,
    p_recipient_profile_id,
    v_recipient_name,
    v_recipient_phone,
    v_recipient_address,
    v_collection_source,
    p_due_date,
    'due',
    nullif(trim(coalesce(p_note, '')), '')
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- =========================================================
-- 3. recompute_global_invoice_totals
-- =========================================================
create or replace function public.recompute_global_invoice_totals(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subtotal numeric(12,2);
  v_face_subtotal numeric(12,2);
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then return; end if;

  select
    coalesce(sum(line_total_amount), 0.00),
    coalesce(sum(line_face_total_amount), 0.00)
  into v_subtotal, v_face_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    face_subtotal_amount = v_face_subtotal,
    accounting_subtotal_amount = v_subtotal,
    middle_man_payout_amount = case
      when invoice_type = 'dropship'::public.global_invoice_type then greatest(v_face_subtotal - v_subtotal, 0.00)
      else 0.00
    end,
    total_amount = greatest(case
      when invoice_type = 'dropship'::public.global_invoice_type then v_face_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
      else v_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
    end, 0.00),
    due_amount = greatest(case
      when invoice_type = 'dropship'::public.global_invoice_type then v_face_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
      else v_subtotal + shipping_charge + cod_charge + wrapping_charge + print_charge - discount_amount
    end - paid_amount, 0.00)
  where id = p_invoice_id;
end;
$$;

-- =========================================================
-- 4. add_global_invoice_item
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

  -- Load item details
  select name, barcode, product_code, product_id
  into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  -- Resolve recipient price
  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    v_recipient_price := coalesce(p_recipient_price_amount, 0.00);
  else
    v_recipient_price := p_sell_price_amount;
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(p_line_discount_amount, 0.00), 0.00);
  v_line_face_total := greatest((p_quantity * v_recipient_price) - coalesce(p_line_discount_amount, 0.00), 0.00);

  insert into public.global_invoice_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    global_stock_id,
    shipment_item_id,
    product_id,
    name_snapshot,
    barcode_snapshot,
    product_code_snapshot,
    quantity,
    unit_cost_price,
    sell_price_amount,
    recipient_price_amount,
    line_discount_amount,
    line_total_amount,
    line_face_total_amount,
    return_quantity
  )
  values (
    v_invoice.tenant_id,
    v_invoice.parent_tenant_id,
    p_invoice_id,
    p_global_stock_id,
    v_stock.shipment_item_id,
    v_product_id,
    v_name_snapshot,
    v_barcode_snapshot,
    v_product_code_snapshot,
    p_quantity,
    0.00, -- Populated on post only
    p_sell_price_amount,
    v_recipient_price,
    coalesce(p_line_discount_amount, 0.00),
    v_line_total,
    v_line_face_total,
    0.00
  )
  returning * into v_row;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

-- =========================================================
-- 5. remove_global_invoice_item
-- =========================================================
create or replace function public.remove_global_invoice_item(
  p_invoice_item_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
begin
  select gi.* into v_invoice
  from public.global_invoices gi
  inner join public.global_invoice_items gii on gii.invoice_id = gi.id
  where gii.id = p_invoice_item_id;

  if v_invoice.id is null then raise exception 'item not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot remove items from a non-draft invoice';
  end if;

  delete from public.global_invoice_items
  where id = p_invoice_item_id;

  perform public.recompute_global_invoice_totals(v_invoice.id);
end;
$$;

-- =========================================================
-- 6. update_global_invoice_header
-- =========================================================
create or replace function public.update_global_invoice_header(
  p_invoice_id bigint,
  p_discount_amount numeric default null,
  p_shipping_charge numeric default null,
  p_cod_charge numeric default null,
  p_wrapping_charge numeric default null,
  p_print_charge numeric default null,
  p_recipient_name text default null,
  p_recipient_phone text default null,
  p_recipient_address text default null,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot update header of a non-draft invoice';
  end if;

  update public.global_invoices
  set
    discount_amount = coalesce(p_discount_amount, discount_amount),
    shipping_charge = coalesce(p_shipping_charge, shipping_charge),
    cod_charge = coalesce(p_cod_charge, cod_charge),
    wrapping_charge = coalesce(p_wrapping_charge, wrapping_charge),
    print_charge = coalesce(p_print_charge, print_charge),
    recipient_name = coalesce(nullif(trim(p_recipient_name), ''), recipient_name),
    recipient_phone = coalesce(nullif(trim(p_recipient_phone), ''), recipient_phone),
    recipient_address = coalesce(nullif(trim(p_recipient_address), ''), recipient_address),
    note = coalesce(nullif(trim(p_note), ''), note)
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$$;

-- =========================================================
-- 7. post_global_invoice
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
  v_alloc_qty integer;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
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
-- 8. void_global_invoice
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
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
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
-- 9. Grants
-- =========================================================
grant execute on function public.calculate_landed_unit_cost(bigint) to authenticated;
grant execute on function public.create_global_invoice(bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text) to authenticated;
grant execute on function public.recompute_global_invoice_totals(bigint) to authenticated;
grant execute on function public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric, numeric) to authenticated;
grant execute on function public.remove_global_invoice_item(bigint) to authenticated;
grant execute on function public.update_global_invoice_header(bigint, numeric, numeric, numeric, numeric, numeric, text, text, text, text) to authenticated;
grant execute on function public.post_global_invoice(bigint) to authenticated;
grant execute on function public.void_global_invoice(bigint) to authenticated;

commit;
