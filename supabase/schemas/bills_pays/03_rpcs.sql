-- bills_pays: bill, receipt, cashbook, and profile-sync functions.

CREATE OR REPLACE FUNCTION "public"."_undo_wallet_ledger_row_before_delete"("p_row" "public"."cashbook_entries") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bucket text;
begin
  v_bucket := coalesce(p_row.metadata->>'target_bucket', 'available');

  update public.cashbook_accounts wa
  set
    available_balance = case
      when v_bucket = 'available' and p_row.type = 'credit' then wa.available_balance - p_row.amount
      when v_bucket = 'available' and p_row.type = 'debit' then wa.available_balance + p_row.amount
      else wa.available_balance
    end,
    pending_balance = case
      when v_bucket = 'pending' and p_row.type = 'credit' then wa.pending_balance - p_row.amount
      when v_bucket = 'pending' and p_row.type = 'debit' then wa.pending_balance + p_row.amount
      else wa.pending_balance
    end,
    locked_balance = case
      when v_bucket = 'locked' and p_row.type = 'credit' then wa.locked_balance - p_row.amount
      when v_bucket = 'locked' and p_row.type = 'debit' then wa.locked_balance + p_row.amount
      else wa.locked_balance
    end,
    updated_at = now()
  where wa.parent_tenant_id = p_row.parent_tenant_id
    and wa.entity_type = p_row.entity_type
    and wa.entity_id = p_row.entity_id
    and wa.currency_code = p_row.currency_code;
end;
$$;

ALTER FUNCTION "public"."_undo_wallet_ledger_row_before_delete"("p_row" "public"."cashbook_entries") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."add_global_invoice_item"("p_invoice_id" bigint, "p_global_stock_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_line_discount_amount" numeric DEFAULT 0, "p_recipient_price_amount" numeric DEFAULT NULL::numeric) RETURNS "public"."bill_lines"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_stock public.global_stocks;
  v_row public.bill_lines;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_line_total numeric;
  v_product_id bigint;
  v_unit_cost numeric;
  v_qty_remaining numeric;
  v_avail numeric;
  v_take numeric;
  v_existing_qty numeric;
  v_curr_stock_id bigint;
  v_shipment_item_id bigint;
  v_assigned_child bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id;
  if v_invoice.id is null then
    raise exception 'invoice not found';
  end if;

  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot add items to a non-draft invoice';
  end if;

  select * into v_stock from public.global_stocks where id = p_global_stock_id;
  if v_stock.id is null then
    raise exception 'stock not found';
  end if;

  if v_stock.parent_tenant_id <> v_invoice.parent_tenant_id then
    raise exception 'stock must belong to the same parent tenant group';
  end if;

  select product_id into v_product_id
  from public.global_shipment_items
  where id = v_stock.shipment_item_id;

  v_qty_remaining := p_quantity;
  v_curr_stock_id := p_global_stock_id;

  v_avail := public.global_stock_atp_qty(v_curr_stock_id);

  select coalesce(sum(quantity), 0) into v_existing_qty
  from public.bill_lines
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

    insert into public.bill_lines (
      parent_tenant_id,
      invoice_id,
      global_stock_id,
      shipment_item_id,
      product_id,
      name_snapshot,
      barcode_snapshot,
      product_code_snapshot,
      quantity,
      sell_price_amount,
      line_discount_amount,
      line_total_amount,
      return_quantity,
      assigned_child_tenant_id
    )
    values (
      v_invoice.parent_tenant_id,
      p_invoice_id,
      v_curr_stock_id,
      v_shipment_item_id,
      v_product_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_take,
      p_sell_price_amount,
      coalesce(p_line_discount_amount, 0.00),
      v_line_total,
      0.00,
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
  v_invoice public.bills;
  v_item public.global_invoice_items;
  v_row public.global_return_items;
  v_parent bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
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
    v_invoice.parent_tenant_id,
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

  v_parent := coalesce(v_invoice.parent_tenant_id, public.resolve_parent_tenant_id(v_invoice.parent_tenant_id));

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

CREATE OR REPLACE FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) RETURNS "public"."pay_allocations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_payment public.pays;
  v_invoice public.bills;
  v_row public.pay_allocations;
begin
  if p_tenant_id is null or p_payment_id is null or p_global_invoice_id is null then
    raise exception 'Tenant, payment and invoice are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Allocation amount must be greater than zero.';
  end if;

  -- Lock payment
  select * into v_payment from public.pays where id = p_payment_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if v_payment.tenant_id <> p_tenant_id then raise exception 'Payment tenant mismatch.'; end if;
  if v_payment.voided_at is not null then raise exception 'Payment is voided.'; end if;
  if v_payment.source not in ('customer_cash', 'bank') then
    raise exception 'Only customer cash/bank leftover can be allocated later.';
  end if;

  -- Lock invoice
  select * into v_invoice from public.bills where id = p_global_invoice_id for update;
  if not found then raise exception 'Invoice not found.'; end if;
  if v_invoice.parent_tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill % is not issued', v_invoice.invoice_no;
  end if;

  -- Validate same billing profile
  if coalesce(v_invoice.profile_id, 0) <> coalesce(v_payment.profile_id, 0) then
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
  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
  values (p_tenant_id, p_payment_id, p_global_invoice_id, p_global_invoice_id, p_amount)
  returning * into v_row;

  -- Update payment unallocated amount
  update public.pays
  set unallocated_amount = unallocated_amount - p_amount
  where id = p_payment_id;

  -- Recompute invoice payment status and due_amount
  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  -- Leftover was credited to customer cashbook at collect; apply it now.
  if v_payment.profile_id is not null then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => p_tenant_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_payment.profile_id,
      p_type => 'debit',
      p_amount => p_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => p_payment_id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied leftover to bill',
        'payment_id', p_payment_id,
        'bill_id', p_global_invoice_id
      )
    );
  end if;

  return v_row;
end;
$$;

ALTER FUNCTION "public"."allocate_payment_to_global_invoice"("p_tenant_id" bigint, "p_payment_id" bigint, "p_global_invoice_id" bigint, "p_amount" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_parent_id bigint;
  v_operating_tenant_id bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'cannot settle a non-posted invoice';
  end if;
  if coalesce(p_amount, 0.00) < 0.00 then
    raise exception 'settlement amount must be 0 or greater';
  end if;
  if coalesce(p_amount, 0.00) > coalesce(v_invoice.due_amount, 0.00) then
    raise exception 'settlement amount exceeds outstanding due';
  end if;

  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.parent_tenant_id);
  v_operating_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);

  if coalesce(p_amount, 0.00) > 0.00 then
    insert into public.invoice_write_offs (
      tenant_id,
      parent_tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    values (
      v_operating_tenant_id,
      v_parent_id,
      p_invoice_id,
      null,
      p_amount,
      'management_concession',
      p_note,
      auth.uid()
    );
  end if;

  if nullif(trim(p_note), '') is not null then
    update public.bills
    set
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
    where id = p_invoice_id;
  end if;

  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  select * into v_invoice from public.bills where id = p_invoice_id;

  -- Record Tenant Revenue Write-Off for settlement discount
  if p_amount > 0 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => coalesce(v_invoice.parent_tenant_id, v_invoice.parent_tenant_id),
      p_operating_tenant_id => coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id, v_invoice.parent_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => coalesce(v_invoice.parent_tenant_id, v_invoice.parent_tenant_id),
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
  v_invoice public.bills;
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
  select * into v_invoice from public.bills where id = p_invoice_id;
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

CREATE OR REPLACE FUNCTION "public"."profile_valid_for_issuer"("p_profile_id" bigint, "p_issued_by_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.profiles pr
    where pr.id = p_profile_id
      and pr.deleted_at is null
      and (
        pr.parent_tenant_id = p_issued_by_tenant_id
        or pr.parent_tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = p_issued_by_tenant_id
            and t.parent_id = pr.parent_tenant_id
        )
        or (
          pr.profile_type = 'customer'::public.profile_party_type
          and (
            pr.operating_tenant_id = p_issued_by_tenant_id
            or pr.operating_tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
            or coalesce(pr.parent_tenant_id, pr.operating_tenant_id)
              = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
            or exists (
              select 1
              from public.tenants t
              where t.id = pr.operating_tenant_id
                and t.parent_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
            )
          )
        )
      )
  );
$$;

ALTER FUNCTION "public"."profile_valid_for_issuer"("p_profile_id" bigint, "p_issued_by_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint DEFAULT NULL::bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_profile_id bigint;
  v_invoice_no text;
  v_pick record;
  v_items jsonb := '[]'::jsonb;
  v_item_json jsonb;
  v_item_sell_price numeric(12,2);
  v_resell_price numeric(12,2);
  v_unit_cost numeric(12,2);
  v_line_id bigint;
  v_held public.global_stocks;
  v_charges record;
  v_channel_meta jsonb;
  v_gift record;
  v_gift_stock_id bigint;
  v_gift_shipment_item_id bigint;
  v_gift_name text;
  v_gift_barcode text;
  v_gift_product_code text;
  v_gift_assigned_child bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'ready_for_pickup'::public.shop_order_status,
    'shipped'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'tenant B2B invoice requires ready_for_pickup, shipped, or delivered (current: %s)',
        v_order.status
      )
    );
  end if;

  v_profile_id := coalesce(p_profile_id, v_order.profile_id);
  if v_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required on the order');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_channel_meta := jsonb_strip_nulls(jsonb_build_object(
    'cod_collect_amount', v_order.cod_collect_amount,
    'collection_source', 'profile',
    'recipient_name', coalesce(v_order.recipient_name, v_order.name),
    'recipient_phone', v_order.recipient_phone,
    'recipient_address', v_order.shipping_address
  ));

  select * into v_charges
  from public.get_dropship_merchant_billable_charges(p_order_id);

  for v_pick in (
    select
      sp.id as pick_id,
      sp.order_item_id,
      sp.quantity as pick_quantity,
      sp.held_stock_id,
      sp.global_stock_id as source_stock_id,
      soi.product_id,
      soi.name as line_name,
      soi.unit_sell_price_amount,
      soi.final_price_amount,
      soi.customer_sell_price_amount,
      coalesce(soi.is_gift, false) as is_gift,
      soi.gift_source,
      coalesce(soi.gift_cost_amount, 0) as gift_cost_amount,
      soi.gift_cost_charged_to,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_item_stock_picks sp
    join public.shop_order_items soi on soi.id = sp.order_item_id
    left join public.global_stocks gs on gs.id = sp.held_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where sp.order_id = v_order.id
      and sp.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
  ) loop
    if v_pick.held_stock_id is null then
      return jsonb_build_object(
        'success', false,
        'error', format('pick %s is missing held_stock_id', v_pick.pick_id)
      );
    end if;

    select * into v_held from public.global_stocks where id = v_pick.held_stock_id;
    if v_held.id is null then
      return jsonb_build_object(
        'success', false,
        'error', format('held stock %s not found for pick %s', v_pick.held_stock_id, v_pick.pick_id)
      );
    end if;

    if v_held.availability <> 'held'::public.stock_availability then
      return jsonb_build_object(
        'success', false,
        'error', format('held stock %s must be held before issue (current: %s)', v_pick.held_stock_id, v_held.availability)
      );
    end if;

    if coalesce(v_pick.is_gift, false) and v_pick.gift_source = 'stock' and v_pick.gift_cost_charged_to = 'reseller' then
      v_item_sell_price := case
        when coalesce(v_pick.pick_quantity, 0) > 0 then
          round(coalesce(v_pick.gift_cost_amount, 0) / v_pick.pick_quantity, 2)
        else coalesce(v_pick.gift_cost_amount, 0)
      end;
    else
      v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
    end if;
    v_resell_price := coalesce(
      v_pick.customer_sell_price_amount,
      v_pick.final_price_amount,
      v_pick.unit_sell_price_amount,
      0
    );
    v_unit_cost := coalesce(v_pick.stock_cost, 0);
    v_line_id := null;

    if p_invoice_id is not null then
      select sii.id into v_line_id
      from public.bill_lines sii
      where sii.invoice_id = p_invoice_id
        and sii.global_stock_id = v_pick.held_stock_id
      order by sii.id
      limit 1;
    end if;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'id', v_line_id,
      'global_stock_id', v_pick.held_stock_id,
      'product_id', v_pick.product_id,
      'shipment_item_id', v_pick.stock_shipment_item_id,
      'name_snapshot',
        coalesce(v_pick.stock_name, v_pick.line_name)
        || case
          when coalesce(v_pick.is_gift, false)
            and v_pick.gift_source = 'stock'
            and v_pick.gift_cost_charged_to = 'reseller'
          then ' (Gift)'
          else ''
        end,
      'barcode_snapshot', v_pick.stock_barcode,
      'product_code_snapshot', v_pick.stock_product_code,
      'quantity', v_pick.pick_quantity,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_pick.stock_assigned_child,
      'line_meta',
        jsonb_build_object('resell_price_amount', v_resell_price)
        || case
          when coalesce(v_pick.is_gift, false)
            and v_pick.gift_source = 'stock'
            and v_pick.gift_cost_charged_to = 'reseller'
          then jsonb_build_object(
            'gift_line_total_amount', coalesce(v_pick.gift_cost_amount, 0),
            'is_warehouse_gift', true
          )
          else '{}'::jsonb
        end
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  for v_gift in
    select
      soi.id as order_item_id,
      soi.product_id,
      soi.name as line_name,
      soi.quantity,
      coalesce(soi.gift_cost_amount, 0) as gift_cost_amount,
      p.barcode as product_barcode,
      p.product_code as product_code
    from public.shop_order_items soi
    left join public.products p on p.id = soi.product_id
    where soi.order_id = v_order.id
      and coalesce(soi.is_gift, false)
      and soi.gift_source = 'stock'
      and soi.gift_cost_charged_to = 'reseller'
      and coalesce(soi.gift_cost_amount, 0) > 0
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  loop
    v_gift_shipment_item_id := null;
    v_gift_name := v_gift.line_name;
    v_gift_barcode := v_gift.product_barcode;
    v_gift_product_code := v_gift.product_code;
    v_gift_assigned_child := null;

    select
      gs.shipment_item_id,
      coalesce(gsi.name, v_gift.line_name),
      gsi.barcode,
      gsi.product_code,
      sh.assigned_child_tenant_id
    into
      v_gift_shipment_item_id,
      v_gift_name,
      v_gift_barcode,
      v_gift_product_code,
      v_gift_assigned_child
    from public.global_stock_allocations gsa
    inner join public.global_stocks gs on gs.id = gsa.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where gsa.shop_id = v_order.shop_id
      and gs.product_id = v_gift.product_id
    order by public.global_stock_atp_qty(gs.id) desc, gs.id
    limit 1;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'product_id', v_gift.product_id,
      'shipment_item_id', v_gift_shipment_item_id,
      'name_snapshot', v_gift_name || ' (Gift)',
      'barcode_snapshot', v_gift_barcode,
      'product_code_snapshot', v_gift_product_code,
      'quantity', v_gift.quantity,
      'sell_price_amount', case
        when coalesce(v_gift.quantity, 0) > 0 then
          round(coalesce(v_gift.gift_cost_amount, 0) / v_gift.quantity, 2)
        else coalesce(v_gift.gift_cost_amount, 0)
      end,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_gift_assigned_child,
      'line_meta', jsonb_build_object(
        'resell_price_amount', 0,
        'is_warehouse_gift', true,
        'gift_line_total_amount', coalesce(v_gift.gift_cost_amount, 0),
        'order_item_id', v_gift.order_item_id
      )
    ));

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  if jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'no billable picked lines for merchant invoice');
  end if;

  return jsonb_build_object(
    'success', true,
    'payload', jsonb_build_object(
      'invoice', jsonb_strip_nulls(jsonb_build_object(
        'invoice_type', 'dropship',
        'invoice_no', v_invoice_no,
        'profile_id', v_profile_id,
        'recipient_profile_id', v_order.recipient_profile_id,
        'recipient_name', coalesce(v_order.recipient_name, v_order.name),
        'recipient_phone', v_order.recipient_phone,
        'recipient_address', v_order.shipping_address,
        'note', coalesce(p_note, 'Merchant bill from dropship order #' || v_order.order_no),
        'discount_amount', coalesce(v_order.discount_amount, 0),
        'shipping_charge', coalesce(v_charges.delivery, 0),
        'cod_charge_amount', coalesce(v_charges.cod, 0),
        'print_charge', coalesce(v_charges.print, 0),
        'wrapping_charge', coalesce(v_charges.packing, 0),
        'collection_source', 'profile'::public.collection_source_type,
        'channel_meta', v_channel_meta
      )),
      'items', v_items,
      'shop_order_id', p_order_id
    )
  );
end;
$$;

ALTER FUNCTION "public"."build_dropship_tenant_b2b_invoice_payload"("p_order_id" bigint, "p_invoice_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_note" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."canonicalize_dropship_order_wallet_source_ids"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice_no text;
  v_parent_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null or v_order.shop_type_snapshot <> 'dropship' then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  v_invoice_no := 'INV-DS-' || v_order.order_no;

  update public.cashbook_entries u
  set
    source_id = p_order_id::text,
    metadata = coalesce(u.metadata, '{}'::jsonb)
      || jsonb_build_object('order_id', p_order_id, 'invoice_no', v_invoice_no)
  where u.source_type = 'shop_order'
    and u.parent_tenant_id = v_parent_tenant_id
    and u.source_id in (v_invoice_no, v_order.order_no);

  if v_order.global_invoice_id is not null then
    update public.cashbook_entries u
    set
      source_id = p_order_id::text,
      metadata = coalesce(u.metadata, '{}'::jsonb)
        || jsonb_build_object('order_id', p_order_id, 'invoice_id', v_order.global_invoice_id)
    from public.bills i
    where i.id = v_order.global_invoice_id
      and u.source_type = 'shop_order'
      and u.parent_tenant_id = v_parent_tenant_id
      and u.source_id = i.invoice_no;
  end if;
end;
$$;

ALTER FUNCTION "public"."canonicalize_dropship_order_wallet_source_ids"("p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."convert_wholesale_draft_to_retail"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
begin
  -- Fetch the invoice
  select * into v_invoice from public.bills where id = p_invoice_id;
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
  update public.bills
  set
    invoice_type = 'retail'::public.global_invoice_type,
    retail_billing_mode = 'account'::public.retail_billing_mode,
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

ALTER FUNCTION "public"."convert_wholesale_draft_to_retail"("p_invoice_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_dropship_invoice"("p_order_id" bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

ALTER FUNCTION "public"."create_dropship_invoice"("p_order_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_note" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_dual_invoice_from_dropship_order"("p_order_id" bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_profile_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

ALTER FUNCTION "public"."create_dual_invoice_from_dropship_order"("p_order_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_note" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type", "p_source_module" "public"."global_source_module" DEFAULT 'wholesale'::"public"."global_source_module", "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_recipient_party_id" bigint DEFAULT NULL::bigint, "p_middle_man_payout_amount" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."bills"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select * from public.create_sales_invoice(
    p_tenant_id,
    p_invoice_no,
    p_profile_id,
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

ALTER FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_retail_billing_mode" "public"."retail_billing_mode" DEFAULT NULL::"public"."retail_billing_mode", "p_due_date" "date" DEFAULT NULL::"date", "p_note" "text" DEFAULT NULL::"text", "p_invoice_date" "date" DEFAULT NULL::"date") RETURNS "public"."bills"
    LANGUAGE "sql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select * from public.create_sales_invoice(
    p_tenant_id,
    p_invoice_no,
    p_invoice_type,
    p_profile_id,
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

ALTER FUNCTION "public"."create_global_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type", "p_source_module" "public"."global_source_module" DEFAULT 'wholesale'::"public"."global_source_module", "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_recipient_party_id" bigint DEFAULT NULL::bigint, "p_middle_man_payout_amount" numeric DEFAULT NULL::numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.bills;
  v_parent_id bigint;
  v_issued_by bigint;
  v_profile public.profiles;
  v_invoice_type public.global_invoice_type;
  v_recipient_name text;
  v_recipient_phone text;
  v_recipient_address text;
  v_collection_source text;
begin
  if p_profile_id is null then
    raise exception 'Customer profile is required.';
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

  select * into v_profile from public.profiles where id = p_profile_id;
  if v_profile.id is null then raise exception 'Customer profile not found.'; end if;
  if not public.profile_valid_for_issuer(p_profile_id, v_issued_by) then
    raise exception 'Customer profile does not belong to issuing tenant.';
  end if;

  if v_invoice_type = 'wholesale' then
    v_recipient_name := coalesce(nullif(trim(p_recipient_name), ''), v_profile.name);
    v_recipient_phone := coalesce(nullif(trim(p_recipient_phone), ''), v_profile.phone);
    v_recipient_address := coalesce(nullif(trim(p_recipient_address), ''), v_profile.address);
    v_collection_source := 'profile';
  elsif v_invoice_type = 'retail' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for retail.'; end if;
    v_collection_source := 'profile';
  elsif v_invoice_type = 'dropship' then
    v_recipient_name := nullif(trim(coalesce(p_recipient_name, '')), '');
    v_recipient_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
    v_recipient_address := nullif(trim(coalesce(p_recipient_address, '')), '');
    if v_recipient_name is null then raise exception 'Recipient name is required for dropship.'; end if;
    v_collection_source := 'profile';
  else
    raise exception 'Invalid invoice type.';
  end if;

  insert into public.bills (
    parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type,
    profile_id,
    recipient_name, recipient_phone, recipient_address,
    collection_source, note, due_amount
  )
  values (
    v_parent_id, v_issued_by, trim(p_invoice_no), v_invoice_type,
    p_profile_id,
    v_recipient_name, v_recipient_phone, v_recipient_address,
    v_collection_source, nullif(trim(coalesce(p_note, '')), ''), 0
  )
  returning * into v_row;

  perform public.stamp_bill_kernel_fields(v_row.id);
  select * into v_row from public.bills where id = v_row.id;

  return v_row;
end;
$$;

ALTER FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_profile_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_source_module" "public"."global_source_module", "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_recipient_party_id" bigint, "p_middle_man_payout_amount" numeric, "p_note" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text" DEFAULT NULL::"text", "p_invoice_type" "public"."global_invoice_type" DEFAULT 'wholesale'::"public"."global_invoice_type", "p_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_profile_id" bigint DEFAULT NULL::bigint, "p_recipient_name" "text" DEFAULT NULL::"text", "p_recipient_phone" "text" DEFAULT NULL::"text", "p_recipient_address" "text" DEFAULT NULL::"text", "p_retail_billing_mode" "public"."retail_billing_mode" DEFAULT NULL::"public"."retail_billing_mode", "p_due_date" "date" DEFAULT NULL::"date", "p_note" "text" DEFAULT NULL::"text", "p_invoice_date" "date" DEFAULT NULL::"date") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.bills;
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
      where (m.tenant_id = p_tenant_id or m.tenant_id = v_parent_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
    or public.is_superadmin()
  ) then
    raise exception 'not allowed';
  end if;

  if p_profile_id is not null then
    if not public.profile_valid_for_issuer(p_profile_id, v_issued_by) then
      raise exception 'billing profile not accessible for this tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not public.recipient_profile_valid_for_issuer(p_recipient_profile_id, v_issued_by) then
      raise exception 'recipient profile not accessible for this tenant';
    end if;
  end if;

  if p_invoice_type = 'wholesale'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for wholesale invoices';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;

  elsif p_invoice_type = 'retail'::public.global_invoice_type then
    if p_retail_billing_mode is null then
      raise exception 'retail billing mode (account or direct) is required for retail invoices';
    end if;

    if p_retail_billing_mode = 'account'::public.retail_billing_mode then
      if p_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
      v_collection_source := 'profile'::public.collection_source_type;
    else
      if p_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
      v_collection_source := 'recipient'::public.collection_source_type;
    end if;

  elsif p_invoice_type = 'dropship'::public.global_invoice_type then
    if p_profile_id is null then
      raise exception 'billing profile (middle man) is required for dropship invoices';
    end if;
    if p_retail_billing_mode is not null then
      raise exception 'retail billing mode must be null for dropship invoices';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;
  elsif p_invoice_type = 'ap'::public.global_invoice_type then
    raise exception 'AP bills are created by sync_shipment_ap_bills only';
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

  if p_invoice_type = 'wholesale'::public.global_invoice_type and p_profile_id is not null then
    select name, phone, address
    into v_bill_name, v_bill_phone, v_bill_address
    from public.profiles
    where id = p_profile_id;

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

  insert into public.bills (
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    retail_billing_mode,
    invoice_status,
    profile_id,
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
    v_issued_by,
    v_invoice_no,
    p_invoice_type,
    v_invoice_date,
    p_retail_billing_mode,
    'draft'::public.global_invoice_status,
    p_profile_id,
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

  perform public.stamp_bill_kernel_fields(v_row.id);
  select * into v_row from public.bills where id = v_row.id;

  return v_row;
end;
$$;

ALTER FUNCTION "public"."create_sales_invoice"("p_tenant_id" bigint, "p_invoice_no" "text", "p_invoice_type" "public"."global_invoice_type", "p_profile_id" bigint, "p_recipient_profile_id" bigint, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_retail_billing_mode" "public"."retail_billing_mode", "p_due_date" "date", "p_note" "text", "p_invoice_date" "date") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_sales_invoice_from_payload"("p_tenant_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_inv jsonb;
  v_item_elem jsonb;
  v_invoice public.bills;
  v_invoice_id bigint;
  v_parent_id bigint;
  v_invoice_type public.global_invoice_type;
  v_retail_mode public.retail_billing_mode;
  v_issue boolean;
  v_shop_order_id bigint;
  v_items jsonb;
  v_item_ids bigint[] := '{}';
  v_created_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_stock_parent bigint;
  v_has_charges boolean;
  v_cod_charge numeric(12,2);
  v_line_meta jsonb;
  v_channel_meta jsonb;
  v_delivery_kind text;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object');
  end if;

  v_inv := coalesce(p_payload->'invoice', '{}'::jsonb);
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_issue := coalesce((p_payload->>'issue')::boolean, false);
  v_shop_order_id := nullif(p_payload->>'shop_order_id', '')::bigint;
  v_channel_meta := coalesce(v_inv->'channel_meta', '{}'::jsonb);
  v_delivery_kind := lower(trim(coalesce(v_channel_meta->>'delivery_kind', 'take')));
  if v_delivery_kind not in ('take', 'condition') then
    return jsonb_build_object('success', false, 'error', 'channel_meta.delivery_kind must be take or condition');
  end if;

  if v_inv->>'invoice_type' is null or trim(v_inv->>'invoice_type') = '' then
    return jsonb_build_object('success', false, 'error', 'invoice.invoice_type is required');
  end if;

  v_invoice_type := (v_inv->>'invoice_type')::public.global_invoice_type;

  if jsonb_typeof(v_items) <> 'array' then
    return jsonb_build_object('success', false, 'error', 'items must be a JSON array');
  end if;

  if v_issue and jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'at least one item is required when issue is true');
  end if;

  v_retail_mode := case
    when v_inv->>'retail_billing_mode' is null or trim(v_inv->>'retail_billing_mode') = '' then null
    else (v_inv->>'retail_billing_mode')::public.retail_billing_mode
  end;

  if v_delivery_kind = 'condition' then
    if v_invoice_type <> 'wholesale'::public.global_invoice_type then
      return jsonb_build_object('success', false, 'error', 'condition bills require wholesale invoice_type');
    end if;
    if v_retail_mode = 'direct'::public.retail_billing_mode then
      return jsonb_build_object('success', false, 'error', 'walk-in bills cannot be condition');
    end if;
  end if;

  v_channel_meta := coalesce(v_channel_meta, '{}'::jsonb) || jsonb_build_object('delivery_kind', v_delivery_kind);

  select * into v_invoice
  from public.create_sales_invoice(
    p_tenant_id => p_tenant_id,
    p_invoice_no => coalesce(nullif(trim(v_inv->>'invoice_no'), ''), ''),
    p_invoice_type => v_invoice_type,
    p_profile_id => nullif(v_inv->>'profile_id', '')::bigint,
    p_recipient_profile_id => nullif(v_inv->>'recipient_profile_id', '')::bigint,
    p_recipient_name => nullif(trim(v_inv->>'recipient_name'), ''),
    p_recipient_phone => nullif(trim(v_inv->>'recipient_phone'), ''),
    p_recipient_address => nullif(trim(v_inv->>'recipient_address'), ''),
    p_retail_billing_mode => v_retail_mode,
    p_due_date => nullif(v_inv->>'due_date', '')::date,
    p_note => nullif(trim(v_inv->>'note'), ''),
    p_invoice_date => nullif(v_inv->>'invoice_date', '')::date
  );

  v_invoice_id := v_invoice.id;
  v_parent_id := v_invoice.parent_tenant_id;

  update public.bills
  set
    shop_order_id = v_shop_order_id,
    channel_meta = v_channel_meta,
    settlement_kind = v_delivery_kind::public.bill_settlement_kind,
    updated_at = now()
  where id = v_invoice_id;

  perform public.stamp_bill_kernel_fields(v_invoice_id);

  for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
    v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
    v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
    v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
    v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);
    v_line_meta := coalesce(v_item_elem->'line_meta', '{}'::jsonb);

    if v_quantity is null or v_quantity <= 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires quantity > 0');
    end if;
    if v_sell_price is null or v_sell_price < 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires sell_price_amount >= 0');
    end if;

    if v_global_stock_id is null
       and coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
      v_product_id := nullif(v_item_elem->>'product_id', '')::bigint;
      v_shipment_item_id := nullif(v_item_elem->>'shipment_item_id', '')::bigint;
      v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), 'Gift item');
      v_barcode_snapshot := nullif(trim(v_item_elem->>'barcode_snapshot'), '');
      v_product_code_snapshot := nullif(trim(v_item_elem->>'product_code_snapshot'), '');
      v_assigned_child := nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint;
      v_line_total := coalesce(
        nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
        greatest((v_quantity * v_sell_price) - v_line_discount, 0)
      );

      insert into public.bill_lines (
        parent_tenant_id,
        invoice_id,
        global_stock_id,
        shipment_item_id,
        product_id,
        name_snapshot,
        barcode_snapshot,
        product_code_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        assigned_child_tenant_id,
        line_meta
      )
      values (
        v_parent_id,
        v_invoice_id,
        null,
        v_shipment_item_id,
        v_product_id,
        v_name_snapshot,
        v_barcode_snapshot,
        v_product_code_snapshot,
        v_quantity,
        v_sell_price,
        v_line_discount,
        v_line_total,
        v_assigned_child,
        v_line_meta
      );

      continue;
    end if;

    if v_global_stock_id is null then
      return jsonb_build_object('success', false, 'error', 'each item requires global_stock_id');
    end if;

    select
      gs.parent_tenant_id,
      gs.shipment_item_id,
      gsi.name,
      gsi.barcode,
      gsi.product_code,
      sh.assigned_child_tenant_id,
      p.id
    into
      v_stock_parent,
      v_shipment_item_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_assigned_child,
      v_product_id
    from public.global_stocks gs
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    left join public.products p on p.id = gsi.product_id
    where gs.id = v_global_stock_id;

    if v_stock_parent is null then
      return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id));
    end if;

    if v_stock_parent <> v_parent_id then
      return jsonb_build_object('success', false, 'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id));
    end if;

    v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
    v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
    v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
    v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
    v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
    v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);

    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest((v_quantity * v_sell_price) - v_line_discount, 0)
    );

    insert into public.bill_lines (
      parent_tenant_id,
      invoice_id,
      global_stock_id,
      shipment_item_id,
      product_id,
      name_snapshot,
      barcode_snapshot,
      product_code_snapshot,
      quantity,
      sell_price_amount,
      line_discount_amount,
      line_total_amount,
      assigned_child_tenant_id,
      line_meta
    )
    values (
      v_parent_id,
      v_invoice_id,
      v_global_stock_id,
      v_shipment_item_id,
      v_product_id,
      v_name_snapshot,
      v_barcode_snapshot,
      v_product_code_snapshot,
      v_quantity,
      v_sell_price,
      v_line_discount,
      v_line_total,
      v_assigned_child,
      v_line_meta
    )
    returning id into v_created_item_id;

    v_item_ids := array_append(v_item_ids, v_created_item_id);
  end loop;

  v_cod_charge := case
    when v_invoice_type = 'wholesale'::public.global_invoice_type then null
    when v_inv ? 'cod_charge_amount' then nullif(v_inv->>'cod_charge_amount', '')::numeric
    when v_inv ? 'cod_charge' then nullif(v_inv->>'cod_charge', '')::numeric
    else null
  end;

  v_has_charges := (
    v_inv ? 'discount_amount'
    or v_inv ? 'shipping_charge'
    or v_inv ? 'print_charge'
    or v_inv ? 'wrapping_charge'
    or (
      v_invoice_type <> 'wholesale'::public.global_invoice_type
      and (v_inv ? 'cod_charge_amount' or v_inv ? 'cod_charge')
    )
  );

  if v_has_charges then
    perform public.update_global_invoice_header(
      p_invoice_id => v_invoice_id,
      p_discount_amount => case when v_inv ? 'discount_amount' then nullif(v_inv->>'discount_amount', '')::numeric else null end,
      p_shipping_charge => case when v_inv ? 'shipping_charge' then nullif(v_inv->>'shipping_charge', '')::numeric else null end,
      p_cod_charge => v_cod_charge,
      p_wrapping_charge => case when v_inv ? 'wrapping_charge' then nullif(v_inv->>'wrapping_charge', '')::numeric else null end,
      p_print_charge => case when v_inv ? 'print_charge' then nullif(v_inv->>'print_charge', '')::numeric else null end,
      p_recipient_name => null,
      p_recipient_phone => null,
      p_recipient_address => null,
      p_note => null,
      p_invoice_no => null,
      p_invoice_date => null
    );
  else
    perform public.recompute_global_invoice_totals(v_invoice_id);
  end if;

  if v_issue then
    perform public.post_sales_invoice(v_invoice_id);
    perform public.sync_sales_invoice_charges_from_header(v_invoice_id);
  end if;

  if v_shop_order_id is not null then
    if not exists (
      select 1 from public.shop_orders o
      where o.id = v_shop_order_id
        and o.tenant_id = p_tenant_id
        and o.shop_type_snapshot = 'dropship'
    ) then
      return jsonb_build_object('success', false, 'error', 'shop_order_id must be a dropship order for this tenant');
    end if;

    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = v_shop_order_id
      and tenant_id = p_tenant_id
      and global_invoice_id is null;
  end if;

  select * into v_invoice from public.bills where id = v_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'subtotal_amount', v_invoice.subtotal_amount,
    'discount_amount', v_invoice.discount_amount,
    'shipping_charge', v_invoice.shipping_charge,
    'cod_charge_amount', coalesce((v_invoice.channel_meta->>'cod_charge_amount')::numeric, 0),
    'print_charge', v_invoice.print_charge,
    'wrapping_charge', v_invoice.wrapping_charge,
    'total_amount', v_invoice.total_amount,
    'paid_amount', v_invoice.paid_amount,
    'due_amount', v_invoice.due_amount,
    'profile_id', v_invoice.profile_id,
    'collection_source', v_invoice.collection_source,
    'item_ids', to_jsonb(v_item_ids),
    'issued', v_issue,
    'shop_order_id', v_shop_order_id
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

ALTER FUNCTION "public"."create_sales_invoice_from_payload"("p_tenant_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text" DEFAULT 'bank_transfer'::"text", "p_reference_notes" "text" DEFAULT NULL::"text", "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile public.profiles;
  v_payout_id text;
  v_parent_tenant_id bigint;
  v_pot_id bigint := p_cashbook_point_pot_id;
begin
  if p_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'Tenant ID is required');
  end if;

  if p_profile_id is null then
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
  from public.profiles
  where id = p_profile_id
    and profile_type = 'customer'::public.profile_party_type;

  if v_profile.id is null or not public.profile_valid_for_issuer(p_profile_id, p_tenant_id) then
    return jsonb_build_object('success', false, 'error', format('Customer profile #%s not found for tenant %s', p_profile_id, p_tenant_id));
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_payout_id := 'PO-' || gen_random_uuid()::text;

  if p_cashbook_point_id is null then
    return jsonb_build_object('success', false, 'error', 'Choose a cash point for this pay out');
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_parent_tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_parent_tenant_id
  ) then
    return jsonb_build_object('success', false, 'error', 'Invalid cash point for this tenant');
  end if;

  if v_pot_id is null then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_tenant_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null then
    return jsonb_build_object('success', false, 'error', 'No currency pot at this cash point');
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_tenant_id,
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
      'profile_id', p_profile_id,
      'profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes,
      'cashbook_point_pot_id', v_pot_id
    ),
    p_cashbook_point_id => p_cashbook_point_id
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
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
    p_profile_id,
    p_amount
  );

  return jsonb_build_object(
    'success', true,
    'payout_id', v_payout_id,
    'profile_id', p_profile_id,
    'amount', p_amount
  );
end;
$$;

ALTER FUNCTION "public"."dispense_middleman_payout_from_tenant"("p_tenant_id" bigint, "p_profile_id" bigint, "p_amount" numeric, "p_payout_method" "text", "p_reference_notes" "text", "p_cashbook_point_id" bigint, "p_cashbook_point_pot_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."enforce_customer_profile_admin_email_unique_per_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.email := nullif(lower(trim(coalesce(new.email, ''))), '');
  return new;
end;
$$;

ALTER FUNCTION "public"."enforce_customer_profile_admin_email_unique_per_tenant"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_customer_profiles_normalize_phone"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.phone := public.normalize_customer_national_phone(new.phone);
  return new;
end;
$$;

ALTER FUNCTION "public"."trg_customer_profiles_normalize_phone"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_customer_profiles_sync_operating_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'public'
    AS $$
begin
  new.parent_tenant_id := coalesce(
    new.parent_tenant_id,
    public.resolve_parent_tenant_id(new.operating_tenant_id)
  );
  new.operating_tenant_id := coalesce(new.operating_tenant_id, new.parent_tenant_id);
  return new;
end;
$$;

ALTER FUNCTION "public"."trg_customer_profiles_sync_operating_tenant"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  -- Intentionally no-op. Dropship B2B invoice does not debit the billing profile wallet.
  -- Courier COD is credited in confirm_dropship_delivered_costing at mark-delivered.
  return;
end;
$$;

ALTER FUNCTION "public"."ensure_dropship_invoice_billed_entry"("p_invoice_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."ensure_dropship_tenant_b2b_invoice_at_delivered"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

ALTER FUNCTION "public"."ensure_dropship_tenant_b2b_invoice_at_delivered"("p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."generate_sales_invoice_number"("p_tenant_id" bigint, "p_invoice_type" "public"."global_invoice_type", "p_date" "date" DEFAULT CURRENT_DATE) RETURNS "text"
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
    WHEN 'ap'::public.global_invoice_type THEN 'AP'
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

CREATE OR REPLACE FUNCTION "public"."stamp_bill_kernel_fields"("p_bill_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO "public"
    AS $$
declare
  v_bill public.bills;
  v_tenant_profile_id bigint;
  v_from bigint;
  v_to bigint;
  v_source_type text;
  v_source_id text;
  v_source_key text;
  v_settle public.bill_settlement_kind;
  v_kind text;
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    return;
  end if;

  select p.id into v_tenant_profile_id
  from public.profiles p
  where p.parent_tenant_id = v_bill.parent_tenant_id
    and p.profile_type = 'tenant'::public.profile_party_type
    and p.subject_id = v_bill.issued_by_tenant_id
  limit 1;

  if v_tenant_profile_id is null then
    select p.id into v_tenant_profile_id
    from public.profiles p
    where p.parent_tenant_id = v_bill.parent_tenant_id
      and p.profile_type = 'tenant'::public.profile_party_type
      and p.subject_id = v_bill.parent_tenant_id
    limit 1;
  end if;

  if v_bill.invoice_type = 'ap'::public.global_invoice_type then
    v_from := v_bill.profile_id;
    v_to := v_tenant_profile_id;
    v_source_type := coalesce(v_bill.source_type, 'shipment_cost');
    v_source_id := coalesce(v_bill.source_id, v_bill.ap_shipment_id::text);
    v_source_key := coalesce(v_bill.source_key, v_bill.ap_kind);
    v_settle := null;
  else
    v_from := v_tenant_profile_id;
    v_to := v_bill.profile_id;
    if v_bill.shop_order_id is not null then
      v_source_type := coalesce(v_bill.source_type, 'shop_order');
      v_source_id := coalesce(v_bill.source_id, v_bill.shop_order_id::text);
      v_source_key := v_bill.source_key;
    else
      v_source_type := coalesce(v_bill.source_type, 'compose');
      v_source_id := coalesce(v_bill.source_id, v_bill.id::text);
      v_source_key := v_bill.source_key;
    end if;
    v_kind := lower(trim(coalesce(v_bill.channel_meta->>'delivery_kind', '')));
    if v_bill.settlement_kind is not null then
      v_settle := v_bill.settlement_kind;
    elsif v_kind in ('take', 'condition') then
      v_settle := v_kind::public.bill_settlement_kind;
    else
      v_settle := 'take'::public.bill_settlement_kind;
    end if;
  end if;

  if v_from is not null and v_to is not null and v_from = v_to then
    v_to := v_bill.profile_id;
    if v_from = v_to then
      v_from := v_tenant_profile_id;
    end if;
  end if;

  if v_from is not null and v_from = v_to then
    if v_bill.invoice_type = 'ap'::public.global_invoice_type then
      v_to := null;
    else
      v_from := null;
    end if;
  end if;

  update public.bills
  set
    from_profile_id = v_from,
    to_profile_id = v_to,
    source_type = v_source_type,
    source_id = v_source_id,
    source_key = v_source_key,
    settlement_kind = v_settle,
    currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT')
  where id = p_bill_id;
end;
$$;

ALTER FUNCTION "public"."stamp_bill_kernel_fields"("p_bill_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."create_bill_adjustment"(
  "p_parent_bill_id" bigint,
  "p_kind" "text",
  "p_amount" numeric,
  "p_reason" "text",
  "p_issue" boolean DEFAULT true,
  "p_refund_amount" numeric DEFAULT NULL::numeric,
  "p_cashbook_point_id" bigint DEFAULT NULL::bigint,
  "p_lines" "jsonb" DEFAULT '[]'::"jsonb"
) RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent public.bills;
  v_kind public.bill_document_kind;
  v_row public.bills;
  v_no text;
  v_reason text;
  v_amount numeric(12,2);
  v_status public.global_invoice_status;
  v_refund numeric(12,2);
  v_child_due numeric(12,2);
  v_pay public.pays;
  v_line_elem jsonb;
  v_line_total numeric(12,2);
  v_books numeric(12,2);
  v_line_kind text;
  v_stock_id bigint;
  v_lines_sum numeric(12,2) := 0.00;
begin
  if p_parent_bill_id is null then
    raise exception 'parent_bill_id is required';
  end if;

  v_kind := case lower(trim(coalesce(p_kind, '')))
    when 'credit_note' then 'credit_note'::public.bill_document_kind
    when 'credit' then 'credit_note'::public.bill_document_kind
    when 'debit_note' then 'debit_note'::public.bill_document_kind
    when 'debit' then 'debit_note'::public.bill_document_kind
    else null
  end;
  if v_kind is null then
    raise exception 'kind must be credit_note or debit_note';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'reason is required';
  end if;

  select * into v_parent from public.bills where id = p_parent_bill_id for update;
  if v_parent.id is null then
    raise exception 'bill not found';
  end if;
  if v_parent.document_kind <> 'standard'::public.bill_document_kind then
    raise exception 'adjustments must attach to a standard bill';
  end if;
  if v_parent.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'parent bill must be issued';
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent.parent_tenant_id)
    or public.membership_has_module_action(v_parent.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' and jsonb_array_length(p_lines) > 0 then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_lines_sum := v_lines_sum + v_books;
    end loop;
    v_amount := round(v_lines_sum, 2);
  else
    v_amount := round(coalesce(p_amount, 0), 2);
  end if;

  if v_amount <= 0 then
    raise exception 'amount must be greater than zero';
  end if;

  v_no := public.generate_sales_invoice_number(
    v_parent.issued_by_tenant_id,
    v_parent.invoice_type,
    current_date
  );
  if v_kind = 'credit_note'::public.bill_document_kind then
    v_no := regexp_replace(v_no, '^INV-', 'INV-CN-');
  else
    v_no := regexp_replace(v_no, '^INV-', 'INV-DN-');
  end if;

  v_status := case when coalesce(p_issue, true)
    then 'issued'::public.global_invoice_status
    else 'draft'::public.global_invoice_status
  end;

  insert into public.bills (
    parent_tenant_id,
    issued_by_tenant_id,
    invoice_no,
    invoice_type,
    invoice_date,
    invoice_status,
    profile_id,
    collection_source,
    payment_status,
    subtotal_amount,
    total_amount,
    due_amount,
    paid_amount,
    note,
    document_kind,
    parent_bill_id,
    ap_shipment_id,
    ap_kind,
    channel_meta
  ) values (
    v_parent.parent_tenant_id,
    v_parent.issued_by_tenant_id,
    v_no,
    v_parent.invoice_type,
    current_date,
    v_status,
    v_parent.profile_id,
    v_parent.collection_source,
    'due',
    v_amount,
    v_amount,
    v_amount,
    0,
    v_reason,
    v_kind,
    v_parent.id,
    v_parent.ap_shipment_id,
    v_parent.ap_kind,
    jsonb_build_object(
      'adjustment', jsonb_build_object(
        'kind', v_kind::text,
        'reason', v_reason,
        'parent_invoice_no', v_parent.invoice_no
      )
    )
  )
  returning * into v_row;

  if coalesce(jsonb_typeof(p_lines), 'null') = 'array' then
    for v_line_elem in select value from jsonb_array_elements(p_lines)
    loop
      v_line_total := round(coalesce((v_line_elem ->> 'line_total_amount')::numeric, 0.00), 2);
      if v_line_total <= 0 then
        continue;
      end if;
      v_books := round(coalesce((v_line_elem ->> 'books_amount')::numeric, v_line_total), 2);
      v_line_kind := lower(trim(coalesce(v_line_elem ->> 'line_kind', 'description')));
      if v_line_kind not in ('stock', 'description', 'charge') then
        v_line_kind := 'description';
      end if;
      v_stock_id := nullif(trim(coalesce(v_line_elem ->> 'global_stock_id', '')), '')::bigint;

      insert into public.bill_lines (
        parent_tenant_id,
        invoice_id,
        line_kind,
        name_snapshot,
        quantity,
        sell_price_amount,
        line_discount_amount,
        line_total_amount,
        currency_code,
        books_amount,
        line_meta,
        global_stock_id
      ) values (
        v_parent.parent_tenant_id,
        v_row.id,
        v_line_kind,
        coalesce(nullif(trim(coalesce(v_line_elem ->> 'name_snapshot', '')), ''), 'Adjustment line'),
        greatest(coalesce((v_line_elem ->> 'quantity')::numeric, 1.000), 0.001),
        v_line_total,
        0.00,
        v_line_total,
        upper(trim(coalesce(v_line_elem ->> 'currency_code', 'BDT'))),
        v_books,
        coalesce(v_line_elem -> 'line_meta', '{}'::jsonb)
          || case
            when nullif(trim(coalesce(v_line_elem ->> 'parent_line_id', '')), '') is not null
            then jsonb_build_object('parent_line_id', v_line_elem ->> 'parent_line_id')
            else '{}'::jsonb
          end,
        v_stock_id
      );
    end loop;
  end if;

  perform public.stamp_bill_kernel_fields(v_row.id);

  if v_status = 'issued'::public.global_invoice_status then
    perform public.recompute_global_invoice_payment_status(v_parent.id);
    select * into v_row from public.bills where id = v_row.id;
  end if;

  v_refund := round(coalesce(p_refund_amount, 0), 2);
  if v_refund > 0 then
    if v_kind <> 'credit_note'::public.bill_document_kind then
      raise exception 'Cash refund applies only to credit notes';
    end if;
    if v_parent.profile_id is null then
      raise exception 'Bill has no profile for refund';
    end if;
    if p_cashbook_point_id is null then
      raise exception 'Choose a cash point for the refund';
    end if;
    if not exists (
      select 1
      from public.cashbook_points cp
      join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
      where cp.id = p_cashbook_point_id
        and cp.is_active = true
        and ca.parent_tenant_id = v_parent.parent_tenant_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent.parent_tenant_id
    ) then
      raise exception 'Invalid cash point for this tenant';
    end if;

    v_child_due := coalesce(v_row.due_amount, 0.00);
    if v_refund > v_child_due then
      raise exception 'Refund % exceeds open credit % on the note', v_refund, v_child_due;
    end if;

    insert into public.pays (
      tenant_id,
      profile_id,
      source,
      amount,
      unallocated_amount,
      payment_date,
      method,
      note,
      cashbook_point_id
    ) values (
      v_parent.parent_tenant_id,
      v_parent.profile_id,
      'ap_payout',
      v_refund,
      0,
      current_date,
      'cash',
      v_reason,
      p_cashbook_point_id
    )
    returning * into v_pay;

    insert into public.pay_instruments (
      payment_id,
      payment_method_code,
      amount,
      sort_order,
      cashbook_point_id
    ) values (
      v_pay.id,
      'CASH',
      v_refund,
      1,
      p_cashbook_point_id
    );

    insert into public.pay_allocations (
      tenant_id,
      payment_id,
      global_invoice_id,
      bill_id,
      amount
    ) values (
      v_parent.parent_tenant_id,
      v_pay.id,
      v_row.id,
      v_row.id,
      v_refund
    );

    perform public.recompute_global_invoice_payment_status(v_row.id);
    perform public.recompute_global_invoice_payment_status(v_parent.id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent.parent_tenant_id,
      p_operating_tenant_id => v_parent.issued_by_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent.parent_tenant_id,
      p_type => 'debit',
      p_amount => v_refund,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'credit_note_refund',
        'transaction_type', 'credit_note_cash_refund',
        'label', 'Credit note cash refund',
        'payment_id', v_pay.id,
        'credit_note_id', v_row.id,
        'credit_note_no', v_row.invoice_no,
        'parent_bill_id', v_parent.id,
        'parent_invoice_no', v_parent.invoice_no
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => p_cashbook_point_id
    );

    select * into v_row from public.bills where id = v_row.id;
  elsif p_cashbook_point_id is not null and coalesce(p_refund_amount, 0) <= 0 then
    raise exception 'Refund amount is required when a cash point is selected';
  end if;

  return v_row;
end;
$$;

ALTER FUNCTION "public"."create_bill_adjustment"("p_parent_bill_id" bigint, "p_kind" "text", "p_amount" numeric, "p_reason" "text", "p_issue" boolean, "p_refund_amount" numeric, "p_cashbook_point_id" bigint, "p_lines" "jsonb") OWNER TO "postgres";

DROP FUNCTION IF EXISTS "public"."post_vendor_credit_refund"("p_credit_note_id" bigint, "p_amount" numeric, "p_cashbook_point_id" bigint, "p_received_on" "date", "p_note" "text", "p_settlement_currency_code" "text", "p_foreign_amount" numeric, "p_exchange_rate" numeric);

CREATE OR REPLACE FUNCTION "public"."post_vendor_credit_refund"(
  "p_credit_note_id" bigint,
  "p_amount" numeric,
  "p_cashbook_point_id" bigint,
  "p_received_on" "date" DEFAULT CURRENT_DATE,
  "p_note" "text" DEFAULT NULL::"text",
  "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text",
  "p_foreign_amount" numeric DEFAULT NULL::numeric,
  "p_exchange_rate" numeric DEFAULT NULL::numeric,
  "p_source_currency_code" "text" DEFAULT NULL::"text",
  "p_transaction_rate" numeric DEFAULT NULL::numeric,
  "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint
) RETURNS "public"."pays"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_cn public.bills;
  v_refund numeric(12,2);
  v_pay public.pays;
  v_reason text;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_base_currency text := 'BDT';
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_source_amount numeric(12, 2);
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_payment_face numeric(12, 2);
begin
  if p_credit_note_id is null then
    raise exception 'credit_note_id is required';
  end if;
  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for the refund';
  end if;

  v_refund := round(coalesce(p_amount, 0), 2);
  if v_refund <= 0 and coalesce(p_foreign_amount, 0) <= 0 then
    raise exception 'Refund amount must be greater than zero';
  end if;

  select * into v_cn from public.bills where id = p_credit_note_id for update;
  if v_cn.id is null then
    raise exception 'bill not found';
  end if;
  if v_cn.document_kind <> 'credit_note'::public.bill_document_kind then
    raise exception 'Refund applies only to a credit note';
  end if;
  if v_cn.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Credit note must be issued';
  end if;
  if v_cn.invoice_type <> 'ap'::public.global_invoice_type then
    raise exception 'Vendor refund applies only to AP credit notes';
  end if;
  if v_cn.profile_id is null then
    raise exception 'Credit note has no profile';
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_cn.parent_tenant_id)
    or public.membership_has_module_action(v_cn.issued_by_tenant_id, 'payments', 'collect_payment')
    or public.membership_has_module_action(v_cn.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_cn.parent_tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_cn.parent_tenant_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  v_reason := coalesce(nullif(trim(coalesce(p_note, '')), ''), 'Vendor credit refund');

  v_base_currency := public.resolve_tenant_base_currency_code(v_cn.parent_tenant_id);

  select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
  into v_settle_currency, v_foreign_amt, v_fx_rate, v_refund
  from public.normalize_pay_settlement_fx(
    v_refund,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    v_base_currency
  ) n;

  if v_refund <= 0 then
    raise exception 'Refund amount must be greater than zero';
  end if;

  if v_refund > coalesce(v_cn.due_amount, 0.00) then
    raise exception 'Refund % exceeds open credit % on the note', v_refund, coalesce(v_cn.due_amount, 0);
  end if;

  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  if v_source_currency = '' then
    select upper(cpp.currency_code)
    into v_source_currency
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_cn.parent_tenant_id
    order by case when upper(cpp.currency_code) = v_base_currency then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_cn.parent_tenant_id
      and upper(cpp.currency_code) = v_source_currency
    limit 1;
  end if;

  if v_pot_id is not null and not exists (
    select 1
    from public.cashbook_point_pots cpp
    where cpp.id = v_pot_id
      and cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_cn.parent_tenant_id
  ) then
    raise exception 'Invalid cash pot for this point';
  end if;

  if upper(v_settle_currency) = v_source_currency then
    v_transaction_rate := 1.000000;
  else
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    if v_transaction_rate <= 0 then
      raise exception 'transaction_rate required when pot currency (%) differs from refund currency (%)',
        v_source_currency, v_settle_currency;
    end if;
  end if;

  if upper(v_settle_currency) = v_base_currency then
    v_payment_face := v_refund;
  else
    v_payment_face := coalesce(v_foreign_amt, 0);
  end if;

  v_source_amount := round(v_payment_face * v_transaction_rate, 2);

  insert into public.pays (
    tenant_id,
    profile_id,
    source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    note,
    cashbook_point_id,
    settlement_currency_code,
    foreign_amount,
    exchange_rate,
    quote_currency_code,
    source_currency_code,
    transaction_rate,
    source_amount,
    cashbook_point_pot_id
  ) values (
    v_cn.parent_tenant_id,
    v_cn.profile_id,
    'customer_cash',
    v_refund,
    0,
    coalesce(p_received_on, current_date),
    'cash',
    v_reason,
    p_cashbook_point_id,
    v_settle_currency,
    v_foreign_amt,
    v_fx_rate,
    v_base_currency,
    v_source_currency,
    v_transaction_rate,
    v_source_amount,
    v_pot_id
  )
  returning * into v_pay;

  insert into public.pay_instruments (
    payment_id,
    payment_method_code,
    amount,
    sort_order,
    cashbook_point_id
  ) values (
    v_pay.id,
    'CASH',
    v_refund,
    1,
    p_cashbook_point_id
  );

  insert into public.pay_allocations (
    tenant_id,
    payment_id,
    global_invoice_id,
    bill_id,
    amount
  ) values (
    v_cn.parent_tenant_id,
    v_pay.id,
    v_cn.id,
    v_cn.id,
    v_refund
  );

  perform public.recompute_global_invoice_payment_status(v_cn.id);
  if v_cn.parent_bill_id is not null then
    perform public.recompute_global_invoice_payment_status(v_cn.parent_bill_id);
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_cn.parent_tenant_id,
    p_operating_tenant_id => v_cn.issued_by_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_cn.parent_tenant_id,
    p_type => 'credit',
    p_amount => v_refund,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'receipt',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'credit_note_refund',
      'transaction_type', 'vendor_credit_cash_refund',
      'label', 'Vendor credit refund received',
      'payment_id', v_pay.id,
      'credit_note_id', v_cn.id,
      'credit_note_no', v_cn.invoice_no,
      'parent_bill_id', v_cn.parent_bill_id,
      'settlement_currency_code', v_settle_currency,
      'foreign_amount', v_foreign_amt,
      'exchange_rate', v_fx_rate,
      'source_currency_code', v_source_currency,
      'transaction_rate', v_transaction_rate,
      'source_amount', v_source_amount,
      'cashbook_point_pot_id', v_pot_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_cashbook_point_id
  );

  return v_pay;
end;
$$;

ALTER FUNCTION "public"."post_vendor_credit_refund"("p_credit_note_id" bigint, "p_amount" numeric, "p_cashbook_point_id" bigint, "p_received_on" "date", "p_note" "text", "p_settlement_currency_code" "text", "p_foreign_amount" numeric, "p_exchange_rate" numeric, "p_source_currency_code" "text", "p_transaction_rate" numeric, "p_cashbook_point_pot_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_bill_adjustment"("p_adjustment_id" bigint) RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.bills;
begin
  select * into v_row from public.bills where id = p_adjustment_id for update;
  if v_row.id is null then
    raise exception 'adjustment not found';
  end if;
  if v_row.document_kind = 'standard'::public.bill_document_kind then
    raise exception 'not an adjustment bill';
  end if;
  if v_row.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'only draft adjustments can be issued';
  end if;
  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_row.parent_tenant_id)
    or public.membership_has_module_action(v_row.issued_by_tenant_id, 'global_invoice', 'edit')
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where id = p_adjustment_id
  returning * into v_row;

  perform public.recompute_global_invoice_payment_status(v_row.parent_bill_id);
  select * into v_row from public.bills where id = p_adjustment_id;
  return v_row;
end;
$$;

ALTER FUNCTION "public"."issue_bill_adjustment"("p_adjustment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_bill_adjustments"("p_parent_bill_id" bigint)
RETURNS SETOF "public"."bills"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select b.*
  from public.bills b
  where b.parent_bill_id = p_parent_bill_id
  order by b.id;
$$;

ALTER FUNCTION "public"."list_bill_adjustments"("p_parent_bill_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_bill_net_balances"("p_bill_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_root public.bills;
  v_credits numeric(12,2);
  v_debits numeric(12,2);
  v_credit_due numeric(12,2);
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  select * into v_root
  from public.bills
  where id = coalesce(v_bill.parent_bill_id, v_bill.id);

  select coalesce(sum(total_amount), 0.00), coalesce(sum(due_amount), 0.00)
  into v_credits, v_credit_due
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root.id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  return jsonb_build_object(
    'bill_id', v_root.id,
    'invoice_no', v_root.invoice_no,
    'original_total', v_root.total_amount,
    'paid_amount', v_root.paid_amount,
    'credits_issued', v_credits,
    'debits_issued', v_debits,
    'due_amount', v_root.due_amount,
    'credit_open', v_credit_due,
    'document_kind', v_bill.document_kind
  );
end;
$$;

ALTER FUNCTION "public"."get_bill_net_balances"("p_bill_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_bill_detail_bundle"("p_tenant_id" bigint, "p_bill_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_bill public.bills;
  v_bill_json jsonb;
  v_adjustments jsonb := '[]'::jsonb;
begin
  if p_tenant_id is null or p_bill_id is null then
    raise exception 'Tenant and bill are required.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    raise exception 'bill not found';
  end if;

  if not (v_bill.parent_tenant_id = v_parent_id or v_bill.issued_by_tenant_id = p_tenant_id) then
    raise exception 'Invoice not found for this tenant.';
  end if;

  v_bill_json := row_to_json(v_bill)::jsonb
    || jsonb_build_object(
      'profiles', (
        select jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address,
          'color', p.accent_color
        )
        from public.profiles p
        where p.id = v_bill.profile_id
      ),
      'from_profile', (
        select jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        from public.profiles p
        where p.id = v_bill.from_profile_id
      ),
      'to_profile', (
        select jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        from public.profiles p
        where p.id = v_bill.to_profile_id
      )
    );

  if v_bill.document_kind = 'standard'::public.bill_document_kind then
    select coalesce(jsonb_agg(row_to_json(adj)), '[]'::jsonb)
    into v_adjustments
    from public.list_bill_adjustments(p_bill_id) as adj;
  end if;

  return jsonb_build_object(
    'bill', v_bill_json,
    'payment_history', public.list_invoice_payment_history(p_tenant_id, p_bill_id),
    'net_balances', public.get_bill_net_balances(p_bill_id),
    'adjustments', v_adjustments
  );
end;
$$;

ALTER FUNCTION "public"."get_bill_detail_bundle"("p_tenant_id" bigint, "p_bill_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_payee_settlement_summary"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_avail NUMERIC(18,4) := 0;
  v_paid NUMERIC(18,4) := 0;
  v_credited NUMERIC(18,4) := 0;
  v_used NUMERIC(18,4) := 0;
  v_events JSONB := '[]'::jsonb;
BEGIN
  IF p_entity_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT COALESCE(available_balance, 0) INTO v_avail
  FROM public.cashbook_accounts
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND currency_code = 'BDT';

  SELECT COALESCE(SUM(base_amount), 0) INTO v_paid
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'pay'
    AND metadata->>'payee_type' = p_entity_type
    AND (metadata->>'payee_id')::bigint = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_credited
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'record_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(SUM(base_amount), 0) INTO v_used
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND metadata->>'action' = 'use_credit'
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'created_at', created_at,
      'type', type,
      'action', metadata->>'action',
      'amount_input', COALESCE((metadata->>'amount_input')::numeric, amount),
      'exchange_rate', COALESCE((metadata->>'exchange_rate')::numeric, exchange_rate),
      'base_amount', base_amount
    ) ORDER BY created_at DESC
  ), '[]'::jsonb) INTO v_events
  FROM public.cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND source_type = 'shipment'
    AND source_id = p_shipment_id::text
    AND (
      (entity_type = p_entity_type AND entity_id = p_entity_id)
      OR
      (metadata->>'payee_type' = p_entity_type AND (metadata->>'payee_id')::bigint = p_entity_id)
    );

  RETURN jsonb_build_object(
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'available_bdt', v_avail,
    'paid_bdt', v_paid,
    'credited_bdt', v_credited,
    'used_bdt', v_used,
    'recent_events', v_events
  );
END;
$$;

ALTER FUNCTION "public"."get_payee_settlement_summary"("p_tenant_id" bigint, "p_shipment_id" bigint, "p_entity_type" "text", "p_entity_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_phone text;
  v_row public.recipient_profiles%rowtype;
  v_can_access boolean;
  v_parent_id bigint;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  v_can_access := public.is_tenant_staff(p_tenant_id)
    or public.current_customer_group_id(p_tenant_id) is not null
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or public.has_active_tenant_membership(p_tenant_id);

  if not v_can_access then
    raise exception 'access denied';
  end if;

  begin
    v_phone := public.normalize_bd_mobile(p_phone);
  exception when others then
    return null;
  end;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_row
  from public.recipient_profiles
  where (parent_tenant_id = v_parent_id or (parent_tenant_id is null and tenant_id = v_parent_id) or tenant_id = p_tenant_id)
    and phone = v_phone
  order by (parent_tenant_id = v_parent_id) desc, updated_at desc
  limit 1;

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
    'parent_tenant_id', v_row.parent_tenant_id,
    'created_at', v_row.created_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

ALTER FUNCTION "public"."get_recipient_profile_by_phone"("p_tenant_id" bigint, "p_phone" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_sales_invoice_dashboard_metrics"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_today date;
  v_today_billed numeric := 0;
  v_unpaid_count bigint := 0;
  v_overdue_count bigint := 0;
  v_draft_count bigint := 0;
  v_paid numeric := 0;
  v_due numeric := 0;
  v_overdue numeric := 0;
  v_customers jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'global_invoice', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    coalesce(sum(si.total_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.invoice_date = v_today
    ), 0),
    count(*) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
    ),
    count(*) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
        AND si.due_date IS NOT NULL
        AND si.due_date < v_today
    ),
    count(*) FILTER (WHERE si.invoice_status = 'draft'::public.global_invoice_status),
    coalesce(sum(si.paid_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
    ), 0),
    coalesce(sum(si.due_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND (si.due_date IS NULL OR si.due_date >= v_today)
        AND si.due_amount > 0
    ), 0),
    coalesce(sum(si.due_amount) FILTER (
      WHERE si.invoice_status = 'issued'::public.global_invoice_status
        AND si.due_amount > 0
        AND si.due_date IS NOT NULL
        AND si.due_date < v_today
    ), 0)
  INTO v_today_billed, v_unpaid_count, v_overdue_count, v_draft_count, v_paid, v_due, v_overdue
  FROM public.bills si
  WHERE si.issued_by_tenant_id = p_tenant_id;

  SELECT coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  INTO v_customers
  FROM (
    SELECT
      coalesce(nullif(trim(pr.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS name,
      round(sum(si.due_amount), 2) AS due_amount,
      count(*)::bigint AS invoice_count
    FROM public.bills si
    LEFT JOIN public.profiles pr ON pr.id = si.profile_id
    WHERE si.issued_by_tenant_id = p_tenant_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.due_amount > 0
      AND si.due_date IS NOT NULL
      AND si.due_date < v_today
    GROUP BY 1
    ORDER BY sum(si.due_amount) DESC
    LIMIT 5
  ) r;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'today_billed_amount', round(v_today_billed, 2),
    'unpaid_count', v_unpaid_count,
    'overdue_count', v_overdue_count,
    'draft_count', v_draft_count,
    'paid_amount', round(v_paid, 2),
    'due_amount', round(v_due, 2),
    'overdue_amount', round(v_overdue, 2),
    'overdue_customers', v_customers
  );
END;
$$;

ALTER FUNCTION "public"."get_sales_invoice_dashboard_metrics"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_result jsonb;
  v_books_id bigint;
  v_entity_id bigint;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
  END IF;

  SELECT jsonb_build_object(
    'parent_tenant_id', v_books_id,
    'tenant_id', v_books_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(w.currency_code, p_currency_code),
    'available_balance', coalesce(w.available_balance, 0.0000),
    'pending_balance', coalesce(w.pending_balance, 0.0000),
    'locked_balance', coalesce(w.locked_balance, 0.0000),
    'total_balance', (
      coalesce(w.available_balance, 0.0000)
      + coalesce(w.pending_balance, 0.0000)
      + coalesce(w.locked_balance, 0.0000)
    )
  )
  INTO v_result
  FROM (SELECT 1) dummy
  LEFT JOIN public.cashbook_accounts w
    ON w.parent_tenant_id = v_books_id
   AND w.entity_type = p_entity_type
   AND w.entity_id = v_entity_id
   AND w.currency_code = coalesce(p_currency_code, 'BDT');

  RETURN v_result;
END;
$$;

ALTER FUNCTION "public"."get_wallet_account_balances"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_wallet_dashboard_summary"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_tenant_cash numeric(18,4) := 0.0000;
  v_courier_cod_holding numeric(18,4) := 0.0000;
  v_merchant_pending numeric(18,4) := 0.0000;
  v_merchant_available numeric(18,4) := 0.0000;
  v_vendor_payables numeric(18,4) := 0.0000;
  v_customer_deposits numeric(18,4) := 0.0000;
  v_ledger_cash numeric(18,4);
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.wallet_staff_can_view(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
    or public.is_tenant_staff(p_tenant_id)
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'access denied',
      'tenant_id', v_books_id,
      'parent_tenant_id', v_books_id,
      'tenant_cash_total', 0,
      'courier_cod_holding_total', 0,
      'merchant_pending_total', 0,
      'merchant_available_total', 0,
      'vendor_payables_total', 0,
      'customer_deposits_total', 0
    );
  end if;

  select coalesce(w.available_balance, 0.0000)
  into v_tenant_cash
  from public.cashbook_accounts w
  where w.parent_tenant_id = v_books_id
    and w.entity_type = 'tenant'
    and w.entity_id = v_books_id
    and w.currency_code = 'BDT'
  limit 1;

  select l.balance_after
  into v_ledger_cash
  from public.cashbook_entries l
  where l.parent_tenant_id = v_books_id
    and l.entity_type = 'tenant'
    and l.entity_id = v_books_id
    and coalesce(l.currency_code, 'BDT') = 'BDT'
  order by l.id desc
  limit 1;

  if coalesce(v_tenant_cash, 0) = 0 and coalesce(v_ledger_cash, 0) <> 0 then
    v_tenant_cash := v_ledger_cash;
  end if;

  select
    coalesce(sum(case when entity_type = 'courier' then pending_balance + available_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then pending_balance else 0 end), 0),
    coalesce(sum(case when entity_type in ('customer', 'middleman') then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'vendor' then available_balance else 0 end), 0),
    coalesce(sum(case when entity_type = 'customer' then available_balance else 0 end), 0)
  into
    v_courier_cod_holding,
    v_merchant_pending,
    v_merchant_available,
    v_vendor_payables,
    v_customer_deposits
  from public.cashbook_accounts
  where parent_tenant_id = v_books_id;

  return jsonb_build_object(
    'success', true,
    'tenant_id', v_books_id,
    'parent_tenant_id', v_books_id,
    'tenant_cash_total', coalesce(v_tenant_cash, 0),
    'courier_cod_holding_total', v_courier_cod_holding,
    'merchant_pending_total', v_merchant_pending,
    'merchant_available_total', v_merchant_available,
    'vendor_payables_total', v_vendor_payables,
    'customer_deposits_total', v_customer_deposits
  );
end;
$$;

ALTER FUNCTION "public"."get_wallet_dashboard_summary"("p_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_wallet_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_operating_id bigint;
  v_name text;
  v_code text;
  v_caption text;
  v_source_uuid uuid;
  v_entity_id bigint;
  v_account jsonb;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_id := p_tenant_id;
  v_entity_id := p_entity_id;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_books_id;
    SELECT t.name INTO v_name FROM public.tenants t WHERE t.id = v_books_id;
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;
    v_caption := 'Company cash pool';

  ELSIF p_entity_type = 'customer' THEN
    SELECT
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || pr.name ELSE pr.name END,
      nullif(trim(concat_ws(' • ', pr.phone, pr.email)), '')
    INTO v_name, v_caption
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    WHERE pr.id = p_entity_id
      AND (pr.operating_tenant_id = v_books_id OR pr.operating_tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'entity not found');
    END IF;

  ELSIF p_entity_type = 'vendor' THEN
    SELECT v.name, v.code, nullif(trim(concat_ws(' • ', v.phone, v.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.vendors v WHERE v.id = p_entity_id AND v.parent_tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'cargo_company' THEN
    SELECT c.name, c.code, nullif(trim(concat_ws(' • ', c.phone, c.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.cargo_companies c WHERE c.id = p_entity_id AND c.parent_tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'courier' THEN
    SELECT cs.name, upper(cs.code), coalesce(nullif(trim(cs.notes), ''), 'Courier service'), cs.id
    INTO v_name, v_code, v_caption, v_source_uuid
    FROM public.courier_services cs
    WHERE cs.wallet_entity_id = p_entity_id AND cs.is_active = true
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id));
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'investor' THEN
    SELECT i.name, nullif(trim(concat_ws(' • ', i.phone, i.email)), '')
    INTO v_name, v_caption
    FROM public.investors i WHERE i.id = p_entity_id AND i.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid entity_type');
  END IF;

  v_account := public.get_wallet_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

  RETURN jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'operating_tenant_id', v_operating_id,
    'entity', jsonb_build_object(
      'entity_type', p_entity_type,
      'entity_id', v_entity_id,
      'name', v_name,
      'code', v_code,
      'caption', v_caption,
      'source_uuid', v_source_uuid
    ),
    'account', jsonb_build_object(
      'currency_code', coalesce(v_account->>'currency_code', p_currency_code),
      'available_balance', coalesce((v_account->>'available_balance')::numeric, 0),
      'pending_balance', coalesce((v_account->>'pending_balance')::numeric, 0),
      'locked_balance', coalesce((v_account->>'locked_balance')::numeric, 0),
      'total_balance', coalesce((v_account->>'total_balance')::numeric, 0)
    ),
    'permissions', jsonb_build_object(
      'can_record_manual', public.wallet_staff_can_edit(p_tenant_id),
      'can_reverse', public.wallet_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

ALTER FUNCTION "public"."get_wallet_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_end_date" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    AS $$
DECLARE
  v_opening_balance NUMERIC(18,4) := 0.0000;
  v_total_credits NUMERIC(18,4) := 0.0000;
  v_total_debits NUMERIC(18,4) := 0.0000;
  v_closing_balance NUMERIC(18,4) := 0.0000;
  v_entries JSONB;
BEGIN
  IF p_start_date IS NOT NULL THEN
    SELECT COALESCE(
      SUM(CASE WHEN type = 'credit' THEN amount ELSE -amount END),
      0.0000
    )
    INTO v_opening_balance
    FROM cashbook_entries
    WHERE tenant_id = p_tenant_id
      AND entity_type = p_entity_type
      AND entity_id = p_entity_id
      AND created_at < p_start_date;
  END IF;

  SELECT 
    COALESCE(SUM(CASE WHEN type = 'credit' THEN amount ELSE 0 END), 0.0000),
    COALESCE(SUM(CASE WHEN type = 'debit' THEN amount ELSE 0 END), 0.0000)
  INTO v_total_credits, v_total_debits
  FROM cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  v_closing_balance := v_opening_balance + v_total_credits - v_total_debits;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', id,
      'tenant_id', tenant_id,
      'entity_type', entity_type,
      'entity_id', entity_id,
      'type', type,
      'amount', amount,
      'currency_code', currency_code,
      'exchange_rate', exchange_rate,
      'base_amount', base_amount,
      'balance_after', balance_after,
      'source_type', source_type,
      'source_id', source_id,
      'metadata', metadata,
      'created_at', created_at
    ) ORDER BY created_at ASC, id ASC
  ), '[]'::jsonb)
  INTO v_entries
  FROM cashbook_entries
  WHERE tenant_id = p_tenant_id
    AND entity_type = p_entity_type
    AND entity_id = p_entity_id
    AND (p_start_date IS NULL OR created_at >= p_start_date)
    AND (p_end_date IS NULL OR created_at <= p_end_date);

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', p_entity_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'opening_balance', v_opening_balance,
    'total_credits', v_total_credits,
    'total_debits', v_total_debits,
    'closing_balance', v_closing_balance,
    'entries', v_entries
  );
END;
$$;

ALTER FUNCTION "public"."get_wallet_entity_statement"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_start_date" timestamp with time zone, "p_end_date" timestamp with time zone) OWNER TO "postgres";

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

CREATE OR REPLACE FUNCTION "public"."insert_global_payment_instruments"("p_payment_id" bigint, "p_instruments" "jsonb") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_sort int := 0;
begin
  if coalesce(jsonb_typeof(p_instruments), 'null') <> 'array' then
    return;
  end if;

  for v_line in
    select value from jsonb_array_elements(p_instruments)
  loop
    v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
    v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
    if v_line_amount <= 0 then
      continue;
    end if;

    if not exists (
      select 1 from public.payment_methods pm
      where pm.code = v_method_code and pm.is_active = true
    ) then
      raise exception 'Invalid payment method: %', v_method_code;
    end if;

    if v_method_code = 'CHEQUE' then
      if (v_line.value ->> 'bd_bank_id') is null then
        raise exception 'Cheque line requires a bank';
      end if;
      if nullif(trim(coalesce(v_line.value ->> 'cheque_number', '')), '') is null then
        raise exception 'Cheque line requires a cheque number';
      end if;
      if (v_line.value ->> 'cheque_date') is null then
        raise exception 'Cheque line requires a cheque date';
      end if;
    end if;

    if v_method_code = 'BANK_TRANSFER'
       and (v_line.value ->> 'bd_bank_id') is null
       and nullif(trim(coalesce(v_line.value ->> 'reference', '')), '') is null then
      raise exception 'Bank transfer line requires a bank or transaction reference';
    end if;

    if v_method_code in ('CHEQUE', 'BANK_TRANSFER')
       and (v_line.value ->> 'bd_bank_id') is not null
       and not exists (
      select 1 from public.bd_banks b
      where b.id = (v_line.value ->> 'bd_bank_id')::bigint and b.is_active = true
    ) then
      raise exception 'Invalid bank on payment line';
    end if;

    v_sort := v_sort + 1;
    insert into public.pay_instruments (
      payment_id, payment_method_code, amount, reference,
      bd_bank_id, cheque_number, cheque_date, sort_order, cashbook_point_id
    ) values (
      p_payment_id,
      v_method_code,
      v_line_amount,
      nullif(trim(coalesce(v_line.value ->> 'reference', '')), ''),
      case when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'bd_bank_id')::bigint else null end,
      case when v_method_code = 'CHEQUE' then nullif(trim(v_line.value ->> 'cheque_number'), '') else null end,
      case
        when v_method_code in ('CHEQUE', 'BANK_TRANSFER') then (v_line.value ->> 'cheque_date')::date
        else null
      end,
      v_sort,
      nullif(v_line.value ->> 'cashbook_point_id', '')::bigint
    );
  end loop;
end;
$$;

ALTER FUNCTION "public"."insert_global_payment_instruments"("p_payment_id" bigint, "p_instruments" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_dropship_tenant_b2b_invoice"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_build jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_created boolean := false;
  v_courier_cod_booked boolean := false;
  v_orphan_invoice_id bigint;
  v_parent_tenant_id bigint;
  v_merchant_profile_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'tenant mismatch');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in (
    'ready_for_pickup'::public.shop_order_status,
    'shipped'::public.shop_order_status,
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'tenant B2B invoice requires ready_for_pickup, shipped, or delivered (current: %s)',
        v_order.status
      )
    );
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  v_merchant_profile_id := null;
  if v_order.profile_id is not null then
    select p.id into v_merchant_profile_id
    from public.profiles p
    where p.id = v_order.profile_id
      and p.profile_type = 'customer'::public.profile_party_type
      and p.deleted_at is null;
  end if;

  if v_merchant_profile_id is null then
    v_merchant_profile_id := public.resolve_customer_profile_for_group(
      v_order.tenant_id,
      v_order.customer_group_id
    );
  end if;

  if v_merchant_profile_id is null then
    return jsonb_build_object(
      'success', false,
      'error', 'dropshipper customer profile is required; do not bill the tenant'
    );
  end if;

  if v_order.profile_id is distinct from v_merchant_profile_id then
    update public.shop_orders
    set profile_id = v_merchant_profile_id, updated_at = now()
    where id = p_order_id;
    v_order.profile_id := v_merchant_profile_id;
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.id is not null
       and v_invoice.invoice_status = 'draft'::public.global_invoice_status then
      if v_invoice.profile_id is distinct from v_merchant_profile_id then
        update public.bills
        set profile_id = v_merchant_profile_id, updated_at = now()
        where id = v_invoice.id;
        perform public.stamp_bill_kernel_fields(v_invoice.id);
      end if;
      perform public.post_sales_invoice(v_invoice.id);
      perform public.sync_sales_invoice_charges_from_header(v_invoice.id);
      select * into v_invoice from public.bills where id = v_invoice.id;
    end if;
    return jsonb_build_object(
      'success', true,
      'already_issued', true,
      'created', false,
      'order_id', p_order_id,
      'invoice', jsonb_build_object(
        'id', v_invoice.id,
        'invoice_no', v_invoice.invoice_no,
        'invoice_type', v_invoice.invoice_type,
        'invoice_status', v_invoice.invoice_status,
        'payment_status', v_invoice.payment_status,
        'subtotal_amount', v_invoice.subtotal_amount,
        'print_charge', v_invoice.print_charge,
        'wrapping_charge', v_invoice.wrapping_charge,
        'discount_amount', v_invoice.discount_amount,
        'total_amount', v_invoice.total_amount,
        'paid_amount', v_invoice.paid_amount,
        'due_amount', v_invoice.due_amount,
        'profile_id', v_invoice.profile_id,
        'collection_source', v_invoice.collection_source
      )
    );
  end if;

  v_build := public.build_dropship_tenant_b2b_invoice_payload(p_order_id);
  if coalesce(v_build->>'success', 'false') <> 'true' then
    return v_build;
  end if;

  v_payload := v_build->'payload';
  v_payload := v_payload || jsonb_build_object(
    'issue', true,
    'shop_order_id', p_order_id
  );

  select i.id into v_orphan_invoice_id
  from public.bills i
  where i.invoice_no = v_payload->'invoice'->>'invoice_no'
    and i.invoice_type = 'dropship'::public.global_invoice_type
    and (
      i.issued_by_tenant_id = v_order.tenant_id
      or i.parent_tenant_id = v_parent_tenant_id
    )
    and not exists (
      select 1 from public.shop_orders o2 where o2.global_invoice_id = i.id
    )
  limit 1;

  if v_orphan_invoice_id is not null then
    delete from public.global_return_items where invoice_id = v_orphan_invoice_id;
    delete from public.bill_lines where invoice_id = v_orphan_invoice_id;
    delete from public.bills where id = v_orphan_invoice_id;
  end if;

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);
  v_created := true;

  if coalesce(v_result->>'success', 'false') <> 'true' then
    return coalesce(
      v_result,
      jsonb_build_object('success', false, 'error', 'failed to upsert tenant B2B invoice')
    );
  end if;

  update public.shop_orders
  set
    global_invoice_id = (v_result->>'invoice_id')::bigint,
    updated_at = now()
  where id = p_order_id
    and global_invoice_id is null;

  select * into v_order from public.shop_orders where id = p_order_id;
  select * into v_invoice from public.bills where id = v_order.global_invoice_id;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice was not created');
  end if;

  perform public.sync_sales_invoice_charges_from_header(v_invoice.id);

  update public.bills
  set
    shop_order_id = p_order_id,
    channel_meta = coalesce(v_payload->'invoice'->'channel_meta', '{}'::jsonb),
    updated_at = now()
  where id = v_invoice.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  v_courier_cod_booked := exists (
    select 1 from public.cashbook_entries
    where tenant_id = v_order.tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'delivered_costing'
  );

  return jsonb_build_object(
    'success', true,
    'created', v_created,
    'already_issued', false,
    'order_id', p_order_id,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'invoice_no', v_invoice.invoice_no,
      'invoice_type', v_invoice.invoice_type,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'subtotal_amount', v_invoice.subtotal_amount,
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'discount_amount', v_invoice.discount_amount,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'profile_id', v_invoice.profile_id,
      'collection_source', v_invoice.collection_source
    ),
    'wallet', jsonb_build_object(
      'courier_cod_booked', v_courier_cod_booked,
      'source_type', 'shop_order',
      'source_id', p_order_id::text
    )
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

ALTER FUNCTION "public"."issue_dropship_tenant_b2b_invoice"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_wholesale_invoice"("p_invoice_id" bigint, "p_items" "jsonb" DEFAULT NULL::"jsonb") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item_record jsonb;
  v_item_id bigint;
  v_item_qty numeric;
  v_item_price numeric;
  v_line_total numeric;
  v_db_item public.bill_lines%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can be issued';
  end if;

  if v_invoice.profile_id is null then
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
        select * into v_db_item from public.bill_lines where id = v_item_id and invoice_id = p_invoice_id;
        if v_db_item.id is not null then
          v_item_price := coalesce(v_item_price, v_db_item.sell_price_amount);
          v_line_total := greatest((v_item_qty * v_item_price) - coalesce(v_db_item.line_discount_amount, 0.00), 0.00);

          update public.bill_lines
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

  if not exists (select 1 from public.bill_lines where invoice_id = p_invoice_id) then
    raise exception 'Cannot issue an empty invoice';
  end if;


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
  for v_db_item in select * from public.bill_lines where invoice_id = p_invoice_id loop
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

  -- 5. Mark invoice as issued (status = 'issued'::public.global_invoice_status)
  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(payment_status, ''), 'due')
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$$;

ALTER FUNCTION "public"."issue_wholesale_invoice"("p_invoice_id" bigint, "p_items" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_customer_group_receipts"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  if p_tenant_id is null or p_customer_group_id is null then
    raise exception 'Tenant and customer group are required.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      gp.id,
      gp.payment_date,
      gp.amount,
      gp.unallocated_amount,
      gp.method,
      gp.reference,
      gp.note,
      gp.voided_at,
      gp.profile_id as profile_id,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            order by gpi.sort_order, gpi.id
          )
          from public.pay_instruments gpi
          left join public.bd_banks b on b.id = gpi.bd_bank_id
          where gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as instruments,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'invoice_id', ip.global_invoice_id,
              'invoice_no', si.invoice_no,
              'amount', ip.amount
            )
            order by si.invoice_no
          )
          from public.pay_allocations ip
          join public.bills si on si.id = ip.global_invoice_id
          where ip.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as allocations
    from public.pays gp
    where gp.tenant_id = p_tenant_id
      and (
        gp.customer_group_id = p_customer_group_id
        or gp.profile_id in (
          select pr.id from public.profiles pr where pr.customer_group_id = p_customer_group_id
        )
      )
      and coalesce(gp.method, '') <> 'wallet_credit'
    order by gp.voided_at nulls first, gp.payment_date desc, gp.id desc
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."list_customer_group_receipts"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_customer_groups_payment_summary"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0, "p_only_with_due" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id,
      cg.name,
      'CUST-GRP-' || lpad(cg.id::text, 4, '0') as account_code,
      coalesce(
        (select pr.phone from public.profiles pr where pr.customer_group_id = cg.id and pr.phone is not null limit 1),
        '—'
      ) as phone,
      coalesce(
        (select array_agg(pr.name order by pr.name) from public.profiles pr where pr.customer_group_id = cg.id),
        array[]::text[]
      ) as branches,
      coalesce(
        count(distinct si.id) filter (where si.invoice_status = 'issued' and si.due_amount > 0),
        0
      )::int as open_invoice_count,
      coalesce(
        sum(si.total_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_invoiced,
      coalesce(
        sum(si.paid_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_paid,
      coalesce(
        sum(si.written_off_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_written_off,
      coalesce(
        sum(si.due_amount) filter (where si.invoice_status = 'issued'),
        0.00
      )::numeric(12,2) as total_due,
      (
        select max(gp.payment_date)
        from public.pays gp
        where gp.customer_group_id = cg.id
           or gp.profile_id in (select id from public.profiles where customer_group_id = cg.id)
      ) as last_payment_date
    from public.customer_groups cg
    left join public.profiles pr on pr.customer_group_id = cg.id
    left join public.bills si on si.profile_id = pr.id
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or cg.name ilike '%' || trim(p_search) || '%'
        or pr.name ilike '%' || trim(p_search) || '%'
        or pr.phone ilike '%' || trim(p_search) || '%'
      )
    group by cg.id, cg.name
    having (
      not coalesce(p_only_with_due, false)
      or coalesce(
        sum(si.due_amount) filter (where si.invoice_status = 'issued'),
        0.00
      ) > 0.00
    )
    order by total_due desc, cg.name asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."list_customer_groups_payment_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer, "p_only_with_due" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_customer_groups_payout_summary"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_only_with_payable" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
  v_search text;
begin
  if p_tenant_id is null then
    return '[]'::jsonb;
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_search := nullif(trim(p_search), '');

  if not (
    public.is_superadmin()
    or public.is_tenant_staff(p_tenant_id)
    or public.membership_has_module_action(v_parent_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
  ) then
    return '[]'::jsonb;
  end if;

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      cg.id as customer_group_id,
      cg.name,
      ('CUST-GRP-' || lpad(cg.id::text, 4, '0')) as account_code,
      coalesce(sum(wa.available_balance), 0.00)::numeric(12, 2) as payable_balance,
      (
        select coalesce(
          jsonb_agg(
            jsonb_build_object(
              'profile_id', pr2.id,
              'name', pr2.name,
              'payable_balance', coalesce(wa2.available_balance, 0.00)
            )
            order by coalesce(wa2.available_balance, 0.00) desc, pr2.name
          ),
          '[]'::jsonb
        )
        from public.profiles pr2
        left join public.cashbook_accounts wa2
          on wa2.parent_tenant_id = v_parent_id
         and wa2.entity_type = 'customer'
         and wa2.entity_id = pr2.id
         and wa2.currency_code = 'BDT'
        where pr2.customer_group_id = cg.id
          and pr2.profile_type = 'customer'::public.profile_party_type
          and (pr2.operating_tenant_id = v_parent_id or pr2.operating_tenant_id = p_tenant_id)
      ) as profiles
    from public.customer_groups cg
    inner join public.profiles pr
      on pr.customer_group_id = cg.id
     and (pr.operating_tenant_id = v_parent_id or pr.operating_tenant_id = p_tenant_id)
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_parent_id
     and wa.entity_type = 'customer'
     and wa.entity_id = pr.id
     and wa.currency_code = 'BDT'
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or pr.name ilike '%' || v_search || '%'
        or coalesce(pr.phone, '') ilike '%' || v_search || '%'
        or coalesce(pr.email, '') ilike '%' || v_search || '%'
      )
    group by cg.id, cg.name
    having (
      not coalesce(p_only_with_payable, false)
      or coalesce(sum(wa.available_balance), 0.00) > 0.00
    )
    order by payable_balance desc nulls last, cg.name asc
    limit greatest(least(coalesce(p_limit, 50), 200), 1)
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."list_customer_groups_payout_summary"("p_tenant_id" bigint, "p_search" "text", "p_limit" integer, "p_customer_group_id" bigint, "p_only_with_payable" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_global_invoice_items"("p_invoice_id" bigint) RETURNS TABLE("id" bigint, "invoice_id" bigint, "global_stock_id" bigint, "name_snapshot" "text", "quantity" numeric, "sell_price_amount" numeric, "recipient_price_amount" numeric, "line_face_total_amount" numeric, "line_discount_amount" numeric, "line_total_amount" numeric, "return_quantity" numeric, "image_url" "text", "shipment_id" bigint, "shipment_item_id" bigint, "purchase_price" numeric, "product_weight" numeric, "package_weight" numeric, "ordered_quantity" integer, "shipment_type" "text", "product_conversion_rate" numeric, "cargo_conversion_rate" numeric, "cargo_rate" numeric, "received_weight" numeric, "transaction_rate" numeric, "available_atp" numeric, "unit_cost_price" numeric)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_tenant_id bigint;
  v_issued_by bigint;
  v_invoice_status public.global_invoice_status;
begin
  select parent_tenant_id, issued_by_tenant_id, invoice_status
  into v_parent_tenant_id, v_issued_by, v_invoice_status
  from public.bills
  where public.bills.id = p_invoice_id;

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
    nullif(gii.line_meta->>'resell_price_amount', '')::numeric as recipient_price_amount,
    (gii.quantity * nullif(gii.line_meta->>'resell_price_amount', '')::numeric) as line_face_total_amount,
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
    null::numeric as transaction_rate,
    case
      when gii.global_stock_id is null then 0::numeric
      when v_invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status)
        then (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0) + gii.quantity)::numeric
      else (coalesce(public.global_stock_atp_qty(gii.global_stock_id), gs.quantity, 0))::numeric
    end as available_atp,
    coalesce(gsi.landed_cost_bdt, gsi.purchase_price, 0)::numeric as unit_cost_price
  from public.bill_lines gii
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

CREATE OR REPLACE FUNCTION "public"."list_invoice_payment_history"("p_tenant_id" bigint, "p_invoice_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  if p_tenant_id is null or p_invoice_id is null then
    raise exception 'Tenant and invoice are required.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not exists (
    select 1
    from public.bills si
    where si.id = p_invoice_id
      and (si.parent_tenant_id = v_parent_id or si.issued_by_tenant_id = p_tenant_id)
  ) then
    raise exception 'Invoice not found for this tenant.';
  end if;

  select coalesce(jsonb_agg(row_to_json(r) order by r.sort_at desc, r.entry_id desc), '[]'::jsonb)
  into v_result
  from (
    select
      'allocation'::text as entry_type,
      ip.id as entry_id,
      gp.id as payment_id,
      gp.payment_date,
      gp.payment_date::timestamptz as sort_at,
      ip.amount as amount,
      gp.amount as receipt_amount,
      gp.voided_at,
      gp.method,
      gp.note,
      null::text as write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') as settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) as exchange_rate,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            order by gpi.sort_order, gpi.id
          )
          from public.pay_instruments gpi
          left join public.bd_banks b on b.id = gpi.bd_bank_id
          where gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as instruments,
      gp.source as payment_source,
      null::text as related_invoice_no,
      null::text as related_document_kind
    from public.pay_allocations ip
    join public.pays gp on gp.id = ip.payment_id
    where ip.global_invoice_id = p_invoice_id

    union all

    select
      'allocation'::text as entry_type,
      ip.id as entry_id,
      gp.id as payment_id,
      gp.payment_date,
      gp.payment_date::timestamptz as sort_at,
      ip.amount as amount,
      gp.amount as receipt_amount,
      gp.voided_at,
      gp.method,
      gp.note,
      null::text as write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') as settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) as exchange_rate,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'id', gpi.id,
              'payment_method_code', gpi.payment_method_code,
              'amount', gpi.amount,
              'reference', gpi.reference,
              'bd_bank_id', gpi.bd_bank_id,
              'bank_name', b.name,
              'cheque_number', gpi.cheque_number,
              'cheque_date', gpi.cheque_date,
              'sort_order', gpi.sort_order
            )
            order by gpi.sort_order, gpi.id
          )
          from public.pay_instruments gpi
          left join public.bd_banks b on b.id = gpi.bd_bank_id
          where gpi.payment_id = gp.id
        ),
        '[]'::jsonb
      ) as instruments,
      gp.source as payment_source,
      child.invoice_no as related_invoice_no,
      child.document_kind::text as related_document_kind
    from public.pay_allocations ip
    join public.pays gp on gp.id = ip.payment_id
    join public.bills child on child.id = coalesce(ip.bill_id, ip.global_invoice_id)
    where child.parent_bill_id = p_invoice_id
      and child.document_kind in (
        'credit_note'::public.bill_document_kind,
        'debit_note'::public.bill_document_kind
      )

    union all

    select
      'write_off'::text as entry_type,
      iwo.id as entry_id,
      iwo.payment_id,
      coalesce(gp.payment_date, iwo.created_at::date) as payment_date,
      coalesce(gp.payment_date::timestamptz, iwo.created_at) as sort_at,
      iwo.amount as amount,
      coalesce(gp.amount, 0.00) as receipt_amount,
      gp.voided_at,
      coalesce(gp.method, 'write_off') as method,
      iwo.note,
      iwo.reason as write_off_reason,
      coalesce(gp.settlement_currency_code, 'BDT') as settlement_currency_code,
      gp.foreign_amount,
      coalesce(gp.exchange_rate, 1.000000) as exchange_rate,
      case
        when gp.id is null then '[]'::jsonb
        else coalesce(
          (
            select jsonb_agg(
              jsonb_build_object(
                'id', gpi.id,
                'payment_method_code', gpi.payment_method_code,
                'amount', gpi.amount,
                'reference', gpi.reference,
                'bd_bank_id', gpi.bd_bank_id,
                'bank_name', b.name,
                'cheque_number', gpi.cheque_number,
                'cheque_date', gpi.cheque_date,
                'sort_order', gpi.sort_order
              )
              order by gpi.sort_order, gpi.id
            )
            from public.pay_instruments gpi
            left join public.bd_banks b on b.id = gpi.bd_bank_id
            where gpi.payment_id = gp.id
          ),
          '[]'::jsonb
        )
      end as instruments,
      gp.source as payment_source,
      null::text as related_invoice_no,
      null::text as related_document_kind
    from public.invoice_write_offs iwo
    left join public.pays gp on gp.id = iwo.payment_id
    where iwo.invoice_id = p_invoice_id
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."list_invoice_payment_history"("p_tenant_id" bigint, "p_invoice_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_open_invoices_for_payment"("p_tenant_id" bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_result
  from (
    select
      si.id,
      si.invoice_no,
      si.invoice_type::text as invoice_type,
      cg.id as customer_group_id,
      coalesce(cg.name, pr.name, si.recipient_name, 'Direct Customer') as customer_group_name,
      coalesce(pr.name, 'Main Outlet') as branch_name,
      si.invoice_date,
      si.due_date,
      si.total_amount,
      si.paid_amount,
      si.written_off_amount,
      si.due_amount,
      si.payment_status
    from public.bills si
    left join public.profiles pr on pr.id = si.profile_id
    left join public.customer_groups cg on cg.id = pr.customer_group_id
    where (si.parent_tenant_id = v_parent_id or si.issued_by_tenant_id = p_tenant_id)
      and si.invoice_status = 'issued'
      and si.due_amount > 0
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or si.invoice_no ilike '%' || trim(p_search) || '%'
        or cg.name ilike '%' || trim(p_search) || '%'
        or pr.name ilike '%' || trim(p_search) || '%'
        or si.recipient_name ilike '%' || trim(p_search) || '%'
      )
    order by si.invoice_date asc, si.id asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."list_open_invoices_for_payment"("p_tenant_id" bigint, "p_customer_group_id" bigint, "p_search" "text", "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_wallet_entities_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 100, "p_offset" integer DEFAULT 0, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS TABLE("entity_id" bigint, "entity_type" "text", "name" "text", "code" "text", "caption" "text", "available_balance" numeric, "pending_balance" numeric, "locked_balance" numeric, "total_balance" numeric, "source_uuid" "uuid", "operating_tenant_id" bigint, "has_wallet_activity" boolean)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_search text;
  v_limit integer;
  v_offset integer;
BEGIN
  IF p_entity_type NOT IN ('customer', 'vendor', 'courier', 'cargo_company', 'investor') THEN
    RAISE EXCEPTION 'Invalid entity_type %. Allowed: customer, vendor, courier, cargo_company, investor', p_entity_type;
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN
    RETURN;
  END IF;

  v_search := nullif(trim(p_search), '');
  v_limit := greatest(least(coalesce(p_limit, 100), 500), 1);
  v_offset := greatest(coalesce(p_offset, 0), 0);

  IF p_entity_type = 'customer' THEN
    RETURN QUERY
    SELECT
      pr.id,
      'customer'::text,
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || pr.name ELSE pr.name END,
      NULL::text,
      nullif(trim(concat_ws(' • ', pr.phone, pr.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid,
      pr.operating_tenant_id,
      wa.id IS NOT NULL
    FROM public.profiles pr
    LEFT JOIN public.customer_groups cg ON cg.id = pr.customer_group_id
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id
     AND wa.entity_type = 'customer'
     AND wa.entity_id = pr.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE pr.profile_type = 'customer'::public.profile_party_type
      AND (pr.operating_tenant_id = v_books_id
       OR pr.operating_tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (
        v_search IS NULL
        OR pr.name ILIKE '%' || v_search || '%'
        OR coalesce(cg.name, '') ILIKE '%' || v_search || '%'
        OR coalesce(pr.phone, '') ILIKE '%' || v_search || '%'
        OR coalesce(pr.email, '') ILIKE '%' || v_search || '%'
      )
    ORDER BY 3 ASC, pr.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'vendor' THEN
    RETURN QUERY
    SELECT
      v.id, 'vendor'::text, v.name, v.code,
      nullif(trim(concat_ws(' • ', v.phone, v.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, v.parent_tenant_id, wa.id IS NOT NULL
    FROM public.vendors v
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'vendor' AND wa.entity_id = v.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE v.parent_tenant_id = v_books_id
      AND (v_search IS NULL OR v.name ILIKE '%' || v_search || '%' OR coalesce(v.code, '') ILIKE '%' || v_search || '%')
    ORDER BY v.name ASC, v.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'cargo_company' THEN
    RETURN QUERY
    SELECT
      c.id, 'cargo_company'::text, c.name, c.code,
      nullif(trim(concat_ws(' • ', c.phone, c.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, c.parent_tenant_id, wa.id IS NOT NULL
    FROM public.cargo_companies c
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'cargo_company' AND wa.entity_id = c.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE c.parent_tenant_id = v_books_id
      AND (v_search IS NULL OR c.name ILIKE '%' || v_search || '%' OR coalesce(c.code, '') ILIKE '%' || v_search || '%')
    ORDER BY c.name ASC, c.id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'courier' THEN
    RETURN QUERY
    SELECT
      cs.wallet_entity_id,
      'courier'::text,
      cs.name,
      upper(cs.code),
      coalesce(nullif(trim(cs.notes), ''), 'Courier service'),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      cs.id,
      coalesce(cs.tenant_id, v_books_id),
      wa.id IS NOT NULL
    FROM public.courier_services cs
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'courier' AND wa.entity_id = cs.wallet_entity_id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE cs.is_active = true
      AND cs.wallet_entity_id IS NOT NULL
      AND (cs.tenant_id IS NULL OR cs.tenant_id = v_books_id
           OR cs.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (v_search IS NULL OR cs.name ILIKE '%' || v_search || '%' OR coalesce(cs.code, '') ILIKE '%' || v_search || '%')
    ORDER BY cs.name ASC, cs.wallet_entity_id ASC
    LIMIT v_limit OFFSET v_offset;

  ELSIF p_entity_type = 'investor' THEN
    RETURN QUERY
    SELECT
      i.id, 'investor'::text, i.name, NULL::text,
      nullif(trim(concat_ws(' • ', i.phone, i.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid, i.tenant_id, wa.id IS NOT NULL
    FROM public.investors i
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id AND wa.entity_type = 'investor' AND wa.entity_id = i.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE i.tenant_id = v_books_id
      AND (v_search IS NULL OR i.name ILIKE '%' || v_search || '%')
    ORDER BY i.name ASC, i.id ASC
    LIMIT v_limit OFFSET v_offset;
  END IF;
END;
$$;

ALTER FUNCTION "public"."list_wallet_entities_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_search" "text", "p_limit" integer, "p_offset" integer, "p_currency_code" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."list_wallet_ledger_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_operating_tenant_id" bigint DEFAULT NULL::bigint, "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("id" "uuid", "parent_tenant_id" bigint, "operating_tenant_id" bigint, "entity_type" "text", "entity_id" bigint, "type" "text", "amount" numeric, "currency_code" "text", "exchange_rate" numeric, "base_amount" numeric, "balance_after" numeric, "source_type" "text", "source_id" "text", "metadata" "jsonb", "created_at" timestamp with time zone, "is_reversal" boolean, "reversed_entry_id" "uuid", "cashbook_point_id" bigint, "cashbook_point_name" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_entity_id bigint;
  v_search text;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN v_entity_id := v_books_id; END IF;

  IF NOT public.wallet_staff_can_view(p_tenant_id) THEN RETURN; END IF;

  v_search := nullif(trim(p_search), '');

  RETURN QUERY
  SELECT
    l.id,
    l.parent_tenant_id,
    l.operating_tenant_id,
    l.entity_type,
    l.entity_id,
    l.type,
    l.amount,
    l.currency_code,
    l.exchange_rate,
    l.base_amount,
    l.balance_after,
    l.source_type,
    l.source_id,
    l.metadata,
    l.created_at,
    (l.metadata ? 'reversal_of'),
    CASE WHEN l.metadata ? 'reversal_of' THEN (l.metadata->>'reversal_of')::uuid ELSE NULL END,
    l.cashbook_point_id,
    cp.name
  FROM public.cashbook_entries l
  LEFT JOIN public.cashbook_points cp ON cp.id = l.cashbook_point_id
  WHERE l.parent_tenant_id = v_books_id
    AND l.entity_type = p_entity_type
    AND l.entity_id = v_entity_id
    AND (p_operating_tenant_id IS NULL OR l.operating_tenant_id = p_operating_tenant_id)
    AND (
      v_search IS NULL
      OR coalesce(l.source_id, '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'note', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'trx_id', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.metadata->>'section', '') ILIKE '%' || v_search || '%'
      OR coalesce(l.source_type, '') ILIKE '%' || v_search || '%'
      OR coalesce(cp.name, '') ILIKE '%' || v_search || '%'
    )
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT greatest(least(coalesce(p_limit, 50), 200), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$$;

ALTER FUNCTION "public"."list_wallet_ledger_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_search" "text", "p_operating_tenant_id" bigint, "p_limit" integer, "p_offset" integer) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."normalize_pay_settlement_fx"("p_instrument_total_bdt" numeric, "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_base_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS TABLE("settlement_currency_code" "text", "foreign_amount" numeric, "exchange_rate" numeric, "amount_bdt" numeric)
    LANGUAGE "plpgsql" IMMUTABLE
    AS $$
declare
  v_cur text;
  v_base text;
  v_for numeric;
  v_rate numeric;
  v_bdt numeric;
begin
  v_base := upper(trim(coalesce(p_base_currency_code, 'BDT')));
  v_cur := upper(trim(coalesce(p_settlement_currency_code, v_base)));
  v_for := p_foreign_amount;

  if v_for is not null and v_for > 0 then
    if v_cur in ('', v_base) then
      raise exception 'foreign_amount requires a settlement currency other than base (%)', v_base;
    end if;
    v_rate := coalesce(p_exchange_rate, 0);
    if v_rate <= 0 then
      raise exception 'exchange_rate must be positive when foreign_amount is set';
    end if;
    v_bdt := round(v_for * v_rate, 2);
    if coalesce(p_instrument_total_bdt, 0) > 0 and round(p_instrument_total_bdt, 2) <> v_bdt then
      raise exception 'Payment instruments total (%) must match books amount from foreign settlement (%)',
        p_instrument_total_bdt, v_bdt;
    end if;
    settlement_currency_code := v_cur;
    foreign_amount := round(v_for, 2);
    exchange_rate := v_rate;
    amount_bdt := v_bdt;
    return next;
    return;
  end if;

  v_bdt := round(coalesce(p_instrument_total_bdt, 0), 2);
  settlement_currency_code := v_base;
  foreign_amount := null;
  exchange_rate := 1.000000;
  amount_bdt := v_bdt;
  return next;
end;
$$;

ALTER FUNCTION "public"."normalize_pay_settlement_fx"("p_instrument_total_bdt" numeric, "p_settlement_currency_code" "text", "p_foreign_amount" numeric, "p_exchange_rate" numeric, "p_base_currency_code" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" "date", "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_source" "text" DEFAULT 'customer_cash'::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric) RETURNS "public"."pays"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_source text := lower(trim(coalesce(p_source, 'customer_cash')));
  v_received_on date := coalesce(p_received_on, current_date);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_reference text := nullif(trim(coalesce(p_reference, '')), '');
  v_pay public.pays;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int := 0;
  v_amount numeric(12, 2) := 0.00;
  v_header_method text;
  v_alloc jsonb;
  v_bill public.bills;
  v_bill_id bigint;
  v_alloc_amount numeric(12, 2);
  v_total_alloc numeric(12, 2) := 0.00;
  v_leftover numeric(12, 2);
  v_profit_already_credited boolean := false;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_cashbook_point_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;
  if v_source not in ('customer_cash', 'bank', 'store_credit', 'courier_remittance') then
    raise exception 'Invalid receipt source: %', p_source;
  end if;
  if v_source = 'courier_remittance' and p_shop_order_id is null then
    raise exception 'Courier remittance requires a shop order';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: cannot record receipts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.parent_tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_profile_id;
  end if;

  -- Instruments: validate and total (header amount = instrument sum).
  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then
        continue;
      end if;
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
      if v_line_count = 1 then
        v_header_method := lower(v_method_code);
      else
        v_header_method := 'split';
      end if;
    end loop;
  end if;

  if v_source = 'store_credit' then
    if v_line_count > 0 then
      raise exception 'Store credit receipts take no instrument lines';
    end if;
    v_header_method := 'store_credit';
  elsif v_line_count = 0 then
    raise exception 'Enter at least one payment line';
  end if;

  if v_header_method is not null and v_header_method not in (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split',
    'store_credit'
  ) then
    v_header_method := 'other';
  end if;

  if v_source <> 'store_credit' then
    select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
    into v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
    from public.normalize_pay_settlement_fx(
      v_amount,
      p_settlement_currency_code,
      p_foreign_amount,
      p_exchange_rate,
      public.resolve_tenant_base_currency_code(p_tenant_id)
    ) n;
  end if;

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id,
    settlement_currency_code, foreign_amount, exchange_rate
  ) values (
    v_parent_id, p_profile_id, v_source, v_amount, v_amount,
    v_received_on, v_header_method, v_reference, v_note, p_shop_order_id,
    v_settle_currency, v_foreign_amt, v_fx_rate
  ) returning * into v_pay;

  if v_line_count > 0 then
    perform public.insert_global_payment_instruments(v_pay.id, p_instruments);
  end if;

  -- Allocations: open issued bills of this profile only.
  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    for v_alloc in select value from jsonb_array_elements(p_allocations)
    loop
      v_bill_id := coalesce(nullif(v_alloc ->> 'bill_id', '')::bigint, nullif(v_alloc ->> 'invoice_id', '')::bigint);
      v_alloc_amount := round(coalesce((v_alloc ->> 'amount')::numeric, 0.00), 2);
      if v_bill_id is null or v_alloc_amount <= 0 then
        continue;
      end if;

      select * into v_bill from public.bills where id = v_bill_id for update;
      if v_bill.id is null then
        raise exception 'Bill % not found', v_bill_id;
      end if;
      if v_bill.parent_tenant_id <> v_parent_id then
        raise exception 'Bill % belongs to other books', v_bill_id;
      end if;
      if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
        raise exception 'Bill % is not issued', v_bill.invoice_no;
      end if;
      if v_bill.profile_id is distinct from p_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;
      if v_alloc_amount > coalesce(v_bill.due_amount, 0.00) then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_bill.due_amount;
      end if;

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_bill_id, v_alloc_amount);

      perform public.recompute_global_invoice_payment_status(v_bill_id);
      v_total_alloc := v_total_alloc + v_alloc_amount;
    end loop;
  end if;

  if v_source = 'store_credit' then
    if v_total_alloc <= 0 then
      raise exception 'Store credit receipt needs at least one allocation';
    end if;
    v_amount := v_total_alloc;
  elsif v_total_alloc > v_amount then
    raise exception 'Allocations (%) exceed receipt amount (%)', v_total_alloc, v_amount;
  end if;

  v_leftover := v_amount - v_total_alloc;

  update public.pays
  set amount = v_amount, unallocated_amount = v_leftover
  where id = v_pay.id
  returning * into v_pay;

  v_cashbook_point_id := null;
  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      if nullif(v_line.value ->> 'cashbook_point_id', '') is not null then
        v_cashbook_point_id := (v_line.value ->> 'cashbook_point_id')::bigint;
        exit;
      end if;
    end loop;
  end if;

  if v_source in ('customer_cash', 'bank', 'courier_remittance') then
    if v_source = 'courier_remittance' and v_cashbook_point_id is null then
      raise exception 'Courier remittance requires a cashbook location';
    end if;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => case when v_source = 'courier_remittance' then 'shop_order' else 'sales_invoice' end,
      p_source_id => case when v_source = 'courier_remittance' then p_shop_order_id::text else v_pay.id::text end,
      p_metadata => jsonb_build_object(
        'section', case when v_source = 'courier_remittance' then 'payment_received' else 'payments' end,
        'purpose', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'tenant_payment_received'
        end,
        'transaction_type', case
          when v_source = 'courier_remittance' then 'courier_remittance_received'
          else 'payment_received'
        end,
        'label', case when v_source = 'courier_remittance' then 'Courier remittance received' else 'Payment received' end,
        'payment_id', v_pay.id,
        'method', v_header_method,
        'instrument_count', v_line_count,
        'reference', v_reference,
        'shop_order_id', case when v_source = 'courier_remittance' then p_shop_order_id else null end
      ),
      p_cashbook_point_id => v_cashbook_point_id
    );
  elsif v_source = 'store_credit' then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => p_profile_id,
      p_type => 'debit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_pay.id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied store credit',
        'payment_id', v_pay.id
      )
    );
  end if;

  if v_leftover > 0 then
    if v_source = 'courier_remittance' then
      select exists (
        select 1
        from public.cashbook_entries u
        where u.parent_tenant_id = v_parent_id
          and u.source_type = 'shop_order'
          and u.source_id = p_shop_order_id::text
          and u.entity_type in ('middleman', 'customer')
          and u.entity_id = p_profile_id
          and u.type = 'credit'
          and coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
      ) into v_profit_already_credited;

      if not v_profit_already_credited then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => v_parent_id,
          p_operating_tenant_id => p_tenant_id,
          p_entity_type => 'customer',
          p_entity_id => p_profile_id,
          p_type => 'credit',
          p_amount => v_leftover,
          p_currency_code => 'BDT',
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_shop_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'payout_earned',
            'transaction_type', 'dropship_profit',
            'label', 'Dropship profit from remittance remainder',
            'order_id', p_shop_order_id,
            'shop_order_id', p_shop_order_id::text,
            'payment_id', v_pay.id,
            'remittance_ref', v_reference,
            'net_remitted', v_amount,
            'invoice_allocated', v_total_alloc
          )
        );
      end if;
    else
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => p_profile_id,
        p_type => 'credit',
        p_amount => v_leftover,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice',
        p_source_id => v_pay.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'store_credit',
          'payment_id', v_pay.id,
          'reference', v_reference
        )
      );
    end if;
  end if;

  return v_pay;
end;
$$;

ALTER FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" "date", "p_note" "text", "p_reference" "text", "p_source" "text", "p_instruments" "jsonb", "p_allocations" "jsonb", "p_shop_order_id" bigint, "p_settlement_currency_code" "text", "p_foreign_amount" numeric, "p_exchange_rate" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_build_shipment_ap_bucket_paper"("p_shipment_id" bigint, "p_ship" "public"."global_shipments", "p_bucket" "public"."global_shipment_cost_bucket") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
declare
  v_lines jsonb := '[]'::jsonb;
  v_currency_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_foreign_total numeric(12, 2);
  v_currency_code text := 'BDT';
  v_currency_symbol text := '৳';
  v_weight_kg numeric(12, 3);
  v_fallback_amount numeric(12, 2);
  v_mixed_currencies boolean := false;
  v_bill_amount numeric(12, 2) := 0;
  v_result jsonb;
begin
  select coalesce(def_cur.code, 'BDT'), coalesce(def_cur.symbol, def_cur.code, '৳')
  into v_currency_code, v_currency_symbol
  from public.global_currencies def_cur
  where def_cur.id = coalesce(p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id);

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'currency_code', g.currency_code,
          'currency_symbol', g.currency_symbol,
          'foreign_total', g.foreign_total,
          'lines', g.lines
        )
        order by g.currency_code
      )
      from (
        select
          coalesce(line_cur.code, v_currency_code) as currency_code,
          coalesce(line_cur.symbol, line_cur.code, v_currency_symbol) as currency_symbol,
          sum(round(e.amount, 2)) as foreign_total,
          jsonb_agg(
            jsonb_build_object(
              'description', coalesce(
                nullif(trim(e.description), ''),
                nullif(trim(e.metadata->>'description'), ''),
                initcap(replace(e.cost_component::text, '_', ' '))
              ),
              'amount', round(e.amount, 2),
              'currency_code', coalesce(line_cur.code, v_currency_code),
              'currency_symbol', coalesce(line_cur.symbol, line_cur.code, v_currency_symbol)
            )
            order by
              case e.cost_component
                when 'subtotal'::public.global_shipment_cost_component then 1
                when 'carriage'::public.global_shipment_cost_component then 2
                when 'vat_tax'::public.global_shipment_cost_component then 3
                when 'misc'::public.global_shipment_cost_component then 4
                else 5
              end,
              e.id desc
          ) as lines
        from public.global_shipment_cost_entries e
        left join public.global_currencies line_cur
          on line_cur.id = coalesce(e.currency_id, p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id)
        where e.shipment_id = p_shipment_id
          and e.cost_bucket = p_bucket
          and coalesce(e.amount, 0) > 0
        group by
          coalesce(line_cur.code, v_currency_code),
          coalesce(line_cur.symbol, line_cur.code, v_currency_symbol)
      ) g
    ),
    '[]'::jsonb
  )
  into v_currency_groups;

  v_group_count := jsonb_array_length(coalesce(v_currency_groups, '[]'::jsonb));
  v_mixed_currencies := v_group_count > 1;

  select coalesce(
    (
      select jsonb_agg(line_elm order by (line_elm->>'currency_code'), (line_elm->>'description'))
      from (
        select jsonb_array_elements(g.elem->'lines') as line_elm
        from jsonb_array_elements(coalesce(v_currency_groups, '[]'::jsonb)) as g(elem)
      ) flat
    ),
    '[]'::jsonb
  )
  into v_lines;

  if v_group_count = 1 then
    v_foreign_total := (v_currency_groups->0->>'foreign_total')::numeric;
    v_currency_code := v_currency_groups->0->>'currency_code';
    v_currency_symbol := v_currency_groups->0->>'currency_symbol';
    v_bill_amount := coalesce(v_foreign_total, 0);
  elsif v_group_count > 1 then
    v_foreign_total := null;
    select coalesce(sum((g.elem->>'foreign_total')::numeric), 0)
    into v_bill_amount
    from jsonb_array_elements(v_currency_groups) as g(elem);
  else
    v_foreign_total := 0;
    v_bill_amount := 0;
  end if;

  if v_bill_amount = 0 and p_bucket = 'material'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.purchase_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
      v_foreign_total := v_fallback_amount;
      v_bill_amount := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Product subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
      v_currency_groups := jsonb_build_array(
        jsonb_build_object(
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol,
          'foreign_total', v_fallback_amount,
          'lines', v_lines
        )
      );
      v_group_count := 1;
      v_mixed_currencies := false;
    end if;
  elsif v_bill_amount = 0 and p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.cargo_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
      v_foreign_total := v_fallback_amount;
      v_bill_amount := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Freight subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
      v_currency_groups := jsonb_build_array(
        jsonb_build_object(
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol,
          'foreign_total', v_fallback_amount,
          'lines', v_lines
        )
      );
      v_group_count := 1;
      v_mixed_currencies := false;
    end if;
  end if;

  v_result := jsonb_build_object(
    'paper', p_bucket::text,
    'lines', coalesce(v_lines, '[]'::jsonb),
    'currency_groups', coalesce(v_currency_groups, '[]'::jsonb),
    'mixed_currencies', v_mixed_currencies,
    'foreign_total', v_foreign_total,
    'currency_code', v_currency_code,
    'currency_symbol', v_currency_symbol,
    'bdt_amount', case
      when upper(coalesce(v_currency_code, 'BDT')) in ('', 'BDT') then coalesce(v_foreign_total, v_bill_amount)
      else null
    end
  );

  if p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_weight_kg := coalesce(p_ship.total_weight_kg, p_ship.received_weight, 0);
    v_result := v_result || jsonb_build_object('weight_kg', v_weight_kg);
  end if;

  return v_result;
end;
$$;

ALTER FUNCTION "public"."_build_shipment_ap_bucket_paper"("p_shipment_id" bigint, "p_ship" "public"."global_shipments", "p_bucket" "public"."global_shipment_cost_bucket") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric, "p_ap_paper" "jsonb" DEFAULT NULL::"jsonb", "p_keep_as_draft" boolean DEFAULT false) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select * into v_bill
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (
        b.source_type = 'shipment_cost'
        and b.source_id = p_shipment_id::text
        and b.source_key = p_ap_kind
      )
      or (b.ap_shipment_id = p_shipment_id and b.ap_kind = p_ap_kind)
    )
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status in (
         'issued'::public.global_invoice_status,
         'draft'::public.global_invoice_status
       ) then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_kind_label := initcap(replace(p_ap_kind, '_', ' '));
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(p_issued_by_tenant_id, 'ap'::public.global_invoice_type, current_date);
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      p_parent_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind, 'shipment_cost', p_shipment_id::text, p_ap_kind, 'BDT',
      format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      v_meta_base,
      'standard'::public.bill_document_kind
    )
    returning id into v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return v_bill.id;
    end if;

    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = p_profile_id,
      subtotal_amount = v_target,
      total_amount = v_target,
      due_amount = v_target,
      payment_status = 'due',
      source_type = coalesce(source_type, 'shipment_cost'),
      source_id = coalesce(source_id, p_shipment_id::text),
      source_key = coalesce(source_key, p_ap_kind),
      currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT'),
      note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      channel_meta = coalesce(channel_meta, '{}'::jsonb)
        || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
        || case
          when p_ap_paper is not null then jsonb_build_object('ap_paper', p_ap_paper)
          else '{}'::jsonb
        end,
      updated_at = now()
    where id = v_bill.id;

    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  v_target := greatest(v_target, coalesce(v_bill.paid_amount, 0));
  v_due := greatest(v_target - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = p_profile_id,
    subtotal_amount = v_target,
    total_amount = v_target,
    due_amount = v_due,
    payment_status = v_status,
    source_type = coalesce(source_type, 'shipment_cost'),
    source_id = coalesce(source_id, p_shipment_id::text),
    source_key = coalesce(source_key, p_ap_kind),
    currency_code = coalesce(nullif(trim(currency_code), ''), 'BDT'),
    note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
    channel_meta = coalesce(channel_meta, '{}'::jsonb)
      || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
      || case
        when p_ap_paper is not null and coalesce(v_bill.paid_amount, 0) = 0
        then jsonb_build_object('ap_paper', p_ap_paper)
        else '{}'::jsonb
      end,
    updated_at = now()
  where id = v_bill.id;

  perform public.stamp_bill_kernel_fields(v_bill.id);
  return v_bill.id;
end;
$$;

ALTER FUNCTION "public"."_upsert_shipment_ap_bill"("p_parent_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric, "p_ap_paper" "jsonb", "p_keep_as_draft" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."upsert_dropship_courier_ap_bill"("p_order_id" bigint, "p_keep_as_draft" boolean DEFAULT false) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_parent_tenant_id bigint;
  v_profile_id bigint;
  v_bill public.bills;
  v_amount numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_paper_status public.global_invoice_status;
  v_courier public.courier_services;
  v_tenant_name text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required');
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select * into v_courier
  from public.courier_services cs
  where cs.id = v_order.courier_service_id;

  if v_courier.id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required');
  end if;

  select t.name into v_tenant_name
  from public.tenants t
  where t.id = v_order.tenant_id;

  perform public.upsert_profile_for_party(
    v_parent_tenant_id,
    'tenant'::public.profile_party_type,
    v_order.tenant_id,
    coalesce(v_tenant_name, 'Tenant'),
    null,
    null,
    '+880',
    null,
    false,
    null,
    true,
    null
  );

  select p.id into v_profile_id
  from public.profiles p
  where p.parent_tenant_id = v_parent_tenant_id
    and p.profile_type = 'courier'::public.profile_party_type
    and p.subject_id = v_courier.wallet_entity_id
  limit 1;

  if v_profile_id is null then
    v_profile_id := public.upsert_profile_for_party(
      v_parent_tenant_id,
      'courier'::public.profile_party_type,
      v_courier.wallet_entity_id,
      v_courier.name,
      null,
      null,
      '+880',
      null,
      false,
      null,
      coalesce(v_courier.is_active, true),
      null
    );
  end if;

  if v_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'courier profile is required');
  end if;

  v_amount := round(
    coalesce(
      nullif(
        coalesce(v_order.delivery_charge_amount, 0) + coalesce(v_order.cod_charge_amount, 0),
        0
      ),
      nullif(v_order.courier_cost_amount, 0),
      nullif(v_courier.inside_dhaka_fee, 0),
      0
    ),
    2
  );

  select * into v_bill
  from public.bills b
  where b.parent_tenant_id = v_parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
  for update;

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(
      v_order.tenant_id,
      'ap'::public.global_invoice_type,
      current_date
    );
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      v_parent_tenant_id, v_order.tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, v_profile_id, 'profile'::public.collection_source_type, 'due',
      v_amount, v_amount, v_amount, 0,
      'dropship_courier', p_order_id::text, 'courier', 'BDT',
      format('Dropship order %s — courier AP', v_order.order_no),
      jsonb_build_object(
        'shop_order_id', p_order_id,
        'courier_service_id', v_order.courier_service_id,
        'delivery_charge_amount', v_order.delivery_charge_amount,
        'cod_charge_amount', v_order.cod_charge_amount,
        'courier_cost_amount', v_order.courier_cost_amount
      ),
      'standard'::public.bill_document_kind
    )
    returning * into v_bill;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'created', true, 'amount', v_amount);
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true);
    end if;
    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = v_profile_id,
      source_type = 'dropship_courier',
      source_id = p_order_id::text,
      source_key = 'courier',
      subtotal_amount = v_amount,
      total_amount = v_amount,
      due_amount = v_amount,
      payment_status = 'due',
      note = format('Dropship order %s — courier AP', v_order.order_no),
      channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object(
        'shop_order_id', p_order_id,
        'courier_service_id', v_order.courier_service_id,
        'delivery_charge_amount', v_order.delivery_charge_amount,
        'cod_charge_amount', v_order.cod_charge_amount,
        'courier_cost_amount', v_order.courier_cost_amount
      ),
      updated_at = now()
    where id = v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'revived', true, 'amount', v_amount);
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status then
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true, 'amount', v_bill.total_amount);
  end if;

  if coalesce(v_bill.paid_amount, 0) > 0 then
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true, 'amount', v_bill.total_amount);
  end if;

  v_due := greatest(v_amount - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = v_profile_id,
    source_type = 'dropship_courier',
    source_id = p_order_id::text,
    source_key = 'courier',
    subtotal_amount = v_amount,
    total_amount = v_amount,
    due_amount = v_due,
    payment_status = v_status,
    invoice_status = case
      when invoice_status = 'issued'::public.global_invoice_status then invoice_status
      else v_paper_status
    end,
    note = format('Dropship order %s — courier AP', v_order.order_no),
    channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object(
      'shop_order_id', p_order_id,
      'courier_service_id', v_order.courier_service_id,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'cod_charge_amount', v_order.cod_charge_amount,
      'courier_cost_amount', v_order.courier_cost_amount
    ),
    updated_at = now()
  where id = v_bill.id;

  perform public.stamp_bill_kernel_fields(v_bill.id);
  return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'amount', v_amount);
end;
$$;

ALTER FUNCTION "public"."upsert_dropship_courier_ap_bill"("p_order_id" bigint, "p_keep_as_draft" boolean) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_ar public.bills;
  v_ap public.bills;
  v_charges record;
  v_ar_bal jsonb;
  v_ap_bal jsonb;
  v_net_ar numeric(12, 2);
  v_net_ap numeric(12, 2);
  v_old_ar_charges numeric(12, 2);
  v_wanted_ar numeric(12, 2);
  v_wanted_ap numeric(12, 2);
  v_diff numeric(12, 2);
  v_reason text;
  v_parts text[] := array[]::text[];
  v_ar_adj jsonb;
  v_ap_adj jsonb;
  v_parent_tenant_id bigint;
  v_has_adjustments boolean := false;
  v_courier_name text;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice is required');
  end if;

  select * into v_ar from public.bills where id = v_order.global_invoice_id;
  if v_ar.id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice not found');
  end if;

  if v_ar.invoice_status <> 'issued'::public.global_invoice_status then
    return jsonb_build_object(
      'success', true,
      'has_adjustments', false,
      'skipped', true,
      'reason', 'customer invoice not issued'
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select * into v_ap
  from public.bills b
  where b.parent_tenant_id = v_parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
    and b.invoice_status <> 'voided'::public.global_invoice_status
  order by b.id
  limit 1;

  if v_order.courier_service_id is not null then
    select cs.name into v_courier_name
    from public.courier_services cs
    where cs.id = v_order.courier_service_id;
  end if;

  select * into v_charges from public.get_dropship_merchant_billable_charges(p_order_id);

  v_ar_bal := public.get_bill_net_balances(v_ar.id);
  v_net_ar := round(
    coalesce((v_ar_bal->>'original_total')::numeric, 0)
    + coalesce((v_ar_bal->>'debits_issued')::numeric, 0)
    - coalesce((v_ar_bal->>'credits_issued')::numeric, 0),
    2
  );

  v_old_ar_charges := round(
    coalesce(v_ar.shipping_charge, 0)
    + coalesce(v_ar.print_charge, 0)
    + coalesce(v_ar.wrapping_charge, 0)
    + coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
    2
  );

  v_wanted_ar := round(
    v_net_ar
    - v_old_ar_charges
    + coalesce(v_charges.delivery, 0)
    + coalesce(v_charges.print, 0)
    + coalesce(v_charges.packing, 0)
    + coalesce(v_charges.cod, 0),
    2
  );

  v_diff := round(v_wanted_ar - v_net_ar, 2);

  if abs(v_diff) >= 0.01 then
    v_parts := array[]::text[];
    if coalesce(v_charges.delivery, 0) is distinct from coalesce(v_ar.shipping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Delivery %s→%s', coalesce(v_ar.shipping_charge, 0), coalesce(v_charges.delivery, 0))
      );
    end if;
    if coalesce(v_charges.print, 0) is distinct from coalesce(v_ar.print_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Print %s→%s', coalesce(v_ar.print_charge, 0), coalesce(v_charges.print, 0))
      );
    end if;
    if coalesce(v_charges.packing, 0) is distinct from coalesce(v_ar.wrapping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Packing %s→%s', coalesce(v_ar.wrapping_charge, 0), coalesce(v_charges.packing, 0))
      );
    end if;
    if coalesce(v_charges.cod, 0) is distinct from coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0) then
      v_parts := array_append(
        v_parts,
        format(
          'Courier COD fee %s→%s',
          coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
          coalesce(v_charges.cod, 0)
        )
      );
    end if;

    v_reason := format(
      'Dropship %s at deliver: %s',
      v_order.order_no,
      coalesce(array_to_string(v_parts, '; '), 'charge adjustment')
    );

    v_ar_adj := jsonb_build_object(
      'bill_id', v_ar.id,
      'invoice_no', v_ar.invoice_no,
      'display_name', coalesce(nullif(trim(v_ar.recipient_name), ''), 'End customer'),
      'invoice_type', v_ar.invoice_type::text,
      'label', 'customer_invoice',
      'adjustment_kind', case when v_diff > 0 then 'debit_note' else 'credit_note' end,
      'amount', abs(v_diff),
      'current_net', v_net_ar,
      'wanted_net', v_wanted_ar,
      'reason', v_reason,
      'detail_parts', to_jsonb(v_parts)
    );
    v_has_adjustments := true;
  end if;

  if v_ap.id is not null and v_ap.invoice_status = 'issued'::public.global_invoice_status then
    v_wanted_ap := round(
      coalesce(v_order.delivery_charge_amount, 0) + coalesce(v_order.cod_charge_amount, 0),
      2
    );

    v_ap_bal := public.get_bill_net_balances(v_ap.id);
    v_net_ap := round(
      coalesce((v_ap_bal->>'original_total')::numeric, 0)
      + coalesce((v_ap_bal->>'debits_issued')::numeric, 0)
      - coalesce((v_ap_bal->>'credits_issued')::numeric, 0),
      2
    );

    v_diff := round(v_wanted_ap - v_net_ap, 2);

    if abs(v_diff) >= 0.01 then
      v_parts := array[]::text[];
      if coalesce(v_order.delivery_charge_amount, 0) is distinct from coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Delivery %s→%s',
            coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0),
            coalesce(v_order.delivery_charge_amount, 0)
          )
        );
      end if;
      if coalesce(v_order.cod_charge_amount, 0) is distinct from coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Courier COD fee %s→%s',
            coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0),
            coalesce(v_order.cod_charge_amount, 0)
          )
        );
      end if;

      v_reason := format(
        'Dropship %s at deliver: %s',
        v_order.order_no,
        coalesce(array_to_string(v_parts, '; '), 'courier charge adjustment')
      );

      v_ap_adj := jsonb_build_object(
        'bill_id', v_ap.id,
        'invoice_no', v_ap.invoice_no,
        'display_name', coalesce(v_courier_name, nullif(trim(v_ap.recipient_name), ''), 'Courier'),
        'invoice_type', v_ap.invoice_type::text,
        'label', 'courier_ap',
        'adjustment_kind', case when v_diff > 0 then 'debit_note' else 'credit_note' end,
        'amount', abs(v_diff),
        'current_net', v_net_ap,
        'wanted_net', v_wanted_ap,
        'reason', v_reason,
        'detail_parts', to_jsonb(v_parts)
      );
      v_has_adjustments := true;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'has_adjustments', v_has_adjustments,
    'customer_invoice', v_ar_adj,
    'courier_ap', v_ap_adj
  );
end;
$$;

ALTER FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  return public.preview_dropship_issued_bill_notes_at_deliver(p_order_id);
end;
$$;

ALTER FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver_for_staff"("p_tenant_id" bigint, "p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."apply_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_plan jsonb;
  v_ar_adj jsonb;
  v_ap_adj jsonb;
  v_note public.bills;
  v_ar_note_id bigint;
  v_ap_note_id bigint;
begin
  v_plan := public.preview_dropship_issued_bill_notes_at_deliver(p_order_id);
  if coalesce(v_plan->>'success', 'false') <> 'true' then
    return v_plan;
  end if;

  if coalesce(v_plan->>'skipped', 'false') = 'true' then
    return jsonb_build_object('success', true, 'skipped', true, 'reason', v_plan->>'reason');
  end if;

  v_ar_adj := v_plan->'customer_invoice';
  if v_ar_adj is not null and v_ar_adj <> 'null'::jsonb then
    perform 1 from public.bills where id = (v_ar_adj->>'bill_id')::bigint for update;
    v_note := public.create_bill_adjustment(
      (v_ar_adj->>'bill_id')::bigint,
      v_ar_adj->>'adjustment_kind',
      (v_ar_adj->>'amount')::numeric,
      v_ar_adj->>'reason',
      true
    );
    v_ar_note_id := v_note.id;
  end if;

  v_ap_adj := v_plan->'courier_ap';
  if v_ap_adj is not null and v_ap_adj <> 'null'::jsonb then
    perform 1 from public.bills where id = (v_ap_adj->>'bill_id')::bigint for update;
    v_note := public.create_bill_adjustment(
      (v_ap_adj->>'bill_id')::bigint,
      v_ap_adj->>'adjustment_kind',
      (v_ap_adj->>'amount')::numeric,
      v_ap_adj->>'reason',
      true
    );
    v_ap_note_id := v_note.id;
  end if;

  return jsonb_build_object(
    'success', true,
    'customer_invoice_id', (v_ar_adj->>'bill_id')::bigint,
    'customer_note_id', v_ar_note_id,
    'courier_ap_bill_id', (v_ap_adj->>'bill_id')::bigint,
    'courier_note_id', v_ap_note_id,
    'has_adjustments', coalesce(v_plan->>'has_adjustments', 'false') = 'true'
  );
end;
$$;

ALTER FUNCTION "public"."apply_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."finalize_dropship_order_bills_at_delivered"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_sync jsonb;
  v_ap jsonb;
  v_notes jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice is required before deliver');
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'linked customer invoice not found');
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'issued'::public.global_invoice_status
  ) then
    return jsonb_build_object(
      'success', false,
      'error', format('customer invoice must be draft or issued (current: %s)', v_invoice.invoice_status)
    );
  end if;

  if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
    v_sync := public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id);
    if coalesce(v_sync->>'success', 'false') <> 'true' then
      return v_sync;
    end if;
  end if;

  v_ap := public.upsert_dropship_courier_ap_bill(p_order_id, false);
  if coalesce(v_ap->>'success', 'false') <> 'true' then
    return v_ap;
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id;
  if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
    perform public.post_sales_invoice(v_invoice.id);
    perform public.sync_sales_invoice_charges_from_header(v_invoice.id);
  end if;

  update public.bills b
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where b.parent_tenant_id = v_invoice.parent_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and (
      (b.source_type = 'dropship_courier' and b.source_id = p_order_id::text)
      or (
        b.source_type = 'shop_order'
        and b.source_id = p_order_id::text
        and coalesce(b.source_key, '') = 'courier'
      )
    )
    and b.invoice_status = 'draft'::public.global_invoice_status;

  v_notes := public.apply_dropship_issued_bill_notes_at_deliver(p_order_id);
  if coalesce(v_notes->>'success', 'false') <> 'true' then
    return v_notes;
  end if;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'courier_ap_bill_id', (v_ap->>'bill_id')::bigint,
    'bill_notes', v_notes
  );
end;
$$;

ALTER FUNCTION "public"."finalize_dropship_order_bills_at_delivered"("p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_shipment_ap_bills"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
  v_count integer := 0;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills b
  set invoice_status = 'issued'::public.global_invoice_status, updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;


ALTER FUNCTION "public"."issue_shipment_ap_bills"("p_shipment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."issue_shipment_ap_bill_for_kind"("p_shipment_id" bigint, "p_ap_kind" "text") RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent bigint;
  v_bill_id bigint;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  if p_ap_kind is null or trim(p_ap_kind) = '' then
    raise exception 'ap_kind is required';
  end if;

  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select gs.parent_tenant_id into v_parent
  from public.global_shipments gs
  where gs.id = p_shipment_id;

  if v_parent is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  update public.bills b
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(b.payment_status, ''), 'due'),
    source_type = coalesce(b.source_type, 'shipment_cost'),
    source_id = coalesce(b.source_id, p_shipment_id::text),
    source_key = coalesce(b.source_key, p_ap_kind),
    updated_at = now()
  where b.parent_tenant_id = v_parent
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0
    and (
      (
        b.source_type = 'shipment_cost'
        and b.source_id = p_shipment_id::text
        and b.source_key = p_ap_kind
      )
      or (b.ap_shipment_id = p_shipment_id and b.ap_kind = p_ap_kind)
    )
  returning b.id into v_bill_id;

  if v_bill_id is null then
    raise exception 'No draft AP bill to issue for bucket %', p_ap_kind;
  end if;

  return v_bill_id;
end;
$$;


ALTER FUNCTION "public"."issue_shipment_ap_bill_for_kind"("p_shipment_id" bigint, "p_ap_kind" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_tenant_name text;
  v_bucket public.global_shipment_cost_bucket;
  v_bucket_text text;
  v_paper jsonb;
  v_amt numeric(12, 2);
  v_profile bigint;
  v_bill_id bigint;
  v_bills jsonb := '{}'::jsonb;
  v_keep_as_draft boolean := false;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := v_ship.parent_tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'cargo'::public.profile_party_type
      and pr.subject_id = v_ship.cargo_company_id;
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_parent;

  v_local_profile := public.upsert_profile_for_party(
    v_parent,
    'company'::public.profile_party_type,
    v_parent,
    coalesce(v_tenant_name, 'Local opex'),
    null, null, '+880', null, false, null, true, null
  );

  v_keep_as_draft := not coalesce(v_ship.costs_locked, false);

  if v_ship.status = 'cancelled' then
    update public.bills
    set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
    where parent_tenant_id = v_parent
      and ap_shipment_id = p_shipment_id
      and invoice_type = 'ap'::public.global_invoice_type
      and document_kind = 'standard'::public.bill_document_kind
      and invoice_status in (
        'issued'::public.global_invoice_status,
        'draft'::public.global_invoice_status
      )
      and coalesce(paid_amount, 0) = 0;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_amt := coalesce(
      (v_paper->>'foreign_total')::numeric,
      (v_paper->>'bdt_amount')::numeric,
      0
    );

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    v_bill_id := public._upsert_shipment_ap_bill(
      v_parent,
      v_issued_by,
      p_shipment_id,
      v_ship.name,
      v_bucket::text,
      v_profile,
      v_amt,
      v_paper,
      v_keep_as_draft
    );

    if v_bill_id is not null then
      v_bills := v_bills || jsonb_build_object(v_bucket::text, v_bill_id);
    end if;
  end loop;

  update public.bills
  set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
  where parent_tenant_id = v_parent
    and ap_shipment_id = p_shipment_id
    and invoice_type = 'ap'::public.global_invoice_type
    and document_kind = 'standard'::public.bill_document_kind
    and ap_kind in ('vendor', 'cargo', 'local')
    and invoice_status = 'issued'::public.global_invoice_status
    and coalesce(paid_amount, 0) = 0;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;

ALTER FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."ap_bill_channel_foreign_face"("p_channel_meta" "jsonb") RETURNS numeric
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select coalesce(
    nullif((p_channel_meta->'ap_paper'->>'foreign_total')::numeric, 0),
    nullif((p_channel_meta->'ap_paper'->'currency_groups'->0->>'foreign_total')::numeric, 0)
  );
$$;

ALTER FUNCTION "public"."ap_bill_channel_foreign_face"("p_channel_meta" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."ap_bill_channel_currency"("p_channel_meta" "jsonb") RETURNS "text"
    LANGUAGE "sql" IMMUTABLE
    AS $$
  select upper(coalesce(
    nullif(trim(p_channel_meta->'ap_paper'->>'currency_code'), ''),
    nullif(trim(p_channel_meta->'ap_paper'->'currency_groups'->0->>'currency_code'), ''),
    'BDT'
  ));
$$;

ALTER FUNCTION "public"."ap_bill_channel_currency"("p_channel_meta" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."shipment_ap_bucket_paid_totals"("p_shipment_id" bigint, "p_ap_kind" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bdt numeric := 0;
  v_foreign numeric := 0;
  v_count integer := 0;
  v_rate numeric := 1;
begin
  if p_shipment_id is null or nullif(trim(coalesce(p_ap_kind, '')), '') is null then
    return jsonb_build_object(
      'bdt_paid', 0,
      'foreign_paid', 0,
      'conversion_rate', 1,
      'payment_count', 0
    );
  end if;

  -- pay_allocations.amount is books (BDT). Foreign paid = BDT ÷ pay rate on FX payouts.
  select
    coalesce(sum(round(pa.amount, 2)), 0),
    coalesce(sum(
      round(
        case
          when coalesce(p.exchange_rate, 0) > 0
               and upper(coalesce(p.settlement_currency_code, 'BDT')) <> 'BDT' then
            pa.amount / p.exchange_rate
          else pa.amount
        end,
        2
      )
    ), 0),
    count(distinct p.id)::integer
  into v_bdt, v_foreign, v_count
  from public.bills b
  inner join public.pay_allocations pa on pa.global_invoice_id = b.id
  inner join public.pays p on p.id = pa.payment_id
  where b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.ap_kind = p_ap_kind
    and p.voided_at is null;

  if v_foreign > 0 then
    v_rate := round(v_bdt / v_foreign, 6);
  end if;

  return jsonb_build_object(
    'bdt_paid', v_bdt,
    'foreign_paid', v_foreign,
    'conversion_rate', v_rate,
    'payment_count', v_count
  );
end;
$$;

ALTER FUNCTION "public"."shipment_ap_bucket_paid_totals"("p_shipment_id" bigint, "p_ap_kind" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "public"."pays"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_received_on date := coalesce(p_paid_on, current_date);
  v_note text := nullif(trim(coalesce(p_note, '')), '');
  v_reference text := nullif(trim(coalesce(p_reference, '')), '');
  v_pay public.pays;
  v_line record;
  v_method_code text;
  v_line_amount numeric(12, 2);
  v_line_count int := 0;
  v_amount numeric(12, 2) := 0.00;
  v_header_method text;
  v_alloc jsonb;
  v_bill public.bills;
  v_bill_id bigint;
  v_alloc_amount numeric(12, 2);
  v_total_alloc numeric(12, 2) := 0.00;
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_leftover numeric(12, 2);
  v_channel_meta jsonb;
  v_foreign_face numeric(12, 2);
  v_paper_currency text;
  v_effective_due numeric(12, 2);
  v_paper jsonb;
  v_books_total numeric(12, 2);
  v_source_currency text;
  v_transaction_rate numeric(15, 6) := 1.000000;
  v_source_amount numeric(12, 2);
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_payment_face numeric(12, 2);
  v_base_currency text := 'BDT';
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent_id)
    or public.membership_has_module_action(p_tenant_id, 'payments', 'collect_payment')
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: cannot record AP payouts for this tenant';
  end if;

  if not exists (
    select 1 from public.profiles pr
    where pr.id = p_profile_id and pr.parent_tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_profile_id;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for this pay out';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_parent_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_parent_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  if coalesce(jsonb_typeof(p_instruments), 'null') = 'array' then
    for v_line in select value from jsonb_array_elements(p_instruments)
    loop
      v_line_amount := round(coalesce((v_line.value ->> 'amount')::numeric, 0.00), 2);
      if v_line_amount <= 0 then
        continue;
      end if;
      v_method_code := upper(trim(coalesce(v_line.value ->> 'payment_method_code', '')));
      v_amount := v_amount + v_line_amount;
      v_line_count := v_line_count + 1;
      if v_line_count = 1 then
        v_header_method := lower(v_method_code);
      else
        v_header_method := 'split';
      end if;
    end loop;
  end if;

  if v_line_count = 0 then
    raise exception 'Enter at least one payment line';
  end if;

  if v_header_method is not null and v_header_method not in (
    'cash', 'bank', 'bank_transfer', 'mobile_banking', 'bkash', 'nagad', 'other', 'cheque', 'rocket',
    'upay', 'tap', 'card_pos', 'wire_transfer', 'paypal', 'stripe', 'letter_of_credit', 'cod', 'split'
  ) then
    v_header_method := 'other';
  end if;

  select n.settlement_currency_code, n.foreign_amount, n.exchange_rate, n.amount_bdt
  into v_settle_currency, v_foreign_amt, v_fx_rate, v_amount
  from public.normalize_pay_settlement_fx(
    v_amount,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    v_base_currency
  ) n;

  v_source_currency := upper(trim(coalesce(p_source_currency_code, '')));
  if v_source_currency = '' then
    select upper(cpp.currency_code)
    into v_source_currency
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_id
      and upper(cpp.currency_code) = v_source_currency
    limit 1;
  end if;

  if upper(v_settle_currency) = v_source_currency then
    v_transaction_rate := 1.000000;
  else
    v_transaction_rate := coalesce(p_transaction_rate, 0);
    if v_transaction_rate <= 0 then
      raise exception 'transaction_rate required when source currency (%) differs from payment currency (%)',
        v_source_currency, v_settle_currency;
    end if;
  end if;

  if upper(v_settle_currency) = v_base_currency then
    v_payment_face := v_amount;
  else
    v_payment_face := coalesce(v_foreign_amt, 0);
  end if;

  v_source_amount := round(v_payment_face * v_transaction_rate, 2);

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note,
    settlement_currency_code, foreign_amount, exchange_rate, quote_currency_code, cashbook_point_id,
    source_currency_code, transaction_rate, source_amount, cashbook_point_pot_id
  ) values (
    v_parent_id, p_profile_id, 'ap_payout', v_amount, 0,
    v_received_on, v_header_method, v_reference, v_note,
    v_settle_currency, v_foreign_amt, v_fx_rate, v_base_currency, p_cashbook_point_id,
    v_source_currency, v_transaction_rate, v_source_amount, v_pot_id
  ) returning * into v_pay;

  perform public.insert_global_payment_instruments(v_pay.id, p_instruments);

  update public.pay_instruments pi
  set cashbook_point_id = coalesce(pi.cashbook_point_id, p_cashbook_point_id)
  where pi.payment_id = v_pay.id;

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    for v_alloc in select value from jsonb_array_elements(p_allocations)
    loop
      v_bill_id := coalesce(nullif(v_alloc ->> 'bill_id', '')::bigint, nullif(v_alloc ->> 'invoice_id', '')::bigint);
      v_alloc_amount := round(coalesce((v_alloc ->> 'amount')::numeric, 0.00), 2);
      if v_bill_id is null or v_alloc_amount <= 0 then
        continue;
      end if;

      select * into v_bill from public.bills where id = v_bill_id for update;
      if v_bill.id is null then
        raise exception 'Bill % not found', v_bill_id;
      end if;
      if v_bill.parent_tenant_id <> v_parent_id then
        raise exception 'Bill % belongs to other books', v_bill_id;
      end if;
      if v_bill.invoice_type <> 'ap'::public.global_invoice_type then
        raise exception 'Bill % is not AP', v_bill.invoice_no;
      end if;
      if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
        raise exception 'Bill % is not issued', v_bill.invoice_no;
      end if;
      if v_bill.profile_id is distinct from p_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;

      v_channel_meta := coalesce(v_bill.channel_meta, '{}'::jsonb);
      v_foreign_face := public.ap_bill_channel_foreign_face(v_channel_meta);
      v_paper_currency := public.ap_bill_channel_currency(v_channel_meta);

      if upper(v_settle_currency) <> v_base_currency
         and v_fx_rate > 0
         and v_foreign_face is not null
         and v_foreign_face > 0
         and upper(coalesce(v_paper_currency, v_base_currency)) <> v_base_currency
      then
        if v_alloc_amount <= v_foreign_face + 0.01
           and v_alloc_amount < v_amount * 0.99
        then
          v_alloc_amount := round(v_alloc_amount * v_fx_rate, 2);
        end if;

        if abs(coalesce(v_bill.due_amount, 0) - v_foreign_face) < 0.02 then
          v_effective_due := round(v_foreign_face * v_fx_rate, 2);
        else
          v_effective_due := coalesce(v_bill.due_amount, 0);
        end if;
      else
        v_effective_due := coalesce(v_bill.due_amount, 0);
      end if;

      if v_alloc_amount > v_effective_due then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_effective_due;
      end if;

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_bill_id, v_alloc_amount);

      perform public.recompute_global_invoice_payment_status(v_bill_id);
      v_total_alloc := v_total_alloc + v_alloc_amount;

      if upper(v_settle_currency) <> v_base_currency
         and v_fx_rate > 0
         and v_foreign_face is not null
         and v_foreign_face > 0
         and upper(coalesce(v_paper_currency, v_base_currency)) <> v_base_currency
      then
        v_books_total := round(v_foreign_face * v_fx_rate, 2);
        v_paper := coalesce(v_channel_meta->'ap_paper', '{}'::jsonb)
          || jsonb_build_object('conversion_rate', v_fx_rate, 'bdt_amount', v_books_total);
        update public.bills b
        set
          channel_meta = jsonb_set(coalesce(b.channel_meta, '{}'::jsonb), '{ap_paper}', v_paper),
          subtotal_amount = v_books_total,
          total_amount = v_books_total
        where b.id = v_bill_id;
        perform public.recompute_global_invoice_payment_status(v_bill_id);
      end if;

      if v_bill.ap_shipment_id is not null
         and not (v_bill.ap_shipment_id = any(v_shipment_ids)) then
        v_shipment_ids := array_append(v_shipment_ids, v_bill.ap_shipment_id);
      end if;
    end loop;
  end if;

  if v_total_alloc > v_amount then
    raise exception 'AP payout allocations (%) exceed payment amount (%)', v_total_alloc, v_amount;
  end if;

  v_leftover := v_amount - v_total_alloc;

  update public.pays
  set unallocated_amount = v_leftover
  where id = v_pay.id
  returning * into v_pay;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_id,
    p_type => 'debit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_pay.id::text,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'ap_payout',
      'transaction_type', 'ap_paid_out',
      'label', 'AP paid out',
      'payment_id', v_pay.id,
      'method', v_header_method,
      'reference', v_reference,
      'settlement_currency_code', v_settle_currency,
      'foreign_amount', v_foreign_amt,
      'exchange_rate', v_fx_rate,
      'source_currency_code', v_source_currency,
      'transaction_rate', v_transaction_rate,
      'source_amount', v_source_amount,
      'cashbook_point_pot_id', v_pot_id
    ),
    p_allow_overdraft => true,
    p_cashbook_point_id => p_cashbook_point_id
  );

  if coalesce(array_length(v_shipment_ids, 1), 0) > 0 then
    foreach v_sid in array v_shipment_ids
    loop
      perform public.refresh_global_shipment_fx_from_ap_payments(v_sid);
      perform public.stamp_global_shipment_landed_costs(v_sid);
    end loop;
  end if;

  return v_pay;
end;
$$;

ALTER FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text", "p_reference" "text", "p_instruments" "jsonb", "p_allocations" "jsonb", "p_settlement_currency_code" "text", "p_foreign_amount" numeric, "p_exchange_rate" numeric, "p_source_currency_code" "text", "p_transaction_rate" numeric, "p_cashbook_point_pot_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations_snapshot"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_pay public.pays;
  v_bill_id bigint;
begin
  v_pay := public.post_ap_payout_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cashbook_point_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    p_source_currency_code,
    p_transaction_rate,
    p_cashbook_point_pot_id
  );

  v_bill_id := null;
  if p_allocations is not null and jsonb_typeof(p_allocations) = 'array' then
    select (elem->>'bill_id')::bigint
    into v_bill_id
    from jsonb_array_elements(p_allocations) as elem
    where nullif(trim(elem->>'bill_id'), '') is not null
    limit 1;
  end if;

  if v_bill_id is null then
    return jsonb_build_object('pay', to_jsonb(v_pay));
  end if;

  return jsonb_build_object(
    'pay', to_jsonb(v_pay),
    'bill', (select to_jsonb(b) from public.bills b where b.id = v_bill_id),
    'net_balances', public.get_bill_net_balances(v_bill_id),
    'payment_history', public.list_invoice_payment_history(p_tenant_id, v_bill_id)
  );
end;
$$;

ALTER FUNCTION "public"."post_ap_payout_with_allocations_snapshot"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text", "p_reference" "text", "p_instruments" "jsonb", "p_allocations" "jsonb", "p_settlement_currency_code" "text", "p_foreign_amount" numeric, "p_exchange_rate" numeric, "p_source_currency_code" "text", "p_transaction_rate" numeric, "p_cashbook_point_pot_id" bigint) OWNER TO "postgres";

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
  v_invoice public.bills;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
  v_delivery_kind text;
  v_held_stock_id bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'only draft or proforma invoices can be posted/issued';
  end if;

  if not exists (select 1 from public.global_invoice_items where invoice_id = p_invoice_id) then
    raise exception 'cannot post an empty invoice';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  v_delivery_kind := lower(trim(coalesce(v_invoice.channel_meta->>'delivery_kind', 'take')));
  if v_delivery_kind not in ('take', 'condition') then
    v_delivery_kind := 'take';
  end if;

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type
     and v_delivery_kind = 'condition' then
    for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
      v_qty := ceil(v_item.quantity)::integer;

      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if v_stock.id is null then
        continue;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'insufficient stock quantity on stock % (requested %, available %)',
          v_item.global_stock_id, v_qty, v_stock.quantity;
      end if;

      if v_stock.availability = 'sellable'::public.stock_availability then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_id,
          p_stock_id => v_item.global_stock_id,
          p_quantity => v_qty,
          p_to_availability => 'held'::public.stock_availability,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Condition bill #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
          p_reference_type => 'sales_invoice',
          p_reference_id => p_invoice_id::text
        );

        select gs.id
        into v_held_stock_id
        from public.global_stocks gs
        where gs.shipment_item_id = v_stock.shipment_item_id
          and gs.availability = 'held'::public.stock_availability
          and gs.location_id = v_stock.location_id
          and gs.grade_tag_id = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
        order by gs.id desc
        limit 1;

        if v_held_stock_id is null then
          raise exception 'held stock not found after condition transfer for line %', v_item.id;
        end if;

        update public.bill_lines
        set global_stock_id = v_held_stock_id
        where id = v_item.id;
      elsif v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'condition bill stock % must be sellable or held (current: %)',
          v_item.global_stock_id, v_stock.availability;
      end if;
    end loop;
  else
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
        if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
           and v_stock.availability <> 'held'::public.stock_availability then
          raise exception 'dropship invoice stock % must be held before issue', v_item.global_stock_id;
        end if;

        if v_stock.quantity < v_qty then
          raise exception 'insufficient stock quantity on stock % (requested %, available %)',
            v_item.global_stock_id, v_qty, v_stock.quantity;
        end if;

        update public.global_stocks
        set quantity = quantity - v_qty
        where id = v_item.global_stock_id;

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
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status
  where id = p_invoice_id;

  if v_invoice.invoice_type = 'retail'::public.global_invoice_type
     and v_invoice.profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.cashbook_entries
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
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

CREATE OR REPLACE FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" "jsonb", "p_return_charge_amount" numeric DEFAULT 0, "p_refund_method" "text" DEFAULT NULL::"text", "p_payout_account_id" bigint DEFAULT NULL::bigint, "p_note" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item_elem jsonb;
  v_item_id bigint;
  v_return_qty numeric;
  v_to_availability public.stock_availability;
  v_to_grade_tag_id bigint;
  v_item_note text;
  v_db_item public.bill_lines%rowtype;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_total_return_value numeric(12,2) := 0.00;
  v_line_unit_price numeric(12,2);
  v_line_return_val numeric(12,2);
  v_new_subtotal numeric(12,2) := 0.00;
  v_charges numeric(12,2) := 0.00;
  v_discount numeric(12,2) := 0.00;
  v_paid numeric(12,2) := 0.00;
  v_new_total numeric(12,2) := 0.00;
  v_new_due numeric(12,2) := 0.00;
  v_excess_paid numeric(12,2) := 0.00;
  v_refund_amount numeric(12,2) := 0.00;
  v_return_count integer := 0;
  v_payout_id text;
  v_charge numeric(12,2) := 0.00;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Returns can only be processed on issued/posted invoices';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'At least one return item must be provided';
  end if;

  v_charge := greatest(coalesce(p_return_charge_amount, 0.00), 0.00);
  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  -- 1. Loop and process each return item
  for v_item_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_item_elem->>'invoice_item_id')::bigint;
    v_return_qty := (v_item_elem->>'quantity')::numeric;
    v_to_availability := coalesce(
      (v_item_elem->>'to_availability')::public.stock_availability,
      'held'::public.stock_availability
    );
    v_to_grade_tag_id := (v_item_elem->>'to_grade_tag_id')::bigint;
    v_item_note := nullif(trim(v_item_elem->>'note'), '');

    if v_item_id is null then
      raise exception 'invoice_item_id is required for all items';
    end if;

    if v_return_qty is null or v_return_qty <= 0 then
      continue; -- Skip 0 or empty quantity items
    end if;

    select * into v_db_item
    from public.bill_lines
    where id = v_item_id and invoice_id = p_invoice_id
    for update;

    if v_db_item.id is null then
      raise exception 'Invoice item % not found on this invoice', v_item_id;
    end if;

    if (v_db_item.return_quantity + v_return_qty) > v_db_item.quantity then
      raise exception 'Return quantity % exceeds available returnable quantity % for %',
        v_return_qty,
        (v_db_item.quantity - v_db_item.return_quantity),
        v_db_item.name_snapshot;
    end if;

    -- Calculate line return value
    v_line_unit_price := v_db_item.sell_price_amount;
    v_line_return_val := round(v_return_qty * v_line_unit_price, 2);
    v_total_return_value := v_total_return_value + v_line_return_val;

    -- Insert record into sales_return_items
    insert into public.sales_return_items (
      parent_tenant_id,
      invoice_id,
      invoice_item_id,
      global_stock_id,
      quantity,
      return_charge_amount,
      note
    ) values (
      v_parent_id,
      p_invoice_id,
      v_item_id,
      v_db_item.global_stock_id,
      v_return_qty,
      0.00,
      v_item_note
    );

    -- Update bill_lines cumulative return_quantity; sold quantity stays.
    -- line_total_amount is the net after return credit (kept qty × price − line discount).
    update public.bill_lines
    set
      return_quantity = return_quantity + v_return_qty,
      line_total_amount = greatest(
        (v_db_item.quantity - (v_db_item.return_quantity + v_return_qty)) * v_db_item.sell_price_amount
        - coalesce(v_db_item.line_discount_amount, 0),
        0
      ),
      updated_at = now()
    where id = v_item_id;

    -- Post return_inbound stock movement
    if v_db_item.global_stock_id is not null then
      perform public.create_and_post_stock_movement(
        p_tenant_id => v_parent_id,
        p_stock_id => v_db_item.global_stock_id,
        p_quantity => ceil(v_return_qty)::integer,
        p_to_location_id => public.default_returns_stock_location_id(v_parent_id),
        p_to_availability => v_to_availability,
        p_to_grade_tag_id => coalesce(v_to_grade_tag_id, public.default_stock_grade_tag_id()),
        p_movement_type => 'return_inbound'::public.stock_movement_type,
        p_notes => coalesce(v_item_note, 'Wholesale invoice return #' || coalesce(v_invoice.invoice_no, p_invoice_id::text)),
        p_reference_type => 'sales_invoice',
        p_reference_id => p_invoice_id::text
      );
    end if;

    v_return_count := v_return_count + 1;
  end loop;

  if v_return_count = 0 then
    raise exception 'No items with quantity > 0 were selected for return';
  end if;

  -- 2. Recalculate invoice totals based on retained quantities
  select coalesce(sum((quantity - return_quantity) * sell_price_amount - line_discount_amount), 0.00)
  into v_new_subtotal
  from public.bill_lines
  where invoice_id = p_invoice_id;

  v_charges := coalesce(v_invoice.shipping_charge, 0.00)
             + coalesce(v_invoice.wrapping_charge, 0.00)
             + coalesce(v_invoice.print_charge, 0.00)
             + v_charge; -- add return handling charge if any

  v_discount := coalesce(v_invoice.discount_amount, 0.00);
  v_paid := coalesce(v_invoice.paid_amount, 0.00);

  v_new_total := greatest(v_new_subtotal + v_charges - v_discount, 0.00);
  v_new_due := greatest(v_new_total - v_paid, 0.00);
  v_excess_paid := greatest(v_paid - v_new_total, 0.00);

  -- 3. Handle excess overpayment refund if applicable
  if v_excess_paid > 0.00 then
    if p_refund_method = 'wallet_credit' and v_invoice.profile_id is not null then
      -- Ensure wallet account exists
      insert into public.cashbook_accounts (
        tenant_id, entity_type, entity_id, currency_code,
        available_balance, locked_balance, pending_balance
      ) values (
        v_eff_tenant_id, 'customer', v_invoice.profile_id, 'BDT',
        0.0000, 0.0000, 0.0000
      ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

      -- Credit Customer Wallet via universal ledger
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
        p_type => 'credit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'sales_invoice_return',
        p_source_id => p_invoice_id::text,
        p_metadata => jsonb_build_object(
          'section', 'returns',
          'purpose', 'wholesale_return_wallet_credit',
          'transaction_type', 'return_credit',
          'label', 'Return Credit (Wallet)',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;

    elsif p_refund_method = 'payout' and v_invoice.profile_id is not null then
      v_payout_id := 'RET-PO-' || gen_random_uuid()::text;

      -- Payout: Debit Tenant Cash (cash outflow from business to customer)
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_eff_tenant_id,
        p_type => 'debit',
        p_amount => v_excess_paid,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payout_id,
        p_metadata => jsonb_build_object(
          'section', 'payout_earned',
          'purpose', 'wholesale_return_payout',
          'transaction_type', 'return_cash_payout',
          'label', 'Return Cash Payout',
          'invoice_id', p_invoice_id,
          'invoice_no', v_invoice.invoice_no,
          'profile_id', v_invoice.profile_id,
          'notes', p_note
        )
      );

      v_refund_amount := v_excess_paid;
    end if;
  end if;

  -- 4. Update bills header
  update public.bills
  set
    subtotal_amount = v_new_subtotal,
    total_amount = v_new_total,
    due_amount = v_new_due,
    payment_status = case
      when v_new_due <= 0.00 then 'paid'
      when v_paid > 0.00 and v_new_due > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = p_invoice_id
  returning * into v_invoice;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'new_subtotal', v_new_subtotal,
    'new_total', v_new_total,
    'new_due', v_new_due,
    'paid_amount', v_paid,
    'excess_paid', v_excess_paid,
    'refund_amount', v_refund_amount,
    'refund_method', p_refund_method,
    'payment_status', v_invoice.payment_status,
    'returned_items_count', v_return_count
  );
end;
$$;

ALTER FUNCTION "public"."process_wholesale_invoice_return"("p_invoice_id" bigint, "p_items" "jsonb", "p_return_charge_amount" numeric, "p_refund_method" "text", "p_payout_account_id" bigint, "p_note" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."recipient_profile_valid_for_issuer"("p_recipient_profile_id" bigint, "p_issued_by_tenant_id" bigint) RETURNS boolean
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select exists (
    select 1
    from public.recipient_profiles rp
    where rp.id = p_recipient_profile_id
      and (
        rp.tenant_id = p_issued_by_tenant_id
        or rp.tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or coalesce(rp.parent_tenant_id, rp.tenant_id)
          = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = rp.tenant_id
            and t.parent_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        )
      )
  );
$$;

ALTER FUNCTION "public"."recipient_profile_valid_for_issuer"("p_recipient_profile_id" bigint, "p_issued_by_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."recompute_global_invoice_payment_status"("p_global_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_root_id bigint;
  v_total numeric(12,2);
  v_paid numeric(12,2);
  v_written_off numeric(12,2);
  v_credits numeric(12,2);
  v_debits numeric(12,2);
  v_due numeric(12,2);
  v_parent_remaining numeric(12,2);
  v_child record;
  v_child_paid numeric(12,2);
  v_child_due numeric(12,2);
  v_child_total numeric(12,2);
begin
  select * into v_bill from public.bills where id = p_global_invoice_id;
  if not found then return; end if;

  v_root_id := coalesce(v_bill.parent_bill_id, v_bill.id);

  select * into v_bill from public.bills where id = v_root_id for update;
  if not found then return; end if;

  select coalesce(sum(amount), 0.00) into v_paid
  from public.pay_allocations where global_invoice_id = v_root_id;

  select coalesce(sum(amount), 0.00) into v_written_off
  from public.invoice_write_offs where invoice_id = v_root_id;

  select coalesce(sum(total_amount), 0.00) into v_credits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'credit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(sum(total_amount), 0.00) into v_debits
  from public.bills
  where parent_bill_id = v_root_id
    and document_kind = 'debit_note'::public.bill_document_kind
    and invoice_status = 'issued'::public.global_invoice_status;

  v_total := coalesce(v_bill.total_amount, 0.00);
  v_parent_remaining := greatest(v_total - v_paid - v_written_off, 0.00);
  v_due := greatest(v_parent_remaining - v_credits + v_debits, 0.00);

  update public.bills
  set
    paid_amount = v_paid,
    written_off_amount = v_written_off,
    due_amount = v_due,
    payment_status = case
      when v_due = 0.00 and v_written_off > 0.00 then 'settled_with_write_off'
      when v_due = 0.00 and v_paid > 0.00 then 'paid'
      when v_paid > 0.00 or v_written_off > 0.00 then 'partially_paid'
      else 'due'
    end,
    updated_at = now()
  where id = v_root_id;

  for v_child in
    select id, document_kind, total_amount, invoice_status
    from public.bills
    where parent_bill_id = v_root_id
    order by id
  loop
    select coalesce(sum(amount), 0.00) into v_child_paid
    from public.pay_allocations where global_invoice_id = v_child.id;

    v_child_total := coalesce(v_child.total_amount, 0.00);

    if v_child.invoice_status <> 'issued'::public.global_invoice_status then
      v_child_due := 0.00;
    else
      v_child_due := greatest(v_child_total - v_child_paid, 0.00);
    end if;

    update public.bills
    set
      paid_amount = v_child_paid,
      due_amount = v_child_due,
      payment_status = case
        when v_child.invoice_status = 'voided'::public.global_invoice_status then 'due'
        when v_child_total <= 0.00 then 'paid'
        when v_child_due <= 0.00 and v_child_paid > 0.00 then 'paid'
        when v_child_paid > 0.00 then 'partially_paid'
        else 'due'
      end,
      updated_at = now()
    where id = v_child.id;
  end loop;
end;
$$;

ALTER FUNCTION "public"."recompute_global_invoice_payment_status"("p_global_invoice_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."recompute_global_invoice_totals"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_subtotal numeric(12,2) := 0;
  v_charges numeric(12,2) := 0;
  v_discount numeric(12,2) := 0;
  v_paid numeric(12,2) := 0;
  v_total numeric(12,2) := 0;
begin
  select * into v_invoice from public.bills where id = p_invoice_id;
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

  update public.bills
  set
    subtotal_amount = v_subtotal,
    total_amount = v_total,
    due_amount = greatest(v_total - v_paid, 0),
    updated_at = now()
  where id = p_invoice_id;
end;
$$;

ALTER FUNCTION "public"."recompute_global_invoice_totals"("p_invoice_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."delete_cashbook_point_for_staff"("p_tenant_id" bigint, "p_point_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_point public.cashbook_points;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_point
  FROM public.cashbook_points cp
  WHERE cp.id = p_point_id
    AND cp.parent_tenant_id = v_books_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'cash point not found');
  END IF;

  UPDATE public.cashbook_entries
  SET cashbook_point_id = NULL
  WHERE cashbook_point_id = p_point_id;

  DELETE FROM public.cashbook_points
  WHERE id = p_point_id;

  RETURN jsonb_build_object('success', true, 'id', p_point_id);
END;
$$;

ALTER FUNCTION "public"."delete_cashbook_point_for_staff"("p_tenant_id" bigint, "p_point_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" "text" DEFAULT 'adjustment'::"text", "p_source_id" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_target_bucket" "text" DEFAULT 'available'::"text", "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_base_amount numeric(18,4);
  v_new_balance numeric(18,4);
  v_ledger_entry jsonb;
  v_ledger_id uuid;
  v_entity_id bigint;
  v_point_ok boolean;
BEGIN
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transaction amount must be greater than zero.';
  END IF;

  IF p_type NOT IN ('credit', 'debit') THEN
    RAISE EXCEPTION 'Transaction type must be credit or debit.';
  END IF;

  IF p_target_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Target bucket must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_parent_tenant_id THEN
    v_entity_id := p_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    p_parent_tenant_id, p_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.parent_tenant_id = p_parent_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
    END IF;
  END IF;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      v_avail := v_avail - p_amount;
    END IF;
    v_new_balance := v_avail;
  ELSIF p_target_bucket = 'pending' THEN
    IF p_type = 'credit' THEN
      v_pend := v_pend + p_amount;
    ELSE
      v_pend := v_pend - p_amount;
    END IF;
    v_new_balance := v_pend;
  ELSIF p_target_bucket = 'locked' THEN
    IF p_type = 'credit' THEN
      v_lock := v_lock + p_amount;
    ELSE
      v_lock := v_lock - p_amount;
    END IF;
    v_new_balance := v_lock;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = p_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
    parent_tenant_id,
    operating_tenant_id,
    entity_type,
    entity_id,
    type,
    amount,
    currency_code,
    exchange_rate,
    base_amount,
    balance_after,
    source_type,
    source_id,
    metadata,
    cashbook_point_id
  )
  VALUES (
    p_parent_tenant_id,
    p_parent_tenant_id,
    p_operating_tenant_id,
    p_entity_type,
    v_entity_id,
    p_type,
    p_amount,
    coalesce(p_currency_code, 'BDT'),
    coalesce(p_exchange_rate, 1.000000),
    v_base_amount,
    v_new_balance,
    coalesce(p_source_type, 'adjustment'),
    p_source_id,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket),
    p_cashbook_point_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'parent_tenant_id', parent_tenant_id,
    'operating_tenant_id', operating_tenant_id,
    'tenant_id', parent_tenant_id,
    'entity_type', entity_type,
    'entity_id', entity_id,
    'type', type,
    'amount', amount,
    'currency_code', currency_code,
    'exchange_rate', exchange_rate,
    'base_amount', base_amount,
    'balance_after', balance_after,
    'source_type', source_type,
    'source_id', source_id,
    'metadata', metadata,
    'cashbook_point_id', cashbook_point_id,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;

ALTER FUNCTION "public"."record_ledger_transaction"("p_parent_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text", "p_exchange_rate" numeric, "p_source_type" "text", "p_source_id" "text", "p_metadata" "jsonb", "p_target_bucket" "text", "p_allow_overdraft" boolean, "p_cashbook_point_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."record_recipient_invoice_collection"("p_global_invoice_id" bigint, "p_amount" numeric, "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_reference" "text" DEFAULT NULL::"text", "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."bills"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_payment_id bigint;
begin
  select * into v_invoice from public.bills where id = p_global_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;
  if coalesce(p_amount, 0.00) <= 0.00 then raise exception 'Amount must be positive.'; end if;

  insert into public.pays (
    tenant_id,
    profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_invoice.parent_tenant_id,
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

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, bill_id, amount)
  values (v_invoice.parent_tenant_id, v_payment_id, p_global_invoice_id, p_global_invoice_id, p_amount);

  update public.bills
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = p_global_invoice_id
  returning * into v_invoice;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  -- Record Tenant Cash Credit for direct cash collection
  perform public.record_ledger_transaction(
    p_tenant_id => v_invoice.parent_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_invoice.parent_tenant_id,
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
  v_invoice public.bills;
begin
  select gi.* into v_invoice
  from public.bills gi
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

CREATE OR REPLACE FUNCTION "public"."resolve_customer_profile_for_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile_id bigint;
  v_books_id bigint;
begin
  if p_customer_group_id is null then
    return null;
  end if;

  select id into v_profile_id
  from public.profiles
  where operating_tenant_id = p_tenant_id
    and customer_group_id = p_customer_group_id
    and profile_type = 'customer'::public.profile_party_type
  order by id
  limit 1;

  if v_profile_id is not null then
    return v_profile_id;
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  select id into v_profile_id
  from public.profiles pr
  where pr.customer_group_id = p_customer_group_id
    and pr.profile_type = 'customer'::public.profile_party_type
    and (
      pr.operating_tenant_id = v_books_id
      or pr.operating_tenant_id in (
        select t.id from public.tenants t where t.parent_id = v_books_id
      )
    )
  order by
    case
      when pr.operating_tenant_id = p_tenant_id then 0
      when pr.operating_tenant_id = v_books_id then 1
      else 2
    end,
    pr.id
  limit 1;

  return v_profile_id;
end;
$$;

ALTER FUNCTION "public"."resolve_customer_profile_for_group"("p_tenant_id" bigint, "p_customer_group_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."reverse_wallet_ledger_entry_for_staff"("p_tenant_id" bigint, "p_ledger_entry_id" "uuid", "p_reason" "text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_orig public.cashbook_entries%ROWTYPE;
  v_reversal_type text;
  v_reversal_id uuid;
  v_meta jsonb;
  v_entry jsonb;
BEGIN
  IF NOT public.wallet_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF nullif(trim(p_reason), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason required');
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT * INTO v_orig FROM public.cashbook_entries WHERE id = p_ledger_entry_id;
  IF v_orig.id IS NULL OR v_orig.parent_tenant_id <> v_books_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry not found');
  END IF;

  IF v_orig.metadata ? 'reversed_by' OR v_orig.metadata ? 'reversal_of' THEN
    RETURN jsonb_build_object('success', false, 'error', 'entry already reversed or is a reversal');
  END IF;

  IF v_orig.source_type = 'shop_order' AND NOT coalesce((v_orig.metadata->>'allow_manual_reversal')::boolean, false)
     AND NOT public.is_superadmin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'system shop_order entries cannot be reversed');
  END IF;

  v_reversal_type := CASE WHEN v_orig.type = 'credit' THEN 'debit' ELSE 'credit' END;
  v_meta := jsonb_build_object(
    'reversal_of', v_orig.id::text,
    'transaction_type', 'manual_reversal',
    'note', p_reason,
    'trx_id', coalesce(p_reference_id, 'REV-' || gen_random_uuid()::text),
    'recorded_by', public.current_user_email()
  );

  v_entry := public.record_ledger_transaction(
    v_orig.parent_tenant_id,
    v_orig.operating_tenant_id,
    v_orig.entity_type,
    v_orig.entity_id,
    v_reversal_type,
    v_orig.amount,
    v_orig.currency_code,
    v_orig.exchange_rate,
    v_orig.source_type,
    coalesce(p_reference_id, v_orig.source_id),
    v_meta,
    coalesce(v_orig.metadata->>'target_bucket', 'available'),
    false
  );
  v_reversal_id := (v_entry->>'id')::uuid;

  UPDATE public.cashbook_entries
  SET metadata = metadata || jsonb_build_object('reversed_by', v_reversal_id::text)
  WHERE id = v_orig.id;

  RETURN jsonb_build_object(
    'success', true,
    'reversal_entry_id', v_reversal_id,
    'account', public.get_wallet_account_balances(
      v_books_id, v_orig.entity_type, v_orig.entity_id, v_orig.currency_code
    )
  );
END;
$$;

ALTER FUNCTION "public"."reverse_wallet_ledger_entry_for_staff"("p_tenant_id" bigint, "p_ledger_entry_id" "uuid", "p_reason" "text", "p_reference_id" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."search_sales_invoice_stock"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS TABLE("global_stock_id" bigint, "shipment_item_id" bigint, "product_id" bigint, "name" "text", "barcode" "text", "product_code" "text", "image_url" "text", "quantity" numeric, "available_atp" numeric, "unit_cost_price" numeric, "suggested_sell_price" numeric, "shipment_id" bigint, "shipment_name" "text", "holding_tenant_id" bigint, "holding_tenant_name" "text", "is_allocated_to_tenant" boolean, "allocation_rank" integer, "location_id" bigint, "location_name" "text", "stock_created_at" timestamp with time zone)
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
    and public.global_stock_atp_qty(gs.id) > 0
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

CREATE OR REPLACE FUNCTION "public"."sync_dropship_tenant_b2b_invoice_from_order"("p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_pick record;
  v_item_sell_price numeric(12,2);
  v_item_line_total numeric(12,2);
  v_charges record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'No tenant B2B invoice linked to order');
  end if;

  select * into v_invoice
  from public.bills
  where id = v_order.global_invoice_id
  for update;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'Linked invoice not found');
  end if;

  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    return jsonb_build_object('success', false, 'error', 'Linked invoice is not a dropship B2B invoice');
  end if;

  if v_invoice.invoice_status = 'voided'::public.global_invoice_status then
    return jsonb_build_object('success', false, 'error', 'Cannot sync a voided invoice');
  end if;

  if v_invoice.payment_status in ('paid', 'partially_paid') then
    raise exception
      'Cannot sync dropship B2B invoice after payment (invoice %). Use scripts/sql/backfill_dropship_invoice_charge_payer_mismatch.sql',
      v_invoice.id;
  end if;

  select * into v_charges
  from public.get_dropship_merchant_billable_charges(p_order_id);

  for v_pick in (
    select
      sp.quantity as pick_quantity,
      sp.held_stock_id,
      soi.product_id,
      soi.unit_sell_price_amount,
      soi.final_price_amount,
      gs.shipment_item_id as stock_shipment_item_id
    from public.shop_order_item_stock_picks sp
    join public.shop_order_items soi on soi.id = sp.order_item_id
    left join public.global_stocks gs on gs.id = sp.held_stock_id
    where sp.order_id = v_order.id
      and sp.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
  ) loop
    v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
    v_item_line_total := v_pick.pick_quantity * v_item_sell_price;

    update public.global_invoice_items gii
    set
      quantity = v_pick.pick_quantity,
      sell_price_amount = v_item_sell_price,
      line_total_amount = v_item_line_total,
      updated_at = now()
    where gii.invoice_id = v_invoice.id
      and gii.global_stock_id = v_pick.held_stock_id;
  end loop;

  update public.bills
  set
    shipping_charge = coalesce(v_charges.delivery, 0),
    print_charge = coalesce(v_charges.print, 0),
    wrapping_charge = coalesce(v_charges.packing, 0),
    channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(v_charges.cod, 0)),
    discount_amount = coalesce(v_order.discount_amount, 0),
    collection_source = 'profile'::public.collection_source_type,
    updated_at = now()
  where id = v_invoice.id;

  perform public.recompute_global_invoice_totals(v_invoice.id);
  perform public.recompute_global_invoice_payment_status(v_invoice.id);

  select * into v_invoice from public.bills where id = v_invoice.id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'total_amount', v_invoice.total_amount,
    'due_amount', v_invoice.due_amount
  );
end;
$$;

ALTER FUNCTION "public"."sync_dropship_tenant_b2b_invoice_from_order"("p_order_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_sales_invoice_charges_from_header"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_inv public.bills;
  v_total numeric(12,2) := 0;
begin
  select * into v_inv from public.bills where id = p_invoice_id;
  if not found then
    return;
  end if;

  delete from public.bill_lines
  where invoice_id = p_invoice_id
    and line_kind = 'charge';

  if coalesce(v_inv.shipping_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Delivery', 1,
      v_inv.shipping_charge, 0, v_inv.shipping_charge, v_inv.shipping_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'delivery')
    );
    v_total := v_total + v_inv.shipping_charge;
  end if;

  if coalesce(v_inv.print_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Print', 1,
      v_inv.print_charge, 0, v_inv.print_charge, v_inv.print_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'print')
    );
    v_total := v_total + v_inv.print_charge;
  end if;

  if coalesce(v_inv.wrapping_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.parent_tenant_id, 'charge', 'Packing', 1,
      v_inv.wrapping_charge, 0, v_inv.wrapping_charge, v_inv.wrapping_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'packing')
    );
    v_total := v_total + v_inv.wrapping_charge;
  end if;


  update public.bills
  set charges_amount = v_total,
      updated_at = now()
  where id = p_invoice_id;
end;
$$;

ALTER FUNCTION "public"."sync_sales_invoice_charges_from_header"("p_invoice_id" bigint) OWNER TO "postgres";

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
  from public.bills
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

CREATE OR REPLACE FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_notes" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_parent_tenant_id bigint;
  v_operating_tenant_id bigint;
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_result jsonb;
  v_entity_id bigint;
BEGIN
  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_operating_tenant_id := p_tenant_id;
  IF p_amount <= 0 THEN
    RAISE EXCEPTION 'Transfer amount must be greater than zero.';
  END IF;

  IF p_from_bucket = p_to_bucket THEN
    RAISE EXCEPTION 'Source and target buckets cannot be identical.';
  END IF;

  IF p_from_bucket NOT IN ('available', 'pending', 'locked')
     OR p_to_bucket NOT IN ('available', 'pending', 'locked') THEN
    RAISE EXCEPTION 'Invalid bucket specifiers. Must be available, pending, or locked.';
  END IF;

  v_entity_id := p_entity_id;
  IF p_entity_type = 'tenant' THEN
    v_entity_id := v_parent_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, parent_tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    v_parent_tenant_id, v_parent_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (parent_tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_from_bucket = 'pending' THEN
    IF v_pend < p_amount THEN
      RAISE EXCEPTION 'Insufficient pending balance (Pending: %, Requested: %).', v_pend, p_amount;
    END IF;
    v_pend := v_pend - p_amount;
  ELSIF p_from_bucket = 'available' THEN
    v_avail := v_avail - p_amount;
  ELSIF p_from_bucket = 'locked' THEN
    IF v_lock < p_amount THEN
      RAISE EXCEPTION 'Insufficient locked balance (Locked: %, Requested: %).', v_lock, p_amount;
    END IF;
    v_lock := v_lock - p_amount;
  END IF;

  IF p_to_bucket = 'pending' THEN
    v_pend := v_pend + p_amount;
  ELSIF p_to_bucket = 'available' THEN
    v_avail := v_avail + p_amount;
  ELSIF p_to_bucket = 'locked' THEN
    v_lock := v_lock + p_amount;
  END IF;

  UPDATE public.cashbook_accounts
  SET
    available_balance = v_avail,
    pending_balance = v_pend,
    locked_balance = v_lock,
    tenant_id = v_parent_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  INSERT INTO public.cashbook_entries (
    tenant_id, parent_tenant_id, operating_tenant_id,
    entity_type, entity_id, type, amount, currency_code,
    exchange_rate, base_amount, balance_after, source_type, source_id, metadata
  )
  VALUES (
    v_parent_tenant_id, v_parent_tenant_id, v_operating_tenant_id,
    p_entity_type, v_entity_id, 'credit', p_amount, coalesce(p_currency_code, 'BDT'),
    1.000000, p_amount, v_avail, 'bucket_transfer', NULL,
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object(
      'from_bucket', p_from_bucket,
      'to_bucket', p_to_bucket,
      'notes', p_notes
    )
  );

  SELECT jsonb_build_object(
    'account_id', v_account_id,
    'parent_tenant_id', v_parent_tenant_id,
    'tenant_id', v_parent_tenant_id,
    'entity_type', p_entity_type,
    'entity_id', v_entity_id,
    'currency_code', coalesce(p_currency_code, 'BDT'),
    'available_balance', v_avail,
    'pending_balance', v_pend,
    'locked_balance', v_lock
  ) INTO v_result;

  RETURN v_result;
END;
$$;

ALTER FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text", "p_notes" "text", "p_metadata" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_auto_create_customer_profile_for_customer_group"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_profile_id bigint;
begin
  v_books_id := coalesce(new.parent_tenant_id, public.resolve_parent_tenant_id(new.tenant_id));

  if exists (
    select 1
    from public.profiles
    where customer_group_id = new.id
      and profile_type = 'customer'::public.profile_party_type
  ) then
    return new;
  end if;

  insert into public.profiles (
    parent_tenant_id,
    profile_type,
    subject_id,
    customer_group_id,
    operating_tenant_id,
    name,
    email,
    phone,
    address,
    accent_color,
    is_active,
    created_at,
    updated_at
  )
  values (
    v_books_id,
    'customer'::public.profile_party_type,
    new.id,
    new.id,
    v_books_id,
    new.name,
    null,
    null,
    null,
    new.accent_color,
    coalesce(new.is_active, true),
    now(),
    now()
  )
  returning id into v_profile_id;

  update public.profiles
  set subject_id = v_profile_id
  where id = v_profile_id;

  return new;
end;
$$;

ALTER FUNCTION "public"."trg_auto_create_customer_profile_for_customer_group"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_sync_profile_from_cargo_company"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := new.parent_tenant_id;

  if v_books_id is null then
    return new;
  end if;

  perform public.upsert_profile_for_party(
    v_books_id,
    'cargo'::public.profile_party_type,
    new.id,
    new.name,
    new.email,
    new.phone,
    '+880',
    new.address,
    case when new.phone is null or btrim(new.phone) = '' then false else true end,
    null,
    true,
    null
  );

  return new;
end;
$$;

ALTER FUNCTION "public"."trg_sync_profile_from_cargo_company"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_sync_profile_from_courier_service"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  if new.tenant_id is null then
    return new;
  end if;

  v_books_id := public.resolve_parent_tenant_id(new.tenant_id);

  perform public.upsert_profile_for_party(
    v_books_id,
    'courier'::public.profile_party_type,
    new.wallet_entity_id,
    new.name,
    null,
    null,
    '+880',
    null,
    false,
    null,
    coalesce(new.is_active, true),
    null
  );

  return new;
end;
$$;

ALTER FUNCTION "public"."trg_sync_profile_from_courier_service"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_sync_profile_from_customer_group"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  update public.profiles p
  set
    accent_color = new.accent_color,
    is_active = new.is_active,
    deleted_at = new.deleted_at,
    updated_at = now()
  where p.customer_group_id = new.id
    and p.profile_type = 'customer'::public.profile_party_type;

  return new;
end;
$$;

ALTER FUNCTION "public"."trg_sync_profile_from_customer_group"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_sync_profile_from_tenant"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := coalesce(new.parent_id, new.id);

  perform public.upsert_profile_for_party(
    v_books_id,
    'tenant'::public.profile_party_type,
    new.id,
    new.name,
    null,
    null,
    '+880',
    null,
    false,
    null,
    coalesce(new.is_active, true),
    null
  );

  return new;
end;
$$;

ALTER FUNCTION "public"."trg_sync_profile_from_tenant"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_sync_profile_from_vendor"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := new.parent_tenant_id;

  if v_books_id is null then
    return new;
  end if;

  perform public.upsert_profile_for_party(
    v_books_id,
    'vendor'::public.profile_party_type,
    new.id,
    new.name,
    new.email,
    new.phone,
    '+880',
    new.address,
    case when new.phone is null or btrim(new.phone) = '' then false else true end,
    null,
    true,
    null
  );

  return new;
end;
$$;

ALTER FUNCTION "public"."trg_sync_profile_from_vendor"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."trg_validate_global_invoice_profiles"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if new.profile_id is not null then
    if not public.profile_valid_for_issuer(
      new.profile_id,
      new.issued_by_tenant_id
    ) then
      raise exception 'Profile books must match invoice issued_by_tenant_id';
    end if;
  end if;

  if new.recipient_profile_id is not null then
    if not public.recipient_profile_valid_for_issuer(
      new.recipient_profile_id,
      new.issued_by_tenant_id
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
  v_invoice public.bills;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
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


  -- Mark invoice as draft
  update public.bills
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
  v_invoice public.bills;
begin
  select * into v_invoice from public.bills where id = p_invoice_id;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'draft'::public.global_invoice_status then
    raise exception 'cannot update header of a non-draft invoice';
  end if;

  update public.bills
  set
    discount_amount = coalesce(p_discount_amount, discount_amount),
    shipping_charge = coalesce(p_shipping_charge, shipping_charge),
    channel_meta = case
      when p_cod_charge is null then channel_meta
      else coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', p_cod_charge)
    end,
    wrapping_charge = coalesce(p_wrapping_charge, wrapping_charge),
    print_charge = coalesce(p_print_charge, print_charge),
    recipient_name = coalesce(nullif(trim(p_recipient_name), ''), recipient_name),
    recipient_phone = coalesce(nullif(trim(p_recipient_phone), ''), recipient_phone),
    recipient_address = coalesce(nullif(trim(p_recipient_address), ''), recipient_address),
    note = coalesce(nullif(trim(p_note), ''), note),
    invoice_no = coalesce(nullif(trim(p_invoice_no), ''), invoice_no),
    invoice_date = coalesce(p_invoice_date, invoice_date),
    updated_at = now()
  where id = p_invoice_id;

  perform public.recompute_global_invoice_totals(p_invoice_id);
end;
$$;

ALTER FUNCTION "public"."update_global_invoice_header"("p_invoice_id" bigint, "p_discount_amount" numeric, "p_shipping_charge" numeric, "p_cod_charge" numeric, "p_wrapping_charge" numeric, "p_print_charge" numeric, "p_recipient_name" "text", "p_recipient_phone" "text", "p_recipient_address" "text", "p_note" "text", "p_invoice_no" "text", "p_invoice_date" "date") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_global_invoice_item"("p_item_id" bigint, "p_quantity" numeric, "p_sell_price_amount" numeric, "p_recipient_price_amount" numeric DEFAULT NULL::numeric) RETURNS "public"."bill_lines"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.bill_lines;
  v_invoice public.bills;
  v_line_total numeric;
begin
  select * into v_item from public.bill_lines where id = p_item_id;
  if v_item.id is null then raise exception 'Invoice item not found'; end if;

  select * into v_invoice from public.bills where id = v_item.invoice_id;
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

  update public.bill_lines
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

CREATE OR REPLACE FUNCTION "public"."update_payment_instrument_details"("p_tenant_id" bigint, "p_instrument_id" bigint, "p_reference" "text" DEFAULT NULL::"text", "p_bd_bank_id" bigint DEFAULT NULL::bigint, "p_cheque_number" "text" DEFAULT NULL::"text", "p_cheque_date" "date" DEFAULT NULL::"date") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_line public.pay_instruments;
  v_payment public.pays;
  v_method text;
begin
  if p_tenant_id is null or p_instrument_id is null then
    raise exception 'Tenant and instrument are required.';
  end if;

  select gpi.* into v_line
  from public.pay_instruments gpi
  where gpi.id = p_instrument_id;

  if v_line.id is null then
    raise exception 'Instrument line not found.';
  end if;

  select * into v_payment
  from public.pays gp
  where gp.id = v_line.payment_id
    and gp.tenant_id = p_tenant_id;

  if v_payment.id is null then
    raise exception 'Payment not found for tenant.';
  end if;

  if v_payment.voided_at is not null then
    raise exception 'Cannot edit a voided receipt.';
  end if;

  v_method := upper(trim(v_line.payment_method_code));

  if v_method = 'CHEQUE' then
    if p_bd_bank_id is null then
      raise exception 'Cheque line requires a bank.';
    end if;
    if nullif(trim(coalesce(p_cheque_number, '')), '') is null then
      raise exception 'Cheque line requires a cheque number.';
    end if;
    if p_cheque_date is null then
      raise exception 'Cheque line requires a cheque date.';
    end if;
    if not exists (
      select 1 from public.bd_banks b
      where b.id = p_bd_bank_id and b.is_active = true
    ) then
      raise exception 'Invalid bank for cheque line.';
    end if;
  elsif v_method = 'BANK_TRANSFER' then
    if p_bd_bank_id is null then
      raise exception 'Bank transfer line requires a bank.';
    end if;
    if not exists (
      select 1 from public.bd_banks b
      where b.id = p_bd_bank_id and b.is_active = true
    ) then
      raise exception 'Invalid bank for bank transfer line.';
    end if;
  end if;

  update public.pay_instruments
  set
    reference = nullif(trim(coalesce(p_reference, '')), ''),
    bd_bank_id = case when v_method in ('CHEQUE', 'BANK_TRANSFER') then p_bd_bank_id else null end,
    cheque_number = case when v_method = 'CHEQUE' then nullif(trim(coalesce(p_cheque_number, '')), '') else null end,
    cheque_date = case when v_method in ('CHEQUE', 'BANK_TRANSFER') then p_cheque_date else null end
  where id = p_instrument_id
  returning * into v_line;

  return jsonb_build_object(
    'success', true,
    'instrument_id', v_line.id,
    'payment_id', v_line.payment_id
  );
end;
$$;

ALTER FUNCTION "public"."update_payment_instrument_details"("p_tenant_id" bigint, "p_instrument_id" bigint, "p_reference" "text", "p_bd_bank_id" bigint, "p_cheque_number" "text", "p_cheque_date" "date") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."update_sales_invoice_from_payload"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $_$
declare
  v_inv_patch jsonb;
  v_items jsonb;
  v_remove_ids jsonb;
  v_item_elem jsonb;
  v_invoice public.bills;
  v_parent_id bigint;
  v_item_id bigint;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_unit_cost numeric;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_name_snapshot text;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
  v_stock_parent bigint;
  v_db_item public.bill_lines;
  v_removed_ids bigint[] := '{}';
  v_remove_id bigint;
  v_result_items jsonb := '[]'::jsonb;
  v_has_changes boolean := false;
  v_recompute boolean := true;
  v_dropship_sync boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied', 'code', 'ACCESS_DENIED');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object', 'code', 'VALIDATION_ERROR');
  end if;

  v_dropship_sync := coalesce((p_payload->'options'->>'dropship_sync')::boolean, false);

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice not found', 'code', 'NOT_FOUND');
  end if;

  if v_invoice.issued_by_tenant_id <> p_tenant_id then
    return jsonb_build_object('success', false, 'error', 'invoice does not belong to tenant', 'code', 'ACCESS_DENIED');
  end if;

  if v_invoice.invoice_status not in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    if not (
      v_dropship_sync
      and v_invoice.invoice_type = 'dropship'::public.global_invoice_type
      and v_invoice.invoice_status = 'issued'::public.global_invoice_status
    ) then
      return jsonb_build_object(
        'success', false,
        'error', format('invoice is not editable (status: %s)', v_invoice.invoice_status),
        'code', 'INVOICE_NOT_EDITABLE'
      );
    end if;
  end if;

  v_inv_patch := p_payload->'invoice';
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_remove_ids := coalesce(p_payload->'remove_item_ids', '[]'::jsonb);
  v_recompute := coalesce((p_payload->'options'->>'recompute_totals')::boolean, true);

  if v_dropship_sync and v_invoice.invoice_status = 'issued'::public.global_invoice_status then
    v_remove_ids := '[]'::jsonb;
  end if;

  if (v_inv_patch is null or v_inv_patch = '{}'::jsonb)
     and jsonb_array_length(v_items) = 0
     and jsonb_array_length(v_remove_ids) = 0 then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  v_parent_id := v_invoice.parent_tenant_id;

  if v_inv_patch is not null and jsonb_typeof(v_inv_patch) = 'object' and v_inv_patch <> '{}'::jsonb then
    if v_inv_patch ? 'profile_id' and nullif(v_inv_patch->>'profile_id', '') is not null then
      if not exists (
        select 1 from public.profiles pr
        where pr.id = (v_inv_patch->>'profile_id')::bigint
          and pr.operating_tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'billing profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    if v_inv_patch ? 'recipient_profile_id' and nullif(v_inv_patch->>'recipient_profile_id', '') is not null then
      if not exists (
        select 1 from public.recipient_profiles rp
        where rp.id = (v_inv_patch->>'recipient_profile_id')::bigint
          and rp.tenant_id = p_tenant_id
      ) then
        return jsonb_build_object('success', false, 'error', 'recipient profile must belong to tenant', 'code', 'VALIDATION_ERROR');
      end if;
    end if;

    update public.bills
    set
      invoice_no = case
        when v_inv_patch ? 'invoice_no' then coalesce(nullif(trim(v_inv_patch->>'invoice_no'), ''), invoice_no)
        else invoice_no
      end,
      invoice_date = case
        when v_inv_patch ? 'invoice_date' then coalesce(nullif(v_inv_patch->>'invoice_date', '')::date, invoice_date)
        else invoice_date
      end,
      due_date = case
        when v_inv_patch ? 'due_date' then nullif(v_inv_patch->>'due_date', '')::date
        else due_date
      end,
      profile_id = case
        when v_inv_patch ? 'profile_id' then nullif(v_inv_patch->>'profile_id', '')::bigint
        else profile_id
      end,
      recipient_profile_id = case
        when v_inv_patch ? 'recipient_profile_id' then nullif(v_inv_patch->>'recipient_profile_id', '')::bigint
        else recipient_profile_id
      end,
      recipient_name = case
        when v_inv_patch ? 'recipient_name' then nullif(trim(v_inv_patch->>'recipient_name'), '')
        else recipient_name
      end,
      recipient_phone = case
        when v_inv_patch ? 'recipient_phone' then nullif(trim(v_inv_patch->>'recipient_phone'), '')
        else recipient_phone
      end,
      recipient_address = case
        when v_inv_patch ? 'recipient_address' then nullif(trim(v_inv_patch->>'recipient_address'), '')
        else recipient_address
      end,
      note = case
        when v_inv_patch ? 'note' then nullif(trim(v_inv_patch->>'note'), '')
        else note
      end,
      discount_amount = case
        when v_inv_patch ? 'discount_amount' then coalesce(nullif(v_inv_patch->>'discount_amount', '')::numeric, 0)
        else discount_amount
      end,
      shipping_charge = case
        when v_inv_patch ? 'shipping_charge' then coalesce(nullif(v_inv_patch->>'shipping_charge', '')::numeric, 0)
        else shipping_charge
      end,
      channel_meta = case
        when v_inv_patch ? 'channel_meta' and jsonb_typeof(v_inv_patch->'channel_meta') = 'object'
          then coalesce(channel_meta, '{}'::jsonb) || (v_inv_patch->'channel_meta')
        when v_inv_patch ? 'cod_charge_amount' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge_amount', '')::numeric, 0))
        when v_inv_patch ? 'cod_charge' then coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('cod_charge_amount', coalesce(nullif(v_inv_patch->>'cod_charge', '')::numeric, 0))
        else channel_meta
      end,
      print_charge = case
        when v_inv_patch ? 'print_charge' then coalesce(nullif(v_inv_patch->>'print_charge', '')::numeric, 0)
        else print_charge
      end,
      wrapping_charge = case
        when v_inv_patch ? 'wrapping_charge' then coalesce(nullif(v_inv_patch->>'wrapping_charge', '')::numeric, 0)
        else wrapping_charge
      end,
      collection_source = case
        when v_inv_patch ? 'collection_source' and nullif(trim(v_inv_patch->>'collection_source'), '') is not null
          then (v_inv_patch->>'collection_source')::public.collection_source_type
        else collection_source
      end,
      updated_at = now()
    where id = p_invoice_id;

    v_has_changes := true;
  end if;

  if jsonb_typeof(v_remove_ids) = 'array' and jsonb_array_length(v_remove_ids) > 0 then
    for v_remove_id in
      select (value::text)::bigint
      from jsonb_array_elements(v_remove_ids) as t(value)
      where value is not null and value::text ~ '^[0-9]+$'
    loop
      delete from public.bill_lines
      where id = v_remove_id
        and invoice_id = p_invoice_id
      returning id into v_item_id;

      if v_item_id is not null then
        v_removed_ids := array_append(v_removed_ids, v_item_id);
        v_has_changes := true;
      end if;
    end loop;
  end if;

  if jsonb_typeof(v_items) = 'array' and jsonb_array_length(v_items) > 0 then
    for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
      v_item_id := nullif(v_item_elem->>'id', '')::bigint;

      if v_item_id is not null then
        select * into v_db_item
        from public.bill_lines
        where id = v_item_id
          and invoice_id = p_invoice_id;

        if v_db_item.id is null then
          return jsonb_build_object(
            'success', false,
            'error', format('invoice item %s not found on invoice', v_item_id),
            'code', 'NOT_FOUND'
          );
        end if;

        v_quantity := coalesce(
          case when v_item_elem ? 'quantity' then nullif(v_item_elem->>'quantity', '')::numeric else null end,
          v_db_item.quantity
        );
        v_sell_price := coalesce(
          case when v_item_elem ? 'sell_price_amount' then nullif(v_item_elem->>'sell_price_amount', '')::numeric else null end,
          v_db_item.sell_price_amount
        );
        v_line_discount := coalesce(
          case when v_item_elem ? 'line_discount_amount' then nullif(v_item_elem->>'line_discount_amount', '')::numeric else null end,
          v_db_item.line_discount_amount,
          0
        );

        if v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'quantity must be > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'sell_price_amount must be >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        update public.bill_lines
        set
          quantity = v_quantity,
          sell_price_amount = v_sell_price,
          line_discount_amount = v_line_discount,
          line_total_amount = v_line_total,
          name_snapshot = case
            when v_item_elem ? 'name_snapshot' then coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), name_snapshot)
            else name_snapshot
          end,
          updated_at = now()
        where id = v_item_id
        returning * into v_db_item;

        v_has_changes := true;
      elsif not v_dropship_sync then
        v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
        v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
        v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
        v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);

        if v_global_stock_id is null then
          return jsonb_build_object('success', false, 'error', 'new items require global_stock_id', 'code', 'VALIDATION_ERROR');
        end if;
        if v_quantity is null or v_quantity <= 0 then
          return jsonb_build_object('success', false, 'error', 'new items require quantity > 0', 'code', 'VALIDATION_ERROR');
        end if;
        if v_sell_price is null or v_sell_price < 0 then
          return jsonb_build_object('success', false, 'error', 'new items require sell_price_amount >= 0', 'code', 'VALIDATION_ERROR');
        end if;

        select
          gs.parent_tenant_id,
          gs.shipment_item_id,
          gsi.name,
          gsi.barcode,
          gsi.product_code,
          sh.assigned_child_tenant_id,
          p.id
        into
          v_stock_parent,
          v_shipment_item_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_assigned_child,
          v_product_id
        from public.global_stocks gs
        left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
        left join public.global_shipments sh on sh.id = gsi.shipment_id
        left join public.products p on p.id = gsi.product_id
        where gs.id = v_global_stock_id;

        if v_stock_parent is null then
          return jsonb_build_object('success', false, 'error', format('stock %s not found', v_global_stock_id), 'code', 'NOT_FOUND');
        end if;

        if v_stock_parent <> v_parent_id then
          return jsonb_build_object(
            'success', false,
            'error', format('stock %s does not belong to invoice parent tenant', v_global_stock_id),
            'code', 'VALIDATION_ERROR'
          );
        end if;

        v_shipment_item_id := coalesce(nullif(v_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
        v_product_id := coalesce(nullif(v_item_elem->>'product_id', '')::bigint, v_product_id);
        v_name_snapshot := coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
        v_barcode_snapshot := coalesce(nullif(trim(v_item_elem->>'barcode_snapshot'), ''), v_barcode_snapshot);
        v_product_code_snapshot := coalesce(nullif(trim(v_item_elem->>'product_code_snapshot'), ''), v_product_code_snapshot);
        v_assigned_child := coalesce(nullif(v_item_elem->>'assigned_child_tenant_id', '')::bigint, v_assigned_child);
        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        insert into public.bill_lines (
          parent_tenant_id,
          invoice_id,
          global_stock_id,
          shipment_item_id,
          product_id,
          name_snapshot,
          barcode_snapshot,
          product_code_snapshot,
          quantity,
          sell_price_amount,
          line_discount_amount,
          line_total_amount,
          assigned_child_tenant_id
        )
        values (
          v_parent_id,
          p_invoice_id,
          v_global_stock_id,
          v_shipment_item_id,
          v_product_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_quantity,
          v_sell_price,
          v_line_discount,
          v_line_total,
          v_assigned_child
        )
        returning * into v_db_item;

        v_has_changes := true;
      end if;
    end loop;
  end if;

  if not v_has_changes then
    return jsonb_build_object('success', false, 'error', 'nothing to update', 'code', 'EMPTY_PAYLOAD');
  end if;

  if v_recompute then
    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  select * into v_invoice from public.bills where id = p_invoice_id;

  if v_dropship_sync then
    if v_invoice.invoice_status in (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) then
      perform public.post_sales_invoice(p_invoice_id);
      select * into v_invoice from public.bills where id = p_invoice_id;
    elsif v_invoice.payment_status not in ('paid', 'partially_paid') then
      update public.bills
      set
        payment_status = 'due',
        due_amount = greatest(coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0), 0),
        updated_at = now()
      where id = p_invoice_id;
      select * into v_invoice from public.bills where id = p_invoice_id;
    end if;
    perform public.recompute_global_invoice_payment_status(p_invoice_id);
    select * into v_invoice from public.bills where id = p_invoice_id;
  end if;

  select coalesce(jsonb_agg(to_jsonb(sii.*) order by sii.id), '[]'::jsonb)
  into v_result_items
  from public.bill_lines sii
  where sii.invoice_id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no,
    'invoice_type', v_invoice.invoice_type,
    'invoice_status', v_invoice.invoice_status,
    'payment_status', v_invoice.payment_status,
    'invoice', jsonb_build_object(
      'id', v_invoice.id,
      'parent_tenant_id', v_invoice.parent_tenant_id,
      'issued_by_tenant_id', v_invoice.issued_by_tenant_id,
      'invoice_type', v_invoice.invoice_type,
      'invoice_no', v_invoice.invoice_no,
      'invoice_status', v_invoice.invoice_status,
      'payment_status', v_invoice.payment_status,
      'profile_id', v_invoice.profile_id,
      'recipient_profile_id', v_invoice.recipient_profile_id,
      'recipient_name', v_invoice.recipient_name,
      'recipient_phone', v_invoice.recipient_phone,
      'recipient_address', v_invoice.recipient_address,
      'collection_source', v_invoice.collection_source,
      'subtotal_amount', v_invoice.subtotal_amount,
      'discount_amount', v_invoice.discount_amount,
      'shipping_charge', v_invoice.shipping_charge,
      'cod_charge_amount', coalesce((v_invoice.channel_meta->>'cod_charge_amount')::numeric, 0),
      'print_charge', v_invoice.print_charge,
      'wrapping_charge', v_invoice.wrapping_charge,
      'total_amount', v_invoice.total_amount,
      'paid_amount', v_invoice.paid_amount,
      'due_amount', v_invoice.due_amount,
      'note', v_invoice.note,
      'due_date', v_invoice.due_date,
      'invoice_date', v_invoice.invoice_date
    ),
    'items', v_result_items,
    'removed_item_ids', to_jsonb(v_removed_ids)
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm, 'code', 'VALIDATION_ERROR');
end;
$_$;

ALTER FUNCTION "public"."update_sales_invoice_from_payload"("p_tenant_id" bigint, "p_invoice_id" bigint, "p_payload" "jsonb") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."upsert_profile_for_party"("p_parent_tenant_id" bigint, "p_profile_type" "public"."profile_party_type", "p_subject_id" bigint, "p_name" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_phone_country_code" "text" DEFAULT '+880'::"text", "p_address" "text" DEFAULT NULL::"text", "p_is_phone_unique" boolean DEFAULT true, "p_accent_color" "text" DEFAULT NULL::"text", "p_is_active" boolean DEFAULT true, "p_deleted_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile_id bigint;
  v_phone_unique boolean;
begin
  if p_parent_tenant_id is null or p_subject_id is null then
    return null;
  end if;

  if nullif(btrim(coalesce(p_name, '')), '') is null then
    raise exception 'profile name is required';
  end if;

  v_phone_unique := coalesce(p_is_phone_unique, true);
  if p_phone is null or btrim(p_phone) = '' then
    v_phone_unique := false;
  end if;

  insert into public.profiles (
    parent_tenant_id,
    profile_type,
    subject_id,
    name,
    email,
    phone,
    phone_country_code,
    address,
    is_phone_unique,
    accent_color,
    is_active,
    deleted_at
  )
  values (
    p_parent_tenant_id,
    p_profile_type,
    p_subject_id,
    btrim(p_name),
    nullif(btrim(coalesce(p_email, '')), ''),
    nullif(btrim(coalesce(p_phone, '')), ''),
    coalesce(nullif(btrim(coalesce(p_phone_country_code, '')), ''), '+880'),
    nullif(btrim(coalesce(p_address, '')), ''),
    v_phone_unique,
    nullif(btrim(coalesce(p_accent_color, '')), ''),
    coalesce(p_is_active, true),
    p_deleted_at
  )
  on conflict (parent_tenant_id, profile_type, subject_id) do update set
    name = excluded.name,
    email = excluded.email,
    phone = excluded.phone,
    phone_country_code = excluded.phone_country_code,
    address = excluded.address,
    is_phone_unique = excluded.is_phone_unique,
    accent_color = coalesce(excluded.accent_color, profiles.accent_color),
    is_active = excluded.is_active,
    deleted_at = excluded.deleted_at,
    updated_at = now()
  returning id into v_profile_id;

  return v_profile_id;
end;
$$;

ALTER FUNCTION "public"."upsert_profile_for_party"("p_parent_tenant_id" bigint, "p_profile_type" "public"."profile_party_type", "p_subject_id" bigint, "p_name" "text", "p_email" "text", "p_phone" "text", "p_phone_country_code" "text", "p_address" "text", "p_is_phone_unique" boolean, "p_accent_color" "text", "p_is_active" boolean, "p_deleted_at" timestamp with time zone) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."void_customer_receipt"("p_tenant_id" bigint, "p_payment_id" bigint, "p_reason" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_payment public.pays;
  v_parent_id bigint;
  v_invoice_id bigint;
  v_leftover numeric(12,2);
begin
  if p_tenant_id is null or p_payment_id is null then
    raise exception 'Tenant and payment are required.';
  end if;

  if nullif(trim(coalesce(p_reason, '')), '') is null then
    raise exception 'A reason is required to void a receipt.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_payment
  from public.pays
  where id = p_payment_id
    and tenant_id = p_tenant_id
  for update;

  if v_payment.id is null then
    raise exception 'Payment not found.';
  end if;

  if v_payment.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  if coalesce(v_payment.method, '') = 'wallet_credit' then
    raise exception 'Store-credit application receipts cannot be voided from this screen.';
  end if;

  for v_invoice_id in
    select distinct ip.global_invoice_id
    from public.pay_allocations ip
    where ip.payment_id = v_payment.id
  loop
    delete from public.pay_allocations
    where payment_id = v_payment.id
      and global_invoice_id = v_invoice_id;
    perform public.recompute_global_invoice_payment_status(v_invoice_id);
  end loop;

  v_leftover := coalesce(v_payment.unallocated_amount, 0.00);

  if coalesce(v_payment.amount, 0.00) > 0.00 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'debit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_batch_payment_received',
        'payment_id', v_payment.id,
        'reason', p_reason
      ),
      p_allow_overdraft => true
    );
  end if;

  if v_leftover > 0.00 and v_payment.profile_id is not null then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_payment.profile_id,
      p_type => 'debit',
      p_amount => v_leftover,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_store_credit',
        'payment_id', v_payment.id,
        'reason', p_reason
      ),
      p_allow_overdraft => true
    );
  end if;

  update public.pays
  set
    voided_at = now(),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[VOIDED] ' || trim(p_reason)
    )
  where id = v_payment.id;

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment.id,
    'customer_group_id', v_payment.customer_group_id
  );
end;
$$;

ALTER FUNCTION "public"."void_customer_receipt"("p_tenant_id" bigint, "p_payment_id" bigint, "p_reason" "text") OWNER TO "postgres";

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
  v_invoice public.bills;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'only issued invoices can be voided';
  end if;
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot void a paid or partially paid invoice; reverse collections/payments first';
  end if;

  if v_invoice.document_kind = 'standard'::public.bill_document_kind
     and exists (
       select 1 from public.bills n
       where n.parent_bill_id = p_invoice_id
         and n.invoice_status <> 'voided'::public.global_invoice_status
     ) then
    raise exception 'void or issue credit on child notes before voiding this bill';
  end if;

  -- Mark invoice as voided (Trigger on bills handles restoring stock)
  update public.bills
  set
    invoice_status = 'voided'::public.global_invoice_status,
    due_amount = 0.00
  where id = p_invoice_id;

  if v_invoice.parent_bill_id is not null then
    perform public.recompute_global_invoice_payment_status(v_invoice.parent_bill_id);
  end if;
end;
$$;

ALTER FUNCTION "public"."void_sales_invoice"("p_invoice_id" bigint) OWNER TO "postgres";
