-- Migration: Dropship management desk RPCs (DROPSHIP_MANAGEMENT.md §4, §7)

begin;

-- ---------------------------------------------------------------------------
-- Internal: compute settlement totals (§8 formulas)
-- ---------------------------------------------------------------------------
create or replace function public.compute_dropship_settlement_totals(
  p_collected_cod numeric,
  p_reseller_purchase_cost numeric,
  p_discount_company_pay numeric,
  p_charge_lines jsonb
)
returns table (
  total_cost numeric,
  reseller_profit numeric,
  company_profit numeric,
  merchant_paid_charges numeric
)
language plpgsql
immutable
as $$
declare
  v_charge_sum numeric := 0;
  v_merchant_paid numeric := 0;
  v_line jsonb;
begin
  if p_charge_lines is not null and jsonb_typeof(p_charge_lines) = 'array' then
    for v_line in select value from jsonb_array_elements(p_charge_lines)
    loop
      v_charge_sum := v_charge_sum + coalesce((v_line->>'amount')::numeric, 0);
      if coalesce(v_line->>'payer', '') = 'merchant' then
        v_merchant_paid := v_merchant_paid + coalesce((v_line->>'amount')::numeric, 0);
      end if;
    end loop;
  end if;

  total_cost := coalesce(p_reseller_purchase_cost, 0) + v_charge_sum;
  merchant_paid_charges := v_merchant_paid;
  reseller_profit := coalesce(p_collected_cod, 0) - coalesce(p_reseller_purchase_cost, 0) - v_merchant_paid;
  company_profit := reseller_profit - coalesce(p_discount_company_pay, 0);
  return next;
end;
$$;

-- ---------------------------------------------------------------------------
-- Internal: default charge lines from shop_orders (§118-131)
-- ---------------------------------------------------------------------------
create or replace function public.build_default_dropship_settlement_charge_lines(
  p_order public.shop_orders
)
returns jsonb
language plpgsql
stable
as $$
begin
  return jsonb_build_array(
    jsonb_build_object(
      'charge_type', 'delivery',
      'amount', coalesce(p_order.delivery_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_delivery_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'print',
      'amount', coalesce(p_order.print_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_print_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'packing',
      'amount', coalesce(p_order.packing_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_packing_from_margin, false) then 'merchant' else 'recipient' end
    ),
    jsonb_build_object(
      'charge_type', 'return',
      'amount', coalesce(p_order.return_charge_amount, 0),
      'payer', case when coalesce(p_order.deduct_return_charge_from_middle_man, true) then 'merchant' else 'company' end
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- save_dropship_settlement_draft
-- ---------------------------------------------------------------------------
create or replace function public.save_dropship_settlement_draft(
  p_tenant_id bigint,
  p_order_id bigint,
  p_payload jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_detail jsonb;
  v_settlement public.dropship_order_settlements;
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_reseller_purchase_cost numeric(15,2);
  v_discount_company_pay numeric(15,2);
  v_return_reason_note text;
  v_charge_lines jsonb;
  v_line jsonb;
  v_totals record;
  v_currency_id bigint;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id
  for update;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'not a dropship order';
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);
  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select s.sell_currency_id into v_currency_id
  from public.shops s where s.id = v_order.shop_id;

  v_collected_cod := coalesce((p_payload->>'collected_cod_amount')::numeric, 0);
  v_reseller_purchase_cost := coalesce((p_payload->>'reseller_purchase_cost')::numeric, 0);
  v_discount_company_pay := coalesce((p_payload->>'discount_company_pay')::numeric, 0);
  v_return_reason_note := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');
  v_charge_lines := coalesce(p_payload->'charge_lines', '[]'::jsonb);

  if jsonb_typeof(v_charge_lines) <> 'array' then
    raise exception 'charge_lines must be a JSON array';
  end if;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  if found and v_settlement.status = 'confirmed' then
    raise exception 'settlement is confirmed and cannot be edited';
  end if;

  select * into v_totals
  from public.compute_dropship_settlement_totals(
    v_collected_cod,
    v_reseller_purchase_cost,
    v_discount_company_pay,
    v_charge_lines
  );

  if not found then
    insert into public.dropship_order_settlements (
      tenant_id,
      shop_order_id,
      billing_profile_id,
      currency_id,
      calculated_cod_amount,
      collected_cod_amount,
      reseller_purchase_cost,
      discount_company_pay,
      return_reason_note,
      total_cost,
      reseller_profit,
      company_profit,
      status
    ) values (
      p_tenant_id,
      p_order_id,
      v_order.billing_profile_id,
      v_currency_id,
      v_calculated_cod,
      v_collected_cod,
      v_reseller_purchase_cost,
      v_discount_company_pay,
      v_return_reason_note,
      v_totals.total_cost,
      v_totals.reseller_profit,
      v_totals.company_profit,
      'draft'
    )
    returning * into v_settlement;
  else
    update public.dropship_order_settlements
    set
      billing_profile_id = coalesce(v_order.billing_profile_id, billing_profile_id),
      currency_id = coalesce(v_currency_id, currency_id),
      calculated_cod_amount = v_calculated_cod,
      collected_cod_amount = v_collected_cod,
      reseller_purchase_cost = v_reseller_purchase_cost,
      discount_company_pay = v_discount_company_pay,
      return_reason_note = v_return_reason_note,
      total_cost = v_totals.total_cost,
      reseller_profit = v_totals.reseller_profit,
      company_profit = v_totals.company_profit,
      updated_at = now()
    where id = v_settlement.id
    returning * into v_settlement;
  end if;

  delete from public.dropship_settlement_charge_lines
  where settlement_id = v_settlement.id;

  for v_line in select value from jsonb_array_elements(v_charge_lines)
  loop
    insert into public.dropship_settlement_charge_lines (
      settlement_id,
      charge_type,
      amount,
      payer
    ) values (
      v_settlement.id,
      (v_line->>'charge_type')::public.dropship_settlement_charge_type,
      coalesce((v_line->>'amount')::numeric, 0),
      (v_line->>'payer')::public.dropship_settlement_charge_payer
    );
  end loop;

  return jsonb_build_object(
    'success', true,
    'settlement_id', v_settlement.id,
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', v_settlement.status,
      'calculated_cod_amount', v_settlement.calculated_cod_amount,
      'collected_cod_amount', v_settlement.collected_cod_amount,
      'reseller_purchase_cost', v_settlement.reseller_purchase_cost,
      'discount_company_pay', v_settlement.discount_company_pay,
      'return_reason_note', v_settlement.return_reason_note,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at
    )
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- get_dropship_management_order
-- ---------------------------------------------------------------------------
create or replace function public.get_dropship_management_order(
  p_tenant_id bigint,
  p_order_id bigint
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_detail jsonb;
  v_order public.shop_orders;
  v_settlement public.dropship_order_settlements;
  v_charge_lines jsonb;
  v_reseller_purchase_cost numeric(15,2);
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_courier_name text;
  v_has_settlement boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);

  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if v_order.status not in ('shipped', 'delivered', 'payment_received') then
    raise exception 'order status % is not eligible for dropship management desk', v_order.status;
  end if;

  select coalesce(cs.name, v_order.courier_name)
  into v_courier_name
  from public.courier_services cs
  where cs.id::text = v_order.courier_service_id::text;

  select coalesce(
    sum(coalesce(soi.cost_price_amount, soi.unit_list_price_amount, 0) * soi.quantity),
    0
  )
  into v_reseller_purchase_cost
  from public.shop_order_items soi
  where soi.order_id = p_order_id;

  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  if v_has_settlement then
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'charge_type', cl.charge_type,
          'amount', cl.amount,
          'payer', cl.payer
        )
        order by cl.charge_type
      ),
      '[]'::jsonb
    )
    into v_charge_lines
    from public.dropship_settlement_charge_lines cl
    where cl.settlement_id = v_settlement.id;

    v_collected_cod := v_settlement.collected_cod_amount;
  else
    v_charge_lines := public.build_default_dropship_settlement_charge_lines(v_order);
    v_collected_cod := coalesce(v_order.cod_collect_amount, v_calculated_cod);
  end if;

  return jsonb_build_object(
    'success', true,
    'order', (v_detail->'order') || jsonb_build_object(
      'courier_name', v_courier_name,
      'payout_settlement_status', v_order.payout_settlement_status
    ),
    'fulfillment', v_detail->'fulfillment',
    'computed', v_detail->'computed',
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', coalesce(v_settlement.status::text, 'draft'),
      'calculated_cod_amount', coalesce(v_settlement.calculated_cod_amount, v_calculated_cod),
      'collected_cod_amount', coalesce(v_settlement.collected_cod_amount, v_collected_cod),
      'reseller_purchase_cost', coalesce(v_settlement.reseller_purchase_cost, v_reseller_purchase_cost),
      'discount_company_pay', coalesce(v_settlement.discount_company_pay, 0),
      'return_reason_note', coalesce(v_settlement.return_reason_note, ''),
      'charge_lines', v_charge_lines,
      'total_cost', v_settlement.total_cost,
      'reseller_profit', v_settlement.reseller_profit,
      'company_profit', v_settlement.company_profit,
      'courier_cod_booked_at', v_settlement.courier_cod_booked_at,
      'remittance_at', v_settlement.remittance_at,
      'merchant_payout_at', v_settlement.merchant_payout_at
    ),
    'step_state', jsonb_build_object(
      'can_mark_delivered',
        v_order.status = 'shipped'
        and (not v_has_settlement or v_settlement.courier_cod_booked_at is null),
      'can_record_bank_transfer',
        v_order.status = 'delivered'
        and (not v_has_settlement or v_settlement.remittance_at is null),
      'can_transfer_to_reseller',
        v_order.status in ('delivered', 'payment_received')
        and (not v_has_settlement or v_settlement.status is distinct from 'confirmed')
        and (not v_has_settlement or v_settlement.merchant_payout_at is null)
    )
  );
end;
$$;

grant execute on function public.save_dropship_settlement_draft(bigint, bigint, jsonb) to authenticated;
grant execute on function public.get_dropship_management_order(bigint, bigint) to authenticated;

commit;
