-- BP17 + BP24 later cleanup (schemas source)

-- BP24: commission / merchant profit payout on money spine (replaces dispense as writer).

ALTER TABLE public.pays DROP CONSTRAINT IF EXISTS pays_source_check;
ALTER TABLE public.pays ADD CONSTRAINT pays_source_check CHECK (
  source = ANY (ARRAY[
    'customer_cash'::text,
    'bank'::text,
    'store_credit'::text,
    'courier_remittance'::text,
    'ap_payout'::text,
    'commission'::text
  ])
);

CREATE OR REPLACE FUNCTION public._kernel_post_commission_payout(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_payout_method text DEFAULT 'bank_transfer',
  p_cashbook_point_id bigint DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_profile public.profiles;
  v_parent_tenant_id bigint;
  v_pot_id bigint := p_cashbook_point_pot_id;
  v_pay public.pays;
  v_existing public.pays;
  v_ledger_source_id text;
  v_method text := coalesce(nullif(btrim(p_payout_method), ''), 'bank_transfer');
  v_paid_on date := coalesce(p_paid_on, current_date);
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;
  if p_profile_id is null then
    raise exception 'Billing profile ID is required';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payout amount must be greater than 0';
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied for tenant %', p_tenant_id;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);

  v_existing := public._kernel_claim_pay_idempotency(v_parent_tenant_id, p_idempotency_key);
  if v_existing.id is not null then
    return v_existing;
  end if;

  select * into v_profile
  from public.profiles
  where id = p_profile_id
    and profile_type = 'customer'::public.profile_party_type;

  if v_profile.id is null or not public.profile_valid_for_issuer(p_profile_id, p_tenant_id) then
    raise exception 'Customer profile #% not found for tenant %', p_profile_id, p_tenant_id;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Choose a cash point for this pay out';
  end if;

  if not exists (
    select 1
    from public.cashbook_points cp
    join public.cashbook_accounts ca on ca.id = cp.cashbook_account_id
    where cp.id = p_cashbook_point_id
      and cp.is_active = true
      and ca.parent_tenant_id = v_parent_tenant_id
      and ca.entity_type = 'tenant'
      and ca.entity_id = v_parent_tenant_id
  ) then
    raise exception 'Invalid cash point for this tenant';
  end if;

  if v_pot_id is null then
    select cpp.id
    into v_pot_id
    from public.cashbook_point_pots cpp
    where cpp.cashbook_point_id = p_cashbook_point_id
      and cpp.parent_tenant_id = v_parent_tenant_id
    order by case when upper(cpp.currency_code) = 'BDT' then 0 else 1 end, cpp.id
    limit 1;
  end if;

  if v_pot_id is null then
    raise exception 'No currency pot at this cash point';
  end if;

  perform public._kernel_lock_cashbook_point_pots(p_cashbook_point_id);

  insert into public.pays (
    tenant_id,
    profile_id,
    source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note,
    settlement_currency_code,
    foreign_amount,
    exchange_rate,
    quote_currency_code,
    cashbook_point_id,
    cashbook_point_pot_id
  ) values (
    v_parent_tenant_id,
    p_profile_id,
    'commission',
    round(p_amount, 2),
    0.00,
    v_paid_on,
    v_method,
    coalesce(nullif(btrim(p_reference), ''), nullif(btrim(p_source_id), '')),
    p_note,
    'BDT',
    null,
    1.000000,
    'BDT',
    p_cashbook_point_id,
    v_pot_id
  ) returning * into v_pay;

  v_ledger_source_id := coalesce(nullif(btrim(p_source_id), ''), v_pay.id::text);

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_tenant_id,
    p_type => 'debit',
    p_amount => round(p_amount, 2),
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_ledger_source_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_tenant_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'profile_id', p_profile_id,
      'profile_name', v_profile.name,
      'payout_method', v_method,
      'notes', p_note,
      'cashbook_point_pot_id', v_pot_id,
      'pay_id', v_pay.id,
      'commission_source_id', nullif(btrim(p_source_id), '')
    ),
    p_cashbook_point_id => p_cashbook_point_id
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_profile_id,
    p_type => 'debit',
    p_amount => round(p_amount, 2),
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_ledger_source_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'payout_method', v_method,
      'notes', p_note,
      'pay_id', v_pay.id
    )
  );

  perform public.apply_dropship_payout_settlement_fifo(
    p_tenant_id,
    p_profile_id,
    round(p_amount, 2)
  );

  return public._kernel_finalize_pay_idempotency(v_pay.id, v_parent_tenant_id, p_idempotency_key);
end;
$$;

CREATE OR REPLACE FUNCTION public.dispense_middleman_payout_from_tenant(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_amount numeric,
  p_payout_method text DEFAULT 'bank_transfer',
  p_reference_notes text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
begin
  v_pay := public._kernel_post_commission_payout(
    p_tenant_id,
    p_profile_id,
    current_date,
    p_amount,
    p_reference_notes,
    null,
    p_payout_method,
    p_cashbook_point_id,
    p_cashbook_point_pot_id,
    null,
    null
  );

  return jsonb_build_object(
    'success', true,
    'payout_id', v_pay.id::text,
    'payment_id', v_pay.id,
    'profile_id', p_profile_id,
    'amount', p_amount
  );
exception
  when others then
    return jsonb_build_object('success', false, 'error', sqlerrm);
end;
$$;

GRANT EXECUTE ON FUNCTION public._kernel_post_commission_payout(
  bigint, bigint, date, numeric, text, text, text, bigint, bigint, text, text
) TO authenticated, service_role;

GRANT EXECUTE ON FUNCTION public.dispense_middleman_payout_from_tenant(
  bigint, bigint, numeric, text, text, bigint, bigint
) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.post_money_out(
  p_tenant_id bigint,
  p_profile_id bigint,
  p_paid_on date,
  p_amount numeric,
  p_source text DEFAULT 'ap_payout',
  p_note text DEFAULT NULL,
  p_reference text DEFAULT NULL,
  p_cashbook_point_id bigint DEFAULT NULL,
  p_instruments jsonb DEFAULT '[]'::jsonb,
  p_allocations jsonb DEFAULT '[]'::jsonb,
  p_settlement_currency_code text DEFAULT 'BDT',
  p_foreign_amount numeric DEFAULT NULL,
  p_exchange_rate numeric DEFAULT NULL,
  p_source_type text DEFAULT NULL,
  p_source_id text DEFAULT NULL,
  p_idempotency_key text DEFAULT NULL,
  p_cashbook_point_pot_id bigint DEFAULT NULL,
  p_payout_method text DEFAULT 'bank_transfer'
) RETURNS public.pays
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_pay public.pays;
begin
  if coalesce(p_source_type, '') = 'commission' or p_source = 'commission' then
    return public._kernel_post_commission_payout(
      p_tenant_id,
      p_profile_id,
      p_paid_on,
      p_amount,
      p_note,
      p_reference,
      p_payout_method,
      p_cashbook_point_id,
      p_cashbook_point_pot_id,
      p_source_id,
      p_idempotency_key
    );
  end if;

  if p_cashbook_point_id is null then
    raise exception 'cashbook_point_id required for pay out';
  end if;

  v_pay := public.post_ap_payout_with_allocations(
    p_tenant_id,
    p_profile_id,
    p_paid_on,
    p_cashbook_point_id,
    p_note,
    p_reference,
    p_instruments,
    p_allocations,
    p_settlement_currency_code,
    p_foreign_amount,
    p_exchange_rate,
    null,
    null,
    null,
    p_idempotency_key
  );

  return v_pay;
end;
$$;

-- BP17: wholesale stock commit before kernel issue (warehouse orchestration).

CREATE OR REPLACE FUNCTION public._bill_line_global_stock_id(p_line public.bill_lines)
RETURNS bigint
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
    nullif(p_line.line_meta->'stock_ref'->>'global_stock_id', '')::bigint,
    p_line.global_stock_id
  );
$$;

CREATE OR REPLACE FUNCTION public.commit_wholesale_bill_stock(p_bill_id bigint)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_invoice public.bills;
  v_db_item public.bill_lines%rowtype;
  v_stock_id bigint;
  v_qty integer;
  v_stock record;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_has_stock boolean := false;
begin
  select * into v_invoice from public.bills where id = p_bill_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can commit stock';
  end if;

  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  select sm.id
  into v_mov_id
  from public.stock_movements sm
  where sm.reference_type = 'sales_invoice'
    and sm.reference_id = p_bill_id::text
    and sm.is_posted = true
  order by sm.id desc
  limit 1;

  if v_mov_id is not null then
    return v_mov_id;
  end if;

  select exists (
    select 1
    from public.bill_lines bl
    where bl.invoice_id = p_bill_id
      and public._bill_line_global_stock_id(bl) is not null
  ) into v_has_stock;

  if not v_has_stock then
    return null;
  end if;

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
    p_bill_id::text,
    'Issued Wholesale Invoice #' || coalesce(v_invoice.invoice_no, p_bill_id::text),
    public.current_user_email(),
    true,
    now()
  ) returning id into v_mov_id;

  for v_db_item in select * from public.bill_lines where invoice_id = p_bill_id loop
    v_stock_id := public._bill_line_global_stock_id(v_db_item);
    if v_stock_id is null then
      continue;
    end if;

    v_qty := ceil(v_db_item.quantity)::integer;

    select * into v_stock from public.global_stocks where id = v_stock_id for update;
    if v_stock.id is null then
      raise exception 'Stock % not found for line %', v_stock_id, v_db_item.name_snapshot;
    end if;
    if v_stock.quantity < v_qty then
      raise exception 'Insufficient stock for % (requested %, available %)', v_db_item.name_snapshot, v_qty, v_stock.quantity;
    end if;

    update public.global_stocks
    set quantity = quantity - v_qty
    where id = v_stock_id;

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
      v_stock_id,
      v_qty,
      v_stock.location_id,
      v_stock.location_id,
      v_stock.availability,
      v_stock.availability
    );
  end loop;

  return v_mov_id;
end;
$$;

GRANT EXECUTE ON FUNCTION public.commit_wholesale_bill_stock(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public._bill_line_global_stock_id(public.bill_lines) TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public._insert_bill_line_from_compose_payload(
  p_parent_id bigint,
  p_invoice_id bigint,
  p_item_elem jsonb
) RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_global_stock_id bigint;
  v_quantity numeric;
  v_sell_price numeric;
  v_line_discount numeric;
  v_line_total numeric;
  v_line_meta jsonb;
  v_line_kind text;
  v_name_snapshot text;
  v_created_item_id bigint;
  v_stock_parent bigint;
  v_shipment_item_id bigint;
  v_product_id bigint;
  v_barcode_snapshot text;
  v_product_code_snapshot text;
  v_assigned_child bigint;
begin
  v_line_meta := coalesce(p_item_elem->'line_meta', '{}'::jsonb);
  v_global_stock_id := coalesce(
    nullif(p_item_elem->>'global_stock_id', '')::bigint,
    nullif(v_line_meta->'stock_ref'->>'global_stock_id', '')::bigint
  );
  v_quantity := nullif(p_item_elem->>'quantity', '')::numeric;
  v_sell_price := nullif(p_item_elem->>'sell_price_amount', '')::numeric;
  v_line_discount := coalesce(nullif(p_item_elem->>'line_discount_amount', '')::numeric, 0);
  v_line_kind := lower(trim(coalesce(p_item_elem->>'line_kind', '')));

  if v_quantity is null or v_quantity <= 0 then
    raise exception 'each item requires quantity > 0';
  end if;
  if v_sell_price is null or v_sell_price < 0 then
    raise exception 'each item requires sell_price_amount >= 0';
  end if;

  if v_global_stock_id is null and coalesce(v_line_meta->>'is_warehouse_gift', 'false') = 'true' then
    v_product_id := nullif(p_item_elem->>'product_id', '')::bigint;
    v_shipment_item_id := nullif(p_item_elem->>'shipment_item_id', '')::bigint;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Gift item');
    v_line_total := coalesce(
      nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
      greatest((v_quantity * v_sell_price) - v_line_discount, 0)
    );

    insert into public.bill_lines (
      parent_tenant_id, invoice_id, global_stock_id, shipment_item_id, product_id,
      name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
      sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
    ) values (
      p_parent_id, p_invoice_id, null, v_shipment_item_id, v_product_id,
      v_name_snapshot,
      nullif(trim(p_item_elem->>'barcode_snapshot'), ''),
      nullif(trim(p_item_elem->>'product_code_snapshot'), ''),
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      nullif(p_item_elem->>'assigned_child_tenant_id', '')::bigint,
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  if v_global_stock_id is null then
    if v_line_kind = '' then
      v_line_kind := 'description';
    end if;
    if v_line_kind not in ('description', 'charge') then
      raise exception 'non-stock items require line_kind description or charge';
    end if;
    v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), 'Line');
    v_line_total := greatest((v_quantity * v_sell_price) - v_line_discount, 0);

    insert into public.bill_lines (
      parent_tenant_id, invoice_id, line_kind, global_stock_id, name_snapshot,
      quantity, sell_price_amount, line_discount_amount, line_total_amount,
      currency_code, books_amount, line_meta
    ) values (
      p_parent_id, p_invoice_id, v_line_kind, null, v_name_snapshot,
      v_quantity, v_sell_price, v_line_discount, v_line_total,
      upper(trim(coalesce(p_item_elem->>'currency_code', 'BDT'))),
      coalesce(nullif(p_item_elem->>'books_amount', '')::numeric, v_line_total),
      v_line_meta
    )
    returning id into v_created_item_id;
    return v_created_item_id;
  end if;

  select
    gs.parent_tenant_id, gs.shipment_item_id, gsi.name, gsi.barcode, gsi.product_code,
    sh.assigned_child_tenant_id, p.id
  into
    v_stock_parent, v_shipment_item_id, v_name_snapshot, v_barcode_snapshot,
    v_product_code_snapshot, v_assigned_child, v_product_id
  from public.global_stocks gs
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments sh on sh.id = gsi.shipment_id
  left join public.products p on p.id = gsi.product_id
  where gs.id = v_global_stock_id;

  if v_stock_parent is null then
    raise exception 'stock % not found', v_global_stock_id;
  end if;
  if v_stock_parent <> p_parent_id then
    raise exception 'stock % does not belong to invoice parent tenant', v_global_stock_id;
  end if;

  v_shipment_item_id := coalesce(nullif(p_item_elem->>'shipment_item_id', '')::bigint, v_shipment_item_id);
  v_product_id := coalesce(nullif(p_item_elem->>'product_id', '')::bigint, v_product_id);
  v_name_snapshot := coalesce(nullif(trim(p_item_elem->>'name_snapshot'), ''), v_name_snapshot, 'Item');
  v_line_total := coalesce(
    nullif(v_line_meta->>'gift_line_total_amount', '')::numeric,
    greatest((v_quantity * v_sell_price) - v_line_discount, 0)
  );

  v_line_meta := jsonb_set(
    coalesce(v_line_meta, '{}'::jsonb),
    '{stock_ref}',
    jsonb_build_object('global_stock_id', v_global_stock_id),
    true
  );

  insert into public.bill_lines (
    parent_tenant_id, invoice_id, line_kind, global_stock_id, shipment_item_id, product_id,
    name_snapshot, barcode_snapshot, product_code_snapshot, quantity,
    sell_price_amount, line_discount_amount, line_total_amount, assigned_child_tenant_id, line_meta
  ) values (
    p_parent_id, p_invoice_id, 'stock', v_global_stock_id, v_shipment_item_id, v_product_id,
    v_name_snapshot, v_barcode_snapshot, v_product_code_snapshot,
    v_quantity, v_sell_price, v_line_discount, v_line_total, v_assigned_child, v_line_meta
  )
  returning id into v_created_item_id;
  return v_created_item_id;
end;
$$;

CREATE OR REPLACE FUNCTION public._kernel_issue_wholesale_stock(p_invoice_id bigint, p_items jsonb DEFAULT NULL::jsonb)
 RETURNS bills
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_invoice public.bills;
  v_item_record jsonb;
  v_item_id bigint;
  v_item_qty numeric;
  v_item_price numeric;
  v_line_total numeric;
  v_db_item public.bill_lines%rowtype;
  v_unit_cost numeric;
  v_mov_id bigint;
  v_mov_no text;
  v_parent_id bigint;
  v_eff_tenant_id bigint;
  v_stock record;
  v_qty integer;
begin
  select * into v_invoice from public.bills where id = p_invoice_id for update;
  if v_invoice.id is null then raise exception 'Invoice not found'; end if;
  if v_invoice.invoice_status not in ('draft'::public.global_invoice_status, 'proforma_generated'::public.global_invoice_status) then
    raise exception 'Only draft or proforma invoices can be issued';
  end if;

  if v_invoice.profile_id is null then
    raise exception 'Billing profile is required for wholesale invoices';
  end if;

  v_eff_tenant_id := coalesce(v_invoice.issued_by_tenant_id, v_invoice.parent_tenant_id);
  v_parent_id := coalesce(v_invoice.parent_tenant_id, v_invoice.issued_by_tenant_id);

  -- 1. Optionally apply batch quantity/price updates from dialog payload
  if p_items is not null and jsonb_typeof(p_items) = 'array' and jsonb_array_length(p_items) > 0 then
    for v_item_record in select * from jsonb_array_elements(p_items) loop
      v_item_id := (v_item_record->>'id')::bigint;
      v_item_qty := (v_item_record->>'quantity')::numeric;
      v_item_price := (v_item_record->>'sell_price_amount')::numeric;

      if v_item_id is not null and v_item_qty is not null and v_item_qty > 0 then
        select * into v_db_item from public.bill_lines where id = v_item_id and invoice_id = p_invoice_id;
        if v_db_item.id is not null then
          v_item_price := coalesce(v_item_price, v_db_item.sell_price_amount);
          v_line_total := greatest((v_item_qty * v_item_price) - coalesce(v_db_item.line_discount_amount, 0.00), 0.00);

          update public.bill_lines
          set
            quantity = v_item_qty,
            sell_price_amount = v_item_price,
            line_total_amount = v_line_total
          where id = v_item_id;
        end if;
      end if;
    end loop;

    perform public.recompute_global_invoice_totals(p_invoice_id);
  end if;

  if not exists (select 1 from public.bill_lines where invoice_id = p_invoice_id) then
    raise exception 'Cannot issue an empty invoice';
  end if;

  if exists (
    select 1
    from public.bill_lines bl
    where bl.invoice_id = p_invoice_id
      and public._bill_line_global_stock_id(bl) is not null
  ) and not exists (
    select 1
    from public.stock_movements sm
    where sm.reference_type = 'sales_invoice'
      and sm.reference_id = p_invoice_id::text
      and sm.is_posted = true
  ) then
    raise exception 'Stock must be committed before issue — call commit_wholesale_bill_stock first';
  end if;

  -- Mark invoice as issued (status = 'issued'::public.global_invoice_status)
  update public.bills
  set
    invoice_status = 'issued'::public.global_invoice_status,
    payment_status = coalesce(nullif(payment_status, ''), 'due')
  where id = p_invoice_id
  returning * into v_invoice;

  return v_invoice;
end;
$function$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_invoice(p_invoice_id bigint, p_items jsonb DEFAULT NULL)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  return public.issue_wholesale_bill(p_invoice_id, p_items);
end;
$$;

CREATE OR REPLACE FUNCTION public.issue_wholesale_bill(
  p_bill_id bigint,
  p_items jsonb DEFAULT NULL
)
RETURNS public.bills
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  perform public.commit_wholesale_bill_stock(p_bill_id);
  return public._kernel_issue_wholesale_stock(p_bill_id, p_items);
end;
$$;

UPDATE public.bill_lines SET line_meta = jsonb_set(coalesce(line_meta, '{}'::jsonb), '{stock_ref}', jsonb_build_object('global_stock_id', global_stock_id), true) WHERE global_stock_id IS NOT NULL AND (line_meta->'stock_ref' IS NULL OR line_meta->'stock_ref' = 'null'::jsonb);
