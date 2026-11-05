-- Phase 8c: rename parent_tenant_id -> tenant_id on bills/money/profile/vendor tables.
ALTER TABLE public.bills RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.bill_lines RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.bill_settlements RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.books_exchange_rates RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.cashbook_point_pots RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.cashbook_points RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.invoice_brands RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.profiles RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.vendors RENAME COLUMN parent_tenant_id TO tenant_id;
ALTER TABLE public.sales_return_items RENAME COLUMN parent_tenant_id TO tenant_id;

DROP VIEW IF EXISTS public.global_invoice_items CASCADE;
DROP VIEW IF EXISTS public.global_return_items CASCADE;
DROP VIEW IF EXISTS public.v_kernel_bill_summaries CASCADE;

-- compat + kernel views

CREATE OR REPLACE VIEW "public"."global_invoice_items" WITH ("security_invoker"='false') AS
 SELECT "id",
    "tenant_id" AS "tenant_id",
    "tenant_id" AS "parent_tenant_id",
    "invoice_id",
    (("line_meta" -> 'stock_ref'::"text") ->> 'global_stock_id'::"text")::bigint AS "global_stock_id",
    "shipment_item_id",
    "product_id",
    "name_snapshot",
    "barcode_snapshot",
    "product_code_snapshot",
    "quantity",
    "sell_price_amount",
    "line_discount_amount",
    "line_total_amount",
    "return_quantity",
    "created_at",
    "updated_at",
    "assigned_child_tenant_id",
    "line_meta",
    "line_kind",
    "currency_code",
    "books_amount"
   FROM "public"."bill_lines";

CREATE OR REPLACE VIEW "public"."global_return_items" WITH ("security_invoker"='false') AS
 SELECT "id",
    "tenant_id" AS "parent_tenant_id",
    "tenant_id" AS "tenant_id",
    "invoice_id",
    "invoice_item_id",
    "global_stock_id",
    "quantity",
    "return_charge_amount",
    "note",
    "created_at",
    "updated_at"
   FROM "public"."sales_return_items";

CREATE OR REPLACE VIEW public.v_kernel_bill_summaries
WITH (security_invoker = true)
AS
SELECT
  b.id AS bill_id,
  b.tenant_id,
  b.issued_by_tenant_id,
  b.source_type,
  b.source_id,
  b.source_key,
  b.document_kind,
  b.invoice_type,
  b.invoice_no,
  b.invoice_date,
  CASE
    WHEN b.invoice_status = 'voided'::public.global_invoice_status THEN 'voided'
    WHEN b.invoice_status IN (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) THEN 'draft'
    WHEN b.invoice_status = 'issued'::public.global_invoice_status THEN 'issued'
    ELSE 'draft'
  END AS lifecycle_status,
  b.payment_status::text AS settlement_status,
  coalesce(b.txn_currency_code, b.currency_code, 'BDT') AS txn_currency_code,
  coalesce(b.txn_total_amount, b.total_amount) AS txn_total_amount,
  coalesce(b.currency_code, 'BDT') AS currency_code,
  b.total_amount,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_books,
  CASE
    WHEN b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
    THEN coalesce(oc.open_txn, oc.open_books, b.due_amount, 0)
    ELSE coalesce(b.due_amount, 0)
  END AS open_txn,
  b.due_date,
  b.from_profile_id,
  b.to_profile_id,
  b.profile_id,
  b.parent_bill_id
FROM public.bills b
LEFT JOIN LATERAL public._kernel_bill_open_components(coalesce(b.parent_bill_id, b.id)) oc ON true;;

-- RPCs (48 functions)

CREATE OR REPLACE FUNCTION "public"."_sync_dropship_courier_ap_bill_details"("p_bill_id" bigint, "p_order_id" bigint, "p_allow_line_sync" boolean DEFAULT true) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_bill public.bills;
  v_order public.shop_orders;
  v_courier public.courier_services;
  v_delivery numeric(12, 2);
  v_cod numeric(12, 2);
  v_charges_total numeric(12, 2) := 0;
  v_paper jsonb;
  v_note text;
  v_meta jsonb;
begin
  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then
    return;
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return;
  end if;

  select * into v_courier from public.courier_services where id = v_order.courier_service_id;

  v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
  v_cod := round(coalesce(v_order.cod_charge_amount, 0), 2);

  v_paper := public._build_dropship_courier_ap_paper(
    v_order,
    v_courier,
    v_delivery,
    v_cod,
    v_bill.total_amount
  );

  v_note := format(
    'Courier AP — %s — order %s%s',
    coalesce(v_courier.name, 'Courier'),
    v_order.order_no,
    case
      when nullif(trim(coalesce(v_order.courier_awb_number, '')), '') is not null
      then format(' (AWB %s)', trim(v_order.courier_awb_number))
      else ''
    end
  );

  v_meta := coalesce(v_bill.channel_meta, '{}'::jsonb) || jsonb_build_object(
    'shop_order_id', p_order_id,
    'order_no', v_order.order_no,
    'courier_service_id', v_order.courier_service_id,
    'courier_name', v_courier.name,
    'courier_awb_number', v_order.courier_awb_number,
    'tracking_url', v_order.tracking_url,
    'delivery_charge_amount', v_order.delivery_charge_amount,
    'cod_charge_amount', v_order.cod_charge_amount,
    'courier_cost_amount', v_order.courier_cost_amount,
    'recipient_name', v_order.recipient_name,
    'recipient_phone', v_order.recipient_phone,
    'shipping_address', v_order.shipping_address,
    'ap_paper', v_paper
  );

  update public.bills
  set
    note = v_note,
    recipient_name = v_order.recipient_name,
    recipient_phone = v_order.recipient_phone,
    recipient_address = v_order.shipping_address,
    shipping_charge = case when p_allow_line_sync then v_delivery else shipping_charge end,
    channel_meta = v_meta,
    updated_at = now()
  where id = p_bill_id;

  if not p_allow_line_sync then
    return;
  end if;

  delete from public.bill_lines
  where invoice_id = p_bill_id
    and line_kind = 'charge';

  if v_delivery > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.tenant_id, 'charge', 'Delivery charge', 1,
      v_delivery, 0, v_delivery, v_delivery,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'delivery')
    );
    v_charges_total := v_charges_total + v_delivery;
  end if;

  if v_cod > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.tenant_id, 'charge', 'COD / cash handling', 1,
      v_cod, 0, v_cod, v_cod,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'cod')
    );
    v_charges_total := v_charges_total + v_cod;
  end if;

  if v_charges_total = 0 and coalesce(v_bill.total_amount, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.tenant_id, 'charge',
      format('Courier charges — order %s', v_order.order_no), 1,
      v_bill.total_amount, 0, v_bill.total_amount, v_bill.total_amount,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'courier')
    );
    v_charges_total := v_bill.total_amount;
  end if;

  update public.bills
  set charges_amount = v_charges_total,
      updated_at = now()
  where id = p_bill_id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."_upsert_shipment_ap_bill"("p_tenant_id" bigint, "p_issued_by_tenant_id" bigint, "p_shipment_id" bigint, "p_shipment_name" "text", "p_ap_kind" "text", "p_profile_id" bigint, "p_amount" numeric) RETURNS bigint
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
begin
  if p_ap_kind not in ('vendor', 'cargo', 'local') then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  select * into v_bill
  from public.bills b
  where b.tenant_id = p_tenant_id
    and b.ap_shipment_id = p_shipment_id
    and b.ap_kind = p_ap_kind
    and b.invoice_type = 'ap'::public.global_invoice_type
  for update;

  if p_profile_id is null or coalesce(p_amount, 0) <= 0 then
    if v_bill.id is not null and coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_status = 'issued'::public.global_invoice_status then
      update public.bills
      set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
      where id = v_bill.id;
    end if;
    return null;
  end if;

  v_target := round(p_amount, 2);
  v_kind_label := initcap(p_ap_kind);

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(p_issued_by_tenant_id, 'ap'::public.global_invoice_type, current_date);
    insert into public.bills (
      tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, note, channel_meta
    ) values (
      p_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      'issued'::public.global_invoice_status, p_profile_id, 'billing_profile'::public.collection_source_type, 'due',
      v_target, v_target, v_target, 0,
      p_shipment_id, p_ap_kind,
      format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
      jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
    )
    returning id into v_bill.id;
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
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
    note = format('Shipment %s — %s AP', coalesce(p_shipment_name, p_shipment_id::text), v_kind_label),
    channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id),
    updated_at = now()
  where id = v_bill.id;

  return v_bill.id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."add_child_line_to_parent_shipment"("p_parent_shipment_id" bigint, "p_source_type" "text", "p_source_id" bigint) RETURNS "public"."global_shipment_items"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shipment public.global_shipments;
  v_row public.global_shipment_items;
  v_source_type text;
  v_child_tenant_id bigint;
  v_prod record;
  v_vendor_id bigint;
begin
  v_source_type := lower(trim(coalesce(p_source_type, '')));

  if v_source_type not in ('order_item', 'costing_item', 'shop_order_item') then
    raise exception 'invalid source_type: %', p_source_type;
  end if;

  select * into v_shipment
  from public.global_shipments
  where id = p_parent_shipment_id;

  if v_shipment.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_shipment.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_source_type = 'order_item' then
    -- Legacy Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.order_items oi
    inner join public.orders o on o.id = oi.order_id
    where oi.id = p_source_id
      and o.tenant_id = v_shipment.tenant_id
      and oi.shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.order_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      oi.name,
      greatest(coalesce(oi.ordered_quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'order_item',
      oi.id
    from public.order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.order_items
    set shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'costing_item' then
    -- Costing Pull
    select pcf.tenant_id into v_child_tenant_id
    from public.product_based_costing_items pci
    inner join public.product_based_costing_files pcf on pcf.id = pci.product_based_costing_file_id
    inner join public.tenants t on t.id = pcf.tenant_id
    where pci.id = p_source_id
      and t.parent_id = v_shipment.tenant_id
      and pci.assigned_shipment_id is null;

    if v_child_tenant_id is null then
      raise exception 'costing item not available for procurement';
    end if;

    select product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.product_based_costing_items where id = p_source_id);

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      pci.product_id,
      pci.name,
      greatest(coalesce(pci.quantity, 0), 0),
      pci.image_url,
      'costing'::public.global_shipment_item_add_method,
      coalesce(pci.price_gbp, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      pci.barcode,
      pci.product_code,
      v_child_tenant_id,
      'costing_item',
      pci.id
    from public.product_based_costing_items pci
    where pci.id = p_source_id
    returning * into v_row;

    update public.product_based_costing_items
    set assigned_shipment_id = p_parent_shipment_id
    where id = p_source_id;

  elsif v_source_type = 'shop_order_item' then
    -- Shop Order Pull
    select o.tenant_id into v_child_tenant_id
    from public.shop_order_items oi
    inner join public.shop_orders o on o.id = oi.order_id
    inner join public.tenants t on t.id = o.tenant_id
    where oi.id = p_source_id
      and t.parent_id = v_shipment.tenant_id
      and oi.procurement_pulled = false
      and o.status = 'placed';

    if v_child_tenant_id is null then
      raise exception 'shop order item not available for procurement';
    end if;

    select barcode, product_code, product_weight, package_weight into v_prod
    from public.products
    where id = (select product_id from public.shop_order_items where id = p_source_id);

    -- Try to match vendor by vendor_code of the shop
    select v.id into v_vendor_id
    from public.shop_order_items oi
    join public.shop_orders o on o.id = oi.order_id
    join public.shops s on s.id = o.shop_id
    join public.vendors v on v.code = s.vendor_code and v.tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
    where oi.id = p_source_id
    limit 1;

    insert into public.global_shipment_items (
      shipment_id,
      product_id,
      vendor_id,
      name,
      ordered_quantity,
      image_url,
      add_method,
      purchase_price,
      product_weight,
      package_weight,
      barcode,
      product_code,
      source_child_tenant_id,
      source_type,
      source_id
    )
    select
      p_parent_shipment_id,
      oi.product_id,
      v_vendor_id,
      oi.name,
      greatest(coalesce(oi.quantity, 0), 0),
      oi.image_url,
      'order'::public.global_shipment_item_add_method,
      coalesce(oi.final_price_amount, 0.00),
      coalesce(v_prod.product_weight, 0.00),
      coalesce(v_prod.package_weight, 0.00),
      v_prod.barcode,
      v_prod.product_code,
      v_child_tenant_id,
      'shop_order_item',
      oi.id
    from public.shop_order_items oi
    where oi.id = p_source_id
    returning * into v_row;

    update public.shop_order_items
    set procurement_pulled = true
    where id = p_source_id;

  end if;

  return v_row;
end;
$$;

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

  if v_stock.tenant_id <> v_invoice.tenant_id then
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
      tenant_id,
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
      v_invoice.tenant_id,
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
    tenant_id,
    invoice_id,
    invoice_item_id,
    global_stock_id,
    quantity,
    return_charge_amount,
    note
  )
  values (
    v_invoice.tenant_id,
    v_invoice.tenant_id,
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

  select * into v_payment from public.pays where id = p_payment_id for update;
  if not found then raise exception 'Payment not found.'; end if;
  if v_payment.tenant_id <> p_tenant_id then raise exception 'Payment tenant mismatch.'; end if;
  if v_payment.voided_at is not null then raise exception 'Payment is voided.'; end if;
  if v_payment.source not in ('customer_cash', 'bank') then
    raise exception 'Only customer cash/bank leftover can be allocated later.';
  end if;

  select * into v_invoice from public.bills where id = p_global_invoice_id for update;
  if not found then raise exception 'Invoice not found.'; end if;
  if v_invoice.tenant_id <> p_tenant_id then raise exception 'Invoice tenant mismatch.'; end if;
  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill % is not issued', v_invoice.invoice_no;
  end if;

  if coalesce(v_invoice.profile_id, 0) <> coalesce(v_payment.profile_id, 0) then
    raise exception 'Invoice and payment billing profile mismatch.';
  end if;

  if p_amount > v_payment.unallocated_amount then
    raise exception 'Allocation amount % exceeds payment unallocated amount %.', p_amount, v_payment.unallocated_amount;
  end if;

  if p_amount > v_invoice.due_amount then
    raise exception 'Allocation amount % exceeds invoice remaining due balance %.', p_amount, v_invoice.due_amount;
  end if;

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
  values (p_tenant_id, p_payment_id, p_global_invoice_id, p_amount)
  returning * into v_row;

  update public.pays
  set unallocated_amount = unallocated_amount - p_amount
  where id = p_payment_id;

  perform public.recompute_global_invoice_payment_status(p_global_invoice_id);

  if v_payment.profile_id is not null then
    perform public.record_ledger_transaction(
      p_tenant_id => p_tenant_id,
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

  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.tenant_id);
  v_operating_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);

  if coalesce(p_amount, 0.00) > 0.00 then
    insert into public.invoice_write_offs (
      tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    values (
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
      p_tenant_id => coalesce(v_invoice.tenant_id, v_invoice.tenant_id),
      p_operating_tenant_id => coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id, v_invoice.tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => coalesce(v_invoice.tenant_id, v_invoice.tenant_id),
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

CREATE OR REPLACE FUNCTION "public"."create_bill_adjustment"("p_parent_bill_id" bigint, "p_kind" "text", "p_amount" numeric, "p_reason" "text", "p_issue" boolean DEFAULT true, "p_refund_amount" numeric DEFAULT NULL::numeric, "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_lines" "jsonb" DEFAULT '[]'::"jsonb") RETURNS "public"."bills"
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

  v_no := public.next_document_number(
    v_parent.issued_by_tenant_id,
    case
      when v_kind = 'credit_note'::public.bill_document_kind then 'credit_note'
      else 'debit_note'
    end,
    public.map_global_invoice_type_to_sub_type(v_parent.invoice_type),
    (current_date::timestamp AT TIME ZONE public._document_number_tenant_timezone(v_parent.issued_by_tenant_id, 'UTC'))
  );

  v_status := case when coalesce(p_issue, true)
    then 'issued'::public.global_invoice_status
    else 'draft'::public.global_invoice_status
  end;

  insert into public.bills (
    tenant_id,
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
    v_parent.tenant_id,
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
        tenant_id,
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
        v_parent.tenant_id,
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
        and ca.tenant_id = v_parent.tenant_id
        and ca.entity_type = 'tenant'
        and ca.entity_id = v_parent.tenant_id
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
      v_parent.tenant_id,
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
      v_parent.tenant_id,
      v_pay.id,
      v_row.id,
      v_row.id,
      v_refund
    );

    perform public.recompute_global_invoice_payment_status(v_row.id);
    perform public.recompute_global_invoice_payment_status(v_parent.id);

    perform public.record_ledger_transaction(
      p_tenant_id => v_parent.tenant_id,
      p_operating_tenant_id => v_parent.issued_by_tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent.tenant_id,
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

CREATE OR REPLACE FUNCTION "public"."create_customer_account"("p_tenant_id" bigint, "p_group_name" "text", "p_admin_name" "text" DEFAULT NULL::"text", "p_admin_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_accent_color" "text" DEFAULT '#B45F34'::"text", "p_phone_country_code" "text" DEFAULT '+880'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_group public.customer_groups;
  v_profile public.profiles;
  v_profile_id bigint;
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
    from public.profiles pr
    left join public.customer_groups cg on cg.id = pr.customer_group_id
    where pr.profile_type = 'customer'::public.profile_party_type
      and pr.tenant_id = v_books_id
      and pr.phone_country_code = v_clean_code
      and pr.phone = v_clean_phone
      and pr.is_phone_unique
      and (cg.id is null or cg.deleted_at is null)
  ) then
    raise exception 'This phone is already used by another customer';
  end if;

  insert into public.customer_groups (
    tenant_id,
    name,
    accent_color,
    is_active
  ) values (
    v_books_id,
    v_clean_group_name,
    v_clean_color,
    true
  )
  returning * into v_group;

  select * into v_profile
  from public.profiles
  where customer_group_id = v_group.id
    and profile_type = 'customer'::public.profile_party_type
  order by id asc
  limit 1;

  if v_profile.id is null then
    insert into public.profiles (
      tenant_id,
      profile_type,
      subject_id,
      customer_group_id,
      operating_tenant_id,
      name,
      phone,
      phone_country_code,
      address,
      accent_color,
      is_active,
      created_at,
      updated_at
    ) values (
      v_books_id,
      'customer'::public.profile_party_type,
      v_group.id,
      v_group.id,
      v_books_id,
      v_clean_group_name,
      v_clean_phone,
      v_clean_code,
      nullif(trim(coalesce(p_address, '')), ''),
      v_clean_color,
      true,
      now(),
      now()
    )
    returning * into v_profile;

    update public.profiles
    set subject_id = v_profile.id
    where id = v_profile.id;
  else
    update public.profiles
    set
      name = v_clean_group_name,
      phone = v_clean_phone,
      phone_country_code = v_clean_code,
      tenant_id = v_books_id,
      operating_tenant_id = v_books_id,
      address = coalesce(nullif(trim(coalesce(p_address, '')), ''), address),
      updated_at = now()
    where id = v_profile.id
    returning * into v_profile;
  end if;

  insert into public.cashbook_accounts (
    tenant_id,
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    locked_balance,
    pending_balance
  ) values (
    v_books_id,
    'customer',
    v_profile.id,
    'BDT',
    0.0000,
    0.0000,
    0.0000
  )
  on conflict (tenant_id, entity_type, entity_id, currency_code) do nothing;

  return jsonb_build_object(
    'id', v_group.id,
    'customer_group_id', v_group.id,
    'profile_id', v_profile.id,
    'group_name', v_group.name,
    'admin_name', v_profile.name,
    'email', v_profile.email,
    'phone', concat_ws(' ', v_profile.phone_country_code, v_profile.phone),
    'address', v_profile.address,
    'accent_color', coalesce(v_group.accent_color, '#B45F34'),
    'is_active', v_group.is_active,
    'member_count', 0,
    'wallet_available_balance', 0,
    'created_at', v_group.created_at
  );
end;
$$;

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
    tenant_id, issued_by_tenant_id, invoice_no, invoice_type,
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
  v_parent_id := v_invoice.tenant_id;

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
        tenant_id,
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
      gs.tenant_id,
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
      tenant_id,
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

CREATE OR REPLACE FUNCTION "public"."create_shipment_draft"("p_tenant_id" bigint, "p_name" "text", "p_type" "public"."global_shipment_type", "p_vendor_id" bigint DEFAULT NULL::bigint, "p_cargo_company_id" bigint DEFAULT NULL::bigint) RETURNS "public"."global_shipments"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stock_parent bigint;
  v_vendor_id bigint;
  v_cargo_id bigint;
  v_row public.global_shipments%rowtype;
begin
  if p_tenant_id is null then
    raise exception 'p_tenant_id is required';
  end if;

  if nullif(trim(p_name), '') is null then
    raise exception 'name is required';
  end if;

  if p_type is null then
    raise exception 'type is required';
  end if;

  v_stock_parent := public.resolve_parent_tenant_id(p_tenant_id);

  if not public.user_can_manage_parent_tenant(v_stock_parent) then
    raise exception 'not allowed';
  end if;

  v_vendor_id := p_vendor_id;
  if v_vendor_id is null then
    v_vendor_id := public.ensure_default_vendor(v_stock_parent);
  else
    if not exists (
      select 1
      from public.vendors v
      where v.id = v_vendor_id
        and v.tenant_id = v_stock_parent
    ) then
      raise exception 'vendor % does not belong to parent tenant %', v_vendor_id, v_stock_parent;
    end if;
  end if;

  v_cargo_id := p_cargo_company_id;
  if v_cargo_id is null then
    v_cargo_id := public.ensure_default_cargo_company(v_stock_parent);
  else
    if not exists (
      select 1
      from public.cargo_companies c
      where c.id = v_cargo_id
        and c.tenant_id = v_stock_parent
    ) then
      raise exception 'cargo company % does not belong to parent tenant %', v_cargo_id, v_stock_parent;
    end if;
  end if;

  insert into public.global_shipments (
    tenant_id,
    name,
    type,
    vendor_id,
    cargo_company_id,
    status
  )
  values (
    v_stock_parent,
    trim(p_name),
    p_type,
    v_vendor_id,
    v_cargo_id,
    'draft'
  )
  returning * into v_row;

  perform public.ensure_global_shipment_default_section(v_row.id);

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_website" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    tenant_id,
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
$$;

CREATE OR REPLACE FUNCTION "public"."delete_cashbook_point_for_staff"("p_tenant_id" bigint, "p_point_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_id bigint;
  v_point public.cashbook_points;
BEGIN
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  IF NOT public.cashbook_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  SELECT * INTO v_point
  FROM public.cashbook_points cp
  WHERE cp.id = p_point_id
    AND cp.tenant_id = v_books_id;

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
      and ca.tenant_id = v_parent_tenant_id
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
      and cpp.tenant_id = v_parent_tenant_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null then
    return jsonb_build_object('success', false, 'error', 'No currency pot at this cash point');
  end if;

  perform public.record_ledger_transaction(
    p_tenant_id => v_parent_tenant_id,
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
    p_tenant_id => v_parent_tenant_id,
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

CREATE OR REPLACE FUNCTION "public"."ensure_default_vendor"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_vendor_id is not null then
    return v_vendor_id;
  end if;

  select id into v_vendor_id
  from public.vendors
  where tenant_id = p_tenant_id
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
    tenant_id,
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
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
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
$$;

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
  where b.tenant_id = v_invoice.tenant_id
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

  perform public._kernel_freeze_bill_txn_face(b.id)
  from public.bills b
  where b.tenant_id = v_invoice.tenant_id
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
    and b.invoice_status = 'issued'::public.global_invoice_status;

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

CREATE OR REPLACE FUNCTION "public"."finalize_dropship_return"("p_order_id" bigint, "p_items" "jsonb", "p_actual_return_charge" numeric DEFAULT 0.00, "p_deduct_from_middle_man" boolean DEFAULT true, "p_override_reason" "text" DEFAULT NULL::"text", "p_return_ref" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  v_profile_id bigint;
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
    where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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

  v_profile_id := v_order.profile_id;
  if v_profile_id is null and v_order.customer_group_id is not null then
    select id into v_profile_id
    from public.profiles
    where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
            tenant_id, tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.tenant_id, v_invoice.tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
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
    where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.cashbook_entries
  where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.cashbook_entries
    where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.cashbook_entries
  where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.cashbook_entries
  where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
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
  where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.cashbook_entries
  where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
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
  elsif v_profile_id is not null and v_has_billed and v_billed = 0
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
        p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
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
          p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_profile_id,
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
  elsif v_profile_id is not null
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
    where tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_profile_id,
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
  if v_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
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
      p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
        p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
        p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
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
     and v_profile_id is not null
     and not exists (
       select 1 from public.cashbook_entries
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_profile_id,
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
$$;

CREATE OR REPLACE FUNCTION "public"."find_customer_create_conflict"("p_tenant_id" bigint, "p_phone" "text" DEFAULT NULL::"text", "p_phone_country_code" "text" DEFAULT NULL::"text", "p_group_name" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_phone text;
  v_code text;
  v_name text;
  v_phone_group text;
  v_name_group text;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_phone := public.normalize_customer_national_phone(p_phone);
  v_code := nullif(trim(coalesce(p_phone_country_code, '')), '');
  if v_code is not null and v_code not like '+%' then
    v_code := '+' || v_code;
  end if;
  v_name := nullif(trim(coalesce(p_group_name, '')), '');

  if v_phone is not null and v_code is not null then
    select cg.name
    into v_phone_group
    from public.profiles pr
    left join public.customer_groups cg on cg.id = pr.customer_group_id
    where pr.profile_type = 'customer'::public.profile_party_type
      and pr.tenant_id = v_books_id
      and pr.phone_country_code = v_code
      and pr.phone = v_phone
      and pr.is_phone_unique
      and (cg.id is null or cg.deleted_at is null)
    order by pr.id
    limit 1;
  end if;

  if v_name is not null then
    select cg.name
    into v_name_group
    from public.customer_groups cg
    where cg.tenant_id = v_books_id
      and cg.deleted_at is null
      and lower(cg.name) = lower(v_name)
    order by cg.id
    limit 1;
  end if;

  return jsonb_build_object(
    'phone_group_name', v_phone_group,
    'name_group_name', v_name_group
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_bill_detail_bundle"("p_tenant_id" bigint, "p_bill_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_parent_id bigint;
  v_bill public.bills;
  v_bill_json jsonb;
  v_adjustments jsonb := '[]'::jsonb;
BEGIN
  IF p_tenant_id IS NULL OR p_bill_id IS NULL THEN
    RAISE EXCEPTION 'Tenant and bill are required.';
  END IF;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  SELECT * INTO v_bill FROM public.bills WHERE id = p_bill_id;
  IF v_bill.id IS NULL THEN
    RAISE EXCEPTION 'bill not found';
  END IF;

  IF NOT (v_bill.tenant_id = v_parent_id OR v_bill.issued_by_tenant_id = p_tenant_id) THEN
    RAISE EXCEPTION 'Invoice not found for this tenant.';
  END IF;

  v_bill_json := row_to_json(v_bill)::jsonb
    || jsonb_build_object(
      'profiles', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address,
          'color', p.accent_color
        )
        FROM public.profiles p
        WHERE p.id = v_bill.profile_id
      ),
      'from_profile', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        FROM public.profiles p
        WHERE p.id = v_bill.from_profile_id
      ),
      'to_profile', (
        SELECT jsonb_build_object(
          'id', p.id,
          'name', p.name,
          'email', p.email,
          'phone', p.phone,
          'address', p.address
        )
        FROM public.profiles p
        WHERE p.id = v_bill.to_profile_id
      )
    );

  IF v_bill.document_kind = 'standard'::public.bill_document_kind THEN
    SELECT coalesce(jsonb_agg(row_to_json(adj)), '[]'::jsonb)
    INTO v_adjustments
    FROM public.list_bill_adjustments(p_bill_id) AS adj;
  END IF;

  RETURN jsonb_build_object(
    'bill', v_bill_json,
    'payment_history', public.list_invoice_payment_history(p_tenant_id, p_bill_id),
    'net_balances', public.get_bill_net_balances(p_bill_id),
    'adjustments', v_adjustments
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_customer_account_summary_for_staff"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
  v_group_tenant_id bigint;
  v_profile_id bigint;
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
    coalesce(array_agg(pr.id order by
      case when pr.operating_tenant_id = v_group_tenant_id then 0 else 1 end,
      pr.id
    ), '{}'::bigint[]),
    (array_agg(pr.id order by
      case when pr.operating_tenant_id = v_group_tenant_id then 0 else 1 end,
      pr.id
    ))[1]
  into v_bp_ids, v_profile_id
  from public.profiles pr
  where pr.customer_group_id = p_customer_group_id
    and pr.profile_type = 'customer'::public.profile_party_type
    and pr.tenant_id = v_books_id;

  if v_profile_id is null then
    return jsonb_build_object(
      'success', true,
      'books_tenant_id', v_books_id,
      'profile_id', null,
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
    and wa.entity_id = v_profile_id
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
    where l.tenant_id = v_books_id
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
    'profile_id', v_profile_id,
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
$$;

CREATE OR REPLACE FUNCTION "public"."get_tenant_month_snapshot_report"("p_tenant_id" bigint, "p_month" "date") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  v_tenant_cash numeric(18,4) := 0;
  v_ledger_cash numeric(18,4);
  v_courier_holding numeric(18,4) := 0;
  v_cod_unremitted numeric(18,4) := 0;
  v_ap_payable numeric(18,4) := 0;
  v_customer_store_credit numeric(18,4) := 0;
  v_merchant_leftover numeric(18,4) := 0;
  v_net_buffer numeric(18,4) := 0;
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
    WHERE si.tenant_id = v_books_id
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
    WHERE si.tenant_id = v_books_id
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
  WHERE si.tenant_id = v_books_id
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.invoice_type <> 'ap'::public.global_invoice_type
    AND si.profile_id IS NOT NULL
    AND si.due_amount > 0;

  SELECT round(
    coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN pending_balance ELSE 0 END), 0)
    + coalesce(sum(CASE WHEN entity_type IN ('customer', 'middleman') THEN available_balance ELSE 0 END), 0),
    2
  )
  INTO v_merchant_payable
  FROM public.cashbook_accounts
  WHERE tenant_id = v_books_id;

  SELECT coalesce(w.available_balance, 0.0000)
  INTO v_tenant_cash
  FROM public.cashbook_accounts w
  WHERE w.tenant_id = v_books_id
    AND w.entity_type = 'tenant'
    AND w.entity_id = v_books_id
    AND w.currency_code = 'BDT'
  LIMIT 1;

  SELECT l.balance_after
  INTO v_ledger_cash
  FROM public.cashbook_entries l
  WHERE l.tenant_id = v_books_id
    AND l.entity_type = 'tenant'
    AND l.entity_id = v_books_id
    AND coalesce(l.currency_code, 'BDT') = 'BDT'
  ORDER BY l.id DESC
  LIMIT 1;

  IF coalesce(v_tenant_cash, 0) = 0 AND coalesce(v_ledger_cash, 0) <> 0 THEN
    v_tenant_cash := v_ledger_cash;
  END IF;

  SELECT round(coalesce(sum(pending_balance + available_balance), 0), 2)
  INTO v_courier_holding
  FROM public.cashbook_accounts
  WHERE tenant_id = v_books_id
    AND entity_type = 'courier';

  WITH delivered_orders AS (
    SELECT
      coalesce(so.cod_collect_amount, 0)::numeric(12,2) AS cod_collect_amount,
      round(coalesce((
        SELECT l.amount
        FROM public.cashbook_entries l
        WHERE l.tenant_id = v_books_id
          AND l.entity_type = 'tenant'
          AND l.source_type = 'shop_order'
          AND l.source_id = so.id::text
          AND coalesce(l.metadata->>'purpose', '') = 'tenant_remittance_received'
        LIMIT 1
      ), 0), 2) AS remitted_amount
    FROM public.shop_orders so
    WHERE public.resolve_parent_tenant_id(so.tenant_id) = v_books_id
      AND so.status IN ('delivered'::public.shop_order_status, 'payment_received'::public.shop_order_status)
      AND so.shop_type_snapshot = 'dropship'::public.shop_type_enum
      AND coalesce(so.cod_collect_amount, 0) > 0
  )
  SELECT round(coalesce(sum(greatest(cod_collect_amount - remitted_amount, 0)), 0), 2)
  INTO v_cod_unremitted
  FROM delivered_orders;

  SELECT round(coalesce(sum(si.due_amount), 0), 2)
  INTO v_ap_payable
  FROM public.bills si
  WHERE si.tenant_id = v_books_id
    AND si.invoice_type = 'ap'::public.global_invoice_type
    AND si.invoice_status = 'issued'::public.global_invoice_status
    AND si.due_amount > 0;

  SELECT
    round(coalesce(sum(CASE WHEN entity_type = 'customer' THEN available_balance ELSE 0 END), 0), 2),
    round(coalesce(sum(CASE WHEN entity_type = 'middleman' THEN pending_balance + available_balance ELSE 0 END), 0), 2)
  INTO v_customer_store_credit, v_merchant_leftover
  FROM public.cashbook_accounts
  WHERE tenant_id = v_books_id;

  v_net_buffer := round(
    coalesce(v_tenant_cash, 0)
    + coalesce(v_courier_holding, 0)
    + coalesce(v_ar_outstanding, 0)
    + coalesce(v_cod_unremitted, 0)
    - coalesce(v_ap_payable, 0)
    - coalesce(v_merchant_leftover, 0)
    - coalesce(v_customer_store_credit, 0),
    2
  );

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
    ),
    'position', jsonb_build_object(
      'tenant_cash', round(coalesce(v_tenant_cash, 0), 2),
      'courier_holding', coalesce(v_courier_holding, 0),
      'ar_outstanding', v_ar_outstanding,
      'cod_unremitted', coalesce(v_cod_unremitted, 0),
      'ap_payable', coalesce(v_ap_payable, 0),
      'merchant_payable', coalesce(v_merchant_leftover, 0),
      'customer_store_credit', coalesce(v_customer_store_credit, 0),
      'net_buffer', v_net_buffer
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_cashbook_detail_for_staff"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS "jsonb"
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

  IF NOT public.cashbook_staff_can_view(p_tenant_id) THEN
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
    FROM public.vendors v WHERE v.id = p_entity_id AND v.tenant_id = v_books_id;
    IF v_name IS NULL THEN RETURN jsonb_build_object('success', false, 'error', 'entity not found'); END IF;

  ELSIF p_entity_type = 'cargo_company' THEN
    SELECT c.name, c.code, nullif(trim(concat_ws(' • ', c.phone, c.email)), '')
    INTO v_name, v_code, v_caption
    FROM public.cargo_companies c WHERE c.id = p_entity_id AND c.tenant_id = v_books_id;
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

  v_account := public.get_cashbook_account_balances(v_books_id, p_entity_type, v_entity_id, p_currency_code);

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
      'can_record_manual', public.cashbook_staff_can_edit(p_tenant_id),
      'can_reverse', public.cashbook_staff_can_edit(p_tenant_id)
    )
  );
END;
$$;

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

  select gs.tenant_id into v_parent
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
  where b.tenant_id = v_parent
    and b.ap_shipment_id = p_shipment_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.invoice_status = 'draft'::public.global_invoice_status
    and coalesce(b.total_amount, 0) > 0;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

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

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);
  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);

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
  v_mov_no := public.next_stock_movement_number(v_parent_id, 'stock_movement');

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

CREATE OR REPLACE FUNCTION "public"."list_customer_accounts"("p_tenant_id" bigint, "p_search" "text" DEFAULT NULL::"text") RETURNS TABLE("id" bigint, "customer_group_id" bigint, "profile_id" bigint, "group_name" "text", "admin_name" "text", "email" "text", "phone" "text", "address" "text", "accent_color" "text", "is_active" boolean, "member_count" bigint, "wallet_available_balance" numeric, "created_at" timestamp with time zone)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select
    cg.id,
    cg.id as customer_group_id,
    bp.id as profile_id,
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
  left join public.profiles bp
    on bp.customer_group_id = cg.id
   and bp.tenant_id = v_books_id
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
  where cg.tenant_id = v_books_id
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
$$;

CREATE OR REPLACE FUNCTION "public"."list_customer_accounts_paginated"("p_tenant_id" bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 20, "p_search" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  left join public.profiles bp
    on bp.customer_group_id = cg.id
   and bp.tenant_id = v_books_id
  where cg.tenant_id = v_books_id
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
        'profile_id', bp.id,
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
    left join public.profiles bp
      on bp.customer_group_id = cg.id
     and bp.tenant_id = v_books_id
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
    where cg.tenant_id = v_books_id
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
$$;

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

CREATE OR REPLACE FUNCTION "public"."list_vendors_for_tenant"("p_tenant_id" bigint) RETURNS SETOF "public"."vendors"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    return query
    select v.*
    from public.vendors v
    where v.tenant_id is null
    order by v.id asc;

    return;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_parent_tenant_id(p_tenant_id);

  return query
  select v.*
  from public.vendors v
  where v.tenant_id = v_books_id
  order by v.id asc;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."post_ap_payout_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_paid_on" "date", "p_cashbook_point_id" bigint, "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint, "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "public"."pays"
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
  v_bill_ids bigint[] := '{}';
begin
  if p_tenant_id is null then
    raise exception 'Tenant is required';
  end if;
  if p_profile_id is null then
    raise exception 'Profile is required';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_base_currency := public.resolve_tenant_base_currency_code(p_tenant_id);

  v_pay := public._kernel_claim_pay_idempotency(v_parent_id, p_idempotency_key);
  if v_pay.id is not null then
    return v_pay;
  end if;

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
    where pr.id = p_profile_id and pr.tenant_id = v_parent_id
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
      and ca.tenant_id = v_parent_id
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
      and cpp.tenant_id = v_parent_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_parent_id
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

  if coalesce(jsonb_typeof(p_allocations), 'null') = 'array' then
    select coalesce(array_agg(distinct x.bid order by x.bid), '{}'::bigint[])
    into v_bill_ids
    from (
      select coalesce(
        nullif(v_alloc_elem.value ->> 'bill_id', '')::bigint,
        nullif(v_alloc_elem.value ->> 'invoice_id', '')::bigint
      ) as bid
      from jsonb_array_elements(p_allocations) as v_alloc_elem(value)
    ) x
    where x.bid is not null;
  end if;

  perform public._kernel_lock_bills(v_bill_ids);

  for v_sid in
    select distinct b.ap_shipment_id
    from public.bills b
    where b.id = any(v_bill_ids)
      and b.ap_shipment_id is not null
    order by b.ap_shipment_id asc
  loop
    perform public._kernel_advisory_shipment_money_lock(v_sid);
  end loop;

  perform public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

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
      if v_bill.tenant_id <> v_parent_id then
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
    p_tenant_id => v_parent_id,
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

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_id, p_idempotency_key);
end;
$$;

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
    where pr.id = p_profile_id and pr.tenant_id = v_parent_id
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
      if v_bill.tenant_id <> v_parent_id then
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
      p_tenant_id => v_parent_id,
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
      p_tenant_id => v_parent_id,
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
        where u.tenant_id = v_parent_id
          and u.source_type = 'shop_order'
          and u.source_id = p_shop_order_id::text
          and u.entity_type in ('middleman', 'customer')
          and u.entity_id = p_profile_id
          and u.type = 'credit'
          and coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
      ) into v_profit_already_credited;

      if not v_profit_already_credited then
        perform public.record_ledger_transaction(
          p_tenant_id => v_parent_id,
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
        p_tenant_id => v_parent_id,
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

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);
  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);

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
    v_mov_no := public.next_stock_movement_number(v_parent_id, 'stock_movement');

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

  perform public._kernel_freeze_bill_txn_face(p_invoice_id);
  perform public.recompute_global_invoice_payment_status(p_invoice_id);

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

CREATE OR REPLACE FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint, "p_delivery_override" numeric DEFAULT NULL::numeric, "p_cod_override" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
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
  v_delivery_merchant numeric(12, 2);
  v_cod_merchant numeric(12, 2);
  v_delivery_payer text;
  v_cod_payer text;
  v_delivery_for_ap numeric(12, 2);
  v_cod_for_ap numeric(12, 2);
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
  where b.tenant_id = v_parent_tenant_id
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

  v_delivery_merchant := coalesce(v_charges.delivery, 0);
  v_cod_merchant := coalesce(v_charges.cod, 0);

  if p_delivery_override is not null then
    select coalesce(cl.payer::text, 'recipient')
    into v_delivery_payer
    from public.dropship_order_settlements s
    inner join public.dropship_settlement_charge_lines cl
      on cl.settlement_id = s.id and cl.charge_type = 'delivery'::public.dropship_settlement_charge_type
    where s.shop_order_id = p_order_id
    limit 1;

    if not found then
      v_delivery_payer := case
        when coalesce(v_order.deduct_delivery_from_margin, false) then 'merchant'
        else 'recipient'
      end;
    end if;

    if v_delivery_payer = 'merchant' then
      v_delivery_merchant := round(coalesce(p_delivery_override, 0), 2);
    end if;
  end if;

  if p_cod_override is not null then
    select coalesce(cl.payer::text, 'recipient')
    into v_cod_payer
    from public.dropship_order_settlements s
    inner join public.dropship_settlement_charge_lines cl
      on cl.settlement_id = s.id and cl.charge_type = 'cod'::public.dropship_settlement_charge_type
    where s.shop_order_id = p_order_id
    limit 1;

    if not found then
      v_cod_payer := case
        when coalesce(v_order.deduct_cod_from_margin, false) then 'merchant'
        else 'recipient'
      end;
    end if;

    if v_cod_payer = 'merchant' then
      v_cod_merchant := round(coalesce(p_cod_override, 0), 2);
    end if;
  end if;

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
    + coalesce(v_delivery_merchant, 0)
    + coalesce(v_charges.print, 0)
    + coalesce(v_charges.packing, 0)
    + coalesce(v_cod_merchant, 0),
    2
  );

  v_diff := round(v_wanted_ar - v_net_ar, 2);

  if abs(v_diff) >= 0.01 then
    v_parts := array[]::text[];
    if coalesce(v_delivery_merchant, 0) is distinct from coalesce(v_ar.shipping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Delivery %s→%s', coalesce(v_ar.shipping_charge, 0), coalesce(v_delivery_merchant, 0))
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
    if coalesce(v_cod_merchant, 0) is distinct from coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0) then
      v_parts := array_append(
        v_parts,
        format(
          'Courier COD fee %s→%s',
          coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
          coalesce(v_cod_merchant, 0)
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
    v_delivery_for_ap := coalesce(p_delivery_override, v_order.delivery_charge_amount, 0);
    v_cod_for_ap := coalesce(p_cod_override, v_order.cod_charge_amount, 0);
    v_wanted_ap := round(coalesce(v_delivery_for_ap, 0) + coalesce(v_cod_for_ap, 0), 2);

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
      if coalesce(v_delivery_for_ap, 0) is distinct from coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Delivery %s→%s',
            coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0),
            coalesce(v_delivery_for_ap, 0)
          )
        );
      end if;
      if coalesce(v_cod_for_ap, 0) is distinct from coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Courier COD fee %s→%s',
            coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0),
            coalesce(v_cod_for_ap, 0)
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
  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.tenant_id);
  v_parent_id := coalesce(v_invoice.tenant_id, v_invoice.issued_by_tenant_id);

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
      tenant_id,
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
        pr.tenant_id = p_issued_by_tenant_id
        or pr.tenant_id = public.resolve_parent_tenant_id(p_issued_by_tenant_id)
        or exists (
          select 1
          from public.tenants t
          where t.id = p_issued_by_tenant_id
            and t.parent_id = pr.tenant_id
        )
      )
  );
$$;

CREATE OR REPLACE FUNCTION "public"."purge_archived_shipment"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
begin
  select * into v_ship
  from public.global_shipments
  where id = p_id
  for update;

  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if v_ship.is_archived is not true then
    raise exception 'shipment must be archived before it can be permanently deleted';
  end if;

  delete from public.shop_order_item_stock_picks sp
  where sp.shipment_id = p_id
     or sp.shipment_item_id in (
       select id from public.global_shipment_items where shipment_id = p_id
     )
     or sp.global_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     )
     or sp.held_stock_id in (
       select gs.id
       from public.global_stocks gs
       inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
       where gsi.shipment_id = p_id
     );

  update public.bill_lines bl
  set
    line_meta = bl.line_meta - 'stock_ref',
    shipment_item_id = null,
    updated_at = now()
  where bl.shipment_item_id in (
    select id from public.global_shipment_items where shipment_id = p_id
  )
  or nullif(bl.line_meta->'stock_ref'->>'global_stock_id', '')::bigint in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  update public.sales_return_items sri
  set
    global_stock_id = null,
    updated_at = now()
  where sri.global_stock_id in (
    select gs.id
    from public.global_stocks gs
    inner join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    where gsi.shipment_id = p_id
  );

  delete from public.global_shipments where id = p_id;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."record_ledger_transaction"("p_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_type" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_exchange_rate" numeric DEFAULT 1.000000, "p_source_type" "text" DEFAULT 'adjustment'::"text", "p_source_id" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_target_bucket" "text" DEFAULT 'available'::"text", "p_allow_overdraft" boolean DEFAULT false, "p_cashbook_point_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
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
  v_pot_id bigint;
  v_pot_amt numeric(12, 2);
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
  IF p_entity_type = 'tenant' AND v_entity_id IS DISTINCT FROM p_tenant_id THEN
    v_entity_id := p_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    p_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
  DO UPDATE SET updated_at = now()
  RETURNING id, available_balance, pending_balance, locked_balance
  INTO v_account_id, v_avail, v_pend, v_lock;

  IF p_cashbook_point_id IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.cashbook_points cp
      WHERE cp.id = p_cashbook_point_id
        AND cp.tenant_id = p_tenant_id
        AND cp.cashbook_account_id = v_account_id
        AND cp.is_active = true
    ) INTO v_point_ok;
    IF NOT coalesce(v_point_ok, false) THEN
      RAISE EXCEPTION 'Invalid cashbook point for this account.';
    END IF;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      p_tenant_id,
      p_cashbook_point_id,
      coalesce(p_currency_code, 'BDT')
    );
    PERFORM 1
    FROM public.cashbook_point_pots cpp
    WHERE cpp.id = v_pot_id
    FOR UPDATE;

    IF p_type = 'debit' THEN
      SELECT cpp.amount
      INTO v_pot_amt
      FROM public.cashbook_point_pots cpp
      WHERE cpp.id = v_pot_id;

      IF coalesce(v_pot_amt, 0) < p_amount THEN
        IF NOT coalesce(p_allow_overdraft, false) THEN
          RAISE EXCEPTION 'Insufficient cash in till (available: %, requested: %).',
            coalesce(v_pot_amt, 0), p_amount;
        END IF;
        v_pot_id := NULL;
      END IF;
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
      IF v_avail < p_amount AND NOT coalesce(p_allow_overdraft, false) THEN
        RAISE EXCEPTION 'Insufficient available balance (available: %, requested debit: %).',
          v_avail, p_amount;
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
    tenant_id = p_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  v_base_amount := p_amount * coalesce(p_exchange_rate, 1.000000);

  INSERT INTO public.cashbook_entries (
    tenant_id,
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
    cashbook_point_id,
    cashbook_point_pot_id
  )
  VALUES (
    p_tenant_id,
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
    p_cashbook_point_id,
    v_pot_id
  )
  RETURNING id INTO v_ledger_id;

  SELECT jsonb_build_object(
    'id', id,
    'parent_tenant_id', parent_tenant_id,
    'operating_tenant_id', operating_tenant_id,
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
    'cashbook_point_id', cashbook_point_id,
    'created_at', created_at
  ) INTO v_ledger_entry
  FROM public.cashbook_entries
  WHERE id = v_ledger_id;

  RETURN v_ledger_entry;
END;
$$;

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

  insert into public.pay_allocations (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.tenant_id, v_payment_id, p_global_invoice_id, p_amount);

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

CREATE OR REPLACE FUNCTION "public"."resolve_dropship_courier_ap_bill_id"("p_order_id" bigint, "p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select b.id
  from public.bills b
  where b.tenant_id = p_tenant_id
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
$$;

CREATE OR REPLACE FUNCTION "public"."settle_dropship_courier_ap_via_cod_retention"("p_ap_bill_id" bigint, "p_amount" numeric, "p_order_id" bigint, "p_remittance_ref" "text", "p_receipt_payment_id" bigint DEFAULT NULL::bigint) RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ap public.bills;
  v_bal jsonb;
  v_family_due numeric(12, 2);
  v_remaining numeric(12, 2);
  v_chunk numeric(12, 2);
  v_total_settled numeric(12, 2) := 0;
  v_bill record;
  v_operating_tenant_id bigint;
  v_note text;
begin
  if p_ap_bill_id is null then
    return 0;
  end if;

  select * into v_ap from public.bills where id = p_ap_bill_id for update;
  if v_ap.id is null then
    raise exception 'courier AP bill not found';
  end if;

  if v_ap.invoice_type <> 'ap'::public.global_invoice_type then
    raise exception 'bill is not an AP bill';
  end if;

  if v_ap.invoice_status <> 'issued'::public.global_invoice_status then
    return 0;
  end if;

  v_bal := public.get_bill_net_balances(p_ap_bill_id);
  v_family_due := greatest(coalesce((v_bal->>'due_amount')::numeric, 0), 0);
  v_remaining := least(
    round(greatest(coalesce(p_amount, 0), 0), 2),
    v_family_due
  );

  if v_remaining <= 0 then
    return 0;
  end if;

  v_note := format(
    'Courier COD retention — order #%s — remittance %s',
    p_order_id,
    coalesce(nullif(trim(p_remittance_ref), ''), '—')
  );

  for v_bill in
    select
      b.id,
      b.due_amount,
      b.issued_by_tenant_id,
      b.tenant_id
    from public.bills b
    where (
        b.id = p_ap_bill_id
        or b.parent_bill_id = p_ap_bill_id
      )
      and b.invoice_status = 'issued'::public.global_invoice_status
      and greatest(coalesce(b.due_amount, 0), 0) > 0
    order by
      case when b.id = p_ap_bill_id then 0 else 1 end,
      b.id
    for update
  loop
    v_chunk := least(v_remaining, greatest(coalesce(v_bill.due_amount, 0), 0));
    if v_chunk <= 0 then
      continue;
    end if;

    v_operating_tenant_id := coalesce(v_bill.issued_by_tenant_id, v_bill.tenant_id);

    insert into public.invoice_write_offs (
      tenant_id,
      invoice_id,
      payment_id,
      amount,
      reason,
      note,
      approved_by
    )
    values (
      v_bill.tenant_id,
      v_bill.id,
      p_receipt_payment_id,
      v_chunk,
      'dispute_settlement',
      v_note,
      auth.uid()
    );

    perform public.recompute_global_invoice_payment_status(v_bill.id);

    v_total_settled := v_total_settled + v_chunk;
    v_remaining := v_remaining - v_chunk;

    if v_remaining <= 0 then
      exit;
    end if;
  end loop;

  perform public.recompute_global_invoice_payment_status(p_ap_bill_id);

  return round(v_total_settled, 2);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."stamp_bill_kernel_fields"("p_bill_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
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
  where p.tenant_id = v_bill.tenant_id
    and p.profile_type = 'tenant'::public.profile_party_type
    and p.subject_id = v_bill.issued_by_tenant_id
  limit 1;

  if v_tenant_profile_id is null then
    select p.id into v_tenant_profile_id
    from public.profiles p
    where p.tenant_id = v_bill.tenant_id
      and p.profile_type = 'tenant'::public.profile_party_type
      and p.subject_id = v_bill.tenant_id
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

  -- Self-bills (counterparty is the tenant profile): keep one side, leave the other null.
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

CREATE OR REPLACE FUNCTION "public"."sync_lookup_tenant_id"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.tenant_id
    into v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    end if;
  end if;

  return new;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."sync_product_tenant_from_vendor"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
declare
  v_parent_tenant_id bigint;
begin
  if new.vendor_id is not null then
    select v.tenant_id
    into v_parent_tenant_id
    from public.vendors v
    where v.id = new.vendor_id;

    if v_parent_tenant_id is not null then
      new.parent_tenant_id := public.resolve_parent_tenant_id(v_parent_tenant_id);
    end if;
  end if;

  return new;
end;
$$;

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
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.tenant_id, 'charge', 'Delivery', 1,
      v_inv.shipping_charge, 0, v_inv.shipping_charge, v_inv.shipping_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'delivery')
    );
    v_total := v_total + v_inv.shipping_charge;
  end if;

  if coalesce(v_inv.print_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.tenant_id, 'charge', 'Print', 1,
      v_inv.print_charge, 0, v_inv.print_charge, v_inv.print_charge,
      coalesce(v_inv.currency_code, 'BDT'), jsonb_build_object('charge_type', 'print')
    );
    v_total := v_total + v_inv.print_charge;
  end if;

  if coalesce(v_inv.wrapping_charge, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_invoice_id, v_inv.tenant_id, 'charge', 'Packing', 1,
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

  v_parent := v_ship.tenant_id;
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
    where pr.tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.tenant_id = v_parent
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
    where tenant_id = v_parent
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
  where tenant_id = v_parent
    and ap_shipment_id = p_shipment_id
    and invoice_type = 'ap'::public.global_invoice_type
    and document_kind = 'standard'::public.bill_document_kind
    and ap_kind in ('vendor', 'cargo', 'local')
    and invoice_status = 'issued'::public.global_invoice_status
    and coalesce(paid_amount, 0) = 0;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;

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

  v_parent_id := v_invoice.tenant_id;

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
          gs.tenant_id,
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
          tenant_id,
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
      'tenant_id', v_invoice.tenant_id,
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
  where p.tenant_id = v_parent_tenant_id
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
  where b.tenant_id = v_parent_tenant_id
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
    v_invoice_no := 'AP-CR-' || v_order.order_no;
    insert into public.bills (
      tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind,
      recipient_name, recipient_phone, recipient_address
    ) values (
      v_parent_tenant_id, v_order.tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, v_profile_id, 'profile'::public.collection_source_type, 'due',
      v_amount, v_amount, v_amount, 0,
      'dropship_courier', p_order_id::text, 'courier', 'BDT',
      format('Courier AP — %s — order %s', v_courier.name, v_order.order_no),
      '{}'::jsonb,
      'standard'::public.bill_document_kind,
      v_order.recipient_name, v_order.recipient_phone, v_order.shipping_address
    )
    returning * into v_bill;
    perform public._sync_dropship_courier_ap_bill_details(v_bill.id, p_order_id, true);
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
      recipient_name = v_order.recipient_name,
      recipient_phone = v_order.recipient_phone,
      recipient_address = v_order.shipping_address,
      updated_at = now()
    where id = v_bill.id;
    perform public._sync_dropship_courier_ap_bill_details(v_bill.id, p_order_id, true);
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'revived', true, 'amount', v_amount);
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status then
    perform public._sync_dropship_courier_ap_bill_details(
      v_bill.id,
      p_order_id,
      coalesce(v_bill.paid_amount, 0) = 0
    );
    if coalesce(v_bill.paid_amount, 0) = 0
       and v_bill.invoice_no not like 'AP-CR-%' then
      update public.bills b
      set invoice_no = 'AP-CR-' || v_order.order_no,
          updated_at = now()
      where b.id = v_bill.id
        and not exists (
          select 1
          from public.bills b2
          where b2.tenant_id = v_parent_tenant_id
            and b2.invoice_no = 'AP-CR-' || v_order.order_no
            and b2.id <> b.id
        );
    end if;
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
    recipient_name = v_order.recipient_name,
    recipient_phone = v_order.recipient_phone,
    recipient_address = v_order.shipping_address,
    updated_at = now()
  where id = v_bill.id;

  perform public._sync_dropship_courier_ap_bill_details(v_bill.id, p_order_id, true);
  perform public.stamp_bill_kernel_fields(v_bill.id);
  return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'amount', v_amount);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."upsert_profile_for_party"("p_tenant_id" bigint, "p_profile_type" "public"."profile_party_type", "p_subject_id" bigint, "p_name" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_phone_country_code" "text" DEFAULT '+880'::"text", "p_address" "text" DEFAULT NULL::"text", "p_is_phone_unique" boolean DEFAULT true, "p_accent_color" "text" DEFAULT NULL::"text", "p_is_active" boolean DEFAULT true, "p_deleted_at" timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_profile_id bigint;
  v_phone_unique boolean;
begin
  if p_tenant_id is null or p_subject_id is null then
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
    tenant_id,
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
    p_tenant_id,
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
  on conflict (tenant_id, profile_type, subject_id) do update set
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

-- RLS
DROP POLICY IF EXISTS "books_exchange_rates_authenticated_policy" ON public.books_exchange_rates;
DROP POLICY IF EXISTS "cashbook_point_pots_authenticated_policy" ON public.cashbook_point_pots;
DROP POLICY IF EXISTS "cashbook_points_authenticated_policy" ON public.cashbook_points;
DROP POLICY IF EXISTS "global_invoice_items_all" ON public.bill_lines;
DROP POLICY IF EXISTS "global_invoices_select" ON public.bills;
DROP POLICY IF EXISTS "global_invoices_write" ON public.bills;
DROP POLICY IF EXISTS "invoice_brands_delete" ON public.invoice_brands;
DROP POLICY IF EXISTS "invoice_brands_insert" ON public.invoice_brands;
DROP POLICY IF EXISTS "invoice_brands_select" ON public.invoice_brands;
DROP POLICY IF EXISTS "invoice_brands_update" ON public.invoice_brands;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;
DROP POLICY IF EXISTS "profiles_write" ON public.profiles;
DROP POLICY IF EXISTS "vendors_delete" ON public.vendors;
DROP POLICY IF EXISTS "vendors_insert" ON public.vendors;
DROP POLICY IF EXISTS "vendors_select" ON public.vendors;
DROP POLICY IF EXISTS "vendors_update" ON public.vendors;

CREATE POLICY "books_exchange_rates_authenticated_policy" ON "public"."books_exchange_rates" TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "cashbook_point_pots_authenticated_policy" ON "public"."cashbook_point_pots" TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "cashbook_points_authenticated_policy" ON "public"."cashbook_points" TO "authenticated" USING (true) WITH CHECK (true);

CREATE POLICY "global_invoice_items_all" ON "public"."bill_lines" TO "authenticated" USING ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "bill_lines"."invoice_id")))) WITH CHECK ((EXISTS ( SELECT 1
   FROM "public"."bills" "gi"
  WHERE ("gi"."id" = "bill_lines"."invoice_id"))));

CREATE POLICY "global_invoices_select" ON "public"."bills" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("issued_by_tenant_id") OR "public"."user_can_manage_parent_tenant"("tenant_id") OR (("invoice_type" = 'ap'::"public"."global_invoice_type") AND ("public"."membership_has_module_action"("tenant_id", 'global_invoice'::"text", 'view'::"text") OR (EXISTS ( SELECT 1
   FROM ("public"."tenants" "ct"
     JOIN "public"."memberships" "m" ON (("m"."tenant_id" = "ct"."id")))
  WHERE (("ct"."parent_id" = "bills"."tenant_id") AND "public"."membership_email_matches_current_user"("m"."email") AND ("m"."is_active" = true) AND "public"."membership_has_module_action"("ct"."id", 'global_invoice'::"text", 'view'::"text"))))))));

CREATE POLICY "global_invoices_write" ON "public"."bills" TO "authenticated" USING (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("issued_by_tenant_id", 'global_invoice'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "invoice_brands_delete" ON "public"."invoice_brands" FOR DELETE TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "invoice_brands_insert" ON "public"."invoice_brands" FOR INSERT TO "authenticated" WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "invoice_brands_select" ON "public"."invoice_brands" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "invoice_brands_update" ON "public"."invoice_brands" FOR UPDATE TO "authenticated" USING (("public"."membership_has_module_action"("tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id"))) WITH CHECK (("public"."membership_has_module_action"("tenant_id", 'invoice_brand'::"text", 'edit'::"text") OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "profiles_select" ON "public"."profiles" FOR SELECT TO "authenticated" USING (("public"."has_active_tenant_membership"("tenant_id") OR "public"."user_can_manage_parent_tenant"("tenant_id") OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("m"."tenant_id" = "profiles"."tenant_id") AND ("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND "m"."is_active")))));

CREATE POLICY "profiles_write" ON "public"."profiles" TO "authenticated" USING ("public"."membership_has_module_action"("tenant_id", 'billing_profile'::"text", 'edit'::"text")) WITH CHECK ("public"."membership_has_module_action"("tenant_id", 'billing_profile'::"text", 'edit'::"text"));

CREATE POLICY "vendors_delete" ON "public"."vendors" FOR DELETE TO "authenticated" USING ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (("tenant_id" IS NOT NULL) AND "public"."is_network_owner"("tenant_id")) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id"))))));

CREATE POLICY "vendors_insert" ON "public"."vendors" FOR INSERT TO "authenticated" WITH CHECK ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (("tenant_id" IS NOT NULL) AND "public"."is_network_owner"("tenant_id")) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id"))))));

CREATE POLICY "vendors_select" ON "public"."vendors" FOR SELECT TO "authenticated" USING ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id")))) OR "public"."user_can_manage_parent_tenant"("tenant_id")));

CREATE POLICY "vendors_update" ON "public"."vendors" FOR UPDATE TO "authenticated" USING ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (("tenant_id" IS NOT NULL) AND "public"."is_network_owner"("tenant_id")) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id")))))) WITH CHECK ((("public"."is_superadmin"() AND ("tenant_id" IS NULL)) OR (("tenant_id" IS NOT NULL) AND "public"."is_network_owner"("tenant_id")) OR (EXISTS ( SELECT 1
   FROM "public"."memberships" "m"
  WHERE (("lower"(TRIM(BOTH FROM "m"."email")) = "public"."current_user_email"()) AND ("m"."role" = 'admin'::"public"."app_role") AND ("m"."is_active" = true) AND ("m"."tenant_id" IS NOT NULL) AND ("vendors"."tenant_id" = "m"."tenant_id"))))));
