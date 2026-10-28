-- BP9: dropship B2B issue uses kernel upsert_draft_bill entry.

CREATE OR REPLACE FUNCTION public.issue_dropship_tenant_b2b_invoice(
  p_tenant_id bigint,
  p_order_id bigint
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
      perform public.issue_bill(v_invoice.id);
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

  select * into v_invoice
  from public.upsert_draft_bill(v_payload || jsonb_build_object('tenant_id', v_order.tenant_id));
  v_created := true;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'failed to upsert tenant B2B invoice');
  end if;

  v_result := jsonb_build_object(
    'success', true,
    'invoice_id', v_invoice.id,
    'invoice_no', v_invoice.invoice_no
  );

  update public.shop_orders
  set
    global_invoice_id = v_invoice.id,
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

  perform public.stamp_bill_kernel_fields(v_invoice.id);
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
    'courier_cod_booked', v_courier_cod_booked
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;
