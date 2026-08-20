-- Extracted from supabase/schemas/public.sql (sales_invoice). Move-only.

CREATE OR REPLACE FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric DEFAULT 0, "p_recipient_price_amount" numeric DEFAULT NULL::numeric) RETURNS "public"."sales_invoice_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
  v_stock public.global_stocks;
  v_row public.global_invoice_items;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_line_total numeric;
  v_product_id bigint;
  v_unit_cost numeric;
  v_qty_remaining numeric;
  v_avail integer;
  v_take numeric;
  v_existing_qty numeric;
  v_curr_stock_id bigint;
  v_shipment_item_id bigint;
  v_assigned_child bigint;
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

  select product_id into v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  v_qty_remaining := p_quantity;
  v_curr_stock_id := p_global_stock_id;

  v_avail := public.get_available_stock(v_curr_stock_id, v_invoice.tenant_id);
  select coalesce(sum(quantity), 0) into v_existing_qty
  from public.global_invoice_items
  where invoice_id = p_invoice_id and global_stock_id = v_curr_stock_id;

  v_avail := greatest(v_avail - v_existing_qty, 0);

  if v_avail > 0 then
    v_take := least(v_qty_remaining, v_avail);

    select gsi.name, gsi.barcode, gsi.product_code, gsi.id, sh.assigned_child_tenant_id
    into v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_shipment_item_id, v_assigned_child
    from public.global_shipment_items gsi
    join public.global_shipments sh on sh.id = gsi.shipment_id
    where gsi.id = (select shipment_item_id from public.global_stocks where id = v_curr_stock_id);

    v_line_total := greatest((v_take * p_sell_price_amount) - coalesce(p_line_discount_amount, 0.00), 0.00);
    v_unit_cost := coalesce(public.calculate_landed_unit_cost(v_shipment_item_id), 0.00);

    insert into public.global_invoice_items (
      tenant_id, parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity, unit_cost_price,
      sell_price_amount, line_discount_amount, line_total_amount, return_quantity,
      assigned_child_tenant_id
    )
    values (
      v_invoice.tenant_id, v_invoice.parent_tenant_id, p_invoice_id, v_curr_stock_id,
      v_shipment_item_id, v_product_id,
      v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot, v_take, v_unit_cost,
      p_sell_price_amount, coalesce(p_line_discount_amount, 0.00), v_line_total, 0.00,
      v_assigned_child
    )
    returning * into v_row;

    v_qty_remaining := v_qty_remaining - v_take;
  end if;

  if v_qty_remaining > 0 then
    raise exception 'insufficient stock: requested %, available %', p_quantity, (p_quantity - v_qty_remaining);
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

ALTER FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric, "p_recipient_price_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_charge_amount" numeric DEFAULT 0, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."sales_return_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return public.add_global_return_item(
    p_invoice_id,
    p_invoice_item_id,
    p_quantity,
    0::numeric,
    0::numeric,
    p_return_charge_amount,
    p_note,
    null::bigint,
    'held'::public.stock_availability
  );
end;
$$;

ALTER FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_charge_amount" numeric, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_face_amount" numeric, "p_return_accounting_amount" numeric, "p_return_charge_amount" numeric DEFAULT 0, "p_note" "text" DEFAULT NULL::"text", "p_to_grade_tag_id" bigint DEFAULT NULL::bigint, "p_to_availability" "public"."stock_availability" DEFAULT 'held'::"public"."stock_availability") RETURNS "public"."sales_return_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_parent bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot return items on a non-posted invoice';
  end if;

  select * into v_item from public.global_invoice_items where id = p_invoice_item_id for update;
  if v_item.id is null then raise exception 'invoice item not found'; end if;
  if v_item.invoice_id <> p_invoice_id then
    raise exception 'invoice item does not belong to the selected invoice';
  end if;

  if v_item.return_quantity + p_quantity > v_item.quantity then
    raise exception 'return quantity exceeds available item quantity';
  end if;

  insert into public.global_return_items (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
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
    coalesce(p_return_charge_amount, 0.00),
    nullif(trim(p_note), '')
  )
  returning * into v_row;

  update public.global_invoice_items
  set return_quantity = return_quantity + p_quantity
  where id = p_invoice_item_id;

  v_parent := coalesce(v_invoice.parent_tenant_id, public.resolve_parent_tenant_id(v_invoice.tenant_id));

  if v_item.global_stock_id is not null then
    perform public.create_and_post_stock_movement(
      v_parent,
      v_item.global_stock_id,
      ceil(p_quantity)::integer,
      public.default_returns_stock_location_id(v_parent),
      coalesce(p_to_availability, 'held'::public.stock_availability),
      coalesce(p_to_grade_tag_id, public.default_stock_grade_tag_id()),
      'return_inbound'::public.stock_movement_type,
      coalesce(nullif(trim(p_note), ''), 'Invoice return'),
      'sales_invoice',
      p_invoice_id::text
    );
  end if;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  return v_row;
end;
$$;

ALTER FUNCTION "public"."add_global_return_item"("p_invoice_id" bigint, "p_invoice_item_id" bigint, "p_quantity" numeric, "p_return_face_amount" numeric, "p_return_accounting_amount" numeric, "p_return_charge_amount" numeric, "p_note" "text", "p_to_grade_tag_id" bigint, "p_to_availability" "public"."stock_availability") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) RETURNS "public"."invoice_payments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_payment public.global_payments;
  v_invoice public.global_invoices;
  v_row public.invoice_payments;
begin
  if p_tenant_id is null or p_payment_id is null or p_global_invoice_id is null then
    raise exception 'Tenant, payment and invoice are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  -- Lock payment
  select * into v_payment from public.global_payments where id = p_payment_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if v_payment.tenant_id <> p_tenant_id then raise exception 'Payment tenant mismatch.'; end if;

  -- Lock invoice
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if not found then raise exception 'Invoice not found.'; end if;
  if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;

  -- Validate same billing profile
  if coalesce(v_invoice.billing_profile_id, 0) <> coalesce(v_payment.billing_profile_id, 0) then
    raise exception 'Invoice and payment billing profile mismatch.';
  end if;

  -- Check payment unallocated amount
  if p_amount > v_payment.unallocated_amount then
    raise exception 'Allocation amount % exceeds payment unallocated amount %.', p_amount, v_payment.unallocated_amount;
  end if;

  -- Check invoice remaining due balance
  if p_amount > v_invoice.due_amount then
    raise exception 'Allocation amount % exceeds invoice remaining due balance %.', p_amount, v_invoice.due_amount;
  end if;

  -- Insert allocation record
  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (p_tenant_id, p_payment_id, p_global_invoice_id, p_amount)
  returning * into v_row;

  -- Update payment unallocated amount
  update public.global_payments
  set unallocated_amount = unallocated_amount - p_amount
  where id = p_payment_id;

  -- Update invoice paid amount
  update public.global_invoices
  set paid_amount = coalesce(paid_amount, 0.00) + p_amount, updated_at = now()
  where id = p_global_invoice_id;

  -- Recompute invoice payment status and due_amount
  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  return v_row;
end;
$$;

ALTER FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."sales_invoices"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'cannot settle a non-posted invoice';
  end if;
  if coalesce(p_amount, 0.00) < 0.00 then
    raise exception 'settlement amount must be 0 or greater';
  end if;
  if coalesce(p_amount, 0.00) > coalesce(v_invoice.due_amount, 0.00) then
    raise exception 'settlement amount exceeds outstanding due';
  end if;

  update public.global_invoices
  set
    settlement_discount_amount = coalesce(settlement_discount_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);

  select * into v_invoice from public.global_invoices where id = p_invoice_id;

  -- Record Tenant Revenue Write-Off for settlement discount
  if p_amount > 0 then
    perform public.record_ledger_transaction(
      p_tenant_id => v_invoice.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_invoice.tenant_id,
      p_type => 'debit',
      p_amount => p_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => p_invoice_id::text,
      p_metadata => jsonb_build_object(
        'section', 'settlement_discount',
        'purpose', 'settlement_discount_write_off',
        'transaction_type', 'settlement_discount',
        'label', 'Settlement Discount',
        'invoice_id', p_invoice_id,
        'invoice_no', v_invoice.invoice_no
      )
    );
  end if;

  return v_invoice;
end;
$$;

ALTER FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."apply_global_invoice_target_total"("p_invoice_id" bigint, "p_target_total" numeric, "p_dry_run" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
  v_charges_sum numeric(12,2);
  v_target_line_subtotal numeric(12,2);
  v_current_subtotal numeric(12,2);
  v_current_total numeric(12,2);
  v_count integer;
  v_index integer := 0;
  v_running numeric(12,2) := 0.00;
  v_share numeric(12,2);
  v_base numeric(12,2);
  v_old_price numeric(12,2);
  v_new_price numeric(12,2);
  v_item record;
  v_lines jsonb := '[]'::jsonb;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot adjust totals on a non-draft invoice';
  end if;
  if p_target_total is null or p_target_total < 0 then
    raise exception 'target total must be 0 or greater';
  end if;

  v_charges_sum := coalesce(v_invoice.shipping_charge, 0.00)
    + coalesce(v_invoice.wrapping_charge, 0.00)
    + coalesce(v_invoice.print_charge, 0.00);

  v_target_line_subtotal := round(p_target_total - v_charges_sum + coalesce(v_invoice.discount_amount, 0.00), 2);
  if v_target_line_subtotal < 0 then
    raise exception 'target total too low: charges and discount leave no room for item prices';
  end if;

  select
    count(*),
    coalesce(sum(line_total_amount), 0.00)
  into v_count, v_current_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  if v_count = 0 then raise exception 'invoice has no items to adjust'; end if;
  if v_current_subtotal <= 0 then
    raise exception 'current item subtotal is zero; cannot spread proportionally';
  end if;

  v_current_total := round(coalesce(v_invoice.subtotal_amount, 0.00) + v_charges_sum - coalesce(v_invoice.discount_amount, 0.00), 2);

  for v_item in
    select id, name_snapshot, quantity, sell_price_amount, line_total_amount, line_discount_amount
    from public.global_invoice_items
    where invoice_id = p_invoice_id
    order by id asc
  loop
    v_index := v_index + 1;
    v_base := v_item.line_total_amount;
    v_old_price := v_item.sell_price_amount;

    if v_index = v_count then
      v_share := round(v_target_line_subtotal - v_running, 2);
    else
      v_share := round(v_target_line_subtotal * (v_base / v_current_subtotal), 2);
      v_running := v_running + v_share;
    end if;

    if v_share < 0 then
      raise exception 'target total too low: item "%" would need a negative line total', v_item.name_snapshot;
    end if;

    v_new_price := round((v_share + coalesce(v_item.line_discount_amount, 0.00)) / v_item.quantity, 2);
    if v_new_price < 0 then
      raise exception 'target total too low: item "%" would need a negative price', v_item.name_snapshot;
    end if;

    v_lines := v_lines || jsonb_build_object(
      'item_id', v_item.id,
      'name', v_item.name_snapshot,
      'quantity', v_item.quantity,
      'old_price', v_old_price,
      'new_price', v_new_price,
      'unit_delta', round(v_new_price - v_old_price, 2),
      'line_delta', round(v_share - v_base, 2)
    );

    if not p_dry_run then
      update public.global_invoice_items
      set sell_price_amount = v_new_price,
          line_total_amount = v_share
      where id = v_item.id;
    end if;
  end loop;

  if not p_dry_run then
    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  return jsonb_build_object(
    'current_total', v_current_total,
    'target_total', round(p_target_total, 2),
    'adjustment', round(p_target_total - v_current_total, 2),
    'lines', v_lines
  );
end;
$$;

ALTER FUNCTION "public"."apply_global_invoice_target_total"("p_invoice_id" bigint, "p_target_total" numeric, "p_dry_run" boolean) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."convert_wholesale_draft_to_retail"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
begin
  -- Fetch the invoice
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then 
    raise exception 'Invoice not found'; 
  end if;

  -- Verify it is a wholesale invoice and in draft status
  if v_invoice.invoice_type <> 'wholesale'::public.global_invoice_type then
    raise exception 'Only wholesale invoices can be converted to retail';
  end if;
  
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'Only draft invoices can be converted to retail';
  end if;

  -- Update invoice type to retail and mode to account
  update public.global_invoices
  set
    invoice_type = 'retail'::public.global_invoice_type,
    retail_billing_mode = 'account'::public.retail_billing_mode,
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

ALTER FUNCTION "public"."convert_wholesale_draft_to_retail"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_billing_profile_payment_with_allocations"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text", "p_allocations" "jsonb") RETURNS "public"."global_payments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_payment public.global_payments;
  v_alloc jsonb;
  v_global_invoice_id bigint;
  v_commerce_invoice_id bigint;
  v_legacy_invoice_id bigint;
  v_alloc_amount numeric(12,2);
  v_total_alloc numeric(12,2) := 0;
  v_invoice record;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    raise exception 'Tenant and billing profile are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payment amount must be greater than zero.';
  end if;

  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    p_tenant_id,
    p_billing_profile_id,
    p_amount,
    p_amount,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    p_note
  )
  returning * into v_payment;

  if jsonb_typeof(coalesce(p_allocations, '[]'::jsonb)) <> 'array' then
    raise exception 'Allocations must be an array.';
  end if;

  for v_alloc in select * from jsonb_array_elements(coalesce(p_allocations, '[]'::jsonb))
  loop
    v_global_invoice_id := nullif(v_alloc->>'global_invoice_id', '')::bigint;
    v_commerce_invoice_id := nullif(v_alloc->>'commerce_invoice_id', '')::bigint;
    v_legacy_invoice_id := nullif(v_alloc->>'invoice_id', '')::bigint;
    v_alloc_amount := coalesce((v_alloc->>'amount')::numeric, 0.00);

    if v_alloc_amount <= 0.00 then continue; end if;

    if v_global_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount, collection_source
      into v_invoice
      from public.global_invoices where id = v_global_invoice_id for update;

      if not found then raise exception 'Global invoice % not found.', v_global_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_global_invoice_id, v_alloc_amount);

      update public.global_invoices
      set paid_amount = coalesce(paid_amount, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_global_invoice_id;

      perform public.recompute_global_invoice_payment_status(v_global_invoice_id);

    elsif v_commerce_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, amount_paid as paid_amount
      into v_invoice
      from public.commerce_invoices where id = v_commerce_invoice_id for update;

      if not found then raise exception 'Commerce invoice % not found.', v_commerce_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.invoice_payments (tenant_id, payment_id, commerce_invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_commerce_invoice_id, v_alloc_amount);

      update public.commerce_invoices
      set amount_paid = coalesce(amount_paid, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_commerce_invoice_id;

    elsif v_legacy_invoice_id is not null then
      select id, tenant_id, billing_profile_id, total_amount, paid_amount
      into v_invoice
      from public.invoices where id = v_legacy_invoice_id for update;

      if not found then raise exception 'Legacy invoice % not found.', v_legacy_invoice_id; end if;
      if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
      if coalesce(v_invoice.billing_profile_id, 0) <> p_billing_profile_id then
        raise exception 'Invoice does not belong to billing profile.';
      end if;

      insert into public.invoice_payments (tenant_id, payment_id, invoice_id, amount)
      values (p_tenant_id, v_payment.id, v_legacy_invoice_id, v_alloc_amount);

      update public.invoices
      set paid_amount = coalesce(paid_amount, 0.00) + v_alloc_amount, updated_at = now()
      where id = v_legacy_invoice_id;

      perform public.recompute_invoice_payment_status(v_legacy_invoice_id);
    end if;

    v_total_alloc := v_total_alloc + v_alloc_amount;
  end loop;

  if v_total_alloc > p_amount then
    raise exception 'Total allocation exceeds payment amount.';
  end if;

  update public.global_payments
  set unallocated_amount = p_amount - v_total_alloc
  where id = v_payment.id
  returning * into v_payment;

  -- Universal Wallet 1: Credit Tenant Cash Available (money received)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => v_payment.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'tenant_payment_received',
      'transaction_type', 'payment_received',
      'label', 'Payment Received',
      'payment_id', v_payment.id,
      'billing_profile_id', p_billing_profile_id,
      'reference', p_reference
    )
  );

  -- Universal Wallet 2: Credit Customer Available (reduces Accounts Receivable)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_billing_profile_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => v_payment.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'customer_ar_reduction',
      'transaction_type', 'payment_received',
      'label', 'Payment Applied',
      'payment_id', v_payment.id,
      'reference', p_reference
    )
  );

  return v_payment;
end;
$$;

ALTER FUNCTION "public"."create_billing_profile_payment_with_allocations"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text", "p_allocations" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_dropship_invoice"("p_order_id" bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_billing_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return public.create_dual_invoice_from_dropship_order(p_order_id, p_invoice_no, p_billing_profile_id, p_note);
end;
$$;

ALTER FUNCTION "public"."create_dropship_invoice"("p_order_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_dual_invoice_from_dropship_order"("p_order_id" bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_billing_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_billing_profile_id bigint;
  v_profile record;
  v_parent_tenant_id bigint;
  v_invoice_no text;
  v_invoice public.global_invoices;
  v_item record;
  v_subtotal numeric(12,2) := 0;
  v_charges_total numeric(12,2) := 0;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_assigned_child bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    raise exception 'Invoice can only be created for orders ready for pickup or later (current status: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is not null then
    raise exception 'Invoice already created for this order (invoice_id: %)', v_order.global_invoice_id;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and customer_group_id = v_order.customer_group_id
    order by created_at asc
    limit 1;
  end if;

  if v_billing_profile_id is null then
    raise exception 'Billing profile is required for creating invoice';
  end if;

  select * into v_profile from public.billing_profiles where id = v_billing_profile_id;
  if v_profile.id is null then
    raise exception 'Billing profile not found';
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  select * into v_invoice from public.create_global_invoice(
    p_tenant_id => v_order.tenant_id,
    p_invoice_no => v_invoice_no,
    p_invoice_type => 'dropship'::public.global_invoice_type,
    p_billing_profile_id => v_billing_profile_id,
    p_recipient_profile_id => v_order.recipient_profile_id,
    p_recipient_name => coalesce(v_order.recipient_name, v_order.name),
    p_recipient_phone => v_order.recipient_phone,
    p_recipient_address => v_order.shipping_address,
    p_note => coalesce(p_note, 'B2B Wholesale invoice created from dropship order #' || v_order.order_no)
  );

  for v_item in (
    select
      soi.*,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) loop
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);
    v_item_line_total := v_item.quantity * v_item_sell_price;
    v_assigned_child := v_item.stock_assigned_child;

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
      line_discount_amount,
      line_total_amount,
      assigned_child_tenant_id
    )
    values (
      v_invoice.tenant_id,
      v_invoice.parent_tenant_id,
      v_invoice.id,
      v_item.global_stock_id,
      v_item.stock_shipment_item_id,
      v_item.product_id,
      coalesce(v_item.stock_name, v_item.name),
      v_item.stock_barcode,
      v_item.stock_product_code,
      v_item.quantity,
      coalesce(v_item.stock_cost, 0),
      v_item_sell_price,
      0,
      v_item_line_total,
      v_assigned_child
    );

    v_subtotal := v_subtotal + v_item_line_total;

    update public.shop_order_items
    set delivered_quantity = quantity,
        updated_at = now()
    where id = v_item.id;
  end loop;

  v_charges_total := coalesce(v_order.print_charge_amount, 0) + coalesce(v_order.packing_charge_amount, 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    shipping_charge = 0,
    print_charge = coalesce(v_order.print_charge_amount, 0),
    wrapping_charge = coalesce(v_order.packing_charge_amount, 0),
    discount_amount = coalesce(v_order.discount_amount, 0),
    total_amount = greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0),
    due_amount = greatest(v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0), 0),
    collection_source = case
      when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end,
    invoice_status = 'posted'::public.global_invoice_status,
    updated_at = now()
  where id = v_invoice.id;

  update public.shop_orders
  set
    global_invoice_id = v_invoice.id,
    updated_at = now()
  where id = v_order.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice_no,
    'subtotal_amount', v_subtotal,
    'total_amount', v_subtotal + v_charges_total - coalesce(v_order.discount_amount, 0)
  );
end;
$$;

ALTER FUNCTION "public"."create_dual_invoice_from_dropship_order"("p_order_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type", "p_source_module" "public"."global_source_module" DEFAULT 'wholesale'::"public"."global_source_module", "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_recipient_party_id" bigint DEFAULT NULL::bigint, "p_middle_man_payout_amount" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."sales_invoices"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select * from public.create_sales_invoice(
    p_tenant_id,
    p_invoice_no,
    p_billing_profile_id,
    p_invoice_type,
    p_source_module,
    p_recipient_name,
    p_recipient_phone,
    p_recipient_address,
    p_recipient_party_id,
    p_middle_man_payout_amount,
    p_note
  );
$$;

ALTER FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_retail_billing_mode" "public"."retail_billing_mode" DEFAULT NULL::"public"."retail_billing_mode", "p_due_date" "date" DEFAULT NULL::"date", "p_note" "text" DEFAULT NULL::"text", "p_invoice_date" "date" DEFAULT NULL::"date") RETURNS "public"."sales_invoices"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select * from public.create_sales_invoice(
    p_tenant_id,
    p_invoice_no,
    p_invoice_type,
    p_billing_profile_id,
    p_recipient_profile_id,
    p_recipient_name,
    p_recipient_phone,
    p_recipient_address,
    p_retail_billing_mode,
    p_due_date,
    p_note,
    p_invoice_date
  );
$$;

ALTER FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_billing_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type", "p_source_module" "public"."global_source_module" DEFAULT 'wholesale'::"public"."global_source_module", "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_recipient_party_id" bigint DEFAULT NULL::bigint, "p_middle_man_payout_amount" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."sales_invoices"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_issued_by bigint;
  v_profile public.billing_profiles;
  v_invoice_type public.global_invoice_type;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_collection_source text;
begin
  if p_billing_profile_id is null then
    raise exception 'Billing profile is required.';
  end if;

  v_invoice_type := coalesce(p_invoice_type, 'wholesale');
  v_issued_by := p_tenant_id;
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

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

  select * into v_profile from public.billing_profiles where id = p_billing_profile_id;
  if v_profile.id is null then raise exception 'Billing profile not found.'; end if;
  if v_profile.tenant_id <> v_issued_by then
    raise exception 'Billing profile does not belong to issuing tenant.';
  end if;

  if v_invoice_type = 'wholesale' then
    v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_profile.name);
    v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_profile.phone);
    v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_profile.address);
    v_collection_source := 'billing_profile';
  elsif v_invoice_type = 'retail' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for retail.'; end if;
    v_collection_source := 'billing_profile';
  elsif v_invoice_type = 'dropship' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for dropship.'; end if;
    v_collection_source := 'billing_profile';
  else
    raise exception 'Invalid invoice type.';
  end if;

  insert into public.global_invoices (
    tenant_id, parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type,
    billing_profile_id,
    recipient_name, recipient_phone, recipient_address,
    collection_source, note, due_amount
  )
  values (
    v_parent_id, v_parent_id, v_issued_by, trim(p_invoice_no), v_invoice_type,
    p_billing_profile_id,
    v_recipient_name, v_recipient_phone, v_recipient_address,
    v_collection_source, nullif(trim(coalesce(p_note, '')), ''), 0
  )
  returning * into v_row;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."generate_sales_invoice_number"(
  "p_tenant_id" bigint,
  "p_invoice_type" "public"."global_invoice_type",
  "p_date" "date" DEFAULT CURRENT_DATE
) RETURNS "text"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_type_code text;
  v_date_key text;
  v_next bigint;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;

  IF p_invoice_type IS NULL THEN
    RAISE EXCEPTION 'invoice_type is required';
  END IF;

  v_type_code := CASE p_invoice_type
    WHEN 'wholesale'::public.global_invoice_type THEN 'WS'
    WHEN 'retail'::public.global_invoice_type THEN 'RT'
    WHEN 'dropship'::public.global_invoice_type THEN 'DS'
    ELSE 'INV'
  END;

  v_date_key := to_char(COALESCE(p_date, CURRENT_DATE), 'YYYYMMDD');

  INSERT INTO public.sales_invoice_counters (tenant_id, invoice_type, date_key, last_value)
  VALUES (p_tenant_id, p_invoice_type, v_date_key, 1)
  ON CONFLICT (tenant_id, invoice_type, date_key)
  DO UPDATE
    SET last_value = public.sales_invoice_counters.last_value + 1,
        updated_at = now()
  RETURNING last_value INTO v_next;

  RETURN 'INV-' || v_type_code || '-' || v_date_key || '-' || lpad(v_next::text, 4, '0');
END;
$$;

ALTER FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_retail_billing_mode" "public"."retail_billing_mode" DEFAULT NULL::"public"."retail_billing_mode", "p_due_date" "date" DEFAULT NULL::"date", "p_note" "text" DEFAULT NULL::"text", "p_invoice_date" "date" DEFAULT NULL::"date") RETURNS "public"."sales_invoices"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.global_invoices;
  v_parent_id bigint;
  v_issued_by bigint;
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
  v_invoice_no text;
  v_invoice_date date;
begin
  v_issued_by := p_tenant_id;
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_invoice_date := coalesce(p_invoice_date, CURRENT_DATE);

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

  if p_billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles
      where id = p_billing_profile_id and tenant_id = v_issued_by
    ) then
      raise exception 'billing profile must belong to the issuing tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles
      where id = p_recipient_profile_id and tenant_id = v_issued_by
    ) then
      raise exception 'recipient profile must belong to the issuing tenant';
    end if;
  end if;

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

  if p_recipient_profile_id is not null then
    select name, phone, address
    into v_rec_name, v_rec_phone, v_rec_address
    from public.recipient_profiles
    where id = p_recipient_profile_id;
  end if;

  v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_rec_name);
  v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_rec_phone);
  v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_rec_address);

  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_billing_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.billing_profiles
    where id = p_billing_profile_id;

    v_recipient_name := coalesce(v_recipient_name, v_bill_name);
    v_recipient_phone := coalesce(v_recipient_phone, v_bill_phone);
    v_recipient_address := coalesce(v_recipient_address, v_bill_address);
  end if;

  -- Resolve invoice_no: auto-generate if omitted or empty
  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := public.generate_sales_invoice_number(p_tenant_id, p_invoice_type, v_invoice_date);
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  insert into public.global_invoices (
    tenant_id,
    parent_tenant_id,
    issued_by_tenant_id,
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
    v_parent_id,
    v_parent_id,
    v_issued_by,
    v_invoice_no,
    p_invoice_type,
    v_invoice_date,
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

ALTER FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_billing_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") OWNER TO "postgres";



CREATE OR REPLACE FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text" DEFAULT 'bank_transfer'::"text", "p_reference_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile public.billing_profiles;
  v_payout_id text;
begin
  if p_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'Tenant ID is required');
  end if;

  if p_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'Billing Profile ID is required');
  end if;

  if coalesce(p_amount, 0) <= 0 then
    return jsonb_build_object('success', false, 'error', 'Payout amount must be greater than 0');
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', p_tenant_id));
  end if;

  select * into v_profile
  from public.billing_profiles
  where id = p_billing_profile_id and tenant_id = p_tenant_id;

  if v_profile.id is null then
    return jsonb_build_object('success', false, 'error', format('Billing profile #%s not found for tenant %s', p_billing_profile_id, p_tenant_id));
  end if;

  v_payout_id := 'PO-' || gen_random_uuid()::text;

  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_tenant_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'billing_profile_id', p_billing_profile_id,
      'billing_profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_billing_profile_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.apply_dropship_payout_settlement_fifo(
    p_tenant_id,
    p_billing_profile_id,
    p_amount
  );

  return jsonb_build_object(
    'success', true,
    'payout_id', v_payout_id,
    'billing_profile_id', p_billing_profile_id,
    'amount', p_amount
  );
end;
$$;

ALTER FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_billing_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text", "p_reference_notes" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
begin
  select * into v_invoice
  from public.global_invoices
  where id = p_invoice_id;

  if v_invoice.id is null then
    return;
  end if;

  -- Only applies to posted dropship invoices with a valid billing profile and total > 0
  if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
     and v_invoice.invoice_status = 'posted'::public.global_invoice_status
     and v_invoice.billing_profile_id is not null
     and v_invoice.total_amount > 0
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
        and (metadata->>'invoice_id' = p_invoice_id::text or source_id = v_invoice.invoice_no)
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_invoice.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_source_type => 'shop_order',
        p_source_id => v_invoice.invoice_no,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', p_invoice_id
        )
      );
    end if;
  end if;
end;
$$;

ALTER FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_invoice_margin_detail"("p_invoice_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice jsonb;
  v_lines jsonb;
  v_returns jsonb;
  v_gross_profit numeric(12,2);
begin
  -- 1. Get invoice details
  select row_to_json(i)::jsonb
  into v_invoice
  from public.global_invoices i
  where i.id = p_invoice_id;

  if v_invoice is null then
    raise exception 'invoice not found';
  end if;

  -- 2. Get line margins
  select coalesce(jsonb_agg(row_to_json(l)), '[]'::jsonb)
  into v_lines
  from (
    select
      ii.*,
      ((ii.sell_price_amount - ii.unit_cost_price) * ii.quantity - ii.line_discount_amount) as line_margin
    from public.global_invoice_items ii
    where ii.invoice_id = p_invoice_id
  ) l;

  -- 3. Get return margins
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_returns
  from (
    select
      ri.*,
      (ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)) as return_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    where ri.invoice_id = p_invoice_id
  ) r;

  -- 4. Calculate total gross profit
  declare
    v_lines_margin numeric(12,2) := 0;
    v_returns_margin numeric(12,2) := 0;
    v_discount numeric(12,2);
    v_charges numeric(12,2);
  begin
    select coalesce(sum((sell_price_amount - unit_cost_price) * quantity - line_discount_amount), 0)
    into v_lines_margin
    from public.global_invoice_items
    where invoice_id = p_invoice_id;

    select coalesce(sum(ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)), 0)
    into v_returns_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    where ri.invoice_id = p_invoice_id;

    select 
      coalesce(discount_amount, 0),
      case 
        when invoice_type = 'wholesale' or invoice_type = 'dropship' then shipping_charge
        when invoice_type = 'retail' then shipping_charge + cod_charge + print_charge + wrapping_charge
        else 0.00 
      end
    into v_discount, v_charges
    from public.global_invoices
    where id = p_invoice_id;

    v_gross_profit := v_lines_margin - v_discount + v_charges - v_returns_margin;
  end;

  return jsonb_build_object(
    'invoice', v_invoice,
    'lines', v_lines,
    'returns', v_returns,
    'gross_profit', v_gross_profit
  );
end;
$$;

ALTER FUNCTION "public"."get_invoice_margin_detail"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_phone text;
  v_row public.recipient_profiles%rowtype;
  v_can_access boolean;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_can_access := public.is_tenant_staff(p_tenant_id)
    or exists (
      select 1
      from public.customer_group_members cgm
      join public.customer_groups cg on cg.id = cgm.customer_group_id
      where cg.tenant_id = p_tenant_id
        and lower(trim(cgm.email)) = public.current_user_email()
        and cgm.is_active = true
        and cg.is_active = true
    );

  if not v_can_access then
    raise exception 'access denied';
  end if;

  begin
    v_phone := public.normalize_bd_mobile(p_phone);
  exception when others then
    return null;
  end;

  select * into v_row
  from public.recipient_profiles
  where tenant_id = p_tenant_id and phone = v_phone;

  if v_row.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'name', v_row.name,
    'phone', v_row.phone,
    'secondary_phone', v_row.secondary_phone,
    'address', v_row.address,
    'district', v_row.district,
    'thana', v_row.thana,
    'addresses', v_row.addresses,
    'tenant_id', v_row.tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

ALTER FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."global_invoices_default_issued_by_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.issued_by_tenant_id is null then
    new.issued_by_tenant_id := new.tenant_id;
  end if;
  return new;
end;
$$;

ALTER FUNCTION "public"."global_invoices_default_issued_by_tenant_id"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_billing_balances"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_data jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      bp.id,
      bp.name,
      bp.email,
      bp.phone,
      bp.color,
      coalesce(sum(i.due_amount), 0.00) as balance_due,
      coalesce(sum(i.total_amount), 0.00) as total_invoiced,
      coalesce(sum(i.paid_amount), 0.00) as total_paid
    from public.billing_profiles bp
    left join public.global_invoices i on i.billing_profile_id = bp.id and i.invoice_status = 'posted'::public.global_invoice_status
    where bp.tenant_id = p_tenant_id
      and (p_search is null or p_search = '' or bp.name ilike '%' || p_search || '%' or bp.email ilike '%' || p_search || '%')
    group by bp.id
    
    union all
    
    select
      -1::bigint as id,
      'Walk-in / Direct' as name,
      null::text as email,
      null::text as phone,
      '#757575' as color,
      coalesce(sum(i.due_amount), 0.00) as balance_due,
      coalesce(sum(i.total_amount), 0.00) as total_invoiced,
      coalesce(sum(i.paid_amount), 0.00) as total_paid
    from public.global_invoices i
    where i.tenant_id = p_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.billing_profile_id is null
      and (p_search is null or p_search = '' or 'Walk-in / Direct' ilike '%' || p_search || '%')
    having count(i.id) > 0
    
    order by balance_due desc, name asc
  ) r;

  return v_data;
end;
$$;

ALTER FUNCTION "public"."list_billing_balances"("p_tenant_id" bigint, "p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) RETURNS TABLE("id" bigint, "invoice_id" bigint, "global_stock_id" bigint, "name_snapshot" "text", "quantity" numeric, "sell_price_amount" numeric, "recipient_price_amount" numeric, "line_face_total_amount" numeric, "line_discount_amount" numeric, "line_total_amount" numeric, "return_quantity" numeric, "image_url" "text", "shipment_id" bigint, "shipment_item_id" bigint, "purchase_price" numeric, "product_weight" numeric, "package_weight" numeric, "ordered_quantity" integer, "shipment_type" "text", "product_conversion_rate" numeric, "cargo_conversion_rate" numeric, "cargo_rate" numeric, "received_weight" numeric, "transaction_rate" numeric)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_issued_by bigint;
begin
  select parent_tenant_id, issued_by_tenant_id
  into v_parent_tenant_id, v_issued_by
  from public.sales_invoices
  where public.sales_invoices.id = p_invoice_id;

  if not found then
    raise exception 'Invoice with ID % not found', p_invoice_id;
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or public.has_active_tenant_membership(v_issued_by)
    or public.membership_has_module_action(v_issued_by, 'global_invoice', 'view')
  ) then
    raise exception 'Access denied for invoice with ID %', p_invoice_id;
  end if;

  return query
  select
    gii.id,
    gii.invoice_id,
    gii.global_stock_id,
    gii.name_snapshot,
    gii.quantity,
    gii.sell_price_amount,
    gii.sell_price_amount as recipient_price_amount,
    gii.line_total_amount as line_face_total_amount,
    gii.line_discount_amount,
    gii.line_total_amount,
    gii.return_quantity,
    coalesce(gsi.image_url, p.image_url) as image_url,
    gsi.shipment_id,
    gsi.id as shipment_item_id,
    gsi.purchase_price,
    gsi.product_weight,
    gsi.package_weight,
    gsi.ordered_quantity,
    gship.type::text as shipment_type,
    null::numeric as product_conversion_rate,
    null::numeric as cargo_conversion_rate,
    null::numeric as cargo_rate,
    gship.received_weight,
    null::numeric as transaction_rate
  from public.sales_invoice_items gii
  left join public.global_stocks gs on gs.id = gii.global_stock_id
  left join public.global_shipment_items gsi
    on gsi.id = coalesce(gii.shipment_item_id, gs.shipment_item_id)
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  left join public.products p on p.id = gii.product_id
  where gii.invoice_id = p_invoice_id
  order by gii.id;
end;
$$;

ALTER FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_invoice_margin_report"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_search" "text" DEFAULT NULL::"text", "p_invoice_type" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_is_parent boolean;
  v_total_count bigint;
  v_data jsonb;
  v_total_pages integer;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent := public.is_parent_company(p_tenant_id);

  -- 1. Get total count of matching posted invoices
  select count(*)
  into v_total_count
  from public.global_invoices i
  where (
    (v_is_parent = true and i.parent_tenant_id = v_parent_id)
    or (v_is_parent = false and i.tenant_id = p_tenant_id)
  )
    and i.invoice_status = 'posted'::public.global_invoice_status
    and (p_start_date is null or i.invoice_date >= p_start_date)
    and (p_end_date is null or i.invoice_date <= p_end_date)
    and (p_invoice_type is null or p_invoice_type = '' or p_invoice_type = '__all__' or i.invoice_type::text = p_invoice_type)
    and (
      p_search is null or p_search = '' or (
        i.invoice_no ilike '%' || p_search || '%'
        or i.recipient_name ilike '%' || p_search || '%'
      )
    );

  -- 2. Get paginated records as a jsonb array with derived gross profit
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    with invoice_line_margin as (
      select
        invoice_id,
        sum((sell_price_amount - unit_cost_price) * quantity - line_discount_amount) as lines_margin
      from public.global_invoice_items
      group by invoice_id
    ),
    invoice_return_margin as (
      select
        ri.invoice_id,
        sum(ri.return_accounting_amount - (ii.unit_cost_price * ri.quantity)) as returns_margin
      from public.global_return_items ri
      join public.global_invoice_items ii on ii.id = ri.invoice_item_id
      group by ri.invoice_id
    )
    select
      i.*,
      coalesce(lm.lines_margin, 0.00) 
        - i.discount_amount 
        + (case 
             when i.invoice_type = 'wholesale' or i.invoice_type = 'dropship' then i.shipping_charge
             when i.invoice_type = 'retail' then i.shipping_charge + i.cod_charge + i.print_charge + i.wrapping_charge
             else 0.00 
           end)
        - coalesce(rm.returns_margin, 0.00) as gross_profit
    from public.global_invoices i
    left join invoice_line_margin lm on lm.invoice_id = i.id
    left join invoice_return_margin rm on rm.invoice_id = i.id
    where (
      (v_is_parent = true and i.parent_tenant_id = v_parent_id)
      or (v_is_parent = false and i.tenant_id = p_tenant_id)
    )
      and i.invoice_status = 'posted'::public.global_invoice_status
      and (p_start_date is null or i.invoice_date >= p_start_date)
      and (p_end_date is null or i.invoice_date <= p_end_date)
      and (p_invoice_type is null or p_invoice_type = '' or p_invoice_type = '__all__' or i.invoice_type::text = p_invoice_type)
      and (
        p_search is null or p_search = '' or (
          i.invoice_no ilike '%' || p_search || '%'
          or i.recipient_name ilike '%' || p_search || '%'
        )
      )
    order by i.invoice_date desc, i.id desc
    limit p_page_size
    offset (greatest(coalesce(p_page, 1), 1) - 1) * p_page_size
  ) r;

  -- 3. Calculate total pages
  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::float / p_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', p_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$$;

ALTER FUNCTION "public"."list_invoice_margin_report"("p_tenant_id" bigint, "p_page" integer, "p_page_size" integer, "p_start_date" "date", "p_end_date" "date", "p_search" "text", "p_invoice_type" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."list_invoice_outstanding"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_data jsonb;
begin
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_data
  from (
    select
      i.id,
      i.invoice_no,
      i.invoice_date,
      i.invoice_type,
      i.payment_status,
      i.total_amount,
      i.due_amount,
      i.paid_amount,
      i.recipient_name,
      i.recipient_phone,
      i.billing_profile_id,
      bp.name as billing_profile_name
    from public.global_invoices i
    left join public.billing_profiles bp on bp.id = i.billing_profile_id
    where i.tenant_id = p_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.due_amount > 0
      and (p_search is null or p_search = '' or i.invoice_no ilike '%' || p_search || '%' or i.recipient_name ilike '%' || p_search || '%')
    order by i.invoice_date desc, i.id desc
  ) r;

  return v_data;
end;
$$;

ALTER FUNCTION "public"."list_invoice_outstanding"("p_tenant_id" bigint, "p_search" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."post_global_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.post_sales_invoice(p_invoice_id);
end;
$$;

ALTER FUNCTION "public"."post_global_invoice"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'only draft or proforma invoices can be posted/issued';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  -- Validate required fields per invoice type
  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
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

  -- 1. Snapshot unit costs on line items
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  -- 2. Deduct physical stock & write stock movement audit
  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent_id,
    v_mov_no,
    'adjustment'::public.stock_movement_type,
    'sales_invoice',
    p_invoice_id::text,
    'Issued ' || upper(v_invoice.invoice_type::text) || ' Invoice #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_qty := ceil(v_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
    if v_stock.id is not null then
      -- Deduct from global_stocks
      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_item.global_stock_id;

      -- Insert movement line
      insert into public.stock_movement_lines (
        movement_id,
        stock_id,
        quantity,
        from_location_id,
        to_location_id,
        from_availability,
        to_availability
      ) values (
        v_mov_id,
        v_item.global_stock_id,
        v_qty,
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        v_stock.availability
      );
    end if;
  end loop;

  -- 3. Mark invoice as posted/issued
  update public.global_invoices
  set invoice_status = 'posted'::public.global_invoice_status
  where id = p_invoice_id;

  -- 4. Universal wallet: Only for non-wholesale account invoices
  if v_invoice.invoice_type <> 'wholesale'::public.global_invoice_type
     and v_invoice.billing_profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
        p_type => 'debit',
        p_amount => v_invoice.total_amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'invoices',
          'purpose', 'invoice_billed',
          'transaction_type', 'invoice_billed',
          'label', 'Invoice Billed',
          'invoice_no', v_invoice.invoice_no,
          'invoice_id', v_invoice.id,
          'invoice_type', v_invoice.invoice_type
        )
      );
    end if;
  end if;
end;
$$;

ALTER FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_global_invoice_payment_status"("p_global_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_total numeric(12,2);
  v_paid numeric(12,2);
begin
  select total_amount, coalesce(paid_amount, 0.00)
  into v_total, v_paid
  from public.global_invoices
  where id = p_global_invoice_id;

  if not found then return; end if;

  update public.global_invoices
  set
    payment_status = case
      when coalesce(v_paid, 0.00) <= 0.00 then 'due'
      when v_paid >= coalesce(v_total, 0.00) then 'paid'
      else 'partially_paid'
    end,
    due_amount = greatest(coalesce(v_total, 0.00) - coalesce(v_paid, 0.00), 0.00),
    updated_at = now()
  where id = p_global_invoice_id;
end;
$$;

ALTER FUNCTION "public"."recompute_global_invoice_payment_status"("p_global_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."recompute_global_invoice_totals"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
  v_subtotal numeric(12,2) := 0;
  v_charges numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id;
  if v_invoice.id is null then return; end if;

  select coalesce(sum(line_total_amount), 0)
  into v_subtotal
  from public.global_invoice_items
  where invoice_id = p_invoice_id;

  v_charges := coalesce(v_invoice.shipping_charge, 0) 
             + coalesce(v_invoice.wrapping_charge, 0) 
             + coalesce(v_invoice.print_charge, 0);

  v_discount := coalesce(v_invoice.discount_amount, 0);
  v_paid := coalesce(v_invoice.paid_amount, 0);

  v_total := greatest(v_subtotal + v_charges - v_discount, 0);

  update public.global_invoices
  set
    subtotal_amount = v_subtotal,
    total_amount = v_total,
    due_amount = greatest(v_total - v_paid, 0),
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

ALTER FUNCTION "public"."recompute_global_invoice_totals"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."record_recipient_invoice_collection"("p_global_invoice_id" bigint, "p_amount" numeric, "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_reference" "text" DEFAULT NULL::"text", "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."sales_invoices"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
  v_payment_id bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_invoice.tenant_id,
    null,
    'recipient'::public.collection_source_type,
    p_amount,
    0.00,
    coalesce(p_payment_date, current_date),
    p_method,
    p_reference,
    nullif(trim(p_note), '')
  )
  returning id into v_payment_id;

  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.tenant_id, v_payment_id, p_global_invoice_id, p_amount);

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  -- Record Tenant Cash Credit for direct cash collection
  perform public.record_ledger_transaction(
    p_tenant_id => v_invoice.tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_invoice.tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'sales_invoice',
    p_source_id => p_global_invoice_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'recipient_cash_collection',
      'transaction_type', 'cash_collected',
      'label', 'Direct Cash Collection',
      'payment_id', v_payment_id,
      'invoice_id', p_global_invoice_id,
      'invoice_no', v_invoice.invoice_no
    )
  );

  return v_invoice;
end;
$$;

ALTER FUNCTION "public"."record_recipient_invoice_collection"("p_global_invoice_id" bigint, "p_amount" numeric, "p_payment_date" "date", "p_method" "text", "p_reference" "text", "p_note" "text") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."remove_global_invoice_item"("p_invoice_item_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

ALTER FUNCTION "public"."remove_global_invoice_item"("p_invoice_item_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."resolve_billing_profile_for_customer_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_billing_profile_id bigint;
begin
  select id into v_billing_profile_id
  from public.billing_profiles
  where tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
  order by id
  limit 1;
  
  return v_billing_profile_id;
end;
$$;

ALTER FUNCTION "public"."resolve_billing_profile_for_customer_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."sync_shop_order_collection_source_from_invoice"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_src public.collection_source_type;
begin
  if new.global_invoice_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.global_invoice_id is not distinct from new.global_invoice_id
     and new.collection_source is not null then
    return new;
  end if;

  select collection_source into v_src
  from public.global_invoices
  where id = new.global_invoice_id;

  if v_src is not null then
    new.collection_source := v_src;
    if new.payout_settlement_status is null
       and new.shop_type_snapshot = 'dropship' then
      new.payout_settlement_status := 'unpaid';
    end if;
  end if;

  return new;
end;
$$;

ALTER FUNCTION "public"."sync_shop_order_collection_source_from_invoice"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_auto_create_billing_profile_for_customer_group"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not exists (
    select 1 from public.billing_profiles
    where tenant_id = new.tenant_id
      and customer_group_id = new.id
  ) then
    insert into public.billing_profiles (
      tenant_id,
      customer_group_id,
      name,
      email,
      phone,
      address,
      color,
      created_at,
      updated_at
    )
    values (
      new.tenant_id,
      new.id,
      new.name,
      null,
      null,
      null,
      new.accent_color,
      now(),
      now()
    );
  end if;
  return new;
end;
$$;

ALTER FUNCTION "public"."trg_auto_create_billing_profile_for_customer_group"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_global_invoice_items_stock_sync"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

ALTER FUNCTION "public"."trg_fn_global_invoice_items_stock_sync"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_fn_global_invoices_stock_sync"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

ALTER FUNCTION "public"."trg_fn_global_invoices_stock_sync"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."trg_validate_global_invoice_profiles"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    AS $$
begin
  if new.billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles bp
      where bp.id = new.billing_profile_id
        and bp.tenant_id = new.issued_by_tenant_id
    ) then
      raise exception 'Billing profile tenant_id must match invoice issued_by_tenant_id';
    end if;
  end if;

  if new.recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles rp
      where rp.id = new.recipient_profile_id
        and rp.tenant_id = new.issued_by_tenant_id
    ) then
      raise exception 'Recipient profile tenant_id must match invoice issued_by_tenant_id';
    end if;
  end if;

  return new;
end;
$$;

ALTER FUNCTION "public"."trg_validate_global_invoice_profiles"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unpost_global_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.unpost_sales_invoice(p_invoice_id);
end;
$$;

ALTER FUNCTION "public"."unpost_global_invoice"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."unpost_sales_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

ALTER FUNCTION "public"."unpost_sales_invoice"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_global_invoice_header"("p_invoice_id" bigint, "p_discount_amount" numeric DEFAULT NULL::numeric, "p_shipping_charge" numeric DEFAULT NULL::numeric, "p_cod_charge" numeric DEFAULT NULL::numeric, "p_wrapping_charge" numeric DEFAULT NULL::numeric, "p_print_charge" numeric DEFAULT NULL::numeric, "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_note" "text" DEFAULT NULL::"text", "p_invoice_no" "text" DEFAULT NULL::"text", "p_invoice_date" "date" DEFAULT NULL::"date") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    note = coalesce(nullif(trim(p_note), ''), note),
    invoice_no = coalesce(nullif(trim(p_invoice_no), ''), invoice_no),
    invoice_date = coalesce(p_invoice_date, invoice_date)
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$$;

ALTER FUNCTION "public"."update_global_invoice_header"("p_invoice_id" bigint, "p_discount_amount" numeric, "p_shipping_charge" numeric, "p_cod_charge" numeric, "p_wrapping_charge" numeric, "p_print_charge" numeric, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_note" "text", "p_invoice_no" "text", "p_invoice_date" "date") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."update_global_invoice_item"(
  "p_item_id" bigint,
  "p_quantity" numeric,
  "p_sell_price_amount" numeric,
  "p_recipient_price_amount" numeric DEFAULT NULL::numeric
) RETURNS "public"."sales_invoice_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.sales_invoice_items;
  v_invoice public.sales_invoices;
  v_line_total numeric;
begin
  select * into v_item from public.sales_invoice_items where id = p_item_id;
  if v_item.id is null then raise exception 'Invoice item not found'; end if;

  select * into v_invoice from public.sales_invoices where id = v_item.invoice_id;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Cannot edit items on a posted or voided invoice';
  end if;

  if p_quantity <= 0 then
    raise exception 'Quantity must be greater than 0';
  end if;

  if p_sell_price_amount < 0 then
    raise exception 'Sell price cannot be negative';
  end if;

  v_line_total := greatest((p_quantity * p_sell_price_amount) - coalesce(v_item.line_discount_amount, 0.00), 0.00);

  update public.sales_invoice_items
  set
    quantity = p_quantity,
    sell_price_amount = p_sell_price_amount,
    line_total_amount = v_line_total
  where id = p_item_id
  returning * into v_item;

  perform public.recompute_global_invoice_totals(v_item.invoice_id);

  return v_item;
end;
$$;

ALTER FUNCTION "public"."update_global_invoice_item"("p_item_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_recipient_price_amount" numeric) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."void_global_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  perform public.void_sales_invoice(p_invoice_id);
end;
$$;

ALTER FUNCTION "public"."void_global_invoice"("p_invoice_id" bigint) OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."void_sales_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

ALTER FUNCTION "public"."void_sales_invoice"("p_invoice_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."search_sales_invoice_stock"(
  "p_tenant_id" bigint,
  "p_search" "text" DEFAULT NULL::"text",
  "p_limit" integer DEFAULT 50,
  "p_offset" integer DEFAULT 0
) RETURNS TABLE(
  "global_stock_id" bigint,
  "shipment_item_id" bigint,
  "product_id" bigint,
  "name" "text",
  "barcode" "text",
  "product_code" "text",
  "image_url" "text",
  "quantity" numeric,
  "available_atp" numeric,
  "unit_cost_price" numeric,
  "suggested_sell_price" numeric,
  "shipment_id" bigint,
  "shipment_name" "text",
  "holding_tenant_id" bigint,
  "holding_tenant_name" "text",
  "is_allocated_to_tenant" boolean,
  "allocation_rank" integer,
  "location_id" bigint,
  "location_name" "text",
  "stock_created_at" timestamp with time zone
)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_is_parent_context boolean;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent_context := (p_tenant_id = v_parent_id);

  -- Verify membership & access (checks active tenant or parent tenant membership)
  if not exists (
    select 1
    from public.memberships m
    where (m.tenant_id = p_tenant_id or m.tenant_id = v_parent_id)
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  return query
  select
    gs.id as global_stock_id,
    gsi.id as shipment_item_id,
    gsi.product_id,
    gsi.name,
    gsi.barcode,
    gsi.product_code,
    gsi.image_url,
    gs.quantity::numeric as quantity,
    public.global_stock_atp_qty(gs.id)::numeric as available_atp,
    coalesce(gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric as unit_cost_price,
    coalesce(p.list_price_amount, 0)::numeric as suggested_sell_price,
    sh.id as shipment_id,
    sh.name as shipment_name,
    coalesce(sh.assigned_child_tenant_id, v_parent_id) as holding_tenant_id,
    coalesce(ht.name, pt.name) as holding_tenant_name,
    (coalesce(sh.assigned_child_tenant_id, v_parent_id) = p_tenant_id) as is_allocated_to_tenant,
    case
      -- 0 = Directly allocated to the requesting child/sister tenant
      when sh.assigned_child_tenant_id = p_tenant_id then 0
      -- 1 = Parent company stock / unallocated to specific child
      when sh.assigned_child_tenant_id is null or sh.assigned_child_tenant_id = v_parent_id then 1
      -- 2 = Allocated to another sister concern (visible in parent context)
      else 2
    end as allocation_rank,
    gs.location_id,
    sl.name as location_name,
    gs.created_at as stock_created_at
  from public.global_stocks gs
  inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  inner join public.global_shipments sh on sh.id = gsi.shipment_id
  inner join public.tenants pt on pt.id = v_parent_id
  left join public.tenants ht on ht.id = coalesce(sh.assigned_child_tenant_id, v_parent_id)
  left join public.stock_locations sl on sl.id = gs.location_id
  left join public.products p on p.id = gsi.product_id
  where gs.parent_tenant_id = v_parent_id
    and (
      v_is_parent_context
      or sh.assigned_child_tenant_id is null
      or sh.assigned_child_tenant_id = p_tenant_id
    )
    and sh.status = 'received'
    and gs.availability = 'sellable'::public.stock_availability
    and gs.quantity > 0
    and (
      p_search is null
      or trim(p_search) = ''
      or (
        select coalesce(bool_and(
          gsi.name ilike '%' || trim(word) || '%'
          or coalesce(gsi.barcode, '') ilike '%' || trim(word) || '%'
          or coalesce(gsi.product_code, '') ilike '%' || trim(word) || '%'
          or coalesce(p.name, '') ilike '%' || trim(word) || '%'
        ), true)
        from unnest(string_to_array(trim(p_search), ' ')) as word
        where trim(word) <> ''
      )
    )
  order by
    -- 1. Show items allocated to the tenant first, then parent/unallocated, then others
    case
      when sh.assigned_child_tenant_id = p_tenant_id then 0
      when sh.assigned_child_tenant_id is null or sh.assigned_child_tenant_id = v_parent_id then 1
      else 2
    end asc,
    -- 2. FIFO Order: Oldest stock (earliest insert date) appears first
    gs.created_at asc,
    gs.id asc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$$;

ALTER FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_wholesale_invoice"(
  "p_invoice_id" bigint,
  "p_items" jsonb DEFAULT NULL
) RETURNS "public"."sales_invoices"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.sales_invoices;
  v_item_record jsonb;
  v_item_id bigint;
  v_item_qty numeric;
  v_item_price numeric;
  v_line_total numeric;
  v_db_item public.sales_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.sales_invoices where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can be issued';
  end if;

  if v_invoice.billing_profile_id is null then
    raise exception 'Billing profile is required for wholesale invoices';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  -- 1. Optionally apply batch quantity/price updates from dialog payload
  if p_items is not null and jsonb_typeof(p_items) = 'array' and jsonb_array_length(p_items) > 0 then
    for v_item_record in select * from jsonb_array_elements(p_items) loop
      v_item_id := (v_item_record->>'id')::bigint;
      v_item_qty := (v_item_record->>'quantity')::numeric;
      v_item_price := (v_item_record->>'sell_price_amount')::numeric;

      if v_item_id is not null and v_item_qty is not null and v_item_qty > 0 then
        select * into v_db_item from public.sales_invoice_items where id = v_item_id and invoice_id = p_invoice_id;
        if v_db_item.id is not null then
          v_item_price := coalesce(v_item_price, v_db_item.sell_price_amount);
          v_line_total := greatest((v_item_qty * v_item_price) - coalesce(v_db_item.line_discount_amount, 0.00), 0.00);

          update public.sales_invoice_items
          set
            quantity = v_item_qty,
            sell_price_amount = v_item_price,
            line_total_amount = v_line_total
          where id = v_item_id;
        end if;
      end if;
    end loop;

    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  if not exists (select 1 from public.sales_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'Cannot issue an empty invoice';
  end if;

  -- 2. Snapshot unit landed costs on line items
  for v_db_item in select * from public.sales_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_db_item.shipment_item_id);
    update public.sales_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_db_item.id;
  end loop;

  -- 3. Create stock movement audit record
  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  insert into public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) values (
    v_parent_id,
    v_mov_no,
    'adjustment'::public.stock_movement_type,
    'sales_invoice',
    p_invoice_id::text,
    'Issued Wholesale Invoice #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  -- 4. Deduct warehouse stock and record movement lines
  for v_db_item in select * from public.sales_invoice_items where invoice_id = p_invoice_id loop
    v_qty := ceil(v_db_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_db_item.global_stock_id for update;
    if v_stock.id is not null then
      if v_stock.quantity < v_qty then
        raise exception 'Insufficient stock for % (requested %, available %)', v_db_item.name_snapshot, v_qty, v_stock.quantity;
      end if;

      -- Deduct from global_stocks
      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_db_item.global_stock_id;

      -- Insert movement line
      insert into public.stock_movement_lines (
        movement_id,
        stock_id,
        quantity,
        from_location_id,
        to_location_id,
        from_availability,
        to_availability
      ) values (
        v_mov_id,
        v_db_item.global_stock_id,
        v_qty,
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        v_stock.availability
      );
    end if;
  end loop;

  -- 5. Mark invoice as posted/issued (no wallet touch)
  update public.sales_invoices
  set
    invoice_status = 'posted'::public.global_invoice_status,
    payment_status = coalesce(nullif(payment_status, ''), 'due')
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

ALTER FUNCTION "public"."issue_wholesale_invoice"("p_invoice_id" bigint, "p_items" jsonb) OWNER TO "postgres";


