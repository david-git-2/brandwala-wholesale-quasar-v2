-- Phase 1: BP24-r, BP17-r, BP16-r (schemas source)

DROP FUNCTION IF EXISTS public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text, bigint, bigint);

-- BP17: sales bill stock commit before kernel issue (warehouse orchestration).

CREATE OR REPLACE FUNCTION public._bill_line_global_stock_id(p_line public.bill_lines)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT nullif(p_line.line_meta->'stock_ref'->>'global_stock_id', '')::bigint;
$$;

CREATE OR REPLACE FUNCTION public.commit_sales_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_invoice public.bills;
  v_db_item public.bill_lines%rowtype;
  v_stock_id bigint;
  v_qty integer;
  v_stock record;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_has_stock boolean := false;
begin
  select * into v_invoice from public.bills where id = p_bill_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can commit stock';
  end if;

  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  select sm.id
  into v_mov_id
  from public.stock_movements sm
  where sm.reference_type = 'sales_invoice'
    and sm.reference_id = p_bill_id::text
    and sm.is_posted = true
  order by sm.id desc
  limit 1;

  if v_mov_id is not null then
    return v_mov_id;
  end if;

  select exists (
    select 1
    from public.bill_lines bl
    where bl.invoice_id = p_bill_id
      and public._bill_line_global_stock_id(bl) is not null
  ) into v_has_stock;

  if not v_has_stock then
    return null;
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
    p_bill_id::text,
    'Issued ' || upper(v_invoice.invoice_type::text) || ' Invoice #' || coalesce(v_invoice.invoice_no, p_bill_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  for v_db_item in select * from public.bill_lines where invoice_id = p_bill_id loop
    v_stock_id := public._bill_line_global_stock_id(v_db_item);
    if v_stock_id is null then
      continue;
    end if;

    v_qty := ceil(v_db_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_stock_id for update;
    if v_stock.id is null then
      raise exception 'Stock % not found for line %', v_stock_id, v_db_item.name_snapshot;
    end if;

    if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
       and v_stock.availability <> 'held'::public.stock_availability then
      raise exception 'dropship invoice stock % must be held before issue', v_stock_id;
    end if;

    if v_stock.quantity < v_qty then
      raise exception 'Insufficient stock for % (requested %, available %)', v_db_item.name_snapshot, v_qty, v_stock.quantity;
    end if;

    update public.global_stocks
    set quantity = quantity - v_qty
    where id = v_stock_id;

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
      v_stock_id,
      v_qty,
      v_stock.location_id,
      v_stock.location_id,
      v_stock.availability,
      v_stock.availability
    );
  end loop;

  return v_mov_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.commit_wholesale_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public.commit_sales_bill_stock(p_bill_id);
end;
$$;

GRANT EXECUTE ON FUNCTION public.commit_sales_bill_stock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.commit_wholesale_bill_stock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._bill_line_global_stock_id(public.bill_lines) TO authenticated, service_role;

-- BP17: post_sales_invoice stock via commit_sales_bill_stock

CREATE OR REPLACE FUNCTION public.post_sales_invoice(p_invoice_id bigint) RETURNS void
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
        set line_meta = jsonb_set(
          coalesce(line_meta, '{}'::jsonb),
          '{stock_ref}',
          jsonb_build_object('global_stock_id', v_held_stock_id),
          true
        )
        where id = v_item.id;
      elsif v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'condition bill stock % must be sellable or held (current: %)',
          v_item.global_stock_id, v_stock.availability;
      end if;
    end loop;
  else
    perform public.commit_sales_bill_stock(p_invoice_id);
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
-- BP9 kernel compose / shop / courier / wholesale adapters
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
      parent_tenant_id, invoice_id, shipment_item_id, product_id,
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
      parent_tenant_id, invoice_id, line_kind, name_snapshot,
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
    gs.parent_tenant_id, gs.shipment_item_id, gsi.name, gsi.barcode, gsi.product_code,
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
    parent_tenant_id, invoice_id, line_kind, shipment_item_id, product_id,
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
    if p_profile_id is null then
      raise exception 'payee profile_id is required for AP bills';
    end if;
    v_collection_source := 'profile'::public.collection_source_type;
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

CREATE OR REPLACE FUNCTION public._kernel_upsert_compose_draft_json(p_payload jsonb) RETURNS jsonb
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_tenant_id bigint;
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
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'tenant_id required');
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  if p_payload is null or jsonb_typeof(p_payload) <> 'object' then
    return jsonb_build_object('success', false, 'error', 'payload must be a JSON object');
  end if;

  v_inv := coalesce(p_payload->'invoice', '{}'::jsonb);
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_issue := coalesce((p_payload->>'issue')::boolean, false);
  v_shop_order_id := nullif(p_payload->>'shop_order_id', '')::bigint;
  if v_inv->>'invoice_type' is null or trim(v_inv->>'invoice_type') = '' then
    return jsonb_build_object('success', false, 'error', 'invoice.invoice_type is required');
  end if;

  v_invoice_type := (v_inv->>'invoice_type')::public.global_invoice_type;

  v_channel_meta := coalesce(v_inv->'channel_meta', '{}'::jsonb);
  v_delivery_kind := lower(trim(coalesce(v_channel_meta->>'delivery_kind', 'take')));
  if v_invoice_type = 'ap'::public.global_invoice_type then
    v_delivery_kind := 'take';
  elsif v_delivery_kind not in ('take', 'condition') then
    return jsonb_build_object('success', false, 'error', 'channel_meta.delivery_kind must be take or condition');
  end if;

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
    if v_issue and not exists (
      select 1 from jsonb_array_elements(v_items) e
      where nullif(e.value->>'global_stock_id', '') is not null
    ) then
      return jsonb_build_object('success', false, 'error', 'condition bills require at least one stock line');
    end if;
  end if;

  if v_invoice_type = 'ap'::public.global_invoice_type and exists (
    select 1 from jsonb_array_elements(v_items) e
    where nullif(e.value->>'global_stock_id', '') is not null
  ) then
    return jsonb_build_object('success', false, 'error', 'AP bills cannot have stock lines');
  end if;

  v_channel_meta := coalesce(v_channel_meta, '{}'::jsonb) || jsonb_build_object('delivery_kind', v_delivery_kind);

  select * into v_invoice
  from public.create_sales_invoice(
    v_tenant_id => v_tenant_id,
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

    if v_global_stock_id is null
       and coalesce(v_line_meta->>'is_warehouse_gift', 'false') <> 'true' then
      v_created_item_id := public._insert_bill_line_from_compose_payload(v_parent_id, v_invoice_id, v_item_elem);
      v_item_ids := array_append(v_item_ids, v_created_item_id);
      continue;
    end if;

    if v_global_stock_id is null then
      continue;
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

    v_line_meta := jsonb_set(
      coalesce(v_line_meta, '{}'::jsonb),
      '{stock_ref}',
      jsonb_build_object('global_stock_id', v_global_stock_id),
      true
    );

    insert into public.bill_lines (
      parent_tenant_id,
      invoice_id,
      line_kind,
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
      'stock',
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
        and o.tenant_id = v_tenant_id
        and o.shop_type_snapshot = 'dropship'
    ) then
      return jsonb_build_object('success', false, 'error', 'shop_order_id must be a dropship order for this tenant');
    end if;

    update public.shop_orders
    set
      global_invoice_id = v_invoice_id,
      updated_at = now()
    where id = v_shop_order_id
      and tenant_id = v_tenant_id
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

CREATE OR REPLACE FUNCTION public._kernel_update_compose_draft_json(p_tenant_id bigint, p_invoice_id bigint, p_payload jsonb) RETURNS "jsonb"
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
  v_line_meta jsonb;
  v_stock_parent bigint;
  v_db_item public.bill_lines;
  v_removed_ids bigint[] := '{}';
  v_remove_id bigint;
  v_created_item_id bigint;
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
          books_amount = coalesce(books_amount, v_line_total),
          name_snapshot = case
            when v_item_elem ? 'name_snapshot' then coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), name_snapshot)
            else name_snapshot
          end,
          line_kind = case
            when v_item_elem ? 'line_kind' then lower(trim(v_item_elem->>'line_kind'))
            else line_kind
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
          begin
            v_created_item_id := public._insert_bill_line_from_compose_payload(v_parent_id, p_invoice_id, v_item_elem);
            v_db_item.id := v_created_item_id;
          exception when others then
            return jsonb_build_object('success', false, 'error', sqlerrm, 'code', 'VALIDATION_ERROR');
          end;
          v_has_changes := true;
          continue;
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
        v_line_meta := jsonb_set(
          coalesce(v_db_item.line_meta, '{}'::jsonb),
          '{stock_ref}',
          jsonb_build_object('global_stock_id', v_global_stock_id),
          true
        );

        insert into public.bill_lines (
          parent_tenant_id,
          invoice_id,
          line_kind,
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
          p_invoice_id,
          'stock',
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

CREATE OR REPLACE FUNCTION public._kernel_upsert_dropship_courier_ap(p_order_id bigint, p_keep_as_draft boolean DEFAULT false) RETURNS "jsonb"
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
    v_invoice_no := 'AP-CR-' || v_order.order_no;
    insert into public.bills (
      parent_tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
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
          where b2.parent_tenant_id = v_parent_tenant_id
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



CREATE OR REPLACE FUNCTION public._kernel_issue_wholesale_stock(p_invoice_id bigint, p_items jsonb DEFAULT NULL::jsonb)
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

  if exists (
    select 1
    from public.bill_lines bl
    where bl.invoice_id = p_invoice_id
      and public._bill_line_global_stock_id(bl) is not null
  ) and not exists (
    select 1
    from public.stock_movements sm
    where sm.reference_type = 'sales_invoice'
      and sm.reference_id = p_invoice_id::text
      and sm.is_posted = true
  ) then
    raise exception 'Stock must be committed before issue — call commit_wholesale_bill_stock first';
  end if;

  -- Mark invoice as issued (status = 'issued'::public.global_invoice_status)
  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(payment_status, ''), 'due')
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$function$;


-- ---------------------------------------------------------------------------
-- Kernel wrappers (BP9)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_upsert_compose_draft(p_payload jsonb)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_result jsonb;
  v_bill public.bills;
begin
  v_result := public._kernel_upsert_compose_draft_json(p_payload);
  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'compose upsert failed');
  end if;
  select * into v_bill from public.bills where id = (v_result->>'invoice_id')::bigint;
  if v_bill.id is null then
    raise exception 'compose upsert returned no bill';
  end if;
  return v_bill;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_shop_order_draft(p_payload jsonb)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if nullif(p_payload->>'shop_order_id', '') is null then
    raise exception 'shop_order_id required for shop_order adapter';
  end if;
  return public._kernel_upsert_compose_draft(p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_update_compose_draft(p_tenant_id bigint, p_bill_id bigint, p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_update_compose_draft_json(p_tenant_id, p_bill_id, p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public.create_sales_invoice_from_payload(p_tenant_id bigint, p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_upsert_compose_draft_json(
    coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('tenant_id', p_tenant_id)
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.update_sales_invoice_from_payload(p_tenant_id bigint, p_invoice_id bigint, p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_update_compose_draft_json(p_tenant_id, p_invoice_id, p_payload);
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_dropship_courier_ap_bill(p_order_id bigint, p_keep_as_draft boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_upsert_dropship_courier_ap(p_order_id, p_keep_as_draft);
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_invoice(p_invoice_id bigint, p_items jsonb DEFAULT NULL)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public.issue_wholesale_bill(p_invoice_id, p_items);
end;
$$;

-- Credit/debit notes on standard bills (BP8). Source for migrations; live copy also in baseline until full split.

CREATE OR REPLACE FUNCTION public.create_bill_adjustment(
  p_parent_bill_id bigint,
  p_kind text,
  p_amount numeric,
  p_reason text,
  p_issue boolean DEFAULT true,
  p_refund_amount numeric DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_lines jsonb DEFAULT '[]'::jsonb
) RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_parent public.bills;
  v_kind public.bill_document_kind;
  v_row public.bills;
  v_no text;
  v_reason text;
  v_amount numeric(12, 2);
  v_status public.global_invoice_status;
  v_refund numeric(12, 2);
  v_child_due numeric(12, 2);
  v_pay public.pays;
  v_pay_source text;
  v_line_elem jsonb;
  v_line_total numeric(12, 2);
  v_books numeric(12, 2);
  v_line_kind text;
  v_stock_id bigint;
  v_pot_id bigint;
  v_lines_sum numeric(12, 2) := 0.00;
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

  v_status := case
    when coalesce(p_issue, true) then 'issued'::public.global_invoice_status
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
        line_meta
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
            when v_stock_id is not null
            then jsonb_build_object(
              'stock_ref',
              jsonb_build_object('global_stock_id', v_stock_id)
            )
            else '{}'::jsonb
          end
          || case
            when nullif(trim(coalesce(v_line_elem ->> 'parent_line_id', '')), '') is not null
            then jsonb_build_object('parent_line_id', v_line_elem ->> 'parent_line_id')
            else '{}'::jsonb
          end
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

    v_pay_source := case
      when v_parent.invoice_type = 'ap'::public.global_invoice_type then 'ap_payout'
      else 'customer_cash'
    end;

    v_pot_id := public._kernel_ensure_cashbook_point_pot(
      v_parent.parent_tenant_id,
      p_cashbook_point_id,
      'BDT'
    );

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
      cashbook_point_pot_id,
      source_currency_code,
      transaction_rate
    ) values (
      v_parent.parent_tenant_id,
      v_parent.profile_id,
      v_pay_source,
      v_refund,
      0,
      current_date,
      'cash',
      v_reason,
      p_cashbook_point_id,
      v_pot_id,
      'BDT',
      1.000000
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
        'label', case
          when v_parent.invoice_type = 'ap'::public.global_invoice_type
          then 'Vendor credit note cash refund'
          else 'Customer credit note cash refund'
        end,
        'payment_id', v_pay.id,
        'credit_note_id', v_row.id,
        'credit_note_no', v_row.invoice_no,
        'parent_bill_id', v_parent.id,
        'parent_invoice_no', v_parent.invoice_no,
        'cashbook_point_pot_id', v_pot_id,
        'source_currency_code', coalesce(v_pay.source_currency_code, 'BDT'),
        'transaction_rate', coalesce(v_pay.transaction_rate, 1.000000)
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

-- BP12 + BP11 custody + WA13 bounce (source for migrations).

ALTER TABLE public.pay_instruments
  ADD COLUMN IF NOT EXISTS bounced_at timestamptz;

-- ---------------------------------------------------------------------------
-- BP12: settlements-aware payment reverse
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_reverse_payment(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_payment public.pays;
  v_parent_id bigint;
  v_bill_id bigint;
  v_bill_ids bigint[] := '{}';
  v_leftover numeric(12, 2);
  v_reason text;
  v_shipment_ids bigint[] := '{}';
  v_sid bigint;
  v_cashbook_point_id bigint;
begin
  if p_tenant_id is null or p_payment_id is null then
    raise exception 'Tenant and payment are required.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required to void a payment.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);

  select * into v_payment
  from public.pays
  where id = p_payment_id
    and tenant_id = v_parent_id
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

  if v_payment.source = 'store_credit' then
    raise exception 'Store-credit application payments cannot be voided here.';
  end if;

  select coalesce(array_agg(distinct x.bid), '{}')
  into v_bill_ids
  from (
    select coalesce(pa.bill_id, pa.global_invoice_id) as bid
    from public.pay_allocations pa
    where pa.payment_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    where bs.allocator_kind = 'pay'
      and bs.allocator_id = v_payment.id
    union
    select bs.bill_id as bid
    from public.bill_settlements bs
    join public.pay_allocations pa on pa.id = bs.pay_allocation_id
    where pa.payment_id = v_payment.id
  ) x
  where x.bid is not null;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public._kernel_lock_bills(array[v_bill_id]);
    select b.ap_shipment_id into v_sid
    from public.bills b
    where b.id = v_bill_id and b.ap_shipment_id is not null;
    if v_sid is not null and not (v_sid = any(v_shipment_ids)) then
      v_shipment_ids := array_append(v_shipment_ids, v_sid);
    end if;
  end loop;

  delete from public.bill_settlements bs
  where bs.pay_allocation_id in (
    select pa.id from public.pay_allocations pa where pa.payment_id = v_payment.id
  );

  delete from public.bill_settlements bs
  where bs.allocator_kind = 'pay'
    and bs.allocator_id = v_payment.id;

  delete from public.pay_allocations
  where payment_id = v_payment.id;

  foreach v_bill_id in array v_bill_ids
  loop
    perform public.recompute_global_invoice_payment_status(v_bill_id);
  end loop;

  v_leftover := coalesce(v_payment.unallocated_amount, 0.00);

  if v_payment.source = 'ap_payout' then
    select pi.cashbook_point_id into v_cashbook_point_id
    from public.pay_instruments pi
    where pi.payment_id = v_payment.id
    order by pi.sort_order, pi.id
    limit 1;

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => coalesce(v_payment.tenant_id, p_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_ap_payout',
        'transaction_type', 'ap_payout_reversal',
        'label', 'Void AP payout',
        'payment_id', v_payment.id,
        'reason', v_reason,
        'cashbook_point_pot_id', v_payment.cashbook_point_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => coalesce(v_cashbook_point_id, v_payment.cashbook_point_id)
    );
  elsif v_payment.source = 'commission' then
    v_cashbook_point_id := coalesce(v_payment.cashbook_point_id, v_cashbook_point_id);

    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_id,
      p_operating_tenant_id => coalesce(v_payment.tenant_id, p_tenant_id),
      p_entity_type => 'tenant',
      p_entity_id => v_parent_id,
      p_type => 'credit',
      p_amount => v_payment.amount,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'payout',
      p_source_id => v_payment.id::text,
      p_metadata => jsonb_build_object(
        'section', 'payments',
        'purpose', 'void_commission_payout',
        'transaction_type', 'profit_paid_out_reversal',
        'label', 'Void commission payout',
        'payment_id', v_payment.id,
        'reason', v_reason,
        'cashbook_point_pot_id', v_payment.cashbook_point_pot_id
      ),
      p_allow_overdraft => true,
      p_cashbook_point_id => v_cashbook_point_id
    );

    if v_payment.profile_id is not null then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_payment.profile_id,
        p_type => 'credit',
        p_amount => v_payment.amount,
        p_currency_code => 'BDT',
        p_exchange_rate => 1.000000,
        p_source_type => 'payout',
        p_source_id => v_payment.id::text,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_commission_payout_profile',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true
      );
    end if;
  elsif v_payment.source in ('customer_cash', 'bank', 'courier_remittance') then
    if coalesce(v_payment.amount, 0.00) > 0.00 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => v_parent_id,
        p_operating_tenant_id => p_tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => v_parent_id,
        p_type => 'debit',
        p_amount => case
          when coalesce(v_payment.source_currency_code, 'BDT') <> 'BDT'
            then coalesce(v_payment.source_amount, v_payment.amount)
          else v_payment.amount
        end,
        p_currency_code => coalesce(nullif(trim(v_payment.source_currency_code), ''), 'BDT'),
        p_exchange_rate => coalesce(v_payment.transaction_rate, 1.000000),
        p_source_type => case
          when v_payment.source = 'courier_remittance' then 'shop_order'
          else 'sales_invoice'
        end,
        p_source_id => case
          when v_payment.source = 'courier_remittance' then coalesce(v_payment.shop_order_id::text, v_payment.id::text)
          else v_payment.id::text
        end,
        p_metadata => jsonb_build_object(
          'section', 'payments',
          'purpose', 'void_batch_payment_received',
          'payment_id', v_payment.id,
          'reason', v_reason
        ),
        p_allow_overdraft => true,
        p_cashbook_point_id => v_payment.cashbook_point_id
      );
    end if;

    if v_leftover > 0.00 and v_payment.profile_id is not null
       and v_payment.source in ('customer_cash', 'bank') then
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
          'reason', v_reason
        ),
        p_allow_overdraft => true
      );
    end if;
  else
    raise exception 'Cannot void payment source %.', v_payment.source;
  end if;

  update public.pays
  set
    voided_at = now(),
    note = trim(
      coalesce(note, '')
      || case when coalesce(note, '') = '' then '' else E'\n' end
      || '[VOIDED] ' || v_reason
    )
  where id = v_payment.id;

  if coalesce(array_length(v_shipment_ids, 1), 0) > 0 then
    foreach v_sid in array v_shipment_ids
    loop
      perform public.refresh_global_shipment_fx_from_ap_payments(v_sid);
    end loop;
  end if;

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment.id,
    'customer_group_id', v_payment.customer_group_id
  );
end;
$$;

CREATE OR REPLACE FUNCTION public.void_customer_receipt(
  p_tenant_id bigint,
  p_payment_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public._kernel_reverse_payment(p_tenant_id, p_payment_id, p_reason);
end;
$$;

CREATE OR REPLACE FUNCTION public.reverse_pay(
  p_payment_id bigint,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
  v_reason text;
begin
  select * into v_pay from public.pays where id = p_payment_id;
  if v_pay.id is null then
    raise exception 'Payment not found.';
  end if;

  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;

  perform public._kernel_reverse_payment(v_pay.tenant_id, p_payment_id, v_reason);
end;
$$;

-- ---------------------------------------------------------------------------
-- BP11: profile custody → bill
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public._kernel_apply_custody_to_bill(
  p_tenant_id bigint,
  p_bill_id bigint,
  p_books_amount numeric
)
RETURNS public.bill_settlements
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_parent_id bigint;
  v_avail numeric(18, 4);
  v_books numeric(12, 2);
  v_open numeric(12, 2);
  v_row public.bill_settlements;
  v_txn numeric(12, 2);
  v_rate numeric(15, 6);
  v_delta numeric(12, 2);
  v_ledger jsonb;
  v_entry_id uuid;
  v_anchor bigint;
  v_source_key text;
begin
  if not public.membership_has_module_action(p_tenant_id, 'payments', 'allocate_payment') then
    raise exception 'Permission denied.';
  end if;

  v_parent_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_books := round(coalesce(p_books_amount, 0), 2);
  if v_books <= 0 then
    raise exception 'Amount must be greater than zero.';
  end if;

  perform public._kernel_lock_bills(array[p_bill_id]);

  select * into v_bill from public.bills where id = p_bill_id;
  if v_bill.id is null then raise exception 'Bill not found.'; end if;
  if v_bill.parent_tenant_id <> v_parent_id then raise exception 'Bill tenant mismatch.'; end if;
  if v_bill.profile_id is null then raise exception 'Bill has no profile.'; end if;
  if v_bill.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Bill is not issued.';
  end if;
  if coalesce(v_bill.document_kind, 'standard'::public.bill_document_kind)
    <> 'standard'::public.bill_document_kind then
    raise exception 'Custody applies to standard bills only.';
  end if;

  v_open := coalesce(
    (public.get_bill_net_balances(p_bill_id)->>'open_books')::numeric,
    v_bill.due_amount,
    0
  );
  if v_books > v_open then
    raise exception 'Amount % exceeds open bill balance %.', v_books, v_open;
  end if;

  select coalesce(ca.available_balance, 0)
  into v_avail
  from public.cashbook_accounts ca
  where ca.parent_tenant_id = v_parent_id
    and ca.entity_type = 'customer'
    and ca.entity_id = v_bill.profile_id
    and ca.currency_code = 'BDT';

  if v_avail < v_books then
    raise exception 'Insufficient profile custody (available %).', v_avail;
  end if;

  v_source_key := 'custody_apply:' || p_bill_id::text || ':' || gen_random_uuid()::text;

  v_ledger := public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => v_bill.profile_id,
    p_type => 'debit',
    p_amount => v_books,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'bill_settlement',
    p_source_id => v_source_key,
    p_metadata => jsonb_build_object(
      'section', 'payments',
      'purpose', 'apply_custody_to_bill',
      'transaction_type', 'custody_apply',
      'label', 'Applied custody to bill',
      'bill_id', p_bill_id
    ),
    p_allow_overdraft => false
  );

  v_entry_id := (v_ledger->>'id')::uuid;
  v_anchor := abs(hashtext(v_entry_id::text));

  select sa.allocated_txn_amount, sa.allocated_books_amount, sa.books_rate_at_alloc, sa.fx_realized_books_delta
  into v_txn, v_books, v_rate, v_delta
  from public._kernel_settlement_amounts_from_pay_alloc(v_bill, null, v_books) sa;

  insert into public.bill_settlements (
    parent_tenant_id, bill_id, allocator_kind, allocator_id,
    allocated_txn_amount, allocated_books_amount, books_rate_at_alloc, fx_realized_books_delta
  ) values (
    v_bill.parent_tenant_id, p_bill_id, 'custody_entry', v_anchor,
    v_txn, v_books, v_rate, v_delta
  )
  returning * into v_row;

  update public.cashbook_entries
  set metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
    'bill_settlement_id', v_row.id,
    'custody_entry_uuid', v_entry_id
  )
  where id = v_entry_id;

  perform public.recompute_global_invoice_payment_status(p_bill_id);

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- WA13: cheque bounce (whole pay)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.bounce_cheque_instrument(
  p_tenant_id bigint,
  p_instrument_id bigint,
  p_reason text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_inst public.pay_instruments;
  v_pay public.pays;
  v_reason text;
begin
  v_reason := nullif(trim(coalesce(p_reason, '')), '');
  if v_reason is null then
    raise exception 'A reason is required.';
  end if;

  select * into v_inst
  from public.pay_instruments
  where id = p_instrument_id
  for update;

  if v_inst.id is null then
    raise exception 'Instrument not found.';
  end if;

  if upper(trim(v_inst.payment_method_code)) <> 'CHEQUE' then
    raise exception 'Instrument is not a cheque.';
  end if;

  if v_inst.bounced_at is not null then
    raise exception 'Cheque already marked bounced.';
  end if;

  select * into v_pay from public.pays where id = v_inst.payment_id for update;
  if v_pay.voided_at is not null then
    raise exception 'Payment is already voided.';
  end if;

  update public.pay_instruments
  set bounced_at = now()
  where id = v_inst.id;

  perform public.reverse_pay(
    v_pay.id,
    'Cheque bounced: ' || v_reason
  );

  return jsonb_build_object(
    'success', true,
    'payment_id', v_pay.id,
    'instrument_id', v_inst.id
  );
end;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_reverse_payment(bigint, bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.reverse_pay(bigint, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_apply_custody_to_bill(bigint, bigint, numeric) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bounce_cheque_instrument(bigint, bigint, text) TO authenticated, service_role;

-- BP17: drop physical stock column; view compat from line_meta.stock_ref
CREATE OR REPLACE VIEW public.global_invoice_items WITH (security_invoker='false') AS
 SELECT id,
    parent_tenant_id AS tenant_id,
    parent_tenant_id,
    invoice_id,
    ((line_meta -> 'stock_ref'::text) ->> 'global_stock_id'::text)::bigint AS global_stock_id,
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
    line_meta,
    line_kind,
    currency_code,
    books_amount
   FROM public.bill_lines;

DROP INDEX IF EXISTS public.global_invoice_items_global_stock_id_idx;
ALTER TABLE public.bill_lines DROP COLUMN IF EXISTS global_stock_id;

CREATE INDEX global_invoice_items_global_stock_id_idx ON public.bill_lines USING btree (
  (((line_meta -> 'stock_ref'::text) ->> 'global_stock_id'::text)::bigint)
) WHERE ((line_meta -> 'stock_ref'::text) ->> 'global_stock_id'::text) IS NOT NULL;
