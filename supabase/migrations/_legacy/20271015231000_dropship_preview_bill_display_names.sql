-- Enrich dropship deliver bill note preview with bill display names
CREATE OR REPLACE FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint) RETURNS "jsonb"
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
    + coalesce(v_charges.delivery, 0)
    + coalesce(v_charges.print, 0)
    + coalesce(v_charges.packing, 0)
    + coalesce(v_charges.cod, 0),
    2
  );

  v_diff := round(v_wanted_ar - v_net_ar, 2);

  if abs(v_diff) >= 0.01 then
    v_parts := array[]::text[];
    if coalesce(v_charges.delivery, 0) is distinct from coalesce(v_ar.shipping_charge, 0) then
      v_parts := array_append(
        v_parts,
        format('Delivery %s→%s', coalesce(v_ar.shipping_charge, 0), coalesce(v_charges.delivery, 0))
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
    if coalesce(v_charges.cod, 0) is distinct from coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0) then
      v_parts := array_append(
        v_parts,
        format(
          'Courier COD fee %s→%s',
          coalesce((v_ar.channel_meta->>'cod_charge_amount')::numeric, 0),
          coalesce(v_charges.cod, 0)
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
    v_wanted_ap := round(
      coalesce(v_order.delivery_charge_amount, 0) + coalesce(v_order.cod_charge_amount, 0),
      2
    );

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
      if coalesce(v_order.delivery_charge_amount, 0) is distinct from coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Delivery %s→%s',
            coalesce((v_ap.channel_meta->>'delivery_charge_amount')::numeric, 0),
            coalesce(v_order.delivery_charge_amount, 0)
          )
        );
      end if;
      if coalesce(v_order.cod_charge_amount, 0) is distinct from coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0) then
        v_parts := array_append(
          v_parts,
          format(
            'Courier COD fee %s→%s',
            coalesce((v_ap.channel_meta->>'cod_charge_amount')::numeric, 0),
            coalesce(v_order.cod_charge_amount, 0)
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

ALTER FUNCTION "public"."preview_dropship_issued_bill_notes_at_deliver"("p_order_id" bigint) OWNER TO "postgres";
