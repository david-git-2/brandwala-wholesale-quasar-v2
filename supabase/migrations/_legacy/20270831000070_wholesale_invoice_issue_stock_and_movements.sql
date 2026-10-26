-- Migration: 20270831000070_wholesale_invoice_issue_stock_and_movements.sql
-- Description: Update post_sales_invoice to support draft & proforma posting, deduct stock, record stock_movements, and skip wallet debit for wholesale invoices

CREATE OR REPLACE FUNCTION "public"."post_sales_invoice"("p_invoice_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  -- Validate required fields per invoice type
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

  -- 1. Snapshot unit costs on line items
  for v_item in select * from public.global_invoice_items where invoice_id = p_invoice_id loop
    v_unit_cost := public.calculate_landed_unit_cost(v_item.shipment_item_id);
    update public.global_invoice_items
    set unit_cost_price = v_unit_cost
    where id = v_item.id;
  end loop;

  -- 2. Deduct physical stock & write stock movement audit
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
      -- Deduct from global_stocks
      update public.global_stocks
      set quantity = quantity - v_qty
      where id = v_item.global_stock_id;

      -- Insert movement line
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

  -- 3. Mark invoice as posted/issued
  update public.global_invoices
  set invoice_status = 'posted'::public.global_invoice_status
  where id = p_invoice_id;

  -- 4. Universal wallet: Only for non-wholesale account invoices
  if v_invoice.invoice_type <> 'wholesale'::public.global_invoice_type
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
