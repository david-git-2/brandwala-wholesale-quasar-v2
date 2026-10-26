-- Dropship courier remittance queue: use is_prepaid_snapshot, not merchant invoice collection_source.

create or replace function public.sync_shop_order_collection_source_from_invoice()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_src public.collection_source_type;
begin
  if new.global_invoice_id is null then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and old.global_invoice_id is not distinct from new.global_invoice_id
     and new.collection_source is not null then
    return new;
  end if;

  if new.shop_type_snapshot = 'dropship' then
    new.collection_source := case
      when coalesce(new.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else 'recipient'::public.collection_source_type
    end;
    if new.payout_settlement_status is null then
      new.payout_settlement_status := 'unpaid';
    end if;
    return new;
  end if;

  select collection_source into v_src
  from public.global_invoices
  where id = new.global_invoice_id;

  if v_src is not null then
    new.collection_source := v_src;
  end if;

  return new;
end;
$$;

update public.shop_orders o
set
  collection_source = case
    when coalesce(o.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
    else 'recipient'::public.collection_source_type
  end,
  updated_at = now()
where o.shop_type_snapshot = 'dropship'
  and o.global_invoice_id is not null
  and (
    coalesce(o.is_prepaid_snapshot, false)
    or coalesce(o.collection_source, 'recipient'::public.collection_source_type) = 'billing_profile'::public.collection_source_type
  );

CREATE OR REPLACE FUNCTION "public"."get_dropship_finance_hub_data"("p_tenant_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_summary jsonb;
  v_orders jsonb;
  v_merchants jsonb;
  v_parent_tenant_id bigint;
  v_is_parent_scope boolean;
begin
  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_is_parent_scope := (p_tenant_id = v_parent_tenant_id);

  v_summary := public.get_wallet_dashboard_summary(p_tenant_id);

  with finance_orders as (
    select
      o.id,
      o.order_no,
      o.recipient_name,
      o.status,
      o.cod_collect_amount,
      o.delivery_charge_amount,
      o.cod_charge_amount,
      o.driver_notes,
      o.courier_name,
      o.courier_remittance_ref,
      o.courier_bank_trx_id,
      o.billing_profile_id,
      o.created_at,
      o.collection_source,
      o.payout_settlement_status,
      o.is_prepaid_snapshot,
      o.global_invoice_id,
      s.name as shop_name,
      bp.name as billing_profile_name,
      inv.collection_source as invoice_collection_source,
      inv.total_amount as invoice_total_amount,
      inv.paid_amount as invoice_paid_amount
    from public.shop_orders o
    left join public.shops s on s.id = o.shop_id
    left join public.billing_profiles bp on bp.id = o.billing_profile_id
    left join public.sales_invoices inv on inv.id = o.global_invoice_id
    where (
        (v_is_parent_scope and (o.parent_tenant_id = p_tenant_id or o.tenant_id = p_tenant_id))
        or (not v_is_parent_scope and o.tenant_id = p_tenant_id)
      )
      and o.shop_type_snapshot = 'dropship'
      and o.status in ('delivered', 'payment_received')
  ),
  ledger_flags as (
    select
      l.source_id,
      max(case when coalesce(l.metadata->>'purpose', '') in ('delivered_costing', 'courier_cod_receivable') then 1 else 0 end) as has_delivered_costing,
      max(case when coalesce(l.metadata->>'purpose', '') = 'courier_remittance' then 1 else 0 end) as has_remittance
    from public.universal_wallet_ledger l
    where l.parent_tenant_id = v_parent_tenant_id
      and l.source_type = 'shop_order'
      and l.source_id in (select fo.id::text from finance_orders fo)
    group by l.source_id
  ),
  order_rows as (
    select
      fo.id,
      fo.order_no as "orderNo",
      fo.recipient_name as "customerName",
      fo.shop_name as "shopName",
      fo.courier_name as "courierName",
      fo.status::text as status,
      case
        when fo.global_invoice_id is not null then coalesce(fo.invoice_total_amount, 0)
        else coalesce(fo.cod_collect_amount, 0)
      end as "totalAmount",
      coalesce(fo.cod_collect_amount, 0) as "codCollectAmount",
      coalesce(fo.delivery_charge_amount, 0) as "deliveryChargeAmount",
      coalesce(fo.cod_charge_amount, 0) as "codChargeAmount",
      fo.driver_notes as "courierNotes",
      fo.courier_remittance_ref as "courierRemittanceRef",
      fo.courier_bank_trx_id as "courierBankTrxId",
      fo.billing_profile_id as "billingProfileId",
      fo.billing_profile_name as "billingProfileName",
      fo.created_at as "createdAt",
      case
        when fo.status::text = 'payment_received'
          or fo.courier_remittance_ref is not null
          or coalesce(lf.has_remittance, 0) > 0
          then 'completed'
        when fo.status::text = 'delivered'
          and (
            coalesce(fo.is_prepaid_snapshot, false)
            or coalesce(fo.cod_collect_amount, 0) <= 0
          )
          then 'completed'
        when fo.status::text = 'delivered'
          and coalesce(lf.has_delivered_costing, 0) = 0
          then 'delivered_costing'
        when fo.status::text = 'delivered'
          then 'courier_remittance'
        else 'completed'
      end as "nextStep",
      case
        when coalesce(fo.is_prepaid_snapshot, false) then 'billing_profile'
        else coalesce(fo.collection_source, 'recipient')
      end as "collectionSource",
      coalesce(fo.is_prepaid_snapshot, false) as "isPrepaidSnapshot",
      coalesce(fo.payout_settlement_status, 'unpaid') as "payoutSettlementStatus",
      case
        when fo.global_invoice_id is not null then greatest(coalesce(fo.invoice_total_amount, 0) - coalesce(fo.invoice_paid_amount, 0), 0)
        else null
      end as "invoiceOutstanding"
    from finance_orders fo
    left join ledger_flags lf on lf.source_id = fo.id::text
    order by fo.created_at desc
  )
  select coalesce(jsonb_agg(to_jsonb(order_rows)), '[]'::jsonb)
  into v_orders
  from order_rows;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', bp.id,
        'name', bp.name,
        'payableBalance', coalesce(wa.available_balance, 0)
      )
      order by bp.name
    ),
    '[]'::jsonb
  )
  into v_merchants
  from public.billing_profiles bp
  left join public.wallet_accounts wa
    on wa.tenant_id = p_tenant_id
   and wa.entity_type = 'customer'
   and wa.entity_id = bp.id
  where bp.tenant_id = p_tenant_id;

  return jsonb_build_object(
    'kpis', jsonb_build_object(
      'courierOwedTotal', coalesce((v_summary->>'courier_cod_holding_total')::numeric, 0),
      'tenantCashTotal', coalesce((v_summary->>'tenant_cash_total')::numeric, 0),
      'middlemanPayableTotal', coalesce((v_summary->>'merchant_available_total')::numeric, 0)
    ),
    'orders', coalesce(v_orders, '[]'::jsonb),
    'merchants', coalesce(v_merchants, '[]'::jsonb)
  );
end;
$$;;

CREATE OR REPLACE FUNCTION "public"."get_shop_order_for_staff"(
  p_tenant_id bigint,
  p_order_id bigint
)
RETURNS "jsonb"
LANGUAGE "plpgsql"
SECURITY DEFINER
SET "search_path" TO 'public'
STABLE
AS $$
declare
  v_order public.shop_orders%rowtype;
  v_shop_name text;
  v_sell_currency_id bigint;
  v_buy_currency_id bigint;
  v_sell_code text;
  v_sell_symbol text;
  v_buy_code text;
  v_buy_symbol text;
  v_customer_group_name text;
  v_item_count bigint;
  v_total_amount numeric;
  v_collection_source public.collection_source_type;
  v_items jsonb;
  v_invoices jsonb;
  v_shipments jsonb;
  v_order_json jsonb;
begin
  if p_tenant_id is null or p_order_id is null then
    raise exception 'tenant required';
  end if;

  if not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  select *
  into v_order
  from public.shop_orders o
  where o.id = p_order_id;

  if not found then
    raise exception 'order not found';
  end if;

  if v_order.tenant_id is distinct from p_tenant_id and v_order.parent_tenant_id is distinct from p_tenant_id then
    raise exception 'tenant mismatch';
  end if;

  select
    s.name,
    s.sell_currency_id,
    s.buy_currency_id,
    sell_gc.code,
    sell_gc.symbol,
    buy_gc.code,
    buy_gc.symbol
  into
    v_shop_name,
    v_sell_currency_id,
    v_buy_currency_id,
    v_sell_code,
    v_sell_symbol,
    v_buy_code,
    v_buy_symbol
  from public.shops s
  left join public.global_currencies sell_gc on sell_gc.id = s.sell_currency_id
  left join public.global_currencies buy_gc on buy_gc.id = s.buy_currency_id
  where s.id = v_order.shop_id;

  select cg.name
  into v_customer_group_name
  from public.customer_groups cg
  where cg.id = v_order.customer_group_id;

  if v_order.shop_type_snapshot = 'dropship' then
    v_collection_source := case
      when coalesce(v_order.is_prepaid_snapshot, false) then 'billing_profile'::public.collection_source_type
      else coalesce(v_order.collection_source, 'recipient'::public.collection_source_type)
    end;
  else
    v_collection_source := v_order.collection_source;
    if v_collection_source is null and v_order.global_invoice_id is not null then
      select inv.collection_source
      into v_collection_source
      from public.sales_invoices inv
      where inv.id = v_order.global_invoice_id;
    end if;
    if v_collection_source is null and v_order.is_prepaid_snapshot then
      v_collection_source := 'billing_profile'::public.collection_source_type;
    end if;
  end if;

  select count(*)::bigint
  into v_item_count
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  select coalesce(
    sum(
      coalesce(
        soi.final_price_amount,
        soi.staff_offer_amount,
        soi.customer_offer_amount,
        soi.unit_sell_price_amount,
        soi.unit_list_price_amount
      ) * soi.quantity
    ),
    0
  )
  into v_total_amount
  from public.shop_order_items soi
  where soi.order_id = v_order.id;

  if v_order.global_invoice_id is not null then
    v_invoices := jsonb_build_array(jsonb_build_object('id', v_order.global_invoice_id));
  else
    v_invoices := '[]'::jsonb;
  end if;

  select coalesce(
    jsonb_agg(jsonb_build_object('id', x.shipment_id) order by x.shipment_id),
    '[]'::jsonb
  )
  into v_shipments
  from (
    select distinct gship.id as shipment_id
    from public.shop_order_items soi
    join public.global_stocks gs on gs.id = soi.global_stock_id
    join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
    join public.global_shipments gship on gship.id = gsi.shipment_id
    where soi.order_id = v_order.id
  ) x;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', soi.id,
        'order_id', soi.order_id,
        'name', soi.name,
        'image_url', soi.image_url,
        'quantity', soi.quantity,
        'created_at', soi.created_at,
        'updated_at', soi.updated_at,
        'product', jsonb_build_object(
          'id', soi.product_id,
          'sku', p.product_code,
          'brand', p.brand,
          'barcode', p.barcode,
          'weight_gm', p.product_weight,
          'package_weight_gm', p.package_weight,
          'minimum_order_quantity', coalesce(p.minimum_order_quantity, 1)
        ),
        'pricing', jsonb_build_object(
          'cost', jsonb_build_object(
            'amount', coalesce(soi.cost_price_amount, soi.unit_list_price_amount, p.reference_cost_amount),
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = coalesce(
                soi.cost_price_currency_id,
                soi.unit_list_price_currency_id
              )
              limit 1
            )
          ),
          'list', jsonb_build_object(
            'amount', soi.unit_list_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_list_price_currency_id
              limit 1
            )
          ),
          'sell', jsonb_build_object(
            'amount', soi.unit_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_sell_price_currency_id
              limit 1
            )
          ),
          'minimum_sell', jsonb_build_object(
            'amount', soi.unit_minimum_sell_price_amount,
            'currency', (
              select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
              from public.global_currencies gc
              where gc.id = soi.unit_minimum_sell_price_currency_id
              limit 1
            )
          )
        ),
        'negotiation', jsonb_build_object(
          'status', soi.negotiation_status,
          'customer_decision', soi.customer_decision_status,
          'staff_offer', case
            when soi.staff_offer_amount is not null then jsonb_build_object(
              'amount', soi.staff_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.staff_offer_currency_id
                limit 1
              ),
              'at', soi.staff_offer_at,
              'is_manual', soi.is_first_offer_manual
            )
            else null
          end,
          'customer_offer', case
            when soi.customer_offer_amount is not null then jsonb_build_object(
              'amount', soi.customer_offer_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.customer_offer_currency_id
                limit 1
              ),
              'at', soi.customer_counter_at
            )
            else null
          end,
          'final_offer', case
            when soi.final_price_amount is not null then jsonb_build_object(
              'amount', soi.final_price_amount,
              'currency', (
                select jsonb_build_object('id', gc.id, 'code', gc.code, 'symbol', gc.symbol)
                from public.global_currencies gc
                where gc.id = soi.final_price_currency_id
                limit 1
              ),
              'at', soi.final_offer_at,
              'is_manual', soi.is_final_offer_manual
            )
            else null
          end,
          'weight_kg', soi.weight_kg,
          'confirmed_quantity', soi.confirmed_quantity
        ),
        'fulfillment', jsonb_build_object(
          'returned', soi.returned_quantity,
          'procurement_pulled', soi.procurement_pulled
        ),
        'stock', case
          when soi.global_stock_id is not null then jsonb_build_object(
            'global_stock_id', soi.global_stock_id,
            'global_stock_allocation_id', soi.global_stock_allocation_id,
            'shipment_item_id', gsi.id,
            'shipment_id', gship.id
          )
          else null
        end
      )
      order by soi.created_at, soi.id
    ),
    '[]'::jsonb
  )
  into v_items
  from public.shop_order_items soi
  left join public.products p on p.id = soi.product_id
  left join public.global_stocks gs on gs.id = soi.global_stock_id
  left join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  left join public.global_shipments gship on gship.id = gsi.shipment_id
  where soi.order_id = v_order.id;

  v_order_json := jsonb_build_object(
    'id', v_order.id,
    'tenant_id', v_order.tenant_id,
    'order_no', v_order.order_no,
    'name', v_order.name,
    'cart_id', v_order.cart_id,
    'created_by_email', v_order.created_by_email,
    'created_at', v_order.created_at,
    'updated_at', v_order.updated_at,
    'placed_at', v_order.placed_at,
    'fulfilled_at', v_order.fulfilled_at,
    'global_invoice_id', v_order.global_invoice_id,
    'collection_source', v_collection_source,
    'shop', jsonb_build_object(
      'id', v_order.shop_id,
      'name', v_shop_name,
      'type', v_order.shop_type_snapshot,
      'order_mode', v_order.order_mode_snapshot,
      'is_negotiable', v_order.is_negotiable_snapshot,
      'sell_currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end,
      'buy_currency', case
        when v_buy_currency_id is not null then jsonb_build_object(
          'id', v_buy_currency_id,
          'code', v_buy_code,
          'symbol', v_buy_symbol
        )
        else null
      end
    ),
    'customer', jsonb_build_object(
      'group_id', v_order.customer_group_id,
      'group_name', v_customer_group_name
    ),
    'status', jsonb_build_object(
      'value', v_order.status,
      'negotiate_round', v_order.negotiate_round
    ),
    'rates', jsonb_build_object(
      'cargo', v_order.cargo_rate,
      'conversion', v_order.conversion_rate,
      'profit', v_order.profit_rate,
      'first_offer', v_order.first_offer_rate,
      'final_offer', v_order.final_offer_rate,
      'profit_basis', v_order.profit_basis,
      'package_weight_kg', v_order.package_weight_kg
    ),
    'recipient', jsonb_build_object(
      'name', v_order.recipient_name,
      'phone', v_order.recipient_phone,
      'phone_secondary', v_order.recipient_phone_secondary,
      'address', v_order.shipping_address,
      'district', v_order.shipping_district,
      'thana', v_order.shipping_thana,
      'profile_id', v_order.recipient_profile_id,
      'billing_profile_id', v_order.billing_profile_id,
      'delivery_instructions', v_order.delivery_instructions,
      'is_prepaid', v_order.is_prepaid_snapshot
    ),
    'charges', jsonb_build_object(
      'cod', v_order.cod_charge_amount,
      'delivery', v_order.delivery_charge_amount,
      'print', v_order.print_charge_amount,
      'packing', v_order.packing_charge_amount,
      'discount', v_order.discount_amount,
      'deduct_from_margin', jsonb_build_object(
        'charges', v_order.deduct_charges_from_margin,
        'cod', v_order.deduct_cod_from_margin,
        'delivery', v_order.deduct_delivery_from_margin,
        'print', v_order.deduct_print_from_margin,
        'packing', v_order.deduct_packing_from_margin
      )
    ),
    'totals', jsonb_build_object(
      'item_count', v_item_count,
      'amount', v_total_amount,
      'currency', case
        when v_sell_currency_id is not null then jsonb_build_object(
          'id', v_sell_currency_id,
          'code', v_sell_code,
          'symbol', v_sell_symbol
        )
        else null
      end
    ),
    'courier', jsonb_build_object(
      'service_id', v_order.courier_service_id,
      'name', v_order.courier_name,
      'awb_number', v_order.courier_awb_number,
      'tracking_url', v_order.tracking_url,
      'order_ref', v_order.courier_order_ref,
      'tracking_number', v_order.courier_tracking_number,
      'consignment_id', v_order.courier_consignment_id,
      'cost_amount', v_order.courier_cost_amount,
      'delivered_at', v_order.delivered_at,
      'returned_at', v_order.returned_at
    ),
    'pickup', jsonb_build_object(
      'sender_name', v_order.sender_name,
      'phone', v_order.pickup_phone,
      'address', v_order.pickup_address,
      'default_sender_name', v_order.default_sender_name,
      'default_phone', v_order.default_pickup_phone,
      'default_address', v_order.default_pickup_address
    ),
    'payout', jsonb_build_object(
      'account_type', v_order.payout_account_type,
      'account_info', v_order.payout_account_info,
      'default_account_type', v_order.default_payout_account_type,
      'default_account_info', v_order.default_payout_account_info,
      'settlement_status', v_order.payout_settlement_status,
      'cod_collect_amount', v_order.cod_collect_amount,
      'courier_remittance_ref', v_order.courier_remittance_ref,
      'courier_bank_trx_id', v_order.courier_bank_trx_id
    ),
    'parcel', jsonb_build_object(
      'weight_band', v_order.package_weight_band,
      'item_category', v_order.item_category,
      'description', v_order.parcel_description,
      'delivery_zone', v_order.delivery_zone,
      'allow_open_box', v_order.allow_open_box,
      'driver_notes', v_order.driver_notes,
      'delivery_instruction_notes', v_order.delivery_instruction_notes
    ),
    'return_info', jsonb_build_object(
      'sub_state', v_order.return_sub_state,
      'override_reason', v_order.return_override_reason,
      'ref', v_order.return_ref,
      'charge_amount', v_order.return_charge_amount,
      'deduct_charge_from_middle_man', v_order.deduct_return_charge_from_middle_man,
      'replacement_of_order_id', v_order.replacement_of_order_id,
      'middle_man_reference', v_order.middle_man_reference
    ),
    'links', jsonb_build_object(
      'invoices', v_invoices,
      'shipments', v_shipments
    )
  );

  return jsonb_build_object(
    'order', v_order_json,
    'items', v_items
  );
end;
$$;;
