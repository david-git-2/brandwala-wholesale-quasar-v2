-- Dropship tenant B2B invoice: create/update via payload RPCs (desk mark-delivered flow).

begin;

-- ---------------------------------------------------------------------------
-- 1. Build create/update payload from shop order
-- ---------------------------------------------------------------------------
create or replace function public.build_dropship_tenant_b2b_invoice_payload(
  p_order_id bigint,
  p_invoice_id bigint default null,
  p_invoice_no text default null,
  p_billing_profile_id bigint default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_billing_profile_id bigint;
  v_invoice_no text;
  v_item record;
  v_items jsonb := '[]'::jsonb;
  v_item_json jsonb;
  v_item_sell_price numeric(12,2);
  v_unit_cost numeric(12,2);
  v_line_id bigint;
  v_collection_source public.collection_source_type;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    return jsonb_build_object(
      'success', false,
      'error', format('tenant B2B invoice requires delivered status (current: %s)', v_order.status)
    );
  end if;

  v_billing_profile_id := coalesce(p_billing_profile_id, v_order.billing_profile_id);
  if v_billing_profile_id is null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where tenant_id = v_order.tenant_id
      and customer_group_id = v_order.customer_group_id
    order by created_at asc
    limit 1;
  end if;

  if v_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'billing profile is required for creating invoice');
  end if;

  if p_invoice_no is null or trim(p_invoice_no) = '' then
    v_invoice_no := 'INV-DS-' || v_order.order_no;
  else
    v_invoice_no := trim(p_invoice_no);
  end if;

  v_collection_source := case
    when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
    else 'recipient'::public.collection_source_type
  end;

  for v_item in (
    select
      soi.*,
      gs.shipment_item_id as stock_shipment_item_id,
      coalesce(public.calculate_landed_unit_cost(gs.shipment_item_id), 0) as stock_cost,
      gsi.name as stock_name,
      gsi.barcode as stock_barcode,
      gsi.product_code as stock_product_code,
      sh.assigned_child_tenant_id as stock_assigned_child
    from public.shop_order_items soi
    left join public.global_stocks gs on gs.id = soi.global_stock_id
    left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    left join public.global_shipments sh on sh.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) loop
    v_item_sell_price := coalesce(v_item.unit_sell_price_amount, v_item.final_price_amount, 0);
    v_unit_cost := coalesce(v_item.stock_cost, 0);
    v_line_id := null;

    if p_invoice_id is not null then
      select sii.id into v_line_id
      from public.sales_invoice_items sii
      where sii.invoice_id = p_invoice_id
        and (
          (sii.global_stock_id is not null and sii.global_stock_id = v_item.global_stock_id)
          or (sii.global_stock_id is null and sii.product_id = v_item.product_id)
        )
      order by sii.id
      limit 1;
    end if;

    v_item_json := jsonb_strip_nulls(jsonb_build_object(
      'id', v_line_id,
      'global_stock_id', v_item.global_stock_id,
      'product_id', v_item.product_id,
      'shipment_item_id', v_item.stock_shipment_item_id,
      'name_snapshot', coalesce(v_item.stock_name, v_item.name),
      'barcode_snapshot', v_item.stock_barcode,
      'product_code_snapshot', v_item.stock_product_code,
      'quantity', v_item.quantity,
      'unit_cost_price', v_unit_cost,
      'sell_price_amount', v_item_sell_price,
      'line_discount_amount', 0,
      'assigned_child_tenant_id', v_item.stock_assigned_child
    ));

    if v_line_id is null then
      v_item_json := v_item_json - 'id';
    end if;

    v_items := v_items || jsonb_build_array(v_item_json);
  end loop;

  return jsonb_build_object(
    'success', true,
    'payload', jsonb_build_object(
      'invoice', jsonb_strip_nulls(jsonb_build_object(
        'invoice_type', 'dropship',
        'invoice_no', v_invoice_no,
        'billing_profile_id', v_billing_profile_id,
        'recipient_profile_id', v_order.recipient_profile_id,
        'recipient_name', coalesce(v_order.recipient_name, v_order.name),
        'recipient_phone', v_order.recipient_phone,
        'recipient_address', v_order.shipping_address,
        'note', coalesce(p_note, 'B2B Wholesale invoice created from dropship order #' || v_order.order_no),
        'discount_amount', coalesce(v_order.discount_amount, 0),
        'shipping_charge', 0,
        'print_charge', coalesce(v_order.print_charge_amount, 0),
        'wrapping_charge', coalesce(v_order.packing_charge_amount, 0),
        'collection_source', v_collection_source
      )),
      'items', v_items
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Allow issued dropship sync on update_sales_invoice_from_payload
-- ---------------------------------------------------------------------------
create or replace function public.update_sales_invoice_from_payload(
  p_tenant_id bigint,
  p_invoice_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv_patch jsonb;
  v_items jsonb;
  v_remove_ids jsonb;
  v_item_elem jsonb;
  v_invoice public.sales_invoices;
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
  v_stock_parent bigint;
  v_db_item public.sales_invoice_items;
  v_removed_ids bigint[] := '{}';
  v_remove_id bigint;
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
  from public.sales_invoices
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
    if v_inv_patch ? 'billing_profile_id' and nullif(v_inv_patch->>'billing_profile_id', '') is not null then
      if not exists (
        select 1 from public.billing_profiles bp
        where bp.id = (v_inv_patch->>'billing_profile_id')::bigint
          and bp.tenant_id = p_tenant_id
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

    update public.sales_invoices
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
      billing_profile_id = case
        when v_inv_patch ? 'billing_profile_id' then nullif(v_inv_patch->>'billing_profile_id', '')::bigint
        else billing_profile_id
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
      delete from public.sales_invoice_items
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
        from public.sales_invoice_items
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

        update public.sales_invoice_items
        set
          quantity = v_quantity,
          sell_price_amount = v_sell_price,
          line_discount_amount = v_line_discount,
          line_total_amount = v_line_total,
          name_snapshot = case
            when v_item_elem ? 'name_snapshot' then coalesce(nullif(trim(v_item_elem->>'name_snapshot'), ''), name_snapshot)
            else name_snapshot
          end,
          unit_cost_price = case
            when v_item_elem ? 'unit_cost_price' then coalesce(nullif(v_item_elem->>'unit_cost_price', '')::numeric, 0)
            else unit_cost_price
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
          return jsonb_build_object('success', false, 'error', 'new items require global_stock_id', 'code', 'VALIDATION_ERROR');
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
        v_unit_cost := coalesce(
          nullif(v_item_elem->>'unit_cost_price', '')::numeric,
          public.calculate_landed_unit_cost(v_shipment_item_id),
          0
        );
        v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

        insert into public.sales_invoice_items (
          parent_tenant_id,
          invoice_id,
          global_stock_id,
          shipment_item_id,
          product_id,
          name_snapshot,
          barcode_snapshot,
          product_code_snapshot,
          quantity,
          unit_cost_price,
          sell_price_amount,
          line_discount_amount,
          line_total_amount,
          assigned_child_tenant_id
        )
        values (
          v_parent_id,
          p_invoice_id,
          v_global_stock_id,
          v_shipment_item_id,
          v_product_id,
          v_name_snapshot,
          v_barcode_snapshot,
          v_product_code_snapshot,
          v_quantity,
          v_unit_cost,
          v_sell_price,
          v_line_discount,
          v_line_total,
          v_assigned_child
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

  select * into v_invoice from public.sales_invoices where id = p_invoice_id;

  if v_dropship_sync then
    if v_invoice.invoice_status in (
      'draft'::public.global_invoice_status,
      'proforma_generated'::public.global_invoice_status
    ) then
      perform public.post_sales_invoice(p_invoice_id);
      select * into v_invoice from public.sales_invoices where id = p_invoice_id;
    elsif v_invoice.payment_status not in ('paid', 'partially_paid') then
      update public.sales_invoices
      set
        payment_status = 'due',
        due_amount = greatest(coalesce(v_invoice.total_amount, 0) - coalesce(v_invoice.paid_amount, 0), 0),
        updated_at = now()
      where id = p_invoice_id;
      select * into v_invoice from public.sales_invoices where id = p_invoice_id;
    end if;
    perform public.recompute_global_invoice_payment_status(p_invoice_id);
    select * into v_invoice from public.sales_invoices where id = p_invoice_id;
  end if;

  select coalesce(jsonb_agg(to_jsonb(sii.*) order by sii.id), '[]'::jsonb)
  into v_result_items
  from public.sales_invoice_items sii
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
      'billing_profile_id', v_invoice.billing_profile_id,
      'recipient_profile_id', v_invoice.recipient_profile_id,
      'recipient_name', v_invoice.recipient_name,
      'recipient_phone', v_invoice.recipient_phone,
      'recipient_address', v_invoice.recipient_address,
      'collection_source', v_invoice.collection_source,
      'subtotal_amount', v_invoice.subtotal_amount,
      'discount_amount', v_invoice.discount_amount,
      'shipping_charge', v_invoice.shipping_charge,
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
$$;

-- ---------------------------------------------------------------------------
-- 3. issue_dropship_tenant_b2b_invoice via payload RPCs
-- ---------------------------------------------------------------------------
create or replace function public.issue_dropship_tenant_b2b_invoice(
  p_tenant_id bigint,
  p_order_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_build jsonb;
  v_payload jsonb;
  v_result jsonb;
  v_created boolean := false;
  v_billed boolean := false;
  v_orphan_invoice_id bigint;
  v_parent_tenant_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    return jsonb_build_object('success', false, 'error', 'access denied');
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id
  for update;

  if not found then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  if v_order.global_invoice_id is null then
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
    from public.global_invoices i
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
      delete from public.sales_invoice_items where invoice_id = v_orphan_invoice_id;
      delete from public.sales_invoices where id = v_orphan_invoice_id;
    end if;

    v_result := public.create_sales_invoice_from_payload(p_tenant_id, v_payload);
    v_created := true;
  else
    v_build := public.build_dropship_tenant_b2b_invoice_payload(
      p_order_id,
      v_order.global_invoice_id
    );
    if coalesce(v_build->>'success', 'false') <> 'true' then
      return v_build;
    end if;

    v_payload := (v_build->'payload') || jsonb_build_object(
      'options', jsonb_build_object('dropship_sync', true, 'recompute_totals', true)
    );

    v_result := public.update_sales_invoice_from_payload(
      p_tenant_id,
      v_order.global_invoice_id,
      v_payload
    );
    v_created := false;
  end if;

  if coalesce(v_result->>'success', 'false') <> 'true' then
    return coalesce(
      v_result,
      jsonb_build_object('success', false, 'error', 'failed to upsert tenant B2B invoice')
    );
  end if;

  update public.shop_orders
  set
    global_invoice_id = coalesce(v_order.global_invoice_id, (v_result->>'invoice_id')::bigint),
    updated_at = now()
  where id = p_order_id
    and global_invoice_id is null;

  select * into v_order from public.shop_orders where id = p_order_id;
  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;

  if v_invoice.id is null then
    return jsonb_build_object('success', false, 'error', 'invoice was not created');
  end if;

  perform public.canonicalize_dropship_order_wallet_source_ids(p_order_id);
  perform public.ensure_dropship_invoice_billed_entry(v_invoice.id);

  v_billed := exists (
    select 1 from public.universal_wallet_ledger
    where source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  return jsonb_build_object(
    'success', true,
    'created', v_created,
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
      'billing_profile_id', v_invoice.billing_profile_id,
      'collection_source', v_invoice.collection_source
    ),
    'wallet', jsonb_build_object(
      'invoice_billed', v_billed,
      'source_type', 'shop_order',
      'source_id', p_order_id::text
    )
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Retire legacy bodies — thin wrappers
-- ---------------------------------------------------------------------------
create or replace function public.sync_dropship_tenant_b2b_invoice_from_order(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
  v_order public.shop_orders;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'no tenant B2B invoice linked to order');
  end if;

  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

create or replace function public.ensure_dropship_tenant_b2b_invoice_at_delivered(p_order_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id from public.shop_orders where id = p_order_id;
  if v_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;
  return public.issue_dropship_tenant_b2b_invoice(v_tenant_id, p_order_id);
end;
$$;

create or replace function public.create_dual_invoice_from_dropship_order(
  p_order_id bigint,
  p_invoice_no text default null,
  p_billing_profile_id bigint default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_build jsonb;
  v_payload jsonb;
  v_result jsonb;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  v_build := public.build_dropship_tenant_b2b_invoice_payload(
    p_order_id,
    null,
    p_invoice_no,
    p_billing_profile_id,
    p_note
  );
  if coalesce(v_build->>'success', 'false') <> 'true' then
    return v_build;
  end if;

  v_payload := (v_build->'payload') || jsonb_build_object(
    'issue', true,
    'shop_order_id', p_order_id
  );

  v_result := public.create_sales_invoice_from_payload(v_order.tenant_id, v_payload);
  if coalesce(v_result->>'success', 'false') <> 'true' then
    return v_result;
  end if;

  perform public.ensure_dropship_invoice_billed_entry((v_result->>'invoice_id')::bigint);

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_result->>'invoice_id',
    'invoice_no', v_result->>'invoice_no',
    'invoice_status', v_result->>'invoice_status',
    'payment_status', v_result->>'payment_status',
    'subtotal_amount', v_result->'subtotal_amount',
    'total_amount', v_result->'total_amount'
  );
end;
$$;

grant execute on function public.build_dropship_tenant_b2b_invoice_payload(bigint, bigint, text, bigint, text) to authenticated;
grant execute on function public.issue_dropship_tenant_b2b_invoice(bigint, bigint) to authenticated;
grant execute on function public.sync_dropship_tenant_b2b_invoice_from_order(bigint) to authenticated;
grant execute on function public.ensure_dropship_tenant_b2b_invoice_at_delivered(bigint) to authenticated;
grant execute on function public.create_dual_invoice_from_dropship_order(bigint, text, bigint, text) to authenticated;
grant execute on function public.update_sales_invoice_from_payload(bigint, bigint, jsonb) to authenticated;

commit;
