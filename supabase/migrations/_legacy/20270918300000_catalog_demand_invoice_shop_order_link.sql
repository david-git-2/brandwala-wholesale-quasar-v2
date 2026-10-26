-- Catalog proforma: link shop_order_id after create (payload shop_order_id is dropship-only)
CREATE OR REPLACE FUNCTION "public"."create_invoice_from_preorder_demand_document"("p_tenant_id" bigint, "p_document_type" "text", "p_document_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  update public.sales_invoices
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
$$;
