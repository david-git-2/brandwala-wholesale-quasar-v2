-- Dropship tenant B2B invoice: accounting only on issue.
-- Wallet: courier COD credit on mark-delivered (confirm_dropship_delivered_costing), not customer invoice_billed.

begin;

create or replace function public.ensure_dropship_invoice_billed_entry(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Intentionally no-op. Dropship B2B invoice does not debit the billing profile wallet.
  -- Courier COD is credited in confirm_dropship_delivered_costing at mark-delivered.
  return;
end;
$$;

-- Patch post_sales_invoice wallet hook: retail account invoices only.
create or replace function public.post_sales_invoice(p_invoice_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice public.global_invoices;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.global_invoices where id = p_invoice_id for update;
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
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.billing_profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.billing_profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

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
    p_invoice_id::text,
    'Issued ' || upper(v_invoice.invoice_type::text) || ' Invoice #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_qty := ceil(v_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
    if v_stock.id is not null then
      if v_invoice.invoice_type = 'dropship'::public.global_invoice_type
         and v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'dropship invoice stock % must be held before issue', v_item.global_stock_id;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'insufficient stock quantity on stock % (requested %, available %)',
          v_item.global_stock_id, v_qty, v_stock.quantity;
      end if;

      update public.global_stocks
      set quantity = quantity - v_qty, updated_at = now()
      where id = v_stock.id;

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
        v_item.global_stock_id,
        v_qty,
        v_stock.location_id,
        v_stock.location_id,
        v_stock.availability,
        v_stock.availability
      );
    end if;
  end loop;

  update public.sales_invoices
  set invoice_status = 'issued'::public.global_invoice_status
  where id = p_invoice_id;

  -- Retail account invoices only. Wholesale = AR. Dropship B2B = courier COD on deliver.
  if v_invoice.invoice_type = 'retail'::public.global_invoice_type
     and v_invoice.billing_profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.universal_wallet_ledger
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.billing_profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.billing_profile_id,
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
  v_courier_cod_booked boolean := false;
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

  v_courier_cod_booked := exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = p_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'delivered_costing'
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

grant execute on function public.ensure_dropship_invoice_billed_entry(bigint) to authenticated;
grant execute on function public.ensure_dropship_invoice_billed_entry(bigint) to service_role;
grant execute on function public.post_sales_invoice(bigint) to authenticated;
grant execute on function public.issue_dropship_tenant_b2b_invoice(bigint, bigint) to authenticated;

commit;
