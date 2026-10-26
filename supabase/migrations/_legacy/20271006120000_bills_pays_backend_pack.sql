-- Bills & pays backend pack (SI5, WA12, SI6, BP3, BP4).
-- Hand-written: table renames + backfills cannot come from db diff (diff would drop/create tables).

-- ---------------------------------------------------------------------------
-- Retired writers (WA12) and bill COGS snapshot (SI5)
-- ---------------------------------------------------------------------------
drop function if exists public.snapshot_sales_invoice_item_costs(bigint);
drop function if exists public.collect_wholesale_invoice_payment(bigint, jsonb, numeric, numeric, text, date);
drop function if exists public.collect_wholesale_invoice_payment(bigint, numeric, text, numeric, numeric);
drop function if exists public.create_billing_profile_payment_with_allocations(bigint, bigint, numeric, date, text, text, text, jsonb);
drop function if exists public.record_batch_customer_payment(bigint, bigint, bigint, numeric, date, text, text, text, jsonb, jsonb, jsonb);
drop function if exists public.dispense_middleman_payout(bigint, numeric, text, text);

-- Compatibility views pin columns we drop. global_invoices is retired (BP4);
-- global_invoice_items is recreated below without unit_cost_price.
drop view if exists public.global_invoices;
drop view if exists public.global_invoice_items;

-- ---------------------------------------------------------------------------
-- SI5: bills store sell only. GP = shipment P&L.
-- ---------------------------------------------------------------------------
drop table if exists public.sales_invoice_item_costs;

alter table public.sales_invoice_items
  drop constraint if exists global_invoice_items_unit_cost_price_check;
alter table public.sales_invoice_items
  drop column if exists unit_cost_price;

-- ---------------------------------------------------------------------------
-- SI6: COD / fulfillment off the bill header (kept in channel_meta).
-- ---------------------------------------------------------------------------
update public.sales_invoices
set channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_strip_nulls(jsonb_build_object(
  'cod_charge_amount', nullif(cod_charge_amount, 0),
  'fulfillment_status', case when fulfillment_status::text <> 'pending' then fulfillment_status::text end
))
where coalesce(cod_charge_amount, 0) <> 0
   or fulfillment_status::text <> 'pending';

delete from public.sales_invoice_charges where charge_type::text = 'cod';

alter table public.sales_invoices
  drop constraint if exists global_invoices_cod_charge_amount_check;
alter table public.sales_invoices
  drop column if exists cod_charge_amount,
  drop column if exists fulfillment_status;

-- ---------------------------------------------------------------------------
-- BP3: bills / pays hang off profiles.id (customer profiles share billing_profiles ids).
-- ---------------------------------------------------------------------------
-- Re-fire party sync for any billing profile missing its profiles row.
update public.billing_profiles bp
set updated_at = bp.updated_at
where not exists (select 1 from public.profiles p where p.id = bp.id);

alter table public.sales_invoices add column if not exists profile_id bigint;
alter table public.global_payments add column if not exists profile_id bigint;

update public.sales_invoices set profile_id = billing_profile_id
where billing_profile_id is not null and profile_id is null;
update public.global_payments set profile_id = billing_profile_id
where billing_profile_id is not null and profile_id is null;

alter table public.sales_invoices
  add constraint bills_profile_id_fkey foreign key (profile_id)
  references public.profiles (id) on delete set null;
alter table public.global_payments
  add constraint pays_profile_id_fkey foreign key (profile_id)
  references public.profiles (id) on delete set null;

create index if not exists bills_profile_id_idx on public.sales_invoices using btree (profile_id);
create index if not exists pays_profile_id_idx on public.global_payments using btree (profile_id);

alter table public.sales_invoices drop column billing_profile_id;
alter table public.global_payments drop column billing_profile_id;

-- Pay source (spec PAY.source).
alter table public.global_payments
  add column if not exists source text not null default 'customer_cash';

update public.global_payments
set source = case
  when shop_order_id is not null then 'courier_remittance'
  when method in ('wallet_credit', 'store_credit') then 'store_credit'
  when method in ('bank', 'bank_transfer', 'wire_transfer', 'cheque') then 'bank'
  else 'customer_cash'
end;

alter table public.global_payments
  add constraint pays_source_check check (
    source = any (array['customer_cash'::text, 'bank'::text, 'store_credit'::text, 'courier_remittance'::text])
  );

alter table public.global_payments drop constraint if exists payments_method_check;
alter table public.global_payments
  add constraint payments_method_check check (
    method is null or method = any (array[
      'cash'::text, 'bank'::text, 'bank_transfer'::text, 'mobile_banking'::text, 'bkash'::text,
      'nagad'::text, 'other'::text, 'cheque'::text, 'rocket'::text, 'upay'::text, 'tap'::text,
      'card_pos'::text, 'wire_transfer'::text, 'paypal'::text, 'stripe'::text,
      'letter_of_credit'::text, 'cod'::text, 'split'::text, 'store_credit'::text
    ])
  );

-- ---------------------------------------------------------------------------
-- BP4: spec table names.
-- ---------------------------------------------------------------------------
alter table public.sales_invoices rename to bills;
alter table public.sales_invoice_items rename to bill_lines;
alter table public.sales_invoice_charges rename to bill_charges;
alter table public.global_payments rename to pays;
alter table public.global_payment_instruments rename to pay_instruments;
alter table public.invoice_payments rename to pay_allocations;
alter table public.wallet_accounts rename to cashbook_accounts;
alter table public.universal_wallet_ledger rename to cashbook_entries;

comment on table public.bills is 'Bills (spec). parent_tenant_id = parent books/stock, issued_by_tenant_id = selling child. Channel extras (COD, fulfillment) live in channel_meta.';

create view public.global_invoice_items with (security_invoker = 'false') as
select
  id,
  parent_tenant_id as tenant_id,
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
  created_at,
  updated_at,
  assigned_child_tenant_id,
  line_meta
from public.bill_lines;

alter view public.global_invoice_items owner to postgres;
revoke all on public.global_invoice_items from anon, authenticated, service_role;
grant references, trigger, truncate on public.global_invoice_items to anon, authenticated, service_role;

-- ---------------------------------------------------------------------------
-- Functions (bodies follow renamed tables / dropped columns)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public._undo_wallet_ledger_row_before_delete(p_row cashbook_entries)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.add_demand_bucket_item_internal(p_tenant_id bigint, p_billing_profile_id bigint, p_product_id bigint, p_source_type demand_bucket_source_type, p_source_id bigint DEFAULT NULL::bigint, p_snapshot jsonb DEFAULT '{}'::jsonb, p_quantity integer DEFAULT 1)
 RETURNS customer_demand_bucket_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.customer_demand_bucket_items;
  v_name text;
  v_image_url text;
  v_barcode text;
  v_product_code text;
  v_note text;
  v_quantity integer;
begin
  if p_tenant_id is null or p_billing_profile_id is null or p_product_id is null then
    raise exception 'tenant_id, billing_profile_id, and product_id are required';
  end if;

  v_quantity := greatest(coalesce(p_quantity, 1), 1);

  v_name := nullif(trim(coalesce(p_snapshot->>'name', '')), '');
  v_image_url := nullif(trim(coalesce(p_snapshot->>'image_url', '')), '');
  v_barcode := nullif(trim(coalesce(p_snapshot->>'barcode', '')), '');
  v_product_code := nullif(trim(coalesce(p_snapshot->>'product_code', '')), '');
  v_note := nullif(trim(coalesce(p_snapshot->>'note', '')), '');

  if v_name is null then
    select
      coalesce(p.name, 'Item'),
      p.image_url,
      p.barcode,
      p.product_code
    into v_name, v_image_url, v_barcode, v_product_code
    from public.products p
    where p.id = p_product_id;
  end if;

  insert into public.customer_demand_bucket_items (
    tenant_id,
    billing_profile_id,
    product_id,
    source_type,
    source_id,
    name,
    image_url,
    barcode,
    product_code,
    note,
    quantity,
    status
  ) values (
    p_tenant_id,
    p_billing_profile_id,
    p_product_id,
    p_source_type,
    p_source_id,
    coalesce(v_name, 'Item'),
    v_image_url,
    v_barcode,
    v_product_code,
    v_note,
    v_quantity,
    'open'
  )
  returning * into v_row;

  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.add_global_invoice_item(p_invoice_id bigint, p_global_stock_id bigint, p_quantity numeric, p_sell_price_amount numeric, p_line_discount_amount numeric DEFAULT 0, p_recipient_price_amount numeric DEFAULT NULL::numeric)
 RETURNS bill_lines
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.add_global_return_item(p_invoice_id bigint, p_invoice_item_id bigint, p_quantity numeric, p_return_face_amount numeric, p_return_accounting_amount numeric, p_return_charge_amount numeric DEFAULT 0, p_note text DEFAULT NULL::text, p_to_grade_tag_id bigint DEFAULT NULL::bigint, p_to_availability stock_availability DEFAULT 'held'::stock_availability)
 RETURNS sales_return_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.add_pbc_backlog_to_costing_file(p_file_id bigint, p_backlog_ids bigint[])
 RETURNS SETOF bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (
    public.can_admin_manage_costing_file(v_file.tenant_id)
    OR public.can_staff_access_costing_file(v_file.tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.billing_profile_id IS NULL THEN
    RAISE EXCEPTION 'costing file % must have a billing_profile_id assigned before consuming backlog', p_file_id;
  END IF;

  IF p_backlog_ids IS NULL OR array_length(p_backlog_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  FOR v_backlog IN
    SELECT *
    FROM public.product_based_costing_backlog_items
    WHERE id = ANY(p_backlog_ids)
      AND tenant_id = v_file.tenant_id
      AND billing_profile_id = v_file.billing_profile_id
  LOOP
    INSERT INTO public.product_based_costing_items (
      product_based_costing_file_id,
      product_id,
      name,
      image_url,
      quantity,
      confirmed_quantity,
      delivered_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      v_backlog.open_quantity,
      NULL,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    RETURN NEXT v_new_item_id;
  END LOOP;

  RETURN;
END;
$function$;

CREATE OR REPLACE FUNCTION public.add_pbc_backlog_to_file(p_file_id bigint, p_backlog_ids bigint[])
 RETURNS bigint[]
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_file public.product_based_costing_files%ROWTYPE;
  v_backlog public.product_based_costing_backlog_items%ROWTYPE;
  v_new_item_id bigint;
  v_added_ids bigint[] := ARRAY[]::bigint[];
BEGIN
  SELECT * INTO v_file
  FROM public.product_based_costing_files
  WHERE id = p_file_id;

  IF v_file.id IS NULL THEN
    RAISE EXCEPTION 'costing file % not found', p_file_id;
  END IF;

  IF NOT (
    public.can_admin_manage_costing_file(v_file.tenant_id)
    OR public.can_staff_access_costing_file(v_file.tenant_id)
  ) THEN
    RAISE EXCEPTION 'access denied for tenant %', v_file.tenant_id;
  END IF;

  IF v_file.billing_profile_id IS NULL THEN
    RAISE EXCEPTION 'costing file % must have a billing_profile_id assigned before consuming backlog', p_file_id;
  END IF;

  IF p_backlog_ids IS NULL OR array_length(p_backlog_ids, 1) IS NULL THEN
    RETURN v_added_ids;
  END IF;

  FOR v_backlog IN
    SELECT *
    FROM public.product_based_costing_backlog_items
    WHERE id = ANY(p_backlog_ids)
      AND tenant_id = v_file.tenant_id
      AND billing_profile_id = v_file.billing_profile_id
  LOOP
    INSERT INTO public.product_based_costing_items (
      product_based_costing_file_id,
      product_id,
      name,
      image_url,
      quantity,
      confirmed_quantity,
      delivered_quantity,
      price_gbp,
      product_weight,
      package_weight,
      barcode,
      product_code
    )
    VALUES (
      v_file.id,
      v_backlog.product_id,
      v_backlog.name,
      v_backlog.image_url,
      v_backlog.open_quantity,
      v_backlog.open_quantity,
      NULL,
      v_backlog.price_gbp,
      v_backlog.product_weight::integer,
      v_backlog.package_weight::integer,
      v_backlog.barcode,
      v_backlog.product_code
    )
    RETURNING id INTO v_new_item_id;

    DELETE FROM public.product_based_costing_backlog_items
    WHERE id = v_backlog.id;

    v_added_ids := array_append(v_added_ids, v_new_item_id);
  END LOOP;

  RETURN v_added_ids;
END;
$function$;

CREATE OR REPLACE FUNCTION public.advance_dropship_order_status(p_order_id bigint, p_target_status shop_order_status, p_remittance_ref text DEFAULT NULL::text, p_bank_trx_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  end if;

  if p_target_status in ('shipped'::public.shop_order_status, 'delivered'::public.shop_order_status) then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Use ship_dropship_order_and_issue_merchant_bill or mark_dropship_order_delivered instead of advance to %s',
        p_target_status
      )
    );
  end if;

  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed')
     and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in (
      'processing', 'ready_for_pickup', 'returned', 'payment_received', 'cancelled'
    ) then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format(
        'Invalid status transition for dropship order from %s to %s',
        v_current_status,
        p_target_status
      )
    );
  end if;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.payment_status in ('paid', 'partially_paid') then
      return jsonb_build_object(
        'success', false,
        'error', 'Cannot rollback: merchant bill has payments allocated'
      );
    end if;
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status = 'cancelled' then
    perform public.release_dropship_order_stock(p_order_id, true);
  end if;

  if p_target_status = 'processing' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.cashbook_entries
    where source_type = 'shop_order'
      and (
        source_id = p_order_id::text
        or source_id = v_order.order_no
        or source_id = v_invoice.invoice_no
      )
      and tenant_id = v_order.tenant_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.bills where id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$function$;

CREATE OR REPLACE FUNCTION public.allocate_payment_to_global_invoice(p_tenant_id bigint, p_payment_id bigint, p_global_invoice_id bigint, p_amount numeric)
 RETURNS pay_allocations
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  -- Lock invoice
  select * into v_invoice from public.bills where id = p_global_invoice_id for update;
  if not found then raise exception 'Invoice not found.'; end if;
  if v_invoice.parent_tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;

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
  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
  values (p_tenant_id, p_payment_id, p_global_invoice_id, p_amount)
  returning * into v_row;

  -- Update payment unallocated amount
  update public.pays
  set unallocated_amount = unallocated_amount - p_amount
  where id = p_payment_id;

  -- Update invoice paid amount
  update public.bills
  set paid_amount = coalesce(paid_amount, 0.00) + p_amount, updated_at = now()
  where id = p_global_invoice_id;

  -- Recompute invoice payment status and due_amount
  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_dropship_order_charge_lines(p_order_id bigint, p_charge_lines jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_line jsonb;
  v_delivery_amount numeric(12,2);
  v_print_amount numeric(12,2);
  v_packing_amount numeric(12,2);
  v_cod_amount numeric(12,2);
  v_deduct_delivery boolean;
  v_deduct_print boolean;
  v_deduct_packing boolean;
  v_deduct_cod boolean;
  v_has_delivery boolean := false;
  v_has_print boolean := false;
  v_has_packing boolean := false;
  v_has_cod boolean := false;
begin
  if p_charge_lines is null or jsonb_typeof(p_charge_lines) <> 'array' then
    return;
  end if;

  for v_line in select value from jsonb_array_elements(p_charge_lines)
  loop
    case coalesce(v_line->>'charge_type', '')
      when 'delivery' then
        v_delivery_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_delivery := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_delivery := true;
      when 'print' then
        v_print_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_print := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_print := true;
      when 'packing' then
        v_packing_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_packing := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_packing := true;
      when 'cod' then
        v_cod_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_cod := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_cod := true;
      else
        null;
    end case;
  end loop;

  if not (v_has_delivery or v_has_print or v_has_packing or v_has_cod) then
    return;
  end if;

  update public.shop_orders o
  set
    delivery_charge_amount = case when v_has_delivery then v_delivery_amount else o.delivery_charge_amount end,
    print_charge_amount = case when v_has_print then v_print_amount else o.print_charge_amount end,
    packing_charge_amount = case when v_has_packing then v_packing_amount else o.packing_charge_amount end,
    cod_charge_amount = case when v_has_cod then v_cod_amount else o.cod_charge_amount end,
    deduct_delivery_from_margin = case when v_has_delivery then v_deduct_delivery else o.deduct_delivery_from_margin end,
    deduct_print_from_margin = case when v_has_print then v_deduct_print else o.deduct_print_from_margin end,
    deduct_packing_from_margin = case when v_has_packing then v_deduct_packing else o.deduct_packing_from_margin end,
    deduct_cod_from_margin = case when v_has_cod then v_deduct_cod else o.deduct_cod_from_margin end,
    updated_at = now()
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_dropship_payout_settlement_fifo(p_tenant_id bigint, p_billing_profile_id bigint, p_amount numeric)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  v_parent_tenant_id bigint;
  r record;
  v_hold numeric;
  v_paid numeric;
  v_outstanding numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  for r in
    select o.id
    from public.shop_orders o
    where o.tenant_id = p_tenant_id
      and o.billing_profile_id = p_billing_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0)
    into v_hold
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

    select coalesce(sum(u.amount), 0)
    into v_paid
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_billing_profile_id
      and u.type = 'debit'
      and coalesce(u.metadata->>'transaction_type', '') = 'profit_paid_out'
      and coalesce(u.metadata->>'shop_order_id', u.metadata->>'order_id', '') = r.id::text;

    v_outstanding := greatest(v_hold - v_paid, 0);

    if v_outstanding <= 0 then
      continue;
    end if;

    if v_remaining >= v_outstanding then
      update public.shop_orders
      set payout_settlement_status = 'paid',
          updated_at = now()
      where id = r.id;
      v_remaining := v_remaining - v_outstanding;
    else
      update public.shop_orders
      set payout_settlement_status = 'partial',
          updated_at = now()
      where id = r.id;
      v_remaining := 0;
    end if;
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.apply_global_invoice_settlement_discount(p_invoice_id bigint, p_amount numeric, p_note text DEFAULT NULL::text)
 RETURNS bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.apply_global_invoice_target_total(p_invoice_id bigint, p_target_total numeric, p_dry_run boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.build_default_dropship_settlement_charge_lines(p_order shop_orders)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
AS $function$
begin
  return jsonb_build_array(
    jsonb_build_object(
      'charge_type', 'delivery',
      'amount', coalesce(p_order.delivery_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_delivery_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'print',
      'amount', coalesce(p_order.print_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_print_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'packing',
      'amount', coalesce(p_order.packing_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_packing_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'return',
      'amount', coalesce(p_order.return_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_return_charge_from_middle_man, true) then 'merchant' else 'company' end
    ),
    jsonb_build_object(
      'charge_type', 'cod',
      'amount', coalesce(p_order.cod_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_cod_from_margin, false) then 'merchant' else 'recipient' end
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.build_dropship_tenant_b2b_invoice_payload(p_order_id bigint, p_invoice_id bigint DEFAULT NULL::bigint, p_invoice_no text DEFAULT NULL::text, p_billing_profile_id bigint DEFAULT NULL::bigint, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_billing_profile_id bigint;
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

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required on the order');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_channel_meta := jsonb_strip_nulls(jsonb_build_object(
    'cod_collect_amount', v_order.cod_collect_amount,
    'collection_source', 'billing_profile',
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

    v_item_sell_price := coalesce(v_pick.unit_sell_price_amount, v_pick.final_price_amount, 0);
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
      'name_snapshot', coalesce(v_pick.stock_name, v_pick.line_name),
      'barcode_snapshot', v_pick.stock_barcode,
      'product_code_snapshot', v_pick.stock_product_code,
      'quantity', v_pick.pick_quantity,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_pick.stock_assigned_child,
      'line_meta', jsonb_build_object('resell_price_amount', v_resell_price)
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

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
        'billing_profile_id', v_billing_profile_id,
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
        'collection_source', 'billing_profile'::public.collection_source_type,
        'channel_meta', v_channel_meta
      )),
      'items', v_items,
      'shop_order_id', p_order_id
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_demand_bucket_item(p_bucket_item_id bigint)
 RETURNS customer_demand_bucket_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.customer_demand_bucket_items;
begin
  select * into v_row
  from public.customer_demand_bucket_items
  where id = p_bucket_item_id;

  if not found then
    raise exception 'bucket item not found: %', p_bucket_item_id;
  end if;

  if v_row.status <> 'open' then
    raise exception 'bucket item % is not open', p_bucket_item_id;
  end if;

  if not public.can_access_demand_bucket_profile(v_row.tenant_id, v_row.billing_profile_id, true) then
    raise exception 'access denied';
  end if;

  update public.customer_demand_bucket_items
  set
    status = 'cancelled',
    updated_at = now()
  where id = p_bucket_item_id
  returning * into v_row;

  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.cancel_shop_order_dropship(p_order_id bigint, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_invoice public.bills%rowtype;
  v_allowed boolean := false;
  v_pick_count integer := 0;
  v_released_picks integer := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'not a dropship order');
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_allowed := v_order.status in (
    'submitted', 'draft', 'placed', 'confirmed', 'processing', 'ready_for_pickup'
  );

  if not v_allowed then
    return jsonb_build_object(
      'success', false,
      'error', format('cannot cancel order in status %s', v_order.status)
    );
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks where order_id = p_order_id;

  if v_order.status = 'ready_for_pickup' and v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
      perform public.unpost_global_invoice(v_order.global_invoice_id);
    end if;

    delete from public.cashbook_entries
    where source_type = 'shop_order'
      and (
        source_id = p_order_id::text
        or source_id = v_order.order_no
        or source_id = v_invoice.invoice_no
      )
      and tenant_id = v_order.tenant_id;

    delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
    delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
    delete from public.bills where id = v_order.global_invoice_id;

    update public.shop_orders
    set global_invoice_id = null, updated_at = now()
    where id = p_order_id;
  elsif v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.invoice_status in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.bills where id = v_order.global_invoice_id;
      update public.shop_orders set global_invoice_id = null, updated_at = now() where id = p_order_id;
    end if;
  end if;

  perform public.release_dropship_order_stock(p_order_id, true);
  v_released_picks := v_pick_count;

  delete from public.shop_order_item_stock_picks where order_id = p_order_id;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = false,
    unavailable_reason = null,
    unavailable_at = null,
    unavailable_by_email = null,
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where order_id = p_order_id;

  update public.shop_orders
  set status = 'cancelled'::public.shop_order_status, updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'new_status', 'cancelled',
    'restock_summary', jsonb_build_object(
      'pick_rows_released', v_released_picks,
      'reason', nullif(trim(p_reason), '')
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.canonicalize_dropship_order_wallet_source_ids(p_order_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.confirm_courier_remittance_to_tenant(p_order_id bigint, p_courier_charge numeric DEFAULT 0.00, p_remittance_ref text DEFAULT NULL::text, p_bank_trx_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order record;
  v_invoice record;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
  v_ref text;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  end if;

  if v_order.status <> 'delivered' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" to remit)', v_order.order_no, v_order.status)
    );
  end if;

  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id;
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.id is not null and v_invoice.invoice_status = 'draft'::public.global_invoice_status then
      perform public.post_global_invoice(v_order.global_invoice_id);
    end if;
  end if;

  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);
  v_ref := coalesce(nullif(trim(p_remittance_ref), ''), 'REMIT-' || v_order.order_no);

  return public.record_dropship_courier_remittance(
    p_order_id => p_order_id,
    p_net_amount => v_net_remitted,
    p_remittance_ref => v_ref,
    p_bank_trx_id => p_bank_trx_id,
    p_payment_date => current_date,
    p_method => 'cash',
    p_note => null,
    p_courier_charge => v_charge
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.convert_wholesale_draft_to_retail(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.create_cargo_company_with_wallet(p_tenant_id bigint, p_name text, p_code text, p_email text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.cargo_companies;
  v_wallet public.cashbook_accounts;
  v_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  if exists (
    select 1 from public.tenants t where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'cargo companies belong on parent tenants only';
  end if;

  v_code := upper(trim(p_code));
  if v_code is null or v_code = '' then
    raise exception 'code is required';
  end if;

  if v_code = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default cargo company';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  insert into public.cargo_companies (
    parent_tenant_id,
    name,
    code,
    email,
    phone,
    address,
    notes,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    trim(p_name),
    v_code,
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_notes), ''),
    false,
    true
  )
  returning * into v_row;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'cargo_company',
    v_row.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'cargo_company', to_jsonb(v_row),
    'wallet', to_jsonb(v_wallet)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_customer_account(p_tenant_id bigint, p_group_name text, p_admin_name text DEFAULT NULL::text, p_admin_email text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_accent_color text DEFAULT '#B45F34'::text, p_phone_country_code text DEFAULT '+880'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_group public.customer_groups;
  v_billing_profile public.billing_profiles;
  v_books_id bigint;
  v_clean_phone text;
  v_clean_code text;
  v_clean_group_name text;
  v_clean_color text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.can_administer_customer_group(v_books_id) then
    raise exception 'Only parent tenant admins can create customer groups';
  end if;

  v_clean_group_name := trim(coalesce(p_group_name, ''));
  v_clean_phone := nullif(regexp_replace(trim(coalesce(p_phone, '')), '[^0-9]', '', 'g'), '');
  v_clean_code := coalesce(nullif(trim(coalesce(p_phone_country_code, '')), ''), '+880');
  if v_clean_code not like '+%' then
    v_clean_code := '+' || v_clean_code;
  end if;
  v_clean_color := coalesce(nullif(trim(coalesce(p_accent_color, '')), ''), '#B45F34');

  if v_clean_group_name = '' then
    raise exception 'Group / Company name is required';
  end if;
  if v_clean_phone is null then
    raise exception 'Phone is required';
  end if;

  if exists (
    select 1
    from public.billing_profiles bp
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    where bp.parent_tenant_id = v_books_id
      and bp.phone_country_code = v_clean_code
      and bp.phone = v_clean_phone
      and bp.is_phone_unique
      and (cg.id is null or cg.deleted_at is null)
  ) then
    raise exception 'This phone is already used by another customer';
  end if;

  insert into public.customer_groups (
    tenant_id,
    parent_tenant_id,
    name,
    accent_color,
    is_active
  ) values (
    v_books_id,
    v_books_id,
    v_clean_group_name,
    v_clean_color,
    true
  )
  returning * into v_group;

  select * into v_billing_profile
  from public.billing_profiles
  where customer_group_id = v_group.id
  order by id asc
  limit 1;

  if v_billing_profile.id is null then
    insert into public.billing_profiles (
      tenant_id,
      parent_tenant_id,
      customer_group_id,
      name,
      phone,
      phone_country_code,
      created_at,
      updated_at
    ) values (
      v_books_id,
      v_books_id,
      v_group.id,
      v_clean_group_name,
      v_clean_phone,
      v_clean_code,
      now(),
      now()
    )
    returning * into v_billing_profile;
  else
    update public.billing_profiles
    set
      name = v_clean_group_name,
      phone = v_clean_phone,
      phone_country_code = v_clean_code,
      parent_tenant_id = v_books_id,
      tenant_id = v_books_id,
      updated_at = now()
    where id = v_billing_profile.id
    returning * into v_billing_profile;
  end if;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    locked_balance,
    pending_balance
  ) values (
    v_books_id,
    v_books_id,
    'customer',
    v_billing_profile.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

  return jsonb_build_object(
    'id', v_group.id,
    'customer_group_id', v_group.id,
    'billing_profile_id', v_billing_profile.id,
    'group_name', v_group.name,
    'admin_name', v_billing_profile.name,
    'email', v_billing_profile.email,
    'phone', concat_ws(' ', v_billing_profile.phone_country_code, v_billing_profile.phone),
    'address', v_billing_profile.address,
    'accent_color', coalesce(v_group.accent_color, '#B45F34'),
    'is_active', v_group.is_active,
    'member_count', 0,
    'wallet_available_balance', 0,
    'created_at', v_group.created_at
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_invoice_from_preorder_demand_document(p_tenant_id bigint, p_document_type text, p_document_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_billing_profile_id bigint;
  v_operating_tenant_id bigint;
  v_existing_invoice_id bigint;
  v_doc_status text;
  v_items jsonb := '[]'::jsonb;
  v_pick_elem jsonb;
  v_pd record;
  v_sell_price numeric(12,2);
  v_global_stock_id bigint;
  v_qty integer;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.billing_profile_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_billing_profile_id, v_existing_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.billing_profile_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_billing_profile_id, v_existing_invoice_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id;

    if v_operating_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_operating_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document must be procuring to create invoice from demand';
  end if;

  if v_billing_profile_id is null then
    raise exception 'billing_profile_id is required on document';
  end if;

  if v_existing_invoice_id is not null then
    return jsonb_build_object(
      'success', true,
      'invoice_id', v_existing_invoice_id,
      'created', false
    );
  end if;

  if v_doc_type = 'shop_order' then
    for v_pd in
      select
        pd.stock_picks,
        coalesce(oi.final_price_amount, oi.staff_offer_amount, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.shop_order_items oi
        on pd.source_type = 'shop_order_item'
        and pd.source_id = oi.id
      where oi.order_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  else
    for v_pd in
      select
        pd.stock_picks,
        coalesce(pci.offer_price, 0)::numeric(12,2) as sell_price
      from public.preorder_demand pd
      inner join public.product_based_costing_items pci
        on pd.source_type = 'pbc_costing_item'
        and pd.source_id = pci.id
      where pci.product_based_costing_file_id = p_document_id
        and jsonb_array_length(coalesce(pd.stock_picks, '[]'::jsonb)) > 0
    loop
      v_sell_price := v_pd.sell_price;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_global_stock_id is not null and v_qty > 0 then
          v_items := v_items || jsonb_build_array(jsonb_build_object(
            'global_stock_id', v_global_stock_id,
            'quantity', v_qty,
            'sell_price_amount', v_sell_price
          ));
        end if;
      end loop;
    end loop;
  end if;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'at least one stock pick is required before marking ready for shipment';
  end if;

  v_payload := jsonb_build_object(
    'invoice', jsonb_build_object(
      'invoice_type', 'wholesale',
      'billing_profile_id', v_billing_profile_id
    ),
    'items', v_items,
    'issue', false
  );

  v_result := public.create_sales_invoice_from_payload(v_operating_tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to create invoice from demand');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

  update public.bills
  set
    invoice_status = 'proforma_generated'::public.global_invoice_status,
    shop_order_id = case when v_doc_type = 'shop_order' then p_document_id else shop_order_id end,
    updated_at = now()
  where id = v_invoice_id
    and invoice_status = 'draft'::public.global_invoice_status;

  if v_doc_type = 'shop_order' then
    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = p_document_id
      and global_invoice_id is null;
  else
    update public.product_based_costing_files
    set
      invoice_id = v_invoice_id,
      updated_at = now()
    where id = p_document_id
      and invoice_id is null;
  end if;

  return v_result || jsonb_build_object(
    'created', true,
    'invoice_status', 'proforma_generated'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_sales_invoice(p_tenant_id bigint, p_invoice_no text DEFAULT NULL::text, p_invoice_type global_invoice_type DEFAULT 'wholesale'::global_invoice_type, p_billing_profile_id bigint DEFAULT NULL::bigint, p_recipient_profile_id bigint DEFAULT NULL::bigint, p_recipient_name text DEFAULT NULL::text, p_recipient_phone text DEFAULT NULL::text, p_recipient_address text DEFAULT NULL::text, p_retail_billing_mode retail_billing_mode DEFAULT NULL::retail_billing_mode, p_due_date date DEFAULT NULL::date, p_note text DEFAULT NULL::text, p_invoice_date date DEFAULT NULL::date)
 RETURNS bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  if p_billing_profile_id is not null then
    if not exists (
      select 1 from public.billing_profiles
      where id = p_billing_profile_id
        and (tenant_id = v_issued_by or tenant_id = v_parent_id or parent_tenant_id = v_parent_id)
    ) then
      raise exception 'billing profile not accessible for this tenant';
    end if;
  end if;

  if p_recipient_profile_id is not null then
    if not exists (
      select 1 from public.recipient_profiles
      where id = p_recipient_profile_id
        and (tenant_id = v_issued_by or tenant_id = v_parent_id or parent_tenant_id = v_parent_id)
    ) then
      raise exception 'recipient profile not accessible for this tenant';
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
    v_collection_source := 'billing_profile'::public.collection_source_type;
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
$function$;

CREATE OR REPLACE FUNCTION public.create_sales_invoice(p_tenant_id bigint, p_invoice_no text, p_billing_profile_id bigint, p_invoice_type global_invoice_type DEFAULT 'wholesale'::global_invoice_type, p_source_module global_source_module DEFAULT 'wholesale'::global_source_module, p_recipient_name text DEFAULT NULL::text, p_recipient_phone text DEFAULT NULL::text, p_recipient_address text DEFAULT NULL::text, p_recipient_party_id bigint DEFAULT NULL::bigint, p_middle_man_payout_amount numeric DEFAULT NULL::numeric, p_note text DEFAULT NULL::text)
 RETURNS bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.bills;
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

  insert into public.bills (
    parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type,
    profile_id,
    recipient_name, recipient_phone, recipient_address,
    collection_source, note, due_amount
  )
  values (
    v_parent_id, v_issued_by, trim(p_invoice_no), v_invoice_type,
    p_billing_profile_id,
    v_recipient_name, v_recipient_phone, v_recipient_address,
    v_collection_source, nullif(trim(coalesce(p_note, '')), ''), 0
  )
  returning * into v_row;

  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_sales_invoice_from_payload(p_tenant_id bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  select * into v_invoice
  from public.create_sales_invoice(
    p_tenant_id => p_tenant_id,
    p_invoice_no => coalesce(nullif(trim(v_inv->>'invoice_no'), ''), ''),
    p_invoice_type => v_invoice_type,
    p_billing_profile_id => nullif(v_inv->>'billing_profile_id', '')::bigint,
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
    updated_at = now()
  where id = v_invoice_id;

  for v_item_elem in select value from jsonb_array_elements(v_items) as t(value) loop
    v_global_stock_id := nullif(v_item_elem->>'global_stock_id', '')::bigint;
    v_quantity := nullif(v_item_elem->>'quantity', '')::numeric;
    v_sell_price := nullif(v_item_elem->>'sell_price_amount', '')::numeric;
    v_line_discount := coalesce(nullif(v_item_elem->>'line_discount_amount', '')::numeric, 0);
    v_line_meta := coalesce(v_item_elem->'line_meta', '{}'::jsonb);

    if v_global_stock_id is null then
      return jsonb_build_object('success', false, 'error', 'each item requires global_stock_id');
    end if;
    if v_quantity is null or v_quantity <= 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires quantity > 0');
    end if;
    if v_sell_price is null or v_sell_price < 0 then
      return jsonb_build_object('success', false, 'error', 'each item requires sell_price_amount >= 0');
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
    'billing_profile_id', v_invoice.profile_id,
    'collection_source', v_invoice.collection_source,
    'item_ids', to_jsonb(v_item_ids),
    'issued', v_issue,
    'shop_order_id', v_shop_order_id
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_vendor_with_wallet(p_tenant_id bigint, p_name text, p_code text, p_market_code text, p_email text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_website text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vendor public.vendors;
  v_wallet public.cashbook_accounts;
  v_currency_code text := 'BDT';
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;
    v_books_id := null;
  else
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
    v_books_id := p_tenant_id;
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    v_books_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  if v_books_id is not null then
    insert into public.cashbook_accounts (
      tenant_id,
      entity_type,
      entity_id,
      currency_code,
      available_balance,
      pending_balance,
      locked_balance
    )
    values (
      v_books_id,
      'vendor',
      v_vendor.id,
      v_currency_code,
      0.0000,
      0.0000,
      0.0000
    )
    on conflict (tenant_id, entity_type, entity_id, currency_code)
    do update set updated_at = now()
    returning * into v_wallet;
  end if;

  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.create_vendor_with_wallet(p_tenant_id bigint, p_name text, p_code text, p_market_code text, p_email text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_address text DEFAULT NULL::text, p_website text DEFAULT NULL::text, p_currency_code text DEFAULT 'BDT'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_vendor public.vendors%rowtype;
  v_wallet public.cashbook_accounts%rowtype;
  v_currency_code text := coalesce(nullif(trim(p_currency_code), ''), 'BDT');
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if not (
    public.is_superadmin()
    or public.user_can_manage_parent_tenant(p_tenant_id)
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  ) then
    raise exception 'not allowed';
  end if;

  if exists (
    select 1 from public.tenants t where t.id = p_tenant_id and t.parent_id is not null
  ) then
    raise exception 'vendors belong on parent tenants only';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if nullif(trim(p_code), '') is null then
    raise exception 'code is required';
  end if;

  if upper(trim(p_code)) = 'DEFAULT' then
    raise exception 'code DEFAULT is reserved for the system default vendor';
  end if;

  if nullif(trim(p_market_code), '') is null then
    raise exception 'market_code is required';
  end if;

  if exists (
    select 1
    from public.vendors v
    where v.parent_tenant_id = p_tenant_id
      and upper(trim(v.code)) = upper(trim(p_code))
  ) then
    raise exception 'vendor code % already exists for this tenant', upper(trim(p_code));
  end if;

  if p_email is not null and trim(p_email) <> '' then
    if exists (
      select 1
      from public.vendors v
      where v.parent_tenant_id = p_tenant_id
        and lower(trim(v.email)) = lower(trim(p_email))
    ) then
      raise exception 'vendor email % already exists for this tenant', lower(trim(p_email));
    end if;
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    email,
    phone,
    address,
    website
  )
  values (
    p_tenant_id,
    trim(p_name),
    upper(trim(p_code)),
    upper(trim(p_market_code)),
    nullif(lower(trim(p_email)), ''),
    nullif(trim(p_phone), ''),
    nullif(trim(p_address), ''),
    nullif(trim(p_website), '')
  )
  returning * into v_vendor;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    coalesce(v_vendor.parent_tenant_id, p_tenant_id),
    'vendor',
    v_vendor.id,
    v_currency_code,
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now()
  returning * into v_wallet;

  return jsonb_build_object(
    'vendor', to_jsonb(v_vendor),
    'wallet', to_jsonb(v_wallet)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.dispense_middleman_payout_from_tenant(p_tenant_id bigint, p_billing_profile_id bigint, p_amount numeric, p_payout_method text DEFAULT 'bank_transfer'::text, p_reference_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_profile public.billing_profiles;
  v_payout_id text;
  v_parent_tenant_id bigint;
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

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_payout_id := 'PO-' || gen_random_uuid()::text;

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
      'billing_profile_id', p_billing_profile_id,
      'billing_profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
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
$function$;

CREATE OR REPLACE FUNCTION public.ensure_default_cargo_company(p_tenant_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tenant public.tenants%rowtype;
  v_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_cargo_company requires a parent tenant (got child %)', p_tenant_id;
  end if;

  if auth.uid() is not null then
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
  end if;

  select id into v_id
  from public.cargo_companies
  where parent_tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  select id into v_id
  from public.cargo_companies
  where parent_tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_id is not null then
    update public.cargo_companies
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Cargo Company'),
        is_active = true,
        updated_at = now()
    where id = v_id;
    return v_id;
  end if;

  insert into public.cargo_companies (
    parent_tenant_id,
    name,
    code,
    is_default,
    is_active
  )
  values (
    p_tenant_id,
    'Default Cargo Company',
    'DEFAULT',
    true,
    true
  )
  returning id into v_id;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'cargo_company',
    v_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_default_vendor(p_tenant_id bigint)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_tenant public.tenants%rowtype;
  v_vendor_id bigint;
  v_market_code text;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  select * into v_tenant
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant % not found', p_tenant_id;
  end if;

  if v_tenant.parent_id is not null then
    raise exception 'ensure_default_vendor requires a parent tenant (got child %)', p_tenant_id;
  end if;

  if auth.uid() is not null then
    if not (
      public.is_superadmin()
      or public.user_can_manage_parent_tenant(p_tenant_id)
      or exists (
        select 1
        from public.memberships m
        where m.tenant_id = p_tenant_id
          and lower(trim(m.email)) = public.current_user_email()
          and m.role in ('admin', 'staff')
          and m.is_active = true
      )
    ) then
      raise exception 'not allowed';
    end if;
  end if;

  select id into v_vendor_id
  from public.vendors
  where parent_tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_vendor_id is not null then
    return v_vendor_id;
  end if;

  select id into v_vendor_id
  from public.vendors
  where parent_tenant_id = p_tenant_id
    and upper(trim(code)) = 'DEFAULT'
  limit 1;

  if v_vendor_id is not null then
    update public.vendors
    set is_default = true,
        name = coalesce(nullif(trim(name), ''), 'Default Vendor'),
        updated_at = now()
    where id = v_vendor_id;
    return v_vendor_id;
  end if;

  select upper(trim(code)) into v_market_code
  from public.global_markets
  where is_active = true
  order by id asc
  limit 1;

  if v_market_code is null or v_market_code = '' then
    v_market_code := 'BD';
  end if;

  insert into public.vendors (
    parent_tenant_id,
    name,
    code,
    market_code,
    is_default
  )
  values (
    p_tenant_id,
    'Default Vendor',
    'DEFAULT',
    v_market_code,
    true
  )
  returning id into v_vendor_id;

  insert into public.cashbook_accounts (
    tenant_id,
    parent_tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
    p_tenant_id,
    p_tenant_id,
    'vendor',
    v_vendor_id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code)
  do update set updated_at = now();

  return v_vendor_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.ensure_dropship_courier_cod_receivable(p_order_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_parent_tenant_id bigint;
  v_courier_id bigint;
  v_cod numeric(12,2) := 0.00;
  v_delivery_charge numeric(12,2) := 0.00;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return;
  end if;

  if v_order.status not in (
    'delivered'::public.shop_order_status,
    'payment_received'::public.shop_order_status
  ) then
    return;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if exists (
    select 1
    from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    return;
  end if;

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  if v_cod <= 0.00 then
    return;
  end if;

  if v_order.courier_service_id is null then
    raise exception 'Courier service is required before booking COD receivable on order #%', v_order.order_no;
  end if;

  select cs.wallet_entity_id
  into v_courier_id
  from public.courier_services cs
  where cs.id = v_order.courier_service_id;

  if v_courier_id is null or v_courier_id <= 0 then
    raise exception 'Courier wallet is not configured for order #%', v_order.order_no;
  end if;

  if exists (
    select 1
    from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and entity_id = v_courier_id
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and coalesce(metadata->>'purpose', '') in ('courier_cod_receivable', 'delivered_costing')
  ) then
    return;
  end if;

  v_delivery_charge := coalesce(v_order.delivery_charge_amount, 0.00);

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => v_order.tenant_id,
    p_entity_type => 'courier',
    p_entity_id => v_courier_id,
    p_type => 'credit',
    p_amount => v_cod,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'cod_pending',
      'purpose', 'courier_cod_receivable',
      'transaction_type', 'courier_cod_receivable',
      'label', 'Courier COD receivable',
      'order_no', v_order.order_no,
      'order_id', p_order_id,
      'gross_cod', v_cod,
      'delivery_charge', v_delivery_charge,
      'courier_service_id', v_order.courier_service_id
    )
  );

  update public.dropship_order_settlements
  set
    courier_cod_booked_at = coalesce(courier_cod_booked_at, now()),
    updated_at = now()
  where shop_order_id = p_order_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.fill_preorder_demand_oldest_stock_for_document(p_tenant_id bigint, p_document_type text, p_document_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_parent_tenant_id bigint;
  v_updated integer := 0;
  v_skipped integer := 0;
  r record;
  v_stock record;
  v_total_avail integer := 0;
  v_remaining integer;
  v_avail integer;
  v_take integer;
  v_picks jsonb;
  v_delivered integer;
  v_db_reserved integer;
  v_run_reserved integer;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  create temp table if not exists fifo_run_pick_reserve (
    global_stock_id bigint primary key,
    reserved_qty integer not null default 0
  ) on commit delete rows;
  delete from fifo_run_pick_reserve where true;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.billing_profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status not in ('procuring', 'packed') then
    raise exception 'document is not open for stock pick updates';
  end if;

  select coalesce(t.parent_id, t.id) into v_parent_tenant_id
  from public.tenants t
  where t.id = v_line_tenant_id;

  for r in
    select
      q.source_type,
      q.source_id,
      q.tenant_id,
      q.product_id,
      q.need_qty
    from (
      select
        'shop_order_item'::public.preorder_demand_source_type as source_type,
        oi.id as source_id,
        o.tenant_id,
        oi.product_id,
        greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as need_qty
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where v_doc_type = 'shop_order'
        and o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
      union all
      select
        'pbc_costing_item'::public.preorder_demand_source_type,
        pci.id,
        f.tenant_id,
        pci.product_id,
        greatest(
          case
            when pci.assigned_shipment_id is not null then 0
            else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
          end,
          0
        )::integer
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where v_doc_type = 'pbc_costing_file'
        and f.id = p_document_id
        and f.billing_profile_id is not null
    ) q
    order by q.source_id
  loop
    if r.product_id is null or r.need_qty <= 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    if exists (
      select 1
      from public.preorder_demand pd
      where pd.source_type = r.source_type
        and pd.source_id = r.source_id
        and public.sum_preorder_stock_picks(pd.stock_picks) > 0
    ) then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_total_avail := 0;
    for v_stock in
      select
        gs.id as global_stock_id,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.parent_tenant_id = v_parent_tenant_id
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      v_total_avail := v_total_avail + v_avail;
    end loop;

    if v_total_avail < r.need_qty then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_picks := '[]'::jsonb;
    v_remaining := r.need_qty;

    for v_stock in
      select
        gs.id as global_stock_id,
        sh.name as shipment_name,
        sl.name as location_name,
        floor(public.global_stock_atp_qty(gs.id))::integer as atp
      from public.global_stocks gs
      inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      inner join public.global_shipments sh on sh.id = gsi.shipment_id
      left join public.stock_locations sl on sl.id = gs.location_id
      where gs.parent_tenant_id = v_parent_tenant_id
        and gsi.product_id = r.product_id
        and gs.availability = 'sellable'::public.stock_availability
        and (gs.location_id is null or sl.is_pickable = true)
      order by gs.created_at, gs.id
    loop
      select coalesce(sum((e.value->>'quantity')::integer), 0)::integer
      into v_db_reserved
      from public.preorder_demand pd
      cross join jsonb_array_elements(coalesce(pd.stock_picks, '[]'::jsonb)) e(value)
      where nullif(e.value->>'global_stock_id', '')::bigint = v_stock.global_stock_id;

      v_run_reserved := coalesce((
        select fr.reserved_qty
        from fifo_run_pick_reserve fr
        where fr.global_stock_id = v_stock.global_stock_id
      ), 0);

      v_avail := greatest(v_stock.atp - v_db_reserved - v_run_reserved, 0);
      if v_avail <= 0 then
        continue;
      end if;

      v_take := least(v_avail, v_remaining);
      v_picks := v_picks || jsonb_build_array(
        jsonb_build_object(
          'global_stock_id', v_stock.global_stock_id,
          'quantity', v_take,
          'shipment_name', coalesce(v_stock.shipment_name, ''),
          'location_name', coalesce(v_stock.location_name, '')
        )
      );

      insert into fifo_run_pick_reserve (global_stock_id, reserved_qty)
      values (v_stock.global_stock_id, v_take)
      on conflict (global_stock_id) do update
        set reserved_qty = fifo_run_pick_reserve.reserved_qty + excluded.reserved_qty;

      v_remaining := v_remaining - v_take;
      if v_remaining <= 0 then
        exit;
      end if;
    end loop;

    if v_remaining > 0 then
      v_skipped := v_skipped + 1;
      continue;
    end if;

    v_delivered := public.sum_preorder_stock_picks(v_picks);

    insert into public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      placed_quantity,
      delivered_quantity,
      stock_picks,
      updated_by_user_id
    ) values (
      r.tenant_id,
      r.source_type,
      r.source_id,
      0,
      v_delivered,
      v_picks,
      auth.uid()
    )
    on conflict (source_type, source_id) do update set
      delivered_quantity = excluded.delivered_quantity,
      stock_picks = excluded.stock_picks,
      updated_by_user_id = auth.uid(),
      updated_at = now();

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'updated_count', v_updated,
    'skipped_count', v_skipped
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.fill_preorder_demand_placed_quantities_for_document(p_tenant_id bigint, p_document_type text, p_document_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_updated integer := 0;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.billing_profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document is not open for placed quantity updates';
  end if;

  if v_doc_type = 'shop_order' then
    with lines as (
      select
        o.tenant_id,
        oi.id as source_id,
        greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as need_qty
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'shop_order_item'::public.preorder_demand_source_type,
        l.source_id,
        l.need_qty,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        placed_quantity = excluded.placed_quantity,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  else
    with lines as (
      select
        f.tenant_id,
        pci.id as source_id,
        greatest(
          case
            when pci.assigned_shipment_id is not null then 0
            else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
          end,
          0
        )::integer as need_qty
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where f.id = p_document_id
        and f.billing_profile_id is not null
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'pbc_costing_item'::public.preorder_demand_source_type,
        l.source_id,
        l.need_qty,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        placed_quantity = excluded.placed_quantity,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  end if;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'updated_count', v_updated
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.finalize_dropship_return(p_order_id bigint, p_items jsonb, p_actual_return_charge numeric DEFAULT 0.00, p_deduct_from_middle_man boolean DEFAULT true, p_override_reason text DEFAULT NULL::text, p_return_ref text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order record;
  v_invoice record;
  v_parent_tenant_id bigint;
  v_ref text;
  v_item_elem jsonb;
  v_order_item_id bigint;
  v_returned_qty numeric;
  v_condition text;
  v_order_item record;
  v_invoice_item record;
  v_stock record;
  v_target_stock_type_id bigint;
  v_target_stock_id bigint;
  v_net_delivered numeric;
  v_currency text;
  v_billing_profile_id bigint;
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
  v_profit numeric(12,2) := 0;
  v_revenue numeric(12,2) := 0;
  v_billed numeric(12,2) := 0;
  v_remit_net numeric(12,2) := 0;
  v_courier_charge numeric(12,2) := 0;
  v_has_billed boolean := false;
  v_has_profit boolean := false;
  v_grade_tag_id bigint;
  v_to_availability public.stock_availability;
  v_to_availability_raw text;
  v_use_explicit_targets boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order #% is not a dropship order', p_order_id;
  end if;

  v_currency := 'BDT';
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

  v_ref := nullif(trim(coalesce(p_return_ref, '')), '');
  if v_ref is not null then
    select id into v_existing_ref_order_id
    from public.shop_orders
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and return_ref = v_ref;

    if v_existing_ref_order_id is not null then
      if v_existing_ref_order_id = p_order_id and v_order.return_sub_state = 'return_finalized' then
        return jsonb_build_object(
          'success', true,
          'idempotent', true,
          'message', 'Return already finalized with reference ' || v_ref,
          'order_id', p_order_id
        );
      else
        raise exception 'Duplicate return reference % already used for another return', v_ref;
      end if;
    end if;
  end if;

  if v_order.return_sub_state = 'return_finalized' then
    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'message', 'Order return is already finalized',
      'order_id', p_order_id
    );
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  end if;

  v_billing_profile_id := v_order.billing_profile_id;
  if v_billing_profile_id is null and v_order.customer_group_id is not null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');
      v_grade_tag_id := nullif((v_item_elem->>'grade_tag_id')::bigint, 0);
      v_to_availability_raw := nullif(lower(trim(v_item_elem->>'to_availability')), '');
      v_use_explicit_targets := v_grade_tag_id is not null or v_to_availability_raw is not null;

      if v_returned_qty <= 0 then
        continue;
      end if;

      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      end if;

      v_net_delivered := coalesce(v_order_item.confirmed_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      end if;

      if v_use_explicit_targets then
        v_grade_tag_id := coalesce(
          v_grade_tag_id,
          v_order_item.grade_tag_id,
          public.default_stock_grade_tag_id()
        );
        v_to_availability := coalesce(
          v_to_availability_raw::public.stock_availability,
          'held'::public.stock_availability
        );
      else
        v_to_availability := case
          when v_condition = 'damaged' then 'unsellable'::public.stock_availability
          else 'held'::public.stock_availability
        end;
        v_grade_tag_id := public.stock_grade_tag_id_for_slug(
          case v_condition
            when 'open_box' then 'open_box'
            when 'damaged' then 'badly_damaged'
            else 'standard'
          end
        );
      end if;

      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        perform public.create_and_post_stock_movement(
          v_parent_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_parent_tenant_id),
          v_to_availability,
          v_grade_tag_id,
          'return_inbound'::public.stock_movement_type,
          coalesce(p_override_reason, 'Dropship return'),
          'shop_order',
          p_order_id::text
        );
      end if;

      update public.shop_order_items
      set returned_quantity = coalesce(returned_quantity, 0) + v_returned_qty, updated_at = now()
      where id = v_order_item_id;

      if v_invoice.id is not null then
        select * into v_invoice_item
        from public.global_invoice_items
        where invoice_id = v_invoice.id
          and (global_stock_id = v_order_item.global_stock_id or product_id = v_order_item.product_id)
        limit 1;

        if v_invoice_item.id is not null then
          -- global_return_items schema: quantity + return_charge_amount only (no return_amount / face / accounting)
          insert into public.global_return_items (
            tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.parent_tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
            v_returned_qty, 0.00, coalesce(p_override_reason, 'Dropship return finalization')
          );

          update public.global_invoice_items
          set return_quantity = coalesce(return_quantity, 0) + v_returned_qty, updated_at = now()
          where id = v_invoice_item.id;
        end if;
      end if;
    end loop;
  end if;

  if v_invoice.id is not null then
    perform public.recompute_global_invoice_totals(v_invoice.id);
  end if;

  select exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_billing_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_billing_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'tenant'
    and metadata->>'transaction_type' = 'revenue';

  if v_revenue <= 0 then
    v_revenue := coalesce(v_invoice.total_amount, 0.00);
  end if;

  select coalesce((metadata->>'net_remitted')::numeric, amount, 0)
  into v_remit_net
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.cashbook_entries
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_billing_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'credit',
      p_amount => v_billed,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'return_reversal',
        'label', 'Return Billed Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  elsif v_billing_profile_id is not null and v_has_billed and v_billed = 0
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    -- Invoice fully collected already — reverse original billed amount then reverse collection net via billed lookup
    select coalesce(base_amount, 0) into v_billed
    from public.cashbook_entries
    where source_type = 'shop_order' and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
    limit 1;

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'credit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_reversal',
          'label', 'Return Billed Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );

      if exists (
        select 1 from public.cashbook_entries
        where source_type = 'shop_order' and source_id = p_order_id::text
          and metadata->>'transaction_type' = 'invoice_collection'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_billing_profile_id,
          p_type => 'debit',
          p_amount => v_billed,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'receivable',
            'transaction_type', 'return_collection_reversal',
            'label', 'Return Collection Reversal',
            'order_no', v_order.order_no,
            'return_ref', v_ref
          )
        );
      end if;
    end if;

  -- Historical remittance path: invoice_collection posted without invoice_billed.
  -- Unwind collection only (no synthetic return_reversal credit).
  elsif v_billing_profile_id is not null
     and exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_collection'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_collection_reversal'
     )
  then
    select coalesce(sum(base_amount), 0) into v_billed
    from public.cashbook_entries
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_billing_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'debit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_collection_reversal',
          'label', 'Return Collection Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Leg 2: Claw back profit on customer (unified billing-profile wallet)
  if v_billing_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => v_profit,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_profit_clawback',
        'label', 'Return Profit Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 3: Reverse tenant revenue
  if v_revenue > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_revenue_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_type => 'debit',
      p_amount => v_revenue,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'revenue',
        'transaction_type', 'return_revenue_reversal',
        'label', 'Return Revenue Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 4: Reverse remittance cash + courier fee if remitted
  if v_is_remitted then
    if coalesce(v_remit_net, 0) > 0
       and not exists (
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'remittance_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
        p_type => 'debit',
        p_amount => v_remit_net,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'payment_received',
          'purpose', 'remittance_return_reversal',
          'transaction_type', 'remittance_return_reversal',
          'label', 'Remittance Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;

    if coalesce(v_courier_charge, 0) > 0
       and not exists (
         select 1 from public.cashbook_entries
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'courier_charge_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
        p_type => 'credit',
        p_amount => v_courier_charge,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'delivery_fee',
          'purpose', 'courier_charge_return_reversal',
          'transaction_type', 'courier_charge_return_reversal',
          'label', 'Courier Fee Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Return fee: UWL only (legacy middle_man_payout_ledger was dropped)
  if p_deduct_from_middle_man
     and p_actual_return_charge > 0
     and v_billing_profile_id is not null
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => p_actual_return_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_fee',
        'label', 'Return Fee',
        'order_no', v_order.order_no,
        'return_ref', v_ref,
        'invoice_id', v_order.global_invoice_id
      )
    );
  end if;

  update public.shop_orders
  set
    status = 'returned'::public.shop_order_status,
    return_sub_state = 'return_finalized',
    returned_at = coalesce(returned_at, now()),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man,
    return_override_reason = coalesce(p_override_reason, return_override_reason),
    return_ref = v_ref,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'returned',
    'return_sub_state', 'return_finalized',
    'return_ref', v_ref
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.fulfill_shop_order_to_invoice(p_order_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_invoice_type public.global_invoice_type;
  v_retail_billing_mode public.retail_billing_mode;
  v_invoice_no text;
  v_item record;
  v_items jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status = 'fulfilled' and v_order.global_invoice_id is not null then
    return;
  end if;

  if v_order.status <> 'confirmed' then
    raise exception 'only confirmed orders can be fulfilled to an invoice';
  end if;

  if v_order.shop_type_snapshot = 'vendor_catalog' then
    raise exception 'vendor catalog orders cannot be fulfilled to an invoice directly';
  end if;

  if v_order.shop_type_snapshot = 'dropship' then
    raise exception 'dropship orders must use ship_dropship_order_and_issue_merchant_bill';
  end if;

  if exists (
    select 1
    from public.bills si
    where si.shop_order_id = p_order_id
  ) then
    raise exception 'order already has a linked sales invoice';
  end if;

  if v_order.order_mode_snapshot = 'checkout_wholesale' then
    v_invoice_type := 'wholesale'::public.global_invoice_type;
    v_retail_billing_mode := null;
    if v_order.billing_profile_id is null then
      raise exception 'billing profile is required for wholesale shop orders';
    end if;
  else
    v_invoice_type := 'retail'::public.global_invoice_type;
    if v_order.billing_profile_id is not null then
      v_retail_billing_mode := 'account'::public.retail_billing_mode;
    else
      v_retail_billing_mode := 'direct'::public.retail_billing_mode;
    end if;
  end if;

  v_invoice_no := 'INV-SO-' || v_order.order_no;

  for v_item in
    select *
    from public.shop_order_items
    where order_id = p_order_id
      and coalesce(is_fulfillment_unavailable, false) = false
      and quantity > 0
  loop
    if v_item.global_stock_id is null then
      raise exception 'item % is missing global_stock_id association', v_item.name;
    end if;

    v_items := v_items || jsonb_build_array(
      jsonb_build_object(
        'global_stock_id', v_item.global_stock_id,
        'quantity', v_item.quantity::numeric,
        'sell_price_amount', coalesce(
          v_item.final_price_amount,
          v_item.unit_sell_price_amount,
          v_item.unit_list_price_amount
        ),
        'line_discount_amount', 0,
        'line_meta', case
          when v_item.customer_sell_price_amount is not null then
            jsonb_build_object('resell_price_amount', v_item.customer_sell_price_amount)
          else '{}'::jsonb
        end
      )
    );
  end loop;

  if jsonb_array_length(v_items) = 0 then
    raise exception 'order has no fulfillable line items';
  end if;

  v_payload := jsonb_build_object(
    'invoice', jsonb_build_object(
      'invoice_no', v_invoice_no,
      'invoice_type', v_invoice_type,
      'billing_profile_id', v_order.billing_profile_id,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_address', v_order.shipping_address,
      'retail_billing_mode', v_retail_billing_mode,
      'discount_amount', coalesce(v_order.discount_amount, 0),
      'shipping_charge', coalesce(v_order.delivery_charge_amount, 0),
      'print_charge', coalesce(v_order.print_charge_amount, 0),
      'wrapping_charge', coalesce(v_order.packing_charge_amount, 0),
      'note', coalesce(v_order.delivery_instructions, 'Fulfillment of Shop Order: ' || v_order.order_no)
    ),
    'items', v_items,
    'issue', true
  );

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to fulfill shop order to invoice');
  end if;

  v_invoice_id := (v_result->>'invoice_id')::bigint;

  update public.bills
  set
    shop_order_id = p_order_id,
    collection_source = 'billing_profile'::public.collection_source_type,
    updated_at = now()
  where id = v_invoice_id;

  update public.shop_orders
  set
    status = 'fulfilled',
    global_invoice_id = v_invoice_id,
    fulfilled_at = now(),
    updated_at = now()
  where id = p_order_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_courier_unremitted_financial_summary(p_tenant_id bigint)
 RETURNS TABLE(courier_service_id uuid, courier_name text, gross_cod_total numeric, company_wholesale_total numeric, middleman_margin_total numeric, order_count bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  return query
  select
    so.courier_service_id,
    coalesce(cs.name, so.courier_name, 'Unassigned') as courier_name,
    coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00)::numeric(12,2) as gross_cod_total,
    (
      coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00) -
      coalesce(sum(coalesce(wl.amount, 0)), 0.00)
    )::numeric(12,2) as company_wholesale_total,
    coalesce(sum(coalesce(wl.amount, 0)), 0.00)::numeric(12,2) as middleman_margin_total,
    count(so.id)::bigint as order_count
  from public.shop_orders so
  left join public.courier_services cs on cs.id = so.courier_service_id
  left join public.bills gi on gi.id = so.global_invoice_id
  left join public.billing_profile_wallet_ledger wl
    on wl.shop_order_id = so.id and wl.transaction_type = 'dropship_profit'
  where so.tenant_id = p_tenant_id
    and so.status = 'delivered'
  group by so.courier_service_id, coalesce(cs.name, so.courier_name, 'Unassigned');
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_customer_account_summary_for_staff(p_tenant_id bigint, p_customer_group_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_books_id bigint;
  v_group_tenant_id bigint;
  v_billing_profile_id bigint;
  v_bp_ids bigint[];
  v_still_due numeric(12, 2) := 0;
  v_total_billed numeric(12, 2) := 0;
  v_settlement numeric(12, 2) := 0;
  v_collected_cash numeric(12, 2) := 0;
  v_wallet_applied numeric(12, 2) := 0;
  v_store_credit numeric(15, 4) := 0;
  v_unallocated numeric(12, 2) := 0;
  v_open_invoices jsonb := '[]'::jsonb;
  v_recent_payments jsonb := '[]'::jsonb;
  v_recent_ledger jsonb := '[]'::jsonb;
  v_shop_access jsonb := '[]'::jsonb;
begin
  if p_tenant_id is null or p_customer_group_id is null then
    return jsonb_build_object('success', false, 'error', 'tenant and customer group are required');
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  if not (
    public.is_tenant_staff(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'customer', 'view')
  ) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select cg.tenant_id
  into v_group_tenant_id
  from public.customer_groups cg
  where cg.id = p_customer_group_id;

  if v_group_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'customer group not found');
  end if;

  select
    coalesce(array_agg(bp.id order by
      case when bp.tenant_id = v_group_tenant_id then 0 else 1 end,
      bp.id
    ), '{}'::bigint[]),
    (array_agg(bp.id order by
      case when bp.tenant_id = v_group_tenant_id then 0 else 1 end,
      bp.id
    ))[1]
  into v_bp_ids, v_billing_profile_id
  from public.billing_profiles bp
  where bp.customer_group_id = p_customer_group_id
    and (
      bp.tenant_id = v_books_id
      or bp.tenant_id in (
        select t.id from public.tenants t where t.parent_id = v_books_id
      )
    );

  if v_billing_profile_id is null then
    return jsonb_build_object(
      'success', true,
      'books_tenant_id', v_books_id,
      'billing_profile_id', null,
      'still_due', 0,
      'total_billed', 0,
      'collected_cash', 0,
      'wallet_applied', 0,
      'settlement', 0,
      'store_credit_balance', 0,
      'unallocated_payments', 0,
      'open_invoices', '[]'::jsonb,
      'recent_payments', '[]'::jsonb,
      'recent_ledger', '[]'::jsonb,
      'shop_access', coalesce((
        select jsonb_agg(to_jsonb(r))
        from (
          select
            s.id as shop_id,
            s.name as shop_name,
            s.shop_type::text as shop_type,
            st.id as shop_tenant_id,
            st.name as shop_tenant_name,
            scga.status,
            scga.credit_limit_amount
          from public.shop_customer_group_access scga
          join public.shops s on s.id = scga.shop_id
          join public.tenants st on st.id = s.tenant_id
          where scga.customer_group_id = p_customer_group_id
          order by st.name, s.name
          limit 20
        ) r
      ), '[]'::jsonb)
    );
  end if;

  select
    coalesce(sum(si.due_amount), 0.00),
    coalesce(sum(si.total_amount), 0.00),
    coalesce(sum(si.settlement_discount_amount), 0.00)
  into v_still_due, v_total_billed, v_settlement
  from public.bills si
  where si.profile_id = any(v_bp_ids)
    and si.invoice_status = 'issued'::public.global_invoice_status;

  select
    coalesce(sum(ip.amount) filter (where coalesce(gp.method, '') <> 'wallet_credit'), 0.00),
    coalesce(sum(ip.amount) filter (where gp.method = 'wallet_credit'), 0.00)
  into v_collected_cash, v_wallet_applied
  from public.pay_allocations ip
  join public.pays gp on gp.id = ip.payment_id
  join public.bills si on si.id = ip.global_invoice_id
  where si.profile_id = any(v_bp_ids)
    and si.invoice_status = 'issued'::public.global_invoice_status;

  select coalesce(wa.available_balance, 0.0000)
  into v_store_credit
  from public.cashbook_accounts wa
  where wa.parent_tenant_id = v_books_id
    and wa.entity_type = 'customer'
    and wa.entity_id = v_billing_profile_id
    and wa.currency_code = 'BDT';

  select coalesce(sum(gp.unallocated_amount), 0.00)
  into v_unallocated
  from public.pays gp
  where gp.profile_id = any(v_bp_ids);

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_open_invoices
  from (
    select
      si.id,
      si.invoice_no,
      si.invoice_type::text as invoice_type,
      si.due_amount,
      si.paid_amount,
      si.total_amount,
      si.payment_status,
      si.invoice_date,
      si.due_date,
      si.issued_by_tenant_id,
      it.name as issued_by_tenant_name
    from public.bills si
    left join public.tenants it on it.id = si.issued_by_tenant_id
    where si.profile_id = any(v_bp_ids)
      and si.invoice_status = 'issued'::public.global_invoice_status
      and si.due_amount > 0
    order by si.due_amount desc, si.invoice_date desc, si.id desc
    limit 50
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_recent_payments
  from (
    select
      gp.id as payment_id,
      gp.payment_date,
      gp.method,
      gp.amount,
      gp.unallocated_amount,
      gp.note,
      ip.global_invoice_id as invoice_id,
      ip.amount as allocated_amount
    from public.pays gp
    left join public.pay_allocations ip on ip.payment_id = gp.id
    where gp.profile_id = any(v_bp_ids)
    order by gp.payment_date desc, gp.id desc
    limit 30
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_recent_ledger
  from (
    select
      l.id,
      l.type,
      l.amount,
      l.balance_after,
      l.operating_tenant_id,
      l.source_type,
      l.source_id,
      l.created_at,
      l.metadata->>'transaction_type' as transaction_type,
      coalesce(
        l.metadata->>'label',
        l.metadata->>'transaction_type',
        'Adjustment'
      ) as label
    from public.cashbook_entries l
    where l.parent_tenant_id = v_books_id
      and l.entity_type = 'customer'
      and l.entity_id = any(v_bp_ids)
    order by l.created_at desc, l.id desc
    limit 30
  ) r;

  select coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  into v_shop_access
  from (
    select
      s.id as shop_id,
      s.name as shop_name,
      s.shop_type::text as shop_type,
      st.id as shop_tenant_id,
      st.name as shop_tenant_name,
      scga.status,
      scga.credit_limit_amount
    from public.shop_customer_group_access scga
    join public.shops s on s.id = scga.shop_id
    join public.tenants st on st.id = s.tenant_id
    where scga.customer_group_id = p_customer_group_id
    order by st.name, s.name
    limit 20
  ) r;

  return jsonb_build_object(
    'success', true,
    'books_tenant_id', v_books_id,
    'billing_profile_id', v_billing_profile_id,
    'still_due', v_still_due,
    'total_billed', v_total_billed,
    'collected_cash', v_collected_cash,
    'wallet_applied', v_wallet_applied,
    'settlement', v_settlement,
    'store_credit_balance', v_store_credit,
    'unallocated_payments', v_unallocated,
    'open_invoices', v_open_invoices,
    'recent_payments', v_recent_payments,
    'recent_ledger', v_recent_ledger,
    'shop_access', v_shop_access
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_customer_dues_report(p_tenant_id bigint, p_issued_by_tenant_id bigint DEFAULT NULL::bigint, p_search text DEFAULT NULL::text, p_aging_bucket text DEFAULT NULL::text, p_min_due numeric DEFAULT 0, p_over_limit_only boolean DEFAULT false, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_skip_count boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_books_id bigint;
  v_today date;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_today := (timezone('Asia/Dhaka', now()))::date;
  v_offset := (v_page - 1) * v_page_size;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH invoice_returned AS (
    SELECT
      sii.invoice_id,
      coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii
    GROUP BY sii.invoice_id
  ),
  invoice_payments_agg AS (
    SELECT
      ip.global_invoice_id AS invoice_id,
      coalesce(sum(CASE WHEN coalesce(gp.method, '') <> 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS collected_cash,
      coalesce(sum(CASE WHEN gp.method = 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS wallet_applied
    FROM public.pay_allocations ip
    JOIN public.pays gp ON gp.id = ip.payment_id
    WHERE ip.global_invoice_id IS NOT NULL
      AND gp.voided_at IS NULL
    GROUP BY ip.global_invoice_id
  ),
  per_invoice AS (
    SELECT
      si.profile_id AS billing_profile_id,
      si.due_amount,
      (si.total_amount + coalesce(ir.returned, 0))::numeric(12,2) AS billed,
      coalesce(ir.returned, 0)::numeric(12,2) AS returned,
      coalesce(ipa.collected_cash, 0)::numeric(12,2) AS collected_cash,
      coalesce(ipa.wallet_applied, 0)::numeric(12,2) AS wallet_applied,
      coalesce(si.written_off_amount, 0)::numeric(12,2) AS settlement,
      coalesce(si.due_date, si.invoice_date) AS aging_date,
      CASE
        WHEN si.due_amount <= 0 THEN NULL
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) <= 0 THEN 'current'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 1 AND 30 THEN '1_30'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 31 AND 60 THEN '31_60'
        WHEN (v_today - coalesce(si.due_date, si.invoice_date)) BETWEEN 61 AND 90 THEN '61_90'
        ELSE '90_plus'
      END AS aging_bucket
    FROM public.bills si
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    LEFT JOIN invoice_payments_agg ipa ON ipa.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.profile_id IS NOT NULL
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
  ),
  customer_base AS (
    SELECT
      pi.billing_profile_id,
      round(sum(pi.billed), 2) AS billed,
      round(sum(pi.returned), 2) AS returned,
      round(sum(pi.collected_cash), 2) AS collected_cash,
      round(sum(pi.wallet_applied), 2) AS wallet_applied,
      round(sum(pi.settlement), 2) AS settlement,
      round(sum(pi.due_amount), 2) AS still_due,
      min(pi.aging_date) FILTER (WHERE pi.due_amount > 0) AS oldest_due_date,
      count(*) FILTER (WHERE pi.due_amount > 0)::bigint AS open_invoice_count,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = 'current'), 0), 2) AS aging_current,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '1_30'), 0), 2) AS aging_d1_30,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '31_60'), 0), 2) AS aging_d31_60,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '61_90'), 0), 2) AS aging_d61_90,
      round(coalesce(sum(pi.due_amount) FILTER (WHERE pi.aging_bucket = '90_plus'), 0), 2) AS aging_d90_plus
    FROM per_invoice pi
    GROUP BY pi.billing_profile_id
    HAVING sum(pi.due_amount) > 0
  ),
  customer_rows AS (
    SELECT
      cb.*,
      bp.name,
      bp.phone,
      cl.credit_limit
    FROM customer_base cb
    JOIN public.billing_profiles bp ON bp.id = cb.billing_profile_id
    LEFT JOIN LATERAL (
      SELECT max(scga.credit_limit_amount)::numeric(12,2) AS credit_limit
      FROM public.shop_customer_group_access scga
      JOIN public.shops sh ON sh.id = scga.shop_id
      WHERE scga.customer_group_id = bp.customer_group_id
        AND public.resolve_parent_tenant_id(sh.tenant_id) = v_books_id
    ) cl ON true
    WHERE cb.still_due >= coalesce(p_min_due, 0)
      AND (
        p_search IS NULL
        OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
      AND (
        p_aging_bucket IS NULL
        OR btrim(p_aging_bucket) = ''
        OR (p_aging_bucket = 'current' AND cb.aging_current > 0)
        OR (p_aging_bucket = '1_30' AND cb.aging_d1_30 > 0)
        OR (p_aging_bucket = '31_60' AND cb.aging_d31_60 > 0)
        OR (p_aging_bucket = '61_90' AND cb.aging_d61_90 > 0)
        OR (p_aging_bucket = '90_plus' AND cb.aging_d90_plus > 0)
      )
      AND (
        NOT coalesce(p_over_limit_only, false)
        OR (cl.credit_limit IS NOT NULL AND cb.still_due > cl.credit_limit)
      )
  ),
  totals_calc AS (
    SELECT
      round(coalesce(sum(billed), 0), 2) AS billed,
      round(coalesce(sum(returned), 0), 2) AS returned,
      round(coalesce(sum(collected_cash), 0), 2) AS collected_cash,
      round(coalesce(sum(wallet_applied), 0), 2) AS wallet_applied,
      round(coalesce(sum(settlement), 0), 2) AS settlement,
      round(coalesce(sum(still_due), 0), 2) AS still_due,
      count(*)::bigint AS customer_count
    FROM customer_rows
  ),
  paged AS (
    SELECT * FROM customer_rows ORDER BY still_due DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM customer_rows),
    (SELECT jsonb_build_object(
      'billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due,
      'customer_count', customer_count
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'billing_profile_id', billing_profile_id, 'name', name, 'phone', phone, 'credit_limit', credit_limit,
      'billed', billed, 'returned', returned, 'collected_cash', collected_cash, 'wallet_applied', wallet_applied,
      'settlement', settlement, 'still_due', still_due, 'oldest_due_date', oldest_due_date,
      'open_invoice_count', open_invoice_count,
      'aging', jsonb_build_object(
        'current', aging_current, 'd1_30', aging_d1_30, 'd31_60', aging_d31_60,
        'd61_90', aging_d61_90, 'd90_plus', aging_d90_plus
      )
    ) ORDER BY still_due DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object(
    'totals', coalesce(v_totals, '{}'::jsonb),
    'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page,
    'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_customer_shop_order(p_tenant_id bigint, p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_group_id bigint;
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_shop_slug text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_symbol text;
  v_buy_symbol text;
  v_item_count bigint;
  v_total_amount numeric;
  v_items jsonb;
  v_order_json jsonb;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  v_group_id := public.current_customer_group_id(p_tenant_id);
  if v_group_id is null then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.customer_group_id is distinct from v_group_id then
    raise exception 'order not found';
  end if;

  select
    s.name,
    s.slug,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.symbol,
    buy_gc.symbol
  into
    v_shop_name,
    v_shop_slug,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_symbol,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  if v_order.shop_type_snapshot = 'dropship'::public.shop_type_enum then
    v_can_see_buy_price := true;
    v_can_see_sell_price := true;
  else
    select
      case
        when v_order.cart_id is not null then coalesce(c.can_see_buy_price_snapshot, perm.can_see_buy_price, false)
        else coalesce(perm.can_see_buy_price, false)
      end,
      case
        when v_order.cart_id is not null then coalesce(c.can_see_sell_price_snapshot, perm.can_see_sell_price, false)
        else coalesce(perm.can_see_sell_price, false)
      end
    into v_can_see_buy_price, v_can_see_sell_price
    from public.get_shop_permissions_for_customer(v_order.shop_id) perm
    left join public.shop_carts c on c.id = v_order.cart_id;
  end if;

  v_can_see_buy_price := coalesce(v_can_see_buy_price, false);
  v_can_see_sell_price := coalesce(v_can_see_sell_price, false);

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        case
          when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null
          else soi.unit_list_price_amount
        end
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'unit_list_price_amount', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_amount end,
        'unit_list_price_currency_id', case when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum and not v_can_see_buy_price then null else soi.unit_list_price_currency_id end,
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount', soi.customer_sell_price_amount,
        'customer_sell_price_currency_id', soi.customer_sell_price_currency_id,
        'customer_offer_amount', soi.customer_offer_amount,
        'customer_offer_currency_id', soi.customer_offer_currency_id,
        'staff_offer_amount', soi.staff_offer_amount,
        'staff_offer_currency_id', soi.staff_offer_currency_id,
        'is_first_offer_manual', soi.is_first_offer_manual,
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'final_offer_amount', soi.final_price_amount,
        'is_final_offer_manual', soi.is_final_offer_manual,
        'confirmed_quantity', soi.confirmed_quantity,
        'weight_kg', soi.weight_kg,
        'customer_decision_status', soi.customer_decision_status,
        'customer_decision_at', soi.customer_decision_at,
        'negotiation_status', soi.negotiation_status,
        'staff_offer_at', soi.staff_offer_at,
        'customer_counter_at', soi.customer_counter_at,
        'final_offer_at', soi.final_offer_at,
        'returned_quantity', soi.returned_quantity,
        'sku', p.product_code,
        'brand', p.brand,
        'barcode', p.barcode,
        'minimum_order_quantity', p.minimum_order_quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  v_order_json :=
    jsonb_build_object(
      'id', v_order.id,
      'tenant_id', v_order.tenant_id,
      'shop_id', v_order.shop_id,
      'shop_name', v_shop_name,
      'shop_slug', v_shop_slug,
      'customer_group_id', v_order.customer_group_id,
      'cart_id', v_order.cart_id,
      'order_no', v_order.order_no,
      'name', v_order.name,
      'shop_type_snapshot', v_order.shop_type_snapshot,
      'order_mode_snapshot', v_order.order_mode_snapshot,
      'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
      'status', v_order.status,
      'negotiate_round', v_order.negotiate_round,
      'cargo_rate', v_order.cargo_rate,
      'conversion_rate', v_order.conversion_rate,
      'profit_rate', v_order.profit_rate,
      'first_offer_rate', v_order.first_offer_rate,
      'final_offer_rate', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_phone_secondary', v_order.recipient_phone_secondary,
      'shipping_address', v_order.shipping_address,
      'shipping_district', v_order.shipping_district,
      'shipping_thana', v_order.shipping_thana,
      'recipient_profile_id', v_order.recipient_profile_id,
      'billing_profile_id', v_order.billing_profile_id,
      'placed_at', v_order.placed_at,
      'fulfilled_at', v_order.fulfilled_at,
      'shop_sell_currency_id', v_sell_currency_id,
      'shop_buy_currency_id', v_buy_currency_id,
      'shop_sell_currency_symbol', v_sell_symbol,
      'shop_buy_currency_symbol', v_buy_symbol,
      'can_see_buy_price', v_can_see_buy_price,
      'can_see_sell_price', v_can_see_sell_price
    )
    || jsonb_build_object(
      'created_at', v_order.created_at,
      'updated_at', v_order.updated_at,
      'cod_charge_amount', v_order.cod_charge_amount,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'print_charge_amount', v_order.print_charge_amount,
      'packing_charge_amount', v_order.packing_charge_amount,
      'discount_amount', v_order.discount_amount,
      'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
      'delivery_instructions', v_order.delivery_instructions,
      'deduct_charges_from_margin', v_order.deduct_charges_from_margin,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'item_count', v_item_count,
      'total_amount', case
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and not v_can_see_sell_price then null
        when v_order.shop_type_snapshot = 'vendor_catalog'::public.shop_type_enum
          and not v_can_see_buy_price
          and v_total_amount = 0 then null
        else v_total_amount
      end,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'payout_settlement_status', v_order.payout_settlement_status
    );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dropship_finance_hub_data(p_tenant_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_summary jsonb;
  v_orders jsonb;
  v_merchants jsonb;
  v_parent_tenant_id bigint;
  v_is_parent_scope boolean;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent_scope := (p_tenant_id = v_parent_tenant_id);

  v_summary := public.get_wallet_dashboard_summary(p_tenant_id);

  with finance_orders as (
    select
      o.id,
      o.order_no,
      o.recipient_name,
      o.status,
      o.cod_collect_amount,
      o.delivery_charge_amount,
      o.cod_charge_amount,
      o.driver_notes,
      o.courier_name,
      o.courier_remittance_ref,
      o.courier_bank_trx_id,
      o.billing_profile_id,
      o.created_at,
      o.collection_source,
      o.payout_settlement_status,
      o.is_prepaid_snapshot,
      o.global_invoice_id,
      s.name as shop_name,
      bp.name as billing_profile_name,
      inv.collection_source as invoice_collection_source,
      inv.total_amount as invoice_total_amount,
      inv.paid_amount as invoice_paid_amount
    from public.shop_orders o
    left join public.shops s on s.id = o.shop_id
    left join public.billing_profiles bp on bp.id = o.billing_profile_id
    left join public.bills inv on inv.id = o.global_invoice_id
    where (
        (v_is_parent_scope and (o.parent_tenant_id = p_tenant_id or o.tenant_id = p_tenant_id))
        or (not v_is_parent_scope and o.tenant_id = p_tenant_id)
      )
      and o.shop_type_snapshot = 'dropship'
      and o.status in ('delivered', 'payment_received')
  ),
  ledger_flags as (
    select
      l.source_id,
      max(case when coalesce(l.metadata->>'purpose', '') in ('delivered_costing', 'courier_cod_receivable') then 1 else 0 end) as has_delivered_costing,
      max(case when coalesce(l.metadata->>'purpose', '') = 'courier_remittance' then 1 else 0 end) as has_remittance
    from public.cashbook_entries l
    where l.parent_tenant_id = v_parent_tenant_id
      and l.source_type = 'shop_order'
      and l.source_id in (select fo.id::text from finance_orders fo)
    group by l.source_id
  ),
  order_rows as (
    select
      fo.id,
      fo.order_no as "orderNo",
      fo.recipient_name as "customerName",
      fo.shop_name as "shopName",
      fo.courier_name as "courierName",
      fo.status::text as status,
      case
        when fo.global_invoice_id is not null then coalesce(fo.invoice_total_amount, 0)
        else coalesce(fo.cod_collect_amount, 0)
      end as "totalAmount",
      coalesce(fo.cod_collect_amount, 0) as "codCollectAmount",
      coalesce(fo.delivery_charge_amount, 0) as "deliveryChargeAmount",
      coalesce(fo.cod_charge_amount, 0) as "codChargeAmount",
      fo.driver_notes as "courierNotes",
      fo.courier_remittance_ref as "courierRemittanceRef",
      fo.courier_bank_trx_id as "courierBankTrxId",
      fo.billing_profile_id as "billingProfileId",
      fo.billing_profile_name as "billingProfileName",
      fo.created_at as "createdAt",
      case
        when fo.status::text = 'delivered'
          and coalesce(lf.has_remittance, 0) = 0
          and fo.courier_remittance_ref is null
          and coalesce(fo.cod_collect_amount, 0) > 0
          and coalesce(
            fo.collection_source,
            fo.invoice_collection_source,
            case when fo.is_prepaid_snapshot then 'billing_profile' else 'recipient' end
          ) <> 'billing_profile'
          then 'courier_remittance'
        when coalesce(lf.has_delivered_costing, 0) = 0 and fo.status::text = 'delivered' then 'delivered_costing'
        when fo.status::text = 'delivered'
          or (coalesce(lf.has_remittance, 0) = 0 and fo.status::text <> 'payment_received')
          then 'courier_remittance'
        else 'completed'
      end as "nextStep",
      coalesce(
        fo.collection_source,
        fo.invoice_collection_source,
        case when fo.is_prepaid_snapshot then 'billing_profile' else null end
      ) as "collectionSource",
      coalesce(fo.payout_settlement_status, 'unpaid') as "payoutSettlementStatus",
      case
        when fo.global_invoice_id is not null then greatest(coalesce(fo.invoice_total_amount, 0) - coalesce(fo.invoice_paid_amount, 0), 0)
        else null
      end as "invoiceOutstanding"
    from finance_orders fo
    left join ledger_flags lf on lf.source_id = fo.id::text
    order by fo.created_at desc
  )
  select coalesce(jsonb_agg(to_jsonb(order_rows)), '[]'::jsonb)
  into v_orders
  from order_rows;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bp.id,
        'name', bp.name,
        'payableBalance', coalesce(wa.available_balance, 0)
      )
      order by bp.name
    ),
    '[]'::jsonb
  )
  into v_merchants
  from public.billing_profiles bp
  left join public.cashbook_accounts wa
    on wa.tenant_id = p_tenant_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
  where bp.tenant_id = p_tenant_id;

  return jsonb_build_object(
    'kpis', jsonb_build_object(
      'courierOwedTotal', coalesce((v_summary->>'courier_cod_holding_total')::numeric, 0),
      'tenantCashTotal', coalesce((v_summary->>'tenant_cash_total')::numeric, 0),
      'middlemanPayableTotal', coalesce((v_summary->>'merchant_available_total')::numeric, 0)
    ),
    'orders', coalesce(v_orders, '[]'::jsonb),
    'merchants', coalesce(v_merchants, '[]'::jsonb)
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dropship_management_order(p_tenant_id bigint, p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_detail jsonb;
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_charge_lines jsonb;
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_order_item_quantity integer;
  v_company_procurement_cost numeric(15,2);
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_courier_name text;
  v_has_settlement boolean := false;
  v_invoice jsonb;
  v_is_returned boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
    and (tenant_id = p_tenant_id or parent_tenant_id = p_tenant_id);

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  v_is_returned := v_order.status = 'returned'::public.shop_order_status;

  if v_order.status not in ('shipped', 'delivered', 'payment_received', 'reseller_paid', 'returned') then
    raise exception 'order status % is not eligible for dropship management desk', v_order.status;
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);

  select coalesce(cs.name, v_order.courier_name)
  into v_courier_name
  from public.courier_services cs
  where cs.id::text = v_order.courier_service_id::text;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost,
    rp.order_item_quantity
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost, v_order_item_quantity
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id
    and (o.tenant_id = p_tenant_id or o.parent_tenant_id = p_tenant_id);

  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  v_charge_lines := public.build_dropship_management_charge_lines(
    v_order,
    case when v_has_settlement then v_settlement.id else null end
  );

  if v_has_settlement then
    v_collected_cod := v_settlement.collected_cod_amount;
  else
    v_collected_cod := coalesce(v_order.cod_collect_amount, v_calculated_cod);
  end if;

  if v_order.global_invoice_id is null then
    v_invoice := null;
  else
    select jsonb_build_object(
      'id', i.id,
      'invoice_no', i.invoice_no,
      'invoice_status', i.invoice_status,
      'payment_status', i.payment_status,
      'total_amount', i.total_amount,
      'due_amount', i.due_amount
    )
    into v_invoice
    from public.bills i
    where i.id = v_order.global_invoice_id;
  end if;

  return jsonb_build_object(
    'success', true,
    'order', (v_detail->'order') || jsonb_build_object(
      'courier_name', v_courier_name,
      'payout_settlement_status', v_order.payout_settlement_status,
      'returned_at', v_order.returned_at,
      'return_charge_amount', coalesce(v_order.return_charge_amount, 0),
      'deduct_return_charge_from_middle_man', coalesce(v_order.deduct_return_charge_from_middle_man, false),
      'return_override_reason', v_order.return_override_reason
    ),
    'items', coalesce(v_detail->'items', '[]'::jsonb),
    'fulfillment', v_detail->'fulfillment',
    'computed', (v_detail->'computed') || jsonb_build_object(
      'order_item_quantity', v_order_item_quantity
    ),
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', coalesce(v_settlement.status::text, 'draft'),
      'calculated_cod_amount', coalesce(v_calculated_cod, v_settlement.calculated_cod_amount),
      'collected_cod_amount', coalesce(v_settlement.collected_cod_amount, v_collected_cod),
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
      'discount_company_pay', coalesce(v_settlement.discount_company_pay, 0),
      'return_reason_note', coalesce(v_settlement.return_reason_note, ''),
      'charge_lines', v_charge_lines,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at
    ),
    'invoice', v_invoice,
    'step_state', jsonb_build_object(
      'can_mark_returned',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_mark_delivered',
        not v_is_returned
        and v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_issue_invoice',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and v_order.global_invoice_id is null,
      'can_record_bank_transfer',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.remittance_at is null),
      'can_transfer_to_reseller',
        not v_is_returned
        and v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.status is distinct from 'confirmed')
        and (not v_has_settlement or v_settlement.merchant_payout_at is null)
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dropship_order_detail_v2(p_tenant_id bigint, p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_customer_group_name text;
  v_sell_symbol text;
  v_buy_currency_id bigint;
  v_items jsonb;
  v_courier_services jsonb;
  v_items_resell_total numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_recipient_grand_total numeric := 0;
  v_all_lines_resolved boolean := false;
  v_total_delivered_qty numeric := 0;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select o.*
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  select s.name, gc.symbol, s.buy_currency_id
  into v_shop_name, v_sell_symbol, v_buy_currency_id
  from public.shops s
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'product_id', soi.product_id,
        'global_stock_id', soi.global_stock_id,
        'global_stock_allocation_id', soi.global_stock_allocation_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'cost_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'cost_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_list_price_amount', public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount),
        'unit_list_price_currency_id', coalesce(soi.cost_price_currency_id, v_buy_currency_id, soi.unit_list_price_currency_id),
        'unit_sell_price_amount', soi.unit_sell_price_amount,
        'unit_sell_price_currency_id', soi.unit_sell_price_currency_id,
        'unit_minimum_sell_price_amount', soi.unit_minimum_sell_price_amount,
        'unit_minimum_sell_price_currency_id', soi.unit_minimum_sell_price_currency_id,
        'customer_sell_price_amount',
          coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount),
        'customer_sell_price_currency_id',
          coalesce(soi.customer_sell_price_currency_id, soi.final_price_currency_id, soi.unit_sell_price_currency_id),
        'final_price_amount', soi.final_price_amount,
        'final_price_currency_id', soi.final_price_currency_id,
        'returned_quantity', coalesce(soi.returned_quantity, 0),
        'confirmed_quantity', soi.confirmed_quantity,
        'is_fulfillment_unavailable', coalesce(soi.is_fulfillment_unavailable, false),
        'unavailable_reason', soi.unavailable_reason,
        'fulfillment_resolved', (
          coalesce(soi.is_fulfillment_unavailable, false)
          or coalesce(soi.confirmed_quantity, 0) > 0
        ),
        'sku', p.product_code,
        'barcode', p.barcode,
        'brand', p.brand,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)
      * soi.quantity
    ),
    0
  )
  into v_items_resell_total
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  v_recipient_charge_total :=
    case when not coalesce(v_order.deduct_delivery_from_margin, false)
      then coalesce(v_order.delivery_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_cod_from_margin, false)
      then coalesce(v_order.cod_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_print_from_margin, false)
      then coalesce(v_order.print_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_packing_from_margin, false)
      then coalesce(v_order.packing_charge_amount, 0) else 0 end;

  v_recipient_grand_total :=
    v_items_resell_total + v_recipient_charge_total - coalesce(v_order.discount_amount, 0);

  select coalesce(bool_and(
    coalesce(soi.is_fulfillment_unavailable, false)
    or coalesce(soi.confirmed_quantity, 0) > 0
  ), true)
  into v_all_lines_resolved
  from public.shop_order_items soi
  where soi.order_id = v_order.id and soi.quantity > 0;

  select coalesce(sum(coalesce(soi.confirmed_quantity, 0)), 0)
  into v_total_delivered_qty
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    jsonb_agg(
      to_jsonb(cs.*)
      order by cs.created_at, cs.id
    ),
    '[]'::jsonb
  )
  into v_courier_services
  from public.courier_services cs
  where cs.is_active = true
    and (cs.tenant_id is null or cs.tenant_id = v_order.tenant_id);

  return jsonb_build_object(
    'success', true,
    'order', jsonb_build_object(
      'id', v_order.id,
      'tenant_id', v_order.tenant_id,
      'shop_id', v_order.shop_id,
      'shop_name', v_shop_name,
      'customer_group_id', v_order.customer_group_id,
      'customer_group_name', v_customer_group_name,
      'cart_id', v_order.cart_id,
      'order_no', v_order.order_no,
      'name', v_order.name,
      'shop_type_snapshot', v_order.shop_type_snapshot,
      'order_mode_snapshot', v_order.order_mode_snapshot,
      'is_negotiable_snapshot', v_order.is_negotiable_snapshot,
      'status', v_order.status,
      'negotiate_round', v_order.negotiate_round,
      'placed_at', v_order.placed_at,
      'fulfilled_at', v_order.fulfilled_at,
      'global_invoice_id', v_order.global_invoice_id,
      'created_by_email', v_order.created_by_email,
      'created_at', v_order.created_at,
      'updated_at', v_order.updated_at,
      'shop_sell_currency_symbol', v_sell_symbol,
      'recipient_name', v_order.recipient_name,
      'recipient_phone', v_order.recipient_phone,
      'recipient_phone_secondary', v_order.recipient_phone_secondary,
      'shipping_address', v_order.shipping_address,
      'shipping_thana', v_order.shipping_thana,
      'shipping_district', v_order.shipping_district,
      'shipping_post_code', null,
      'recipient_profile_id', v_order.recipient_profile_id,
      'billing_profile_id', v_order.billing_profile_id,
      'delivery_instructions', v_order.delivery_instructions,
      'is_prepaid_snapshot', v_order.is_prepaid_snapshot,
      'cod_charge_amount', v_order.cod_charge_amount,
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'print_charge_amount', v_order.print_charge_amount,
      'packing_charge_amount', v_order.packing_charge_amount,
      'discount_amount', v_order.discount_amount,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total),
      'item_count', jsonb_array_length(v_items),
      'delivery_zone', v_order.delivery_zone,
      'courier_name', v_order.courier_name,
      'courier_awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url
    ),
    'items', v_items,
    'summary', jsonb_build_object(
      'delivery_charge_amount', v_order.delivery_charge_amount,
      'deduct_delivery_from_margin', v_order.deduct_delivery_from_margin,
      'cod_charge_amount', v_order.cod_charge_amount,
      'deduct_cod_from_margin', v_order.deduct_cod_from_margin,
      'print_charge_amount', v_order.print_charge_amount,
      'deduct_print_from_margin', v_order.deduct_print_from_margin,
      'packing_charge_amount', v_order.packing_charge_amount,
      'deduct_packing_from_margin', v_order.deduct_packing_from_margin,
      'discount_amount', v_order.discount_amount,
      'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total)
    ),
    'computed', jsonb_build_object(
      'items_resell_total', v_items_resell_total,
      'recipient_charge_total', v_recipient_charge_total,
      'recipient_grand_total', v_recipient_grand_total,
      'all_lines_resolved', v_all_lines_resolved,
      'total_delivered_qty', v_total_delivered_qty,
      'delivery_zone_label',
        case v_order.delivery_zone
          when 'inside_dhaka' then 'Inside Dhaka'
          when 'outside_dhaka' then 'Outside Dhaka'
          else null
        end
    ),
    'fulfillment', jsonb_build_object(
      'pickup', jsonb_build_object(
        'merchant_id', null,
        'sender_name', coalesce(v_order.sender_name, v_order.default_sender_name),
        'pickup_phone', coalesce(v_order.pickup_phone, v_order.default_pickup_phone),
        'pickup_address', coalesce(v_order.pickup_address, v_order.default_pickup_address)
      ),
      'courier', jsonb_build_object(
        'courier_service_id', v_order.courier_service_id,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'allow_open_box', coalesce(v_order.allow_open_box, false),
        'cod_charge', v_order.cod_charge_amount
      )
    ),
    'lookups', jsonb_build_object(
      'courier_services', v_courier_services
    ),
    'permissions', jsonb_build_object(
      'can_show_invoice_paper', v_order.status = 'confirmed',
      'can_start_processing', v_order.status = 'confirmed',
      'can_mark_ready_for_pickup', v_order.status = 'processing',
      'can_mark_shipped', v_order.status = 'ready_for_pickup',
      'can_print_customer_invoice', v_order.status in ('ready_for_pickup', 'shipped', 'delivered')
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dropship_review_cart(p_shop_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shop_type public.shop_type_enum;
  v_tenant_id bigint;
  v_customer_group_id bigint;
  v_cart_id bigint;
  v_result jsonb;
  v_resell_subtotal numeric := 0;
  v_has_floor_violation boolean := false;
  v_delivery_min numeric := 60;
  v_delivery_max numeric := 130;
  v_cod_percent_min numeric := 1;
  v_cod_percent_max numeric := 1;
  v_delivery_mid numeric;
  v_cod_charge_preview numeric;
  v_recipient_grand_total numeric;
begin
  select tenant_id, shop_type into v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_tenant_id is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  if not public.can_customer_access_shop(p_shop_id) then
    raise exception 'access denied';
  end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id
    and access.status = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc
  limit 1;

  if v_customer_group_id is null then
    raise exception 'no customer group access found';
  end if;

  select c.id into v_cart_id
  from public.shop_carts c
  where c.tenant_id = v_tenant_id
    and c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id
    and c.status = 'active'
  order by c.id desc
  limit 1;

  if v_cart_id is null then
    raise exception 'cart not found';
  end if;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'shop_name', s.name,
      'shop_slug', s.slug,
      'customer_group_id', c.customer_group_id,
      'status', c.status,
      'allow_delivery', s.allow_delivery,
      'currency', jsonb_build_object(
        'id', s.sell_currency_id,
        'code', gc.code,
        'symbol', gc.symbol
      ),
      'charges', jsonb_build_object(
        'cod_charge_amount', c.cod_charge_amount,
        'delivery_charge_amount', c.delivery_charge_amount,
        'print_charge_amount', coalesce(nullif(c.print_charge_amount, 0), s.default_print_charge_amount),
        'packing_charge_amount', coalesce(nullif(c.packing_charge_amount, 0), s.default_packing_charge_amount),
        'discount_amount', c.discount_amount,
        'is_prepaid', c.is_prepaid,
        'delivery_instructions', c.delivery_instructions
      ),
      'margin_deductions', jsonb_build_object(
        'deduct_charges_from_margin', c.deduct_charges_from_margin,
        'deduct_print_from_margin', c.deduct_print_from_margin,
        'deduct_packing_from_margin', c.deduct_packing_from_margin
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'permissions', (
      select jsonb_build_object(
        'can_browse', p.can_browse,
        'can_see_buy_price', p.can_see_buy_price,
        'can_see_sell_price', p.can_see_sell_price,
        'can_see_resell_minimum_price', p.can_see_resell_minimum_price,
        'can_add_to_cart', p.can_add_to_cart,
        'can_place_order', p.can_place_order,
        'can_negotiate', p.can_negotiate,
        'can_view_quantity', p.can_view_quantity,
        'can_set_dropship_price', p.can_set_dropship_price
      )
      from public.get_shop_permissions_for_customer(p_shop_id) p
      limit 1
    ),
    'items', coalesce(items.items, '[]'::jsonb),
    'totals', coalesce(items.totals, jsonb_build_object(
      'item_count', 0,
      'line_count', 0,
      'purchase_subtotal', 0,
      'resell_subtotal', 0,
      'estimated_profit', 0
    ))
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select
      jsonb_agg(
        jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'global_stock_id', ci.global_stock_id,
          'name', ci.name,
          'image_url', ci.image_url,
          'quantity', ci.quantity,
          'minimum_quantity', ci.minimum_quantity,
          'minimum_order_quantity', p.minimum_order_quantity,
          'purchase_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'listing_sell_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'resell_price', jsonb_build_object(
            'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
            'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
            'code', coalesce(cust_gc.code, sell_gc.code),
            'symbol', coalesce(cust_gc.symbol, sell_gc.symbol)
          ),
          'min_resell_price', jsonb_build_object(
            'amount', ci.unit_minimum_sell_price_amount,
            'currency_id', ci.unit_minimum_sell_price_currency_id,
            'code', min_gc.code,
            'symbol', min_gc.symbol
          ),
          'line_totals', jsonb_build_object(
            'purchase_subtotal', ci.quantity * coalesce(ci.unit_sell_price_amount, 0),
            'resell_subtotal', ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
          ),
          'is_resell_below_floor', (
            coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
            and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
              < ci.unit_minimum_sell_price_amount
          )
        )
        order by ci.id
      ) as items,
      jsonb_build_object(
        'item_count', coalesce(sum(ci.quantity), 0),
        'line_count', count(ci.id),
        'purchase_subtotal', coalesce(sum(ci.quantity * coalesce(ci.unit_sell_price_amount, 0)), 0),
        'resell_subtotal', coalesce(sum(
          ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        ), 0),
        'estimated_profit', coalesce(sum(
          ci.quantity * (
            coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
            - coalesce(ci.unit_sell_price_amount, 0)
          )
        ), 0)
      ) as totals
    from public.shop_cart_items ci
    left join public.products p on p.id = ci.product_id
    left join public.global_currencies sell_gc on sell_gc.id = ci.unit_sell_price_currency_id
    left join public.global_currencies cust_gc on cust_gc.id = ci.customer_sell_price_currency_id
    left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
    where ci.cart_id = c.id
  ) items on true
  where c.id = v_cart_id;

  if coalesce(jsonb_array_length(v_result->'items'), 0) = 0 then
    raise exception 'cart is empty';
  end if;

  v_resell_subtotal := coalesce((v_result->'totals'->>'resell_subtotal')::numeric, 0);

  select bool_or((item->>'is_resell_below_floor')::boolean)
  into v_has_floor_violation
  from jsonb_array_elements(v_result->'items') item;

  select
    coalesce(min(least(cs.inside_dhaka_fee, cs.outside_dhaka_fee)), 60),
    coalesce(max(greatest(cs.inside_dhaka_fee, cs.outside_dhaka_fee)), 130),
    coalesce(min(cs.cod_fee_percent) filter (where cs.cod_fee_mode = 'percent_of_collect'), 1),
    coalesce(max(cs.cod_fee_percent) filter (where cs.cod_fee_mode = 'percent_of_collect'), 1)
  into v_delivery_min, v_delivery_max, v_cod_percent_min, v_cod_percent_max
  from public.courier_services cs
  where cs.tenant_id = v_tenant_id
    and cs.is_active = true;

  v_delivery_mid := (v_delivery_min + v_delivery_max) / 2;
  v_cod_charge_preview := round(v_resell_subtotal * coalesce(v_cod_percent_min, 1) / 100, 2);
  v_recipient_grand_total := v_resell_subtotal + v_delivery_mid + v_cod_charge_preview;

  return v_result || jsonb_build_object(
    'charge_estimates', jsonb_build_object(
      'delivery_min', v_delivery_min,
      'delivery_max', v_delivery_max,
      'delivery_mid', v_delivery_mid,
      'cod_percent_min', v_cod_percent_min,
      'cod_percent_max', v_cod_percent_max,
      'cod_charge_preview', v_cod_charge_preview
    ),
    'review_summary', jsonb_build_object(
      'total_units', coalesce((v_result->'totals'->>'item_count')::int, 0),
      'has_floor_violation', coalesce(v_has_floor_violation, false),
      'recipient_grand_total', v_recipient_grand_total,
      'can_continue', not coalesce(v_has_floor_violation, false)
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dropship_shop_cart(p_shop_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shop_type public.shop_type_enum;
  v_cart_id bigint;
  v_result jsonb;
begin
  select shop_type into v_shop_type
  from public.shops
  where id = p_shop_id
    and is_active = true;

  if v_shop_type is null then
    raise exception 'shop not found or inactive';
  end if;

  if v_shop_type <> 'dropship' then
    raise exception 'shop is not dropship';
  end if;

  v_cart_id := (public.get_or_create_shop_cart(p_shop_id)->'cart'->>'id')::bigint;

  select jsonb_build_object(
    'cart', jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'shop_id', c.shop_id,
      'shop_name', s.name,
      'shop_slug', s.slug,
      'customer_group_id', c.customer_group_id,
      'status', c.status,
      'allow_delivery', s.allow_delivery,
      'currency', jsonb_build_object(
        'id', s.sell_currency_id,
        'code', gc.code,
        'symbol', gc.symbol
      ),
      'charges', jsonb_build_object(
        'cod_charge_amount', c.cod_charge_amount,
        'delivery_charge_amount', c.delivery_charge_amount,
        'print_charge_amount', coalesce(nullif(c.print_charge_amount, 0), s.default_print_charge_amount),
        'packing_charge_amount', coalesce(nullif(c.packing_charge_amount, 0), s.default_packing_charge_amount),
        'discount_amount', c.discount_amount,
        'is_prepaid', c.is_prepaid,
        'delivery_instructions', c.delivery_instructions
      ),
      'margin_deductions', jsonb_build_object(
        'deduct_charges_from_margin', c.deduct_charges_from_margin,
        'deduct_print_from_margin', c.deduct_print_from_margin,
        'deduct_packing_from_margin', c.deduct_packing_from_margin
      ),
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'permissions', (
      select jsonb_build_object(
        'can_browse', p.can_browse,
        'can_see_buy_price', p.can_see_buy_price,
        'can_see_sell_price', p.can_see_sell_price,
        'can_see_resell_minimum_price', p.can_see_resell_minimum_price,
        'can_add_to_cart', p.can_add_to_cart,
        'can_place_order', p.can_place_order,
        'can_negotiate', p.can_negotiate,
        'can_view_quantity', p.can_view_quantity,
        'can_set_dropship_price', p.can_set_dropship_price
      )
      from public.get_shop_permissions_for_customer(p_shop_id) p
      limit 1
    ),
    'items', coalesce(items.items, '[]'::jsonb),
    'totals', coalesce(items.totals, jsonb_build_object(
      'item_count', 0,
      'line_count', 0,
      'purchase_subtotal', 0,
      'resell_subtotal', 0,
      'estimated_profit', 0
    ))
  )
  into v_result
  from public.shop_carts c
  join public.shops s on s.id = c.shop_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  left join lateral (
    select
      jsonb_agg(
        jsonb_build_object(
          'id', ci.id,
          'product_id', ci.product_id,
          'global_stock_id', ci.global_stock_id,
          'name', ci.name,
          'image_url', ci.image_url,
          'quantity', ci.quantity,
          'minimum_quantity', ci.minimum_quantity,
          'minimum_order_quantity', p.minimum_order_quantity,
          'purchase_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'listing_sell_price', jsonb_build_object(
            'amount', ci.unit_sell_price_amount,
            'currency_id', ci.unit_sell_price_currency_id,
            'code', sell_gc.code,
            'symbol', sell_gc.symbol
          ),
          'resell_price', jsonb_build_object(
            'amount', coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount),
            'currency_id', coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id),
            'code', coalesce(cust_gc.code, sell_gc.code),
            'symbol', coalesce(cust_gc.symbol, sell_gc.symbol)
          ),
          'min_resell_price', jsonb_build_object(
            'amount', ci.unit_minimum_sell_price_amount,
            'currency_id', ci.unit_minimum_sell_price_currency_id,
            'code', min_gc.code,
            'symbol', min_gc.symbol
          ),
          'line_totals', jsonb_build_object(
            'purchase_subtotal', ci.quantity * coalesce(ci.unit_sell_price_amount, 0),
            'resell_subtotal', ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
          ),
          'is_resell_below_floor', (
            coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
            and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
              < ci.unit_minimum_sell_price_amount
          )
        )
        order by ci.id
      ) as items,
      jsonb_build_object(
        'item_count', coalesce(sum(ci.quantity), 0),
        'line_count', count(ci.id),
        'purchase_subtotal', coalesce(sum(ci.quantity * coalesce(ci.unit_sell_price_amount, 0)), 0),
        'resell_subtotal', coalesce(sum(
          ci.quantity * coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
        ), 0),
        'estimated_profit', coalesce(sum(
          ci.quantity * (
            coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0)
            - coalesce(ci.unit_sell_price_amount, 0)
          )
        ), 0)
      ) as totals
    from public.shop_cart_items ci
    left join public.products p on p.id = ci.product_id
    left join public.global_currencies sell_gc on sell_gc.id = ci.unit_sell_price_currency_id
    left join public.global_currencies cust_gc on cust_gc.id = ci.customer_sell_price_currency_id
    left join public.global_currencies min_gc on min_gc.id = ci.unit_minimum_sell_price_currency_id
    where ci.cart_id = c.id
  ) items on true
  where c.id = v_cart_id;

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dropship_wallet_reconciliation_report(p_tenant_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_target_tenant_id bigint;
  v_missing_invoice_billed bigint := 0;
  v_missing_courier_remittance bigint := 0;
  v_missing_return_compensation bigint := 0;
  v_mixed_customer_profit bigint := 0;
  v_uncanonicalized_source_ids bigint := 0;
  v_conflicting_active_offers bigint := 0;
  v_missing_or_duplicate_gifts bigint := 0;
begin
  if p_tenant_id is not null then
    v_target_tenant_id := p_tenant_id;
  else
    v_target_tenant_id := public.current_tenant_id();
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where (v_target_tenant_id is null or m.tenant_id = v_target_tenant_id)
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Admin or Staff role required for reconciliation report';
  end if;

  -- 1. Posted dropship invoices missing invoice_billed (P0A contract)
  select count(*) into v_missing_invoice_billed
  from public.bills i
  where i.invoice_type = 'dropship'
    and i.invoice_status = 'posted'
    and i.billing_profile_id is not null
    and i.total_amount > 0
    and (v_target_tenant_id is null or i.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = i.tenant_id
        and u.entity_type = 'customer'
        and u.entity_id = i.billing_profile_id
        and u.source_type = 'shop_order'
        and u.metadata->>'transaction_type' = 'invoice_billed'
        and (u.metadata->>'invoice_id' = i.id::text or u.source_id = i.invoice_no)
    );

  -- 2. Remitted shop orders missing courier remittance UWL entry
  select count(*) into v_missing_courier_remittance
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'
    and o.courier_remittance_ref is not null
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = o.tenant_id
        and u.entity_type = 'courier'
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and u.metadata->>'purpose' = 'courier_remittance'
    );

  -- 3. Finalized returns missing return compensating UWL entry
  select count(*) into v_missing_return_compensation
  from public.shop_orders o
  where o.shop_type_snapshot = 'dropship'
    and o.status = 'returned'
    and (v_target_tenant_id is null or o.tenant_id = v_target_tenant_id)
    and not exists (
      select 1 from public.cashbook_entries u
      where u.tenant_id = o.tenant_id
        and u.source_type = 'shop_order'
        and u.source_id = o.id::text
        and (
          u.metadata->>'purpose' = 'dropship_return_finalize'
          or u.metadata->>'transaction_type' in (
            'return_reversal',
            'return_profit_clawback',
            'return_revenue_reversal'
          )
        )
    );

  -- 4. Mixed customer vs middleman profit rows
  select count(*) into v_mixed_customer_profit
  from public.cashbook_entries u
  where u.entity_type = 'customer'
    and u.source_type = 'shop_order'
    and u.metadata->>'transaction_type' = 'dropship_profit'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 5. Uncanonicalized source_ids (order_no instead of order_id string), exclude invoice_billed
  select count(*) into v_uncanonicalized_source_ids
  from public.cashbook_entries u
  join public.shop_orders o on o.tenant_id = u.tenant_id and o.order_no = u.source_id
  where u.source_type = 'shop_order'
    and coalesce(u.metadata->>'transaction_type', '') <> 'invoice_billed'
    and (v_target_tenant_id is null or u.tenant_id = v_target_tenant_id);

  -- 6. Conflicting active offer prices (P2 shop_product_offers)
  select count(*) into v_conflicting_active_offers
  from (
    select shop_id, product_id, condition_bucket
    from public.shop_product_offers
    where is_active = true
    group by shop_id, product_id, condition_bucket
    having count(*) > 1
  ) t;

  -- 7. Legacy gift rules removed - drift is 0
  v_missing_or_duplicate_gifts := 0;

  return jsonb_build_object(
    'reconciliation_time', now(),
    'tenant_id', v_target_tenant_id,
    'healthy', (
      v_missing_invoice_billed = 0 and
      v_missing_courier_remittance = 0 and
      v_missing_return_compensation = 0 and
      v_mixed_customer_profit = 0 and
      v_uncanonicalized_source_ids = 0 and
      v_conflicting_active_offers = 0 and
      v_missing_or_duplicate_gifts = 0
    ),
    'drift_counts', jsonb_build_object(
      'missing_invoice_billed', v_missing_invoice_billed,
      'missing_courier_remittance', v_missing_courier_remittance,
      'missing_return_compensation', v_missing_return_compensation,
      'mixed_customer_profit', v_mixed_customer_profit,
      'uncanonicalized_source_ids', v_uncanonicalized_source_ids,
      'conflicting_active_offers', v_conflicting_active_offers,
      'missing_or_duplicate_gifts', v_missing_or_duplicate_gifts
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_my_dropship_wallet_summary()
 RETURNS TABLE(billing_profile_id bigint, available_balance numeric, pending_balance numeric, locked_balance numeric, currency text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_email text := public.current_user_email();
  v_tenant_id bigint;
  v_group_id bigint;
  v_bp_id bigint;
  v_available numeric := 0;
  v_pending numeric := 0;
  v_locked numeric := 0;
begin
  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'Not authenticated';
  end if;

  select cg.tenant_id, cgm.customer_group_id
  into v_tenant_id, v_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = lower(trim(v_email))
    and cgm.is_active = true
    and cg.is_active = true
  order by cgm.id
  limit 1;

  if v_tenant_id is null or v_group_id is null then
    raise exception 'No active customer group membership';
  end if;

  v_bp_id := public.resolve_billing_profile_for_customer_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  select coalesce(w.available_balance, 0)
  into v_available
  from public.cashbook_accounts w
  where w.parent_tenant_id = public.resolve_parent_tenant_id(v_tenant_id)
    and w.entity_type = 'customer'
    and w.entity_id = v_bp_id
    and w.currency_code = 'BDT';

  select coalesce(sum(s.reseller_profit), 0)
  into v_pending
  from public.shop_orders o
  join public.dropship_order_settlements s on s.shop_order_id = o.id
  where o.tenant_id = v_tenant_id
    and o.billing_profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'::public.shop_order_status
    and coalesce(s.reseller_profit, 0) > 0
    and s.merchant_payout_at is null;

  select coalesce(sum(greatest(coalesce(o.cod_collect_amount, 0), 0)), 0)
  into v_locked
  from public.shop_orders o
  where o.tenant_id = v_tenant_id
    and o.billing_profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'delivered'
    and o.courier_remittance_ref is null
    and coalesce(o.collection_source, 'recipient') = 'recipient';

  return query select
    v_bp_id,
    v_available,
    v_pending,
    v_locked,
    'BDT'::text;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_parent_cash_circulation(p_parent_tenant_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  select
    coalesce(sum(case when type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_parent_tenant_id;

  select coalesce(sum(coalesce(allocated_cost, invested_amount)), 0) into v_deployed
  from public.shipment_investments
  where tenant_id = p_parent_tenant_id and status = 'active';

  select
    coalesce(sum(due_amount), 0),
    coalesce(sum(paid_amount), 0)
  into v_ar_due, v_ar_paid
  from public.bills
  where parent_tenant_id = p_parent_tenant_id;

  select coalesce(sum(
    public.calculate_landed_unit_cost(gs.shipment_item_id) * gs.quantity
  ), 0) into v_stock_cost
  from public.global_stocks gs
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.parent_tenant_id = p_parent_tenant_id
    and gst.is_sellable = true
    and gs.quantity > 0;

  with invoice_line_margin as (
    select
      ii.invoice_id,
      sum(ii.sell_price_amount * ii.quantity - ii.line_discount_amount) as lines_margin
    from public.global_invoice_items ii
    join public.bills i on i.id = ii.invoice_id
    where i.parent_tenant_id = p_parent_tenant_id
      and i.invoice_status = 'posted'::public.global_invoice_status
      and i.invoice_date >= date_trunc('month', current_date)::date
    group by ii.invoice_id
  ),
  invoice_return_margin as (
    select
      ri.invoice_id,
      sum(ri.return_accounting_amount) as returns_margin
    from public.global_return_items ri
    join public.global_invoice_items ii on ii.id = ri.invoice_item_id
    join public.bills i on i.id = ri.invoice_id
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
  from public.bills i
  left join invoice_line_margin lm on lm.invoice_id = i.id
  left join invoice_return_margin rm on rm.invoice_id = i.id
  where i.parent_tenant_id = p_parent_tenant_id
    and i.invoice_status = 'posted'::public.global_invoice_status
    and i.invoice_date >= date_trunc('month', current_date)::date;

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
$function$;

CREATE OR REPLACE FUNCTION public.get_payee_settlement_summary(p_tenant_id bigint, p_shipment_id bigint, p_entity_type text, p_entity_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.get_procurement_demand_open_qty(p_source_type preorder_demand_source_type, p_source_id bigint)
 RETURNS TABLE(tenant_id bigint, open_qty integer, document_status text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if p_source_type = 'shop_order_item' then
    return query
    select
      o.tenant_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      public.normalize_shop_order_procurement_status(o.status)
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.shop_type_snapshot = 'vendor_catalog';
  elsif p_source_type = 'pbc_costing_item' then
    return query
    select
      f.tenant_id,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer,
      public.normalize_pbc_procurement_status(f.status)
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    where pci.id = p_source_id
      and f.billing_profile_id is not null;
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_sales_invoice_dashboard_metrics(p_tenant_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS name,
      round(sum(si.due_amount), 2) AS due_amount,
      count(*)::bigint AS invoice_count
    FROM public.bills si
    LEFT JOIN public.billing_profiles bp ON bp.id = si.profile_id
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
$function$;

CREATE OR REPLACE FUNCTION public.get_shipment_pnl(p_tenant_id bigint, p_shipment_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_cost,
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
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
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
      coalesce(public.calculate_landed_unit_cost(si.id), 0) * coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_cost,
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
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
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
$function$;

CREATE OR REPLACE FUNCTION public.get_shop_order_dashboard_metrics(p_tenant_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_today date;
  v_sales numeric := 0;
  v_invoice_count bigint := 0;
  v_shipped bigint := 0;
  v_ready bigint := 0;
  v_needs_quote bigint := 0;
  v_processing bigint := 0;
  v_dropship_submitted bigint := 0;
  v_dropship_processing bigint := 0;
  v_dropship_ready bigint := 0;
  v_hourly jsonb := '[]'::jsonb;
  v_couriers jsonb := '[]'::jsonb;
  v_pipeline jsonb := '[]'::jsonb;
BEGIN
  IF NOT public.membership_has_module_action(p_tenant_id, 'shop_order', 'view') THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  v_today := (timezone('Asia/Dhaka', now()))::date;

  SELECT
    coalesce(sum(si.total_amount), 0),
    count(*)
  INTO v_sales, v_invoice_count
  FROM public.bills si
  WHERE si.issued_by_tenant_id = p_tenant_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_date = v_today;

  SELECT
    coalesce(count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status), 0),
    coalesce(count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status), 0)
  INTO v_shipped, v_ready
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id
    AND o.status IN (
      'shipped'::public.shop_order_status,
      'ready_for_pickup'::public.shop_order_status
    );

  SELECT
    coalesce(count(*) FILTER (
      WHERE o.status IN (
        'submitted'::public.shop_order_status,
        'costing_pending'::public.shop_order_status,
        'countered'::public.shop_order_status
      )
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.status IN (
        'processing'::public.shop_order_status,
        'confirmed'::public.shop_order_status,
        'procuring'::public.shop_order_status,
        'packed'::public.shop_order_status,
        'placed'::public.shop_order_status,
        'ordered'::public.shop_order_status
      )
    ), 0)
  INTO v_needs_quote, v_processing
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id;

  SELECT
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'submitted'::public.shop_order_status
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'processing'::public.shop_order_status
    ), 0),
    coalesce(count(*) FILTER (
      WHERE o.shop_type_snapshot = 'dropship'::public.shop_type_enum
        AND o.status = 'ready_for_pickup'::public.shop_order_status
    ), 0)
  INTO v_dropship_submitted, v_dropship_processing, v_dropship_ready
  FROM public.shop_orders o
  WHERE o.tenant_id = p_tenant_id;

  SELECT coalesce(jsonb_agg(row_to_json(p) ORDER BY p.sort_key), '[]'::jsonb)
  INTO v_pipeline
  FROM (
    SELECT
      bucket.status,
      count(*)::bigint AS count,
      bucket.sort_key
    FROM (
      SELECT
        CASE
          WHEN o.status IN (
            'submitted'::public.shop_order_status,
            'costing_pending'::public.shop_order_status,
            'countered'::public.shop_order_status
          ) THEN 'needs_quote'
          WHEN o.status IN (
            'priced'::public.shop_order_status,
            'final_offered'::public.shop_order_status,
            'negotiating'::public.shop_order_status
          ) THEN 'awaiting_customer'
          WHEN o.status IN (
            'processing'::public.shop_order_status,
            'confirmed'::public.shop_order_status,
            'procuring'::public.shop_order_status,
            'packed'::public.shop_order_status,
            'placed'::public.shop_order_status,
            'ordered'::public.shop_order_status
          ) THEN 'processing'
          WHEN o.status = 'ready_for_pickup'::public.shop_order_status THEN 'ready_for_pickup'
          WHEN o.status = 'shipped'::public.shop_order_status THEN 'shipped'
        END AS status,
        CASE
          WHEN o.status IN (
            'submitted'::public.shop_order_status,
            'costing_pending'::public.shop_order_status,
            'countered'::public.shop_order_status
          ) THEN 1
          WHEN o.status IN (
            'priced'::public.shop_order_status,
            'final_offered'::public.shop_order_status,
            'negotiating'::public.shop_order_status
          ) THEN 2
          WHEN o.status IN (
            'processing'::public.shop_order_status,
            'confirmed'::public.shop_order_status,
            'procuring'::public.shop_order_status,
            'packed'::public.shop_order_status,
            'placed'::public.shop_order_status,
            'ordered'::public.shop_order_status
          ) THEN 3
          WHEN o.status = 'ready_for_pickup'::public.shop_order_status THEN 4
          WHEN o.status = 'shipped'::public.shop_order_status THEN 5
        END AS sort_key
      FROM public.shop_orders o
      WHERE o.tenant_id = p_tenant_id
    ) bucket
    WHERE bucket.status IS NOT NULL
    GROUP BY bucket.status, bucket.sort_key
  ) p;

  SELECT coalesce(jsonb_agg(row_to_json(h) ORDER BY h.hour_at), '[]'::jsonb)
  INTO v_hourly
  FROM (
    SELECT
      date_trunc('hour', timezone('Asia/Dhaka', si.created_at)) AS hour_at,
      to_char(timezone('Asia/Dhaka', si.created_at), 'HH12 AM') AS label,
      round(sum(si.total_amount), 2) AS amount
    FROM public.bills si
    WHERE si.issued_by_tenant_id = p_tenant_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date = v_today
    GROUP BY 1, 2
  ) h;

  SELECT coalesce(jsonb_agg(row_to_json(c) ORDER BY c.count DESC), '[]'::jsonb)
  INTO v_couriers
  FROM (
    SELECT
      coalesce(nullif(trim(o.courier_name), ''), 'Store pickup') AS name,
      count(*)::bigint AS count,
      count(*) FILTER (WHERE o.status = 'shipped'::public.shop_order_status)::bigint AS shipped_count,
      count(*) FILTER (WHERE o.status = 'ready_for_pickup'::public.shop_order_status)::bigint AS ready_count
    FROM public.shop_orders o
    WHERE o.tenant_id = p_tenant_id
      AND o.status IN (
        'shipped'::public.shop_order_status,
        'ready_for_pickup'::public.shop_order_status
      )
    GROUP BY 1
  ) c;

  RETURN jsonb_build_object(
    'tenant_id', p_tenant_id,
    'today_sales_amount', round(v_sales, 2),
    'today_invoice_count', v_invoice_count,
    'shipped_count', v_shipped,
    'ready_for_pickup_count', v_ready,
    'needs_quote_count', v_needs_quote,
    'processing_count', v_processing,
    'dropship_submitted', v_dropship_submitted,
    'dropship_processing', v_dropship_processing,
    'dropship_ready', v_dropship_ready,
    'hourly', v_hourly,
    'couriers', v_couriers,
    'pipeline', v_pipeline
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_shop_order_for_staff(p_tenant_id bigint, p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_code text;
  v_sell_symbol text;
  v_buy_code text;
  v_buy_symbol text;
  v_customer_group_name text;
  v_item_count bigint;
  v_total_amount numeric;
  v_collection_source public.collection_source_type;
  v_items jsonb;
  v_invoices jsonb;
  v_shipments jsonb;
  v_order_json jsonb;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  select
    s.name,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.code,
    sell_gc.symbol,
    buy_gc.code,
    buy_gc.symbol
  into
    v_shop_name,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_code,
    v_sell_symbol,
    v_buy_code,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  v_collection_source := v_order.collection_source;
  if v_collection_source is null and v_order.global_invoice_id is not null then
    select inv.collection_source
    into v_collection_source
    from public.bills inv
    where inv.id = v_order.global_invoice_id;
  end if;
  if v_collection_source is null and v_order.is_prepaid_snapshot then
    v_collection_source := 'billing_profile'::public.collection_source_type;
  end if;

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.staff_offer_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        soi.unit_list_price_amount
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  if v_order.global_invoice_id is not null then
    v_invoices := jsonb_build_array(jsonb_build_object('id', v_order.global_invoice_id));
  else
    v_invoices := '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('id', x.shipment_id) order by x.shipment_id),
    '[]'::jsonb
  )
  into v_shipments
  from (
    select distinct gship.id as shipment_id
    from public.shop_order_items soi
    join public.global_stocks gs on gs.id = soi.global_stock_id
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) x;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at,
        'product', jsonb_build_object(
          'id', soi.product_id,
          'sku', p.product_code,
          'brand', p.brand,
          'barcode', p.barcode,
          'weight_gm', p.product_weight,
          'package_weight_gm', p.package_weight,
          'minimum_order_quantity', coalesce(p.minimum_order_quantity, 1)
        ),
        'pricing', jsonb_build_object(
          'cost', jsonb_build_object(
            'amount', coalesce(soi.cost_price_amount, soi.unit_list_price_amount, p.reference_cost_amount),
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = coalesce(
                soi.cost_price_currency_id,
                soi.unit_list_price_currency_id
              )
              limit 1
            )
          ),
          'list', jsonb_build_object(
            'amount', soi.unit_list_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_list_price_currency_id
              limit 1
            )
          ),
          'sell', jsonb_build_object(
            'amount', soi.unit_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_sell_price_currency_id
              limit 1
            )
          ),
          'minimum_sell', jsonb_build_object(
            'amount', soi.unit_minimum_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_minimum_sell_price_currency_id
              limit 1
            )
          )
        ),
        'negotiation', jsonb_build_object(
          'status', soi.negotiation_status,
          'customer_decision', soi.customer_decision_status,
          'staff_offer', case
            when soi.staff_offer_amount is not null then jsonb_build_object(
              'amount', soi.staff_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.staff_offer_currency_id
                limit 1
              ),
              'at', soi.staff_offer_at,
              'is_manual', soi.is_first_offer_manual
            )
            else null
          end,
          'customer_offer', case
            when soi.customer_offer_amount is not null then jsonb_build_object(
              'amount', soi.customer_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.customer_offer_currency_id
                limit 1
              ),
              'at', soi.customer_counter_at
            )
            else null
          end,
          'final_offer', case
            when soi.final_price_amount is not null then jsonb_build_object(
              'amount', soi.final_price_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.final_price_currency_id
                limit 1
              ),
              'at', soi.final_offer_at,
              'is_manual', soi.is_final_offer_manual
            )
            else null
          end,
          'weight_kg', soi.weight_kg,
          'confirmed_quantity', soi.confirmed_quantity
        ),
        'fulfillment', jsonb_build_object(
          'returned', soi.returned_quantity,
          'procurement_pulled', soi.procurement_pulled
        ),
        'stock', case
          when soi.global_stock_id is not null then jsonb_build_object(
            'global_stock_id', soi.global_stock_id,
            'global_stock_allocation_id', soi.global_stock_allocation_id,
            'shipment_item_id', gsi.id,
            'shipment_id', gship.id
          )
          else null
        end
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  left join public.global_stocks gs on gs.id = soi.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  where soi.order_id = v_order.id;

  v_order_json := jsonb_build_object(
    'id', v_order.id,
    'tenant_id', v_order.tenant_id,
    'order_no', v_order.order_no,
    'name', v_order.name,
    'cart_id', v_order.cart_id,
    'created_by_email', v_order.created_by_email,
    'created_at', v_order.created_at,
    'updated_at', v_order.updated_at,
    'placed_at', v_order.placed_at,
    'fulfilled_at', v_order.fulfilled_at,
    'global_invoice_id', v_order.global_invoice_id,
    'collection_source', v_collection_source,
    'shop', jsonb_build_object(
      'id', v_order.shop_id,
      'name', v_shop_name,
      'type', v_order.shop_type_snapshot,
      'order_mode', v_order.order_mode_snapshot,
      'is_negotiable', v_order.is_negotiable_snapshot,
      'sell_currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end,
      'buy_currency', case
        when v_buy_currency_id is not null then jsonb_build_object(
          'id', v_buy_currency_id,
          'code', v_buy_code,
          'symbol', v_buy_symbol
        )
        else null
      end
    ),
    'customer', jsonb_build_object(
      'group_id', v_order.customer_group_id,
      'group_name', v_customer_group_name
    ),
    'status', jsonb_build_object(
      'value', v_order.status,
      'negotiate_round', v_order.negotiate_round
    ),
    'rates', jsonb_build_object(
      'cargo', v_order.cargo_rate,
      'conversion', v_order.conversion_rate,
      'profit', v_order.profit_rate,
      'first_offer', v_order.first_offer_rate,
      'final_offer', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg
    ),
    'recipient', jsonb_build_object(
      'name', v_order.recipient_name,
      'phone', v_order.recipient_phone,
      'phone_secondary', v_order.recipient_phone_secondary,
      'address', v_order.shipping_address,
      'district', v_order.shipping_district,
      'thana', v_order.shipping_thana,
      'profile_id', v_order.recipient_profile_id,
      'billing_profile_id', v_order.billing_profile_id,
      'delivery_instructions', v_order.delivery_instructions,
      'is_prepaid', v_order.is_prepaid_snapshot
    ),
    'charges', jsonb_build_object(
      'cod', v_order.cod_charge_amount,
      'delivery', v_order.delivery_charge_amount,
      'print', v_order.print_charge_amount,
      'packing', v_order.packing_charge_amount,
      'discount', v_order.discount_amount,
      'deduct_from_margin', jsonb_build_object(
        'charges', v_order.deduct_charges_from_margin,
        'cod', v_order.deduct_cod_from_margin,
        'delivery', v_order.deduct_delivery_from_margin,
        'print', v_order.deduct_print_from_margin,
        'packing', v_order.deduct_packing_from_margin
      )
    ),
    'totals', jsonb_build_object(
      'item_count', v_item_count,
      'amount', v_total_amount,
      'currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end
    ),
    'courier', jsonb_build_object(
      'service_id', v_order.courier_service_id,
      'name', v_order.courier_name,
      'awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'order_ref', v_order.courier_order_ref,
      'tracking_number', v_order.courier_tracking_number,
      'consignment_id', v_order.courier_consignment_id,
      'cost_amount', v_order.courier_cost_amount,
      'delivered_at', v_order.delivered_at,
      'returned_at', v_order.returned_at
    ),
    'pickup', jsonb_build_object(
      'sender_name', v_order.sender_name,
      'phone', v_order.pickup_phone,
      'address', v_order.pickup_address,
      'default_sender_name', v_order.default_sender_name,
      'default_phone', v_order.default_pickup_phone,
      'default_address', v_order.default_pickup_address
    ),
    'payout', jsonb_build_object(
      'account_type', v_order.payout_account_type,
      'account_info', v_order.payout_account_info,
      'default_account_type', v_order.default_payout_account_type,
      'default_account_info', v_order.default_payout_account_info,
      'settlement_status', v_order.payout_settlement_status,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_remittance_ref', v_order.courier_remittance_ref,
      'courier_bank_trx_id', v_order.courier_bank_trx_id
    ),
    'parcel', jsonb_build_object(
      'weight_band', v_order.package_weight_band,
      'item_category', v_order.item_category,
      'description', v_order.parcel_description,
      'delivery_zone', v_order.delivery_zone,
      'allow_open_box', v_order.allow_open_box,
      'driver_notes', v_order.driver_notes,
      'delivery_instruction_notes', v_order.delivery_instruction_notes
    ),
    'return_info', jsonb_build_object(
      'sub_state', v_order.return_sub_state,
      'override_reason', v_order.return_override_reason,
      'ref', v_order.return_ref,
      'charge_amount', v_order.return_charge_amount,
      'deduct_charge_from_middle_man', v_order.deduct_return_charge_from_middle_man,
      'replacement_of_order_id', v_order.replacement_of_order_id,
      'middle_man_reference', v_order.middle_man_reference
    ),
    'links', jsonb_build_object(
      'invoices', v_invoices,
      'shipments', v_shipments
    )
  );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_cash_in_report(p_tenant_id bigint, p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_books_id bigint;
  v_cash_in numeric(18,4) := 0.0000;
  v_count integer := 0;
  v_by_method jsonb;
  v_entries jsonb;
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  select coalesce(t.parent_id, t.id)
  into v_books_id
  from public.tenants t
  where t.id = p_tenant_id;

  if v_books_id is null then
    raise exception 'Tenant not found';
  end if;

  if not (
    public.membership_has_module_action(p_tenant_id, 'universal_wallet', 'view')
    or public.membership_has_module_action(v_books_id, 'universal_wallet', 'view')
  ) then
    raise exception 'Not authorized';
  end if;

  with receipt_invoice as (
    select
      ip.payment_id,
      min(ip.global_invoice_id) as invoice_id
    from public.pay_allocations ip
    group by ip.payment_id
  ),
  receipt_lines as (
    select
      gp.id as payment_id,
      gp.id::text || '-' || coalesce(gpi.id::text, 'h') as line_id,
      coalesce(gpi.amount, gp.amount) as amount,
      case
        when gp.collection_source = 'recipient'::public.collection_source_type then 'courier_remittance'
        else 'buyer_receipt'
      end as source_type,
      gp.id::text as source_id,
      nullif(trim(gp.note), '') as label,
      ri.invoice_id,
      gp.created_at,
      coalesce(gpi.payment_method_code, nullif(trim(gp.method::text), ''), 'other') as method,
      gpi.reference as instrument_reference,
      gpi.cheque_number,
      bb.name as bank_name
    from public.pays gp
    left join public.pay_instruments gpi on gpi.payment_id = gp.id
    left join public.bd_banks bb on bb.id = gpi.bd_bank_id
    left join receipt_invoice ri on ri.payment_id = gp.id
    where gp.tenant_id = v_books_id
      and gp.voided_at is null
      and coalesce(gp.method::text, '') <> 'wallet_credit'
      and (p_start_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) >= p_start_date)
      and (p_end_date is null or coalesce(gp.payment_date::timestamptz, gp.created_at) <= p_end_date)
  ),
  lined as (
    select distinct on (line_id)
      line_id as id,
      amount,
      source_type,
      source_id,
      case
        when bank_name is not null and cheque_number is not null then
          coalesce(label, '') || ' Cheque ' || cheque_number || ' @ ' || bank_name
        when instrument_reference is not null then coalesce(label, instrument_reference)
        else label
      end as label,
      invoice_id,
      created_at,
      method
    from receipt_lines
    order by line_id, amount desc
  )
  select
    coalesce(sum(amount), 0.0000),
    count(*)::integer,
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'method', m.method,
          'amount', m.amt,
          'count', m.cnt
        ) order by m.amt desc)
        from (
          select method, sum(amount) as amt, count(*)::integer as cnt
          from lined
          group by method
        ) m
      ),
      '[]'::jsonb
    ),
    coalesce(
      (
        select jsonb_agg(jsonb_build_object(
          'id', e.id,
          'amount', e.amount,
          'method', e.method,
          'source_type', e.source_type,
          'source_id', e.source_id,
          'label', e.label,
          'invoice_id', e.invoice_id,
          'created_at', e.created_at
        ) order by e.created_at desc, e.id desc)
        from lined e
      ),
      '[]'::jsonb
    )
  into v_cash_in, v_count, v_by_method, v_entries
  from lined;

  return jsonb_build_object(
    'tenant_id', v_books_id,
    'start_date', p_start_date,
    'end_date', p_end_date,
    'cash_in_total', v_cash_in,
    'entry_count', v_count,
    'by_method', v_by_method,
    'entries', v_entries
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_courier_cod_report(p_tenant_id bigint, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_courier_service_id uuid DEFAULT NULL::uuid, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_skip_count boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_orders jsonb := NULL;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH delivered_orders AS (
    SELECT
      so.id AS order_id,
      so.order_no,
      coalesce(so.courier_awb_number, so.courier_tracking_number) AS awb,
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      so.courier_remittance_ref AS remittance_ref,
      so.delivered_at,
      so.courier_service_id,
      coalesce(cs.name, so.courier_name, 'Unassigned') AS courier_name,
      round(coalesce((
        SELECT l.amount
        FROM public.cashbook_entries l
        WHERE l.parent_tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    LEFT JOIN public.courier_services cs ON cs.id = so.courier_service_id
    WHERE public.resolve_parent_tenant_id(so.tenant_id) = v_books_id
      AND so.status IN ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status)
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
      AND (v_start_ts IS NULL OR so.delivered_at >= v_start_ts)
      AND (v_end_ts IS NULL OR so.delivered_at <= v_end_ts)
      AND (p_courier_service_id IS NULL OR so.courier_service_id = p_courier_service_id)
  ),
  order_amounts AS (
    SELECT *,
      remitted_amount AS remitted,
      round(greatest(cod_collect_amount - remitted_amount, 0), 2) AS unremitted,
      round(remitted_amount - cod_collect_amount, 2) AS short_over
    FROM delivered_orders
  ),
  courier_rows AS (
    SELECT
      courier_service_id,
      courier_name,
      round(coalesce(sum(cod_collect_amount), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      count(*)::bigint AS order_count
    FROM order_amounts
    GROUP BY courier_service_id, courier_name
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(delivered_cod), 0), 2) AS delivered_cod,
      round(coalesce(sum(remitted), 0), 2) AS remitted,
      round(coalesce(sum(unremitted), 0), 2) AS unremitted,
      round(coalesce(sum(short_over), 0), 2) AS short_over,
      coalesce(sum(order_count), 0)::bigint AS order_count
    FROM courier_rows
  ),
  paged AS (
    SELECT * FROM courier_rows ORDER BY delivered_cod DESC, courier_name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM courier_rows),
    (SELECT jsonb_build_object('delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'courier_service_id', courier_service_id, 'courier_name', courier_name,
      'delivered_cod', delivered_cod, 'remitted', remitted, 'unremitted', unremitted,
      'short_over', short_over, 'order_count', order_count
    ) ORDER BY delivered_cod DESC, courier_name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  IF p_courier_service_id IS NOT NULL THEN
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'order_id', order_id, 'order_no', order_no, 'awb', awb,
      'cod_collect_amount', cod_collect_amount, 'remittance_ref', remittance_ref, 'delivered_at', delivered_at,
      'remitted', remitted
    ) ORDER BY delivered_at DESC NULLS LAST, order_id DESC), '[]'::jsonb)
    INTO v_orders
    FROM order_amounts;
  END IF;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'orders', v_orders, 'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_invoice_book_report(p_tenant_id bigint, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_search text DEFAULT NULL::text, p_invoice_type text DEFAULT NULL::text, p_payment_status text DEFAULT NULL::text, p_issued_by_tenant_id bigint DEFAULT NULL::bigint, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_skip_count boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH invoice_returned AS (
    SELECT sii.invoice_id, coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii GROUP BY sii.invoice_id
  ),
  invoice_payments_agg AS (
    SELECT ip.global_invoice_id AS invoice_id,
      coalesce(sum(CASE WHEN coalesce(gp.method, '') <> 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS collected_cash,
      coalesce(sum(CASE WHEN gp.method = 'wallet_credit' THEN ip.amount ELSE 0 END), 0)::numeric(12,2) AS wallet_applied
    FROM public.pay_allocations ip
    JOIN public.pays gp ON gp.id = ip.payment_id
    WHERE ip.global_invoice_id IS NOT NULL
      AND gp.voided_at IS NULL
    GROUP BY ip.global_invoice_id
  ),
  base AS (
    SELECT
      si.id, si.invoice_no, si.invoice_date, si.invoice_type::text AS invoice_type,
      si.payment_status, si.profile_id AS billing_profile_id, si.due_amount,
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS customer_name,
      coalesce(child.name, parent.name) AS issued_by_name,
      round((si.total_amount + coalesce(ir.returned, 0)), 2) AS billed,
      round(coalesce(ir.returned, 0), 2) AS returned,
      round(coalesce(ipa.collected_cash, 0), 2) AS collected_cash,
      round(coalesce(ipa.wallet_applied, 0), 2) AS wallet_applied,
      round(coalesce(si.written_off_amount, 0), 2) AS settlement,
      round(coalesce(si.due_amount, 0), 2) AS still_due
    FROM public.bills si
    LEFT JOIN public.billing_profiles bp ON bp.id = si.profile_id
    LEFT JOIN public.tenants child ON child.id = si.issued_by_tenant_id
    LEFT JOIN public.tenants parent ON parent.id = si.parent_tenant_id
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    LEFT JOIN invoice_payments_agg ipa ON ipa.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND (p_start_date IS NULL OR si.invoice_date >= p_start_date)
      AND (p_end_date IS NULL OR si.invoice_date <= p_end_date)
      AND (p_invoice_type IS NULL OR btrim(p_invoice_type) = '' OR si.invoice_type::text = p_invoice_type)
      AND (p_payment_status IS NULL OR btrim(p_payment_status) = '' OR si.payment_status = p_payment_status)
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR si.invoice_no ILIKE ('%' || btrim(p_search) || '%')
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR si.recipient_name ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(billed), 0), 2) AS billed, round(coalesce(sum(returned), 0), 2) AS returned,
      round(coalesce(sum(collected_cash), 0), 2) AS collected_cash, round(coalesce(sum(wallet_applied), 0), 2) AS wallet_applied,
      round(coalesce(sum(settlement), 0), 2) AS settlement, round(coalesce(sum(still_due), 0), 2) AS still_due,
      count(*)::bigint AS invoice_count FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY invoice_date DESC, id DESC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object('billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due, 'invoice_count', invoice_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'invoice_no', invoice_no, 'invoice_date', invoice_date, 'invoice_type', invoice_type,
      'payment_status', payment_status, 'customer_name', customer_name, 'billing_profile_id', billing_profile_id,
      'issued_by_name', issued_by_name, 'billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due
    ) ORDER BY invoice_date DESC, id DESC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_invoice_profit_report(p_tenant_id bigint, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_search text DEFAULT NULL::text, p_invoice_type text DEFAULT NULL::text, p_issued_by_tenant_id bigint DEFAULT NULL::bigint, p_invoice_id bigint DEFAULT NULL::bigint, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_skip_count boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_lines jsonb := NULL;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH line_metrics AS (
    SELECT
      sii.invoice_id,
      sii.id AS item_id,
      sii.name_snapshot AS name,
      sii.barcode_snapshot AS barcode,
      sii.quantity,
      sii.return_quantity,
      greatest(sii.quantity - sii.return_quantity, 0) AS net_qty,
      round(
        greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
        - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0)),
        2
      ) AS net_revenue,
      0::numeric AS cogs
    FROM public.bill_lines sii
    JOIN public.bills si ON si.id = sii.invoice_id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND (p_invoice_id IS NULL OR si.id = p_invoice_id)
      AND (p_start_date IS NULL OR si.invoice_date >= p_start_date)
      AND (p_end_date IS NULL OR si.invoice_date <= p_end_date)
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
      AND (p_invoice_type IS NULL OR btrim(p_invoice_type) = '' OR si.invoice_type::text = p_invoice_type)
  ),
  invoice_metrics AS (
    SELECT
      si.id,
      si.invoice_no,
      si.invoice_date,
      si.invoice_type::text AS invoice_type,
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS customer_name,
      round(coalesce(sum(lm.net_qty), 0), 3) AS net_qty,
      round(coalesce(sum(lm.net_revenue), 0), 2) AS net_revenue,
      round(coalesce(sum(lm.cogs), 0), 2) AS cogs,
      round(coalesce(sum(lm.net_revenue - lm.cogs), 0), 2) AS realized_gp
    FROM public.bills si
    LEFT JOIN public.billing_profiles bp ON bp.id = si.profile_id
    LEFT JOIN line_metrics lm ON lm.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND (p_invoice_id IS NULL OR si.id = p_invoice_id)
      AND (p_start_date IS NULL OR si.invoice_date >= p_start_date)
      AND (p_end_date IS NULL OR si.invoice_date <= p_end_date)
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
      AND (p_invoice_type IS NULL OR btrim(p_invoice_type) = '' OR si.invoice_type::text = p_invoice_type)
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR si.invoice_no ILIKE ('%' || btrim(p_search) || '%')
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR si.recipient_name ILIKE ('%' || btrim(p_search) || '%')
      )
    GROUP BY si.id, si.invoice_no, si.invoice_date, si.invoice_type, bp.name, si.recipient_name
  ),
  enriched AS (
    SELECT *,
      CASE WHEN net_revenue > 0 THEN round((realized_gp / net_revenue) * 100, 2) ELSE 0 END AS gp_margin_pct
    FROM invoice_metrics
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(net_qty), 0), 3) AS net_sold_qty,
      round(coalesce(sum(net_revenue), 0), 2) AS net_revenue,
      round(coalesce(sum(cogs), 0), 2) AS cogs,
      round(coalesce(sum(realized_gp), 0), 2) AS realized_gp,
      CASE WHEN coalesce(sum(net_revenue), 0) > 0
        THEN round((coalesce(sum(realized_gp), 0) / coalesce(sum(net_revenue), 0)) * 100, 2) ELSE 0 END AS gp_margin_pct,
      count(*)::bigint AS invoice_count
    FROM enriched
  ),
  paged AS (
    SELECT * FROM enriched ORDER BY invoice_date DESC, id DESC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM enriched),
    (SELECT jsonb_build_object('net_sold_qty', net_sold_qty, 'net_revenue', net_revenue, 'cogs', cogs,
      'realized_gp', realized_gp, 'gp_margin_pct', gp_margin_pct, 'invoice_count', invoice_count) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'id', id, 'invoice_no', invoice_no, 'invoice_date', invoice_date, 'invoice_type', invoice_type,
      'customer_name', customer_name,
      'net_qty', net_qty, 'net_revenue', net_revenue, 'cogs', cogs, 'realized_gp', realized_gp, 'gp_margin_pct', gp_margin_pct
    ) ORDER BY invoice_date DESC, id DESC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  IF p_invoice_id IS NOT NULL THEN
    WITH line_metrics AS (
      SELECT
        sii.invoice_id,
        sii.id AS item_id,
        sii.name_snapshot AS name,
        sii.barcode_snapshot AS barcode,
        sii.quantity,
        sii.return_quantity,
        greatest(sii.quantity - sii.return_quantity, 0) AS net_qty,
        round(
          greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
          - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0)),
          2
        ) AS net_revenue,
        0::numeric AS cogs
      FROM public.bill_lines sii
      WHERE sii.invoice_id = p_invoice_id
    )
    SELECT coalesce(jsonb_agg(jsonb_build_object(
      'item_id', lm.item_id, 'name', lm.name, 'barcode', lm.barcode,
      'quantity', lm.quantity, 'return_quantity', lm.return_quantity, 'net_qty', lm.net_qty,
      'sell_price_amount', round(lm.net_revenue / nullif(lm.net_qty, 0), 2),
      'unit_cost_price', round(lm.cogs / nullif(lm.net_qty, 0), 2),
      'net_revenue', lm.net_revenue, 'cogs', lm.cogs, 'line_gp', round(lm.net_revenue - lm.cogs, 2)
    ) ORDER BY lm.item_id), '[]'::jsonb)
    INTO v_lines
    FROM line_metrics lm;
  END IF;

  RETURN jsonb_build_object(
    'totals', coalesce(v_totals, '{}'::jsonb),
    'rows', coalesce(v_rows, '[]'::jsonb),
    'lines', v_lines,
    'page', v_page,
    'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_month_snapshot_report(p_tenant_id bigint, p_month date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_books_id bigint;
  v_start date;
  v_end date;
  v_start_ts timestamptz;
  v_end_ts timestamptz;
  v_net_sales numeric(18,4) := 0;
  v_cogs numeric(18,4) := 0;
  v_gross_profit numeric(18,4) := 0;
  v_cash_collected numeric(18,4) := 0;
  v_ar_outstanding numeric(18,4) := 0;
  v_merchant_payable numeric(18,4) := 0;
  v_sales_by_invoice_type jsonb := '{}'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_month IS NULL THEN
    RAISE EXCEPTION 'Tenant ID and month are required';
  END IF;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_start := date_trunc('month', p_month)::date;
  v_end := (date_trunc('month', p_month) + interval '1 month' - interval '1 day')::date;
  v_start_ts := v_start::timestamptz;
  v_end_ts := (v_end + interval '1 day' - interval '1 microsecond');

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  WITH invoice_returned AS (
    SELECT sii.invoice_id, coalesce(sum(sii.return_quantity * sii.sell_price_amount), 0)::numeric(12,2) AS returned
    FROM public.bill_lines sii GROUP BY sii.invoice_id
  ),
  month_invoices AS (
    SELECT si.id, si.invoice_type::text AS invoice_type, si.total_amount, coalesce(ir.returned, 0) AS returned
    FROM public.bills si
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  line_metrics AS (
    SELECT
      round(coalesce(sum(
        greatest(sii.quantity - sii.return_quantity, 0) * sii.sell_price_amount
        - coalesce(sii.line_discount_amount, 0) * (greatest(sii.quantity - sii.return_quantity, 0) / nullif(sii.quantity, 0))
      ), 0), 2) AS net_revenue,
      0::numeric AS cogs
    FROM public.bill_lines sii
    JOIN public.bills si ON si.id = sii.invoice_id
    WHERE si.parent_tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.invoice_date BETWEEN v_start AND v_end
  ),
  sales_by_type AS (
    SELECT invoice_type, round(coalesce(sum(total_amount), 0), 2) AS sales
    FROM month_invoices
    GROUP BY invoice_type
  )
  SELECT
    round(coalesce((SELECT sum(total_amount) FROM month_invoices), 0), 2),
    round(coalesce((SELECT cogs FROM line_metrics), 0), 2),
    coalesce((SELECT jsonb_object_agg(invoice_type, sales) FROM sales_by_type), '{}'::jsonb)
  INTO v_net_sales, v_cogs, v_sales_by_invoice_type;

  v_gross_profit := round(v_net_sales - v_cogs, 2);

  SELECT round(coalesce(sum(gp.amount), 0), 2)
  INTO v_cash_collected
  FROM public.pays gp
  WHERE gp.tenant_id = v_books_id
    AND gp.voided_at IS NULL
    AND coalesce(gp.method::text, '') <> 'wallet_credit'
    AND coalesce(gp.payment_date::timestamptz, gp.created_at) BETWEEN v_start_ts AND v_end_ts;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ar_outstanding
  FROM public.bills si
  WHERE si.parent_tenant_id = v_books_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.profile_id IS NOT NULL
    AND si.due_amount > 0;

  SELECT round(
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0)
    + coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    2
  )
  INTO v_merchant_payable
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  RETURN jsonb_build_object(
    'tenant_id', v_books_id,
    'month', v_start,
    'start_date', v_start,
    'end_date', v_end,
    'sales_by_invoice_type', v_sales_by_invoice_type,
    'kpis', jsonb_build_object(
      'net_sales', v_net_sales,
      'cogs', v_cogs,
      'gross_profit', v_gross_profit,
      'cash_collected', v_cash_collected,
      'ar_outstanding', v_ar_outstanding,
      'merchant_payable', v_merchant_payable
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_shipment_profit_report(p_tenant_id bigint, p_shipment_id bigint DEFAULT NULL::bigint, p_search text DEFAULT NULL::text, p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_page integer DEFAULT 1, p_page_size integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_books_id bigint;
  v_summary jsonb;
  v_rows jsonb;
  v_total_count integer := 0;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(coalesce(p_page_size, 20), 1);
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'Tenant ID is required';
  END IF;

  SELECT coalesce(t.parent_id, t.id)
  INTO v_books_id
  FROM public.tenants t
  WHERE t.id = p_tenant_id;

  IF v_books_id IS NULL THEN
    RAISE EXCEPTION 'Tenant not found';
  END IF;

  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(p_tenant_id, 'global_shipment', 'view')
    OR public.membership_has_module_action(v_books_id, 'global_shipment', 'view')
  ) THEN
    RAISE EXCEPTION 'Not authorized';
  END IF;

  WITH shipment_metrics AS (
    SELECT
      s.id AS shipment_id,
      s.name AS shipment_name,
      s.tenant_shipment_id::text AS shipment_code,
      s.status AS shipment_status,
      s.created_at,
      s.shipment_cost_currency_id AS currency_id,
      
      -- Inbound Quantities & Landed Cost (ordered manifest, not sold-only received)
      coalesce(sum(gsi.ordered_quantity), 0)::int AS inbound_quantity,
      coalesce(sum(gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS total_landed_cost,
      
      -- Sales & Returns from Issued Sales Invoices (invoice_status = 'issued')
      coalesce(sum(sales.sold_qty), 0)::int AS sold_quantity,
      coalesce(sum(sales.returned_qty), 0)::int AS returned_quantity,
      coalesce(sum(sales.net_sold_qty), 0)::int AS net_sold_quantity,
      coalesce(sum(sales.sold_revenue), 0)::numeric(18,4) AS gross_sold_revenue,
      coalesce(sum(sales.cogs), 0)::numeric(18,4) AS cogs_amount,
      coalesce(sum(sales.sold_revenue - sales.cogs), 0)::numeric(18,4) AS realized_gross_profit,
      
      -- Inventory Valuation & Damage
      coalesce(sum(inv.sellable_qty), 0)::int AS sellable_stock_qty,
      coalesce(sum(inv.held_qty), 0)::int AS held_stock_qty,
      coalesce(sum(inv.unsellable_qty), 0)::int AS damaged_stock_qty,
      coalesce(sum(
        greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
        * coalesce(gsi.landed_cost_bdt, 0)
      ), 0)::numeric(18,4) AS unsold_stock_value,
      coalesce(sum(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0)), 0)::numeric(18,4) AS damage_loss_value,

      -- Item details array if single shipment requested
      CASE WHEN p_shipment_id IS NOT NULL THEN
        coalesce(
          jsonb_agg(
            jsonb_build_object(
              'item_id', gsi.id,
              'product_name', coalesce(gsi.name, 'Item #' || gsi.id),
              'barcode', gsi.barcode,
              'inbound_qty', gsi.ordered_quantity,
              'unit_cost_bdt', gsi.landed_cost_bdt,
              'total_cost_bdt', (gsi.ordered_quantity * coalesce(gsi.landed_cost_bdt, 0)),
              'sold_qty', coalesce(sales.net_sold_qty, 0),
              'sold_revenue', coalesce(sales.sold_revenue, 0),
              'cogs', coalesce(sales.cogs, 0),
              'gross_profit', coalesce(sales.sold_revenue - sales.cogs, 0),
              'sellable_qty', coalesce(inv.sellable_qty, 0),
              'unsold_stock_value', coalesce(
                greatest(gsi.ordered_quantity - coalesce(sales.net_sold_qty, 0), coalesce(inv.sellable_qty, 0))
                * coalesce(gsi.landed_cost_bdt, 0),
                0
              ),
              'damaged_qty', coalesce(inv.unsellable_qty, 0),
              'damage_loss_value', coalesce(inv.unsellable_qty * coalesce(gsi.landed_cost_bdt, 0), 0)
            )
          ) FILTER (WHERE gsi.id IS NOT NULL),
          '[]'::jsonb
        )
      ELSE NULL END AS items

    FROM public.global_shipments s
    LEFT JOIN public.global_shipment_items gsi ON gsi.shipment_id = s.id
    
    -- Subquery for aggregated sales per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(gii.quantity), 0) AS sold_qty,
        coalesce(sum(gii.return_quantity), 0) AS returned_qty,
        coalesce(sum(gii.quantity - gii.return_quantity), 0) AS net_sold_qty,
        coalesce(sum(
          gii.sell_price_amount * (gii.quantity - coalesce(gii.return_quantity, 0))
          - coalesce(gii.line_discount_amount, 0) * (greatest(gii.quantity - gii.return_quantity, 0) / nullif(gii.quantity, 0))
          - CASE
            WHEN si.invoice_type = 'dropship'::public.global_invoice_type THEN 0.00
            ELSE (coalesce(si.discount_amount, 0.00) + coalesce(si.written_off_amount, 0.00))
              * (gii.line_total_amount / nullif(invagg.inv_line_subtotal, 0.00))
          END
        ), 0) AS sold_revenue,
        coalesce(sum((gii.quantity - gii.return_quantity) * coalesce(gsi.landed_cost_bdt, 0)), 0) AS cogs
      FROM public.global_invoice_items gii
      JOIN public.bills si ON si.id = gii.invoice_id
      LEFT JOIN LATERAL (
        SELECT coalesce(sum(x.line_total_amount), 0.00) AS inv_line_subtotal
        FROM public.global_invoice_items x
        WHERE x.invoice_id = gii.invoice_id
      ) invagg ON true
      WHERE gii.shipment_item_id = gsi.id
        AND si.invoice_status = 'issued'
    ) sales ON true

    -- Subquery for inventory breakdown per shipment item
    LEFT JOIN LATERAL (
      SELECT
        coalesce(sum(CASE WHEN gs.availability = 'sellable' THEN gs.quantity ELSE 0 END), 0) AS sellable_qty,
        coalesce(sum(CASE WHEN gs.availability = 'held' THEN gs.quantity ELSE 0 END), 0) AS held_qty,
        coalesce(sum(CASE WHEN gs.availability = 'unsellable' THEN gs.quantity ELSE 0 END), 0) AS unsellable_qty
      FROM public.global_stocks gs
      WHERE gs.shipment_item_id = gsi.id
    ) inv ON true

    WHERE s.parent_tenant_id = v_books_id
      AND (p_shipment_id IS NULL OR s.id = p_shipment_id)
      AND (p_start_date IS NULL OR s.created_at >= p_start_date)
      AND (p_end_date IS NULL OR s.created_at <= p_end_date)
      AND (
        p_search IS NULL 
        OR btrim(p_search) = ''
        OR s.name ILIKE ('%' || btrim(p_search) || '%')
        OR (s.tenant_shipment_id IS NOT NULL AND s.tenant_shipment_id::text ILIKE ('%' || btrim(p_search) || '%'))
      )
    GROUP BY s.id, s.name, s.tenant_shipment_id, s.status, s.created_at, s.shipment_cost_currency_id
  ),
  counted AS (
    SELECT count(*) AS total_count FROM shipment_metrics
  ),
  summary_calc AS (
    SELECT
      coalesce(sum(inbound_quantity), 0)::int AS total_inbound_units,
      coalesce(sum(total_landed_cost), 0)::numeric(18,4) AS total_landed_cost,
      coalesce(sum(net_sold_quantity), 0)::int AS total_net_sold_units,
      coalesce(sum(gross_sold_revenue), 0)::numeric(18,4) AS total_gross_sold_revenue,
      coalesce(sum(cogs_amount), 0)::numeric(18,4) AS total_cogs,
      coalesce(sum(realized_gross_profit), 0)::numeric(18,4) AS total_realized_gross_profit,
      CASE
        WHEN coalesce(sum(gross_sold_revenue), 0) > 0
        THEN round((coalesce(sum(realized_gross_profit), 0) / sum(gross_sold_revenue) * 100)::numeric, 2)
        ELSE 0.00
      END AS overall_realized_gp_margin_pct,
      coalesce(sum(unsold_stock_value), 0)::numeric(18,4) AS total_unsold_stock_value,
      coalesce(sum(damage_loss_value), 0)::numeric(18,4) AS total_damage_loss_value,
      count(*)::int AS total_shipments_count
    FROM shipment_metrics
  ),
  paginated_rows AS (
    SELECT
      sm.*,
      CASE
        WHEN sm.gross_sold_revenue > 0
        THEN round((sm.realized_gross_profit / sm.gross_sold_revenue * 100)::numeric, 2)
        ELSE 0.00
      END AS realized_gp_margin_pct,
      CASE
        WHEN sm.inbound_quantity > 0
        THEN round((sm.net_sold_quantity::numeric / sm.inbound_quantity::numeric * 100)::numeric, 1)
        ELSE 0.0
      END AS batch_sold_pct
    FROM shipment_metrics sm
    ORDER BY sm.created_at DESC, sm.shipment_id DESC
    OFFSET (v_page - 1) * v_page_size
    LIMIT v_page_size
  )
  SELECT
    to_jsonb(s),
    coalesce((SELECT total_count FROM counted), 0),
    coalesce(jsonb_agg(to_jsonb(r)), '[]'::jsonb)
  INTO v_summary, v_total_count, v_rows
  FROM summary_calc s
  CROSS JOIN paginated_rows r
  GROUP BY to_jsonb(s);

  RETURN jsonb_build_object(
    'summary', coalesce(v_summary, jsonb_build_object(
      'total_inbound_units', 0,
      'total_landed_cost', 0,
      'total_net_sold_units', 0,
      'total_gross_sold_revenue', 0,
      'total_cogs', 0,
      'total_realized_gross_profit', 0,
      'overall_realized_gp_margin_pct', 0,
      'total_unsold_stock_value', 0,
      'total_damage_loss_value', 0,
      'total_shipments_count', 0
    )),
    'shipments', coalesce(v_rows, '[]'::jsonb),
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', CASE WHEN v_total_count = 0 THEN 1 ELSE ceil(v_total_count::numeric / v_page_size::numeric)::int END
    )
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_tenant_wallet_liability_report(p_tenant_id bigint, p_start_date date DEFAULT NULL::date, p_end_date date DEFAULT NULL::date, p_search text DEFAULT NULL::text, p_page integer DEFAULT 1, p_page_size integer DEFAULT 50, p_skip_count boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_books_id bigint;
  v_totals jsonb;
  v_rows jsonb;
  v_total_count bigint;
  v_page integer := greatest(coalesce(p_page, 1), 1);
  v_page_size integer := greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_offset integer := (greatest(coalesce(p_page, 1), 1) - 1) * greatest(least(coalesce(p_page_size, 50), 200), 1);
  v_start_ts timestamptz := CASE WHEN p_start_date IS NULL THEN NULL ELSE p_start_date::timestamptz END;
  v_end_ts timestamptz := CASE WHEN p_end_date IS NULL THEN NULL ELSE (p_end_date + interval '1 day' - interval '1 microsecond') END;
  v_customer_store_credit numeric(18,4) := 0;
  v_merchant_payable numeric(18,4) := 0;
  v_courier numeric(18,4) := 0;
BEGIN
  IF p_tenant_id IS NULL THEN RAISE EXCEPTION 'Tenant ID is required'; END IF;
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  IF NOT (
    public.membership_has_module_action(p_tenant_id, 'reporting_treasury', 'view')
    OR public.membership_has_module_action(v_books_id, 'reporting_treasury', 'view')
  ) THEN RAISE EXCEPTION 'Not authorized'; END IF;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance + available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'courier' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_merchant_payable, v_courier
  FROM public.cashbook_accounts
  WHERE parent_tenant_id = v_books_id;

  WITH ledger_agg AS (
    SELECT
      l.entity_id AS billing_profile_id,
      round(
        coalesce(sum(CASE
          WHEN l.type = 'credit'
            AND coalesce(l.metadata->>'reversed_by', '') = ''
            AND coalesce(l.metadata->>'purpose', '') IN ('customer_ar_reduction', 'store_credit')
          THEN l.amount
          ELSE 0
        END), 0)
        - coalesce(sum(CASE
          WHEN l.type = 'debit'
            AND coalesce(l.metadata->>'purpose', '') IN ('reverse_customer_ar_reduction', 'void_store_credit')
          THEN l.amount
          ELSE 0
        END), 0),
        4
      ) AS credit_issued,
      round(coalesce(sum(CASE
        WHEN l.type = 'debit' AND coalesce(l.metadata->>'purpose', '') = 'apply_store_credit' THEN l.amount
        ELSE 0 END), 0), 4) AS credit_applied
    FROM public.cashbook_entries l
    WHERE l.parent_tenant_id = v_books_id
      AND l.entity_type = 'customer'
      AND (v_start_ts IS NULL OR l.created_at >= v_start_ts)
      AND (v_end_ts IS NULL OR l.created_at <= v_end_ts)
    GROUP BY l.entity_id
  ),
  base AS (
    SELECT
      wa.entity_id AS billing_profile_id,
      bp.name,
      bp.phone,
      round(coalesce(la.credit_issued, 0), 2) AS credit_issued,
      round(coalesce(la.credit_applied, 0), 2) AS credit_applied,
      round(coalesce(wa.available_balance, 0), 2) AS outstanding
    FROM public.cashbook_accounts wa
    JOIN public.billing_profiles bp ON bp.id = wa.entity_id
    LEFT JOIN ledger_agg la ON la.billing_profile_id = wa.entity_id
    WHERE wa.parent_tenant_id = v_books_id
      AND wa.entity_type = 'customer'
      AND (
        coalesce(wa.available_balance, 0) > 0
        OR coalesce(la.credit_issued, 0) > 0
        OR coalesce(la.credit_applied, 0) > 0
      )
      AND (
        p_search IS NULL OR btrim(p_search) = ''
        OR bp.name ILIKE ('%' || btrim(p_search) || '%')
        OR bp.phone ILIKE ('%' || btrim(p_search) || '%')
      )
  ),
  totals_calc AS (
    SELECT round(coalesce(sum(credit_issued), 0), 2) AS credit_issued,
      round(coalesce(sum(credit_applied), 0), 2) AS credit_applied,
      round(coalesce(sum(outstanding), 0), 2) AS outstanding,
      count(*)::bigint AS customer_count
    FROM base
  ),
  paged AS (
    SELECT * FROM base ORDER BY outstanding DESC, name ASC OFFSET v_offset LIMIT v_page_size
  )
  SELECT (SELECT count(*) FROM base),
    (SELECT jsonb_build_object(
      'credit_issued', credit_issued, 'credit_applied', credit_applied,
      'outstanding', outstanding, 'customer_count', customer_count,
      'customer_store_credit', v_customer_store_credit,
      'merchant_payable', v_merchant_payable,
      'courier', v_courier
    ) FROM totals_calc),
    coalesce((SELECT jsonb_agg(jsonb_build_object(
      'billing_profile_id', billing_profile_id, 'name', name, 'phone', phone,
      'credit_issued', credit_issued, 'credit_applied', credit_applied, 'outstanding', outstanding
    ) ORDER BY outstanding DESC, name ASC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$function$;

CREATE OR REPLACE FUNCTION public.get_wallet_account_balances(p_tenant_id bigint, p_entity_type text, p_entity_id bigint, p_currency_code text DEFAULT 'BDT'::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.get_wallet_dashboard_summary(p_tenant_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.get_wallet_entity_statement(p_tenant_id bigint, p_entity_type text, p_entity_id bigint, p_start_date timestamp with time zone DEFAULT NULL::timestamp with time zone, p_end_date timestamp with time zone DEFAULT NULL::timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.global_stock_hold_qty(p_global_stock_id bigint)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select
    coalesce((
      select sum(gii.quantity - coalesce(gii.return_quantity, 0))
      from public.global_invoice_items gii
      join public.bills gi on gi.id = gii.invoice_id
      where gii.global_stock_id = p_global_stock_id
        and gi.invoice_status = 'draft'::public.global_invoice_status
    ), 0)
    + coalesce((
      select sum(sci.quantity)
      from public.shop_cart_items sci
      where sci.global_stock_id = p_global_stock_id
    ), 0);
$function$;

CREATE OR REPLACE FUNCTION public.insert_global_payment_instruments(p_payment_id bigint, p_instruments jsonb)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      bd_bank_id, cheque_number, cheque_date, sort_order
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
      v_sort
    );
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.investor_uwl_flow_total(p_tenant_id bigint, p_investor_id bigint, p_flow text)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(abs(uwl.amount)), 0)::numeric(12,2)
  from public.cashbook_entries uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
    and (
      (
        p_flow = 'in'
        and uwl.type = 'credit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'capital_in', 'capital_adjustment', 'manual_adjustment', 'deposit'
        )
      )
      or (
        p_flow = 'out'
        and uwl.type = 'debit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'withdrawal_paid', 'withdrawal', 'profit_payout'
        )
      )
    );
$function$;

CREATE OR REPLACE FUNCTION public.investor_uwl_flow_total_range(p_tenant_id bigint, p_investor_id bigint, p_flow text, p_start_date date, p_end_date date)
 RETURNS numeric
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(sum(abs(uwl.amount)), 0)::numeric(12,2)
  from public.cashbook_entries uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_id = p_investor_id
    and uwl.entity_type = 'investor'
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
    and uwl.created_at::date >= p_start_date
    and uwl.created_at::date <= p_end_date
    and (
      (
        p_flow = 'in'
        and uwl.type = 'credit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'capital_in', 'capital_adjustment', 'manual_adjustment', 'deposit'
        )
      )
      or (
        p_flow = 'out'
        and uwl.type = 'debit'
        and coalesce(uwl.metadata->>'transaction_type', '') in (
          'withdrawal_paid', 'withdrawal', 'profit_payout'
        )
      )
    );
$function$;

CREATE OR REPLACE FUNCTION public.issue_dropship_tenant_b2b_invoice(p_tenant_id bigint, p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
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
        'billing_profile_id', v_invoice.profile_id,
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
    delete from public.bill_charges where invoice_id = v_orphan_invoice_id;
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
      'billing_profile_id', v_invoice.profile_id,
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
$function$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_invoice(p_invoice_id bigint, p_items jsonb DEFAULT NULL::jsonb)
 RETURNS bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.list_customer_accounts(p_tenant_id bigint, p_search text DEFAULT NULL::text)
 RETURNS TABLE(id bigint, customer_group_id bigint, billing_profile_id bigint, group_name text, admin_name text, email text, phone text, address text, accent_color text, is_active boolean, member_count bigint, wallet_available_balance numeric, created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_books_id bigint;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    cg.id,
    cg.id as customer_group_id,
    bp.id as billing_profile_id,
    cg.name as group_name,
    coalesce(bp.name, cg.name) as admin_name,
    bp.email,
    nullif(concat_ws(' ', bp.phone_country_code, bp.phone), '') as phone,
    bp.address,
    coalesce(cg.accent_color, '#B45F34') as accent_color,
    cg.is_active,
    coalesce(mem.cnt, 0::bigint) as member_count,
    coalesce(wa.available_balance, 0.00) as wallet_available_balance,
    cg.created_at
  from public.customer_groups cg
  left join public.billing_profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  left join (
    select cgm.customer_group_id as c_group_id, count(*) as cnt
    from public.customer_group_members cgm
    group by cgm.customer_group_id
  ) mem on mem.c_group_id = cg.id
  left join public.cashbook_accounts wa
    on wa.parent_tenant_id = v_books_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
   and wa.currency_code = 'BDT'
  where cg.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      p_search is null
      or trim(p_search) = ''
      or cg.name ilike '%' || trim(p_search) || '%'
      or bp.name ilike '%' || trim(p_search) || '%'
      or bp.email ilike '%' || trim(p_search) || '%'
      or bp.phone ilike '%' || trim(p_search) || '%'
      or bp.phone_country_code ilike '%' || trim(p_search) || '%'
      or bp.address ilike '%' || trim(p_search) || '%'
    )
  order by cg.id desc;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_customer_accounts_paginated(p_tenant_id bigint, p_page integer DEFAULT 1, p_page_size integer DEFAULT 20, p_search text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_books_id bigint;
  v_page integer;
  v_page_size integer;
  v_total_count bigint;
  v_total_pages integer;
  v_data jsonb;
  v_search text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_page := greatest(coalesce(p_page, 1), 1);
  v_page_size := greatest(1, least(coalesce(p_page_size, 20), 200));
  v_search := nullif(trim(coalesce(p_search, '')), '');

  select count(*)
  into v_total_count
  from public.customer_groups cg
  left join public.billing_profiles bp
    on bp.customer_group_id = cg.id
   and bp.parent_tenant_id = v_books_id
  where cg.parent_tenant_id = v_books_id
    and cg.deleted_at is null
    and (
      v_search is null
      or cg.name ilike '%' || v_search || '%'
      or bp.name ilike '%' || v_search || '%'
      or bp.email ilike '%' || v_search || '%'
      or bp.phone ilike '%' || v_search || '%'
      or bp.phone_country_code ilike '%' || v_search || '%'
      or bp.address ilike '%' || v_search || '%'
    );

  select coalesce(jsonb_agg(row_json order by sort_id desc), '[]'::jsonb)
  into v_data
  from (
    select
      cg.id as sort_id,
      jsonb_build_object(
        'id', cg.id,
        'customer_group_id', cg.id,
        'billing_profile_id', bp.id,
        'group_name', cg.name,
        'admin_name', coalesce(bp.name, cg.name),
        'email', bp.email,
        'phone', nullif(concat_ws(' ', bp.phone_country_code, bp.phone), ''),
        'address', bp.address,
        'accent_color', coalesce(cg.accent_color, '#B45F34'),
        'is_active', cg.is_active,
        'member_count', coalesce(mem.cnt, 0::bigint),
        'wallet_available_balance', coalesce(wa.available_balance, 0.00),
        'created_at', cg.created_at
      ) as row_json
    from public.customer_groups cg
    left join public.billing_profiles bp
      on bp.customer_group_id = cg.id
     and bp.parent_tenant_id = v_books_id
    left join (
      select cgm.customer_group_id as c_group_id, count(*) as cnt
      from public.customer_group_members cgm
      group by cgm.customer_group_id
    ) mem on mem.c_group_id = cg.id
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_books_id
     and wa.entity_type = 'customer'
     and wa.entity_id = bp.id
     and wa.currency_code = 'BDT'
    where cg.parent_tenant_id = v_books_id
      and cg.deleted_at is null
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or bp.name ilike '%' || v_search || '%'
        or bp.email ilike '%' || v_search || '%'
        or bp.phone ilike '%' || v_search || '%'
        or bp.phone_country_code ilike '%' || v_search || '%'
        or bp.address ilike '%' || v_search || '%'
      )
    order by cg.id desc
    limit v_page_size
    offset (v_page - 1) * v_page_size
  ) q;

  if v_total_count = 0 then
    v_total_pages := 0;
  else
    v_total_pages := ceil(v_total_count::numeric / v_page_size)::integer;
  end if;

  return jsonb_build_object(
    'data', v_data,
    'meta', jsonb_build_object(
      'total', v_total_count,
      'page', v_page,
      'page_size', v_page_size,
      'total_pages', v_total_pages
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_customer_group_receipts(p_tenant_id bigint, p_customer_group_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      gp.profile_id as billing_profile_id,
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
          select bp.id from public.billing_profiles bp where bp.customer_group_id = p_customer_group_id
        )
      )
      and coalesce(gp.method, '') <> 'wallet_credit'
    order by gp.voided_at nulls first, gp.payment_date desc, gp.id desc
  ) r;

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_customer_groups_payment_summary(p_tenant_id bigint, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0, p_only_with_due boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
        (select bp.phone from public.billing_profiles bp where bp.customer_group_id = cg.id and bp.phone is not null limit 1),
        '—'
      ) as phone,
      coalesce(
        (select array_agg(bp.name order by bp.name) from public.billing_profiles bp where bp.customer_group_id = cg.id),
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
           or gp.profile_id in (select id from public.billing_profiles where customer_group_id = cg.id)
      ) as last_payment_date
    from public.customer_groups cg
    left join public.billing_profiles bp on bp.customer_group_id = cg.id
    left join public.bills si on si.profile_id = bp.id
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or cg.name ilike '%' || trim(p_search) || '%'
        or bp.name ilike '%' || trim(p_search) || '%'
        or bp.phone ilike '%' || trim(p_search) || '%'
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
$function$;

CREATE OR REPLACE FUNCTION public.list_customer_groups_payout_summary(p_tenant_id bigint, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_customer_group_id bigint DEFAULT NULL::bigint, p_only_with_payable boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
              'billing_profile_id', bp2.id,
              'name', bp2.name,
              'payable_balance', coalesce(wa2.available_balance, 0.00)
            )
            order by coalesce(wa2.available_balance, 0.00) desc, bp2.name
          ),
          '[]'::jsonb
        )
        from public.billing_profiles bp2
        left join public.cashbook_accounts wa2
          on wa2.parent_tenant_id = v_parent_id
         and wa2.entity_type = 'customer'
         and wa2.entity_id = bp2.id
         and wa2.currency_code = 'BDT'
        where bp2.customer_group_id = cg.id
          and (bp2.tenant_id = v_parent_id or bp2.tenant_id = p_tenant_id)
      ) as billing_profiles
    from public.customer_groups cg
    inner join public.billing_profiles bp
      on bp.customer_group_id = cg.id
     and (bp.tenant_id = v_parent_id or bp.tenant_id = p_tenant_id)
    left join public.cashbook_accounts wa
      on wa.parent_tenant_id = v_parent_id
     and wa.entity_type = 'customer'
     and wa.entity_id = bp.id
     and wa.currency_code = 'BDT'
    where (cg.parent_tenant_id = v_parent_id or cg.tenant_id = p_tenant_id)
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        v_search is null
        or cg.name ilike '%' || v_search || '%'
        or bp.name ilike '%' || v_search || '%'
        or coalesce(bp.phone, '') ilike '%' || v_search || '%'
        or coalesce(bp.email, '') ilike '%' || v_search || '%'
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
$function$;

CREATE OR REPLACE FUNCTION public.list_customer_order_backlog_items(p_tenant_id bigint, p_billing_profile_id bigint)
 RETURNS TABLE(id bigint, tenant_id bigint, billing_profile_id bigint, product_id bigint, order_id bigint, order_item_id bigint, requested_quantity integer, fulfilled_quantity integer, open_quantity integer, backlog_status text, name text, image_url text, barcode text, product_code text, created_at timestamp with time zone)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  RETURN QUERY
  SELECT 
    b.id,
    b.tenant_id,
    b.billing_profile_id,
    b.product_id,
    b.order_id,
    b.order_item_id,
    b.requested_quantity,
    b.fulfilled_quantity,
    (b.requested_quantity - b.fulfilled_quantity) AS open_quantity,
    b.backlog_status,
    p.name,
    p.image_url,
    p.barcode,
    p.product_code,
    b.created_at
  FROM customer_order_backlog_items b
  JOIN products p ON p.id = b.product_id
  WHERE b.tenant_id = p_tenant_id
    AND b.billing_profile_id = p_billing_profile_id
    AND b.backlog_status IN ('open', 'partially_fulfilled')
  ORDER BY b.created_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.list_demand_bucket_items(p_tenant_id bigint, p_billing_profile_id bigint, p_status demand_bucket_status DEFAULT 'open'::demand_bucket_status, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0)
 RETURNS TABLE(id bigint, tenant_id bigint, billing_profile_id bigint, product_id bigint, source_type demand_bucket_source_type, source_id bigint, name text, image_url text, barcode text, product_code text, note text, quantity integer, status demand_bucket_status, popped_at timestamp with time zone, popped_into_type text, popped_into_id bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_limit integer := greatest(coalesce(p_limit, 100), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if not public.can_access_demand_bucket_profile(p_tenant_id, p_billing_profile_id, false) then
    raise exception 'access denied';
  end if;

  return query
  select
    b.id,
    b.tenant_id,
    b.billing_profile_id,
    b.product_id,
    b.source_type,
    b.source_id,
    b.name,
    b.image_url,
    b.barcode,
    b.product_code,
    b.note,
    b.quantity,
    b.status,
    b.popped_at,
    b.popped_into_type,
    b.popped_into_id,
    b.created_at,
    b.updated_at
  from public.customer_demand_bucket_items b
  where b.billing_profile_id = p_billing_profile_id
    and (p_status is null or b.status = p_status)
  order by b.created_at desc, b.id desc
  limit v_limit
  offset v_offset;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_global_invoice_items(p_invoice_id bigint)
 RETURNS TABLE(id bigint, invoice_id bigint, global_stock_id bigint, name_snapshot text, quantity numeric, sell_price_amount numeric, recipient_price_amount numeric, line_face_total_amount numeric, line_discount_amount numeric, line_total_amount numeric, return_quantity numeric, image_url text, shipment_id bigint, shipment_item_id bigint, purchase_price numeric, product_weight numeric, package_weight numeric, ordered_quantity integer, shipment_type text, product_conversion_rate numeric, cargo_conversion_rate numeric, cargo_rate numeric, received_weight numeric, transaction_rate numeric, available_atp numeric, unit_cost_price numeric)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.list_investor_wallet_activity(p_tenant_id bigint, p_investor_id bigint DEFAULT NULL::bigint, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(id text, investor_id bigint, amount numeric, activity_date date, method investor_payment_method, transaction_type text, note text, created_at timestamp with time zone, total_count bigint)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_total_count bigint;
begin
  if not (
    public.user_can_manage_parent_tenant(p_tenant_id)
    or (p_investor_id is not null and public.auth_investor_id() = p_investor_id)
  ) then
    raise exception 'not allowed';
  end if;

  select count(*) into v_total_count
  from public.cashbook_entries uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital';

  return query
  select
    uwl.id::text,
    uwl.entity_id as investor_id,
    abs(uwl.amount)::numeric,
    uwl.created_at::date as activity_date,
    coalesce(nullif(uwl.metadata->>'method', ''), 'other')::public.investor_payment_method,
    coalesce(uwl.metadata->>'transaction_type', 'manual_adjustment'),
    coalesce(uwl.metadata->>'notes', uwl.metadata->>'note'),
    uwl.created_at,
    v_total_count
  from public.cashbook_entries uwl
  inner join public.investors i on i.id = uwl.entity_id
  where i.tenant_id = p_tenant_id
    and uwl.entity_type = 'investor'
    and (p_investor_id is null or uwl.entity_id = p_investor_id)
    and coalesce(uwl.metadata->>'section', '') = 'investor_capital'
  order by uwl.created_at desc
  limit p_limit
  offset p_offset;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_invoice_payment_history(p_tenant_id bigint, p_invoice_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      ) as instruments
    from public.pay_allocations ip
    join public.pays gp on gp.id = ip.payment_id
    where ip.global_invoice_id = p_invoice_id

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
      end as instruments
    from public.invoice_write_offs iwo
    left join public.pays gp on gp.id = iwo.payment_id
    where iwo.invoice_id = p_invoice_id
  ) r;

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_my_dropship_wallet_ledger(p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(id text, created_at timestamp with time zone, transaction_type text, amount numeric, balance_after numeric, source_id text, order_id bigint, note text)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_email text := public.current_user_email();
  v_tenant_id bigint;
  v_group_id bigint;
  v_bp_id bigint;
begin
  if v_email is null or length(trim(v_email)) = 0 then
    raise exception 'Not authenticated';
  end if;

  select cg.tenant_id, cgm.customer_group_id
  into v_tenant_id, v_group_id
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  where lower(trim(cgm.email)) = lower(trim(v_email))
    and cgm.is_active = true
    and cg.is_active = true
  order by cgm.id
  limit 1;

  if v_tenant_id is null then
    raise exception 'No active customer group membership';
  end if;

  v_bp_id := public.resolve_billing_profile_for_customer_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  return query
  select
    u.id::text,
    u.created_at,
    coalesce(u.metadata->>'transaction_type', u.metadata->>'purpose', u.type)::text as transaction_type,
    case when u.type = 'debit' then -u.amount else u.amount end,
    u.balance_after,
    u.source_id,
    case
      when u.source_type = 'shop_order' and u.source_id ~ '^[0-9]+$' then u.source_id::bigint
      else null
    end as order_id,
    coalesce(u.metadata->>'notes', u.metadata->>'note', '')::text as note
  from public.cashbook_entries u
  where u.tenant_id = v_tenant_id
    and u.entity_id = v_bp_id
    and u.entity_type in ('middleman', 'customer')
  order by u.created_at desc, u.id desc
  limit greatest(coalesce(p_limit, 50), 1)
  offset greatest(coalesce(p_offset, 0), 0);
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_open_invoices_for_payment(p_tenant_id bigint, p_customer_group_id bigint DEFAULT NULL::bigint, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      coalesce(cg.name, bp.name, si.recipient_name, 'Direct Customer') as customer_group_name,
      coalesce(bp.name, 'Main Outlet') as branch_name,
      si.invoice_date,
      si.due_date,
      si.total_amount,
      si.paid_amount,
      si.written_off_amount,
      si.due_amount,
      si.payment_status
    from public.bills si
    left join public.billing_profiles bp on bp.id = si.profile_id
    left join public.customer_groups cg on cg.id = bp.customer_group_id
    where (si.parent_tenant_id = v_parent_id or si.issued_by_tenant_id = p_tenant_id)
      and si.invoice_status = 'issued'
      and si.due_amount > 0
      and (p_customer_group_id is null or cg.id = p_customer_group_id)
      and (
        p_search is null
        or trim(p_search) = ''
        or si.invoice_no ilike '%' || trim(p_search) || '%'
        or cg.name ilike '%' || trim(p_search) || '%'
        or bp.name ilike '%' || trim(p_search) || '%'
        or si.recipient_name ilike '%' || trim(p_search) || '%'
      )
    order by si.invoice_date asc, si.id asc
    limit coalesce(p_limit, 50)
    offset coalesce(p_offset, 0)
  ) r;

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_pbc_backlog_items(p_tenant_id bigint, p_billing_profile_id bigint)
 RETURNS TABLE(id bigint, tenant_id bigint, billing_profile_id bigint, product_id bigint, open_quantity integer, name text, image_url text, barcode text, product_code text, price_gbp numeric, product_weight numeric, package_weight numeric, note text, last_costing_file_id bigint, last_costing_item_id bigint, created_at timestamp with time zone, updated_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
  IF NOT (public.can_admin_manage_costing_file(p_tenant_id) OR public.can_staff_access_costing_file(p_tenant_id)) THEN
    RAISE EXCEPTION 'access denied for tenant %', p_tenant_id;
  END IF;

  RETURN QUERY
  SELECT
    bi.id,
    bi.tenant_id,
    bi.billing_profile_id,
    bi.product_id,
    bi.open_quantity,
    bi.name,
    bi.image_url,
    bi.barcode,
    bi.product_code,
    bi.price_gbp,
    bi.product_weight,
    bi.package_weight,
    bi.note,
    bi.last_costing_file_id,
    bi.last_costing_item_id,
    bi.created_at,
    bi.updated_at
  FROM public.product_based_costing_backlog_items bi
  WHERE bi.tenant_id = p_tenant_id
    AND bi.billing_profile_id = p_billing_profile_id
  ORDER BY bi.updated_at DESC;
END;
$function$;

CREATE OR REPLACE FUNCTION public.list_procurement_demand_group_items(p_tenant_id bigint, p_document_type text, p_document_id bigint, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_cursor_source_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(1, least(coalesce(p_limit, 50), 100));
  v_items jsonb := '[]'::jsonb;
  v_n integer := 0;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
  v_last_source_id bigint;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;

  if v_doc_type not in ('shop_order', 'pbc_costing_file') then
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      nullif(trim(coalesce(p.vendor_code, '')), '') as vendor_code,
      nullif(trim(coalesce(p.market_code, '')), '') as market_code,
      nullif(trim(coalesce(p.brand, '')), '') as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where v_doc_type = 'shop_order'
      and o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog'
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      coalesce(
        nullif(trim(coalesce(pci.vendor_code, '')), ''),
        nullif(trim(coalesce(p.vendor_code, '')), '')
      ) as vendor_code,
      coalesce(
        nullif(trim(coalesce(pci.market_code, '')), ''),
        nullif(trim(coalesce(p.market_code, '')), '')
      ) as market_code,
      coalesce(
        nullif(trim(coalesce(pci.brand, '')), ''),
        nullif(trim(coalesce(p.brand, '')), '')
      ) as brand,
      nullif(trim(coalesce(p.category, '')), '') as category,
      p.available_units,
      nullif(trim(coalesce(p.languages, '')), '') as languages,
      nullif(trim(coalesce(p.country_of_origin, '')), '') as country_of_origin,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.products p on p.id = pci.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where v_doc_type = 'pbc_costing_file'
      and f.id = p_document_id
      and f.billing_profile_id is not null
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where (
      dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
    )
      and (
        v_search is null
        or dl.name ilike '%' || v_search || '%'
        or coalesce(dl.barcode, '') ilike '%' || v_search || '%'
        or coalesce(dl.product_code, '') ilike '%' || v_search || '%'
      )
      and (
        p_cursor_source_id is null
        or dl.source_id > p_cursor_source_id
      )
  ),
  paged as (
    select el.*
    from eligible_lines el
    order by el.source_id
    limit v_limit + 1
  ),
  page_count as (
    select count(*)::integer as n from paged
  ),
  page_rows as (
    select p.*
    from paged p
    order by p.source_id
    limit v_limit
  ),
  item_json as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'source_type', row.source_type,
          'source_id', row.source_id,
          'product_id', row.product_id,
          'name', row.name,
          'image_url', row.image_url,
          'barcode', nullif(row.barcode, ''),
          'product_code', nullif(row.product_code, ''),
          'vendor_code', row.vendor_code,
          'market_code', row.market_code,
          'brand', row.brand,
          'category', row.category,
          'available_units', row.available_units,
          'languages', row.languages,
          'country_of_origin', row.country_of_origin,
          'quantity', row.quantity,
          'need_quantity', row.quantity,
          'preorder_demand_id', row.preorder_demand_id,
          'vendor_id', row.vendor_id,
          'placed_quantity', row.placed_quantity,
          'delivered_quantity', row.delivered_quantity,
          'remaining_quantity', row.quantity - row.placed_quantity,
          'remaining_to_deliver', greatest(row.quantity - row.delivered_quantity, 0),
          'stock_picks', row.stock_picks
        )
        order by row.source_id
      ),
      '[]'::jsonb
    ) as items
    from page_rows row
  ),
  cursor_row as (
    select p.source_id
    from paged p
    order by p.source_id
    offset v_limit
    limit 1
  )
  select
    ij.items,
    pc.n,
    cr.source_id
  into v_items, v_n, v_last_source_id
  from item_json ij
  cross join page_count pc
  left join cursor_row cr on true;

  if v_n > v_limit then
    v_has_more := true;
    v_next_cursor := jsonb_build_object('source_id', v_last_source_id);
  end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'document_type', v_doc_type,
      'document_id', p_document_id,
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    ),
    'items', v_items
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_procurement_demand_groups(p_tenant_id bigint, p_procurement_status text DEFAULT 'procuring'::text, p_search text DEFAULT NULL::text, p_child_tenant_id bigint DEFAULT NULL::bigint, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
      and (p_child_tenant_id is null or t.id = p_child_tenant_id)
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where f.billing_profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      jsonb_agg(
        jsonb_build_object(
          'source_type', el.source_type,
          'source_id', el.source_id,
          'product_id', el.product_id,
          'name', el.name,
          'image_url', el.image_url,
          'barcode', nullif(el.barcode, ''),
          'product_code', nullif(el.product_code, ''),
          'quantity', el.quantity,
          'need_quantity', el.quantity,
          'preorder_demand_id', el.preorder_demand_id,
          'vendor_id', el.vendor_id,
          'placed_quantity', el.placed_quantity,
          'delivered_quantity', el.delivered_quantity,
          'remaining_quantity', el.quantity - el.placed_quantity,
          'remaining_to_deliver', greatest(el.quantity - el.delivered_quantity, 0),
          'stock_picks', el.stock_picks
        )
        order by el.source_id
      ) as items,
      count(*)::integer as item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  paged as (
    select g.*, count(*) over ()::integer as total_groups
    from grouped g
    order by g.document_type, g.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'items', p.items
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_procurement_fulfill_groups(p_tenant_id bigint, p_procurement_status text DEFAULT 'procuring'::text, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_is_parent boolean;
  v_allowed boolean := false;
  v_status text := lower(trim(coalesce(p_procurement_status, 'procuring')));
  v_search text := nullif(trim(coalesce(p_search, '')), '');
  v_limit integer := greatest(coalesce(p_limit, 50), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
  v_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_item_count integer := 0;
  v_has_shop boolean := false;
  v_has_pbc boolean := false;
  v_sources text[] := '{}'::text[];
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then raise exception 'tenant not found: %', p_tenant_id; end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then raise exception 'access denied'; end if;
  if v_status not in ('procuring', 'packed', 'delivered') then
    raise exception 'invalid procurement status: %', v_status;
  end if;

  with tenant_scope as (
    select t.id as tenant_id from public.tenants t
    where (
      (v_is_parent and (t.parent_id = p_tenant_id or t.id = p_tenant_id))
      or (not v_is_parent and t.id = p_tenant_id)
    )
  ),
  shop_lines as (
    select
      'shop_order'::text as document_type,
      o.id as document_id,
      public.normalize_shop_order_procurement_status(o.status) as document_status,
      o.customer_group_id,
      cg.name as customer_group_name,
      null::jsonb as vendor,
      'shop_order_item'::text as source_type,
      oi.id as source_id,
      oi.product_id,
      oi.name,
      oi.image_url,
      coalesce(p.barcode, '') as barcode,
      coalesce(p.product_code, '') as product_code,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      o.global_invoice_id as invoice_id,
      nullif(trim(coalesce(o.name, o.order_no, '')), '') as document_name
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join tenant_scope ts on ts.tenant_id = o.tenant_id
    left join public.customer_groups cg on cg.id = o.customer_group_id
    left join public.products p on p.id = oi.product_id
    left join public.preorder_demand pd
      on pd.source_type = 'shop_order_item'
      and pd.source_id = oi.id
      and pd.tenant_id = o.tenant_id
    where o.shop_type_snapshot = 'vendor_catalog'
      and public.normalize_shop_order_procurement_status(o.status) = v_status
      and (
        v_search is null
        or oi.name ilike '%' || v_search || '%'
        or o.name ilike '%' || v_search || '%'
        or o.order_no ilike '%' || v_search || '%'
        or coalesce(p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  pbc_lines as (
    select
      'pbc_costing_file'::text as document_type,
      f.id as document_id,
      public.normalize_pbc_procurement_status(f.status) as document_status,
      f.customer_group_id,
      cg.name as customer_group_name,
      case
        when v.id is not null then jsonb_build_object(
          'id', v.id,
          'code', coalesce(nullif(trim(f.vendor_code), ''), v.code),
          'name', v.name
        )
        when nullif(trim(f.vendor_code), '') is not null then jsonb_build_object(
          'id', f.vendor_id,
          'code', trim(f.vendor_code),
          'name', null
        )
        else null::jsonb
      end as vendor,
      'pbc_costing_item'::text as source_type,
      pci.id as source_id,
      pci.product_id,
      coalesce(pci.name, p.name, 'Item') as name,
      coalesce(pci.image_url, p.image_url) as image_url,
      coalesce(pci.barcode, p.barcode, '') as barcode,
      coalesce(pci.product_code, p.product_code, '') as product_code,
      greatest(
        case when pci.assigned_shipment_id is not null then 0
          else coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        end,
        0
      )::integer as quantity,
      pd.id as preorder_demand_id,
      pd.vendor_id,
      coalesce(pd.placed_quantity, 0) as placed_quantity,
      coalesce(pd.delivered_quantity, 0) as delivered_quantity,
      coalesce(pd.stock_picks, '[]'::jsonb) as stock_picks,
      f.invoice_id,
      nullif(trim(coalesce(f.name, '')), '') as document_name
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
    inner join tenant_scope ts on ts.tenant_id = f.tenant_id
    left join public.customer_groups cg on cg.id = f.customer_group_id
    left join public.products p on p.id = pci.product_id
    left join public.vendors v on v.id = f.vendor_id
    left join public.preorder_demand pd
      on pd.source_type = 'pbc_costing_item'
      and pd.source_id = pci.id
      and pd.tenant_id = f.tenant_id
    where f.billing_profile_id is not null
      and public.normalize_pbc_procurement_status(f.status) = v_status
      and (
        v_search is null
        or coalesce(pci.name, p.name, '') ilike '%' || v_search || '%'
        or coalesce(f.name, '') ilike '%' || v_search || '%'
        or coalesce(pci.barcode, p.barcode, '') ilike '%' || v_search || '%'
        or coalesce(pci.product_code, p.product_code, '') ilike '%' || v_search || '%'
      )
  ),
  demand_lines as (
    select * from shop_lines
    union all
    select * from pbc_lines
  ),
  eligible_lines as (
    select dl.*
    from demand_lines dl
    where dl.quantity > 0
      or dl.placed_quantity > 0
      or dl.delivered_quantity > 0
  ),
  grouped as (
    select
      el.document_type,
      el.document_id,
      max(el.document_status) as document_status,
      max(el.customer_group_id) as customer_group_id,
      max(el.customer_group_name) as customer_group_name,
      (array_agg(el.vendor) filter (where el.vendor is not null))[1] as vendor,
      max(el.invoice_id) as invoice_id,
      max(el.document_name) as document_name,
      count(*)::integer as item_count,
      count(*) filter (where el.quantity > el.delivered_quantity)::integer as unallocated_item_count
    from eligible_lines el
    group by el.document_type, el.document_id
  ),
  enriched as (
    select
      g.*,
      inv.invoice_status,
      case
        when g.invoice_id is null then false
        else public.preorder_demand_invoice_items_stale(g.document_type, g.document_id, g.invoice_id)
      end as invoice_stale
    from grouped g
    left join public.bills inv on inv.id = g.invoice_id
  ),
  paged as (
    select e.*, count(*) over ()::integer as total_groups
    from enriched e
    order by e.document_type, e.document_id
    limit v_limit offset v_offset
  )
  select
    coalesce(
      jsonb_agg(
        jsonb_build_object(
          'document_type', p.document_type,
          'document_id', p.document_id,
          'document_name', p.document_name,
          'document_status', p.document_status,
          'customer_group_id', p.customer_group_id,
          'customer_group_name', p.customer_group_name,
          'vendor', p.vendor,
          'invoice_id', p.invoice_id,
          'invoice_status', p.invoice_status,
          'invoice_stale', coalesce(p.invoice_stale, false),
          'item_count', p.item_count,
          'unallocated_item_count', p.unallocated_item_count
        )
        order by p.document_type, p.document_id
      ),
      '[]'::jsonb
    ),
    coalesce(max(p.total_groups), 0),
    coalesce(sum(p.item_count), 0),
    coalesce(bool_or(p.document_type = 'shop_order'), false),
    coalesce(bool_or(p.document_type = 'pbc_costing_file'), false)
  into v_groups, v_group_count, v_item_count, v_has_shop, v_has_pbc
  from paged p;

  if v_has_shop then v_sources := array_append(v_sources, 'shop_order'); end if;
  if v_has_pbc then v_sources := array_append(v_sources, 'pbc_costing'); end if;

  return jsonb_build_object(
    'meta', jsonb_build_object(
      'tenant_id', p_tenant_id,
      'procurement_status', v_status,
      'sources_included', to_jsonb(v_sources),
      'group_count', coalesce(jsonb_array_length(v_groups), 0),
      'item_count', v_item_count,
      'total_group_count', v_group_count,
      'limit', v_limit,
      'offset', v_offset,
      'has_more', v_group_count > (v_offset + v_limit)
    ),
    'groups', v_groups
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.list_wallet_entities_for_staff(p_tenant_id bigint, p_entity_type text, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 100, p_offset integer DEFAULT 0, p_currency_code text DEFAULT 'BDT'::text)
 RETURNS TABLE(entity_id bigint, entity_type text, name text, code text, caption text, available_balance numeric, pending_balance numeric, locked_balance numeric, total_balance numeric, source_uuid uuid, operating_tenant_id bigint, has_wallet_activity boolean)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
      bp.id,
      'customer'::text,
      CASE WHEN cg.name IS NOT NULL THEN cg.name || ' · ' || bp.name ELSE bp.name END,
      NULL::text,
      nullif(trim(concat_ws(' • ', bp.phone, bp.email)), ''),
      coalesce(wa.available_balance, 0.0000),
      coalesce(wa.pending_balance, 0.0000),
      coalesce(wa.locked_balance, 0.0000),
      coalesce(wa.available_balance, 0) + coalesce(wa.pending_balance, 0) + coalesce(wa.locked_balance, 0),
      NULL::uuid,
      bp.tenant_id,
      wa.id IS NOT NULL
    FROM public.billing_profiles bp
    LEFT JOIN public.customer_groups cg ON cg.id = bp.customer_group_id
    LEFT JOIN public.cashbook_accounts wa
      ON wa.parent_tenant_id = v_books_id
     AND wa.entity_type = 'customer'
     AND wa.entity_id = bp.id
     AND wa.currency_code = coalesce(p_currency_code, 'BDT')
    WHERE (bp.tenant_id = v_books_id
       OR bp.tenant_id IN (SELECT t.id FROM public.tenants t WHERE t.parent_id = v_books_id))
      AND (
        v_search IS NULL
        OR bp.name ILIKE '%' || v_search || '%'
        OR coalesce(cg.name, '') ILIKE '%' || v_search || '%'
        OR coalesce(bp.phone, '') ILIKE '%' || v_search || '%'
        OR coalesce(bp.email, '') ILIKE '%' || v_search || '%'
      )
    ORDER BY 3 ASC, bp.id ASC
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
$function$;

CREATE OR REPLACE FUNCTION public.list_wallet_ledger_for_staff(p_tenant_id bigint, p_entity_type text, p_entity_id bigint, p_search text DEFAULT NULL::text, p_operating_tenant_id bigint DEFAULT NULL::bigint, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(id uuid, parent_tenant_id bigint, operating_tenant_id bigint, entity_type text, entity_id bigint, type text, amount numeric, currency_code text, exchange_rate numeric, base_amount numeric, balance_after numeric, source_type text, source_id text, metadata jsonb, created_at timestamp with time zone, is_reversal boolean, reversed_entry_id uuid)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    CASE WHEN l.metadata ? 'reversal_of' THEN (l.metadata->>'reversal_of')::uuid ELSE NULL END
  FROM public.cashbook_entries l
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
    )
  ORDER BY l.created_at DESC, l.id DESC
  LIMIT greatest(least(coalesce(p_limit, 50), 200), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_dropship_order_delivered(p_tenant_id bigint, p_order_id bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_save jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders
  where id = p_order_id for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  if v_order.status <> 'shipped'::public.shop_order_status then
    raise exception 'mark as delivered requires shipped status (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'merchant bill must be issued before deliver';
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id;
  if v_invoice.id is null then
    raise exception 'linked merchant bill not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'merchant bill must be issued before deliver (current: %)', v_invoice.invoice_status;
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
  if coalesce(v_save->>'success', 'false') <> 'true' then
    return v_save;
  end if;

  update public.shop_orders
  set
    status = 'delivered'::public.shop_order_status,
    delivered_at = coalesce(delivered_at, now()),
    updated_at = now()
  where id = p_order_id;

  perform public.ensure_dropship_courier_cod_receivable(p_order_id);

  return jsonb_build_object(
    'success', true,
    'message', 'Order marked as delivered',
    'order_id', p_order_id,
    'invoice_id', v_order.global_invoice_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.mark_shop_order_item_shortfall(p_order_item_id bigint, p_shortfall_qty integer, p_reason text DEFAULT NULL::text, p_add_to_demand_bucket boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_picked integer := 0;
  v_billing_profile_id bigint;
begin
  if p_shortfall_qty is null or p_shortfall_qty <= 0 then
    raise exception 'shortfall quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  select * into v_order from public.shop_orders where id = v_item.order_id for update;

  if not public.is_tenant_staff(v_order.tenant_id) then raise exception 'access denied'; end if;
  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'shortfall only allowed while processing';
  end if;
  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is fully unavailable';
  end if;

  select coalesce(sum(sp.quantity), 0) into v_picked
  from public.shop_order_item_stock_picks sp where sp.order_item_id = p_order_item_id;

  if v_picked + p_shortfall_qty > v_item.quantity then
    raise exception 'shortfall exceeds remaining qty';
  end if;

  update public.shop_order_items
  set shortfall_quantity = p_shortfall_qty, updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_billing_profile_id := coalesce(
      v_order.billing_profile_id,
      public.resolve_billing_profile_for_customer_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_billing_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id, v_billing_profile_id, v_item.product_id,
        'shop_order'::public.demand_bucket_source_type, v_order.id,
        jsonb_build_object('order_item_id', v_item.id, 'reason', coalesce(p_reason, 'partial_shortfall')),
        p_shortfall_qty
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);
  return jsonb_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.mark_shop_order_item_unavailable(p_order_item_id bigint, p_reason text DEFAULT NULL::text, p_add_to_demand_bucket boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_pick_count integer := 0;
  v_billing_profile_id bigint;
begin
  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'unavailable is only allowed while order is processing';
  end if;

  select count(*) into v_pick_count
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  if v_pick_count > 0 then
    raise exception 'cannot mark unavailable while picks exist — remove picks first';
  end if;

  update public.shop_order_items
  set
    is_fulfillment_unavailable = true,
    unavailable_reason = nullif(trim(p_reason), ''),
    unavailable_at = now(),
    unavailable_by_email = public.current_user_email(),
    confirmed_quantity = 0,
    global_stock_id = null,
    updated_at = now()
  where id = p_order_item_id;

  if coalesce(p_add_to_demand_bucket, true) then
    v_billing_profile_id := coalesce(
      v_order.billing_profile_id,
      public.resolve_billing_profile_for_customer_group(v_order.tenant_id, v_order.customer_group_id)
    );
    if v_billing_profile_id is not null then
      perform public.add_demand_bucket_item(
        v_order.tenant_id,
        v_billing_profile_id,
        v_item.product_id,
        'shop_order'::public.demand_bucket_source_type,
        v_order.id,
        jsonb_build_object(
          'order_item_id', v_item.id,
          'name', v_item.name,
          'reason', coalesce(nullif(trim(p_reason), ''), 'fulfillment_unavailable')
        ),
        v_item.quantity
      );
    end if;
  end if;

  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  return jsonb_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.pop_demand_bucket_item(p_bucket_item_id bigint, p_popped_into_type text, p_popped_into_id bigint)
 RETURNS customer_demand_bucket_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.customer_demand_bucket_items;
begin
  if p_bucket_item_id is null then
    raise exception 'bucket_item_id is required';
  end if;
  if nullif(trim(coalesce(p_popped_into_type, '')), '') is null
     or p_popped_into_id is null then
    raise exception 'popped_into_type and popped_into_id are required';
  end if;

  select * into v_row
  from public.customer_demand_bucket_items
  where id = p_bucket_item_id;

  if not found then
    raise exception 'bucket item not found: %', p_bucket_item_id;
  end if;

  if v_row.status <> 'open' then
    raise exception 'bucket item % is not open', p_bucket_item_id;
  end if;

  if not public.can_access_demand_bucket_profile(v_row.tenant_id, v_row.billing_profile_id, false) then
    raise exception 'access denied';
  end if;

  update public.customer_demand_bucket_items
  set
    status = 'popped',
    popped_at = now(),
    popped_into_type = trim(p_popped_into_type),
    popped_into_id = p_popped_into_id,
    updated_at = now()
  where id = p_bucket_item_id
  returning * into v_row;

  return v_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.post_sales_invoice(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.preorder_demand_invoice_items_stale(p_document_type text, p_document_id bigint, p_invoice_id bigint)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
  with expected as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'global_stock_id', (elem->>'global_stock_id')::bigint,
          'quantity', (elem->>'quantity')::numeric,
          'sell_price_amount', (elem->>'sell_price_amount')::numeric(12,2)
        )
        order by (elem->>'global_stock_id')::bigint, (elem->>'quantity')::numeric, (elem->>'sell_price_amount')::numeric
      ),
      '[]'::jsonb
    ) as sig
    from jsonb_array_elements(public.build_preorder_demand_invoice_items(p_document_type, p_document_id)) as elem
  ),
  actual as (
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'global_stock_id', sii.global_stock_id,
          'quantity', sii.quantity,
          'sell_price_amount', sii.sell_price_amount
        )
        order by sii.global_stock_id, sii.quantity, sii.sell_price_amount
      ),
      '[]'::jsonb
    ) as sig
    from public.bill_lines sii
    where sii.invoice_id = p_invoice_id
  )
  select
    p_invoice_id is not null
    and (select sig from expected) is distinct from (select sig from actual);
$function$;

CREATE OR REPLACE FUNCTION public.preview_tenant_data_purge(p_parent_tenant_id bigint, p_scope text DEFAULT 'all_hierarchy'::text, p_target_child_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_target_tenant_ids BIGINT[];
    v_shipment_count BIGINT := 0;
    v_stock_count BIGINT := 0;
    v_invoice_count BIGINT := 0;
    v_order_count BIGINT := 0;
    v_cart_count BIGINT := 0;
    v_ledger_count BIGINT := 0;
    v_wallets_count BIGINT := 0;
BEGIN
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_parent_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Only parent tenant administrators can preview data purges.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_parent_tenant_id OR parent_id = p_parent_tenant_id;

        SELECT count(*) INTO v_shipment_count FROM public.global_shipments WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_stock_count FROM public.global_stocks WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_invoice_count FROM public.bills WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_ledger_count FROM public.cashbook_entries WHERE parent_tenant_id = p_parent_tenant_id;
        SELECT count(*) INTO v_wallets_count FROM public.cashbook_accounts WHERE parent_tenant_id = p_parent_tenant_id;
    ELSE
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = p_target_child_id AND parent_id = p_parent_tenant_id) THEN
            RAISE EXCEPTION 'Invalid child tenant ID for this parent organization.';
        END IF;

        v_target_tenant_ids := ARRAY[p_target_child_id];

        SELECT count(*) INTO v_invoice_count FROM public.bills WHERE issued_by_tenant_id = p_target_child_id;
        SELECT count(*) INTO v_ledger_count FROM public.cashbook_entries WHERE operating_tenant_id = p_target_child_id;
        SELECT count(*) INTO v_wallets_count FROM public.cashbook_accounts WHERE tenant_id = p_target_child_id;
    END IF;

    SELECT count(*) INTO v_order_count FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    SELECT count(*) INTO v_cart_count FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);

    RETURN jsonb_build_object(
        'shipments', v_shipment_count,
        'stocks', v_stock_count,
        'invoices', v_invoice_count,
        'orders', v_order_count,
        'carts', v_cart_count,
        'ledgers', v_ledger_count,
        'wallets_to_reset', v_wallets_count
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.process_courier_bulk_remittance_batch(p_batch_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_batch record;
  v_item record;
  v_order record;
  v_invoice record;
  v_payment_id bigint;
  v_processed_count integer := 0;
  v_error_count integer := 0;
  v_net_remitted numeric(12,2);
  v_total_allocated numeric(12,2) := 0.00;
begin
  -- Lock batch record
  select * into v_batch
  from public.courier_remittance_batches
  where id = p_batch_id for update;

  if v_batch.id is null then
    raise exception 'Remittance batch #% not found', p_batch_id;
  end if;

  if v_batch.status <> 'draft' then
    raise exception 'Batch #% is already %', v_batch.batch_no, v_batch.status;
  end if;

  -- Permission check
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_batch.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_batch.tenant_id;
  end if;

  -- Process line items sequentially
  for v_item in
    select * from public.courier_remittance_items
    where batch_id = p_batch_id
    for update
  loop
    v_net_remitted := v_item.net_remitted_amount;

    -- Validate order
    if v_item.shop_order_id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Missing linked order'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    select * into v_order from public.shop_orders
    where id = v_item.shop_order_id for update;

    if v_order.id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Shop order record not found'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    if v_order.status <> 'delivered' then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Order is not in delivered status (current: ' || v_order.status || ')'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    if v_order.global_invoice_id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Missing accounting global invoice'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    -- Lock & validate global invoice
    select * into v_invoice from public.bills
    where id = v_order.global_invoice_id for update;

    if v_invoice.id is null then
      update public.courier_remittance_items
      set status = 'error', error_message = 'Global invoice not found'
      where id = v_item.id;
      v_error_count := v_error_count + 1;
      continue;
    end if;

    -- Create global payment record
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
      v_batch.tenant_id,
      v_invoice.profile_id,
      v_invoice.collection_source,
      v_net_remitted,
      0.00,
      coalesce(v_batch.payment_date, current_date),
      'bank_transfer',
      v_batch.batch_no,
      'Courier remittance batch #' || v_batch.batch_no || ' order #' || v_order.order_no
    )
    returning id into v_payment_id;

    -- Insert invoice payment allocation
    insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
    values (v_batch.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

    -- Update invoice paid amount
    update public.bills
    set
      paid_amount = coalesce(paid_amount, 0.00) + v_net_remitted,
      updated_at = now()
    where id = v_order.global_invoice_id;

    -- Recompute payment status
    perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

    -- Update order status to payment_received & stamp references
    update public.shop_orders
    set
      status = 'payment_received'::public.shop_order_status,
      courier_remittance_ref = v_batch.batch_no,
      courier_bank_trx_id = coalesce(v_batch.bank_trx_id, courier_bank_trx_id),
      updated_at = now()
    where id = v_order.id;

    -- Mark item as processed
    update public.courier_remittance_items
    set
      status = 'processed',
      error_message = null,
      global_invoice_id = v_order.global_invoice_id
    where id = v_item.id;

    v_processed_count := v_processed_count + 1;
    v_total_allocated := v_total_allocated + v_net_remitted;
  end loop;

  -- Mark batch header as posted if no fatal block
  update public.courier_remittance_batches
  set
    status = 'posted',
    allocated_amount = v_total_allocated,
    variance_amount = net_deposited_amount - v_total_allocated,
    posted_at = now(),
    posted_by = auth.uid(),
    updated_at = now()
  where id = p_batch_id;

  return jsonb_build_object(
    'success', true,
    'batch_id', p_batch_id,
    'processed_count', v_processed_count,
    'error_count', v_error_count,
    'allocated_amount', v_total_allocated,
    'status', 'posted'
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.process_dropship_courier_remittance_uwl(p_order_id bigint, p_net_amount numeric, p_courier_charge numeric DEFAULT 0.00, p_remittance_ref text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order record;
  v_parent_tenant_id bigint;
  v_courier_id bigint;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net numeric(12,2) := 0.00;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  perform public.ensure_dropship_courier_cod_receivable(p_order_id);

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  v_currency := 'BDT';

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  v_charge := greatest(coalesce(p_courier_charge, 0.00), 0.00);
  v_net := greatest(coalesce(p_net_amount, 0.00), 0.00);

  if v_order.courier_service_id is null then
    raise exception 'Courier service is required before recording remittance';
  end if;

  select cs.wallet_entity_id
  into v_courier_id
  from public.courier_services cs
  where cs.id = v_order.courier_service_id;

  if v_courier_id is null or v_courier_id <= 0 then
    raise exception 'Courier wallet is not configured for order #%', v_order.order_no;
  end if;

  if v_net > 0 and not exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_remittance',
        'transaction_type', 'courier_remittance',
        'label', 'COD Remittance to Tenant',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  if v_charge > 0 and not exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_fee_retained'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_fee_retained',
        'transaction_type', 'courier_fee_retained',
        'label', 'Courier COD / Delivery Fee Retained',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  if not exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_tenant_id,
      p_type => 'credit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payment_received',
        'purpose', 'tenant_remittance_received',
        'transaction_type', 'courier_remittance_received',
        'label', 'Courier Remittance Received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'remittance_ref', p_remittance_ref
      )
    );
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.process_wholesale_invoice_return(p_invoice_id bigint, p_items jsonb, p_return_charge_amount numeric DEFAULT 0, p_refund_method text DEFAULT NULL::text, p_payout_account_id bigint DEFAULT NULL::bigint, p_note text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
          'billing_profile_id', v_invoice.profile_id,
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
$function$;

CREATE OR REPLACE FUNCTION public.purge_shop_order_financial_artifacts(p_order_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_invoice_id bigint;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  if v_order.id is null then
    return;
  end if;

  v_invoice_id := v_order.global_invoice_id;

  if v_invoice_id is null and v_order.shop_type_snapshot = 'dropship' then
    select i.id into v_invoice_id
    from public.bills i
    where i.parent_tenant_id = v_order.tenant_id
      and i.invoice_no = 'INV-DS-' || v_order.order_no
      and not exists (
        select 1
        from public.shop_orders o2
        where o2.global_invoice_id = i.id
          and o2.id <> v_order.id
      )
    order by i.id desc
    limit 1;
  end if;

  if v_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_invoice_id;
  end if;

  delete from public.courier_remittance_items
  where shop_order_id = p_order_id;

  perform public.purge_shop_order_wallet_ledger(
    p_order_id => p_order_id,
    p_tenant_id => v_order.tenant_id,
    p_order_no => v_order.order_no,
    p_invoice_id => v_invoice_id,
    p_invoice_no => v_invoice.invoice_no
  );

  if v_invoice_id is not null then
    perform public.purge_shop_order_invoice(v_invoice_id);
  end if;
end;
$function$;

CREATE OR REPLACE FUNCTION public.purge_shop_order_invoice(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.bills;
  v_payment_ids bigint[];
begin
  if p_invoice_id is null then
    return;
  end if;

  select * into v_invoice
  from public.bills
  where id = p_invoice_id
  for update;

  if v_invoice.id is null then
    return;
  end if;

  select coalesce(array_agg(distinct ip.payment_id), '{}'::bigint[])
  into v_payment_ids
  from public.pay_allocations ip
  where ip.global_invoice_id = p_invoice_id;

  delete from public.pay_allocations
  where global_invoice_id = p_invoice_id;

  delete from public.pays gp
  where gp.id = any (v_payment_ids)
    and not exists (
      select 1
      from public.pay_allocations ip
      where ip.payment_id = gp.id
    );

  update public.bills
  set
    paid_amount = 0.00,
    payment_status = 'due',
    due_amount = coalesce(total_amount, 0.00),
    updated_at = now()
  where id = p_invoice_id;

  if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
    perform public.unpost_global_invoice(p_invoice_id);
  end if;

  delete from public.global_return_items where invoice_id = p_invoice_id;
  delete from public.global_invoice_items where invoice_id = p_invoice_id;
  delete from public.bills where id = p_invoice_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.purge_shop_order_wallet_ledger(p_order_id bigint, p_tenant_id bigint, p_order_no text, p_invoice_id bigint DEFAULT NULL::bigint, p_invoice_no text DEFAULT NULL::text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_row public.cashbook_entries;
begin
  for v_row in
    select *
    from public.cashbook_entries u
    where (
      u.source_type = 'shop_order'
      and (
        u.source_id = p_order_id::text
        or (p_order_no is not null and u.source_id = p_order_no)
        or (p_invoice_no is not null and u.source_id = p_invoice_no)
      )
    )
    or u.metadata->>'order_id' = p_order_id::text
    or (p_invoice_id is not null and u.metadata->>'invoice_id' = p_invoice_id::text)
  loop
    perform public._undo_wallet_ledger_row_before_delete(v_row);
  end loop;

  delete from public.cashbook_entries u
  where (
    u.source_type = 'shop_order'
    and (
      u.source_id = p_order_id::text
      or (p_order_no is not null and u.source_id = p_order_no)
      or (p_invoice_no is not null and u.source_id = p_invoice_no)
    )
  )
  or u.metadata->>'order_id' = p_order_id::text
  or (p_invoice_id is not null and u.metadata->>'invoice_id' = p_invoice_id::text);
end;
$function$;

CREATE OR REPLACE FUNCTION public.purge_tenant_operational_data(p_parent_tenant_id bigint, p_scope text DEFAULT 'all_hierarchy'::text, p_confirmation_slug text DEFAULT ''::text, p_target_child_id bigint DEFAULT NULL::bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_parent_slug TEXT;
    v_target_slug TEXT;
    v_target_id BIGINT;
    v_target_tenant_ids BIGINT[];
    v_counts JSONB;
    v_user_id UUID := auth.uid();
    v_user_email TEXT := COALESCE(public.current_user_email(), 'unknown');
BEGIN
    IF NOT (public.is_superadmin() OR public.user_can_manage_parent_tenant(p_parent_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Administrative privileges on the parent tenant required.';
    END IF;

    SELECT slug INTO v_parent_slug FROM public.tenants WHERE id = p_parent_tenant_id AND parent_id IS NULL;
    IF v_parent_slug IS NULL THEN
        RAISE EXCEPTION 'Parent tenant not found or is not a root workspace.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        v_target_id := p_parent_tenant_id;
        v_target_slug := v_parent_slug;

        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_parent_tenant_id OR parent_id = p_parent_tenant_id;
    ELSIF p_scope = 'child_only' THEN
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        SELECT slug INTO v_target_slug
        FROM public.tenants
        WHERE id = p_target_child_id AND parent_id = p_parent_tenant_id;

        IF v_target_slug IS NULL THEN
            RAISE EXCEPTION 'Selected child tenant not found under this parent organization.';
        END IF;

        v_target_id := p_target_child_id;
        v_target_tenant_ids := ARRAY[p_target_child_id];
    ELSE
        RAISE EXCEPTION 'Invalid scope: %. Must be all_hierarchy or child_only.', p_scope;
    END IF;

    IF UPPER(TRIM(p_confirmation_slug)) <> UPPER(TRIM(v_target_slug)) THEN
        RAISE EXCEPTION 'Confirmation slug mismatch. Expected %, received %.', UPPER(TRIM(v_target_slug)), UPPER(TRIM(p_confirmation_slug));
    END IF;

    v_counts := public.preview_tenant_data_purge(p_parent_tenant_id, p_scope, p_target_child_id);

    -- PBC master data must never be purged:
    -- product_based_costing_files, product_based_costing_items, product_based_costing_backlog_items

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.sales_return_items WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.bill_lines WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.bills WHERE parent_tenant_id = p_parent_tenant_id;
    ELSE
        DELETE FROM public.sales_return_items
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE parent_tenant_id = p_parent_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bill_lines
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE parent_tenant_id = p_parent_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bills
        WHERE parent_tenant_id = p_parent_tenant_id
          AND issued_by_tenant_id = p_target_child_id;
    END IF;

    DELETE FROM public.dropship_order_settlements WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.customer_demand_bucket_items WHERE tenant_id = ANY(v_target_tenant_ids);

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.cashbook_entries WHERE parent_tenant_id = p_parent_tenant_id;
        UPDATE public.cashbook_accounts
        SET available_balance = 0.0000,
            pending_balance = 0.0000,
            locked_balance = 0.0000,
            updated_at = now()
        WHERE parent_tenant_id = p_parent_tenant_id;
    ELSE
        DELETE FROM public.cashbook_entries WHERE operating_tenant_id = p_target_child_id;
        UPDATE public.cashbook_accounts
        SET available_balance = 0.0000,
            pending_balance = 0.0000,
            locked_balance = 0.0000,
            updated_at = now()
        WHERE tenant_id = p_target_child_id;
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.stock_movements WHERE tenant_id = ANY(v_target_tenant_ids);
        DELETE FROM public.global_stocks WHERE parent_tenant_id = p_parent_tenant_id;
        DELETE FROM public.global_shipments WHERE parent_tenant_id = p_parent_tenant_id;
    END IF;

    UPDATE public.sales_invoice_counters
    SET last_value = 0
    WHERE tenant_id = ANY(v_target_tenant_ids);

    INSERT INTO public.tenant_data_purge_logs (
        parent_tenant_id,
        target_tenant_id,
        scope,
        executed_by,
        executor_email,
        confirmation_phrase,
        deleted_counts
    ) VALUES (
        p_parent_tenant_id,
        v_target_id,
        p_scope,
        v_user_id,
        v_user_email,
        p_confirmation_slug,
        v_counts
    );

    RETURN jsonb_build_object(
        'success', true,
        'purged_counts', v_counts,
        'purged_at', now()
    );
END;
$function$;

CREATE OR REPLACE FUNCTION public.recompute_dropship_cod_collect_amount(p_order_id bigint)
 RETURNS numeric
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_items_resell_delivered numeric := 0;
  v_recipient_charge_total numeric := 0;
  v_cod_collect_amount numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  select coalesce(
    sum(
      coalesce(soi.customer_sell_price_amount, soi.final_price_amount, soi.unit_sell_price_amount, 0)
      * coalesce(soi.confirmed_quantity, 0)
    ),
    0
  )
  into v_items_resell_delivered
  from public.shop_order_items soi
  where soi.order_id = p_order_id;

  v_recipient_charge_total :=
    case when not coalesce(v_order.deduct_delivery_from_margin, false)
      then coalesce(v_order.delivery_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_cod_from_margin, false)
      then coalesce(v_order.cod_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_print_from_margin, false)
      then coalesce(v_order.print_charge_amount, 0) else 0 end +
    case when not coalesce(v_order.deduct_packing_from_margin, false)
      then coalesce(v_order.packing_charge_amount, 0) else 0 end;

  v_cod_collect_amount :=
    v_items_resell_delivered + v_recipient_charge_total - coalesce(v_order.discount_amount, 0);

  update public.shop_orders
  set cod_collect_amount = v_cod_collect_amount, updated_at = now()
  where id = p_order_id;

  return v_cod_collect_amount;
end;
$function$;

CREATE OR REPLACE FUNCTION public.recompute_global_invoice_payment_status(p_global_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_total numeric(12,2);
  v_paid numeric(12,2);
  v_written_off numeric(12,2);
  v_due numeric(12,2);
begin
  select total_amount into v_total from public.bills where id = p_global_invoice_id for update;
  if not found then return; end if;

  select coalesce(sum(amount), 0.00) into v_paid
  from public.pay_allocations where global_invoice_id = p_global_invoice_id;

  select coalesce(sum(amount), 0.00) into v_written_off
  from public.invoice_write_offs where invoice_id = p_global_invoice_id;

  v_due := greatest(coalesce(v_total, 0.00) - v_paid - v_written_off, 0.00);

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
  where id = p_global_invoice_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.recompute_global_invoice_totals(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.reconcile_single_order_remittance(p_order_id bigint, p_courier_charge numeric DEFAULT 0.00)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_invoice public.bills;
  v_payment_id bigint;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'Order #% cannot be remitted because current status is "%" (must be "delivered")', v_order.order_no, v_order.status;
  end if;

  -- Permission check
  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_order.tenant_id;
  end if;

  -- Ensure global invoice exists or create it
  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id for update;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Failed to resolve accounting invoice for order #%', v_order.order_no;
  end if;

  select * into v_invoice
  from public.bills
  where id = v_order.global_invoice_id for update;

  v_cod := coalesce(v_order.cod_collect_amount, v_invoice.total_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);

  -- Record global payment with valid 'bank' method
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
    v_order.tenant_id,
    v_invoice.profile_id,
    coalesce(v_invoice.collection_source, 'recipient'),
    v_net_remitted,
    0.00,
    current_date,
    'bank',
    coalesce(v_order.courier_awb_number, v_order.order_no),
    'Single-order inline remittance for order #' || v_order.order_no
  )
  returning id into v_payment_id;

  -- Allocate invoice payment
  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
  values (v_order.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

  -- Update global invoice paid amount & status
  update public.bills
  set
    paid_amount = coalesce(paid_amount, 0.00) + v_net_remitted,
    updated_at = now()
  where id = v_order.global_invoice_id;

  perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

  -- Update shop order status to payment_received
  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = coalesce(courier_remittance_ref, 'SINGLE-REMIT-' || v_order.order_no),
    updated_at = now()
  where id = v_order.id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'payment_received',
    'net_remitted', v_net_remitted
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_dropship_courier_remittance(p_order_id bigint, p_net_amount numeric, p_remittance_ref text, p_bank_trx_id text DEFAULT NULL::text, p_payment_date date DEFAULT NULL::date, p_method text DEFAULT 'cash'::text, p_note text DEFAULT NULL::text, p_courier_charge numeric DEFAULT 0.00)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order record;
  v_invoice public.bills;
  v_parent_tenant_id bigint;
  v_payment_id bigint;
  v_pay public.pays;
  v_ref text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_invoice_due numeric(12,2);
  v_invoice_pay numeric(12,2);
  v_remainder numeric(12,2);
  v_already_remitted boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'Courier remittance requires order status delivered or payment_received (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select exists (
    select 1 from public.cashbook_entries
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_already_remitted;

  if v_already_remitted then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'invoice_id', v_order.global_invoice_id,
      'order_id', p_order_id,
      'status', v_order.status
    );
  end if;

  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  end if;

  v_net := coalesce(p_net_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  if v_net <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  end if;

  if v_charge < 0.00 then
    raise exception 'Courier charge cannot be negative';
  end if;

  if v_cod > 0 and (v_net + v_charge) > (v_cod + 0.01) then
    raise exception 'Remittance net (%) + charge (%) exceeds COD collect (%)', v_net, v_charge, v_cod;
  end if;

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

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Merchant bill must be issued before remittance (current: %)', v_invoice.invoice_status;
  end if;

  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    raise exception 'Remittance applies to dropship merchant bills only';
  end if;

  if v_invoice.profile_id is null then
    raise exception 'Merchant profile is required on the bill';
  end if;

  v_invoice_due := greatest(coalesce(v_invoice.due_amount, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_remainder := greatest(v_net - v_invoice_pay, 0.00);

  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  update public.cashbook_entries
  set metadata = metadata || jsonb_build_object(
    'invoice_allocated', v_invoice_pay,
    'merchant_funds_held', v_remainder
  )
  where parent_tenant_id = v_parent_tenant_id
    and entity_type = 'tenant'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received';

  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id => v_order.tenant_id,
    p_billing_profile_id => v_invoice.profile_id,
    p_received_on => coalesce(p_payment_date, current_date),
    p_note => coalesce(
      nullif(trim(p_note), ''),
      'Courier remittance order #' || v_order.order_no
        || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
    ),
    p_reference => v_ref,
    p_source => 'courier_remittance',
    p_instruments => jsonb_build_array(
      jsonb_strip_nulls(
        jsonb_build_object(
          'payment_method_code',
            case upper(coalesce(nullif(trim(p_method), ''), 'CASH'))
              when 'BANK_TRANSFER' then 'BANK_TRANSFER'
              when 'BKASH' then 'BKASH'
              else 'CASH'
            end,
          'amount', v_net,
          'reference', nullif(trim(coalesce(p_bank_trx_id, '')), '')
        )
      )
    ),
    p_allocations => case
      when v_invoice_pay > 0 then jsonb_build_array(jsonb_build_object('bill_id', v_invoice.id, 'amount', v_invoice_pay))
      else '[]'::jsonb
    end,
    p_shop_order_id => p_order_id
  );
  v_payment_id := v_pay.id;

  if v_invoice_pay > 0 and nullif(trim(p_note), '') is not null then
    update public.bills
    set note = trim(p_note), updated_at = now()
    where id = v_invoice.id;
  end if;

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    payout_settlement_status = case when v_remainder > 0 then 'paid' else payout_settlement_status end,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received',
    'net_amount', v_net,
    'courier_charge', v_charge,
    'invoice_allocated', v_invoice_pay,
    'merchant_remainder', v_remainder
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.record_ledger_transaction(p_parent_tenant_id bigint, p_operating_tenant_id bigint, p_entity_type text, p_entity_id bigint, p_type text, p_amount numeric, p_currency_code text DEFAULT 'BDT'::text, p_exchange_rate numeric DEFAULT 1.000000, p_source_type text DEFAULT 'adjustment'::text, p_source_id text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb, p_target_bucket text DEFAULT 'available'::text, p_allow_overdraft boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  SELECT available_balance, pending_balance, locked_balance
  INTO v_avail, v_pend, v_lock
  FROM public.cashbook_accounts
  WHERE id = v_account_id
  FOR UPDATE;

  IF p_target_bucket = 'available' THEN
    IF p_type = 'credit' THEN
      v_avail := v_avail + p_amount;
    ELSE
      IF v_avail < p_amount AND NOT coalesce(p_allow_overdraft, false) THEN
        RAISE EXCEPTION 'Insufficient available balance (Available: %, Requested debit: %).', v_avail, p_amount;
      END IF;
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
    metadata
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
    coalesce(p_metadata, '{}'::jsonb) || jsonb_build_object('target_bucket', p_target_bucket)
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
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$function$;

CREATE OR REPLACE FUNCTION public.record_recipient_invoice_collection(p_global_invoice_id bigint, p_amount numeric, p_payment_date date DEFAULT NULL::date, p_method text DEFAULT 'cash'::text, p_reference text DEFAULT NULL::text, p_note text DEFAULT NULL::text)
 RETURNS bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.parent_tenant_id, v_payment_id, p_global_invoice_id, p_amount);

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
$function$;

CREATE OR REPLACE FUNCTION public.refresh_shipment_investor_profits(p_global_shipment_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shipment public.global_shipments;
  v_pnl jsonb;
  v_buy numeric(12,2);
  v_profit numeric(12,2);
  v_updated integer := 0;
  v_inv record;
  v_status text;
  v_sold_qty numeric;
  v_received_qty numeric;
  v_computed_profit numeric(12,2);
begin
  select * into v_shipment from public.global_shipments where id = p_global_shipment_id;
  if v_shipment.id is null then raise exception 'global shipment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_pnl := public.get_shipment_pnl(v_shipment.parent_tenant_id, p_global_shipment_id);
  v_buy := coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00);
  v_profit := coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00);

  select
    coalesce(sum(ordered_quantity), 0),
    coalesce(sum(sold_qty), 0)
  into v_received_qty, v_sold_qty
  from (
    select
      si.ordered_quantity,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.bills inv on inv.id = ii.invoice_id and inv.invoice_status = 'issued'::public.global_invoice_status
    where si.shipment_id = p_global_shipment_id
    group by si.id, si.ordered_quantity
  ) t;

  if v_received_qty = 0 then
    v_status := 'open';
  elsif v_sold_qty >= v_received_qty then
    v_status := 'realized';
  elsif v_sold_qty > 0 then
    v_status := 'partial';
  else
    v_status := 'open';
  end if;

  for v_inv in
    select * from public.shipment_investments
    where global_shipment_id = p_global_shipment_id
      and status = 'active'
      and cost_share_pct is not null
  loop
    v_computed_profit := round(v_profit * v_inv.cost_share_pct / 100.0, 2);

    update public.shipment_investments
    set
      allocated_cost = round(v_buy * v_inv.cost_share_pct / 100.0, 2),
      computed_profit = v_computed_profit,
      profit_status = v_status
    where id = v_inv.id;

    -- Update investor pending profit bucket if profit is realized
    if v_computed_profit > 0 and v_status = 'realized' then
      if not exists (
        select 1 from public.cashbook_entries
        where tenant_id = v_shipment.parent_tenant_id
          and entity_type = 'investor'
          and entity_id = v_inv.investor_id
          and source_type = 'vendor_purchase'
          and source_id = p_global_shipment_id::text
          and metadata->>'purpose' = 'shipment_investor_profit'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => v_shipment.parent_tenant_id, p_operating_tenant_id => coalesce(v_shipment.assigned_child_tenant_id, v_shipment.parent_tenant_id),
          p_entity_type => 'investor',
          p_entity_id => v_inv.investor_id,
          p_type => 'credit',
          p_amount => v_computed_profit,
          p_currency_code => 'BDT',
          p_exchange_rate => 1.000000,
          p_source_type => 'vendor_purchase',
          p_source_id => p_global_shipment_id::text,
          p_metadata => jsonb_build_object(
            'section', 'investor_capital',
            'purpose', 'shipment_investor_profit',
            'transaction_type', 'profit_accrued',
            'label', 'Shipment Profit Distribution',
            'shipment_id', p_global_shipment_id
          ),
          p_target_bucket => 'pending'
        );
      end if;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'global_shipment_id', p_global_shipment_id,
    'updated_count', v_updated,
    'buy_cost_total', v_buy,
    'profit_total', v_profit,
    'profit_status', v_status
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.release_dropship_order_stock(p_order_id bigint, p_restore_display boolean DEFAULT true)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_item record;
  v_pick record;
  v_skip_stock_release boolean := false;
  v_invoice_status public.global_invoice_status;
  v_parent_tenant_id bigint;
  v_stock public.global_stocks%rowtype;
  v_new_override_qty integer;
  v_new_sellable_qty integer;
  v_grade_tag_id bigint;
  v_held_stock_id bigint;
  v_release_qty integer;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then return; end if;

  if coalesce(v_order.shop_type_snapshot, (
    select shop_type from public.shops where id = v_order.shop_id
  )) <> 'dropship' then
    return;
  end if;

  if v_order.global_invoice_id is not null then
    select invoice_status into v_invoice_status
    from public.bills where id = v_order.global_invoice_id;
    if v_invoice_status = 'issued'::public.global_invoice_status then
      v_skip_stock_release := true;
    end if;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if not v_skip_stock_release then
    for v_pick in
      select * from public.shop_order_item_stock_picks where order_id = p_order_id
    loop
      if v_pick.held_stock_id is null then continue; end if;

      v_held_stock_id := v_pick.held_stock_id;
      v_release_qty := v_pick.quantity;

      update public.shop_order_item_stock_picks
      set held_stock_id = null, updated_at = now()
      where id = v_pick.id;

      select * into v_stock from public.global_stocks where id = v_held_stock_id for update;
      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= v_release_qty then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => v_release_qty,
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Dropship order release (pick)',
          p_reference_type => 'shop_order',
          p_reference_id => p_order_id::text
        );
      end if;
    end loop;
  end if;

  for v_item in select * from public.shop_order_items where order_id = p_order_id
  loop
    v_grade_tag_id := coalesce(
      v_item.grade_tag_id,
      (select gs.grade_tag_id from public.global_stocks gs where gs.id = v_item.global_stock_id),
      public.default_stock_grade_tag_id()
    );

    if p_restore_display then
      if v_item.listing_id is not null then
        update public.shop_product_listings
        set display_quantity_override = display_quantity_override + v_item.quantity
        where id = v_item.listing_id and display_quantity_override is not null;
      end if;
    end if;

    if not v_skip_stock_release
       and v_item.global_stock_id is not null
       and not exists (
         select 1 from public.shop_order_item_stock_picks sp
         where sp.order_item_id = v_item.id
       ) then
      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if found
         and v_stock.availability = 'held'::public.stock_availability
         and v_stock.quantity >= coalesce(v_item.confirmed_quantity, v_item.quantity) then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_tenant_id,
          p_stock_id => v_stock.id,
          p_quantity => coalesce(v_item.confirmed_quantity, v_item.quantity),
          p_to_location_id => v_stock.location_id,
          p_to_availability => 'sellable'::public.stock_availability,
          p_to_grade_tag_id => v_stock.grade_tag_id,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Dropship order release (legacy line)',
          p_reference_type => 'shop_order',
          p_reference_id => p_order_id::text
        );
      end if;
    end if;

    if v_item.listing_id is not null then
      v_new_sellable_qty := public.shop_product_grade_available_units(
        v_order.tenant_id, v_item.product_id, v_grade_tag_id
      );
      select display_quantity_override into v_new_override_qty
      from public.shop_product_listings where id = v_item.listing_id;
      if coalesce(v_new_override_qty, v_new_sellable_qty, 0) > 0 then
        update public.shop_product_listings set is_active = true where id = v_item.listing_id;
      end if;
    end if;
  end loop;
end;
$function$;

CREATE OR REPLACE FUNCTION public.remove_global_invoice_item(p_invoice_item_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.reverse_wallet_ledger_entry_for_staff(p_tenant_id bigint, p_ledger_entry_id uuid, p_reason text, p_reference_id text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.save_dropship_settlement_draft(p_tenant_id bigint, p_order_id bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_detail jsonb;
  v_settlement public.dropship_order_settlements;
  v_has_settlement boolean := false;
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_items_resell_total numeric(15,2);
  v_order_discount_amount numeric(15,2);
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_company_procurement_cost numeric(15,2);
  v_discount_company_pay numeric(15,2);
  v_return_reason_note text;
  v_charge_lines jsonb;
  v_line jsonb;
  v_totals record;
  v_currency_id bigint;
  v_payload_unit numeric(15,2);
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  v_collected_cod := coalesce((p_payload->>'collected_cod_amount')::numeric, 0);
  v_discount_company_pay := coalesce((p_payload->>'discount_company_pay')::numeric, 0);
  v_return_reason_note := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');
  v_charge_lines := coalesce(p_payload->'charge_lines', '[]'::jsonb);

  if jsonb_typeof(v_charge_lines) <> 'array' then
    raise exception 'charge_lines must be a JSON array';
  end if;

  perform public.apply_dropship_order_charge_lines(p_order_id, v_charge_lines);

  v_payload_unit := (p_payload->>'reseller_unit_purchase_cost')::numeric;
  if v_payload_unit is not null then
    perform public.apply_dropship_reseller_unit_purchase(p_order_id, v_payload_unit);
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);
  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );
  v_items_resell_total := coalesce((v_detail->'computed'->>'items_resell_total')::numeric, 0);
  v_order_discount_amount := coalesce(
    (v_detail->'order'->>'discount_amount')::numeric,
    v_order.discount_amount,
    0
  );

  select s.sell_currency_id into v_currency_id
  from public.shops s where s.id = v_order.shop_id;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  if v_has_settlement and v_settlement.status = 'confirmed' then
    raise exception 'settlement is confirmed and cannot be edited';
  end if;

  select * into v_totals
  from public.compute_dropship_settlement_totals(
    v_items_resell_total,
    v_order_discount_amount,
    v_reseller_purchase_cost,
    v_company_procurement_cost,
    v_discount_company_pay,
    v_charge_lines
  );

  if not v_has_settlement then
    insert into public.dropship_order_settlements (
      tenant_id,
      shop_order_id,
      billing_profile_id,
      currency_id,
      calculated_cod_amount,
      collected_cod_amount,
      reseller_unit_purchase_cost,
      reseller_purchase_cost,
      discount_company_pay,
      return_reason_note,
      total_cost,
      reseller_profit,
      company_profit,
      status
    ) values (
      v_order.tenant_id,
      p_order_id,
      v_order.billing_profile_id,
      v_currency_id,
      v_calculated_cod,
      v_collected_cod,
      v_reseller_unit_purchase_cost,
      v_reseller_purchase_cost,
      v_discount_company_pay,
      v_return_reason_note,
      v_totals.total_cost,
      v_totals.reseller_profit,
      v_totals.company_profit,
      'draft'
    )
    returning * into v_settlement;
  else
    update public.dropship_order_settlements
    set
      billing_profile_id = coalesce(v_order.billing_profile_id, billing_profile_id),
      currency_id = coalesce(v_currency_id, currency_id),
      calculated_cod_amount = v_calculated_cod,
      collected_cod_amount = v_collected_cod,
      reseller_unit_purchase_cost = v_reseller_unit_purchase_cost,
      reseller_purchase_cost = v_reseller_purchase_cost,
      discount_company_pay = v_discount_company_pay,
      return_reason_note = v_return_reason_note,
      total_cost = v_totals.total_cost,
      reseller_profit = v_totals.reseller_profit,
      company_profit = v_totals.company_profit,
      updated_at = now()
    where id = v_settlement.id
    returning * into v_settlement;
  end if;

  if v_settlement.id is null then
    raise exception 'settlement row missing after upsert';
  end if;

  delete from public.dropship_settlement_charge_lines
  where settlement_id = v_settlement.id;

  for v_line in select value from jsonb_array_elements(v_charge_lines)
  loop
    insert into public.dropship_settlement_charge_lines (
      settlement_id,
      charge_type,
      amount,
      payer
    ) values (
      v_settlement.id,
      (v_line->>'charge_type')::public.dropship_settlement_charge_type,
      coalesce((v_line->>'amount')::numeric, 0),
      (v_line->>'payer')::public.dropship_settlement_charge_payer
    );
  end loop;

  return jsonb_build_object(
    'success', true,
    'settlement_id', v_settlement.id,
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', v_settlement.status,
      'calculated_cod_amount', v_calculated_cod,
      'collected_cod_amount', v_settlement.collected_cod_amount,
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
      'discount_company_pay', v_settlement.discount_company_pay,
      'return_reason_note', v_settlement.return_reason_note,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at
    )
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.search_sales_invoice_stock(p_tenant_id bigint, p_search text DEFAULT NULL::text, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS TABLE(global_stock_id bigint, shipment_item_id bigint, product_id bigint, name text, barcode text, product_code text, image_url text, quantity numeric, available_atp numeric, unit_cost_price numeric, suggested_sell_price numeric, shipment_id bigint, shipment_name text, holding_tenant_id bigint, holding_tenant_name text, is_allocated_to_tenant boolean, allocation_rank integer, location_id bigint, location_name text, stock_created_at timestamp with time zone)
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.set_preorder_demand_vendor_for_document(p_tenant_id bigint, p_document_type text, p_document_id bigint, p_vendor_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_is_parent boolean;
  v_allowed boolean := false;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_updated integer := 0;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;
  if p_vendor_id is null then
    raise exception 'vendor_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent from public.tenants t where t.id = p_tenant_id;
  if not found then
    raise exception 'tenant not found: %', p_tenant_id;
  end if;

  if v_is_parent then
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  else
    v_allowed := public.is_tenant_staff(p_tenant_id);
  end if;
  if not coalesce(v_allowed, false) then
    raise exception 'access denied';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_line_tenant_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_line_tenant_id is null then
      raise exception 'shop order not found or not vendor catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_line_tenant_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id
      and f.billing_profile_id is not null;

    if v_line_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_parent_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'procuring' then
    raise exception 'document is not open for vendor updates';
  end if;

  if v_doc_type = 'shop_order' then
    with lines as (
      select
        o.tenant_id,
        oi.id as source_id
      from public.shop_order_items oi
      inner join public.shop_orders o on o.id = oi.order_id
      where o.id = p_document_id
        and o.shop_type_snapshot = 'vendor_catalog'
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        vendor_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'shop_order_item'::public.preorder_demand_source_type,
        l.source_id,
        p_vendor_id,
        0,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        vendor_id = excluded.vendor_id,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  else
    with lines as (
      select
        f.tenant_id,
        pci.id as source_id
      from public.product_based_costing_items pci
      inner join public.product_based_costing_files f on f.id = pci.product_based_costing_file_id
      where f.id = p_document_id
        and f.billing_profile_id is not null
    ),
    upserted as (
      insert into public.preorder_demand (
        tenant_id,
        source_type,
        source_id,
        vendor_id,
        placed_quantity,
        delivered_quantity,
        stock_picks,
        updated_by_user_id
      )
      select
        l.tenant_id,
        'pbc_costing_item'::public.preorder_demand_source_type,
        l.source_id,
        p_vendor_id,
        0,
        0,
        '[]'::jsonb,
        auth.uid()
      from lines l
      on conflict (source_type, source_id) do update set
        vendor_id = excluded.vendor_id,
        updated_by_user_id = auth.uid(),
        updated_at = now()
      returning 1
    )
    select count(*)::integer into v_updated from upserted;
  end if;

  return jsonb_build_object(
    'document_type', v_doc_type,
    'document_id', p_document_id,
    'vendor_id', p_vendor_id,
    'updated_count', v_updated
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.ship_dropship_order_and_issue_merchant_bill(p_tenant_id bigint, p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_issue jsonb;
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

  if v_order.status <> 'ready_for_pickup'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('ship requires ready_for_pickup (current: %s)', v_order.status)
    );
  end if;

  if v_order.billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required before ship');
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required before ship');
  end if;

  if nullif(trim(coalesce(v_order.sender_name, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_phone, '')), '') is null
     or nullif(trim(coalesce(v_order.pickup_address, '')), '') is null then
    return jsonb_build_object('success', false, 'error', 'pickup location name, phone, and address are required before ship');
  end if;

  if exists (
    select 1
    from public.shop_order_items soi
    where soi.order_id = p_order_id
      and soi.quantity > 0
      and coalesce(soi.is_fulfillment_unavailable, false) = false
      and coalesce(soi.confirmed_quantity, 0) <= 0
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  ) then
    return jsonb_build_object('success', false, 'error', 'every line must be picked or marked unavailable before ship');
  end if;

  v_issue := public.issue_dropship_tenant_b2b_invoice(p_tenant_id, p_order_id);
  if coalesce(v_issue->>'success', 'false') <> 'true' then
    return v_issue;
  end if;

  update public.shop_orders
  set
    status = 'shipped'::public.shop_order_status,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'shipped',
    'invoice', v_issue->'invoice',
    'created', coalesce(v_issue->>'created', 'false')::boolean,
    'already_issued', coalesce(v_issue->>'already_issued', 'false')::boolean
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$function$;

CREATE OR REPLACE FUNCTION public.staff_set_catalog_ordered_qty(p_order_id bigint, p_items jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order record;
  v_desk_tenant_id bigint;
  v_item_row record;
  v_target_qty integer;
  v_allocated integer;
  v_shortfall integer;
  v_product record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  v_desk_tenant_id := coalesce(v_order.parent_tenant_id, v_order.tenant_id);

  if not public.is_tenant_staff(v_desk_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  if public.normalize_shop_order_procurement_status(v_order.status) <> 'procuring' then
    raise exception 'order must be procuring to mark packed';
  end if;

  update public.shop_orders
  set
    status = 'packed'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  for v_item_row in
    select oi.*
    from public.shop_order_items oi
    where oi.order_id = p_order_id
  loop
    v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);

    select coalesce(pd.delivered_quantity, 0)
    into v_allocated
    from public.preorder_demand pd
    where pd.source_type = 'shop_order_item'
      and pd.source_id = v_item_row.id;

    v_shortfall := greatest(v_target_qty - coalesce(v_allocated, 0), 0);

    if v_shortfall > 0 and v_order.billing_profile_id is not null then
        select p.barcode, p.product_code
        into v_product
        from public.products p
        where p.id = v_item_row.product_id;

        perform public.add_demand_bucket_item_internal(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_billing_profile_id => v_order.billing_profile_id,
          p_product_id => v_item_row.product_id,
          p_source_type => 'shop_order_item',
          p_source_id => v_item_row.id,
          p_snapshot => jsonb_build_object(
            'name', coalesce(v_item_row.name, ''),
            'image_url', v_item_row.image_url,
            'barcode', v_product.barcode,
            'product_code', v_product.product_code,
            'note', null
          ),
          p_quantity => v_shortfall
        );

        insert into public.customer_order_backlog_items (
          tenant_id,
          billing_profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) values (
          v_order.tenant_id,
          v_order.billing_profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_row.id,
          v_shortfall,
          0,
          'open'
        )
        on conflict (tenant_id, billing_profile_id, product_id)
        do update set
          requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
    end if;
  end loop;

  perform public.notify_catalog_shop_order(
    p_order_id := p_order_id,
    p_notify_staff := false,
    p_notify_customer := true,
    p_event_type := 'catalog.order.packed',
    p_title := format('%s is packing', v_order.order_no),
    p_body := 'We will mark it on the way when it ships.'
  );

  return public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.submit_dropship_order_from_cart(p_shop_id bigint, p_recipient_name text, p_recipient_phone text, p_shipping_address text, p_recipient_phone_secondary text DEFAULT NULL::text, p_shipping_district text DEFAULT NULL::text, p_shipping_thana text DEFAULT NULL::text, p_shipping_post_code text DEFAULT NULL::text, p_billing_profile_id bigint DEFAULT NULL::bigint, p_is_prepaid boolean DEFAULT false, p_delivery_instructions text DEFAULT NULL::text, p_cod_charge_amount numeric DEFAULT 0, p_delivery_charge_amount numeric DEFAULT 0, p_print_charge_amount numeric DEFAULT 0, p_packing_charge_amount numeric DEFAULT 0, p_discount_amount numeric DEFAULT 0, p_recipient_pays_delivery boolean DEFAULT true, p_recipient_pays_cod boolean DEFAULT true)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shop public.shops%rowtype;
  v_cart public.shop_carts%rowtype;
  v_customer_group_id bigint;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_deduct_delivery_from_margin boolean;
  v_deduct_cod_from_margin boolean;
  v_order_item_id bigint;
  v_available_after integer;
  v_grade_tag_id bigint;
  v_listing_id bigint;
begin
  select * into v_shop from public.shops where id = p_shop_id and is_active = true;
  if v_shop.id is null then raise exception 'shop not found or inactive'; end if;
  if v_shop.shop_type <> 'dropship' then raise exception 'shop is not dropship'; end if;
  if not public.can_customer_access_shop(p_shop_id) then raise exception 'access denied'; end if;

  select access.customer_group_id into v_customer_group_id
  from public.shop_customer_group_access access
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where access.shop_id = p_shop_id and access.status = true and cg.is_active = true
    and cgm.is_active = true and lower(trim(cgm.email)) = public.current_user_email()
  order by access.created_at asc limit 1;

  if v_customer_group_id is null then raise exception 'no customer group access found'; end if;

  select * into v_cart from public.shop_carts c
  where c.tenant_id = v_shop.tenant_id and c.shop_id = p_shop_id
    and c.customer_group_id = v_customer_group_id and c.status = 'active'
  order by c.id desc limit 1;

  if v_cart.id is null then raise exception 'active cart not found'; end if;
  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then raise exception 'access denied'; end if;

  select can_place_order into v_can_place_order from public.get_shop_permissions_for_customer(p_shop_id);
  if coalesce(v_can_place_order, false) is not true then raise exception 'checkout not allowed for this customer group'; end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = v_cart.id;
  if v_item_count = 0 then raise exception 'cart is empty'; end if;

  if nullif(trim(coalesce(p_recipient_name, '')), '') is null then raise exception 'recipient name is required'; end if;
  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is null then raise exception 'recipient phone is required'; end if;
  if nullif(trim(coalesce(p_shipping_address, '')), '') is null then raise exception 'shipping address is required'; end if;
  if nullif(trim(coalesce(p_shipping_district, '')), '') is null then raise exception 'shipping district is required'; end if;
  if nullif(trim(coalesce(p_shipping_thana, '')), '') is null then raise exception 'shipping thana is required'; end if;

  if exists (
    select 1 from public.shop_cart_items ci
    where ci.cart_id = v_cart.id
      and coalesce(ci.unit_minimum_sell_price_amount, 0) > 0
      and coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, 0) < ci.unit_minimum_sell_price_amount
  ) then
    raise exception 'price floor violation: some items are priced below the minimum sell price';
  end if;

  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.order_mode = 'checkout_fixed' then v_order_status := 'confirmed';
  else v_order_status := 'submitted'; end if;

  v_deduct_delivery_from_margin := not coalesce(p_recipient_pays_delivery, true);
  v_deduct_cod_from_margin := not coalesce(p_recipient_pays_cod, true);

  select public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) into v_order_no;

  v_profile := public.upsert_recipient_profile_and_address(
    p_tenant_id => v_cart.tenant_id, p_name => p_recipient_name, p_phone => v_phone,
    p_phone_secondary => p_recipient_phone_secondary, p_address => p_shipping_address,
    p_district => p_shipping_district, p_thana => p_shipping_thana
  );
  v_recipient_profile_id := (v_profile->>'id')::bigint;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id, order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot, status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, billing_profile_id, created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  ) values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id, v_order_no,
    'Order for ' || nullif(trim(coalesce(p_recipient_name, '')), ''),
    v_shop.shop_type, v_shop.order_mode, v_shop.is_negotiable, v_order_status, 0,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone,
    nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''),
    nullif(trim(coalesce(p_shipping_district, '')), ''),
    nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id, public.current_user_email(),
    coalesce(p_cod_charge_amount, 0), coalesce(p_delivery_charge_amount, 0),
    coalesce(p_print_charge_amount, 0), coalesce(p_packing_charge_amount, 0), coalesce(p_discount_amount, 0),
    coalesce(p_is_prepaid, false), nullif(trim(coalesce(p_delivery_instructions, '')), ''),
    v_shop.deduct_charges_from_margin, v_deduct_cod_from_margin, v_deduct_delivery_from_margin,
    v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  ) returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, listing_id, grade_tag_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id, confirmed_quantity
  )
  select
    v_order_id, ci.product_id, ci.listing_id,
    coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id()),
    null, null, ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount) else null end,
    case when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id) else null end,
    coalesce(ci.unit_list_price_amount, public.shop_product_grade_avg_landed_cost(
      v_cart.tenant_id, ci.product_id,
      coalesce(ci.grade_tag_id, l.grade_tag_id, gs.grade_tag_id, public.default_stock_grade_tag_id())
    )),
    v_shop.buy_currency_id, 0
  from public.shop_cart_items ci
  left join public.shop_product_listings l on l.id = ci.listing_id
  left join public.global_stocks gs on gs.id = ci.global_stock_id
  where ci.cart_id = v_cart.id;

  for v_ci in select * from public.shop_cart_items where cart_id = v_cart.id loop
    v_grade_tag_id := coalesce(
      v_ci.grade_tag_id,
      (select l.grade_tag_id from public.shop_product_listings l where l.id = v_ci.listing_id),
      (select gs.grade_tag_id from public.global_stocks gs where gs.id = v_ci.global_stock_id),
      public.default_stock_grade_tag_id()
    );
    v_listing_id := coalesce(
      v_ci.listing_id,
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and coalesce(l.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id order by l.id asc limit 1),
      (select l.id from public.shop_product_listings l where l.shop_id = v_shop.id and l.product_id = v_ci.product_id
        and l.global_stock_id = v_ci.global_stock_id limit 1)
    );

    if v_listing_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where id = v_listing_id and display_quantity_override is not null;
    elsif v_ci.global_stock_id is not null then
      update public.shop_product_listings
      set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
      where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id
        and display_quantity_override is not null;
    end if;

    select soi.id into v_order_item_id from public.shop_order_items soi
    where soi.order_id = v_order_id and soi.product_id = v_ci.product_id
      and soi.listing_id is not distinct from v_ci.listing_id order by soi.id asc limit 1;
    if v_order_item_id is null then
      select soi.id into v_order_item_id from public.shop_order_items soi
      where soi.order_id = v_order_id and soi.product_id = v_ci.product_id order by soi.id asc limit 1;
    end if;
    if v_order_item_id is not null then
      update public.shop_order_items
      set listing_id = coalesce(listing_id, v_listing_id), grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id)
      where id = v_order_item_id;
    end if;

    if v_listing_id is not null then
      v_available_after := public.shop_product_grade_available_units(v_cart.tenant_id, v_ci.product_id, v_grade_tag_id);
      if coalesce((select display_quantity_override from public.shop_product_listings where id = v_listing_id), v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false where id = v_listing_id;
      end if;
    elsif v_ci.global_stock_id is not null then
      select coalesce(sum(gs.quantity), 0) into v_available_after from public.global_stocks gs
      where gs.shipment_item_id = (select shipment_item_id from public.global_stocks where id = v_ci.global_stock_id)
        and gs.availability = 'sellable'::public.stock_availability;
      if coalesce((select display_quantity_override from public.shop_product_listings
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id),
        v_available_after, 0) <= 0 then
        update public.shop_product_listings set is_active = false
        where shop_id = v_shop.id and product_id = v_ci.product_id and global_stock_id = v_ci.global_stock_id;
      end if;
    end if;
  end loop;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = v_cart.id);
  update public.shop_carts set status = 'converted', updated_at = now() where id = v_cart.id;

  perform public.recompute_dropship_cod_collect_amount(v_order_id);

  select jsonb_build_object(
    'order_id', v_order_id, 'order_no', v_order_no, 'status', v_order_status,
    'cart_id', v_cart.id, 'shop_id', v_shop.id
  ) into v_result;
  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.submit_shop_order_from_cart(p_cart_id bigint, p_recipient_name text, p_recipient_phone text, p_shipping_address text, p_recipient_phone_secondary text DEFAULT NULL::text, p_shipping_district text DEFAULT NULL::text, p_shipping_thana text DEFAULT NULL::text, p_billing_profile_id bigint DEFAULT NULL::bigint, p_is_prepaid boolean DEFAULT false, p_delivery_instructions text DEFAULT NULL::text, p_cod_charge_amount numeric DEFAULT 0, p_delivery_charge_amount numeric DEFAULT 0, p_print_charge_amount numeric DEFAULT 0, p_packing_charge_amount numeric DEFAULT 0, p_discount_amount numeric DEFAULT 0)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_cart public.shop_carts%rowtype;
  v_shop public.shops%rowtype;
  v_order_id bigint;
  v_order_no text;
  v_order_status public.shop_order_status;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_item_count integer;
  v_result jsonb;
  v_billing_profile_id bigint;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_phone text;
  v_ci record;
  v_rem_alloc_qty integer;
  v_rem_override_qty integer;
begin
  select * into v_cart from public.shop_carts where id = p_cart_id and status = 'active';
  if v_cart.id is null then
    raise exception 'active cart not found';
  end if;

  if not public.is_cart_owner(v_cart.customer_group_id, v_cart.tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_shop from public.shops where id = v_cart.shop_id;
  if v_shop.id is null or not v_shop.is_active then
    raise exception 'shop not found or inactive';
  end if;

  select can_place_order, can_negotiate
  into v_can_place_order, v_can_negotiate
  from public.get_shop_permissions_for_customer(v_shop.id);

  if coalesce(v_can_place_order, false) is not true then
    raise exception 'checkout not allowed for this customer group';
  end if;

  select count(*) into v_item_count from public.shop_cart_items where cart_id = p_cart_id;
  if v_item_count = 0 then
    raise exception 'cart is empty';
  end if;

  if v_shop.shop_type = 'dropship' then
    if exists (
      select 1 from public.shop_cart_items ci
      where ci.cart_id = p_cart_id
        and ci.customer_sell_price_currency_id = ci.unit_minimum_sell_price_currency_id
        and ci.customer_sell_price_amount < ci.unit_minimum_sell_price_amount
    ) then
      raise exception 'price floor violation: some items are priced below the minimum sell price';
    end if;
  end if;

  v_billing_profile_id := p_billing_profile_id;
  if v_billing_profile_id is null then
    v_billing_profile_id := public.resolve_billing_profile_for_customer_group(v_cart.tenant_id, v_cart.customer_group_id);
  end if;

  if v_shop.shop_type = 'vendor_catalog' then
    if v_shop.order_mode <> 'procurement_intent' then
      raise exception 'invalid order mode for vendor catalog shop';
    end if;
    -- Catalog orders always start at submitted (CATALOG_NEGOTIATION.md §2.1); negotiation begins at priced.
    v_order_status := 'submitted';
  else
    if v_shop.order_mode = 'checkout_fixed' then
      v_order_status := 'confirmed';
    else
      v_order_status := 'submitted';
    end if;
  end if;

  select public.generate_shop_order_number(v_cart.tenant_id, v_cart.shop_id) into v_order_no;

  v_phone := nullif(trim(coalesce(p_recipient_phone, '')), '');
  if v_phone is not null then
    v_profile := public.upsert_recipient_profile_and_address(
      p_tenant_id => v_cart.tenant_id,
      p_name => p_recipient_name,
      p_phone => v_phone,
      p_phone_secondary => p_recipient_phone_secondary,
      p_address => p_shipping_address,
      p_district => p_shipping_district,
      p_thana => p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;
  end if;

  insert into public.shop_orders (
    tenant_id, shop_id, customer_group_id, cart_id,
    order_no, name,
    shop_type_snapshot, order_mode_snapshot, is_negotiable_snapshot,
    status, negotiate_round,
    recipient_name, recipient_phone, recipient_phone_secondary,
    shipping_address, shipping_district, shipping_thana,
    recipient_profile_id, billing_profile_id,
    created_by_email,
    cod_charge_amount, delivery_charge_amount, print_charge_amount, packing_charge_amount, discount_amount,
    is_prepaid_snapshot, delivery_instructions, deduct_charges_from_margin,
    deduct_cod_from_margin, deduct_delivery_from_margin, deduct_print_from_margin, deduct_packing_from_margin
  )
  values (
    v_cart.tenant_id, v_cart.shop_id, v_cart.customer_group_id, v_cart.id,
    v_order_no, 'Order for ' || coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), 'customer'),
    v_shop.shop_type, v_shop.order_mode,
    coalesce(v_shop.is_negotiable, false) and coalesce(v_can_negotiate, false),
    v_order_status, case when v_order_status = 'negotiating' then 1 else 0 end,
    nullif(trim(coalesce(p_recipient_name, '')), ''), v_phone, nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''),
    nullif(trim(coalesce(p_shipping_address, '')), ''), nullif(trim(coalesce(p_shipping_district, '')), ''), nullif(trim(coalesce(p_shipping_thana, '')), ''),
    v_recipient_profile_id, v_billing_profile_id,
    public.current_user_email(),
    p_cod_charge_amount, p_delivery_charge_amount, p_print_charge_amount, p_packing_charge_amount, p_discount_amount,
    p_is_prepaid, p_delivery_instructions, v_shop.deduct_charges_from_margin,
    false, false, v_shop.deduct_print_from_margin, v_shop.deduct_packing_from_margin
  )
  returning id into v_order_id;

  insert into public.shop_order_items (
    order_id, product_id, global_stock_id, global_stock_allocation_id,
    name, image_url, quantity,
    unit_list_price_amount, unit_list_price_currency_id,
    unit_sell_price_amount, unit_sell_price_currency_id,
    unit_minimum_sell_price_amount, unit_minimum_sell_price_currency_id,
    customer_sell_price_amount, customer_sell_price_currency_id,
    customer_offer_amount, customer_offer_currency_id,
    final_price_amount, final_price_currency_id,
    cost_price_amount, cost_price_currency_id
  )
  select
    v_order_id, ci.product_id, ci.global_stock_id, ci.global_stock_allocation_id,
    ci.name, ci.image_url, ci.quantity,
    ci.unit_list_price_amount, ci.unit_list_price_currency_id,
    ci.unit_sell_price_amount, ci.unit_sell_price_currency_id,
    ci.unit_minimum_sell_price_amount, ci.unit_minimum_sell_price_currency_id,
    ci.customer_sell_price_amount, ci.customer_sell_price_currency_id,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_amount else null end,
    case when v_shop.shop_type = 'dropship' then ci.customer_sell_price_currency_id else null end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_amount, ci.unit_sell_price_amount, ci.unit_list_price_amount)
      else null
    end,
    case
      when v_order_status = 'confirmed' then coalesce(ci.customer_sell_price_currency_id, ci.unit_sell_price_currency_id, ci.unit_list_price_currency_id)
      else null
    end,
    case when v_shop.shop_type = 'dropship' then public.resolve_shop_order_item_landed_cost(ci.global_stock_id, null, ci.unit_list_price_amount) else null end,
    case when v_shop.shop_type = 'dropship' then v_shop.buy_currency_id else null end
  from public.shop_cart_items ci
  where ci.cart_id = p_cart_id;

  if v_shop.shop_type = 'dropship' then
    for v_ci in select * from public.shop_cart_items where cart_id = p_cart_id loop
      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        update public.shop_product_listings
        set display_quantity_override = greatest(0, display_quantity_override - v_ci.quantity)
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id
          and display_quantity_override is not null;
      end if;

      if v_ci.global_stock_allocation_id is not null then
        update public.global_stock_allocations
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_allocation_id;
      end if;

      if v_ci.global_stock_id is not null then
        update public.global_stocks
        set quantity = greatest(0, quantity - v_ci.quantity)
        where id = v_ci.global_stock_id;
      end if;

      if v_ci.product_id is not null and v_ci.global_stock_allocation_id is not null then
        select gsa.quantity into v_rem_alloc_qty
        from public.global_stock_allocations gsa
        where gsa.id = v_ci.global_stock_allocation_id;

        select display_quantity_override into v_rem_override_qty
        from public.shop_product_listings
        where shop_id = v_shop.id
          and product_id = v_ci.product_id
          and global_stock_allocation_id = v_ci.global_stock_allocation_id;

        if coalesce(v_rem_override_qty, v_rem_alloc_qty, 0) <= 0 then
          update public.shop_product_listings
          set is_active = false
          where shop_id = v_shop.id
            and product_id = v_ci.product_id
            and global_stock_allocation_id = v_ci.global_stock_allocation_id;
        end if;
      end if;
    end loop;
  end if;

  delete from public.shop_stock_reservations
  where cart_item_id in (select id from public.shop_cart_items where cart_id = p_cart_id);

  update public.shop_carts
  set status = 'converted', updated_at = now()
  where id = p_cart_id;

  if v_shop.shop_type = 'vendor_catalog' then
    perform public.notify_catalog_shop_order(
      p_order_id := v_order_id,
      p_notify_staff := true,
      p_notify_customer := false,
      p_event_type := 'catalog.order.created',
      p_title := format('New order %s', v_order_no),
      p_body := format('%s items to price', v_item_count)
    );
  end if;

  select jsonb_build_object(
    'order_id', v_order_id,
    'order_no', v_order_no,
    'status', v_order_status
  ) into v_result;

  return v_result;
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    collection_source = 'billing_profile'::public.collection_source_type,
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
$function$;

CREATE OR REPLACE FUNCTION public.sync_invoice_from_preorder_demand_document(p_tenant_id bigint, p_document_type text, p_document_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_operating_tenant_id bigint;
  v_invoice_id bigint;
  v_doc_status text;
  v_invoice_status public.global_invoice_status;
  v_items jsonb := '[]'::jsonb;
  v_remove_ids jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_invoice_id, v_doc_status
    from public.product_based_costing_files f
    where f.id = p_document_id;

    if v_operating_tenant_id is null then
      raise exception 'costing file not found';
    end if;
  else
    raise exception 'invalid document_type: %', p_document_type;
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_operating_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_doc_status <> 'packed' then
    raise exception 'document must be packed to sync invoice from demand';
  end if;

  if v_invoice_id is null then
    raise exception 'document has no linked invoice';
  end if;

  select si.invoice_status
  into v_invoice_status
  from public.bills si
  where si.id = v_invoice_id;

  if v_invoice_status is null then
    raise exception 'invoice not found';
  end if;

  if v_invoice_status not in (
    'draft'::public.global_invoice_status,
    'proforma_generated'::public.global_invoice_status
  ) then
    raise exception 'invoice is not editable (status: %)', v_invoice_status;
  end if;

  v_items := public.build_preorder_demand_invoice_items(v_doc_type, p_document_id);

  if jsonb_array_length(v_items) = 0 then
    raise exception 'at least one stock pick is required to sync invoice';
  end if;

  select coalesce(jsonb_agg(sii.id), '[]'::jsonb)
  into v_remove_ids
  from public.bill_lines sii
  where sii.invoice_id = v_invoice_id;

  v_payload := jsonb_build_object(
    'items', v_items,
    'remove_item_ids', v_remove_ids
  );

  v_result := public.update_sales_invoice_from_payload(
    coalesce(v_operating_tenant_id, p_tenant_id),
    v_invoice_id,
    v_payload
  );

  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'failed to sync invoice from demand');
  end if;

  return v_result || jsonb_build_object(
    'invoice_id', v_invoice_id,
    'synced', true
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_sales_invoice_charges_from_header(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_inv public.bills;
  v_total numeric(12,2) := 0;
begin
  select * into v_inv from public.bills where id = p_invoice_id;
  if not found then
    return;
  end if;

  delete from public.bill_charges where invoice_id = p_invoice_id;

  if coalesce(v_inv.shipping_charge, 0) > 0 then
    insert into public.bill_charges (invoice_id, parent_tenant_id, charge_type, amount)
    values (p_invoice_id, v_inv.parent_tenant_id, 'delivery', v_inv.shipping_charge);
    v_total := v_total + v_inv.shipping_charge;
  end if;

  if coalesce(v_inv.print_charge, 0) > 0 then
    insert into public.bill_charges (invoice_id, parent_tenant_id, charge_type, amount)
    values (p_invoice_id, v_inv.parent_tenant_id, 'print', v_inv.print_charge);
    v_total := v_total + v_inv.print_charge;
  end if;

  if coalesce(v_inv.wrapping_charge, 0) > 0 then
    insert into public.bill_charges (invoice_id, parent_tenant_id, charge_type, amount)
    values (p_invoice_id, v_inv.parent_tenant_id, 'packing', v_inv.wrapping_charge);
    v_total := v_total + v_inv.wrapping_charge;
  end if;


  update public.bills
  set charges_amount = v_total,
      updated_at = now()
  where id = p_invoice_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.sync_shop_order_collection_source_from_invoice()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.transfer_dropship_reseller_profit(p_tenant_id bigint, p_order_id bigint, p_payload jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_save jsonb;
  v_billing_profile_id bigint;
  v_amount numeric(15,2);
  v_parent_tenant_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id
     and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'order not found';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if not found then
    raise exception 'settlement draft is required before crediting reseller profit';
  end if;

  if v_order.status = 'reseller_paid'::public.shop_order_status
     or v_settlement.merchant_payout_at is not null
     or v_settlement.status = 'confirmed' then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'status', coalesce(v_order.status::text, 'reseller_paid')
    );
  end if;

  if v_order.courier_remittance_ref is null
     and v_settlement.remittance_at is null
     and v_order.status <> 'payment_received'::public.shop_order_status then
    raise exception 'Courier remittance must be recorded before crediting reseller profit (current: %)', v_order.status;
  end if;

  if p_payload is not null and p_payload <> '{}'::jsonb then
    v_save := public.save_dropship_settlement_draft(p_tenant_id, p_order_id, p_payload);
    if coalesce(v_save->>'success', 'false') <> 'true' then
      return v_save;
    end if;

    select * into v_settlement
    from public.dropship_order_settlements
    where shop_order_id = p_order_id;
  end if;

  v_billing_profile_id := coalesce(v_order.billing_profile_id, v_settlement.billing_profile_id);
  if v_billing_profile_id is null then
    raise exception 'billing profile is required for reseller profit credit';
  end if;

  v_amount := coalesce(v_settlement.reseller_profit, 0);
  if v_amount <= 0 then
    return jsonb_build_object(
      'success', true,
      'skipped', true,
      'message', 'No reseller profit to credit',
      'order_id', p_order_id,
      'amount', 0
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if exists (
    select 1
    from public.cashbook_entries u
    where u.parent_tenant_id = v_parent_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = v_billing_profile_id
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
  ) then
    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'message', 'Reseller profit already credited to merchant wallet',
      'order_id', p_order_id,
      'amount', v_amount
    );
  end if;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => v_order.tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_billing_profile_id,
    p_type => 'credit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'transaction_type', 'dropship_profit',
      'label', 'Dropship profit earned',
      'order_no', v_order.order_no,
      'order_id', p_order_id,
      'shop_order_id', p_order_id::text,
      'invoice_id', v_order.global_invoice_id,
      'notes', coalesce(
        nullif(trim(p_payload->>'reference_notes'), ''),
        'Dropship reseller profit for order #' || v_order.order_no
      )
    )
  );

  update public.dropship_order_settlements
  set
    status = 'confirmed',
    confirmed_at = now(),
    confirmed_by = auth.uid(),
    merchant_payout_at = now(),
    updated_at = now()
  where id = v_settlement.id;

  update public.shop_orders
  set
    status = 'reseller_paid'::public.shop_order_status,
    payout_settlement_status = 'paid',
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', 'Reseller profit credited to merchant wallet',
    'order_id', p_order_id,
    'amount', v_amount,
    'status', 'reseller_paid',
    'billing_profile_id', v_billing_profile_id
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.transfer_wallet_balance(p_tenant_id bigint, p_entity_type text, p_entity_id bigint, p_from_bucket text, p_to_bucket text, p_amount numeric, p_currency_code text DEFAULT 'BDT'::text, p_notes text DEFAULT NULL::text, p_metadata jsonb DEFAULT '{}'::jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    IF v_avail < p_amount THEN
      RAISE EXCEPTION 'Insufficient available balance (Available: %, Requested: %).', v_avail, p_amount;
    END IF;
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
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_auto_upsert_pbc_backlog()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_file public.product_based_costing_files%rowtype;
  v_tenant_id bigint;
  v_other_id bigint;
  v_open_qty numeric;
  v_prod record;
  v_price_gbp numeric;
  v_name text;
begin
  if tg_op = 'DELETE' then
    if old.product_id is not null and old.product_based_costing_file_id is not null then
      select * into v_file
      from public.product_based_costing_files
      where id = old.product_based_costing_file_id;

      if v_file.id is not null then
        v_tenant_id := v_file.tenant_id;
        if v_tenant_id is null and v_file.billing_profile_id is not null then
          select tenant_id into v_tenant_id
          from public.billing_profiles
          where id = v_file.billing_profile_id;
        end if;

        select pci.id into v_other_id
        from public.product_based_costing_items pci
        inner join public.product_based_costing_files pcf
          on pcf.id = pci.product_based_costing_file_id
        where pci.product_id = old.product_id
          and pcf.billing_profile_id is not distinct from v_file.billing_profile_id
        order by pci.updated_at desc nulls last, pci.id desc
        limit 1;

        if v_other_id is not null then
          perform public.upsert_pbc_backlog_from_item(v_other_id);
        elsif v_tenant_id is not null and v_file.billing_profile_id is not null then
          v_open_qty := coalesce(old.confirmed_quantity, old.quantity, 0);

          if coalesce(v_file.status, 'pending') in ('pending', 'offered')
             and v_open_qty > 0
          then
            select
              p.name,
              p.image_url,
              p.list_price_amount,
              p.product_weight,
              p.package_weight,
              p.barcode,
              p.product_code,
              gc.code as list_price_currency_code
            into v_prod
            from public.products p
            left join public.global_currencies gc on gc.id = p.list_price_currency_id
            where p.id = old.product_id;

            v_name := coalesce(old.name, v_prod.name);
            v_price_gbp := coalesce(
              old.price_gbp,
              case
                when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
                  then v_prod.list_price_amount
                else null
              end
            );

            if v_name is not null then
              insert into public.product_based_costing_backlog_items (
                tenant_id,
                billing_profile_id,
                product_id,
                open_quantity,
                name,
                image_url,
                barcode,
                product_code,
                price_gbp,
                product_weight,
                package_weight,
                last_costing_file_id,
                last_costing_item_id,
                updated_at
              )
              values (
                v_tenant_id,
                v_file.billing_profile_id,
                old.product_id,
                round(v_open_qty)::integer,
                v_name,
                coalesce(old.image_url, v_prod.image_url),
                coalesce(old.barcode, v_prod.barcode),
                coalesce(old.product_code, v_prod.product_code),
                v_price_gbp,
                coalesce(old.product_weight::numeric, v_prod.product_weight),
                coalesce(old.package_weight::numeric, v_prod.package_weight),
                v_file.id,
                null,
                now()
              )
              on conflict (tenant_id, billing_profile_id, product_id)
              do update set
                open_quantity = excluded.open_quantity,
                name = excluded.name,
                image_url = excluded.image_url,
                barcode = excluded.barcode,
                product_code = excluded.product_code,
                price_gbp = excluded.price_gbp,
                product_weight = excluded.product_weight,
                package_weight = excluded.package_weight,
                last_costing_file_id = excluded.last_costing_file_id,
                last_costing_item_id = excluded.last_costing_item_id,
                updated_at = now();
            end if;
          else
            delete from public.product_based_costing_backlog_items
            where tenant_id = v_tenant_id
              and billing_profile_id = v_file.billing_profile_id
              and product_id = old.product_id;
          end if;
        end if;
      end if;
    end if;

    return old;
  end if;

  perform public.upsert_pbc_backlog_from_item(new.id);
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_pbc_files_auto_tenant_id()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.tenant_id is not null then
    select coalesce(t.parent_id, t.id)
    into new.tenant_id
    from public.tenants t
    where t.id = new.tenant_id;
  elsif new.billing_profile_id is not null then
    select coalesce(t.parent_id, t.id)
    into new.tenant_id
    from public.billing_profiles bp
    inner join public.tenants t on t.id = bp.tenant_id
    where bp.id = new.billing_profile_id;
  end if;
  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_pbc_files_stamp_billing_profile()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.customer_group_id is not null then
    select bp.id
    into new.billing_profile_id
    from public.billing_profiles bp
    where bp.customer_group_id = new.customer_group_id;

    if new.billing_profile_id is null then
      raise exception 'customer_group_id % has no linked billing profile', new.customer_group_id;
    end if;
  elsif tg_op = 'UPDATE' and new.customer_group_id is null and old.customer_group_id is not null then
    new.billing_profile_id := null;
  end if;

  return new;
end;
$function$;

CREATE OR REPLACE FUNCTION public.trg_validate_global_invoice_profiles()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if new.profile_id is not null then
    if not public.billing_profile_valid_for_issuer(
      new.profile_id,
      new.issued_by_tenant_id
    ) then
      raise exception 'Billing profile tenant_id must match invoice issued_by_tenant_id';
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
$function$;

CREATE OR REPLACE FUNCTION public.unpost_sales_invoice(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.update_dropship_consignment(p_order_id bigint, p_cod_collect_amount numeric DEFAULT 0.00, p_package_weight_band text DEFAULT 'under_1kg'::text, p_item_category text DEFAULT NULL::text, p_parcel_description text DEFAULT NULL::text, p_courier_order_ref text DEFAULT NULL::text, p_delivery_zone text DEFAULT 'inside_dhaka'::text, p_sender_name text DEFAULT NULL::text, p_pickup_phone text DEFAULT NULL::text, p_pickup_address text DEFAULT NULL::text, p_payout_account_type text DEFAULT 'bank'::text, p_payout_account_info text DEFAULT NULL::text, p_allow_open_box boolean DEFAULT false, p_delivery_instruction_notes text DEFAULT NULL::text, p_courier_service_id uuid DEFAULT NULL::uuid, p_courier_tracking_number text DEFAULT NULL::text, p_courier_awb_number text DEFAULT NULL::text, p_courier_consignment_id text DEFAULT NULL::text, p_tracking_url text DEFAULT NULL::text, p_courier_cost_amount numeric DEFAULT 0.00, p_recipient_name text DEFAULT NULL::text, p_recipient_phone text DEFAULT NULL::text, p_recipient_phone_secondary text DEFAULT NULL::text, p_shipping_address text DEFAULT NULL::text, p_shipping_district text DEFAULT NULL::text, p_shipping_thana text DEFAULT NULL::text, p_delivery_charge_amount numeric DEFAULT NULL::numeric, p_cod_charge_amount numeric DEFAULT NULL::numeric)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order public.shop_orders%rowtype;
  v_profile jsonb;
  v_recipient_profile_id bigint;
  v_delivery_charge numeric;
  v_cod_charge numeric;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  v_delivery_charge := coalesce(p_delivery_charge_amount, p_courier_cost_amount, 0.00);
  v_cod_charge := coalesce(p_cod_charge_amount, 0.00);

  update public.shop_orders
  set
    cod_collect_amount = p_cod_collect_amount,
    package_weight_band = p_package_weight_band,
    item_category = p_item_category,
    parcel_description = p_parcel_description,
    courier_order_ref = coalesce(p_courier_order_ref, order_no),
    delivery_zone = p_delivery_zone,
    sender_name = p_sender_name,
    pickup_phone = p_pickup_phone,
    pickup_address = p_pickup_address,
    payout_account_type = p_payout_account_type,
    payout_account_info = p_payout_account_info,
    allow_open_box = p_allow_open_box,
    delivery_instruction_notes = p_delivery_instruction_notes,
    courier_service_id = p_courier_service_id,
    courier_tracking_number = p_courier_tracking_number,
    courier_awb_number = p_courier_awb_number,
    courier_consignment_id = p_courier_consignment_id,
    tracking_url = p_tracking_url,
    courier_cost_amount = p_courier_cost_amount,
    delivery_charge_amount = v_delivery_charge,
    cod_charge_amount = v_cod_charge,
    updated_at = now()
  where id = p_order_id;

  if nullif(trim(coalesce(p_recipient_phone, '')), '') is not null then
    v_profile := public.upsert_recipient_profile_by_phone(
      v_order.tenant_id,
      coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), v_order.recipient_name, 'Recipient'),
      p_recipient_phone,
      p_recipient_phone_secondary,
      coalesce(nullif(trim(coalesce(p_shipping_address, '')), ''), v_order.shipping_address, 'Address pending'),
      p_shipping_district,
      p_shipping_thana
    );
    v_recipient_profile_id := (v_profile->>'id')::bigint;

    update public.shop_orders
    set
      recipient_name = coalesce(nullif(trim(coalesce(p_recipient_name, '')), ''), recipient_name),
      recipient_phone = v_profile->>'phone',
      recipient_phone_secondary = coalesce(nullif(trim(coalesce(p_recipient_phone_secondary, '')), ''), recipient_phone_secondary),
      shipping_address = coalesce(nullif(trim(coalesce(p_shipping_address, '')), ''), shipping_address),
      shipping_district = coalesce(nullif(trim(coalesce(p_shipping_district, '')), ''), shipping_district),
      shipping_thana = coalesce(nullif(trim(coalesce(p_shipping_thana, '')), ''), shipping_thana),
      recipient_profile_id = v_recipient_profile_id,
      updated_at = now()
    where id = p_order_id;
  end if;

  return jsonb_build_object('success', true);
end;
$function$;

CREATE OR REPLACE FUNCTION public.update_global_invoice_header(p_invoice_id bigint, p_discount_amount numeric DEFAULT NULL::numeric, p_shipping_charge numeric DEFAULT NULL::numeric, p_cod_charge numeric DEFAULT NULL::numeric, p_wrapping_charge numeric DEFAULT NULL::numeric, p_print_charge numeric DEFAULT NULL::numeric, p_recipient_name text DEFAULT NULL::text, p_recipient_phone text DEFAULT NULL::text, p_recipient_address text DEFAULT NULL::text, p_note text DEFAULT NULL::text, p_invoice_no text DEFAULT NULL::text, p_invoice_date date DEFAULT NULL::date)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.update_global_invoice_item(p_item_id bigint, p_quantity numeric, p_sell_price_amount numeric, p_recipient_price_amount numeric DEFAULT NULL::numeric)
 RETURNS bill_lines
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.update_payment_instrument_details(p_tenant_id bigint, p_instrument_id bigint, p_reference text DEFAULT NULL::text, p_bd_bank_id bigint DEFAULT NULL::bigint, p_cheque_number text DEFAULT NULL::text, p_cheque_date date DEFAULT NULL::date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.update_sales_invoice_from_payload(p_tenant_id bigint, p_invoice_id bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
    if v_inv_patch ? 'billing_profile_id' and nullif(v_inv_patch->>'billing_profile_id', '') is not null then
      if not exists (
        select 1 from public.billing_profiles bp
        where bp.id = (v_inv_patch->>'billing_profile_id')::bigint
          and bp.tenant_id = p_tenant_id
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
        when v_inv_patch ? 'billing_profile_id' then nullif(v_inv_patch->>'billing_profile_id', '')::bigint
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
      'billing_profile_id', v_invoice.profile_id,
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
$function$;

CREATE OR REPLACE FUNCTION public.update_shop_order_charges_for_staff(p_tenant_id bigint, p_order_id bigint, p_payload jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_order record;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant and order required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if not found or (v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    delivery_charge_amount = coalesce((p_payload->>'delivery_charge_amount')::numeric, o.delivery_charge_amount),
    deduct_delivery_from_margin = coalesce((p_payload->>'deduct_delivery_from_margin')::boolean, o.deduct_delivery_from_margin),
    cod_charge_amount = coalesce((p_payload->>'cod_charge_amount')::numeric, o.cod_charge_amount),
    deduct_cod_from_margin = coalesce((p_payload->>'deduct_cod_from_margin')::boolean, o.deduct_cod_from_margin),
    print_charge_amount = coalesce((p_payload->>'print_charge_amount')::numeric, o.print_charge_amount),
    deduct_print_from_margin = coalesce((p_payload->>'deduct_print_from_margin')::boolean, o.deduct_print_from_margin),
    packing_charge_amount = coalesce((p_payload->>'packing_charge_amount')::numeric, o.packing_charge_amount),
    deduct_packing_from_margin = coalesce((p_payload->>'deduct_packing_from_margin')::boolean, o.deduct_packing_from_margin),
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$function$;

CREATE OR REPLACE FUNCTION public.upsert_pbc_backlog_from_item(p_costing_item_id bigint)
 RETURNS product_based_costing_backlog_items
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_item public.product_based_costing_items%rowtype;
  v_file public.product_based_costing_files%rowtype;
  v_prod record;
  v_confirmed_qty numeric;
  v_open_qty numeric;
  v_backlog_row public.product_based_costing_backlog_items;
  v_tenant_id bigint;
  v_price_gbp numeric;
begin
  select * into v_item
  from public.product_based_costing_items
  where id = p_costing_item_id;

  if v_item.id is null then
    return null;
  end if;

  select * into v_file
  from public.product_based_costing_files
  where id = v_item.product_based_costing_file_id;

  if v_file.id is null then
    raise exception 'costing file % not found', v_item.product_based_costing_file_id;
  end if;

  v_tenant_id := v_file.tenant_id;
  if v_tenant_id is null and v_file.billing_profile_id is not null then
    select tenant_id into v_tenant_id
    from public.billing_profiles
    where id = v_file.billing_profile_id;
  end if;

  if v_tenant_id is not null and not (
    public.can_admin_manage_costing_file(v_tenant_id)
    or public.can_staff_access_costing_file(v_tenant_id)
  ) then
    raise exception 'access denied for tenant %', v_tenant_id;
  end if;

  if v_tenant_id is null or v_file.billing_profile_id is null or v_item.product_id is null then
    return null;
  end if;

  v_confirmed_qty := coalesce(v_item.confirmed_quantity, v_item.quantity, 0);
  v_open_qty := case
    when v_item.assigned_shipment_id is not null then 0
    when coalesce(v_file.status, 'pending') in ('pending', 'offered') then v_confirmed_qty
    else 0
  end;

  if v_confirmed_qty <= 0 or v_open_qty <= 0 then
    delete from public.product_based_costing_backlog_items
    where tenant_id = v_tenant_id
      and billing_profile_id = v_file.billing_profile_id
      and product_id = v_item.product_id;
    return null;
  end if;

  select
    p.name,
    p.image_url,
    p.list_price_amount,
    p.product_weight,
    p.package_weight,
    p.barcode,
    p.product_code,
    p.brand,
    gc.code as list_price_currency_code
  into v_prod
  from public.products p
  left join public.global_currencies gc on gc.id = p.list_price_currency_id
  where p.id = v_item.product_id;

  v_price_gbp := coalesce(
    v_item.price_gbp,
    case
      when v_prod.list_price_currency_code is null or v_prod.list_price_currency_code = 'GBP'
        then v_prod.list_price_amount
      else null
    end
  );

  insert into public.product_based_costing_backlog_items (
    tenant_id,
    billing_profile_id,
    product_id,
    open_quantity,
    name,
    image_url,
    barcode,
    product_code,
    price_gbp,
    product_weight,
    package_weight,
    last_costing_file_id,
    last_costing_item_id,
    updated_at
  )
  values (
    v_tenant_id,
    v_file.billing_profile_id,
    v_item.product_id,
    v_open_qty,
    coalesce(v_item.name, v_prod.name),
    coalesce(v_item.image_url, v_prod.image_url),
    coalesce(v_item.barcode, v_prod.barcode),
    coalesce(v_item.product_code, v_prod.product_code),
    v_price_gbp,
    coalesce(v_item.product_weight::numeric, v_prod.product_weight),
    coalesce(v_item.package_weight::numeric, v_prod.package_weight),
    v_file.id,
    v_item.id,
    now()
  )
  on conflict (tenant_id, billing_profile_id, product_id)
  do update set
    open_quantity = excluded.open_quantity,
    name = excluded.name,
    image_url = excluded.image_url,
    barcode = excluded.barcode,
    product_code = excluded.product_code,
    price_gbp = excluded.price_gbp,
    product_weight = excluded.product_weight,
    package_weight = excluded.package_weight,
    last_costing_file_id = excluded.last_costing_file_id,
    last_costing_item_id = excluded.last_costing_item_id,
    updated_at = now()
  returning * into v_backlog_row;

  return v_backlog_row;
end;
$function$;

CREATE OR REPLACE FUNCTION public.void_customer_receipt(p_tenant_id bigint, p_payment_id bigint, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
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
$function$;

CREATE OR REPLACE FUNCTION public.void_sales_invoice(p_invoice_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.bills;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'invoice not found'; end if;
  if v_invoice.invoice_status <> 'posted'::public.global_invoice_status then
    raise exception 'only posted invoices can be voided';
  end if;
  if v_invoice.paid_amount > 0 then
    raise exception 'cannot void a paid or partially paid invoice; reverse collections/payments first';
  end if;

  -- Mark invoice as voided (Trigger on bills handles restoring stock)
  update public.bills
  set
    invoice_status = 'voided'::public.global_invoice_status,
    due_amount = 0.00
  where id = p_invoice_id;
end;
$function$;


-- ---------------------------------------------------------------------------
-- WA12: one receipt writer (03-api-contract § B.0)
-- ---------------------------------------------------------------------------
create or replace function public.post_customer_receipt_with_allocations(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_received_on date,
  p_note text default null,
  p_reference text default null,
  p_source text default 'customer_cash',
  p_instruments jsonb default '[]'::jsonb,
  p_allocations jsonb default '[]'::jsonb,
  p_shop_order_id bigint default null
)
returns public.pays
language plpgsql
security definer
set search_path to 'public'
as $function$
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
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_billing_profile_id is null then
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
    where pr.id = p_billing_profile_id and pr.parent_tenant_id = v_parent_id
  ) then
    raise exception 'Profile % does not belong to these books', p_billing_profile_id;
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

  insert into public.pays (
    tenant_id, profile_id, source, amount, unallocated_amount,
    payment_date, method, reference, note, shop_order_id
  ) values (
    v_parent_id, p_billing_profile_id, v_source, v_amount, v_amount,
    v_received_on, v_header_method, v_reference, v_note, p_shop_order_id
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
      if v_bill.profile_id is distinct from p_billing_profile_id then
        raise exception 'Bill % is billed to a different profile', v_bill.invoice_no;
      end if;
      if v_alloc_amount > coalesce(v_bill.due_amount, 0.00) then
        raise exception 'Allocation % exceeds bill % due %', v_alloc_amount, v_bill.invoice_no, v_bill.due_amount;
      end if;

      insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
      values (v_parent_id, v_pay.id, v_bill_id, v_alloc_amount);

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

  -- Cashbook. Remittance cash-in is posted by the courier remittance flow.
  if v_source in ('customer_cash', 'bank') then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'sales_invoice',
      p_source_id => v_pay.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'tenant_payment_received',
        'transaction_type', 'payment_received',
        'label', 'Payment received',
        'payment_id', v_pay.id,
        'method', v_header_method,
        'instrument_count', v_line_count,
        'reference', v_reference
      )
    );
  elsif v_source = 'store_credit' then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => p_tenant_id,
      p_entity_type => 'customer',
      p_entity_id => p_billing_profile_id,
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
          and u.entity_id = p_billing_profile_id
          and u.type = 'credit'
          and coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
      ) into v_profit_already_credited;

      if not v_profit_already_credited then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => v_parent_id,
          p_operating_tenant_id => p_tenant_id,
          p_entity_type => 'customer',
          p_entity_id => p_billing_profile_id,
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
        p_entity_id => p_billing_profile_id,
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
$function$;

alter function public.post_customer_receipt_with_allocations(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint) owner to postgres;
revoke all on function public.post_customer_receipt_with_allocations(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint) from public, anon;
grant execute on function public.post_customer_receipt_with_allocations(bigint, bigint, date, text, text, text, jsonb, jsonb, bigint) to authenticated, service_role;

