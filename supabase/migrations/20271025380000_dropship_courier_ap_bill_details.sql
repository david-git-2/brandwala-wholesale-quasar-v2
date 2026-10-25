CREATE OR REPLACE FUNCTION "public"."_build_dropship_courier_ap_paper"(
  "p_order" "public"."shop_orders",
  "p_courier" "public"."courier_services",
  "p_delivery" numeric,
  "p_cod" numeric,
  "p_total" numeric
) RETURNS "jsonb"
    LANGUAGE "plpgsql" IMMUTABLE
    SET "search_path" TO 'public'
    AS $$
declare
  v_lines jsonb := '[]'::jsonb;
  v_total numeric(12, 2);
begin
  v_total := round(coalesce(p_total, 0), 2);

  if coalesce(p_delivery, 0) > 0 then
    v_lines := v_lines || jsonb_build_array(
      jsonb_build_object(
        'description', 'Delivery charge',
        'amount', round(p_delivery, 2),
        'currency_code', 'BDT',
        'currency_symbol', '৳'
      )
    );
  end if;

  if coalesce(p_cod, 0) > 0 then
    v_lines := v_lines || jsonb_build_array(
      jsonb_build_object(
        'description', 'COD / cash handling',
        'amount', round(p_cod, 2),
        'currency_code', 'BDT',
        'currency_symbol', '৳'
      )
    );
  end if;

  if jsonb_array_length(v_lines) = 0 and v_total > 0 then
    v_lines := jsonb_build_array(
      jsonb_build_object(
        'description', format('Courier charges — order %s', p_order.order_no),
        'amount', v_total,
        'currency_code', 'BDT',
        'currency_symbol', '৳'
      )
    );
  end if;

  return jsonb_build_object(
    'paper', 'courier',
    'lines', v_lines,
    'currency_groups', jsonb_build_array(
      jsonb_build_object(
        'currency_code', 'BDT',
        'currency_symbol', '৳',
        'foreign_total', v_total,
        'lines', v_lines
      )
    ),
    'mixed_currencies', false,
    'foreign_total', v_total,
    'currency_code', 'BDT',
    'currency_symbol', '৳',
    'bdt_amount', v_total,
    'order_no', p_order.order_no,
    'courier_name', p_courier.name,
    'courier_awb_number', p_order.courier_awb_number,
    'tracking_url', p_order.tracking_url,
    'recipient_name', p_order.recipient_name,
    'recipient_phone', p_order.recipient_phone,
    'shipping_address', p_order.shipping_address
  );
end;
$$;

ALTER FUNCTION "public"."_build_dropship_courier_ap_paper"("p_order" "public"."shop_orders", "p_courier" "public"."courier_services", "p_delivery" numeric, "p_cod" numeric, "p_total" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_sync_dropship_courier_ap_bill_details"(
  "p_bill_id" bigint,
  "p_order_id" bigint,
  "p_allow_line_sync" boolean DEFAULT true
) RETURNS "void"
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
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.parent_tenant_id, 'charge', 'Delivery charge', 1,
      v_delivery, 0, v_delivery, v_delivery,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'delivery')
    );
    v_charges_total := v_charges_total + v_delivery;
  end if;

  if v_cod > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.parent_tenant_id, 'charge', 'COD / cash handling', 1,
      v_cod, 0, v_cod, v_cod,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('charge_type', 'cod')
    );
    v_charges_total := v_charges_total + v_cod;
  end if;

  if v_charges_total = 0 and coalesce(v_bill.total_amount, 0) > 0 then
    insert into public.bill_lines (
      invoice_id, parent_tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.parent_tenant_id, 'charge',
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

ALTER FUNCTION "public"."_sync_dropship_courier_ap_bill_details"("p_bill_id" bigint, "p_order_id" bigint, "p_allow_line_sync" boolean) OWNER TO "postgres";

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

ALTER FUNCTION "public"."upsert_dropship_courier_ap_bill"("p_order_id" bigint, "p_keep_as_draft" boolean) OWNER TO "postgres";

-- Backfill existing dropship courier AP bills (e.g. legacy INV-INV-* numbers, empty lines).
do $$
declare
  r record;
  v_order_id bigint;
  v_order_no text;
begin
  for r in
    select b.id, b.parent_tenant_id, b.source_id, b.paid_amount, b.invoice_no
    from public.bills b
    where b.invoice_type = 'ap'::public.global_invoice_type
      and b.document_kind = 'standard'::public.bill_document_kind
      and (
        b.source_type = 'dropship_courier'
        or (b.source_type = 'shop_order' and coalesce(b.source_key, '') = 'courier')
      )
  loop
    v_order_id := r.source_id::bigint;
    perform public._sync_dropship_courier_ap_bill_details(
      r.id,
      v_order_id,
      coalesce(r.paid_amount, 0) = 0
    );

    if coalesce(r.paid_amount, 0) = 0 and r.invoice_no not like 'AP-CR-%' then
      select o.order_no into v_order_no
      from public.shop_orders o
      where o.id = v_order_id;

      if v_order_no is not null then
        update public.bills b
        set invoice_no = 'AP-CR-' || v_order_no,
            updated_at = now()
        where b.id = r.id
          and not exists (
            select 1
            from public.bills b2
            where b2.parent_tenant_id = r.parent_tenant_id
              and b2.invoice_no = 'AP-CR-' || v_order_no
              and b2.id <> r.id
          );
      end if;
    end if;
  end loop;
end;
$$;
