-- Wire dropship management wallet RPCs to parent-books record_ledger_transaction API
-- (p_parent_tenant_id + p_operating_tenant_id; UWL keyed by parent_tenant_id).

begin;

-- ---------------------------------------------------------------------------
-- 1. confirm_dropship_delivered_costing — courier COD credit at mark delivered
-- ---------------------------------------------------------------------------
create or replace function public.confirm_dropship_delivered_costing(
  p_order_id bigint,
  p_cod_amount numeric default null,
  p_delivery_charge numeric default null,
  p_courier_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_courier_id bigint := 0;
  v_cod numeric(15,4) := 0.0000;
  v_delivery_charge numeric(15,4) := 0.0000;
  v_existing_ledger public.universal_wallet_ledger;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  end if;

  if not (
    public.is_superadmin()
    or exists (
      select 1 from public.memberships m
      where m.tenant_id = v_order.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
  ) then
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', v_order.tenant_id));
  end if;

  if v_order.status <> 'delivered' and v_order.status <> 'payment_received' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" or "payment_received" to confirm costing)', v_order.order_no, v_order.status)
    );
  end if;

  v_cod := coalesce(p_cod_amount, v_order.cod_collect_amount, 0.0000);
  v_delivery_charge := coalesce(p_delivery_charge, v_order.delivery_charge_amount, 0.0000);

  update public.shop_orders
  set
    cod_collect_amount = v_cod,
    delivery_charge_amount = v_delivery_charge,
    driver_notes = coalesce(nullif(trim(p_courier_notes), ''), driver_notes),
    updated_at = now()
  where id = p_order_id;

  if v_order.courier_service_id is not null then
    select coalesce(cs.wallet_entity_id, 0)
    into v_courier_id
    from public.courier_services cs
    where cs.id = v_order.courier_service_id;
  end if;

  v_courier_id := coalesce(v_courier_id, 0);

  select * into v_existing_ledger
  from public.universal_wallet_ledger
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and entity_type = 'courier'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'delivered_costing'
  limit 1;

  if v_existing_ledger.id is null and v_cod > 0 then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'credit',
      p_amount => v_cod,
      p_currency_code => 'BDT',
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'delivered_costing',
        'order_no', v_order.order_no,
        'delivery_charge', v_delivery_charge,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  return jsonb_build_object(
    'success', true,
    'message', 'Delivered costing confirmed and courier wallet credited',
    'order_id', p_order_id,
    'cod_amount', v_cod,
    'delivery_charge', v_delivery_charge
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. process_dropship_courier_remittance_uwl — bank transfer wallet legs
-- ---------------------------------------------------------------------------
create or replace function public.process_dropship_courier_remittance_uwl(
  p_order_id bigint,
  p_net_amount numeric,
  p_courier_charge numeric default 0.00,
  p_remittance_ref text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_parent_tenant_id bigint;
  v_courier_id bigint := 0;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net numeric(12,2) := 0.00;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);
  v_currency := 'BDT';
  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := greatest(coalesce(p_courier_charge, 0.00), 0.00);
  v_net := greatest(coalesce(p_net_amount, 0.00), 0.00);

  if v_order.courier_service_id is not null then
    select coalesce(wallet_entity_id, 0) into v_courier_id
    from public.courier_services
    where id = v_order.courier_service_id;

    if v_courier_id is null then
      v_courier_id := 0;
    end if;
  else
    v_courier_id := 0;
  end if;

  if v_net > 0 and not exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_remittance',
        'transaction_type', 'courier_remittance',
        'label', 'COD Remittance to Tenant',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  if v_charge > 0 and not exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_fee_retained'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'cod_pending',
        'purpose', 'courier_fee_retained',
        'transaction_type', 'courier_fee_retained',
        'label', 'Courier COD / Delivery Fee Retained',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'gross_cod', v_cod,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  if not exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = v_parent_tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => v_parent_tenant_id,
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_parent_tenant_id,
      p_type => 'credit',
      p_amount => v_net,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payment_received',
        'purpose', 'tenant_remittance_received',
        'transaction_type', 'courier_remittance_received',
        'label', 'Courier Remittance Received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge,
        'net_remitted', v_net,
        'remittance_ref', p_remittance_ref
      )
    );
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. dispense_middleman_payout_from_tenant — reseller payout wallet legs
-- ---------------------------------------------------------------------------
create or replace function public.dispense_middleman_payout_from_tenant(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_amount numeric,
  p_payout_method text default 'bank_transfer',
  p_reference_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.billing_profiles;
  v_payout_id text;
  v_parent_tenant_id bigint;
begin
  if p_tenant_id is null then
    return jsonb_build_object('success', false, 'error', 'Tenant ID is required');
  end if;

  if p_billing_profile_id is null then
    return jsonb_build_object('success', false, 'error', 'Billing Profile ID is required');
  end if;

  if coalesce(p_amount, 0) <= 0 then
    return jsonb_build_object('success', false, 'error', 'Payout amount must be greater than 0');
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
    return jsonb_build_object('success', false, 'error', format('Permission denied for tenant %s', p_tenant_id));
  end if;

  select * into v_profile
  from public.billing_profiles
  where id = p_billing_profile_id and tenant_id = p_tenant_id;

  if v_profile.id is null then
    return jsonb_build_object('success', false, 'error', format('Billing profile #%s not found for tenant %s', p_billing_profile_id, p_tenant_id));
  end if;

  v_parent_tenant_id := public.resolve_parent_tenant_id(p_tenant_id);
  v_payout_id := 'PO-' || gen_random_uuid()::text;

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => v_parent_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_tenant_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'billing_profile_id', p_billing_profile_id,
      'billing_profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.record_ledger_transaction(
    p_parent_tenant_id => v_parent_tenant_id,
    p_operating_tenant_id => p_tenant_id,
    p_entity_type => 'customer',
    p_entity_id => p_billing_profile_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'section', 'payout_earned',
      'purpose', 'middleman_payout_debit',
      'transaction_type', 'profit_paid_out',
      'label', 'Profit Paid Out',
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  perform public.apply_dropship_payout_settlement_fifo(
    p_tenant_id,
    p_billing_profile_id,
    p_amount
  );

  return jsonb_build_object(
    'success', true,
    'payout_id', v_payout_id,
    'billing_profile_id', p_billing_profile_id,
    'amount', p_amount
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. finalize_dropship_return — wallet unwind legs (grade/availability unchanged)
-- ---------------------------------------------------------------------------
create or replace function public.finalize_dropship_return(
  p_order_id bigint,
  p_items jsonb,
  p_actual_return_charge numeric default 0.00,
  p_deduct_from_middle_man boolean default true,
  p_override_reason text default null,
  p_return_ref text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_invoice record;
  v_parent_tenant_id bigint;
  v_ref text;
  v_item_elem jsonb;
  v_order_item_id bigint;
  v_returned_qty numeric;
  v_condition text;
  v_order_item record;
  v_invoice_item record;
  v_stock record;
  v_target_stock_type_id bigint;
  v_target_stock_id bigint;
  v_net_delivered numeric;
  v_currency text;
  v_billing_profile_id bigint;
  v_is_remitted boolean := false;
  v_existing_ref_order_id bigint;
  v_profit numeric(12,2) := 0;
  v_revenue numeric(12,2) := 0;
  v_billed numeric(12,2) := 0;
  v_remit_net numeric(12,2) := 0;
  v_courier_charge numeric(12,2) := 0;
  v_has_billed boolean := false;
  v_has_profit boolean := false;
  v_grade_tag_id bigint;
  v_to_availability public.stock_availability;
  v_to_availability_raw text;
  v_use_explicit_targets boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order #% is not a dropship order', p_order_id;
  end if;

  v_currency := 'BDT';
  v_parent_tenant_id := public.resolve_parent_tenant_id(v_order.tenant_id);

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

  v_ref := nullif(trim(coalesce(p_return_ref, '')), '');
  if v_ref is not null then
    select id into v_existing_ref_order_id
    from public.shop_orders
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and return_ref = v_ref;

    if v_existing_ref_order_id is not null then
      if v_existing_ref_order_id = p_order_id and v_order.return_sub_state = 'return_finalized' then
        return jsonb_build_object(
          'success', true,
          'idempotent', true,
          'message', 'Return already finalized with reference ' || v_ref,
          'order_id', p_order_id
        );
      else
        raise exception 'Duplicate return reference % already used for another return', v_ref;
      end if;
    end if;
  end if;

  if v_order.return_sub_state = 'return_finalized' then
    return jsonb_build_object(
      'success', true,
      'idempotent', true,
      'message', 'Order return is already finalized',
      'order_id', p_order_id
    );
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  end if;

  v_billing_profile_id := v_order.billing_profile_id;
  if v_billing_profile_id is null and v_order.customer_group_id is not null then
    select id into v_billing_profile_id
    from public.billing_profiles
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and customer_group_id = v_order.customer_group_id
    order by is_default desc, created_at asc
    limit 1;
  end if;

  if p_items is not null and jsonb_array_length(p_items) > 0 then
    for v_item_elem in select * from jsonb_array_elements(p_items) loop
      v_order_item_id := (v_item_elem->>'order_item_id')::bigint;
      v_returned_qty := coalesce((v_item_elem->>'returned_qty')::numeric, 0);
      v_condition := coalesce(lower(trim(v_item_elem->>'condition')), 'perfect');
      v_grade_tag_id := nullif((v_item_elem->>'grade_tag_id')::bigint, 0);
      v_to_availability_raw := nullif(lower(trim(v_item_elem->>'to_availability')), '');
      v_use_explicit_targets := v_grade_tag_id is not null or v_to_availability_raw is not null;

      if v_returned_qty <= 0 then
        continue;
      end if;

      select * into v_order_item
      from public.shop_order_items
      where id = v_order_item_id and order_id = p_order_id for update;

      if v_order_item.id is null then
        raise exception 'Order item #% not found on order #%', v_order_item_id, p_order_id;
      end if;

      v_net_delivered := coalesce(v_order_item.confirmed_quantity, v_order_item.quantity) - coalesce(v_order_item.returned_quantity, 0);
      if v_returned_qty > v_net_delivered then
        raise exception 'Returned quantity % exceeds net delivered quantity % for item #%', v_returned_qty, v_net_delivered, v_order_item_id;
      end if;

      if v_use_explicit_targets then
        v_grade_tag_id := coalesce(
          v_grade_tag_id,
          v_order_item.grade_tag_id,
          public.default_stock_grade_tag_id()
        );
        v_to_availability := coalesce(
          v_to_availability_raw::public.stock_availability,
          'held'::public.stock_availability
        );
      else
        v_to_availability := case
          when v_condition = 'damaged' then 'unsellable'::public.stock_availability
          else 'held'::public.stock_availability
        end;
        v_grade_tag_id := public.stock_grade_tag_id_for_slug(
          case v_condition
            when 'open_box' then 'open_box'
            when 'damaged' then 'badly_damaged'
            else 'standard'
          end
        );
      end if;

      select * into v_stock from public.global_stocks where id = v_order_item.global_stock_id;

      if v_stock.id is not null then
        perform public.create_and_post_stock_movement(
          v_parent_tenant_id,
          v_stock.id,
          ceil(v_returned_qty)::integer,
          public.default_returns_stock_location_id(v_parent_tenant_id),
          v_to_availability,
          v_grade_tag_id,
          'return_inbound'::public.stock_movement_type,
          coalesce(p_override_reason, 'Dropship return'),
          'shop_order',
          p_order_id::text
        );
      end if;

      update public.shop_order_items
      set returned_quantity = coalesce(returned_quantity, 0) + v_returned_qty, updated_at = now()
      where id = v_order_item_id;

      if v_invoice.id is not null then
        select * into v_invoice_item
        from public.global_invoice_items
        where invoice_id = v_invoice.id
          and (global_stock_id = v_order_item.global_stock_id or product_id = v_order_item.product_id)
        limit 1;

        if v_invoice_item.id is not null then
          -- global_return_items schema: quantity + return_charge_amount only (no return_amount / face / accounting)
          insert into public.global_return_items (
            tenant_id, parent_tenant_id, invoice_id, invoice_item_id, global_stock_id,
            quantity, return_charge_amount, note
          )
          values (
            v_invoice.tenant_id, v_invoice.parent_tenant_id, v_invoice.id, v_invoice_item.id, v_order_item.global_stock_id,
            v_returned_qty, 0.00, coalesce(p_override_reason, 'Dropship return finalization')
          );

          update public.global_invoice_items
          set return_quantity = coalesce(return_quantity, 0) + v_returned_qty, updated_at = now()
          where id = v_invoice_item.id;
        end if;
      end if;
    end loop;
  end if;

  if v_invoice.id is not null then
    perform public.recompute_global_invoice_totals(v_invoice.id);
  end if;

  select exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) into v_is_remitted;

  -- Resolve amounts from UWL (canonical after billing-profile unification)
  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_billed
  from public.universal_wallet_ledger
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'customer'
    and entity_id = v_billing_profile_id
    and metadata->>'transaction_type' in ('invoice_billed', 'return_reversal', 'invoice_collection');

  -- Net billed outstanding before clawback: invert so positive = amount still billed
  v_billed := greatest(-v_billed, 0);
  v_has_billed := v_billed > 0 or exists (
    select 1 from public.universal_wallet_ledger
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
  );

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_profit
  from public.universal_wallet_ledger
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type in ('customer', 'middleman')
    and entity_id = v_billing_profile_id
    and metadata->>'section' = 'payout_earned';

  v_profit := greatest(v_profit, 0);
  v_has_profit := v_profit > 0;

  select coalesce(sum(case when type = 'credit' then base_amount else -base_amount end), 0)
  into v_revenue
  from public.universal_wallet_ledger
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and entity_type = 'tenant'
    and metadata->>'transaction_type' = 'revenue';

  if v_revenue <= 0 then
    v_revenue := coalesce(v_invoice.total_amount, 0.00);
  end if;

  select coalesce((metadata->>'net_remitted')::numeric, amount, 0)
  into v_remit_net
  from public.universal_wallet_ledger
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_remittance_received'
  limit 1;

  select coalesce((metadata->>'courier_charge')::numeric, amount, 0)
  into v_courier_charge
  from public.universal_wallet_ledger
  where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'tenant_courier_charge'
  limit 1;

  -- Leg 1: Reverse remaining invoice billed / collection net on customer
  if v_billing_profile_id is not null and v_has_billed and v_billed > 0
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'credit',
      p_amount => v_billed,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'receivable',
        'transaction_type', 'return_reversal',
        'label', 'Return Billed Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  elsif v_billing_profile_id is not null and v_has_billed and v_billed = 0
     and exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_reversal'
     )
  then
    -- Invoice fully collected already — reverse original billed amount then reverse collection net via billed lookup
    select coalesce(base_amount, 0) into v_billed
    from public.universal_wallet_ledger
    where source_type = 'shop_order' and source_id = p_order_id::text
      and metadata->>'transaction_type' = 'invoice_billed'
    limit 1;

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'credit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_reversal',
          'label', 'Return Billed Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );

      if exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order' and source_id = p_order_id::text
          and metadata->>'transaction_type' = 'invoice_collection'
      ) then
        perform public.record_ledger_transaction(
          p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
          p_entity_id => v_billing_profile_id,
          p_type => 'debit',
          p_amount => v_billed,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'receivable',
            'transaction_type', 'return_collection_reversal',
            'label', 'Return Collection Reversal',
            'order_no', v_order.order_no,
            'return_ref', v_ref
          )
        );
      end if;
    end if;

  -- Historical remittance path: invoice_collection posted without invoice_billed.
  -- Unwind collection only (no synthetic return_reversal credit).
  elsif v_billing_profile_id is not null
     and exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_collection'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'invoice_billed'
     )
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_collection_reversal'
     )
  then
    select coalesce(sum(base_amount), 0) into v_billed
    from public.universal_wallet_ledger
    where parent_tenant_id = public.resolve_parent_tenant_id(v_order.tenant_id)
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and entity_type = 'customer'
      and entity_id = v_billing_profile_id
      and type = 'credit'
      and metadata->>'transaction_type' = 'invoice_collection';

    if v_billed > 0 then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'customer',
        p_entity_id => v_billing_profile_id,
        p_type => 'debit',
        p_amount => v_billed,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'receivable',
          'transaction_type', 'return_collection_reversal',
          'label', 'Return Collection Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Leg 2: Claw back profit on customer (unified billing-profile wallet)
  if v_billing_profile_id is not null and v_has_profit
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_profit_clawback'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => v_profit,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_profit_clawback',
        'label', 'Return Profit Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 3: Reverse tenant revenue
  if v_revenue > 0
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order' and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_revenue_reversal'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_type => 'debit',
      p_amount => v_revenue,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'revenue',
        'transaction_type', 'return_revenue_reversal',
        'label', 'Return Revenue Reversal',
        'order_no', v_order.order_no,
        'return_ref', v_ref
      )
    );
  end if;

  -- Leg 4: Reverse remittance cash + courier fee if remitted
  if v_is_remitted then
    if coalesce(v_remit_net, 0) > 0
       and not exists (
         select 1 from public.universal_wallet_ledger
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'remittance_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
        p_type => 'debit',
        p_amount => v_remit_net,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'payment_received',
          'purpose', 'remittance_return_reversal',
          'transaction_type', 'remittance_return_reversal',
          'label', 'Remittance Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;

    if coalesce(v_courier_charge, 0) > 0
       and not exists (
         select 1 from public.universal_wallet_ledger
         where source_type = 'shop_order' and source_id = p_order_id::text
           and metadata->>'purpose' = 'courier_charge_return_reversal'
       )
    then
      perform public.record_ledger_transaction(
        p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
        p_entity_type => 'tenant',
        p_entity_id => public.resolve_parent_tenant_id(v_order.tenant_id),
        p_type => 'credit',
        p_amount => v_courier_charge,
        p_currency_code => v_currency,
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'section', 'delivery_fee',
          'purpose', 'courier_charge_return_reversal',
          'transaction_type', 'courier_charge_return_reversal',
          'label', 'Courier Fee Return Reversal',
          'order_no', v_order.order_no,
          'return_ref', v_ref
        )
      );
    end if;
  end if;

  -- Return fee: UWL only (legacy middle_man_payout_ledger was dropped)
  if p_deduct_from_middle_man
     and p_actual_return_charge > 0
     and v_billing_profile_id is not null
     and not exists (
       select 1 from public.universal_wallet_ledger
       where source_type = 'shop_order'
         and source_id = p_order_id::text
         and metadata->>'transaction_type' = 'return_fee'
     )
  then
    perform public.record_ledger_transaction(
      p_parent_tenant_id => public.resolve_parent_tenant_id(v_order.tenant_id),
      p_operating_tenant_id => v_order.tenant_id,
      p_entity_type => 'customer',
      p_entity_id => v_billing_profile_id,
      p_type => 'debit',
      p_amount => p_actual_return_charge,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'section', 'payout_earned',
        'transaction_type', 'return_fee',
        'label', 'Return Fee',
        'order_no', v_order.order_no,
        'return_ref', v_ref,
        'invoice_id', v_order.global_invoice_id
      )
    );
  end if;

  update public.shop_orders
  set
    status = 'returned'::public.shop_order_status,
    return_sub_state = 'return_finalized',
    returned_at = coalesce(returned_at, now()),
    return_charge_amount = p_actual_return_charge,
    deduct_return_charge_from_middle_man = p_deduct_from_middle_man,
    return_override_reason = coalesce(p_override_reason, return_override_reason),
    return_ref = v_ref,
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'status', 'returned',
    'return_sub_state', 'return_finalized',
    'return_ref', v_ref
  );
end;
$$;

grant execute on function public.confirm_dropship_delivered_costing(bigint, numeric, numeric, text) to authenticated;
grant execute on function public.confirm_dropship_delivered_costing(bigint, numeric, numeric, text) to service_role;
grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to authenticated;
grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to service_role;
grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to authenticated;
grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to service_role;
grant execute on function public.finalize_dropship_return(bigint, jsonb, numeric, boolean, text, text) to authenticated;
grant execute on function public.finalize_dropship_return(bigint, jsonb, numeric, boolean, text, text) to service_role;

commit;
