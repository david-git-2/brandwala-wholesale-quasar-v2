-- Migration: 20270927120000_fix_shipment_pnl_written_off_amount.sql
-- Replace dropped settlement_discount_amount with written_off_amount / invoice_write_offs

CREATE OR REPLACE FUNCTION "public"."get_shipment_pnl"("p_tenant_id" bigint, "p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shipment jsonb;
  v_items jsonb;
  v_total_landed_cost numeric(12,2) := 0;
  v_total_sold_cost numeric(12,2) := 0;
  v_total_revenue numeric(12,2) := 0;
  v_total_gross_profit numeric(12,2) := 0;
  v_total_sellable_on_hand_value numeric(12,2) := 0;
  v_total_shrinkage_value numeric(12,2) := 0;
  v_total_stolen_value numeric(12,2) := 0;
  v_total_box_damage_value numeric(12,2) := 0;
  v_total_expired_value numeric(12,2) := 0;
  v_total_reconciliation_gap bigint := 0;
  v_disposition_available boolean := false;
begin
  -- Resolve parent tenant to enforce access
  if public.resolve_parent_tenant_id(p_tenant_id) <> (select parent_tenant_id from public.global_shipments where id = p_shipment_id) then
    raise exception 'unauthorized tenant access to shipment';
  end if;

  -- 1. Get shipment header
  select row_to_json(s)::jsonb
  into v_shipment
  from public.global_shipments s
  where s.id = p_shipment_id;

  -- Check if disposition is available (i.e. global_stocks rows exist for shipment items)
  select exists (
    select 1
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gs.shipment_item_id = gsi.id
    where gsi.shipment_id = p_shipment_id
  ) into v_disposition_available;

  -- 2. Get shipment items details with on-the-fly margins and stock disposition
  select coalesce(jsonb_agg(row_to_json(r)), '[]'::jsonb)
  into v_items
  from (
    select
      si.*,
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(sum(ii.unit_cost_price * (ii.quantity - ii.return_quantity)), 0) as sold_cost,
      coalesce(sum(
        ii.sell_price_amount * (ii.quantity - coalesce(ii.return_quantity, 0))
        - case
          when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
          else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.written_off_amount, 0.00))
            * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        end
      ), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      coalesce(disp.reserved_qty, 0) as reserved_qty,
      (coalesce(disp.sellable_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as sellable_value,
      ((coalesce(disp.stolen_qty, 0) + coalesce(disp.box_damage_qty, 0) + coalesce(disp.expired_qty, 0)) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as shrinkage_value,
      (coalesce(disp.stolen_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as stolen_value,
      (coalesce(disp.box_damage_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as box_damage_value,
      (coalesce(disp.expired_qty, 0) * public.calculate_landed_unit_cost(si.id))::numeric(12,2) as expired_value,
      (si.ordered_quantity - coalesce(sum(ii.quantity - ii.return_quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    left join lateral (
      select coalesce(sum(x.line_total_amount), 0.00) as inv_line_subtotal
      from public.global_invoice_items x
      where x.invoice_id = ii.invoice_id
    ) invagg on true
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) r;

  -- 3. Sum total metrics
  select
    coalesce(sum(landed_unit_cost * received_qty), 0),
    coalesce(sum(sold_cost), 0),
    coalesce(sum(revenue), 0),
    coalesce(sum(sellable_qty * landed_unit_cost), 0),
    coalesce(sum((stolen_qty + box_damage_qty + expired_qty) * landed_unit_cost), 0),
    coalesce(sum(stolen_qty * landed_unit_cost), 0),
    coalesce(sum(box_damage_qty * landed_unit_cost), 0),
    coalesce(sum(expired_qty * landed_unit_cost), 0),
    coalesce(sum(reconciliation_gap), 0)
  into
    v_total_landed_cost,
    v_total_sold_cost,
    v_total_revenue,
    v_total_sellable_on_hand_value,
    v_total_shrinkage_value,
    v_total_stolen_value,
    v_total_box_damage_value,
    v_total_expired_value,
    v_total_reconciliation_gap
  from (
    select
      public.calculate_landed_unit_cost(si.id) as landed_unit_cost,
      si.ordered_quantity as received_qty,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty,
      coalesce(sum(ii.unit_cost_price * (ii.quantity - ii.return_quantity)), 0) as sold_cost,
      coalesce(sum(
        ii.sell_price_amount * (ii.quantity - coalesce(ii.return_quantity, 0))
        - case
          when inv.invoice_type = 'dropship'::public.global_invoice_type then 0.00
          else (coalesce(inv.discount_amount, 0.00) + coalesce(inv.written_off_amount, 0.00))
            * (ii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
        end
      ), 0) as revenue,
      coalesce(disp.sellable_qty, 0) as sellable_qty,
      coalesce(disp.stolen_qty, 0) as stolen_qty,
      coalesce(disp.box_damage_qty, 0) as box_damage_qty,
      coalesce(disp.expired_qty, 0) as expired_qty,
      (si.ordered_quantity - coalesce(sum(ii.quantity - ii.return_quantity), 0) - coalesce(disp.sellable_qty, 0) - coalesce(disp.stolen_qty, 0) - coalesce(disp.box_damage_qty, 0) - coalesce(disp.expired_qty, 0) - coalesce(disp.reserved_qty, 0)) as reconciliation_gap
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    left join lateral (
      select coalesce(sum(x.line_total_amount), 0.00) as inv_line_subtotal
      from public.global_invoice_items x
      where x.invoice_id = ii.invoice_id
    ) invagg on true
    left join lateral (
      select
        coalesce(sum(gs.quantity) filter (where gst.is_sellable = true), 0) as sellable_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'stolen'), 0) as stolen_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'box damage'), 0) as box_damage_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'expired'), 0) as expired_qty,
        coalesce(sum(gs.quantity) filter (where lower(trim(gst.description)) = 'reserved'), 0) as reserved_qty
      from public.global_stocks gs
      inner join public.global_stock_types gst on gst.id = gs.stock_type_id
      where gs.shipment_item_id = si.id
    ) disp on true
    where si.shipment_id = p_shipment_id
    group by si.id, disp.sellable_qty, disp.stolen_qty, disp.box_damage_qty, disp.expired_qty, disp.reserved_qty
  ) rollup;

  v_total_gross_profit := v_total_revenue - v_total_sold_cost;

  return jsonb_build_object(
    'shipment', v_shipment,
    'items', v_items,
    'totals', jsonb_build_object(
      'landed_cost', v_total_landed_cost,
      'sold_cost', v_total_sold_cost,
      'revenue', v_total_revenue,
      'gross_profit', v_total_gross_profit,
      'sellable_on_hand_value', v_total_sellable_on_hand_value,
      'shrinkage_value', v_total_shrinkage_value,
      'stolen_value', v_total_stolen_value,
      'box_damage_value', v_total_box_damage_value,
      'expired_value', v_total_expired_value,
      'unsold_value', v_total_sellable_on_hand_value, -- alias for backward compat
      'disposition_available', v_disposition_available,
      'reconciliation_gap', v_total_reconciliation_gap
    )
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."apply_global_invoice_settlement_discount"("p_invoice_id" bigint, "p_amount" numeric, "p_note" "text" DEFAULT NULL::"text") RETURNS "public"."sales_invoices"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.global_invoices;
  v_parent_id bigint;
  v_operating_tenant_id bigint;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
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

  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.tenant_id);
  v_operating_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);

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
    update public.sales_invoices
    set
      note = coalesce(nullif(trim(p_note), ''), note),
      updated_at = now()
    where id = p_invoice_id;
  end if;

  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  select * into v_invoice from public.global_invoices where id = p_invoice_id;

  -- Record Tenant Revenue Write-Off for settlement discount
  if p_amount > 0 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => coalesce(v_invoice.parent_tenant_id, v_invoice.tenant_id),
      p_operating_tenant_id => coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id, v_invoice.tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => coalesce(v_invoice.parent_tenant_id, v_invoice.tenant_id),
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

CREATE OR REPLACE FUNCTION "public"."collect_wholesale_invoice_payment"(
  "p_invoice_id" bigint,
  "p_cash_amount" numeric DEFAULT 0,
  "p_cash_method" text DEFAULT 'cash',
  "p_wallet_amount" numeric DEFAULT 0,
  "p_settlement_amount" numeric DEFAULT 0
) RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.sales_invoices;
  v_cash numeric(12,2);
  v_wallet numeric(12,2);
  v_settle numeric(12,2);
  v_due numeric(12,2);
  v_tenant_id bigint;
  v_payment_id bigint;
begin
  if p_invoice_id is null then
    raise exception 'Invoice ID is required';
  end if;

  v_cash := greatest(coalesce(p_cash_amount, 0.00), 0.00);
  v_wallet := greatest(coalesce(p_wallet_amount, 0.00), 0.00);
  v_settle := greatest(coalesce(p_settlement_amount, 0.00), 0.00);

  if v_cash <= 0 and v_wallet <= 0 and v_settle <= 0 then
    raise exception 'Enter cash, store credit, or settlement';
  end if;

  select * into v_invoice
  from public.sales_invoices
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Payments can only be recorded on issued invoices';
  end if;

  if v_invoice.billing_profile_id is null then
    raise exception 'Billing profile is required';
  end if;

  v_due := coalesce(v_invoice.due_amount, 0.00);
  if (v_cash + v_wallet + v_settle) > v_due then
    raise exception 'Cash + credit + settlement cannot exceed due';
  end if;

  v_tenant_id := coalesce(v_invoice.parent_tenant_id, v_invoice.tenant_id);

  if v_cash > 0 then
    insert into public.global_payments (
      tenant_id, billing_profile_id, amount, unallocated_amount,
      payment_date, method, note
    ) values (
      v_tenant_id, v_invoice.billing_profile_id, v_cash, 0.00,
      current_date, coalesce(nullif(trim(p_cash_method), ''), 'cash'),
      'Wholesale invoice collect (cash)'
    ) returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_cash);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_cash, updated_at = now()
    where id = p_invoice_id;

    perform public.recompute_global_invoice_payment_status(p_invoice_id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_tenant_id,
      p_operating_tenant_id => coalesce(v_invoice.issued_by_tenant_id, v_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_tenant_id,
      p_type => 'credit',
      p_amount => v_cash,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'tenant_payment_received',
        'transaction_type', 'payment_received',
        'label', 'Payment Received',
        'invoice_id', p_invoice_id,
        'payment_id', v_payment_id,
        'method', coalesce(nullif(trim(p_cash_method), ''), 'cash')
      )
    );
  end if;

  if v_wallet > 0 then
    insert into public.wallet_accounts (
      tenant_id, entity_type, entity_id, currency_code,
      available_balance, locked_balance, pending_balance
    ) values (
      v_tenant_id, 'customer', v_invoice.billing_profile_id, 'BDT',
      0.0000, 0.0000, 0.0000
    ) on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

    insert into public.global_payments (
      tenant_id, billing_profile_id, amount, unallocated_amount,
      payment_date, method, note
    ) values (
      v_tenant_id, v_invoice.billing_profile_id, v_wallet, 0.00,
      current_date, 'wallet_credit',
      'Wholesale invoice collect (store credit)'
    ) returning id into v_payment_id;

    insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
    values (v_tenant_id, v_payment_id, p_invoice_id, v_wallet);

    update public.sales_invoices
    set paid_amount = coalesce(paid_amount, 0.00) + v_wallet, updated_at = now()
    where id = p_invoice_id;

    perform public.recompute_global_invoice_payment_status(p_invoice_id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_tenant_id,
      p_operating_tenant_id => coalesce(v_invoice.issued_by_tenant_id, v_tenant_id),
      p_entity_type => 'customer',
      p_entity_id => v_invoice.billing_profile_id,
      p_type => 'debit',
      p_amount => v_wallet,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_payment_id::text,
      p_allow_overdraft => false,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'apply_store_credit',
        'transaction_type', 'wallet_credit',
        'label', 'Applied store credit',
        'invoice_id', p_invoice_id,
        'payment_id', v_payment_id
      )
    );
  end if;

  if v_settle > 0 then
    perform public.apply_global_invoice_settlement_discount(p_invoice_id, v_settle, 'Wholesale collect settlement');
  end if;

  select * into v_invoice from public.sales_invoices where id = p_invoice_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'paid_amount', v_invoice.paid_amount,
    'due_amount', v_invoice.due_amount,
    'payment_status', v_invoice.payment_status,
    'written_off_amount', v_invoice.written_off_amount
  );
end;
$$;
