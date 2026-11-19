-- Sync function bodies to supabase/schemas (tenant_id; no parent_tenant_id column).
DROP FUNCTION IF EXISTS public.list_shop_orders_staff_page(
  bigint, bigint, integer, text, text, bigint, text, bigint, timestamptz, bigint
);

DROP FUNCTION IF EXISTS public._upsert_shipment_ap_bill(bigint, bigint, bigint, text, text, bigint, numeric, jsonb, boolean);
CREATE OR REPLACE FUNCTION "public"."_assert_parent_warehouse_tenant"("p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select parent_id into v_parent_id
  from public.tenants
  where id = p_tenant_id;

  if not found then
    raise exception 'tenant not found';
  end if;

  if v_parent_id is not null then
    raise exception 'stock locations are only for parent warehouse tenants';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._insert_bill_line_from_compose_payload(
  p_parent_id bigint,
  p_invoice_id bigint,
  p_item_elem jsonb
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_line_meta jsonb;
  v_line_kind text;
  v_name_snapshot text;
  v_created_item_id bigint;
  v_stock_parent bigint;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
begin
  v_line_meta := coalesce(p_item_elem->'line_meta', '{}'::jsonb);
  v_global_stock_id := coalesce(
    nullif(p_item_elem->>'global_stock_id', '')::bigint,
    nullif(v_line_meta->'stock_ref'->>'global_stock_id', '')::bigint
  );
  v_quantity := nullif(p_item_elem->>'quantity', '')::numeric;
  v_sell_price := nullif(p_item_elem->>'sell_price_amount', '')::numeric;
  v_line_discount := coalesce(nullif(p_item_elem->>'line_discount_amount', '')::numeric, 0);
  v_line_kind := lower(trim(coalesce(p_item_elem->>'line_kind', '')));

  if v_quantity is null or v_quantity <= 0 then
    raise exception 'each item requires quantity > 0';
  end if;
  if v_sell_price is null or v_sell_price < 0 then
    raise exception 'each item requires sell_price_amount >= 0';
  end if;

  if v_global_stock_id is null and coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
    v_product_id := nullif(p_item_elem->>'product_id', '')::bigint;
    v_shipment_item_id := nullif(p_item_elem->>'shipment_item_id', '')::bigint;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Gift item');
    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest((v_quantity * v_sell_price) - v_line_discount, 0)
    );

    insert into public.bill_lines (
      tenant_id, invoice_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
    ) values (
      p_parent_id, p_invoice_id, v_shipment_item_id, v_product_id,
      v_name_snapshot,
      nullif(trim(p_item_elem->>'barcode_snapshot'), ''),
      nullif(trim(p_item_elem->>'product_code_snapshot'), ''),
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      nullif(p_item_elem->>'assigned_child_tenant_id', '')::bigint,
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  if v_global_stock_id is null then
    if v_line_kind = '' then
      v_line_kind := 'description';
    end if;
    if v_line_kind not in ('description', 'charge') then
      raise exception 'non-stock items require line_kind description or charge';
    end if;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Line');
    v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

    insert into public.bill_lines (
      tenant_id, invoice_id, line_kind, name_snapshot,
      quantity, sell_price_amount, line_discount_amount, line_total_amount,
      currency_code, books_amount, line_meta
    ) values (
      p_parent_id, p_invoice_id, v_line_kind, v_name_snapshot,
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      upper(trim(coalesce(p_item_elem->>'currency_code', 'BDT'))),
      coalesce(nullif(p_item_elem->>'books_amount', '')::numeric, v_line_total),
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  select
    gs.tenant_id, gs.shipment_item_id, gsi.name, gsi.barcode, gsi.product_code,
    sh.assigned_child_tenant_id, p.id
  into
    v_stock_parent, v_shipment_item_id, v_name_snapshot, v_barcode_snapshot,
    v_product_code_snapshot, v_assigned_child, v_product_id
  from public.global_stocks gs
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments sh on sh.id = gsi.shipment_id
  left join public.products p on p.id = gsi.product_id
  where gs.id = v_global_stock_id;

  if v_stock_parent is null then
    raise exception 'stock % not found', v_global_stock_id;
  end if;
  if v_stock_parent <> p_parent_id then
    raise exception 'stock % does not belong to invoice parent tenant', v_global_stock_id;
  end if;

  v_shipment_item_id := coalesce(nullif(p_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
  v_product_id := coalesce(nullif(p_item_elem->>'product_id', '')::bigint, v_product_id);
  v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
  v_line_total := coalesce(
    nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
    greatest((v_quantity * v_sell_price) - v_line_discount, 0)
  );

  v_line_meta := jsonb_set(
    coalesce(v_line_meta, '{}'::jsonb),
    '{stock_ref}',
    jsonb_build_object('global_stock_id', v_global_stock_id),
    true
  );

  insert into public.bill_lines (
    tenant_id, invoice_id, line_kind, shipment_item_id, product_id,
    name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
    sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
  ) values (
    p_parent_id, p_invoice_id, 'stock', v_shipment_item_id, v_product_id,
    v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot,
    v_quantity, v_sell_price, v_line_discount, v_line_total, v_assigned_child, v_line_meta
  )
  returning id into v_created_item_id;
  return v_created_item_id;
end;
$$;

CREATE OR REPLACE FUNCTION public._upsert_shipment_ap_bill(
  p_tenant_id bigint,
  p_issued_by_tenant_id bigint,
  p_shipment_id bigint,
  p_shipment_name text,
  p_ap_kind text,
  p_profile_id bigint,
  p_amount numeric,
  p_ap_paper jsonb DEFAULT NULL,
  p_keep_as_draft boolean DEFAULT false,
  p_source_key text DEFAULT NULL
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_target numeric(12, 2);
  v_old_total numeric(12, 2);
  v_due numeric(12, 2);
  v_status text;
  v_invoice_no text;
  v_kind_label text;
  v_meta_base jsonb;
  v_paper_status public.global_invoice_status;
  v_plug_key text;
  v_face_currency text;
  v_base_note text;
  v_note text;
  v_books_target numeric(12, 2);
begin
  if p_ap_kind not in (
    'vendor', 'cargo', 'local',
    'material', 'freight', 'customs', 'handling', 'finance', 'other'
  ) then
    raise exception 'Invalid ap_kind %', p_ap_kind;
  end if;

  v_plug_key := coalesce(nullif(btrim(p_source_key), ''), p_ap_kind);
  v_face_currency := upper(trim(coalesce(p_ap_paper->>'currency_code', 'BDT')));

  select * into v_bill
  from public.bills b
  where b.tenant_id = p_tenant_id
    and b.invoice_type = 'ap'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.source_type = 'shipment_cost'
    and b.source_id = p_shipment_id::text
    and b.source_key = v_plug_key
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
  v_books_target := v_target;
  if upper(v_face_currency) not in ('', 'BDT')
     and upper(v_face_currency) <> upper(public.resolve_tenant_base_currency_code(p_tenant_id)) then
    v_books_target := coalesce(nullif((p_ap_paper->>'bdt_amount')::numeric, 0), 0);
  end if;
  v_kind_label := initcap(replace(p_ap_kind, '_', ' '));
  v_meta_base := jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id);
  if p_ap_paper is not null then
    v_meta_base := v_meta_base || jsonb_build_object('ap_paper', p_ap_paper);
  end if;

  v_base_note := format(
    'Shipment %s — %s AP%s',
    coalesce(p_shipment_name, p_shipment_id::text),
    v_kind_label,
    case when v_plug_key <> p_ap_kind then ' (' || v_plug_key || ')' else '' end
  );

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := public.generate_sales_invoice_number(
      p_issued_by_tenant_id,
      'ap'::public.global_invoice_type,
      current_date
    );
    insert into public.bills (
      tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, total_amount, due_amount, paid_amount,
      ap_shipment_id, ap_kind, source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind
    ) values (
      p_tenant_id, p_issued_by_tenant_id, v_invoice_no, 'ap'::public.global_invoice_type, current_date,
      v_paper_status, p_profile_id, 'profile'::public.collection_source_type, 'due',
      v_books_target, v_books_target, v_books_target, 0,
      p_shipment_id, p_ap_kind, 'shipment_cost', p_shipment_id::text, v_plug_key, v_face_currency,
      v_base_note,
      v_meta_base,
      'standard'::public.bill_document_kind
    )
    returning id into v_bill.id;
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return v_bill.id;
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) = 0
       and not exists (
         select 1 from public.bill_settlements bs where bs.bill_id = v_bill.id
       )
       and p_ap_paper is not null then
      update public.bills
      set
        channel_meta = coalesce(channel_meta, '{}'::jsonb)
          || jsonb_build_object('ap_kind', p_ap_kind, 'shipment_id', p_shipment_id)
          || jsonb_build_object('ap_paper', p_ap_paper),
        updated_at = now()
      where id = v_bill.id;
    end if;
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
      subtotal_amount = v_books_target,
      total_amount = v_books_target,
      due_amount = v_books_target,
      payment_status = 'due',
      source_type = coalesce(source_type, 'shipment_cost'),
      source_id = coalesce(source_id, p_shipment_id::text),
      source_key = coalesce(source_key, v_plug_key),
      currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
      note = v_base_note,
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

  v_old_total := round(coalesce(v_bill.total_amount, 0), 2);
  v_note := coalesce(nullif(trim(v_bill.note), ''), v_base_note);
  if v_old_total is distinct from v_books_target then
    v_note := v_note || format(
      E'\nCost sync %s: %s → %s books (face %s %s)',
      to_char(current_date, 'YYYY-MM-DD'),
      v_old_total,
      v_books_target,
      v_target,
      v_face_currency
    );
  end if;

  v_due := greatest(v_books_target - coalesce(v_bill.paid_amount, 0), 0);
  v_status := case
    when v_due <= 0 then 'paid'
    when coalesce(v_bill.paid_amount, 0) > 0 then 'partially_paid'
    else 'due'
  end;

  update public.bills
  set
    profile_id = p_profile_id,
    subtotal_amount = v_books_target,
    total_amount = v_books_target,
    due_amount = v_due,
    payment_status = v_status,
    source_type = coalesce(source_type, 'shipment_cost'),
    source_id = coalesce(source_id, p_shipment_id::text),
    source_key = coalesce(source_key, v_plug_key),
    currency_code = coalesce(nullif(trim(v_face_currency), ''), nullif(trim(currency_code), ''), 'BDT'),
    note = v_note,
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

CREATE OR REPLACE FUNCTION "public"."_validate_stock_location_nesting"("p_kind" "public"."stock_location_kind", "p_parent_location_id" bigint, "p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent public.stock_locations%rowtype;
begin
  if p_kind in ('warehouse', 'returns') then
    if p_parent_location_id is not null then
      raise exception 'warehouse and returns must be top-level (no parent)';
    end if;
    return;
  end if;

  if p_parent_location_id is null then
    raise exception '% requires a parent location', p_kind;
  end if;

  select * into v_parent
  from public.stock_locations
  where id = p_parent_location_id;

  if not found then
    raise exception 'parent location not found';
  end if;

  if v_parent.tenant_id <> p_tenant_id then
    raise exception 'parent location belongs to another tenant';
  end if;

  if p_kind = 'zone' then
    if v_parent.kind not in ('warehouse', 'returns') then
      raise exception 'zone parent must be a warehouse or returns area';
    end if;
  elsif p_kind = 'shelf' then
    if v_parent.kind <> 'zone' then
      raise exception 'shelf parent must be a zone';
    end if;
  elsif p_kind = 'level' then
    if v_parent.kind <> 'shelf' then
      raise exception 'level parent must be a shelf';
    end if;
  elsif p_kind = 'bin' then
    if v_parent.kind <> 'level' then
      raise exception 'bin parent must be a level';
    end if;
  end if;
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

  v_parent := coalesce(v_invoice.tenant_id, public.resolve_books_tenant_id(v_invoice.tenant_id));

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

CREATE OR REPLACE FUNCTION "public"."add_shop_order_item_stock_pick"("p_order_item_id" bigint, "p_global_stock_id" bigint, "p_quantity" integer, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_item public.shop_order_items%rowtype;
  v_order public.shop_orders%rowtype;
  v_stock public.global_stocks%rowtype;
  v_held_stock_id bigint;
  v_books_tenant_id bigint;
  v_existing_qty integer := 0;
  v_total_picked integer := 0;
  v_pick_id bigint;
  v_grade_tag_id bigint;
  v_confirmed_qty numeric;
  v_fulfillment_resolved boolean;
  v_pick_list jsonb;
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be positive';
  end if;

  select * into v_item from public.shop_order_items where id = p_order_item_id for update;
  if v_item.id is null then
    raise exception 'order item not found';
  end if;

  select * into v_order from public.shop_orders where id = v_item.order_id for update;
  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.status <> 'processing'::public.shop_order_status then
    raise exception 'stock pick is only allowed while order is processing';
  end if;

  if coalesce(v_item.is_fulfillment_unavailable, false) then
    raise exception 'line is marked unavailable';
  end if;

  v_grade_tag_id := coalesce(v_item.grade_tag_id, public.default_stock_grade_tag_id());

  select * into v_stock
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = p_global_stock_id
    and gsi.product_id = v_item.product_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id()) = v_grade_tag_id
  for update of gs;

  if v_stock.id is null then
    raise exception 'stock not found or does not match line product/grade';
  end if;

  if v_stock.availability <> 'sellable'::public.stock_availability then
    raise exception 'stock is not sellable';
  end if;

  if public.global_stock_atp_qty(v_stock.id) < p_quantity then
    raise exception 'insufficient ATP (requested %, available %)', p_quantity, public.global_stock_atp_qty(v_stock.id);
  end if;

  select coalesce(sum(sp.quantity), 0)
  into v_total_picked
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id;

  select coalesce(sp.quantity, 0)
  into v_existing_qty
  from public.shop_order_item_stock_picks sp
  where sp.order_item_id = p_order_item_id
    and sp.global_stock_id = p_global_stock_id;

  if v_total_picked - v_existing_qty + p_quantity > v_item.quantity then
    raise exception 'pick quantity exceeds ordered qty (ordered %, would pick %)',
      v_item.quantity, v_total_picked - v_existing_qty + p_quantity;
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  perform public.create_and_post_stock_movement(
    p_tenant_id => v_books_tenant_id,
    p_stock_id => v_stock.id,
    p_quantity => p_quantity,
    p_to_location_id => v_stock.location_id,
    p_to_availability => 'held'::public.stock_availability,
    p_to_grade_tag_id => v_stock.grade_tag_id,
    p_movement_type => 'availability_transfer'::public.stock_movement_type,
    p_notes => 'Dropship processing pick',
    p_reference_type => 'shop_order',
    p_reference_id => v_order.id::text
  );

  select gs.id into v_held_stock_id
  from public.global_stocks gs
  where gs.shipment_item_id = v_stock.shipment_item_id
    and gs.tenant_id = v_books_tenant_id
    and gs.availability = 'held'::public.stock_availability
    and gs.location_id is not distinct from v_stock.location_id
    and coalesce(gs.grade_tag_id, public.default_stock_grade_tag_id())
      = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  order by gs.id desc
  limit 1;

  insert into public.shop_order_item_stock_picks (
    tenant_id, order_id, order_item_id, global_stock_id,
    shipment_item_id, shipment_id, quantity, held_stock_id, created_by_email
  )
  values (
    v_order.tenant_id, v_order.id, v_item.id, v_stock.id,
    v_stock.shipment_item_id,
    (select shipment_id from public.global_shipment_items where id = v_stock.shipment_item_id),
    p_quantity, v_held_stock_id, public.current_user_email()
  )
  on conflict (order_item_id, global_stock_id) do update
  set
    quantity = public.shop_order_item_stock_picks.quantity + excluded.quantity,
    held_stock_id = excluded.held_stock_id,
    updated_at = now()
  returning id into v_pick_id;

  perform public._recompute_shop_order_item_fulfillment(p_order_item_id);
  perform public.recompute_dropship_cod_collect_amount(v_order.id);

  select
    soi.confirmed_quantity,
    coalesce(soi.is_fulfillment_unavailable, false)
      or coalesce(soi.confirmed_quantity, 0) > 0
      or (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'customer_stock'
        and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
      )
      or (coalesce(soi.is_gift, false) and soi.gift_source = 'stock')
  into v_confirmed_qty, v_fulfillment_resolved
  from public.shop_order_items soi
  where soi.id = p_order_item_id;

  v_pick_list := public.list_stock_for_order_item_pick(
    p_order_item_id,
    p_search,
    p_limit,
    p_offset
  );

  return jsonb_build_object(
    'success', true,
    'pick_id', v_pick_id,
    'confirmed_quantity', v_confirmed_qty,
    'cod_collect_amount', (select cod_collect_amount from public.shop_orders where id = v_order.id),
    'order_line', jsonb_build_object(
      'id', p_order_item_id,
      'confirmed_quantity', v_confirmed_qty,
      'fulfillment_resolved', v_fulfillment_resolved
    ),
    'pick_list', v_pick_list
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."apply_dropship_payout_settlement_fifo"("p_tenant_id" bigint, "p_profile_id" bigint, "p_amount" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_remaining numeric := greatest(coalesce(p_amount, 0), 0);
  v_books_tenant_id bigint;
  r record;
  v_hold numeric;
  v_paid numeric;
  v_outstanding numeric;
begin
  if v_remaining <= 0 then
    return;
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(p_tenant_id);

  for r in
    select o.id
    from public.shop_orders o
    where o.profile_id = p_profile_id
      and o.shop_type_snapshot = 'dropship'
      and o.global_invoice_id is not null
      and coalesce(o.payout_settlement_status, 'unpaid') in ('unpaid', 'partial')
      and (
        o.tenant_id = p_tenant_id
        or o.tenant_id = v_books_tenant_id
      )
    order by o.created_at asc, o.id asc
  loop
    exit when v_remaining <= 0;

    select coalesce(sum(u.amount), 0)
    into v_hold
    from public.cashbook_entries u
    where u.tenant_id = v_books_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = r.id::text
      and u.entity_type in ('middleman', 'customer')
      and u.type = 'credit'
      and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit';

    select coalesce(sum(u.amount), 0)
    into v_paid
    from public.cashbook_entries u
    where u.tenant_id = v_books_tenant_id
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_profile_id
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
$$;

CREATE OR REPLACE FUNCTION public.approve_stock_physical_count(p_count_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count public.stock_physical_counts%rowtype;
  v_line public.stock_physical_count_lines%rowtype;
  v_stock public.global_stocks%rowtype;
  v_mov_payload jsonb;
  v_mov_id bigint;
  v_final_qty integer;
  v_variance integer;
  v_line_count integer := 0;
BEGIN
  SELECT * INTO v_count
  FROM public.stock_physical_counts
  WHERE id = p_count_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'count session not found';
  END IF;

  IF v_count.status <> 'pending_approval'::public.stock_physical_count_status THEN
    RAISE EXCEPTION 'count session must be pending_approval';
  END IF;

  IF NOT public.has_active_tenant_membership(v_count.tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_count.movement_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'status', 'posted',
      'movement_id', v_count.movement_id
    );
  END IF;

  v_mov_payload := public.create_stock_movement(
    v_count.tenant_id,
    'adjustment'::public.stock_movement_type,
    coalesce(v_count.notes, 'Cycle count approve'),
    'stock_physical_count',
    p_count_id::text
  );
  v_mov_id := (v_mov_payload->'movement'->>'id')::bigint;

  FOR v_line IN
    SELECT * FROM public.stock_physical_count_lines WHERE count_id = p_count_id
  LOOP
    v_final_qty := coalesce(v_line.recount_qty, v_line.counted_qty, v_line.system_qty);
    UPDATE public.stock_physical_count_lines
    SET approved_qty = v_final_qty, updated_at = now()
    WHERE id = v_line.id;

    v_variance := v_final_qty - v_line.system_qty;
    IF v_variance = 0 THEN
      CONTINUE;
    END IF;

    SELECT * INTO v_stock
    FROM public.global_stocks
    WHERE id = v_line.global_stock_id
      AND tenant_id = v_count.tenant_id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'stock % not found for count line', v_line.global_stock_id;
    END IF;

    IF v_variance > 0 THEN
      PERFORM public.add_stock_movement_line(
        v_mov_id,
        v_line.global_stock_id,
        abs(v_variance),
        v_stock.location_id,
        v_stock.location_id,
        NULL,
        v_stock.availability,
        NULL,
        v_stock.grade_tag_id
      );
    ELSE
      PERFORM public.add_stock_movement_line(
        v_mov_id,
        v_line.global_stock_id,
        abs(v_variance),
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        NULL,
        NULL,
        NULL
      );
    END IF;
    v_line_count := v_line_count + 1;
  END LOOP;

  IF v_line_count > 0 THEN
    PERFORM public.post_stock_movement(v_mov_id);
  ELSE
    DELETE FROM public.stock_movements WHERE id = v_mov_id;
    v_mov_id := NULL;
  END IF;

  UPDATE public.stock_physical_counts
  SET
    status = 'posted'::public.stock_physical_count_status,
    movement_id = v_mov_id,
    approved_at = now(),
    updated_at = now()
  WHERE id = p_count_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', 'posted',
    'movement_id', v_mov_id,
    'variance_lines', v_line_count
  );
END;
$function$;

CREATE OR REPLACE FUNCTION "public"."canonicalize_dropship_order_wallet_source_ids"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_invoice_no text;
  v_books_tenant_id bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null or v_order.shop_type_snapshot <> 'dropship' then
    return;
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);
  v_invoice_no := null;
  if v_order.global_invoice_id is not null then
    select i.invoice_no into v_invoice_no
    from public.bills i
    where i.id = v_order.global_invoice_id;
  end if;

  update public.cashbook_entries u
  set
    source_id = p_order_id::text,
    metadata = coalesce(u.metadata, '{}'::jsonb)
      || jsonb_build_object(
        'order_id', p_order_id,
        'invoice_no', coalesce(v_invoice_no, v_order.order_no)
      )
  where u.source_type = 'shop_order'
    and u.tenant_id = v_books_tenant_id
    and u.source_id in (
      coalesce(v_invoice_no, ''),
      v_order.order_no,
      'INV-DS-' || v_order.order_no
    );

  if v_order.global_invoice_id is not null then
    update public.cashbook_entries u
    set
      source_id = p_order_id::text,
      metadata = coalesce(u.metadata, '{}'::jsonb)
        || jsonb_build_object('order_id', p_order_id, 'invoice_id', v_order.global_invoice_id)
    from public.bills i
    where i.id = v_order.global_invoice_id
      and u.source_type = 'shop_order'
      and u.tenant_id = v_books_tenant_id
      and u.source_id = i.invoice_no;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."close_preorder_demand_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint, "p_close_action" "text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_close_action text := lower(trim(coalesce(p_close_action, '')));
  v_operating_tenant_id bigint;
  v_profile_id bigint;
  v_doc_status text;
  v_books_tenant_id bigint;
  v_global_invoice_id bigint;
  v_pbc_invoice_id bigint;
  v_items jsonb := '[]'::jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_invoice_id bigint;
  v_line record;
  v_pd record;
  v_pick_elem jsonb;
  v_new_picks jsonb;
  v_pick_close text;
  v_global_stock_id bigint;
  v_qty integer;
  v_pick_count integer := 0;
  v_unit_count integer := 0;
  v_stock public.global_stocks%rowtype;
  v_delivery_kind text;
begin
  if p_tenant_id is null or p_document_id is null then
    raise exception 'tenant_id and document_id are required';
  end if;

  if v_close_action not in ('take', 'condition', 'return') then
    raise exception 'close_action must be take, condition, or return';
  end if;

  if v_doc_type = 'shop_order' then
    select
      o.tenant_id,
      o.profile_id,
      o.global_invoice_id,
      public.normalize_shop_order_procurement_status(o.status)
    into v_operating_tenant_id, v_profile_id, v_global_invoice_id, v_doc_status
    from public.shop_orders o
    where o.id = p_document_id
      and o.shop_type_snapshot = 'vendor_catalog';

    if v_operating_tenant_id is null then
      raise exception 'shop order not found or not vendor_catalog';
    end if;
  elsif v_doc_type = 'pbc_costing_file' then
    select
      f.tenant_id,
      f.profile_id,
      f.invoice_id,
      public.normalize_pbc_procurement_status(f.status)
    into v_operating_tenant_id, v_profile_id, v_pbc_invoice_id, v_doc_status
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

  if v_operating_tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_operating_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_books_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand document';
    end if;
  end if;

  if v_doc_status <> 'packed' then
    raise exception 'document must be packed to close picks';
  end if;

  if v_profile_id is null and v_close_action in ('take', 'condition') then
    raise exception 'profile_id is required on document';
  end if;

  select coalesce(t.parent_id, t.id)
  into v_books_tenant_id
  from public.tenants t
  where t.id = v_operating_tenant_id;

  if v_close_action in ('take', 'condition') then
    v_delivery_kind := v_close_action;

    if v_doc_type = 'shop_order' then
      for v_line in
        select
          pd.source_type,
          pd.source_id,
          pd.stock_picks,
          coalesce(oi.final_price_amount, oi.staff_offer_amount, 0)::numeric(12,2) as sell_price
        from public.preorder_demand pd
        inner join public.shop_order_items oi
          on pd.source_type = 'shop_order_item'
          and pd.source_id = oi.id
        where oi.order_id = p_document_id
        order by pd.source_id
      loop
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_line.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_items := v_items || jsonb_build_array(jsonb_build_object(
              'global_stock_id', v_global_stock_id,
              'quantity', v_qty,
              'sell_price_amount', v_line.sell_price
            ));
            v_pick_count := v_pick_count + 1;
            v_unit_count := v_unit_count + v_qty;
          end if;
        end loop;
      end loop;
    else
      for v_line in
        select
          pd.source_type,
          pd.source_id,
          pd.stock_picks,
          coalesce(pci.offer_price, 0)::numeric(12,2) as sell_price
        from public.preorder_demand pd
        inner join public.product_based_costing_items pci
          on pd.source_type = 'pbc_costing_item'
          and pd.source_id = pci.id
        where pci.product_based_costing_file_id = p_document_id
        order by pd.source_id
      loop
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_line.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_items := v_items || jsonb_build_array(jsonb_build_object(
              'global_stock_id', v_global_stock_id,
              'quantity', v_qty,
              'sell_price_amount', v_line.sell_price
            ));
            v_pick_count := v_pick_count + 1;
            v_unit_count := v_unit_count + v_qty;
          end if;
        end loop;
      end loop;
    end if;

    if v_pick_count = 0 then
      return jsonb_build_object(
        'success', true,
        'created', false,
        'close_action', v_close_action,
        'pick_count', 0,
        'unit_count', 0
      );
    end if;

    v_payload := jsonb_build_object(
      'invoice', jsonb_build_object(
        'invoice_type', 'wholesale',
        'profile_id', v_profile_id,
        'channel_meta', jsonb_build_object('delivery_kind', v_delivery_kind)
      ),
      'items', v_items,
      'issue', false
    );

    v_result := public.create_sales_invoice_from_payload(v_operating_tenant_id, v_payload);

    if coalesce(v_result->>'success', 'false') <> 'true' then
      raise exception '%', coalesce(v_result->>'error', 'failed to create close invoice');
    end if;

    v_invoice_id := (v_result->>'invoice_id')::bigint;

    begin
      update public.bills
      set
        source_type = 'delivery_close',
        source_id = p_document_id::text,
        source_key = v_close_action,
        settlement_kind = v_close_action::public.bill_settlement_kind,
        channel_meta = coalesce(channel_meta, '{}'::jsonb)
          || jsonb_build_object(
            'delivery_kind', v_close_action,
            'document_type', v_doc_type
          ),
        updated_at = now()
      where id = v_invoice_id;
    exception
      when unique_violation then
        update public.bills
        set
          source_type = 'delivery_close',
          source_id = p_document_id::text,
          source_key = v_close_action || ':' || v_invoice_id::text,
          settlement_kind = v_close_action::public.bill_settlement_kind,
          channel_meta = coalesce(channel_meta, '{}'::jsonb)
            || jsonb_build_object(
              'delivery_kind', v_close_action,
              'document_type', v_doc_type
            ),
          updated_at = now()
        where id = v_invoice_id;
    end;

    perform public.stamp_bill_kernel_fields(v_invoice_id);

    if v_doc_type = 'shop_order' then
      for v_pd in
        select pd.id, pd.source_type, pd.source_id, pd.stock_picks
        from public.preorder_demand pd
        inner join public.shop_order_items oi
          on pd.source_type = 'shop_order_item'
          and pd.source_id = oi.id
        where oi.order_id = p_document_id
        order by pd.source_id
      loop
        v_new_picks := '[]'::jsonb;
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_pick_elem := v_pick_elem || jsonb_build_object('invoice_id', v_invoice_id);
          end if;
          v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
        end loop;

        update public.preorder_demand
        set
          stock_picks = v_new_picks,
          updated_at = now()
        where id = v_pd.id;
      end loop;

      if v_close_action = 'take' and v_global_invoice_id is null then
        update public.shop_orders
        set
          global_invoice_id = v_invoice_id,
          updated_at = now()
        where id = p_document_id
          and global_invoice_id is null;
      end if;
    else
      for v_pd in
        select pd.id, pd.source_type, pd.source_id, pd.stock_picks
        from public.preorder_demand pd
        inner join public.product_based_costing_items pci
          on pd.source_type = 'pbc_costing_item'
          and pd.source_id = pci.id
        where pci.product_based_costing_file_id = p_document_id
        order by pd.source_id
      loop
        v_new_picks := '[]'::jsonb;
        for v_pick_elem in
          select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
        loop
          v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
          v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
          v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
          if v_pick_close = v_close_action
            and v_global_stock_id is not null
            and v_qty > 0
            and nullif(v_pick_elem->>'invoice_id', '') is null
            and nullif(v_pick_elem->>'returned_at', '') is null
          then
            v_pick_elem := v_pick_elem || jsonb_build_object('invoice_id', v_invoice_id);
          end if;
          v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
        end loop;

        update public.preorder_demand
        set
          stock_picks = v_new_picks,
          updated_at = now()
        where id = v_pd.id;
      end loop;

      if v_close_action = 'take' and v_pbc_invoice_id is null then
        update public.product_based_costing_files
        set
          invoice_id = v_invoice_id,
          updated_at = now()
        where id = p_document_id
          and invoice_id is null;
      end if;
    end if;

    return jsonb_build_object(
      'success', true,
      'created', true,
      'close_action', v_close_action,
      'invoice_id', v_invoice_id,
      'invoice_no', v_result->>'invoice_no',
      'pick_count', v_pick_count,
      'unit_count', v_unit_count
    );
  end if;

  if v_doc_type = 'shop_order' then
    for v_pd in
      select pd.id, pd.source_type, pd.source_id, pd.stock_picks
      from public.preorder_demand pd
      inner join public.shop_order_items oi
        on pd.source_type = 'shop_order_item'
        and pd.source_id = oi.id
      where oi.order_id = p_document_id
      order by pd.source_id
    loop
      v_new_picks := '[]'::jsonb;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_pick_close = 'return'
          and v_global_stock_id is not null
          and v_qty > 0
          and nullif(v_pick_elem->>'invoice_id', '') is null
          and nullif(v_pick_elem->>'returned_at', '') is null
        then
          select * into v_stock
          from public.global_stocks
          where id = v_global_stock_id
            and tenant_id = v_books_tenant_id
          for update;

          if v_stock.id is null then
            raise exception 'stock % not found', v_global_stock_id;
          end if;

          if v_stock.availability = 'held'::public.stock_availability then
            perform public.create_and_post_stock_movement(
              p_tenant_id => v_books_tenant_id,
              p_stock_id => v_global_stock_id,
              p_quantity => v_qty,
              p_to_location_id => v_stock.location_id,
              p_to_availability => 'sellable'::public.stock_availability,
              p_movement_type => 'availability_transfer'::public.stock_movement_type,
              p_notes => 'Delivery paper return',
              p_reference_type => 'preorder_demand',
              p_reference_id => v_pd.id::text
            );
          elsif v_stock.availability <> 'sellable'::public.stock_availability then
            raise exception 'return close requires held or sellable stock % (current: %)',
              v_global_stock_id, v_stock.availability;
          end if;

          v_pick_elem := v_pick_elem || jsonb_build_object(
            'returned_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
          );
          v_pick_count := v_pick_count + 1;
          v_unit_count := v_unit_count + v_qty;
        end if;
        v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
      end loop;

      update public.preorder_demand
      set
        stock_picks = v_new_picks,
        updated_at = now()
      where id = v_pd.id;
    end loop;
  else
    for v_pd in
      select pd.id, pd.source_type, pd.source_id, pd.stock_picks
      from public.preorder_demand pd
      inner join public.product_based_costing_items pci
        on pd.source_type = 'pbc_costing_item'
        and pd.source_id = pci.id
      where pci.product_based_costing_file_id = p_document_id
      order by pd.source_id
    loop
      v_new_picks := '[]'::jsonb;
      for v_pick_elem in
        select value from jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
      loop
        v_pick_close := lower(trim(coalesce(v_pick_elem->>'close_action', 'take')));
        v_global_stock_id := nullif(v_pick_elem->>'global_stock_id', '')::bigint;
        v_qty := coalesce((v_pick_elem->>'quantity')::integer, 0);
        if v_pick_close = 'return'
          and v_global_stock_id is not null
          and v_qty > 0
          and nullif(v_pick_elem->>'invoice_id', '') is null
          and nullif(v_pick_elem->>'returned_at', '') is null
        then
          select * into v_stock
          from public.global_stocks
          where id = v_global_stock_id
            and tenant_id = v_books_tenant_id
          for update;

          if v_stock.id is null then
            raise exception 'stock % not found', v_global_stock_id;
          end if;

          if v_stock.availability = 'held'::public.stock_availability then
            perform public.create_and_post_stock_movement(
              p_tenant_id => v_books_tenant_id,
              p_stock_id => v_global_stock_id,
              p_quantity => v_qty,
              p_to_location_id => v_stock.location_id,
              p_to_availability => 'sellable'::public.stock_availability,
              p_movement_type => 'availability_transfer'::public.stock_movement_type,
              p_notes => 'Delivery paper return',
              p_reference_type => 'preorder_demand',
              p_reference_id => v_pd.id::text
            );
          elsif v_stock.availability <> 'sellable'::public.stock_availability then
            raise exception 'return close requires held or sellable stock % (current: %)',
              v_global_stock_id, v_stock.availability;
          end if;

          v_pick_elem := v_pick_elem || jsonb_build_object(
            'returned_at', to_char(now() at time zone 'utc', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
          );
          v_pick_count := v_pick_count + 1;
          v_unit_count := v_unit_count + v_qty;
        end if;
        v_new_picks := v_new_picks || jsonb_build_array(v_pick_elem);
      end loop;

      update public.preorder_demand
      set
        stock_picks = v_new_picks,
        updated_at = now()
      where id = v_pd.id;
    end loop;
  end if;

  return jsonb_build_object(
    'success', true,
    'created', v_pick_count > 0,
    'close_action', v_close_action,
    'pick_count', v_pick_count,
    'unit_count', v_unit_count
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."create_and_post_stock_movement"("p_tenant_id" bigint, "p_stock_id" bigint, "p_quantity" integer, "p_to_location_id" bigint DEFAULT NULL::bigint, "p_to_availability" "public"."stock_availability" DEFAULT NULL::"public"."stock_availability", "p_to_grade_tag_id" bigint DEFAULT NULL::bigint, "p_movement_type" "public"."stock_movement_type" DEFAULT 'grade_change'::"public"."stock_movement_type", "p_notes" "text" DEFAULT NULL::"text", "p_reference_type" "text" DEFAULT NULL::"text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_stock public.global_stocks%rowtype;
  v_mov_id bigint;
  v_mov_no text;
  v_is_customer_return boolean;
begin
  if not public.can_act_on_stock_movement_context(p_tenant_id, p_reference_type, p_reference_id) then
    raise exception 'not authorized';
  end if;

  select * into v_stock
  from public.global_stocks
  where id = p_stock_id
    and tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'stock % not found', p_stock_id;
  end if;

  if p_quantity is null or p_quantity <= 0 then
    raise exception 'quantity must be > 0';
  end if;

  v_is_customer_return := (
    p_movement_type = 'return_inbound'::public.stock_movement_type
    and coalesce(p_reference_type, '') is distinct from 'shipment_return'
  );

  if not v_is_customer_return and v_stock.quantity < p_quantity then
    raise exception 'insufficient stock quantity (requested %, available %)', p_quantity, v_stock.quantity;
  end if;

  v_mov_no := public.next_stock_movement_number(p_tenant_id, 'stock_movement');

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
    p_tenant_id,
    v_mov_no,
    p_movement_type,
    coalesce(p_reference_type, 'global_stock'),
    coalesce(p_reference_id, p_stock_id::text),
    p_notes,
    public.current_user_email(),
    false,
    null
  )
  returning id into v_mov_id;

  insert into public.stock_movement_lines (
    movement_id,
    stock_id,
    quantity,
    from_location_id,
    to_location_id,
    from_availability,
    to_availability,
    from_grade_tag_id,
    to_grade_tag_id
  ) values (
    v_mov_id,
    p_stock_id,
    p_quantity,
    v_stock.location_id,
    case
      when v_is_customer_return then coalesce(
        p_to_location_id,
        public.default_returns_stock_location_id(p_tenant_id)
      )
      else coalesce(p_to_location_id, v_stock.location_id)
    end,
    v_stock.availability,
    case
      when v_is_customer_return then coalesce(p_to_availability, 'held'::public.stock_availability)
      else coalesce(p_to_availability, v_stock.availability)
    end,
    v_stock.grade_tag_id,
    coalesce(p_to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  );

  perform public.post_stock_movement(v_mov_id);

  return jsonb_build_object(
    'success', true,
    'movement_id', v_mov_id,
    'movement_no', v_mov_no
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."create_cargo_company_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_notes" "text" DEFAULT NULL::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    or public.user_can_manage_books_tenant(p_tenant_id)
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
    tenant_id,
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
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
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
$$;

CREATE OR REPLACE FUNCTION public.create_delivery_paper_for_document(p_tenant_id bigint, p_document_type text, p_document_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
  v_source_type public.delivery_paper_source_type;
  v_parent_tenant_id bigint;
  v_profile_id bigint;
  v_paper_id bigint;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_document_id IS NULL THEN
    RAISE EXCEPTION 'document_id is required';
  END IF;
  IF v_doc_type NOT IN ('shop_order', 'pbc_costing_file') THEN
    RAISE EXCEPTION 'invalid document_type: %', p_document_type;
  END IF;
  IF NOT public.delivery_paper_document_allows_papers(v_doc_type, p_document_id, p_tenant_id) THEN
    RAISE EXCEPTION 'document does not allow new delivery papers';
  END IF;

  v_source_type := v_doc_type::public.delivery_paper_source_type;

  IF v_doc_type = 'shop_order' THEN
    SELECT
      public.resolve_parent_tenant_id(o.tenant_id),
      o.profile_id
    INTO v_parent_tenant_id, v_profile_id
    FROM public.shop_orders o
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog';
    IF NOT FOUND THEN RAISE EXCEPTION 'shop order not found'; END IF;
  ELSE
    SELECT
      public.resolve_parent_tenant_id(f.tenant_id),
      f.profile_id
    INTO v_parent_tenant_id, v_profile_id
    FROM public.product_based_costing_files f
    WHERE f.id = p_document_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'costing file not found'; END IF;
  END IF;

  INSERT INTO public.delivery_paper (
    tenant_id,
    source_type,
    source_id,
    profile_id,
    status
  ) VALUES (
    v_parent_tenant_id,
    v_source_type,
    p_document_id,
    v_profile_id,
    'draft'::public.delivery_paper_status
  )
  RETURNING id INTO v_paper_id;

  RETURN jsonb_build_object(
    'id', v_paper_id,
    'status', 'draft',
    'created_at', now()
  );
END;
$function$;

CREATE OR REPLACE FUNCTION public.create_stock_physical_count(p_tenant_id bigint, p_location_id bigint DEFAULT NULL::bigint, p_notes text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_row public.stock_physical_counts%rowtype;
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  INSERT INTO public.stock_physical_counts (
    tenant_id,
    location_id,
    status,
    notes,
    created_by_email
  ) VALUES (
    p_tenant_id,
    p_location_id,
    'draft'::public.stock_physical_count_status,
    p_notes,
    public.current_user_email()
  )
  RETURNING * INTO v_row;

  RETURN jsonb_build_object('success', true, 'count', to_jsonb(v_row));
END;
$function$;

CREATE OR REPLACE FUNCTION "public"."create_vendor_with_wallet"("p_tenant_id" bigint, "p_name" "text", "p_code" "text", "p_market_code" "text", "p_email" "text" DEFAULT NULL::"text", "p_phone" "text" DEFAULT NULL::"text", "p_address" "text" DEFAULT NULL::"text", "p_website" "text" DEFAULT NULL::"text", "p_currency_code" "text" DEFAULT 'BDT'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    or public.user_can_manage_books_tenant(p_tenant_id)
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
    where v.tenant_id = p_tenant_id
      and upper(trim(v.code)) = upper(trim(p_code))
  ) then
    raise exception 'vendor code % already exists for this tenant', upper(trim(p_code));
  end if;

  if p_email is not null and trim(p_email) <> '' then
    if exists (
      select 1
      from public.vendors v
      where v.tenant_id = p_tenant_id
        and lower(trim(v.email)) = lower(trim(p_email))
    ) then
      raise exception 'vendor email % already exists for this tenant', lower(trim(p_email));
    end if;
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
$$;

CREATE OR REPLACE FUNCTION "public"."credit_dropship_profit_from_courier_remittance"("p_tenant_id" bigint, "p_profile_id" bigint, "p_order_id" bigint, "p_payment_id" bigint, "p_amount" numeric, "p_reference" "text", "p_net_remitted" numeric, "p_invoice_allocated" numeric) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_profit_already_credited boolean := false;
  v_amount numeric(12, 2);
begin
  v_amount := round(greatest(coalesce(p_amount, 0), 0), 2);
  if v_amount <= 0 then
    return;
  end if;

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  select exists (
    select 1
    from public.cashbook_entries u
    where u.tenant_id = v_parent_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = p_profile_id
      and u.type = 'credit'
      and coalesce(u.metadata ->> 'transaction_type', '') = 'dropship_profit'
  ) into v_profit_already_credited;

  if v_profit_already_credited then
    return;
  end if;

  perform public.record_ledger_transaction(
    p_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
    p_type => 'credit',
    p_amount => v_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'shop_order',
    p_source_id => p_order_id::text,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'transaction_type', 'dropship_profit',
      'label', 'Dropship profit from remittance remainder',
      'order_id', p_order_id,
      'shop_order_id', p_order_id::text,
      'payment_id', p_payment_id,
      'remittance_ref', p_reference,
      'net_remitted', p_net_remitted,
      'invoice_allocated', p_invoice_allocated
    )
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."customer_accessible_catalog_glance"("p_tenant_id" bigint, "p_customer_group_id" bigint) RETURNS "jsonb"
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  WITH accessible_shops AS (
    SELECT
      s.id,
      s.shop_type,
      s.vendor_code,
      s.vendor_filters
    FROM public.shops s
    JOIN public.shop_customer_group_access access ON access.shop_id = s.id
    JOIN public.customer_groups cg ON cg.id = access.customer_group_id
    LEFT JOIN public.customer_group_shop_profiles profile
      ON profile.customer_group_id = cg.id AND profile.tenant_id = s.tenant_id
    WHERE s.is_active = true
      AND s.deleted_at IS NULL
      AND s.tenant_id = p_tenant_id
      AND cg.id = p_customer_group_id
      AND cg.is_active = true
      AND access.status = true
      AND coalesce(profile.is_active, true) = true
      AND coalesce(access.can_browse, profile.default_can_browse, false) = true
  ),
  parent_tenant AS (
    SELECT public.resolve_books_tenant_id(p_tenant_id) AS tenant_id
  ),
  vendor_catalog_products AS (
    SELECT DISTINCT
      p.id AS product_id,
      p.brand AS product_brand
    FROM accessible_shops s
    CROSS JOIN parent_tenant pt
    JOIN public.products p ON p.tenant_id = pt.tenant_id
    WHERE s.shop_type = 'vendor_catalog'::public.shop_type_enum
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
      AND (
        ((s.vendor_filters IS NULL OR jsonb_array_length(s.vendor_filters) = 0) AND p.vendor_code = s.vendor_code)
        OR (
          s.vendor_filters IS NOT NULL AND jsonb_array_length(s.vendor_filters) > 0 AND EXISTS (
            SELECT 1
            FROM jsonb_to_recordset(s.vendor_filters) AS vf(vendor_code text, brands text[])
            WHERE vf.vendor_code = p.vendor_code
              AND (vf.brands IS NULL OR array_length(vf.brands, 1) IS NULL OR p.brand = ANY(vf.brands))
          )
        )
      )
  ),
  listing_products AS (
    SELECT DISTINCT
      p.id AS product_id,
      p.brand AS product_brand
    FROM accessible_shops s
    JOIN public.shop_product_listings l ON l.shop_id = s.id
    JOIN public.products p ON p.id = l.product_id
    WHERE s.shop_type <> 'vendor_catalog'::public.shop_type_enum
      AND l.is_active = true
      AND p.is_available = true
      AND coalesce(p.hazardous, false) = false
  ),
  combined AS (
    SELECT product_id, product_brand FROM vendor_catalog_products
    UNION
    SELECT product_id, product_brand FROM listing_products
  )
  SELECT jsonb_build_object(
    'total_products', coalesce((SELECT count(*)::bigint FROM combined), 0),
    'total_brands', coalesce((
      SELECT count(*)::bigint
      FROM (
        SELECT DISTINCT lower(trim(product_brand)) AS brand_key
        FROM combined
        WHERE product_brand IS NOT NULL
          AND trim(product_brand) <> ''
      ) brands
    ), 0)
  );
$$;

CREATE OR REPLACE FUNCTION "public"."delete_shop"("p_shop_id" bigint, "p_tenant_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_books_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  update public.shops
  set
    deleted_at = now(),
    deleted_by = public.current_user_email(),
    is_active = false
  where id = p_shop_id
    and (tenant_id = p_tenant_id or tenant_id = p_tenant_id)
    and deleted_at is null;

  if not found then
    raise exception 'shop not found or already deleted';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."delete_stock_location"("p_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.stock_locations%rowtype;
  v_parent bigint;
begin
  select * into v_row
  from public.stock_locations
  where id = p_id
  for update;

  if not found then
    raise exception 'location not found';
  end if;

  v_parent := v_row.tenant_id;
  perform public._assert_parent_warehouse_tenant(v_parent);

  if not (
    public.user_can_manage_books_tenant(v_parent)
    or public.membership_has_module_action(v_parent, 'global_stock_location', 'delete')
    or public.membership_has_module_action(v_parent, 'global_stock_location', 'edit')
  ) then
    raise exception 'not allowed';
  end if;

  delete from public.stock_locations where id = p_id;

  -- Promote another leaf default if needed
  if not exists (
    select 1 from public.stock_locations l
    where l.tenant_id = v_parent
      and l.is_default = true
      and l.is_active = true
      and public._stock_location_is_leaf(l.id)
  ) then
    update public.stock_locations
    set is_default = true
    where id = (
      select l.id from public.stock_locations l
      where l.tenant_id = v_parent
        and l.is_active = true
        and public._stock_location_is_leaf(l.id)
      order by l.sort_order, l.id
      limit 1
    );
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public.dispatch_delivery_paper(p_tenant_id bigint, p_delivery_paper_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_line public.delivery_paper_line%rowtype;
  v_mov_id bigint;
  v_mov_payload jsonb;
  v_qty integer;
  v_landed numeric;
  v_existing bigint;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
    AND dp.tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  v_existing := public.delivery_paper_dispatch_movement_id(p_delivery_paper_id);
  IF v_existing IS NOT NULL THEN
    IF v_paper.status <> 'dispatched'::public.delivery_paper_status THEN
      UPDATE public.delivery_paper dp
      SET
        status = 'dispatched'::public.delivery_paper_status,
        dispatched_at = coalesce(dp.dispatched_at, now()),
        updated_at = now()
      WHERE dp.id = p_delivery_paper_id;
    END IF;
    PERFORM public.sync_shop_order_from_delivery_paper(
      p_delivery_paper_id,
      'dispatched'::public.delivery_paper_status
    );
    RETURN jsonb_build_object(
      'success', true,
      'status', 'dispatched',
      'movement_id', v_existing,
      'idempotent', true
    );
  END IF;

  IF v_paper.status <> 'packed'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper must be packed before dispatch (current: %)', v_paper.status;
  END IF;

  v_mov_payload := public.create_stock_movement(
    p_tenant_id,
    'issue_outbound'::public.stock_movement_type,
    'Dispatch delivery paper #' || p_delivery_paper_id::text,
    'delivery_paper',
    p_delivery_paper_id::text
  );
  v_mov_id := (v_mov_payload->'movement'->>'id')::bigint;

  FOR v_line IN
    SELECT dpl.*
    FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
      AND dpl.global_stock_id IS NOT NULL
  LOOP
    v_qty := public.delivery_paper_line_packed_qty(v_line.splits);
    IF v_qty <= 0 THEN
      CONTINUE;
    END IF;

    SELECT gsi.landed_cost_bdt INTO v_landed
    FROM public.global_stocks gs
    INNER JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE gs.id = v_line.global_stock_id;

    UPDATE public.delivery_paper_line dpl
    SET unit_cost_landed_snapshot = v_landed, updated_at = now()
    WHERE dpl.id = v_line.id;

    PERFORM public.add_stock_movement_line(
      v_mov_id,
      v_line.global_stock_id,
      v_qty,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL,
      NULL
    );
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM public.stock_movement_lines sml WHERE sml.movement_id = v_mov_id
  ) THEN
    DELETE FROM public.stock_movements WHERE id = v_mov_id;
    RAISE EXCEPTION 'no stock lines to dispatch on paper %', p_delivery_paper_id;
  END IF;

  UPDATE public.delivery_paper_line dpl
  SET
    dispatched_global_stock_id = dpl.global_stock_id,
    updated_at = now()
  WHERE dpl.delivery_paper_id = p_delivery_paper_id
    AND dpl.global_stock_id IS NOT NULL;

  PERFORM public.post_stock_movement(v_mov_id);

  UPDATE public.delivery_paper dp
  SET
    status = 'dispatched'::public.delivery_paper_status,
    dispatched_at = now(),
    updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  PERFORM public.sync_shop_order_from_delivery_paper(
    p_delivery_paper_id,
    'dispatched'::public.delivery_paper_status
  );

  RETURN jsonb_build_object(
    'success', true,
    'status', 'dispatched',
    'movement_id', v_mov_id
  );
END;
$function$;

CREATE OR REPLACE FUNCTION "public"."enqueue_notification"("p_tenant_id" bigint, "p_operating_tenant_id" bigint, "p_audience" "public"."notification_audience", "p_event_type" "text", "p_title" "text", "p_body" "text" DEFAULT NULL::"text", "p_link_path" "text" DEFAULT NULL::"text", "p_entity_type" "text" DEFAULT NULL::"text", "p_entity_id" "text" DEFAULT NULL::"text", "p_recipient_user_ids" "uuid"[] DEFAULT NULL::"uuid"[], "p_module_key" "text" DEFAULT NULL::"text", "p_action" "text" DEFAULT 'view'::"text") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_tenant_id bigint;
  v_notification_id uuid;
  v_recipient_user_ids uuid[];
  v_title text := trim(coalesce(p_title, ''));
  v_event_type text := trim(coalesce(p_event_type, ''));
BEGIN
  IF p_tenant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_tenant_id is required');
  END IF;

  IF v_title = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_title is required');
  END IF;

  IF v_event_type = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'p_event_type is required');
  END IF;

  IF p_audience = 'assignee_only'
     AND (p_recipient_user_ids IS NULL OR cardinality(p_recipient_user_ids) = 0) THEN
    RETURN jsonb_build_object('success', false, 'error', 'assignee_only requires p_recipient_user_ids');
  END IF;

  v_books_tenant_id := public.resolve_books_tenant_id(p_tenant_id);

  v_recipient_user_ids := public.resolve_notification_recipient_user_ids(
    v_books_tenant_id,
    p_operating_tenant_id,
    p_audience,
    p_recipient_user_ids,
    p_module_key,
    p_action
  );

  IF v_recipient_user_ids IS NULL OR cardinality(v_recipient_user_ids) = 0 THEN
    RETURN jsonb_build_object(
      'success', true,
      'notification_id', NULL,
      'tenant_id', v_books_tenant_id,
      'operating_tenant_id', p_operating_tenant_id,
      'recipient_count', 0,
      'recipient_user_ids', '[]'::jsonb
    );
  END IF;

  INSERT INTO public.notifications (
    tenant_id,
    operating_tenant_id,
    event_type,
    title,
    body,
    link_path,
    entity_type,
    entity_id
  )
  VALUES (
    v_books_tenant_id,
    p_operating_tenant_id,
    v_event_type,
    v_title,
    nullif(trim(coalesce(p_body, '')), ''),
    nullif(trim(coalesce(p_link_path, '')), ''),
    nullif(trim(coalesce(p_entity_type, '')), ''),
    nullif(trim(coalesce(p_entity_id, '')), '')
  )
  RETURNING id INTO v_notification_id;

  INSERT INTO public.notification_recipients (notification_id, user_id)
  SELECT v_notification_id, recipient_user_id
  FROM unnest(v_recipient_user_ids) AS recipient_user_id
  ON CONFLICT (notification_id, user_id) DO NOTHING;

  RETURN jsonb_build_object(
    'success', true,
    'notification_id', v_notification_id,
    'tenant_id', v_books_tenant_id,
    'operating_tenant_id', p_operating_tenant_id,
    'recipient_count', cardinality(v_recipient_user_ids),
    'recipient_user_ids', to_jsonb(v_recipient_user_ids)
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."ensure_default_cargo_company"("p_tenant_id" bigint) RETURNS bigint
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
      or public.user_can_manage_books_tenant(p_tenant_id)
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
  where tenant_id = p_tenant_id
    and is_default = true
  limit 1;

  if v_id is not null then
    return v_id;
  end if;

  select id into v_id
  from public.cargo_companies
  where tenant_id = p_tenant_id
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
    tenant_id,
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
    entity_type,
    entity_id,
    currency_code,
    available_balance,
    pending_balance,
    locked_balance
  )
  values (
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
$$;

CREATE OR REPLACE FUNCTION "public"."ensure_dropship_courier_cod_receivable"("p_order_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_books_tenant_id bigint;
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

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  if exists (
    select 1
    from public.cashbook_entries
    where tenant_id = v_books_tenant_id
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
    where tenant_id = v_books_tenant_id
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
    p_tenant_id => v_books_tenant_id,
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
$$;

CREATE OR REPLACE FUNCTION "public"."ensure_preorder_demand_for_procuring_document"("p_document_type" "text", "p_document_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_doc_type text := lower(trim(coalesce(p_document_type, '')));
BEGIN
  IF p_document_id IS NULL THEN
    RETURN;
  END IF;

  IF v_doc_type = 'shop_order' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      placed_quantity,
      delivered_quantity,
      stock_picks
    )
    SELECT
      o.tenant_id,
      'shop_order_item'::public.preorder_demand_source_type,
      oi.id,
      o.profile_id,
      greatest(coalesce(oi.confirmed_quantity, oi.quantity, 0), 0)::integer,
      0,
      '[]'::jsonb
    FROM public.shop_order_items oi
    INNER JOIN public.shop_orders o ON o.id = oi.order_id
    WHERE o.id = p_document_id
      AND o.shop_type_snapshot = 'vendor_catalog'
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      updated_at = now();
  ELSIF v_doc_type = 'pbc_costing_file' THEN
    INSERT INTO public.preorder_demand (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      placed_quantity,
      delivered_quantity,
      stock_picks
    )
    SELECT
      f.tenant_id,
      'pbc_costing_item'::public.preorder_demand_source_type,
      pci.id,
      f.profile_id,
      greatest(
        CASE
          WHEN pci.assigned_shipment_id IS NOT NULL THEN 0
          ELSE coalesce(pci.confirmed_quantity, pci.quantity::integer, 0)
        END,
        0
      )::integer,
      0,
      '[]'::jsonb
    FROM public.product_based_costing_items pci
    INNER JOIN public.product_based_costing_files f ON f.id = pci.product_based_costing_file_id
    WHERE f.id = p_document_id
    ON CONFLICT (source_type, source_id) DO UPDATE SET
      profile_id = coalesce(public.preorder_demand.profile_id, excluded.profile_id),
      updated_at = now();
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_available_stock"("p_stock_id" bigint, "p_tenant_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_tenant_id bigint;
  v_global_qty integer;
  v_other_allocated integer;
begin
  select tenant_id, quantity
  into v_books_tenant_id, v_global_qty
  from public.global_stocks
  where id = p_stock_id;

  if v_books_tenant_id is null then
    return 0;
  end if;

  -- Parent tenant can sell up to the entire global quantity
  if p_tenant_id = v_books_tenant_id then
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

CREATE OR REPLACE FUNCTION "public"."get_cashbook_dashboard_summary"("p_tenant_id" bigint) RETURNS "jsonb"
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
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  if not (
    public.cashbook_staff_can_view(p_tenant_id)
    or public.membership_has_module_action(v_books_id, 'payments', 'view')
    or public.membership_has_module_action(p_tenant_id, 'payments', 'view')
    or public.is_tenant_staff(p_tenant_id)
  ) then
    return jsonb_build_object(
      'success', false,
      'error', 'access denied',
      'tenant_id', v_books_id,
      'tenant_id', v_books_id,
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
  where w.tenant_id = v_books_id
    and w.entity_type = 'tenant'
    and w.entity_id = v_books_id
    and w.currency_code = 'BDT'
  limit 1;

  select l.balance_after
  into v_ledger_cash
  from public.cashbook_entries l
  where l.tenant_id = v_books_id
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
  where tenant_id = v_books_id;

  return jsonb_build_object(
    'success', true,
    'tenant_id', v_books_id,
    'tenant_id', v_books_id,
    'tenant_cash_total', coalesce(v_tenant_cash, 0),
    'courier_cod_holding_total', v_courier_cod_holding,
    'merchant_pending_total', v_merchant_pending,
    'merchant_available_total', v_merchant_available,
    'vendor_payables_total', v_vendor_payables,
    'customer_deposits_total', v_customer_deposits
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_customer_dues_report"("p_tenant_id" bigint, "p_issued_by_tenant_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_aging_bucket" "text" DEFAULT NULL::"text", "p_min_due" numeric DEFAULT 0, "p_over_limit_only" boolean DEFAULT false, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
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
      si.profile_id AS profile_id,
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
    WHERE si.tenant_id = v_books_id
      AND si.invoice_status = 'issued'::public.global_invoice_status
      AND si.profile_id IS NOT NULL
      AND (p_issued_by_tenant_id IS NULL OR si.issued_by_tenant_id = p_issued_by_tenant_id)
  ),
  customer_base AS (
    SELECT
      pi.profile_id,
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
    GROUP BY pi.profile_id
    HAVING sum(pi.due_amount) > 0
  ),
  customer_rows AS (
    SELECT
      cb.*,
      bp.name,
      bp.phone,
      cl.credit_limit
    FROM customer_base cb
    JOIN public.profiles bp ON bp.id = cb.profile_id
    LEFT JOIN LATERAL (
      SELECT max(scga.credit_limit_amount)::numeric(12,2) AS credit_limit
      FROM public.shop_customer_group_access scga
      JOIN public.shops sh ON sh.id = scga.shop_id
      WHERE scga.customer_group_id = bp.customer_group_id
        AND public.resolve_books_tenant_id(sh.tenant_id) = v_books_id
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
      'profile_id', profile_id, 'name', name, 'phone', phone, 'credit_limit', credit_limit,
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
$$;

CREATE OR REPLACE FUNCTION "public"."get_my_dropship_wallet_summary"() RETURNS TABLE("profile_id" bigint, "available_balance" numeric, "pending_balance" numeric, "locked_balance" numeric, "currency" "text")
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  v_bp_id := public.resolve_customer_profile_for_group(v_tenant_id, v_group_id);
  if v_bp_id is null then
    raise exception 'No billing profile linked for your customer group';
  end if;

  select coalesce(w.available_balance, 0)
  into v_available
  from public.cashbook_accounts w
  where w.tenant_id = public.resolve_books_tenant_id(v_tenant_id)
    and w.entity_type = 'customer'
    and w.entity_id = v_bp_id
    and w.currency_code = 'BDT';

  select coalesce(sum(s.reseller_profit), 0)
  into v_pending
  from public.shop_orders o
  join public.dropship_order_settlements s on s.shop_order_id = o.id
  where o.tenant_id = v_tenant_id
    and o.profile_id = v_bp_id
    and o.shop_type_snapshot = 'dropship'
    and o.status = 'payment_received'::public.shop_order_status
    and coalesce(s.reseller_profit, 0) > 0
    and s.merchant_payout_at is null;

  select coalesce(sum(greatest(coalesce(o.cod_collect_amount, 0), 0)), 0)
  into v_locked
  from public.shop_orders o
  where o.tenant_id = v_tenant_id
    and o.profile_id = v_bp_id
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
$$;

CREATE OR REPLACE FUNCTION "public"."get_parent_cash_circulation"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  if not public.user_can_manage_books_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  select
    coalesce(sum(case when type in ('deposit', 'capital_in', 'capital_adjustment', 'manual_adjustment') then amount else 0 end), 0),
    coalesce(sum(case when type in ('withdrawal', 'withdrawal_paid') then amount else 0 end), 0)
  into v_deposits, v_withdrawals
  from public.investor_transactions it
  where it.tenant_id = p_tenant_id;

  select coalesce(sum(coalesce(allocated_cost, invested_amount)), 0) into v_deployed
  from public.shipment_investments
  where tenant_id = p_tenant_id and status = 'active';

  select
    coalesce(sum(due_amount), 0),
    coalesce(sum(paid_amount), 0)
  into v_ar_due, v_ar_paid
  from public.bills
  where tenant_id = p_tenant_id;

  select coalesce(sum(
    public.calculate_landed_unit_cost(gs.shipment_item_id) * gs.quantity
  ), 0) into v_stock_cost
  from public.global_stocks gs
  inner join public.global_stock_types gst on gst.id = gs.stock_type_id
  where gs.tenant_id = p_tenant_id
    and gst.is_sellable = true
    and gs.quantity > 0;

  with invoice_line_margin as (
    select
      ii.invoice_id,
      sum(ii.sell_price_amount * ii.quantity - ii.line_discount_amount) as lines_margin
    from public.global_invoice_items ii
    join public.bills i on i.id = ii.invoice_id
    where i.tenant_id = p_tenant_id
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
    where i.tenant_id = p_tenant_id
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
  where i.tenant_id = p_tenant_id
    and i.invoice_status = 'posted'::public.global_invoice_status
    and i.invoice_date >= date_trunc('month', current_date)::date;

  select coalesce(sum(amount), 0) into v_payouts
  from public.investor_transactions
  where tenant_id = p_tenant_id
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

CREATE OR REPLACE FUNCTION "public"."get_shop_catalog_product_for_customer"("p_tenant_id" bigint, "p_shop_slug" "text", "p_product_id" bigint, "p_listing_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_shop_id bigint;
  v_shop_tenant_id bigint;
  v_books_tenant_id bigint;
  v_shop_name text;
  v_shop_type public.shop_type_enum;
  v_vendor_code text;
  v_order_mode public.shop_order_mode_enum;
  v_is_negotiable boolean;
  v_show_stock_quantity boolean;
  v_default_currency_id bigint;
  v_is_active boolean;
  v_buy_currency_id bigint;
  v_sell_currency_id bigint;
  v_pricing_method text;
  v_markup_percentage numeric;
  v_quantity_display_mode text;
  v_vendor_filters jsonb;
  v_can_browse boolean;
  v_can_see_buy_price boolean;
  v_can_see_sell_price boolean;
  v_can_see_resell_minimum_price boolean;
  v_can_add_to_cart boolean;
  v_can_place_order boolean;
  v_can_negotiate boolean;
  v_can_view_quantity boolean;
  v_can_set_dropship_price boolean;
  v_product jsonb;
begin
  if p_tenant_id is null then
    raise exception 'tenant required';
  end if;
  if p_product_id is null then
    raise exception 'product required';
  end if;
  if public.current_customer_group_id(p_tenant_id) is null then
    raise exception 'access denied';
  end if;

  select
    id, tenant_id, name, shop_type, vendor_code, order_mode,
    is_negotiable, show_stock_quantity, default_currency_id, is_active,
    buy_currency_id, sell_currency_id, pricing_method, markup_percentage, quantity_display_mode,
    vendor_filters
  into
    v_shop_id, v_shop_tenant_id, v_shop_name, v_shop_type, v_vendor_code, v_order_mode,
    v_is_negotiable, v_show_stock_quantity, v_default_currency_id, v_is_active,
    v_buy_currency_id, v_sell_currency_id, v_pricing_method, v_markup_percentage, v_quantity_display_mode,
    v_vendor_filters
  from public.shops
  where slug = p_shop_slug
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if v_shop_id is null or v_is_active is not true then
    raise exception 'shop not found or inactive';
  end if;

  select
    can_browse, can_see_buy_price, can_see_sell_price, can_see_resell_minimum_price,
    can_add_to_cart, can_place_order,
    can_negotiate, can_view_quantity, can_set_dropship_price
  into
    v_can_browse, v_can_see_buy_price, v_can_see_sell_price, v_can_see_resell_minimum_price,
    v_can_add_to_cart, v_can_place_order,
    v_can_negotiate, v_can_view_quantity, v_can_set_dropship_price
  from public.get_shop_permissions_for_customer(v_shop_id);

  if coalesce(v_can_browse, false) is not true then
    raise exception 'access denied';
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_shop_tenant_id);

  if v_shop_type = 'vendor_catalog' then
    select jsonb_build_object(
      'product_id', p.id,
      'product_name', p.name,
      'product_image_url', p.image_url,
      'product_barcode', p.barcode,
      'product_code', p.product_code,
      'product_brand', p.brand,
      'product_category', p.category,
      'vendor_code', p.vendor_code,
      'is_available', p.is_available,
      'country_of_origin', p.country_of_origin,
      'expire_date', p.expire_date,
      'unit_price_amount', case when v_can_see_buy_price then p.list_price_amount else null end,
      'unit_price_currency_id', case when v_can_see_buy_price then p.list_price_currency_id else null end,
      'unit_price_currency_code', case when v_can_see_buy_price then (select code from public.global_currencies where id = p.list_price_currency_id) else null end,
      'unit_price_currency_symbol', case when v_can_see_buy_price then (select symbol from public.global_currencies where id = p.list_price_currency_id) else null end,
      'minimum_sell_price_amount', null,
      'minimum_sell_price_currency_id', null,
      'minimum_sell_price_currency_code', null,
      'minimum_sell_price_currency_symbol', null,
      'available_units', null,
      'global_stock_allocation_id', null,
      'global_stock_id', null,
      'minimum_order_quantity', p.minimum_order_quantity
    )
    into v_product
    from public.products p
    where p.id = p_product_id
      and p.is_available = true
      and coalesce(p.hazardous, false) = false
      and p.tenant_id = v_books_tenant_id
      and (
        ((v_vendor_filters is null or jsonb_array_length(v_vendor_filters) = 0) and p.vendor_code = v_vendor_code)
        or
        (v_vendor_filters is not null and jsonb_array_length(v_vendor_filters) > 0 and exists (
          select 1
          from jsonb_to_recordset(v_vendor_filters) as vf(vendor_code text, brands text[])
          where vf.vendor_code = p.vendor_code
            and (vf.brands is null or array_length(vf.brands, 1) is null or p.brand = any(vf.brands))
        ))
      )
    limit 1;
  else
    select jsonb_build_object(
      'product_id', row.product_id,
      'product_name', row.product_name,
      'product_image_url', row.product_image_url,
      'product_barcode', row.product_barcode,
      'product_code', row.product_code,
      'product_brand', row.product_brand,
      'product_category', row.product_category,
      'vendor_code', row.product_vendor_code,
      'is_available', row.product_is_available,
      'country_of_origin', row.country_of_origin,
      'expire_date', row.expire_date,
      'unit_price_amount', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.computed_sell_price
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.computed_sell_price
        else null
      end,
      'unit_price_currency_id', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then row.sell_price_currency_id
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then row.sell_price_currency_id
        else null
      end,
      'unit_price_currency_code', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select code from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'unit_price_currency_symbol', case
        when v_shop_type = 'dropship' and v_can_see_buy_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        when v_shop_type = 'fixed_price' and v_can_see_sell_price then (select symbol from public.global_currencies where id = row.sell_price_currency_id)
        else null
      end,
      'minimum_sell_price_amount', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_amount else null end,
      'minimum_sell_price_currency_id', case when v_can_see_sell_price and v_shop_type = 'dropship' then row.minimum_sell_price_currency_id else null end,
      'minimum_sell_price_currency_code', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select code from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'minimum_sell_price_currency_symbol', case when v_can_see_sell_price and v_shop_type = 'dropship' then (select symbol from public.global_currencies where id = row.minimum_sell_price_currency_id) else null end,
      'available_units', case
        when not v_can_view_quantity or not coalesce(row.listing_show_quantity, v_show_stock_quantity) then null
        when v_quantity_display_mode = 'original' then greatest(0, row.available_qty)
        when row.display_quantity_override is not null then row.display_quantity_override
        else greatest(0, row.available_qty)
      end,
      'listing_id', row.listing_id,      'stock_grade', case        when row.grade_slug is not null then jsonb_build_object(          'slug', row.grade_slug,          'label', row.grade_label,          'color', row.grade_color        )        else null      end,      'global_stock_allocation_id', row.global_stock_id,
      'global_stock_id', row.global_stock_id,
      'minimum_order_quantity', row.product_moq
    )
    into v_product
    from (
      select
        l.id as listing_id,
        l.global_stock_id,
        case
          when v_shop_type = 'fixed_price' and v_pricing_method = 'markup' then
            public.shop_product_grade_avg_landed_cost(v_shop_tenant_id, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id)) * (1 + v_markup_percentage / 100.0)
          when v_shop_type = 'fixed_price' and v_pricing_method = 'direct_cost' then
            public.shop_product_grade_avg_landed_cost(v_shop_tenant_id, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id))
          else
            l.sell_price_amount
        end as computed_sell_price,
        l.sell_price_currency_id,
        l.minimum_sell_price_amount,
        l.minimum_sell_price_currency_id,
        l.show_quantity as listing_show_quantity,
        l.display_quantity_override,
        p.id as product_id,
        p.name as product_name,
        p.image_url as product_image_url,
        p.barcode as product_barcode,
        p.product_code as product_code,
        p.brand as product_brand,
        p.category as product_category,
        p.vendor_code as product_vendor_code,
        p.is_available as product_is_available,
        p.country_of_origin,
        p.expire_date,
        p.minimum_order_quantity as product_moq,
        public.shop_product_grade_available_units(v_shop_tenant_id, p.id, coalesce(l.grade_tag_id, gs.grade_tag_id)) as available_qty,
        tg.slug as grade_slug,
        tg.name as grade_label,
        tg.color as grade_color
      from public.shop_product_listings l
      join public.products p on p.id = l.product_id
      left join public.global_stocks gs on gs.id = l.global_stock_id
      left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
      left join public.tags tg on tg.id = coalesce(l.grade_tag_id, gs.grade_tag_id)
      where l.shop_id = v_shop_id
        and l.product_id = p_product_id
        and l.is_active = true
        and p.is_available = true
        and coalesce(p.hazardous, false) = false
        and (p_listing_id is null or l.id = p_listing_id)
        and coalesce(l.grade_tag_id, gs.grade_tag_id) is not null
      order by l.id asc
      limit 1
    ) row;
  end if;

  if v_product is null then
    raise exception 'product not found';
  end if;

  return jsonb_build_object(
    'data', v_product,
    'meta', jsonb_build_object(
      'shop', jsonb_build_object(
        'id', v_shop_id,
        'name', v_shop_name,
        'slug', p_shop_slug,
        'shop_type', v_shop_type,
        'vendor_code', v_vendor_code,
        'order_mode', v_order_mode,
        'is_negotiable', v_is_negotiable,
        'show_stock_quantity', v_show_stock_quantity,
        'default_currency_id', v_default_currency_id,
        'is_active', v_is_active,
        'buy_currency_id', v_buy_currency_id,
        'sell_currency_id', v_sell_currency_id,
        'pricing_method', v_pricing_method,
        'markup_percentage', v_markup_percentage,
        'quantity_display_mode', v_quantity_display_mode,
        'vendor_filters', v_vendor_filters
      ),
      'permissions', jsonb_build_object(
        'can_browse', v_can_browse,
        'can_see_buy_price', v_can_see_buy_price,
    'can_see_sell_price', v_can_see_sell_price,
        'can_add_to_cart', v_can_add_to_cart,
        'can_place_order', v_can_place_order,
        'can_negotiate', v_can_negotiate,
        'can_view_quantity', v_can_view_quantity,
        'can_set_dropship_price', v_can_set_dropship_price
      )
    )
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."get_tenant_invoice_book_report"("p_tenant_id" bigint, "p_start_date" "date" DEFAULT NULL::"date", "p_end_date" "date" DEFAULT NULL::"date", "p_search" "text" DEFAULT NULL::"text", "p_invoice_type" "text" DEFAULT NULL::"text", "p_payment_status" "text" DEFAULT NULL::"text", "p_issued_by_tenant_id" bigint DEFAULT NULL::bigint, "p_page" integer DEFAULT 1, "p_page_size" integer DEFAULT 50, "p_skip_count" boolean DEFAULT true) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  v_books_id := public.resolve_books_tenant_id(p_tenant_id);
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
      si.payment_status, si.profile_id AS profile_id, si.due_amount,
      coalesce(nullif(trim(bp.name), ''), nullif(trim(si.recipient_name), ''), 'Unknown') AS customer_name,
      coalesce(child.name, parent.name) AS issued_by_name,
      round((si.total_amount + coalesce(ir.returned, 0)), 2) AS billed,
      round(coalesce(ir.returned, 0), 2) AS returned,
      round(coalesce(ipa.collected_cash, 0), 2) AS collected_cash,
      round(coalesce(ipa.wallet_applied, 0), 2) AS wallet_applied,
      round(coalesce(si.written_off_amount, 0), 2) AS settlement,
      round(coalesce(si.due_amount, 0), 2) AS still_due
    FROM public.bills si
    LEFT JOIN public.profiles bp ON bp.id = si.profile_id
    LEFT JOIN public.tenants child ON child.id = si.issued_by_tenant_id
    LEFT JOIN public.tenants parent ON parent.id = si.tenant_id
    LEFT JOIN invoice_returned ir ON ir.invoice_id = si.id
    LEFT JOIN invoice_payments_agg ipa ON ipa.invoice_id = si.id
    WHERE si.tenant_id = v_books_id
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
      'payment_status', payment_status, 'customer_name', customer_name, 'profile_id', profile_id,
      'issued_by_name', issued_by_name, 'billed', billed, 'returned', returned, 'collected_cash', collected_cash,
      'wallet_applied', wallet_applied, 'settlement', settlement, 'still_due', still_due
    ) ORDER BY invoice_date DESC, id DESC) FROM paged), '[]'::jsonb)
  INTO v_total_count, v_totals, v_rows;

  RETURN jsonb_build_object('totals', coalesce(v_totals, '{}'::jsonb), 'rows', coalesce(v_rows, '[]'::jsonb),
    'page', v_page, 'page_size', v_page_size,
    'total_count', CASE WHEN coalesce(p_skip_count, true) THEN NULL ELSE v_total_count END);
END;
$$;

CREATE OR REPLACE FUNCTION "public"."get_vendor_for_tenant"("p_id" bigint, "p_tenant_id" bigint) RETURNS "public"."vendors"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.vendors;
  v_books_id bigint;
begin
  if p_tenant_id is null then
    if not public.is_superadmin() then
      raise exception 'not allowed';
    end if;

    select * into v_row
    from public.vendors
    where id = p_id
      and tenant_id is null;

    return v_row;
  end if;

  if not public.user_can_access_tenant_fetch(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  select * into v_row
  from public.vendors
  where id = p_id
    and tenant_id = v_books_id;

  return v_row;
end;
$$;

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
  v_books_tenant_id bigint;
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

  if v_order.tenant_id is distinct from p_tenant_id then
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

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

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
      or i.tenant_id = v_books_tenant_id
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

CREATE OR REPLACE FUNCTION "public"."list_catalog_refresh_log"("p_tenant_id" bigint, "p_limit" integer DEFAULT 50) RETURNS TABLE("id" bigint, "tenant_id" bigint, "source" "text", "event_kind" "text", "source_url" "text", "file_name" "text", "ran_at" timestamp with time zone, "products_updated" integer, "duration_seconds" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if not public.can_view_products_for_books_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  select
    l.id,
    l.tenant_id,
    l.source,
    l.event_kind,
    l.source_url,
    l.file_name,
    l.ran_at,
    l.products_updated,
    l.duration_seconds
  from public.catalog_refresh_log l
  where l.tenant_id = p_tenant_id
  order by l.ran_at desc
  limit greatest(1, least(coalesce(p_limit, 50), 200));
end;
$$;

CREATE OR REPLACE FUNCTION "public"."list_child_allocation_summary"("p_stock_id" bigint) RETURNS TABLE("child_tenant_id" bigint, "child_tenant_name" "text", "allocation_id" bigint, "allocated_qty" integer)
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  return query
  select
    t.id as child_tenant_id,
    t.name as child_tenant_name,
    coalesce(gsa.id, 0)::bigint as allocation_id,
    coalesce(gsa.quantity, 0)::integer as allocated_qty
  from public.tenants t
  left join public.global_stock_allocations gsa on gsa.child_tenant_id = t.id and gsa.stock_id = p_stock_id
  where t.parent_id = (select tenant_id from public.global_stocks where id = p_stock_id)
  order by t.name asc;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."list_open_invoices_for_payment"("p_tenant_id" bigint, "p_customer_group_id" bigint DEFAULT NULL::bigint, "p_search" "text" DEFAULT NULL::"text", "p_limit" integer DEFAULT 50, "p_offset" integer DEFAULT 0) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_parent_id bigint;
  v_result jsonb;
begin
  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

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
    where (si.tenant_id = v_parent_id or si.issued_by_tenant_id = p_tenant_id)
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
$$;

CREATE OR REPLACE FUNCTION public.list_shop_order_delivery_paper_qty_by_item(p_tenant_id bigint, p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_by_item jsonb := '{}'::jsonb;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_order_id IS NULL THEN
    RAISE EXCEPTION 'order_id is required';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.shop_orders o
    WHERE o.id = p_order_id
      AND o.shop_type_snapshot = 'vendor_catalog'
      AND o.tenant_id IS NOT DISTINCT FROM p_tenant_id
  ) THEN
    RAISE EXCEPTION 'shop order not found';
  END IF;

  SELECT coalesce(
    jsonb_object_agg(sub.order_item_id::text, sub.papers),
    '{}'::jsonb
  )
  INTO v_by_item
  FROM (
    SELECT
      oi.id AS order_item_id,
      jsonb_agg(
        jsonb_build_object(
          'delivery_paper_id', agg.delivery_paper_id,
          'paper_status', agg.paper_status,
          'quantity', agg.qty,
          'packed_qty', agg.packed_qty,
          'accepted_qty', agg.accepted_qty,
          'conditioned_qty', agg.conditioned_qty,
          'rejected_qty', agg.rejected_qty
        )
        ORDER BY agg.delivery_paper_id
      ) AS papers
    FROM public.shop_order_items oi
    INNER JOIN (
      SELECT
        pd.source_id AS order_item_id,
        dp.id AS delivery_paper_id,
        dp.status AS paper_status,
        coalesce(sum(public.delivery_paper_line_total_qty(dpl.splits)), 0)::integer AS qty,
        coalesce(sum(public.delivery_paper_line_packed_qty(dpl.splits)), 0)::integer AS packed_qty,
        coalesce(sum(public.delivery_paper_line_status_qty(dpl.splits, 'accepted')), 0)::integer AS accepted_qty,
        coalesce(sum(public.delivery_paper_line_status_qty(dpl.splits, 'conditioned')), 0)::integer AS conditioned_qty,
        coalesce(sum(public.delivery_paper_line_status_qty(dpl.splits, 'rejected')), 0)::integer AS rejected_qty
      FROM public.delivery_paper dp
      INNER JOIN public.delivery_paper_line dpl
        ON dpl.delivery_paper_id = dp.id
      INNER JOIN public.preorder_demand pd
        ON pd.id = dpl.preorder_demand_id
        AND pd.source_type = 'shop_order_item'::public.preorder_demand_source_type
      WHERE dp.source_type = 'shop_order'::public.delivery_paper_source_type
        AND dp.source_id = p_order_id
        AND dp.status <> 'cancelled'::public.delivery_paper_status
      GROUP BY pd.source_id, dp.id, dp.status
    ) agg ON agg.order_item_id = oi.id
    WHERE oi.order_id = p_order_id
    GROUP BY oi.id
  ) sub;

  RETURN jsonb_build_object('by_order_item_id', v_by_item);
END;
$function$;

CREATE OR REPLACE FUNCTION public.mark_delivery_paper_packed(p_tenant_id bigint, p_delivery_paper_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_line public.delivery_paper_line%rowtype;
  v_packed integer;
  v_line_total integer;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
    AND dp.tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status = 'packed'::public.delivery_paper_status THEN
    RETURN jsonb_build_object('success', true, 'status', 'packed', 'idempotent', true);
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper must be draft to mark packed (current: %)', v_paper.status;
  END IF;

  FOR v_line IN
    SELECT * FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
  LOOP
    v_packed := public.delivery_paper_line_packed_qty(v_line.splits);
    v_line_total := public.delivery_paper_line_total_qty(v_line.splits);
    IF v_line.global_stock_id IS NOT NULL AND v_packed <= 0 THEN
      RAISE EXCEPTION 'line % has no packed quantity', v_line.id;
    END IF;
    IF v_line.global_stock_id IS NULL AND v_line_total <= 0 AND v_packed <= 0 THEN
      RAISE EXCEPTION 'planning line % has no quantity', v_line.id;
    END IF;
  END LOOP;

  IF NOT EXISTS (
    SELECT 1 FROM public.delivery_paper_line dpl
    WHERE dpl.delivery_paper_id = p_delivery_paper_id
  ) THEN
    RAISE EXCEPTION 'delivery paper has no lines';
  END IF;

  UPDATE public.delivery_paper dp
  SET status = 'packed'::public.delivery_paper_status, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'status', 'packed');
END;
$function$;

CREATE OR REPLACE FUNCTION "public"."paste_batch_code_items"("p_list_id" bigint, "p_start_row_index" integer, "p_rows" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_tenant_id bigint;
  v_existing_count integer;
  v_needed_count integer;
  v_row_count integer;
  v_missing integer;
  v_row jsonb;
  v_offset integer;
  v_barcode text;
  v_product_code text;
  v_batch_id text;
  v_mfg date;
  v_exp date;
  v_cur public.batch_code_items%rowtype;
begin
  if p_rows is null or jsonb_typeof(p_rows) <> 'array' or jsonb_array_length(p_rows) = 0 then
    return jsonb_build_object('created', 0, 'updated', 0);
  end if;

  if p_start_row_index is null or p_start_row_index < 0 then
    raise exception 'start_row_index must be >= 0';
  end if;

  select l.tenant_id
  into v_books_tenant_id
  from public.batch_code_lists l
  where l.id = p_list_id;

  if v_books_tenant_id is null then
    raise exception 'Batch list not found';
  end if;

  if not public.user_can_manage_books_tenant(v_books_tenant_id) then
    raise exception 'Access denied';
  end if;

  v_row_count := jsonb_array_length(p_rows);
  v_needed_count := p_start_row_index + v_row_count;

  select count(*)::integer
  into v_existing_count
  from public.batch_code_items
  where list_id = p_list_id;

  v_missing := greatest(0, v_needed_count - v_existing_count);

  if v_missing > 0 then
    insert into public.batch_code_items (list_id)
    select p_list_id
    from generate_series(1, v_missing);
  end if;

  for v_offset in 0..(v_row_count - 1) loop
    v_row := p_rows -> v_offset;

    select i.*
    into v_cur
    from public.batch_code_items i
    where i.list_id = p_list_id
    order by i.id
    offset p_start_row_index + v_offset
    limit 1;

    if v_cur.id is null then
      continue;
    end if;

    v_barcode := v_cur.barcode;
    v_product_code := v_cur.product_code;
    v_batch_id := v_cur.batch_id;
    v_mfg := v_cur.manufacturing_date;
    v_exp := v_cur.expire_date;

    if v_row ? 'barcode' then
      v_barcode := nullif(trim(v_row ->> 'barcode'), '');
    end if;

    if v_row ? 'product_code' then
      v_product_code := nullif(trim(v_row ->> 'product_code'), '');
    end if;

    if v_row ? 'batch_id' then
      v_batch_id := nullif(trim(v_row ->> 'batch_id'), '');
    end if;

    if v_row ? 'manufacturing_date' then
      begin
        v_mfg := nullif(trim(v_row ->> 'manufacturing_date'), '')::date;
      exception
        when others then
          v_mfg := v_cur.manufacturing_date;
      end;
    end if;

    if v_row ? 'expire_date' then
      begin
        v_exp := nullif(trim(v_row ->> 'expire_date'), '')::date;
      exception
        when others then
          v_exp := v_cur.expire_date;
      end;
    end if;

    if v_mfg is not null and v_exp is null then
      v_exp := (v_mfg + interval '36 months')::date;
    end if;

    update public.batch_code_items
    set
      barcode = v_barcode,
      product_code = v_product_code,
      batch_id = v_batch_id,
      manufacturing_date = v_mfg,
      expire_date = v_exp,
      updated_at = now()
    where id = v_cur.id;
  end loop;

  update public.batch_code_lists
  set updated_at = now()
  where id = p_list_id;

  return jsonb_build_object('created', v_missing, 'updated', v_row_count);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."post_customer_receipt_with_allocations"("p_tenant_id" bigint, "p_profile_id" bigint, "p_received_on" "date", "p_note" "text" DEFAULT NULL::"text", "p_reference" "text" DEFAULT NULL::"text", "p_source" "text" DEFAULT 'customer_cash'::"text", "p_instruments" "jsonb" DEFAULT '[]'::"jsonb", "p_allocations" "jsonb" DEFAULT '[]'::"jsonb", "p_shop_order_id" bigint DEFAULT NULL::bigint, "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_credit_dropship_profit" boolean DEFAULT true, "p_idempotency_key" "text" DEFAULT NULL::"text") RETURNS "public"."pays"
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
  v_settle_currency text := 'BDT';
  v_foreign_amt numeric(12, 2);
  v_fx_rate numeric(15, 6) := 1.000000;
  v_cashbook_point_id bigint;
  v_bill_ids bigint[] := '{}';
  v_sid bigint;
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

  v_parent_id := public.resolve_books_tenant_id(p_tenant_id);

  v_pay := public._kernel_claim_pay_idempotency(v_parent_id, p_idempotency_key);
  if v_pay.id is not null then
    return v_pay;
  end if;

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent_id)
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
      if coalesce(p_credit_dropship_profit, true) then
        perform public.credit_dropship_profit_from_courier_remittance(
          p_tenant_id,
          p_profile_id,
          p_shop_order_id,
          v_pay.id,
          v_leftover,
          v_reference,
          v_amount,
          v_total_alloc
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

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_id, p_idempotency_key);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."post_vendor_credit_refund"("p_credit_note_id" bigint, "p_amount" numeric, "p_cashbook_point_id" bigint, "p_received_on" "date" DEFAULT CURRENT_DATE, "p_note" "text" DEFAULT NULL::"text", "p_settlement_currency_code" "text" DEFAULT 'BDT'::"text", "p_foreign_amount" numeric DEFAULT NULL::numeric, "p_exchange_rate" numeric DEFAULT NULL::numeric, "p_source_currency_code" "text" DEFAULT NULL::"text", "p_transaction_rate" numeric DEFAULT NULL::numeric, "p_cashbook_point_pot_id" bigint DEFAULT NULL::bigint) RETURNS "public"."pays"
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
    or public.user_can_manage_books_tenant(v_cn.tenant_id)
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
      and ca.tenant_id = v_cn.tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_cn.tenant_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  v_reason := coalesce(nullif(trim(coalesce(p_note, '')), ''), 'Vendor credit refund');

  v_base_currency := public.resolve_tenant_base_currency_code(v_cn.tenant_id);

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
      and cpp.tenant_id = v_cn.tenant_id
    order by case when upper(cpp.currency_code) = v_base_currency then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null and coalesce(v_source_currency, '') <> '' then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_cn.tenant_id
      and upper(cpp.currency_code) = v_source_currency
    limit 1;
  end if;

  if v_pot_id is not null and not exists (
    select 1
    from public.cashbook_point_pots cpp
    where cpp.id = v_pot_id
      and cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.tenant_id = v_cn.tenant_id
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
    v_cn.tenant_id,
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
    v_cn.tenant_id,
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
    p_tenant_id => v_cn.tenant_id,
    p_operating_tenant_id => v_cn.issued_by_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_cn.tenant_id,
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

CREATE OR REPLACE FUNCTION "public"."preview_tenant_data_purge"("p_tenant_id" bigint, "p_scope" "text" DEFAULT 'all_hierarchy'::"text", "p_target_child_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    IF NOT (public.is_superadmin() OR public.user_can_manage_books_tenant(p_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Only parent tenant administrators can preview data purges.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_tenant_id OR parent_id = p_tenant_id;

        SELECT count(*) INTO v_shipment_count FROM public.global_shipments WHERE tenant_id = p_tenant_id;
        SELECT count(*) INTO v_stock_count FROM public.global_stocks WHERE tenant_id = p_tenant_id;
        SELECT count(*) INTO v_invoice_count FROM public.bills WHERE tenant_id = p_tenant_id;
        SELECT count(*) INTO v_ledger_count FROM public.cashbook_entries WHERE tenant_id = p_tenant_id;
        SELECT count(*) INTO v_wallets_count FROM public.cashbook_accounts WHERE tenant_id = p_tenant_id;
    ELSE
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        IF NOT EXISTS (SELECT 1 FROM public.tenants WHERE id = p_target_child_id AND parent_id = p_tenant_id) THEN
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
$$;

CREATE OR REPLACE FUNCTION "public"."process_dropship_courier_remittance_uwl"("p_order_id" bigint, "p_net_amount" numeric, "p_courier_charge" numeric DEFAULT 0.00, "p_remittance_ref" "text" DEFAULT NULL::"text") RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_books_tenant_id bigint;
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

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);
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
    where tenant_id = v_books_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_books_tenant_id,
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
    where tenant_id = v_books_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_fee_retained'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_books_tenant_id,
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

end;
$$;

CREATE OR REPLACE FUNCTION "public"."purge_tenant_operational_data"("p_tenant_id" bigint, "p_scope" "text" DEFAULT 'all_hierarchy'::"text", "p_confirmation_slug" "text" DEFAULT ''::"text", "p_target_child_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
    v_parent_slug TEXT;
    v_target_slug TEXT;
    v_target_id BIGINT;
    v_target_tenant_ids BIGINT[];
    v_counts JSONB;
    v_user_id UUID := auth.uid();
    v_user_email TEXT := COALESCE(public.current_user_email(), 'unknown');
BEGIN
    IF NOT (public.is_superadmin() OR public.user_can_manage_books_tenant(p_tenant_id)) THEN
        RAISE EXCEPTION 'Unauthorized: Administrative privileges on the parent tenant required.';
    END IF;

    SELECT slug INTO v_parent_slug FROM public.tenants WHERE id = p_tenant_id AND parent_id IS NULL;
    IF v_parent_slug IS NULL THEN
        RAISE EXCEPTION 'Parent tenant not found or is not a root workspace.';
    END IF;

    IF p_scope = 'all_hierarchy' THEN
        v_target_id := p_tenant_id;
        v_target_slug := v_parent_slug;

        SELECT array_agg(id) INTO v_target_tenant_ids
        FROM public.tenants
        WHERE id = p_tenant_id OR parent_id = p_tenant_id;
    ELSIF p_scope = 'child_only' THEN
        IF p_target_child_id IS NULL THEN
            RAISE EXCEPTION 'Target child tenant ID is required for child_only scope.';
        END IF;

        SELECT slug INTO v_target_slug
        FROM public.tenants
        WHERE id = p_target_child_id AND parent_id = p_tenant_id;

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

    v_counts := public.preview_tenant_data_purge(p_tenant_id, p_scope, p_target_child_id);

    -- PBC master data must never be purged:
    -- product_based_costing_files, product_based_costing_items, product_based_costing_backlog_items

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.sales_return_items WHERE tenant_id = p_tenant_id;
        DELETE FROM public.bill_lines WHERE tenant_id = p_tenant_id;
        DELETE FROM public.bills WHERE tenant_id = p_tenant_id;
    ELSE
        DELETE FROM public.sales_return_items
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE tenant_id = p_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bill_lines
        WHERE invoice_id IN (
            SELECT id FROM public.bills
            WHERE tenant_id = p_tenant_id
              AND issued_by_tenant_id = p_target_child_id
        );
        DELETE FROM public.bills
        WHERE tenant_id = p_tenant_id
          AND issued_by_tenant_id = p_target_child_id;
    END IF;

    DELETE FROM public.dropship_order_settlements WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_orders WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.shop_carts WHERE tenant_id = ANY(v_target_tenant_ids);
    DELETE FROM public.customer_demand_bucket_items WHERE tenant_id = ANY(v_target_tenant_ids);

    IF p_scope = 'all_hierarchy' THEN
        DELETE FROM public.cashbook_entries WHERE tenant_id = p_tenant_id;
        UPDATE public.cashbook_accounts
        SET available_balance = 0.0000,
            pending_balance = 0.0000,
            locked_balance = 0.0000,
            updated_at = now()
        WHERE tenant_id = p_tenant_id;
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
        DELETE FROM public.global_stocks WHERE tenant_id = p_tenant_id;
        DELETE FROM public.global_shipments WHERE tenant_id = p_tenant_id;
    END IF;

    UPDATE public.sales_invoice_counters
    SET last_value = 0
    WHERE tenant_id = ANY(v_target_tenant_ids);

    INSERT INTO public.tenant_data_purge_logs (
        tenant_id,
        target_tenant_id,
        scope,
        executed_by,
        executor_email,
        confirmation_phrase,
        deleted_counts
    ) VALUES (
        p_tenant_id,
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
$$;

CREATE OR REPLACE FUNCTION public.record_delivery_paper_short_pick(p_tenant_id bigint, p_delivery_paper_id bigint, p_line_id bigint, p_picked_qty integer, p_reason text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_line public.delivery_paper_line%rowtype;
  v_requested integer;
  v_short integer;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_picked_qty IS NULL OR p_picked_qty < 0 THEN
    RAISE EXCEPTION 'picked_qty must be >= 0';
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
    AND dp.tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status NOT IN (
    'draft'::public.delivery_paper_status,
    'packed'::public.delivery_paper_status
  ) THEN
    RAISE EXCEPTION 'short pick not allowed when paper status is %', v_paper.status;
  END IF;

  SELECT * INTO v_line
  FROM public.delivery_paper_line dpl
  WHERE dpl.id = p_line_id
    AND dpl.delivery_paper_id = p_delivery_paper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper line not found';
  END IF;

  v_requested := public.delivery_paper_line_packed_qty(v_line.splits);

  IF p_picked_qty >= v_requested THEN
    RAISE EXCEPTION 'short pick requires picked_qty < requested (% >= %)', p_picked_qty, v_requested;
  END IF;

  v_short := v_requested - p_picked_qty;

  INSERT INTO public.delivery_paper_pick_exceptions (
    delivery_paper_id,
    delivery_paper_line_id,
    requested_qty,
    picked_qty,
    reason,
    created_by_email
  ) VALUES (
    p_delivery_paper_id,
    p_line_id,
    v_requested,
    p_picked_qty,
    p_reason,
    public.current_user_email()
  );

  UPDATE public.delivery_paper_line dpl
  SET
    splits = jsonb_build_array(
      jsonb_build_object('quantity', p_picked_qty, 'status', 'packed')
    ),
    updated_at = now()
  WHERE dpl.id = p_line_id;

  UPDATE public.preorder_demand pd
  SET
    open_quantity = coalesce(pd.open_quantity, 0) + v_short,
    updated_at = now()
  WHERE pd.id = v_line.preorder_demand_id;

  RETURN jsonb_build_object(
    'success', true,
    'requested_qty', v_requested,
    'picked_qty', p_picked_qty,
    'short_qty', v_short
  );
END;
$function$;

CREATE OR REPLACE FUNCTION "public"."reverse_cashbook_ledger_entry_for_staff"("p_tenant_id" bigint, "p_ledger_entry_id" "uuid", "p_reason" "text", "p_reference_id" "text" DEFAULT NULL::"text") RETURNS "jsonb"
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
  IF NOT public.cashbook_staff_can_edit(p_tenant_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'access denied');
  END IF;

  IF nullif(trim(p_reason), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reason required');
  END IF;

  v_books_id := public.resolve_books_tenant_id(p_tenant_id);

  SELECT * INTO v_orig FROM public.cashbook_entries WHERE id = p_ledger_entry_id;
  IF v_orig.id IS NULL OR v_orig.tenant_id <> v_books_id THEN
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
    v_orig.tenant_id,
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
    'account', public.get_cashbook_account_balances(
      v_books_id, v_orig.entity_type, v_orig.entity_id, v_orig.currency_code
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION "public"."set_default_stock_location"("p_id" bigint) RETURNS "public"."stock_locations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.stock_locations%rowtype;
begin
  select * into v_row
  from public.stock_locations
  where id = p_id
  for update;

  if not found then
    raise exception 'location not found';
  end if;

  perform public._assert_parent_warehouse_tenant(v_row.tenant_id);

  if not (
    public.user_can_manage_books_tenant(v_row.tenant_id)
    or public.membership_has_module_action(v_row.tenant_id, 'global_stock_location', 'edit')
  ) then
    raise exception 'not allowed';
  end if;

  if not v_row.is_active then
    raise exception 'cannot set inactive location as default';
  end if;

  if not public._stock_location_is_leaf(v_row.id) then
    raise exception 'only leaf locations can be the default put-away';
  end if;

  update public.stock_locations
  set is_default = false
  where tenant_id = v_row.tenant_id
    and is_default = true
    and id <> p_id;

  update public.stock_locations
  set is_default = true
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.staff_close_catalog_procurement(p_order_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_order record;
  v_desk_tenant_id bigint;
BEGIN
  SELECT * INTO v_order FROM public.shop_orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order not found: %', p_order_id;
  END IF;

  v_desk_tenant_id := coalesce(v_order.tenant_id, v_order.tenant_id);

  IF NOT public.is_tenant_staff(v_desk_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF v_order.shop_type_snapshot <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'staff_close_catalog_procurement is only valid for vendor_catalog orders.';
  END IF;

  IF public.normalize_shop_order_procurement_status(v_order.status) <> 'delivered' THEN
    RAISE EXCEPTION 'order must be delivered to close';
  END IF;

  UPDATE public.shop_orders
  SET status = 'closed'::public.shop_order_status, updated_at = now()
  WHERE id = p_order_id;

  RETURN public.get_shop_order_for_staff(v_desk_tenant_id, p_order_id);
END;
$function$;

CREATE OR REPLACE FUNCTION public.submit_stock_physical_count(p_count_id bigint)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count public.stock_physical_counts%rowtype;
BEGIN
  SELECT * INTO v_count
  FROM public.stock_physical_counts
  WHERE id = p_count_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'count session not found';
  END IF;

  IF NOT public.has_active_tenant_membership(v_count.tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  IF v_count.status NOT IN (
    'draft'::public.stock_physical_count_status,
    'counting'::public.stock_physical_count_status
  ) THEN
    RAISE EXCEPTION 'count session cannot be submitted from status %', v_count.status;
  END IF;

  UPDATE public.stock_physical_counts
  SET
    status = 'pending_approval'::public.stock_physical_count_status,
    submitted_at = now(),
    updated_at = now()
  WHERE id = p_count_id;

  RETURN jsonb_build_object('success', true, 'status', 'pending_approval');
END;
$function$;

CREATE OR REPLACE FUNCTION public.sync_delivery_paper_lines_for_demand(p_preorder_demand_id bigint)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_pd public.preorder_demand%rowtype;
  v_source_type public.delivery_paper_source_type;
  v_source_id bigint;
  v_paper_id bigint;
  v_elem jsonb;
  v_stock_id bigint;
  v_qty integer;
  v_close text;
  v_split_status text;
  v_splits jsonb;
  v_paper_status public.delivery_paper_status;
BEGIN
  SELECT * INTO v_pd FROM public.preorder_demand WHERE id = p_preorder_demand_id;
  IF NOT FOUND THEN
    RETURN;
  END IF;

  IF v_pd.source_type = 'shop_order_item'::public.preorder_demand_source_type THEN
    v_source_type := 'shop_order'::public.delivery_paper_source_type;
    SELECT oi.order_id INTO v_source_id
    FROM public.shop_order_items oi
    WHERE oi.id = v_pd.source_id;
  ELSE
    v_source_type := 'pbc_costing_file'::public.delivery_paper_source_type;
    SELECT pci.product_based_costing_file_id INTO v_source_id
    FROM public.product_based_costing_items pci
    WHERE pci.id = v_pd.source_id;
  END IF;

  IF v_source_id IS NULL THEN
    RETURN;
  END IF;

  SELECT dp.id INTO v_paper_id
  FROM public.delivery_paper dp
  WHERE dp.source_type = v_source_type
    AND dp.source_id = v_source_id
    AND dp.status <> 'cancelled'::public.delivery_paper_status
  ORDER BY dp.id DESC
  LIMIT 1;

  IF v_paper_id IS NULL THEN
    INSERT INTO public.delivery_paper (
      tenant_id,
      source_type,
      source_id,
      profile_id,
      status
    ) VALUES (
      coalesce(v_pd.tenant_id, public.resolve_parent_tenant_id(v_pd.tenant_id)),
      v_source_type,
      v_source_id,
      v_pd.profile_id,
      'draft'::public.delivery_paper_status
    )
    RETURNING id INTO v_paper_id;
  END IF;

  DELETE FROM public.delivery_paper_line dpl
  WHERE dpl.delivery_paper_id = v_paper_id
    AND dpl.preorder_demand_id = v_pd.id;

  CREATE TEMP TABLE IF NOT EXISTS _dpl_sync_splits (
    global_stock_id bigint PRIMARY KEY,
    splits jsonb NOT NULL DEFAULT '[]'::jsonb,
    note text
  ) ON COMMIT DROP;

  TRUNCATE _dpl_sync_splits;

  FOR v_elem IN
    SELECT value FROM jsonb_array_elements(coalesce(v_pd.stock_picks, '[]'::jsonb))
  LOOP
    v_stock_id := nullif(v_elem->>'global_stock_id', '')::bigint;
    v_qty := coalesce(
      nullif(v_elem->>'initial_quantity', '')::integer,
      nullif(v_elem->>'quantity', '')::integer,
      0
    );
    IF v_stock_id IS NULL OR v_qty <= 0 THEN
      CONTINUE;
    END IF;
    v_close := lower(trim(coalesce(v_elem->>'close_action', '')));
    v_split_status := public.delivery_paper_close_action_to_split_status(v_close);

    INSERT INTO _dpl_sync_splits (global_stock_id, splits, note)
    VALUES (
      v_stock_id,
      jsonb_build_array(jsonb_build_object('quantity', v_qty, 'status', v_split_status)),
      nullif(trim(coalesce(v_elem->>'note', '')), '')
    )
    ON CONFLICT (global_stock_id) DO UPDATE SET
      splits = _dpl_sync_splits.splits || EXCLUDED.splits,
      note = coalesce(_dpl_sync_splits.note, EXCLUDED.note);
  END LOOP;

  INSERT INTO public.delivery_paper_line (
    delivery_paper_id,
    preorder_demand_id,
    global_stock_id,
    splits,
    note
  )
  SELECT
    v_paper_id,
    v_pd.id,
    s.global_stock_id,
    s.splits,
    s.note
  FROM _dpl_sync_splits s;

  SELECT CASE
    WHEN EXISTS (
      SELECT 1
      FROM public.delivery_paper_line l
      WHERE l.delivery_paper_id = v_paper_id
        AND public.delivery_paper_line_splits_has_status(l.splits, 'packed')
    ) THEN 'packed'::public.delivery_paper_status
    WHEN EXISTS (
      SELECT 1 FROM public.delivery_paper_line l
      WHERE l.delivery_paper_id = v_paper_id
    ) THEN 'delivered'::public.delivery_paper_status
    ELSE 'draft'::public.delivery_paper_status
  END INTO v_paper_status;

  UPDATE public.delivery_paper dp
  SET status = v_paper_status, updated_at = now()
  WHERE dp.id = v_paper_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.sync_shipment_ap_bills(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
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
  v_void_id bigint;
  v_groups jsonb;
  v_grp jsonb;
  v_ccy text;
  v_plug_key text;
  v_group_count int;
  v_slice jsonb;
  v_active_keys text[] := '{}';
  v_elem jsonb;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  perform public._shipment_money_advisory_lock(p_shipment_id);

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := public._shipment_money_workspace_tenant(p_shipment_id);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_books_tenant(v_parent)
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
    for v_void_id in
      select b.id
      from public.bills b
      where b.tenant_id = v_parent
        and b.ap_shipment_id = p_shipment_id
        and b.invoice_type = 'ap'::public.global_invoice_type
        and b.document_kind = 'standard'::public.bill_document_kind
        and b.invoice_status in (
          'issued'::public.global_invoice_status,
          'draft'::public.global_invoice_status
        )
        and coalesce(b.paid_amount, 0) = 0
      order by b.id asc
    loop
      perform public.void_bill(v_void_id);
    end loop;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  foreach v_bucket_text in array enum_range(null::public.global_shipment_cost_bucket)::text[]
  loop
    v_bucket := v_bucket_text::public.global_shipment_cost_bucket;
    v_paper := public._build_shipment_ap_bucket_paper(p_shipment_id, v_ship, v_bucket);
    v_groups := coalesce(v_paper->'currency_groups', '[]'::jsonb);
    v_group_count := jsonb_array_length(v_groups);

    v_profile := case v_bucket
      when 'material'::public.global_shipment_cost_bucket then v_vendor_profile
      when 'freight'::public.global_shipment_cost_bucket then v_cargo_profile
      when 'customs'::public.global_shipment_cost_bucket then v_cargo_profile
      else v_local_profile
    end;

    if v_group_count = 0 then
      for v_void_id in
        select b.id
        from public.bills b
        where b.tenant_id = v_parent
          and b.source_type = 'shipment_cost'
          and b.source_id = p_shipment_id::text
          and b.invoice_type = 'ap'::public.global_invoice_type
          and b.document_kind = 'standard'::public.bill_document_kind
          and b.invoice_status in (
            'issued'::public.global_invoice_status,
            'draft'::public.global_invoice_status
          )
          and coalesce(b.paid_amount, 0) = 0
          and (
            b.source_key = v_bucket::text
            or b.source_key like v_bucket::text || ':%'
          )
        order by b.id asc
      loop
        perform public.void_bill(v_void_id);
      end loop;
      continue;
    end if;

    for v_elem in select value from jsonb_array_elements(v_groups)
    loop
      v_grp := v_elem;
      v_ccy := upper(trim(coalesce(v_grp->>'currency_code', 'BDT')));
      v_plug_key := case
        when v_group_count > 1 then v_bucket::text || ':' || v_ccy
        else v_bucket::text
      end;
      v_amt := round(coalesce((v_grp->>'foreign_total')::numeric, 0), 2);
      v_slice := v_paper
        || jsonb_build_object(
          'foreign_total', v_grp->>'foreign_total',
          'currency_code', v_ccy,
          'currency_symbol', v_grp->>'currency_symbol',
          'currency_groups', jsonb_build_array(v_grp),
          'mixed_currencies', false,
          'lines', coalesce(v_grp->'lines', '[]'::jsonb)
        );

      if coalesce(v_amt, 0) <= 0 or v_profile is null then
        v_bill_id := public._upsert_shipment_ap_bill(
          v_parent,
          v_parent,
          p_shipment_id,
          v_ship.name,
          v_bucket::text,
          v_profile,
          v_amt,
          v_slice,
          v_keep_as_draft,
          v_plug_key
        );
      else
        select u.id
        into v_bill_id
        from public.upsert_draft_bill(
          jsonb_build_object(
            'tenant_id', v_parent,
            'adapter', 'shipment_cost',
            'issued_by_tenant_id', v_parent,
            'shipment_id', p_shipment_id,
            'shipment_name', v_ship.name,
            'ap_kind', v_bucket::text,
            'profile_id', v_profile,
            'amount', v_amt,
            'ap_paper', v_slice,
            'keep_as_draft', v_keep_as_draft,
            'source_key', v_plug_key
          )
        ) u;
      end if;

      if v_bill_id is not null then
        v_active_keys := array_append(v_active_keys, v_plug_key);
        v_bills := v_bills || jsonb_build_object(v_plug_key, v_bill_id);
      end if;
    end loop;
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.tenant_id = v_parent
      and b.source_type = 'shipment_cost'
      and b.source_id = p_shipment_id::text
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.invoice_status in (
        'draft'::public.global_invoice_status,
        'issued'::public.global_invoice_status
      )
      and coalesce(b.paid_amount, 0) = 0
      and b.source_key is not null
      and not (b.source_key = any(v_active_keys))
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  for v_void_id in
    select b.id
    from public.bills b
    where b.tenant_id = v_parent
      and b.ap_shipment_id = p_shipment_id
      and b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and b.ap_kind in ('vendor', 'cargo', 'local')
      and b.invoice_status = 'issued'::public.global_invoice_status
      and coalesce(b.paid_amount, 0) = 0
    order by b.id asc
  loop
    perform public.void_bill(v_void_id);
  end loop;

  return jsonb_build_object('success', true, 'bills', v_bills);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."transfer_dropship_reseller_profit"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_save jsonb;
  v_profile_id bigint;
  v_amount numeric(15,2);
  v_books_tenant_id bigint;
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

  if v_order.tenant_id is distinct from p_tenant_id then
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

  v_profile_id := coalesce(v_order.profile_id, v_settlement.profile_id);
  if v_profile_id is null then
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

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

  if exists (
    select 1
    from public.cashbook_entries u
    where u.tenant_id = v_books_tenant_id
      and u.source_type = 'shop_order'
      and u.source_id = p_order_id::text
      and u.entity_type in ('middleman', 'customer')
      and u.entity_id = v_profile_id
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
    p_tenant_id => v_books_tenant_id,
    p_operating_tenant_id => v_order.tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_profile_id,
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
    'profile_id', v_profile_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION "public"."transfer_wallet_balance"("p_tenant_id" bigint, "p_entity_type" "text", "p_entity_id" bigint, "p_from_bucket" "text", "p_to_bucket" "text", "p_amount" numeric, "p_currency_code" "text" DEFAULT 'BDT'::"text", "p_notes" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_books_tenant_id bigint;
  v_operating_tenant_id bigint;
  v_account_id bigint;
  v_avail numeric(18,4);
  v_pend numeric(18,4);
  v_lock numeric(18,4);
  v_result jsonb;
  v_entity_id bigint;
BEGIN
  v_books_tenant_id := public.resolve_books_tenant_id(p_tenant_id);
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
    v_entity_id := v_books_tenant_id;
  END IF;

  INSERT INTO public.cashbook_accounts (
    tenant_id, entity_type, entity_id, currency_code,
    available_balance, pending_balance, locked_balance
  )
  VALUES (
    v_books_tenant_id, p_entity_type, v_entity_id,
    coalesce(p_currency_code, 'BDT'), 0.0000, 0.0000, 0.0000
  )
  ON CONFLICT (tenant_id, entity_type, entity_id, currency_code)
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
    tenant_id = v_books_tenant_id,
    updated_at = now()
  WHERE id = v_account_id;

  INSERT INTO public.cashbook_entries (
    tenant_id, operating_tenant_id,
    entity_type, entity_id, type, amount, currency_code,
    exchange_rate, base_amount, balance_after, source_type, source_id, metadata
  )
  VALUES (
    v_books_tenant_id, v_operating_tenant_id,
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
    'tenant_id', v_books_tenant_id,
    'tenant_id', v_books_tenant_id,
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

CREATE OR REPLACE FUNCTION "public"."trg_sync_profile_from_cargo_company"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := new.tenant_id;

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

CREATE OR REPLACE FUNCTION "public"."trg_sync_profile_from_vendor"() RETURNS "trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_books_id bigint;
begin
  v_books_id := new.tenant_id;

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

CREATE OR REPLACE FUNCTION "public"."update_catalog_order_rates_for_staff"("p_tenant_id" bigint, "p_order_id" bigint, "p_payload" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
  if not found
     or (v_order.tenant_id is distinct from p_tenant_id) then
    raise exception 'order not found';
  end if;

  update public.shop_orders o
  set
    conversion_rate = case when p_payload ? 'conversion_rate' then (p_payload->>'conversion_rate')::numeric else o.conversion_rate end,
    cargo_rate = case when p_payload ? 'cargo_rate' then (p_payload->>'cargo_rate')::numeric else o.cargo_rate end,
    profit_rate = case when p_payload ? 'profit_rate' then (p_payload->>'profit_rate')::numeric else o.profit_rate end,
    first_offer_rate = case when p_payload ? 'first_offer_rate' then (p_payload->>'first_offer_rate')::numeric else o.first_offer_rate end,
    final_offer_rate = case when p_payload ? 'final_offer_rate' then (p_payload->>'final_offer_rate')::numeric else o.final_offer_rate end,
    profit_basis = case when p_payload ? 'profit_basis' then nullif(p_payload->>'profit_basis', '') else o.profit_basis end,
    updated_at = now()
  where o.id = p_order_id;

  return public.get_shop_order_for_staff(p_tenant_id, p_order_id);
end;
$$;

CREATE OR REPLACE FUNCTION "public"."upsert_preorder_demand"("p_tenant_id" bigint, "p_source_type" "public"."preorder_demand_source_type", "p_source_id" bigint, "p_vendor_id" bigint DEFAULT NULL::bigint, "p_placed_quantity" integer DEFAULT NULL::integer, "p_stock_picks" "jsonb" DEFAULT NULL::"jsonb", "p_notes" "text" DEFAULT NULL::"text") RETURNS "public"."preorder_demand"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_row public.preorder_demand;
  v_line_tenant_id bigint;
  v_doc_status text;
  v_open_qty integer;
  v_delivered integer;
  v_placed integer;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;
  if p_source_id is null then
    raise exception 'source_id is required';
  end if;

  select g.tenant_id, g.open_qty, g.document_status
  into v_line_tenant_id, v_open_qty, v_doc_status
  from public.get_procurement_demand_open_qty(p_source_type, p_source_id) g;

  if v_line_tenant_id is null then
    raise exception 'demand line not found';
  end if;

  if not public.can_access_preorder_demand_tenant(p_tenant_id)
    and not public.can_access_preorder_demand_tenant(v_line_tenant_id) then
    raise exception 'access denied';
  end if;

  if v_line_tenant_id <> p_tenant_id then
    if not exists (
      select 1 from public.tenants t
      where t.id = v_line_tenant_id
        and t.parent_id = p_tenant_id
        and public.user_can_manage_books_tenant(p_tenant_id)
    ) then
      raise exception 'tenant mismatch for demand line';
    end if;
  end if;

  if v_doc_status not in ('procuring', 'packed') then
    raise exception 'document is not open for preorder demand updates';
  end if;

  if p_placed_quantity is not null and v_doc_status <> 'procuring' then
    raise exception 'placed_quantity can only be updated while procuring';
  end if;

  if p_stock_picks is not null and v_doc_status not in ('procuring', 'packed') then
    raise exception 'stock_picks can only be updated while procuring or packed';
  end if;

  if p_placed_quantity is not null and coalesce(p_placed_quantity, 0) < 0 then
    raise exception 'placed_quantity cannot be negative';
  end if;

  if p_stock_picks is not null and not public.validate_preorder_stock_picks(p_stock_picks) then
    raise exception 'invalid stock_picks payload';
  end if;

  v_delivered := case
    when p_stock_picks is not null then public.sum_preorder_stock_picks(p_stock_picks)
    else null
  end;

  select pd.* into v_row
  from public.preorder_demand pd
  where pd.source_type = p_source_type
    and pd.source_id = p_source_id;

  if found then
    v_placed := coalesce(p_placed_quantity, v_row.placed_quantity, 0);
  else
    v_placed := coalesce(p_placed_quantity, 0);
  end if;

  if v_delivered is not null and v_delivered > coalesce(v_open_qty, 0) then
    raise exception 'delivered_quantity cannot exceed need quantity';
  end if;

  insert into public.preorder_demand (
    tenant_id,
    source_type,
    source_id,
    vendor_id,
    placed_quantity,
    delivered_quantity,
    stock_picks,
    notes,
    updated_by_user_id
  ) values (
    v_line_tenant_id,
    p_source_type,
    p_source_id,
    coalesce(p_vendor_id, case when found then v_row.vendor_id else null end),
    v_placed,
    coalesce(v_delivered, case when found then v_row.delivered_quantity else 0 end, 0),
    coalesce(p_stock_picks, case when found then v_row.stock_picks else '[]'::jsonb end, '[]'::jsonb),
    coalesce(nullif(trim(p_notes), ''), case when found then v_row.notes else null end),
    auth.uid()
  )
  on conflict (source_type, source_id) do update set
    vendor_id = case when p_vendor_id is not null then p_vendor_id else preorder_demand.vendor_id end,
    placed_quantity = case when p_placed_quantity is not null then p_placed_quantity else preorder_demand.placed_quantity end,
    delivered_quantity = case when v_delivered is not null then v_delivered else preorder_demand.delivered_quantity end,
    stock_picks = case when p_stock_picks is not null then p_stock_picks else preorder_demand.stock_picks end,
    notes = case when p_notes is not null then nullif(trim(p_notes), '') else preorder_demand.notes end,
    updated_by_user_id = auth.uid(),
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."upsert_stock_location"("p_tenant_id" bigint, "p_code" "text", "p_name" "text", "p_kind" "public"."stock_location_kind" DEFAULT 'bin'::"public"."stock_location_kind", "p_is_pickable" boolean DEFAULT true, "p_sort_order" integer DEFAULT 0, "p_is_active" boolean DEFAULT true, "p_is_default" boolean DEFAULT false, "p_id" bigint DEFAULT NULL::bigint, "p_parent_location_id" bigint DEFAULT NULL::bigint) RETURNS "public"."stock_locations"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_code text;
  v_name text;
  v_row public.stock_locations%rowtype;
  v_action text;
  v_is_leaf boolean;
  v_want_default boolean;
begin
  perform public._assert_parent_warehouse_tenant(p_tenant_id);

  v_action := case when p_id is null then 'create' else 'edit' end;

  if not (
    public.user_can_manage_books_tenant(p_tenant_id)
    or public.membership_has_module_action(p_tenant_id, 'global_stock_location', v_action)
  ) then
    raise exception 'not allowed';
  end if;

  v_code := upper(trim(coalesce(p_code, '')));
  v_name := trim(coalesce(p_name, ''));

  if length(v_code) = 0 then
    raise exception 'code is required';
  end if;
  if length(v_name) = 0 then
    raise exception 'name is required';
  end if;
  if p_kind is null then
    raise exception 'kind is required';
  end if;

  perform public._validate_stock_location_nesting(
    p_kind, p_parent_location_id, p_tenant_id
  );

  if p_id is not null and p_parent_location_id = p_id then
    raise exception 'location cannot be its own parent';
  end if;

  v_want_default := coalesce(p_is_default, false) and coalesce(p_is_active, true);

  if p_id is null then
    if v_want_default then
      update public.stock_locations
      set is_default = false
      where tenant_id = p_tenant_id
        and is_default = true;
    end if;

    insert into public.stock_locations (
      tenant_id,
      parent_location_id,
      code,
      name,
      kind,
      is_default,
      is_pickable,
      sort_order,
      is_active
    )
    values (
      p_tenant_id,
      p_parent_location_id,
      v_code,
      v_name,
      p_kind,
      v_want_default,
      coalesce(p_is_pickable, true),
      coalesce(p_sort_order, 0),
      coalesce(p_is_active, true)
    )
    returning * into v_row;

    if p_parent_location_id is not null then
      update public.stock_locations
      set is_default = false
      where id = p_parent_location_id
        and is_default = true;
    end if;
  else
    update public.stock_locations
    set
      parent_location_id = p_parent_location_id,
      code = v_code,
      name = v_name,
      kind = p_kind,
      is_pickable = coalesce(p_is_pickable, is_pickable),
      sort_order = coalesce(p_sort_order, sort_order),
      is_active = coalesce(p_is_active, is_active)
    where id = p_id
      and tenant_id = p_tenant_id
    returning * into v_row;

    if not found then
      raise exception 'location not found';
    end if;

    v_is_leaf := public._stock_location_is_leaf(v_row.id);

    if v_want_default and not v_is_leaf then
      raise exception 'only leaf locations can be the default put-away';
    end if;

    if v_want_default then
      update public.stock_locations
      set is_default = false
      where tenant_id = p_tenant_id
        and is_default = true
        and id <> p_id;

      update public.stock_locations
      set is_default = true
      where id = p_id;
    elsif coalesce(p_is_default, false) = false and coalesce(p_is_active, true) = false then
      update public.stock_locations
      set is_default = false
      where id = p_id;
    elsif p_is_default is not null and p_is_default = false then
      update public.stock_locations
      set is_default = false
      where id = p_id;
    end if;

    if p_parent_location_id is not null then
      update public.stock_locations
      set is_default = false
      where id = p_parent_location_id
        and is_default = true;
    end if;
  end if;

  if not exists (
    select 1 from public.stock_locations l
    where l.tenant_id = p_tenant_id
      and l.is_default = true
      and l.is_active = true
      and public._stock_location_is_leaf(l.id)
  ) then
    update public.stock_locations
    set is_default = true
    where id = (
      select l.id from public.stock_locations l
      where l.tenant_id = p_tenant_id
        and l.is_active = true
        and public._stock_location_is_leaf(l.id)
      order by l.sort_order, l.id
      limit 1
    );
  end if;

  select * into v_row from public.stock_locations where id = v_row.id;
  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_stock_physical_count_line(p_count_id bigint, p_stock_id bigint, p_counted_qty integer, p_recount_qty integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
  v_count public.stock_physical_counts%rowtype;
  v_stock public.global_stocks%rowtype;
  v_line public.stock_physical_count_lines%rowtype;
BEGIN
  SELECT * INTO v_count
  FROM public.stock_physical_counts
  WHERE id = p_count_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'count session not found';
  END IF;

  IF v_count.status NOT IN (
    'draft'::public.stock_physical_count_status,
    'counting'::public.stock_physical_count_status
  ) THEN
    RAISE EXCEPTION 'count session is not editable';
  END IF;

  IF NOT public.has_active_tenant_membership(v_count.tenant_id)
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO v_stock
  FROM public.global_stocks
  WHERE id = p_stock_id
    AND tenant_id = v_count.tenant_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'stock % not found', p_stock_id;
  END IF;

  IF v_count.location_id IS NOT NULL
     AND v_stock.location_id IS DISTINCT FROM v_count.location_id THEN
    RAISE EXCEPTION 'stock % is outside count location scope', p_stock_id;
  END IF;

  INSERT INTO public.stock_physical_count_lines (
    count_id,
    global_stock_id,
    system_qty,
    counted_qty,
    recount_qty
  ) VALUES (
    p_count_id,
    p_stock_id,
    v_stock.quantity,
    p_counted_qty,
    p_recount_qty
  )
  ON CONFLICT (count_id, global_stock_id) DO UPDATE SET
    system_qty = EXCLUDED.system_qty,
    counted_qty = EXCLUDED.counted_qty,
    recount_qty = COALESCE(EXCLUDED.recount_qty, stock_physical_count_lines.recount_qty),
    updated_at = now()
  RETURNING * INTO v_line;

  UPDATE public.stock_physical_counts
  SET
    status = 'counting'::public.stock_physical_count_status,
    updated_at = now()
  WHERE id = p_count_id;

  RETURN jsonb_build_object('success', true, 'line', to_jsonb(v_line));
END;
$function$;



CREATE OR REPLACE FUNCTION "public"."list_shop_orders_staff_page"("p_tenant_id" bigint, "p_limit" integer DEFAULT 30, "p_search" "text" DEFAULT NULL::"text", "p_status" "text" DEFAULT NULL::"text", "p_shop_id" bigint DEFAULT NULL::bigint, "p_shop_type" "text" DEFAULT NULL::"text", "p_cursor_created_at" timestamp with time zone DEFAULT NULL::timestamp with time zone, "p_cursor_id" bigint DEFAULT NULL::bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
DECLARE
  v_limit integer := greatest(1, least(coalesce(p_limit, 30), 100));
  v_fetch integer := v_limit + 1;
  v_shops jsonb := '[]'::jsonb;
  v_orders jsonb := '[]'::jsonb;
  v_has_more boolean := false;
  v_next_cursor jsonb := null;
BEGIN
  IF NOT public.is_tenant_staff(p_tenant_id) THEN
    RAISE EXCEPTION 'access denied';
  END IF;

  IF p_cursor_created_at IS NULL AND p_cursor_id IS NULL THEN
    IF NOT EXISTS (
      SELECT 1
      FROM public.memberships m
      WHERE (m.tenant_id = p_tenant_id OR m.tenant_id = public.resolve_books_tenant_id(p_tenant_id))
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = true
    ) THEN
      RAISE EXCEPTION 'not allowed';
    END IF;

    SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x.name), '[]'::jsonb)
    INTO v_shops
    FROM (
      SELECT
        s.id,
        s.tenant_id,
        s.name,
        s.slug,
        s.shop_type,
        coalesce(t.name, '')::text AS tenant_name
      FROM public.shops s
      LEFT JOIN public.tenants t ON t.id = s.tenant_id
      WHERE s.tenant_id = p_tenant_id
        AND s.deleted_at IS NULL
      ORDER BY s.name
      LIMIT 500
    ) x;
  END IF;

  WITH base AS (
    SELECT
      o.id,
      o.tenant_id,
      o.shop_id,
      s.name AS shop_name,
      o.customer_group_id,
      cg.name AS customer_group_name,
      o.order_no,
      o.name,
      o.shop_type_snapshot,
      o.is_negotiable_snapshot,
      o.status,
      o.created_at,
      o.updated_at,
      (SELECT count(*)::bigint FROM public.shop_order_items WHERE order_id = o.id) AS item_count,
      coalesce(t.name, '')::text AS tenant_name
    FROM public.shop_orders o
    JOIN public.shops s ON s.id = o.shop_id
    JOIN public.customer_groups cg ON cg.id = o.customer_group_id
    LEFT JOIN public.tenants t ON t.id = o.tenant_id
    WHERE o.tenant_id = p_tenant_id
      AND (p_status IS NULL OR o.status::text = p_status)
      AND (p_shop_id IS NULL OR o.shop_id = p_shop_id)
      AND (p_shop_type IS NULL OR s.shop_type::text = p_shop_type)
      AND (
        p_search IS NULL
        OR o.order_no ILIKE ('%' || p_search || '%')
        OR o.name ILIKE ('%' || p_search || '%')
        OR s.name ILIKE ('%' || p_search || '%')
        OR cg.name ILIKE ('%' || p_search || '%')
        OR t.name ILIKE ('%' || p_search || '%')
      )
      AND (
        p_cursor_created_at IS NULL
        OR (o.created_at, o.id) < (p_cursor_created_at, p_cursor_id)
      )
    ORDER BY o.created_at DESC, o.id DESC
    LIMIT v_fetch
  ),
  page AS (
    SELECT * FROM base ORDER BY created_at DESC, id DESC LIMIT v_limit
  ),
  tail AS (
    SELECT created_at, id FROM page ORDER BY created_at ASC, id ASC LIMIT 1
  )
  SELECT
    coalesce(
      (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.created_at DESC, p.id DESC) FROM page p),
      '[]'::jsonb
    ),
    (SELECT count(*) > v_limit FROM base),
    CASE
      WHEN (SELECT count(*) FROM base) > v_limit THEN
        (SELECT jsonb_build_object('created_at', created_at, 'id', id) FROM tail)
      ELSE NULL
    END
  INTO v_orders, v_has_more, v_next_cursor;

  RETURN jsonb_build_object(
    'shops', v_shops,
    'orders', v_orders,
    'meta', jsonb_build_object(
      'limit', v_limit,
      'has_more', v_has_more,
      'next_cursor', v_next_cursor
    )
  );
END;
$$;
