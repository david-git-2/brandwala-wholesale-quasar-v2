CREATE FUNCTION public.finalize_dropship_order_bills_at_delivered (
  p_order_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
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
  where b.parent_tenant_id = v_invoice.parent_tenant_id
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
  where b.parent_tenant_id = v_invoice.parent_tenant_id
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
$function$;

GRANT ALL ON FUNCTION public.finalize_dropship_order_bills_at_delivered(bigint) TO anon;

GRANT ALL ON FUNCTION public.finalize_dropship_order_bills_at_delivered(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.finalize_dropship_order_bills_at_delivered(bigint) TO service_role;