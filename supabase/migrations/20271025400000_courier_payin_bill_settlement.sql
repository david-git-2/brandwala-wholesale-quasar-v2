CREATE OR REPLACE FUNCTION "public"."resolve_dropship_courier_ap_bill_id"(
  "p_order_id" bigint,
  "p_parent_tenant_id" bigint
) RETURNS bigint
    LANGUAGE "sql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
  select b.id
  from public.bills b
  where b.parent_tenant_id = p_parent_tenant_id
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
    and b.invoice_status <> 'voided'::public.global_invoice_status
  order by b.id
  limit 1;
$$;

ALTER FUNCTION "public"."resolve_dropship_courier_ap_bill_id"("p_order_id" bigint, "p_parent_tenant_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."settle_dropship_courier_ap_via_cod_retention"(
  "p_ap_bill_id" bigint,
  "p_amount" numeric,
  "p_order_id" bigint,
  "p_remittance_ref" "text",
  "p_receipt_payment_id" bigint DEFAULT NULL::bigint
) RETURNS numeric
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ap public.bills;
  v_settle numeric(12, 2);
  v_operating_tenant_id bigint;
begin
  if p_ap_bill_id is null then
    return 0;
  end if;

  v_settle := round(greatest(coalesce(p_amount, 0), 0), 2);
  if v_settle <= 0 then
    return 0;
  end if;

  select * into v_ap from public.bills where id = p_ap_bill_id for update;
  if v_ap.id is null then
    raise exception 'courier AP bill not found';
  end if;

  if v_ap.invoice_type <> 'ap'::public.global_invoice_type then
    raise exception 'bill is not an AP bill';
  end if;

  if v_ap.invoice_status <> 'issued'::public.global_invoice_status then
    return 0;
  end if;

  v_settle := least(v_settle, greatest(coalesce(v_ap.due_amount, 0), 0));
  if v_settle <= 0 then
    return 0;
  end if;

  v_operating_tenant_id := coalesce(v_ap.issued_by_tenant_id, v_ap.parent_tenant_id);

  insert into public.invoice_write_offs (
    tenant_id,
    parent_tenant_id,
    invoice_id,
    payment_id,
    amount,
    reason,
    note,
    approved_by
  )
  values (
    v_operating_tenant_id,
    v_ap.parent_tenant_id,
    p_ap_bill_id,
    p_receipt_payment_id,
    v_settle,
    'dispute_settlement',
    format(
      'Courier COD retention — order #%s — remittance %s',
      p_order_id,
      coalesce(nullif(trim(p_remittance_ref), ''), '—')
    ),
    auth.uid()
  );

  perform public.recompute_global_invoice_payment_status(p_ap_bill_id);

  return v_settle;
end;
$$;

ALTER FUNCTION "public"."settle_dropship_courier_ap_via_cod_retention"("p_ap_bill_id" bigint, "p_amount" numeric, "p_order_id" bigint, "p_remittance_ref" "text", "p_receipt_payment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"(
  "p_order_id" bigint,
  "p_delivery_override" numeric DEFAULT NULL::numeric,
  "p_cod_override" numeric DEFAULT NULL::numeric
) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_ar public.bills;
  v_ap public.bills;
  v_charges record;
  v_ar_bal jsonb;
  v_ap_bal jsonb;
  v_net_ar numeric(12, 2);
  v_net_ap numeric(12, 2);
  v_old_ar_charges numeric(12, 2);
  v_wanted_ar numeric(12, 2);
  v_wanted_ap numeric(12, 2);
  v_diff numeric(12, 2);
  v_reason text;
  v_parts text[] := array[]::text[];
  v_ar_adj jsonb;
  v_ap_adj jsonb;
  v_parent_tenant_id bigint;
  v_has_adjustments boolean := false;
  v_courier_name text;
  v_delivery_merchant numeric(12, 2);
  v_cod_merchant numeric(12, 2);
  v_delivery_payer text;
  v_cod_payer text;
  v_delivery_for_ap numeric(12, 2);
  v_cod_for_ap numeric(12, 2);
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'order is not a dropship order');
  end if;

  if v_order.global_invoice_id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice is required');
  end if;

  select * into v_ar from public.bills where id = v_order.global_invoice_id;
  if v_ar.id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice not found');
  end if;

  if v_ar.invoice_status <> 'issued'::public.global_invoice_status then
    return jsonb_build_object(
      'success', true,
      'has_adjustments', false,
      'skipped', true,
      'reason', 'customer invoice not issued'
    );
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select * into v_ap
  from public.bills b
  where b.parent_tenant_id = v_parent_tenant_id
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
    and b.invoice_status <> 'voided'::public.global_invoice_status
  order by b.id
  limit 1;

  if v_order.courier_service_id is not null then
    select cs.name into v_courier_name
    from public.courier_services cs
    where cs.id = v_order.courier_service_id;
  end if;

  select * into v_charges from public.get_dropship_merchant_billable_charges(p_order_id);

  v_delivery_merchant := coalesce(v_charges.delivery, 0);
  v_cod_merchant := coalesce(v_charges.cod, 0);

  if p_delivery_override is not null then
    select coalesce(cl.payer::text, 'recipient')
    into v_delivery_payer
    from public.dropship_order_settlements s
    inner join public.dropship_settlement_charge_lines cl
      on cl.settlement_id = s.id and cl.charge_type = 'delivery'::public.dropship_settlement_charge_type
    where s.shop_order_id = p_order_id
    limit 1;

    if not found then
      v_delivery_payer := case
        when coalesce(v_order.deduct_delivery_from_margin, false) then 'merchant'
        else 'recipient'
      end;
    end if;

    if v_delivery_payer = 'merchant' then
      v_delivery_merchant := round(coalesce(p_delivery_override, 0), 2);
    end if;
  end if;

  if p_cod_override is not null then
    select coalesce(cl.payer::text, 'recipient')
    into v_cod_payer
    from public.dropship_order_settlements s
    inner join public.dropship_settlement_charge_lines cl
      on cl.settlement_id = s.id and cl.charge_type = 'cod'::public.dropship_settlement_charge_type
    where s.shop_order_id = p_order_id
    limit 1;

    if not found then
      v_cod_payer := case
        when coalesce(v_order.deduct_cod_from_margin, false) then 'merchant'
        else 'recipient'
      end;
    end if;

    if v_cod_payer = 'merchant' then
      v_cod_merchant := round(coalesce(p_cod_override, 0), 2);
    end if;
  end if;

  v_ar_bal := public.get_bill_net_balances(v_ar.id);
  v_net_ar := round(
    coalesce((v_ar_bal->>'original_total')::numeric, 0)
    + coalesce((v_ar_bal->>'debits_issued')::numeric, 0)
    - coalesce((v_ar_bal->>'credits_issued')::numeric, 0),
    2
  );

  v_old_ar_charges := round(
    coalesce(v_ar.shipping_charge, 0)
    + coalesce(v_ar.print_charge, 0)
    + coalesce(v_ar.wrapping_charge, 0)
    + coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
    2
  );

  v_wanted_ar := round(
    v_net_ar
    - v_old_ar_charges
    + coalesce(v_delivery_merchant, 0)
    + coalesce(v_charges.print, 0)
    + coalesce(v_charges.packing, 0)
    + coalesce(v_cod_merchant, 0),
    2
  );

  v_diff := round(v_wanted_ar - v_net_ar, 2);

  if abs(v_diff) >= 0.01 then
    v_parts := array[]::text[];
    if coalesce(v_delivery_merchant, 0) is distinct from coalesce(v_ar.shipping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Delivery %s→%s', coalesce(v_ar.shipping_charge, 0), coalesce(v_delivery_merchant, 0))
      );
    end if;
    if coalesce(v_charges.print, 0) is distinct from coalesce(v_ar.print_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Print %s→%s', coalesce(v_ar.print_charge, 0), coalesce(v_charges.print, 0))
      );
    end if;
    if coalesce(v_charges.packing, 0) is distinct from coalesce(v_ar.wrapping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Packing %s→%s', coalesce(v_ar.wrapping_charge, 0), coalesce(v_charges.packing, 0))
      );
    end if;
    if coalesce(v_cod_merchant, 0) is distinct from coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0) then
      v_parts := array_append(
        v_parts,
        format(
          'Courier COD fee %s→%s',
          coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
          coalesce(v_cod_merchant, 0)
        )
      );
    end if;

    v_reason := format(
      'Dropship %s at deliver: %s',
      v_order.order_no,
      coalesce(array_to_string(v_parts, '; '), 'charge adjustment')
    );

    v_ar_adj := jsonb_build_object(
      'bill_id', v_ar.id,
      'invoice_no', v_ar.invoice_no,
      'display_name', coalesce(nullif(trim(v_ar.recipient_name), ''), 'End customer'),
      'invoice_type', v_ar.invoice_type::text,
      'label', 'customer_invoice',
      'adjustment_kind', case when v_diff > 0 then 'debit_note' else 'credit_note' end,
      'amount', abs(v_diff),
      'current_net', v_net_ar,
      'wanted_net', v_wanted_ar,
      'reason', v_reason,
      'detail_parts', to_jsonb(v_parts)
    );
    v_has_adjustments := true;
  end if;

  if v_ap.id is not null and v_ap.invoice_status = 'issued'::public.global_invoice_status then
    v_delivery_for_ap := coalesce(p_delivery_override, v_order.delivery_charge_amount, 0);
    v_cod_for_ap := coalesce(p_cod_override, v_order.cod_charge_amount, 0);
    v_wanted_ap := round(coalesce(v_delivery_for_ap, 0) + coalesce(v_cod_for_ap, 0), 2);

    v_ap_bal := public.get_bill_net_balances(v_ap.id);
    v_net_ap := round(
      coalesce((v_ap_bal->>'original_total')::numeric, 0)
      + coalesce((v_ap_bal->>'debits_issued')::numeric, 0)
      - coalesce((v_ap_bal->>'credits_issued')::numeric, 0),
      2
    );

    v_diff := round(v_wanted_ap - v_net_ap, 2);

    if abs(v_diff) >= 0.01 then
      v_parts := array[]::text[];
      if coalesce(v_delivery_for_ap, 0) is distinct from coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Delivery %s→%s',
            coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0),
            coalesce(v_delivery_for_ap, 0)
          )
        );
      end if;
      if coalesce(v_cod_for_ap, 0) is distinct from coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Courier COD fee %s→%s',
            coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0),
            coalesce(v_cod_for_ap, 0)
          )
        );
      end if;

      v_reason := format(
        'Dropship %s at deliver: %s',
        v_order.order_no,
        coalesce(array_to_string(v_parts, '; '), 'courier charge adjustment')
      );

      v_ap_adj := jsonb_build_object(
        'bill_id', v_ap.id,
        'invoice_no', v_ap.invoice_no,
        'display_name', coalesce(v_courier_name, nullif(trim(v_ap.recipient_name), ''), 'Courier'),
        'invoice_type', v_ap.invoice_type::text,
        'label', 'courier_ap',
        'adjustment_kind', case when v_diff > 0 then 'debit_note' else 'credit_note' end,
        'amount', abs(v_diff),
        'current_net', v_net_ap,
        'wanted_net', v_wanted_ap,
        'reason', v_reason,
        'detail_parts', to_jsonb(v_parts)
      );
      v_has_adjustments := true;
    end if;
  end if;

  return jsonb_build_object(
    'success', true,
    'has_adjustments', v_has_adjustments,
    'customer_invoice', v_ar_adj,
    'courier_ap', v_ap_adj
  );
end;
$$;

ALTER FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint, "p_delivery_override" numeric, "p_cod_override" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."preview_dropship_courier_payin_settlement"(
  "p_order_id" bigint,
  "p_delivery_charge" numeric,
  "p_cod_charge" numeric,
  "p_net_amount" numeric
) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_parent_tenant_id bigint;
  v_ar public.bills;
  v_ap public.bills;
  v_notes jsonb;
  v_net numeric(12, 2);
  v_charge numeric(12, 2);
  v_invoice_due_after numeric(12, 2);
  v_invoice_allocated numeric(12, 2);
  v_ap_due_after numeric(12, 2);
  v_ap_settled numeric(12, 2);
  v_merchant_remainder numeric(12, 2);
  v_ar_adj jsonb;
  v_ap_adj jsonb;
  v_ap_id bigint;
begin
  v_net := round(greatest(coalesce(p_net_amount, 0), 0), 2);
  v_charge := round(greatest(coalesce(p_delivery_charge, 0) + coalesce(p_cod_charge, 0), 0), 2);

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'order not found');
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  v_notes := public.preview_dropship_issued_bill_notes_at_deliver(
    p_order_id,
    p_delivery_charge,
    p_cod_charge
  );

  if coalesce(v_notes->>'success', 'false') <> 'true' then
    return v_notes;
  end if;

  select * into v_ar from public.bills where id = v_order.global_invoice_id;
  if v_ar.id is null then
    return jsonb_build_object('success', false, 'error', 'customer invoice not found');
  end if;

  v_ar_adj := v_notes->'customer_invoice';
  if v_ar_adj is not null and v_ar_adj <> 'null'::jsonb then
    v_invoice_due_after := greatest(coalesce((v_ar_adj->>'wanted_net')::numeric, 0), 0)
      - greatest(coalesce(v_ar.paid_amount, 0), 0);
  else
    v_invoice_due_after := greatest(coalesce(v_ar.due_amount, 0), 0);
  end if;

  v_invoice_due_after := greatest(v_invoice_due_after, 0);
  v_invoice_allocated := least(v_net, v_invoice_due_after);

  v_ap_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_ap_id is not null then
    select * into v_ap from public.bills where id = v_ap_id;
    v_ap_adj := v_notes->'courier_ap';
    if v_ap_adj is not null and v_ap_adj <> 'null'::jsonb then
      v_ap_due_after := greatest(
        coalesce((v_ap_adj->>'wanted_net')::numeric, 0) - greatest(coalesce(v_ap.paid_amount, 0), 0),
        0
      );
    else
      v_ap_due_after := greatest(coalesce(v_ap.due_amount, 0), 0);
    end if;
    v_ap_settled := least(v_ap_due_after, v_charge);
  else
    v_ap_due_after := 0;
    v_ap_settled := 0;
  end if;

  v_merchant_remainder := greatest(v_net - v_invoice_allocated, 0);

  return v_notes || jsonb_build_object(
    'net_amount', v_net,
    'courier_charge', v_charge,
    'invoice_due_after_notes', v_invoice_due_after,
    'invoice_allocated', v_invoice_allocated,
    'courier_ap_bill_id', v_ap_id,
    'courier_ap_due_after_notes', v_ap_due_after,
    'courier_ap_settled', v_ap_settled,
    'merchant_remainder', v_merchant_remainder
  );
end;
$$;

ALTER FUNCTION "public"."preview_dropship_courier_payin_settlement"("p_order_id" bigint, "p_delivery_charge" numeric, "p_cod_charge" numeric, "p_net_amount" numeric) OWNER TO "postgres";
ALTER FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_method" "text", "p_note" "text") OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."patch_dropship_courier_fees_for_remittance"(
  "p_order_id" bigint,
  "p_delivery" numeric,
  "p_cod" numeric
) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order public.shop_orders;
  v_delivery_payer text := 'recipient';
  v_cod_payer text := 'recipient';
  v_charge_lines jsonb;
begin
  if p_delivery is null or p_cod is null then
    raise exception 'delivery and COD fees are required';
  end if;

  if coalesce(p_delivery, 0) < 0 or coalesce(p_cod, 0) < 0 then
    raise exception 'courier fees cannot be negative';
  end if;

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  select coalesce(cl.payer::text, 'recipient')
  into v_delivery_payer
  from public.dropship_order_settlements s
  inner join public.dropship_settlement_charge_lines cl
    on cl.settlement_id = s.id and cl.charge_type = 'delivery'::public.dropship_settlement_charge_type
  where s.shop_order_id = p_order_id
  limit 1;

  if not found then
    v_delivery_payer := case
      when coalesce(v_order.deduct_delivery_from_margin, false) then 'merchant'
      else 'recipient'
    end;
  end if;

  select coalesce(cl.payer::text, 'recipient')
  into v_cod_payer
  from public.dropship_order_settlements s
  inner join public.dropship_settlement_charge_lines cl
    on cl.settlement_id = s.id and cl.charge_type = 'cod'::public.dropship_settlement_charge_type
  where s.shop_order_id = p_order_id
  limit 1;

  if not found then
    v_cod_payer := case
      when coalesce(v_order.deduct_cod_from_margin, false) then 'merchant'
      else 'recipient'
    end;
  end if;

  v_charge_lines := jsonb_build_array(
    jsonb_build_object(
      'charge_type', 'delivery',
      'amount', round(coalesce(p_delivery, 0), 2),
      'payer', v_delivery_payer
    ),
    jsonb_build_object(
      'charge_type', 'cod',
      'amount', round(coalesce(p_cod, 0), 2),
      'payer', v_cod_payer
    )
  );

  perform public.apply_dropship_order_charge_lines(p_order_id, v_charge_lines);

  update public.dropship_settlement_charge_lines cl
  set
    amount = case cl.charge_type
      when 'delivery'::public.dropship_settlement_charge_type then round(coalesce(p_delivery, 0), 2)
      when 'cod'::public.dropship_settlement_charge_type then round(coalesce(p_cod, 0), 2)
      else cl.amount
    end,
    updated_at = now()
  from public.dropship_order_settlements s
  where cl.settlement_id = s.id
    and s.shop_order_id = p_order_id
    and cl.charge_type in (
      'delivery'::public.dropship_settlement_charge_type,
      'cod'::public.dropship_settlement_charge_type
    );
end;
$$;

ALTER FUNCTION "public"."patch_dropship_courier_fees_for_remittance"("p_order_id" bigint, "p_delivery" numeric, "p_cod" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text" DEFAULT NULL::"text", "p_payment_date" "date" DEFAULT NULL::"date", "p_method" "text" DEFAULT 'cash'::"text", "p_note" "text" DEFAULT NULL::"text", "p_courier_charge" numeric DEFAULT 0.00, "p_cashbook_point_id" bigint DEFAULT NULL::bigint, "p_delivery_charge" numeric DEFAULT NULL::numeric, "p_cod_charge" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_order record;
  v_invoice public.bills;
  v_parent_tenant_id bigint;
  v_payment_id bigint;
  v_pay public.pays;
  v_ref text;
  v_cod numeric(12,2);
  v_charge numeric(12,2);
  v_net numeric(12,2);
  v_invoice_due numeric(12,2);
  v_invoice_pay numeric(12,2);
  v_remainder numeric(12,2);
  v_already_remitted boolean := false;
  v_notes jsonb;
  v_ap_bill_id bigint;
  v_ap_settled numeric(12,2) := 0;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status not in ('delivered', 'payment_received') then
    raise exception 'Courier remittance requires order status delivered or payment_received (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

  select (
    exists (
      select 1
      from public.pays py
      where py.shop_order_id = p_order_id
        and py.source = 'courier_remittance'
    )
    or nullif(trim(coalesce(v_order.courier_remittance_ref, '')), '') is not null
  ) into v_already_remitted;

  if v_already_remitted then
    select py.id into v_payment_id
    from public.pays py
    where py.shop_order_id = p_order_id
      and py.source = 'courier_remittance'
    order by py.id desc
    limit 1;

    return jsonb_build_object(
      'success', true,
      'already_recorded', true,
      'invoice_id', v_order.global_invoice_id,
      'payment_id', v_payment_id,
      'order_id', p_order_id,
      'status', v_order.status
    );
  end if;

  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  end if;

  v_net := coalesce(p_net_amount, 0.00);

  if p_delivery_charge is not null or p_cod_charge is not null then
    if p_delivery_charge is null or p_cod_charge is null then
      raise exception 'Both delivery and COD fees are required when overriding courier fees';
    end if;
    perform public.patch_dropship_courier_fees_for_remittance(
      p_order_id,
      p_delivery_charge,
      p_cod_charge
    );
    v_charge := round(coalesce(p_delivery_charge, 0) + coalesce(p_cod_charge, 0), 2);
  else
    v_charge := coalesce(p_courier_charge, 0.00);
  end if;

  select coalesce(s.collected_cod_amount, v_order.cod_collect_amount, 0.00)
  into v_cod
  from public.dropship_order_settlements s
  where s.shop_order_id = p_order_id;

  if not found then
    v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  end if;

  if v_net <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  end if;

  if v_charge < 0.00 then
    raise exception 'Courier charge cannot be negative';
  end if;

  if v_cod > 0 and (v_net + v_charge) > (v_cod + 0.01) then
    raise exception 'Remittance net (%) + charge (%) exceeds COD collect (%)', v_net, v_charge, v_cod;
  end if;

  if p_cashbook_point_id is null then
    raise exception 'Cashbook location is required for courier pay in';
  end if;

  if not (
    public.user_can_manage_parent_tenant(v_parent_tenant_id)
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    raise exception 'Permission denied: Staff or Admin role required';
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;

  if v_invoice.invoice_status <> 'issued'::public.global_invoice_status then
    raise exception 'Merchant bill must be issued before remittance (current: %)', v_invoice.invoice_status;
  end if;

  if v_invoice.invoice_type <> 'dropship'::public.global_invoice_type then
    raise exception 'Remittance applies to dropship merchant bills only';
  end if;

  if v_invoice.profile_id is null then
    raise exception 'Merchant profile is required on the bill';
  end if;

  v_notes := public.apply_dropship_issued_bill_notes_at_deliver(p_order_id);
  if coalesce(v_notes->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_notes->>'error', 'Failed to apply bill notes before courier pay in');
  end if;

  select * into v_invoice from public.bills where id = v_order.global_invoice_id for update;

  v_invoice_due := greatest(coalesce(v_invoice.due_amount, 0.00), 0.00);
  v_invoice_pay := least(v_net, v_invoice_due);
  v_remainder := greatest(v_net - v_invoice_pay, 0.00);

  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => v_net,
    p_courier_charge => v_charge,
    p_remittance_ref => v_ref
  );

  v_pay := public.post_customer_receipt_with_allocations(
    p_tenant_id => v_order.tenant_id,
    p_profile_id => v_invoice.profile_id,
    p_received_on => coalesce(p_payment_date, current_date),
    p_note => coalesce(
      nullif(trim(p_note), ''),
      'Courier remittance order #' || v_order.order_no
        || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
    ),
    p_reference => v_ref,
    p_source => 'courier_remittance'::text,
    p_instruments => jsonb_build_array(
      jsonb_strip_nulls(
        jsonb_build_object(
          'payment_method_code',
            case upper(coalesce(nullif(trim(p_method), ''), 'CASH'))
              when 'BANK_TRANSFER' then 'BANK_TRANSFER'
              when 'BKASH' then 'BKASH'
              else 'CASH'
            end,
          'amount', v_net,
          'reference', nullif(trim(coalesce(p_bank_trx_id, '')), ''),
          'cashbook_point_id', p_cashbook_point_id
        )
      )
    ),
    p_allocations => case
      when v_invoice_pay > 0 then jsonb_build_array(jsonb_build_object('bill_id', v_invoice.id, 'amount', v_invoice_pay))
      else '[]'::jsonb
    end,
    p_shop_order_id => p_order_id
  );
  v_payment_id := v_pay.id;

  v_ap_bill_id := public.resolve_dropship_courier_ap_bill_id(p_order_id, v_parent_tenant_id);
  if v_ap_bill_id is not null then
    v_ap_settled := public.settle_dropship_courier_ap_via_cod_retention(
      v_ap_bill_id,
      v_charge,
      p_order_id,
      v_ref,
      v_payment_id
    );
  end if;

  if v_invoice_pay > 0 and nullif(trim(p_note), '') is not null then
    update public.bills
    set note = trim(p_note), updated_at = now()
    where id = v_invoice.id;
  end if;

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    payout_settlement_status = case
      when v_remainder > 0 then 'unpaid'
      when v_remainder <= 0 then 'paid'
      else payout_settlement_status
    end,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received',
    'net_amount', v_net,
    'courier_charge', v_charge,
    'invoice_allocated', v_invoice_pay,
    'merchant_remainder', v_remainder,
    'courier_ap_bill_id', v_ap_bill_id,
    'courier_ap_settled', v_ap_settled,
    'bill_notes', v_notes
  );
end;
$$;

ALTER FUNCTION "public"."record_dropship_courier_remittance"("p_order_id" bigint, "p_net_amount" numeric, "p_remittance_ref" "text", "p_bank_trx_id" "text", "p_payment_date" "date", "p_method" "text", "p_note" "text", "p_courier_charge" numeric, "p_cashbook_point_id" bigint, "p_delivery_charge" numeric, "p_cod_charge" numeric) OWNER TO "postgres";
