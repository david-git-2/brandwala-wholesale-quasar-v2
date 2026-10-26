-- Backlink settlement delivery/print/packing/COD charges to shop_orders

begin;

create or replace function public.apply_dropship_order_charge_lines(
  p_order_id bigint,
  p_charge_lines jsonb
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_line jsonb;
  v_delivery_amount numeric(12,2);
  v_print_amount numeric(12,2);
  v_packing_amount numeric(12,2);
  v_cod_amount numeric(12,2);
  v_deduct_delivery boolean;
  v_deduct_print boolean;
  v_deduct_packing boolean;
  v_deduct_cod boolean;
  v_has_delivery boolean := false;
  v_has_print boolean := false;
  v_has_packing boolean := false;
  v_has_cod boolean := false;
begin
  if p_charge_lines is null or jsonb_typeof(p_charge_lines) <> 'array' then
    return;
  end if;

  for v_line in select value from jsonb_array_elements(p_charge_lines)
  loop
    case coalesce(v_line->>'charge_type', '')
      when 'delivery' then
        v_delivery_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_delivery := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_delivery := true;
      when 'print' then
        v_print_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_print := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_print := true;
      when 'packing' then
        v_packing_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_packing := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_packing := true;
      when 'cod' then
        v_cod_amount := greatest(coalesce((v_line->>'amount')::numeric, 0), 0);
        v_deduct_cod := coalesce(v_line->>'payer', '') = 'merchant';
        v_has_cod := true;
      else
        null;
    end case;
  end loop;

  if not (v_has_delivery or v_has_print or v_has_packing or v_has_cod) then
    return;
  end if;

  update public.shop_orders o
  set
    delivery_charge_amount = case when v_has_delivery then v_delivery_amount else o.delivery_charge_amount end,
    print_charge_amount = case when v_has_print then v_print_amount else o.print_charge_amount end,
    packing_charge_amount = case when v_has_packing then v_packing_amount else o.packing_charge_amount end,
    cod_charge_amount = case when v_has_cod then v_cod_amount else o.cod_charge_amount end,
    deduct_delivery_from_margin = case when v_has_delivery then v_deduct_delivery else o.deduct_delivery_from_margin end,
    deduct_print_from_margin = case when v_has_print then v_deduct_print else o.deduct_print_from_margin end,
    deduct_packing_from_margin = case when v_has_packing then v_deduct_packing else o.deduct_packing_from_margin end,
    deduct_cod_from_margin = case when v_has_cod then v_deduct_cod else o.deduct_cod_from_margin end,
    updated_at = now()
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;
end;
$$;

create or replace function public.build_dropship_management_charge_lines(
  p_order public.shop_orders,
  p_settlement_id bigint default null
)
returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_default_lines jsonb;
  v_return_line jsonb;
begin
  v_default_lines := public.build_default_dropship_settlement_charge_lines(p_order);

  if p_settlement_id is not null then
    select jsonb_build_object(
      'charge_type', cl.charge_type,
      'amount', cl.amount,
      'payer', cl.payer
    )
    into v_return_line
    from public.dropship_settlement_charge_lines cl
    where cl.settlement_id = p_settlement_id
      and cl.charge_type = 'return';
  end if;

  if v_return_line is null then
    select elem.value
    into v_return_line
    from jsonb_array_elements(v_default_lines) elem(value)
    where elem.value->>'charge_type' = 'return';
  end if;

  return coalesce(
    (
      select jsonb_agg(elem.value order by elem.value->>'charge_type')
      from jsonb_array_elements(v_default_lines) elem(value)
      where elem.value->>'charge_type' in ('cod', 'delivery', 'packing', 'print')
    ),
    '[]'::jsonb
  ) || jsonb_build_array(coalesce(v_return_line, jsonb_build_object(
    'charge_type', 'return',
    'amount', coalesce(p_order.return_charge_amount, 0),
    'payer', case when coalesce(p_order.deduct_return_charge_from_middle_man, true) then 'merchant' else 'company' end
  )));
end;
$$;

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
  v_has_settlement boolean := false;
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_reseller_purchase_cost numeric(15,2);
  v_reseller_unit_purchase_cost numeric(15,2);
  v_company_procurement_cost numeric(15,2);
  v_discount_company_pay numeric(15,2);
  v_return_reason_note text;
  v_charge_lines jsonb;
  v_line jsonb;
  v_totals record;
  v_currency_id bigint;
  v_payload_unit numeric(15,2);
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

  v_collected_cod := coalesce((p_payload->>'collected_cod_amount')::numeric, 0);
  v_discount_company_pay := coalesce((p_payload->>'discount_company_pay')::numeric, 0);
  v_return_reason_note := nullif(trim(coalesce(p_payload->>'return_reason_note', '')), '');
  v_charge_lines := coalesce(p_payload->'charge_lines', '[]'::jsonb);

  if jsonb_typeof(v_charge_lines) <> 'array' then
    raise exception 'charge_lines must be a JSON array';
  end if;

  perform public.apply_dropship_order_charge_lines(p_order_id, v_charge_lines);

  v_payload_unit := (p_payload->>'reseller_unit_purchase_cost')::numeric;
  if v_payload_unit is not null then
    perform public.apply_dropship_reseller_unit_purchase(p_order_id, v_payload_unit);
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);
  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select s.sell_currency_id into v_currency_id
  from public.shops s where s.id = v_order.shop_id;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id;

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  if v_has_settlement and v_settlement.status = 'confirmed' then
    raise exception 'settlement is confirmed and cannot be edited';
  end if;

  select * into v_totals
  from public.compute_dropship_settlement_totals(
    v_collected_cod,
    v_reseller_purchase_cost,
    v_company_procurement_cost,
    v_discount_company_pay,
    v_charge_lines
  );

  if not v_has_settlement then
    insert into public.dropship_order_settlements (
      tenant_id,
      shop_order_id,
      billing_profile_id,
      currency_id,
      calculated_cod_amount,
      collected_cod_amount,
      reseller_unit_purchase_cost,
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
      v_reseller_unit_purchase_cost,
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
      reseller_unit_purchase_cost = v_reseller_unit_purchase_cost,
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

  if v_settlement.id is null then
    raise exception 'settlement row missing after upsert';
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
      'calculated_cod_amount', v_calculated_cod,
      'collected_cod_amount', v_settlement.collected_cod_amount,
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
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
  v_reseller_unit_purchase_cost numeric(15,2);
  v_order_item_quantity integer;
  v_company_procurement_cost numeric(15,2);
  v_calculated_cod numeric(15,2);
  v_collected_cod numeric(15,2);
  v_courier_name text;
  v_has_settlement boolean := false;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select * into v_order
  from public.shop_orders
  where id = p_order_id and tenant_id = p_tenant_id;

  if v_order.id is null then
    raise exception 'order not found';
  end if;

  if v_order.status not in ('shipped', 'delivered', 'payment_received') then
    raise exception 'order status % is not eligible for dropship management desk', v_order.status;
  end if;

  v_detail := public.get_dropship_order_detail_v2(p_tenant_id, p_order_id);

  select coalesce(cs.name, v_order.courier_name)
  into v_courier_name
  from public.courier_services cs
  where cs.id::text = v_order.courier_service_id::text;

  select
    rp.reseller_unit_purchase_cost,
    rp.reseller_purchase_cost,
    rp.order_item_quantity
  into v_reseller_unit_purchase_cost, v_reseller_purchase_cost, v_order_item_quantity
  from public.compute_dropship_order_reseller_purchase(p_order_id) rp;

  select coalesce(
    sum(public.resolve_shop_order_item_landed_cost(soi.global_stock_id, soi.cost_price_amount, soi.unit_list_price_amount) * soi.quantity),
    0
  )
  into v_company_procurement_cost
  from public.shop_order_items soi
  inner join public.shop_orders o on o.id = soi.order_id
  where soi.order_id = p_order_id
    and o.tenant_id = p_tenant_id;

  v_calculated_cod := coalesce(
    (v_detail->'computed'->>'recipient_grand_total')::numeric,
    (v_detail->'summary'->>'cod_collect_amount')::numeric,
    coalesce(v_order.cod_collect_amount, 0)
  );

  select * into v_settlement
  from public.dropship_order_settlements
  where shop_order_id = p_order_id;

  v_has_settlement := found;

  v_charge_lines := public.build_dropship_management_charge_lines(
    v_order,
    case when v_has_settlement then v_settlement.id else null end
  );

  if v_has_settlement then
    v_collected_cod := v_settlement.collected_cod_amount;
  else
    v_collected_cod := coalesce(v_order.cod_collect_amount, v_calculated_cod);
  end if;

  return jsonb_build_object(
    'success', true,
    'order', (v_detail->'order') || jsonb_build_object(
      'courier_name', v_courier_name,
      'payout_settlement_status', v_order.payout_settlement_status
    ),
    'fulfillment', v_detail->'fulfillment',
    'computed', (v_detail->'computed') || jsonb_build_object(
      'order_item_quantity', v_order_item_quantity
    ),
    'settlement', jsonb_build_object(
      'id', v_settlement.id,
      'status', coalesce(v_settlement.status::text, 'draft'),
      'calculated_cod_amount', coalesce(v_calculated_cod, v_settlement.calculated_cod_amount),
      'collected_cod_amount', coalesce(v_settlement.collected_cod_amount, v_collected_cod),
      'reseller_unit_purchase_cost', v_reseller_unit_purchase_cost,
      'reseller_purchase_cost', v_reseller_purchase_cost,
      'company_procurement_cost', v_company_procurement_cost,
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

commit;
