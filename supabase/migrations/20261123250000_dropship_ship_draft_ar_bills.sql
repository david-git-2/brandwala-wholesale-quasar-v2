-- Dropship ship: draft customer AR + draft courier AR (SO-CA1 ship slice)

CREATE OR REPLACE FUNCTION public._sync_dropship_courier_ar_bill_details(
  p_bill_id bigint,
  p_order_id bigint,
  p_allow_line_sync boolean DEFAULT true
) RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
declare
  v_bill public.bills;
  v_order public.shop_orders;
  v_courier public.courier_services;
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_discount numeric(12, 2);
  v_net numeric(12, 2);
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

  perform public.recompute_dropship_cod_collect_amount(p_order_id);
  select * into v_order from public.shop_orders where id = p_order_id;

  v_cod_face := round(greatest(coalesce(v_order.cod_collect_amount, 0), 0), 2);
  v_rate := round(coalesce(v_order.cod_charge_amount, 0), 2);
  v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
  v_discount := round(v_rate + v_delivery, 2);
  v_net := greatest(v_cod_face - v_discount, 0);

  v_note := format(
    'Courier receivable — %s — order %s%s',
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
    'cod_collect_amount', v_cod_face,
    'cod_charge_amount', v_rate,
    'delivery_charge_amount', v_delivery,
    'courier_ar_net', v_net,
    'dropship_courier_ar', true
  );

  update public.bills
  set
    note = v_note,
    subtotal_amount = v_cod_face,
    discount_amount = v_discount,
    total_amount = v_net,
    due_amount = greatest(v_net - coalesce(paid_amount, 0), 0),
    recipient_name = v_order.recipient_name,
    recipient_phone = v_order.recipient_phone,
    recipient_address = v_order.shipping_address,
    channel_meta = v_meta,
    updated_at = now()
  where id = p_bill_id;

  if not p_allow_line_sync then
    return;
  end if;

  delete from public.bill_lines
  where invoice_id = p_bill_id
    and line_kind in ('charge', 'description');

  if v_cod_face > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.tenant_id, 'charge', 'COD collect', 1,
      v_cod_face, 0, v_cod_face, v_cod_face,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('courier_ar_line', 'cod')
    );
  end if;

  if v_rate > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.tenant_id, 'charge', 'COD rate (deduction)', 1,
      v_rate, 0, v_rate, v_rate,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('courier_ar_line', 'rate')
    );
  end if;

  if v_delivery > 0 then
    insert into public.bill_lines (
      invoice_id, tenant_id, line_kind, name_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, books_amount,
      currency_code, line_meta
    ) values (
      p_bill_id, v_bill.tenant_id, 'charge', 'Delivery (deduction)', 1,
      v_delivery, 0, v_delivery, v_delivery,
      coalesce(v_bill.currency_code, 'BDT'), jsonb_build_object('courier_ar_line', 'delivery')
    );
  end if;

  perform public.recompute_global_invoice_totals(p_bill_id);
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_dropship_courier_ar(
  p_order_id bigint,
  p_keep_as_draft boolean DEFAULT true
) RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
declare
  v_order public.shop_orders;
  v_books_tenant_id bigint;
  v_profile_id bigint;
  v_bill public.bills;
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_discount numeric(12, 2);
  v_net numeric(12, 2);
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

  if coalesce(v_order.is_prepaid_snapshot, false)
     or coalesce(v_order.cod_collect_amount, 0) <= 0 then
    perform public.recompute_dropship_cod_collect_amount(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id;
    if coalesce(v_order.is_prepaid_snapshot, false)
       or coalesce(v_order.cod_collect_amount, 0) <= 0 then
      return jsonb_build_object('success', true, 'skipped', true, 'reason', 'prepaid_or_no_cod');
    end if;
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required');
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);

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
    v_books_tenant_id,
    'tenant'::public.profile_party_type,
    v_order.tenant_id,
    coalesce(v_tenant_name, 'Tenant'),
    null, null, '+880', null, false, null, true, null
  );

  select p.id into v_profile_id
  from public.profiles p
  where p.tenant_id = v_books_tenant_id
    and p.profile_type = 'courier'::public.profile_party_type
    and p.subject_id = v_courier.wallet_entity_id
  limit 1;

  if v_profile_id is null then
    v_profile_id := public.upsert_profile_for_party(
      v_books_tenant_id,
      'courier'::public.profile_party_type,
      v_courier.wallet_entity_id,
      v_courier.name,
      null, null, '+880', null, false, null,
      coalesce(v_courier.is_active, true),
      null
    );
  end if;

  if v_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'courier profile is required');
  end if;

  perform public.recompute_dropship_cod_collect_amount(p_order_id);
  select * into v_order from public.shop_orders where id = p_order_id;

  v_cod_face := round(greatest(coalesce(v_order.cod_collect_amount, 0), 0), 2);
  v_rate := round(coalesce(v_order.cod_charge_amount, 0), 2);
  v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
  v_discount := round(v_rate + v_delivery, 2);
  v_net := greatest(v_cod_face - v_discount, 0);

  if v_net <= 0 then
    return jsonb_build_object('success', true, 'skipped', true, 'reason', 'zero_courier_receivable');
  end if;

  select * into v_bill
  from public.bills b
  where b.tenant_id = v_books_tenant_id
    and b.invoice_type = 'dropship'::public.global_invoice_type
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.source_type = 'dropship_courier_ar'
    and b.source_id = p_order_id::text
  for update;

  v_paper_status := case
    when p_keep_as_draft then 'draft'::public.global_invoice_status
    else 'issued'::public.global_invoice_status
  end;

  if v_bill.id is null then
    v_invoice_no := 'AR-CR-' || v_order.order_no;
    insert into public.bills (
      tenant_id, issued_by_tenant_id, invoice_no, invoice_type, invoice_date,
      invoice_status, profile_id, collection_source, payment_status,
      subtotal_amount, discount_amount, total_amount, due_amount, paid_amount,
      source_type, source_id, source_key, currency_code,
      note, channel_meta, document_kind, shop_order_id,
      recipient_name, recipient_phone, recipient_address
    ) values (
      v_books_tenant_id, v_order.tenant_id, v_invoice_no, 'dropship'::public.global_invoice_type, current_date,
      v_paper_status, v_profile_id, 'profile'::public.collection_source_type, 'due',
      v_cod_face, v_discount, v_net, v_net, 0,
      'dropship_courier_ar', p_order_id::text, 'courier_ar', 'BDT',
      format('Courier receivable — %s — order %s', v_courier.name, v_order.order_no),
      '{}'::jsonb, 'standard'::public.bill_document_kind, p_order_id,
      v_order.recipient_name, v_order.recipient_phone, v_order.shipping_address
    )
    returning * into v_bill;
    perform public._sync_dropship_courier_ar_bill_details(v_bill.id, p_order_id, true);
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return jsonb_build_object(
      'success', true,
      'bill_id', v_bill.id,
      'created', true,
      'amount', v_net,
      'invoice_status', v_bill.invoice_status
    );
  end if;

  if v_bill.invoice_status = 'voided'::public.global_invoice_status then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true);
    end if;
    update public.bills
    set
      invoice_status = v_paper_status,
      profile_id = v_profile_id,
      updated_at = now()
    where id = v_bill.id;
    perform public._sync_dropship_courier_ar_bill_details(v_bill.id, p_order_id, true);
    perform public.stamp_bill_kernel_fields(v_bill.id);
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'revived', true, 'amount', v_net);
  end if;

  if v_bill.invoice_status = 'issued'::public.global_invoice_status
     and coalesce(v_bill.paid_amount, 0) > 0 then
    return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true, 'amount', v_bill.total_amount);
  end if;

  update public.bills
  set
    profile_id = v_profile_id,
    invoice_status = case
      when invoice_status = 'issued'::public.global_invoice_status then invoice_status
      else v_paper_status
    end,
    updated_at = now()
  where id = v_bill.id;

  perform public._sync_dropship_courier_ar_bill_details(v_bill.id, p_order_id, coalesce(v_bill.paid_amount, 0) = 0);
  perform public.stamp_bill_kernel_fields(v_bill.id);

  select * into v_bill from public.bills where id = v_bill.id;

  return jsonb_build_object(
    'success', true,
    'bill_id', v_bill.id,
    'amount', v_bill.total_amount,
    'invoice_status', v_bill.invoice_status
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

CREATE OR REPLACE FUNCTION public.upsert_dropship_courier_ar_bill(
  p_order_id bigint,
  p_keep_as_draft boolean DEFAULT true
) RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
begin
  return public._kernel_upsert_dropship_courier_ar(p_order_id, p_keep_as_draft);
end;
$$;

DROP FUNCTION IF EXISTS public.issue_dropship_tenant_b2b_invoice(bigint, bigint);

CREATE OR REPLACE FUNCTION public.issue_dropship_tenant_b2b_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_as_draft boolean DEFAULT false
) RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
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
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_courier_net numeric(12, 2);
  v_payout_note text;
  v_issue_flag boolean;
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

  perform public.recompute_dropship_cod_collect_amount(p_order_id);
  select * into v_order from public.shop_orders where id = p_order_id;

  v_cod_face := round(greatest(coalesce(v_order.cod_collect_amount, 0), 0), 2);
  v_rate := round(coalesce(v_order.cod_charge_amount, 0), 2);
  v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
  v_courier_net := greatest(v_cod_face - v_rate - v_delivery, 0);

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.bills where id = v_order.global_invoice_id;
    if v_invoice.id is null then
      return jsonb_build_object('success', false, 'error', 'linked invoice not found');
    end if;

    v_payout_note := format(
      'Expected amount after all payment: %s BDT (informative; payout posts on remittance)',
      greatest(v_courier_net - coalesce(v_invoice.total_amount, 0), 0)
    );

    if v_invoice.invoice_status = 'issued'::public.global_invoice_status then
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

    if v_invoice.profile_id is distinct from v_merchant_profile_id then
      update public.bills
      set profile_id = v_merchant_profile_id, updated_at = now()
      where id = v_invoice.id;
      perform public.stamp_bill_kernel_fields(v_invoice.id);
    end if;

    if p_as_draft then
      update public.bills
      set note = v_payout_note, updated_at = now()
      where id = v_invoice.id;
      perform public.sync_sales_invoice_charges_from_header(v_invoice.id);
      select * into v_invoice from public.bills where id = v_invoice.id;
    else
      perform public.post_sales_invoice(v_invoice.id);
      perform public.sync_sales_invoice_charges_from_header(v_invoice.id);
      select * into v_invoice from public.bills where id = v_invoice.id;
    end if;

    return jsonb_build_object(
      'success', true,
      'already_issued', v_invoice.invoice_status = 'issued'::public.global_invoice_status,
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

  v_payout_note := null;

  v_build := public.build_dropship_tenant_b2b_invoice_payload(
    p_order_id,
    null,
    null,
    v_merchant_profile_id,
    null
  );
  if coalesce(v_build->>'success', 'false') <> 'true' then
    return v_build;
  end if;

  v_payload := v_build->'payload';
  v_issue_flag := not coalesce(p_as_draft, false);

  v_payload := v_payload || jsonb_build_object(
    'issue', v_issue_flag,
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

  v_payout_note := format(
    'Expected amount after all payment: %s BDT (informative; payout posts on remittance)',
    greatest(v_courier_net - coalesce(v_invoice.total_amount, 0), 0)
  );

  update public.bills
  set
    shop_order_id = p_order_id,
    channel_meta = coalesce(v_payload->'invoice'->'channel_meta', '{}'::jsonb)
      || jsonb_build_object('expected_payout_amount', greatest(v_courier_net - coalesce(v_invoice.total_amount, 0), 0)),
    note = v_payout_note,
    updated_at = now()
  where id = v_invoice.id;

  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  select * into v_invoice from public.bills where id = v_invoice.id;

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
    'already_issued', v_invoice.invoice_status = 'issued'::public.global_invoice_status,
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

CREATE OR REPLACE FUNCTION public.resolve_dropship_courier_ap_bill_id(
  p_order_id bigint,
  p_tenant_id bigint
) RETURNS bigint
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO public
AS $$
  with books as (
    select public.resolve_books_tenant_id(p_tenant_id) as tid
  )
  select b.id
  from public.bills b
  cross join books
  where b.tenant_id = books.tid
    and b.document_kind = 'standard'::public.bill_document_kind
    and b.source_id = p_order_id::text
    and b.invoice_status <> 'voided'::public.global_invoice_status
    and (
      (
        b.invoice_type = 'dropship'::public.global_invoice_type
        and b.source_type = 'dropship_courier_ar'
      )
      or (
        b.invoice_type = 'ap'::public.global_invoice_type
        and (
          b.source_type = 'dropship_courier'
          or (b.source_type = 'shop_order' and coalesce(b.source_key, '') = 'courier')
        )
      )
    )
  order by
    case
      when b.source_type = 'dropship_courier_ar' then 0
      when b.source_type = 'dropship_courier' then 1
      else 2
    end,
    b.id
  limit 1;
$$;

CREATE OR REPLACE FUNCTION public.ship_dropship_order_and_issue_merchant_bill(
  p_tenant_id bigint,
  p_order_id bigint
) RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO public
AS $$
declare
  v_order public.shop_orders;
  v_issue jsonb;
  v_courier_ar jsonb;
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

  if v_order.status <> 'ready_for_pickup'::public.shop_order_status then
    return jsonb_build_object(
      'success', false,
      'error', format('ship requires ready_for_pickup (current: %s)', v_order.status)
    );
  end if;

  if v_order.profile_id is null then
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
      and not (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'stock'
      )
      and not (
        coalesce(soi.is_gift, false)
        and soi.gift_source = 'customer_stock'
        and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
      )
      and not exists (
        select 1
        from public.shop_order_item_stock_picks sp
        where sp.order_item_id = soi.id
          and sp.quantity > 0
      )
  ) then
    return jsonb_build_object('success', false, 'error', 'every line must be picked or marked unavailable before ship');
  end if;

  v_issue := public.issue_dropship_tenant_b2b_invoice(p_tenant_id, p_order_id, true);
  if coalesce(v_issue->>'success', 'false') <> 'true' then
    return v_issue;
  end if;

  v_courier_ar := public.upsert_dropship_courier_ar_bill(p_order_id, true);
  if coalesce(v_courier_ar->>'success', 'false') <> 'true' then
    return v_courier_ar;
  end if;

  if coalesce(v_courier_ar->>'skipped', 'false') <> 'true'
     and nullif(v_courier_ar->>'bill_id', '') is null then
    return jsonb_build_object('success', false, 'error', 'courier receivable was not created');
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
    'courier_ar', v_courier_ar,
    'courier_ap', v_courier_ar,
    'created', coalesce(v_issue->>'created', 'false')::boolean,
    'already_issued', coalesce(v_issue->>'already_issued', 'false')::boolean
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

GRANT ALL ON FUNCTION public._sync_dropship_courier_ar_bill_details(bigint, bigint, boolean) TO authenticated, service_role;
GRANT ALL ON FUNCTION public._kernel_upsert_dropship_courier_ar(bigint, boolean) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.upsert_dropship_courier_ar_bill(bigint, boolean) TO authenticated, service_role;
GRANT ALL ON FUNCTION public.issue_dropship_tenant_b2b_invoice(bigint, bigint, boolean) TO authenticated, service_role;CREATE OR REPLACE FUNCTION "public"."get_dropship_order_detail_v2"("p_tenant_id" bigint, "p_order_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_customer_group_name text;
  v_sell_symbol text;
  v_buy_currency_id bigint;
  v_items jsonb;
  v_courier_ap_bill_id bigint;
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

  if v_order.tenant_id is distinct from p_tenant_id then
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
          or (coalesce(soi.is_gift, false) and soi.gift_source = 'customer_stock' and coalesce(soi.confirmed_quantity, 0) >= soi.quantity)
          or (coalesce(soi.is_gift, false) and soi.gift_source = 'stock')
        ),
        'is_gift', coalesce(soi.is_gift, false),
        'gift_source', soi.gift_source,
        'gift_cost_amount', coalesce(soi.gift_cost_amount, 0),
        'gift_cost_charged_to', soi.gift_cost_charged_to,
        'gift_added_by', soi.gift_added_by,
        'shop_customer_stock_id', soi.shop_customer_stock_id,
        'sku', p.product_code,
        'barcode', p.barcode,
        'brand', p.brand,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at,
        'requested_resell_discount_price_amount', soi.requested_resell_discount_price_amount,
        'requested_resell_discount_price_currency_id', soi.requested_resell_discount_price_currency_id,
        'resell_discount_request_reason', soi.resell_discount_request_reason,
        'resell_discount_requested_at', soi.resell_discount_requested_at
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
  where soi.order_id = v_order.id
    and not coalesce(soi.is_gift, false);

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
    or (
      coalesce(soi.is_gift, false)
      and soi.gift_source = 'customer_stock'
      and coalesce(soi.confirmed_quantity, 0) >= soi.quantity
    )
    or (
      coalesce(soi.is_gift, false)
      and soi.gift_source = 'stock'
    )
  ), true)
  into v_all_lines_resolved
  from public.shop_order_items soi
  where soi.order_id = v_order.id and soi.quantity > 0;

  select coalesce(sum(coalesce(soi.confirmed_quantity, 0)), 0)
  into v_total_delivered_qty
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  v_courier_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, p_tenant_id);

  return jsonb_build_object(
    'success', true,
    'order', (
      jsonb_build_object(
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
        'profile_id', v_order.profile_id,
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
        'deduct_packing_from_margin', v_order.deduct_packing_from_margin
      ) || jsonb_build_object(
        'cod_collect_amount', coalesce(v_order.cod_collect_amount, v_recipient_grand_total),
        'item_count', jsonb_array_length(v_items),
        'delivery_zone', v_order.delivery_zone,
        'courier_name', v_order.courier_name,
        'courier_awb_number', v_order.courier_awb_number,
        'tracking_url', v_order.tracking_url,
        'courier_ap_bill_id', v_courier_ap_bill_id,
        'recipient_call_attempt_count', coalesce(v_order.recipient_call_attempt_count, 0),
        'recipient_verified_at', v_order.recipient_verified_at,
        'cancel_reason', v_order.cancel_reason,
        'auto_gifts_applied_at', v_order.auto_gifts_applied_at,
        'auto_gifts_apply_result', v_order.auto_gifts_apply_result
      )
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
    'permissions', jsonb_build_object(
      'can_show_invoice_paper', v_order.status = 'confirmed',
      'can_start_processing', false,
      'can_confirm_recipient_call', v_order.status = 'confirmed' and v_order.recipient_verified_at is null,
      'can_mark_ready_for_pickup', v_order.status = 'processing',
      'can_mark_shipped', v_order.status = 'ready_for_pickup',
      'can_print_customer_invoice', v_order.status in ('ready_for_pickup', 'shipped', 'delivered')
    )
  );
end;
$$;