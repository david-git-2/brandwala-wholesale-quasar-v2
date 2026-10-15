-- Restore create_sales_invoice after BP3 dropped p_billing_profile_id signatures.
-- Also replace create_sales_invoice_from_payload so it calls p_profile_id.

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
    if not exists (
      select 1 from public.profiles
      where id = p_profile_id
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
    updated_at = now()
  where id = v_invoice_id;

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

GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, bigint, public.global_invoice_type, public.global_source_module, text, text, text, bigint, numeric, text) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.create_sales_invoice(bigint, text, public.global_invoice_type, bigint, bigint, text, text, text, public.retail_billing_mode, date, text, date) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.create_sales_invoice_from_payload(bigint, jsonb) TO authenticated;
