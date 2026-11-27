-- public.bills is a view over money_kernel.bills: route compose + dropship courier AR through rpc_create_bill.

INSERT INTO money_kernel.bill_kind_registry (kind, numbering_prefix, required_meta, can_be_paid, description)
VALUES ('dropship_courier_ar', 'AR-DC', '{}', true, 'Dropship courier net remittance AR')
ON CONFLICT (kind) DO NOTHING;

DROP FUNCTION IF EXISTS public.create_sales_invoice(
  bigint, text, global_invoice_type, bigint, bigint, text, text, text,
  retail_billing_mode, date, text, date
);
DROP FUNCTION IF EXISTS public.create_sales_invoice(
  bigint, text, bigint, global_invoice_type, global_source_module,
  text, text, text, bigint, numeric, text
);

CREATE OR REPLACE FUNCTION public._compose_legacy_items_to_kernel_lines(
  p_items jsonb
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_elem jsonb;
  v_lines jsonb := '[]'::jsonb;
  v_line_meta jsonb;
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_name text;
  v_item_kind text;
  v_shipment_item_id bigint;
  v_product_id bigint;
begin
  if jsonb_typeof(p_items) <> 'array' then
  return '[]'::jsonb;
  end if;

  for v_elem in select value from jsonb_array_elements(p_items) as t(value) loop
    v_line_meta := coalesce(v_elem->'line_meta', '{}'::jsonb);
    v_global_stock_id := coalesce(
      nullif(v_elem->>'global_stock_id', '')::bigint,
      nullif(v_line_meta->'stock_ref'->>'global_stock_id', '')::bigint
    );
    v_quantity := nullif(v_elem->>'quantity', '')::numeric;
    v_sell_price := nullif(v_elem->>'sell_price_amount', '')::numeric;
    v_line_discount := coalesce(nullif(v_elem->>'line_discount_amount', '')::numeric, 0);

    if v_quantity is null or v_quantity <= 0 or v_sell_price is null or v_sell_price < 0 then
      continue;
    end if;

    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest(v_quantity * v_sell_price - v_line_discount, 0)
    );
    v_name := coalesce(nullif(trim(v_elem->>'name_snapshot'), ''), 'Line');
    v_shipment_item_id := nullif(v_elem->>'shipment_item_id', '')::bigint;
    v_product_id := nullif(v_elem->>'product_id', '')::bigint;

    if v_global_stock_id is not null then
      v_item_kind := 'stock';
      v_line_meta := jsonb_set(
        coalesce(v_line_meta, '{}'::jsonb),
        '{stock_ref}',
        jsonb_build_object('global_stock_id', v_global_stock_id),
        true
      );
    elsif coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
      v_item_kind := 'charge';
    else
      v_item_kind := lower(trim(coalesce(v_elem->>'line_kind', 'charge')));
      if v_item_kind not in ('stock', 'charge', 'description') then
        v_item_kind := 'charge';
      end if;
    end if;

    v_lines := v_lines || jsonb_build_array(
      jsonb_strip_nulls(jsonb_build_object(
        'item_kind', v_item_kind,
        'description', v_name,
        'quantity', v_quantity,
        'unit_price', v_sell_price,
        'line_total', v_line_total,
        'product_id', v_product_id,
        'global_stock_id', v_global_stock_id,
        'shipment_item_id', v_shipment_item_id,
        'meta', v_line_meta
      ))
    );
  end loop;

  return v_lines;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_invoice_type_to_bill_kind(p_type public.global_invoice_type)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT CASE p_type
    WHEN 'wholesale'::public.global_invoice_type THEN 'sales_invoice_wholesale'
    WHEN 'retail'::public.global_invoice_type THEN 'sales_invoice_retail'
    WHEN 'dropship'::public.global_invoice_type THEN 'sales_invoice_dropship'
    WHEN 'ap'::public.global_invoice_type THEN 'dropship_courier_ap'
    ELSE NULL
  END;
$$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_compose_draft_json(p_payload jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO money_kernel, public, pg_temp
AS $$
declare
  v_tenant_id bigint;
  v_books_tenant_id bigint;
  v_tenant_self_profile bigint;
  v_inv jsonb;
  v_items jsonb;
  v_issue boolean;
  v_shop_order_id bigint;
  v_invoice_type public.global_invoice_type;
  v_kind text;
  v_channel_meta jsonb;
  v_delivery_kind text;
  v_kernel_lines jsonb;
  v_rpc jsonb;
  v_invoice_id bigint;
  v_discount numeric(12, 2);
  v_shipping numeric(12, 2);
  v_print numeric(12, 2);
  v_wrapping numeric(12, 2);
  v_cod numeric(12, 2);
  v_invoice public.bills;
  v_line_subtotal numeric(12, 2) := 0;
  v_elem jsonb;
  v_profile_id bigint;
begin
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'tenant_id required');
  end if;

  if not public.is_tenant_staff(v_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  v_inv := coalesce(p_payload->'invoice', '{}'::jsonb);
  v_items := coalesce(p_payload->'items', '[]'::jsonb);
  v_issue := coalesce((p_payload->>'issue')::boolean, false);
  v_shop_order_id := nullif(p_payload->>'shop_order_id', '')::bigint;

  if v_inv->>'invoice_type' is null or trim(v_inv->>'invoice_type') = '' then
    return jsonb_build_object('success', false, 'error', 'invoice.invoice_type is required');
  end if;

  v_invoice_type := (v_inv->>'invoice_type')::public.global_invoice_type;
  v_kind := public._kernel_invoice_type_to_bill_kind(v_invoice_type);
  if v_kind is null then
    return jsonb_build_object('success', false, 'error', format('unsupported invoice_type %s', v_invoice_type));
  end if;

  if v_issue and jsonb_array_length(v_items) = 0 then
    return jsonb_build_object('success', false, 'error', 'at least one item is required when issue is true');
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_tenant_id);
  v_tenant_self_profile := public._kernel_tenant_mirror_profile_id(v_books_tenant_id);
  if v_tenant_self_profile is null then
    return jsonb_build_object('success', false, 'error', 'tenant billing profile is required');
  end if;

  v_profile_id := nullif(v_inv->>'profile_id', '')::bigint;
  if v_profile_id is null and v_kind <> 'dropship_courier_ap' then
    return jsonb_build_object('success', false, 'error', 'invoice.profile_id is required');
  end if;

  v_channel_meta := coalesce(v_inv->'channel_meta', '{}'::jsonb);
  v_delivery_kind := lower(trim(coalesce(v_channel_meta->>'delivery_kind', 'take')));
  if v_invoice_type = 'ap'::public.global_invoice_type then
    v_delivery_kind := 'take';
  elsif v_delivery_kind not in ('take', 'condition') then
    return jsonb_build_object('success', false, 'error', 'channel_meta.delivery_kind must be take or condition');
  end if;
  v_channel_meta := v_channel_meta || jsonb_build_object('delivery_kind', v_delivery_kind);

  v_kernel_lines := public._compose_legacy_items_to_kernel_lines(v_items);
  if jsonb_array_length(v_kernel_lines) = 0 then
    return jsonb_build_object('success', false, 'error', 'at least one billable line is required');
  end if;

  v_shipping := coalesce(nullif(v_inv->>'shipping_charge', '')::numeric, 0);
  v_print := coalesce(nullif(v_inv->>'print_charge', '')::numeric, 0);
  v_wrapping := coalesce(nullif(v_inv->>'wrapping_charge', '')::numeric, 0);
  v_discount := coalesce(nullif(v_inv->>'discount_amount', '')::numeric, 0);
  v_cod := coalesce(
    nullif(v_inv->>'cod_charge_amount', '')::numeric,
    nullif(v_inv->>'cod_charge', '')::numeric,
    0
  );

  if v_shipping > 0 then
    v_kernel_lines := v_kernel_lines || jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge', 'description', 'Delivery charge',
      'quantity', 1, 'unit_price', v_shipping, 'line_total', v_shipping,
      'meta', jsonb_build_object('charge_type', 'delivery')
    ));
  end if;
  if v_print > 0 then
    v_kernel_lines := v_kernel_lines || jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge', 'description', 'Print charge',
      'quantity', 1, 'unit_price', v_print, 'line_total', v_print,
      'meta', jsonb_build_object('charge_type', 'print')
    ));
  end if;
  if v_wrapping > 0 then
    v_kernel_lines := v_kernel_lines || jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge', 'description', 'Packing charge',
      'quantity', 1, 'unit_price', v_wrapping, 'line_total', v_wrapping,
      'meta', jsonb_build_object('charge_type', 'packing')
    ));
  end if;

  for v_elem in select value from jsonb_array_elements(v_kernel_lines) as t(value) loop
    v_line_subtotal := v_line_subtotal + coalesce(
      nullif(v_elem->>'line_total', '')::numeric,
      coalesce((v_elem->>'quantity')::numeric, 1) * coalesce((v_elem->>'unit_price')::numeric, 0),
      0
    );
  end loop;

  v_rpc := public.rpc_create_bill(jsonb_strip_nulls(jsonb_build_object(
    'tenant_id', v_books_tenant_id,
    'kind', v_kind,
    'source_entity', case when v_shop_order_id is not null then 'public.shop_orders' else null end,
    'source_type', case when v_shop_order_id is not null then 'shop_order' else null end,
    'source_id', v_shop_order_id::text,
    'source_key', format('compose:%s:%s', v_kind, coalesce(v_shop_order_id::text, 'adhoc')),
    'idempotency_key', case when v_shop_order_id is not null
      then format('shop-order-compose-%s-%s', v_shop_order_id, v_kind) else null end,
    'currency_code', 'BDT',
    'from_profile_id', v_profile_id,
    'to_profile_id', v_tenant_self_profile,
    'counterparty_profile_id', v_profile_id,
    'note', nullif(trim(v_inv->>'note'), ''),
    'invoice_date', nullif(v_inv->>'invoice_date', '')::date,
    'due_date', nullif(v_inv->>'due_date', '')::date,
    'auto_issue', v_issue,
    'meta', jsonb_strip_nulls(jsonb_build_object(
      'delivery_kind', v_delivery_kind,
      'shop_order_id', v_shop_order_id,
      'discount_amount', v_discount,
      'shipping_charge', v_shipping,
      'print_charge', v_print,
      'wrapping_charge', v_wrapping,
      'cod_charge_amount', case when v_cod > 0 then v_cod else null end,
      'retail_billing_mode', nullif(trim(v_inv->>'retail_billing_mode'), ''),
      'recipient_name', nullif(trim(v_inv->>'recipient_name'), ''),
      'recipient_phone', nullif(trim(v_inv->>'recipient_phone'), ''),
      'recipient_address', nullif(trim(v_inv->>'recipient_address'), ''),
      'channel_meta', v_channel_meta,
      'subtotal_amount', v_line_subtotal
    )) || v_channel_meta,
    'lines', v_kernel_lines
  )));

  v_invoice_id := nullif(v_rpc->>'bill_id', '')::bigint;
  if v_invoice_id is null then
    return coalesce(v_rpc, jsonb_build_object('success', false, 'error', 'rpc_create_bill failed'));
  end if;

  if v_discount > 0 then
    update money_kernel.bills kb
    set
      total_amount = greatest(kb.total_amount - v_discount, 0),
      due_amount = greatest(kb.due_amount - v_discount, 0),
      meta = coalesce(kb.meta, '{}'::jsonb) || jsonb_build_object('discount_amount', v_discount),
      updated_at = now()
    where kb.id = v_invoice_id
      and kb.tenant_id = v_books_tenant_id;
  end if;

  perform public.stamp_bill_kernel_fields(v_invoice_id);

  if v_issue and coalesce(v_rpc->>'auto_issued', 'false') <> 'true' then
    perform public.post_sales_invoice(v_invoice_id);
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
    set global_invoice_id = v_invoice_id, updated_at = now()
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
    'issued', v_issue,
    'shop_order_id', v_shop_order_id
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

CREATE OR REPLACE FUNCTION public._sync_dropship_courier_ar_bill_details(
  p_bill_id bigint,
  p_order_id bigint,
  p_allow_line_sync boolean DEFAULT true
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO money_kernel, public, pg_temp
AS $$
declare
  v_bill money_kernel.bills;
  v_order public.shop_orders;
  v_courier public.courier_services;
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_discount numeric(12, 2);
  v_net numeric(12, 2);
  v_note text;
  v_meta jsonb;
  v_line_no int := 0;
begin
  select * into v_bill from money_kernel.bills where id = p_bill_id;
  if v_bill.id is null then return; end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then return; end if;

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

  v_meta := coalesce(v_bill.meta, '{}'::jsonb) || jsonb_build_object(
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
    'discount_amount', v_discount,
    'subtotal_amount', v_cod_face,
    'dropship_courier_ar', true,
    'recipient_name', v_order.recipient_name,
    'recipient_phone', v_order.recipient_phone,
    'recipient_address', v_order.shipping_address
  );

  update money_kernel.bills
  set
    note = v_note,
    total_amount = v_net,
    due_amount = greatest(v_net - coalesce(paid_amount, 0), 0),
    meta = v_meta,
    updated_at = now()
  where id = p_bill_id;

  if not p_allow_line_sync then return; end if;

  delete from money_kernel.bill_lines
  where bill_id = p_bill_id and tenant_id = v_bill.tenant_id and item_kind = 'charge';

  if v_cod_face > 0 then
    v_line_no := v_line_no + 1;
    insert into money_kernel.bill_lines (
      tenant_id, bill_id, line_no, item_kind, description,
      quantity, unit_price, line_total, meta
    ) values (
      v_bill.tenant_id, p_bill_id, v_line_no, 'charge', 'COD collect',
      1, v_cod_face, v_cod_face, jsonb_build_object('courier_ar_line', 'cod')
    );
  end if;
  if v_rate > 0 then
    v_line_no := v_line_no + 1;
    insert into money_kernel.bill_lines (
      tenant_id, bill_id, line_no, item_kind, description,
      quantity, unit_price, line_total, meta
    ) values (
      v_bill.tenant_id, p_bill_id, v_line_no, 'charge', 'COD rate (deduction)',
      1, v_rate, v_rate, jsonb_build_object('courier_ar_line', 'rate')
    );
  end if;
  if v_delivery > 0 then
    v_line_no := v_line_no + 1;
    insert into money_kernel.bill_lines (
      tenant_id, bill_id, line_no, item_kind, description,
      quantity, unit_price, line_total, meta
    ) values (
      v_bill.tenant_id, p_bill_id, v_line_no, 'charge', 'Delivery (deduction)',
      1, v_delivery, v_delivery, jsonb_build_object('courier_ar_line', 'delivery')
    );
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_upsert_dropship_courier_ar(
  p_order_id bigint,
  p_keep_as_draft boolean DEFAULT true
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO money_kernel, public, pg_temp
AS $$
declare
  v_order public.shop_orders;
  v_books_tenant_id bigint;
  v_profile_id bigint;
  v_bill money_kernel.bills;
  v_cod_face numeric(12, 2);
  v_rate numeric(12, 2);
  v_delivery numeric(12, 2);
  v_discount numeric(12, 2);
  v_net numeric(12, 2);
  v_courier public.courier_services;
  v_tenant_name text;
  v_rpc jsonb;
  v_bill_id bigint;
  v_tenant_self bigint;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if coalesce(v_order.is_prepaid_snapshot, false) then
    return jsonb_build_object('success', true, 'skipped', true, 'reason', 'prepaid_or_no_cod');
  end if;

  perform public.recompute_dropship_cod_collect_amount(p_order_id);
  select * into v_order from public.shop_orders where id = p_order_id;

  if coalesce(v_order.cod_collect_amount, 0) <= 0 then
    return jsonb_build_object('success', true, 'skipped', true, 'reason', 'prepaid_or_no_cod');
  end if;

  if v_order.courier_service_id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required');
  end if;

  v_books_tenant_id := public.resolve_books_tenant_id(v_order.tenant_id);
  v_tenant_self := public._kernel_tenant_mirror_profile_id(v_books_tenant_id);

  select * into v_courier from public.courier_services where id = v_order.courier_service_id;
  if v_courier.id is null then
    return jsonb_build_object('success', false, 'error', 'courier is required');
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_order.tenant_id;

  perform public.upsert_profile_for_party(
    v_books_tenant_id, 'tenant'::public.profile_party_type, v_order.tenant_id,
    coalesce(v_tenant_name, 'Tenant'), null, null, '+880', null, false, null, true, null
  );

  select p.id into v_profile_id
  from public.profiles p
  where p.tenant_id = v_books_tenant_id
    and p.profile_type = 'courier'::public.profile_party_type
    and p.subject_id = v_courier.wallet_entity_id
  limit 1;

  if v_profile_id is null then
    v_profile_id := public.upsert_profile_for_party(
      v_books_tenant_id, 'courier'::public.profile_party_type, v_courier.wallet_entity_id,
      v_courier.name, null, null, '+880', null, false, null,
      coalesce(v_courier.is_active, true), null
    );
  end if;

  v_cod_face := round(greatest(coalesce(v_order.cod_collect_amount, 0), 0), 2);
  v_rate := round(coalesce(v_order.cod_charge_amount, 0), 2);
  v_delivery := round(coalesce(v_order.delivery_charge_amount, 0), 2);
  v_discount := round(v_rate + v_delivery, 2);
  v_net := greatest(v_cod_face - v_discount, 0);

  if v_net <= 0 then
    return jsonb_build_object('success', true, 'skipped', true, 'reason', 'zero_courier_receivable');
  end if;

  select * into v_bill
  from money_kernel.bills b
  where b.tenant_id = v_books_tenant_id
    and b.source_type = 'dropship_courier_ar'
    and b.source_id = p_order_id::text
    and b.status <> 'voided'
  for update;

  if v_bill.id is not null then
    if coalesce(v_bill.paid_amount, 0) > 0 then
      return jsonb_build_object('success', true, 'bill_id', v_bill.id, 'skipped', true, 'amount', v_bill.total_amount);
    end if;
    perform public._sync_dropship_courier_ar_bill_details(v_bill.id, p_order_id, true);
    perform public.stamp_bill_kernel_fields(v_bill.id);
    select total_amount, status into v_net from money_kernel.bills where id = v_bill.id;
    return jsonb_build_object(
      'success', true, 'bill_id', v_bill.id, 'amount', v_net,
      'invoice_status', public._kernel_bill_invoice_status_enum(
        (select status from money_kernel.bills where id = v_bill.id)
      )
    );
  end if;

  v_rpc := public.rpc_create_bill(jsonb_build_object(
    'tenant_id', v_books_tenant_id,
    'kind', 'dropship_courier_ar',
    'source_entity', 'public.shop_orders',
    'source_type', 'dropship_courier_ar',
    'source_id', p_order_id::text,
    'source_key', 'courier_ar',
    'idempotency_key', format('dropship-courier-ar-%s', p_order_id),
    'currency_code', 'BDT',
    'from_profile_id', v_profile_id,
    'to_profile_id', v_tenant_self,
    'counterparty_profile_id', v_profile_id,
    'auto_issue', not coalesce(p_keep_as_draft, true),
    'note', format('Courier receivable — %s — order %s', v_courier.name, v_order.order_no),
    'meta', jsonb_build_object('shop_order_id', p_order_id),
  'lines', jsonb_build_array(jsonb_build_object(
      'item_kind', 'charge', 'description', 'Net courier remittance',
      'quantity', 1, 'unit_price', v_net, 'line_total', v_net
    ))
  ));

  v_bill_id := nullif(v_rpc->>'bill_id', '')::bigint;
  if v_bill_id is null then
    return jsonb_build_object('success', false, 'error', coalesce(v_rpc->>'error', 'courier AR bill was not created'));
  end if;

  perform public._sync_dropship_courier_ar_bill_details(v_bill_id, p_order_id, true);
  perform public.stamp_bill_kernel_fields(v_bill_id);

  return jsonb_build_object(
    'success', true,
    'bill_id', v_bill_id,
    'created', coalesce((v_rpc->>'idempotent')::boolean, false) = false,
    'amount', v_net,
    'invoice_status', 'draft'
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

GRANT EXECUTE ON FUNCTION public._compose_legacy_items_to_kernel_lines(jsonb) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._kernel_invoice_type_to_bill_kind(public.global_invoice_type) TO authenticated, service_role;