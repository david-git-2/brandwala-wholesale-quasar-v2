-- Kernel cutover: stop UPDATE/DELETE on public.bills / public.bill_lines views.

CREATE OR REPLACE FUNCTION public._kernel_patch_bill_header(
  p_bill_id bigint,
  p_note text DEFAULT NULL,
  p_meta_patch jsonb DEFAULT '{}'::jsonb,
  p_counterparty_profile_id bigint DEFAULT NULL
) RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
begin
  if p_bill_id is null then return; end if;
  if not exists (select 1 from money_kernel.bills where id = p_bill_id) then
    return;
  end if;

  update money_kernel.bills kb
  set
    note = coalesce(p_note, kb.note),
    counterparty_profile_id = coalesce(p_counterparty_profile_id, kb.counterparty_profile_id),
    meta = coalesce(kb.meta, '{}'::jsonb) || coalesce(p_meta_patch, '{}'::jsonb),
    updated_at = now()
  where kb.id = p_bill_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.sync_sales_invoice_charges_from_header(p_invoice_id bigint)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
begin
  if p_invoice_id is null then return; end if;
  if exists (select 1 from money_kernel.bills where id = p_invoice_id) then
    return;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public.stamp_bill_kernel_fields(p_bill_id bigint)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
AS $$
declare
  v_bill public.bills;
  v_kernel money_kernel.bills;
  v_tenant_profile_id bigint;
  v_from bigint;
  v_to bigint;
  v_source_type text;
  v_source_id text;
  v_source_key text;
  v_settle text;
  v_kind text;
begin
  select * into v_kernel from money_kernel.bills where id = p_bill_id;
  if not found then
    return;
  end if;

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
    v_source_type := coalesce(v_kernel.source_type, v_bill.source_type, 'shipment_cost');
    v_source_id := coalesce(v_kernel.source_id, v_bill.source_id, v_bill.ap_shipment_id::text);
    v_source_key := coalesce(v_kernel.source_key, v_bill.source_key, v_bill.ap_kind);
    v_settle := null;
  else
    v_from := coalesce(v_kernel.from_profile_id, v_tenant_profile_id);
    v_to := coalesce(v_kernel.to_profile_id, v_bill.profile_id);
    if v_bill.shop_order_id is not null then
      v_source_type := coalesce(v_kernel.source_type, v_bill.source_type, 'shop_order');
      v_source_id := coalesce(v_kernel.source_id, v_bill.source_id, v_bill.shop_order_id::text);
      v_source_key := coalesce(v_kernel.source_key, v_bill.source_key);
    else
      v_source_type := coalesce(v_kernel.source_type, v_bill.source_type, 'compose');
      v_source_id := coalesce(v_kernel.source_id, v_bill.source_id, v_bill.id::text);
      v_source_key := coalesce(v_kernel.source_key, v_bill.source_key);
    end if;
    v_kind := lower(trim(coalesce(v_bill.channel_meta->>'delivery_kind', v_kernel.meta->>'delivery_kind', '')));
    if v_bill.settlement_kind is not null then
      v_settle := v_bill.settlement_kind::text;
    elsif v_kind in ('take', 'condition') then
      v_settle := v_kind;
    else
      v_settle := 'take';
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

  update money_kernel.bills kb
  set
    from_profile_id = v_from,
    to_profile_id = v_to,
    source_type = coalesce(v_source_type, kb.source_type),
    source_id = coalesce(v_source_id, kb.source_id),
    source_key = coalesce(v_source_key, kb.source_key),
    meta = coalesce(kb.meta, '{}'::jsonb)
      || case when v_settle is not null then jsonb_build_object('delivery_kind', v_settle) else '{}'::jsonb end,
    updated_at = now()
  where kb.id = p_bill_id;
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_dropship_tenant_b2b_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_as_draft boolean DEFAULT false
) RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO money_kernel, public, pg_temp
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
  v_invoice_id bigint;
  v_meta_patch jsonb;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order from public.shop_orders where id = p_order_id for update;
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
      perform public._kernel_patch_bill_header(v_invoice.id, null, '{}'::jsonb, v_merchant_profile_id);
      perform public.stamp_bill_kernel_fields(v_invoice.id);
    end if;

    if p_as_draft then
      perform public._kernel_patch_bill_header(v_invoice.id, v_payout_note, '{}'::jsonb, null);
      select * into v_invoice from public.bills where id = v_invoice.id;
    else
      perform public.post_sales_invoice(v_invoice.id);
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

  v_build := public.build_dropship_tenant_b2b_invoice_payload(
    p_order_id, null, null, v_merchant_profile_id, null
  );
  if coalesce(v_build->>'success', 'false') <> 'true' then
    return v_build;
  end if;

  v_payload := v_build->'payload';
  v_issue_flag := not coalesce(p_as_draft, false);
  v_payload := v_payload || jsonb_build_object('issue', v_issue_flag, 'shop_order_id', p_order_id);

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
    delete from money_kernel.bill_lines where bill_id = v_orphan_invoice_id;
    delete from money_kernel.bills where id = v_orphan_invoice_id;
  end if;

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);
  v_created := true;

  if coalesce(v_result->>'success', 'false') <> 'true' then
    return coalesce(
      v_result,
      jsonb_build_object('success', false, 'error', 'failed to upsert tenant B2B invoice')
    );
  end if;

  v_invoice_id := nullif(v_result->>'invoice_id', '')::bigint;

  update public.shop_orders
  set
    global_invoice_id = v_invoice_id,
    updated_at = now()
  where id = p_order_id
    and global_invoice_id is null;

  select * into v_order from public.shop_orders where id = p_order_id;
  select * into v_invoice from public.bills where id = coalesce(v_order.global_invoice_id, v_invoice_id);

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice was not created');
  end if;

  v_payout_note := format(
    'Expected amount after all payment: %s BDT (informative; payout posts on remittance)',
    greatest(v_courier_net - coalesce(v_invoice.total_amount, 0), 0)
  );

  v_meta_patch := coalesce(v_payload->'invoice'->'channel_meta', '{}'::jsonb)
    || jsonb_build_object(
      'expected_payout_amount', greatest(v_courier_net - coalesce(v_invoice.total_amount, 0), 0),
      'shop_order_id', p_order_id
    );

  perform public._kernel_patch_bill_header(v_invoice.id, v_payout_note, v_meta_patch, v_merchant_profile_id);
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

GRANT EXECUTE ON FUNCTION public._kernel_patch_bill_header(bigint, text, jsonb, bigint) TO authenticated, service_role;