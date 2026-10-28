-- BP17: post_sales_invoice stock via commit_sales_bill_stock

CREATE OR REPLACE FUNCTION public.post_sales_invoice(p_invoice_id bigint) RETURNS void
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_invoice public.bills;
  v_item public.global_invoice_items%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
  v_delivery_kind text;
  v_held_stock_id bigint;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
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
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for wholesale invoices';
    end if;
  elsif v_invoice.invoice_type = 'retail'::public.global_invoice_type then
    if v_invoice.retail_billing_mode = 'account'::public.retail_billing_mode then
      if v_invoice.profile_id is null then
        raise exception 'billing profile is required for retail account invoices';
      end if;
    elsif v_invoice.retail_billing_mode = 'direct'::public.retail_billing_mode then
      if v_invoice.profile_id is not null then
        raise exception 'billing profile must be null for retail direct invoices';
      end if;
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for retail invoices';
    end if;
  elsif v_invoice.invoice_type = 'dropship'::public.global_invoice_type then
    if v_invoice.profile_id is null then
      raise exception 'billing profile is required for dropship invoices';
    end if;
    if nullif(trim(v_invoice.recipient_name), '') is null or
       nullif(trim(v_invoice.recipient_phone), '') is null or
       nullif(trim(v_invoice.recipient_address), '') is null then
      raise exception 'recipient name, phone, and address are required for dropship invoices';
    end if;
  end if;

  v_delivery_kind := lower(trim(coalesce(v_invoice.channel_meta->>'delivery_kind', 'take')));
  if v_delivery_kind not in ('take', 'condition') then
    v_delivery_kind := 'take';
  end if;

  if v_invoice.invoice_type = 'wholesale'::public.global_invoice_type
     and v_delivery_kind = 'condition' then
    for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
      v_qty := ceil(v_item.quantity)::integer;

      select * into v_stock from public.global_stocks where id = v_item.global_stock_id for update;
      if v_stock.id is null then
        continue;
      end if;

      if v_stock.quantity < v_qty then
        raise exception 'insufficient stock quantity on stock % (requested %, available %)',
          v_item.global_stock_id, v_qty, v_stock.quantity;
      end if;

      if v_stock.availability = 'sellable'::public.stock_availability then
        perform public.create_and_post_stock_movement(
          p_tenant_id => v_parent_id,
          p_stock_id => v_item.global_stock_id,
          p_quantity => v_qty,
          p_to_availability => 'held'::public.stock_availability,
          p_movement_type => 'availability_transfer'::public.stock_movement_type,
          p_notes => 'Condition bill #' || coalesce(v_invoice.invoice_no, p_invoice_id::text),
          p_reference_type => 'sales_invoice',
          p_reference_id => p_invoice_id::text
        );

        select gs.id
        into v_held_stock_id
        from public.global_stocks gs
        where gs.shipment_item_id = v_stock.shipment_item_id
          and gs.availability = 'held'::public.stock_availability
          and gs.location_id = v_stock.location_id
          and gs.grade_tag_id = coalesce(v_stock.grade_tag_id, public.default_stock_grade_tag_id())
        order by gs.id desc
        limit 1;

        if v_held_stock_id is null then
          raise exception 'held stock not found after condition transfer for line %', v_item.id;
        end if;

        update public.bill_lines
        set line_meta = jsonb_set(
          coalesce(line_meta, '{}'::jsonb),
          '{stock_ref}',
          jsonb_build_object('global_stock_id', v_held_stock_id),
          true
        )
        where id = v_item.id;
      elsif v_stock.availability <> 'held'::public.stock_availability then
        raise exception 'condition bill stock % must be sellable or held (current: %)',
          v_item.global_stock_id, v_stock.availability;
      end if;
    end loop;
  else
    perform public.commit_sales_bill_stock(p_invoice_id);
  end if;

  update public.bills
  set invoice_status = 'issued'::public.global_invoice_status
  where id = p_invoice_id;

  perform public._kernel_freeze_bill_txn_face(p_invoice_id);
  perform public.recompute_global_invoice_payment_status(p_invoice_id);

  if v_invoice.invoice_type = 'retail'::public.global_invoice_type
     and v_invoice.profile_id is not null
     and coalesce(v_invoice.total_amount, 0) > 0
  then
    if not exists (
      select 1 from public.cashbook_entries
      where source_type = 'sales_invoice'
        and source_id = p_invoice_id::text
        and entity_type = 'customer'
        and entity_id = v_invoice.profile_id
        and metadata->>'transaction_type' = 'invoice_billed'
    ) then
      perform public.record_ledger_transaction(
        p_tenant_id => v_eff_tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_invoice.profile_id,
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