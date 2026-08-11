-- Deferred from 20260728202727_dropship_finance_hub_wallet_flow.sql so fresh resets create universal_wallet_ledger first (20261220000000).
-- On production this re-runs as CREATE OR REPLACE / IF NOT EXISTS — safe.

-- Migration: Dropship Finance Hub Atomic Multi-Wallet RPCs (Phase 1)
-- Date: 2026-07-28

begin;

-- 1. RPC: confirm_dropship_delivered_costing
-- Updates order costing fields (COD collect amount, delivery charge) and credits courier wallet atomically.
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
  v_courier_id bigint;
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

  -- Permission check
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

  -- Update order costing fields
  update public.shop_orders
  set
    cod_collect_amount = v_cod,
    delivery_charge_amount = v_delivery_charge,
    courier_notes = coalesce(p_courier_notes, courier_notes),
    updated_at = now()
  where id = p_order_id;

  -- Get numeric courier_id (fallback to 0 if unassigned)
  -- If courier_service_id exists, try to get entity id or use 0
  v_courier_id := coalesce(
    (select coalesce(c.id, 0) from public.courier_services cs left join public.couriers c on c.code = cs.code or c.name = cs.name limit 1),
    0
  );

  -- Idempotency check on universal_wallet_ledger
  select * into v_existing_ledger
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and entity_type = 'courier'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'delivered_costing'
  limit 1;

  if v_existing_ledger.id is null and v_cod > 0 then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'credit',
      p_amount => v_cod,
      p_currency_code => coalesce(v_order.currency_code, 'BDT'),
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'delivered_costing',
        'order_no', v_order.order_no,
        'delivery_charge', v_delivery_charge
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

grant execute on function public.confirm_dropship_delivered_costing(bigint, numeric, numeric, text) to authenticated;
grant execute on function public.confirm_dropship_delivered_costing(bigint, numeric, numeric, text) to service_role;


-- 2. RPC: confirm_courier_remittance_to_tenant
-- Debits courier wallet, credits tenant wallet, credits middleman wallet (profit payable opens here), updates order status to payment_received.
create or replace function public.confirm_courier_remittance_to_tenant(
  p_order_id bigint,
  p_courier_charge numeric default 0.00,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_courier_id bigint;
  v_billing_profile_id bigint;
  v_cod numeric(15,4) := 0.0000;
  v_charge numeric(15,4) := 0.0000;
  v_net_remitted numeric(15,4) := 0.0000;
  v_profit numeric(15,4) := 0.0000;
  v_recipient_subtotal numeric(15,4) := 0.0000;
  v_accounting_subtotal numeric(15,4) := 0.0000;
  v_middleman_cost numeric(15,4) := 0.0000;
  v_existing_remit_ledger public.universal_wallet_ledger;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  end if;

  if v_order.status <> 'delivered' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" to remit)', v_order.order_no, v_order.status)
    );
  end if;

  -- Authorization check
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

  v_cod := coalesce(v_order.cod_collect_amount, 0.0000);
  v_charge := coalesce(p_courier_charge, 0.0000);
  v_net_remitted := v_cod - v_charge;

  if v_net_remitted < 0 then
    v_net_remitted := 0.0000;
  end if;

  -- Ensure global invoice exists or post it
  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id for update;
  end if;

  if v_order.global_invoice_id is not null then
    perform public.post_global_invoice(v_order.global_invoice_id);
  end if;

  -- 1. Courier Debit (reduces courier liability)
  v_courier_id := coalesce(
    (select coalesce(c.id, 0) from public.courier_services cs left join public.couriers c on c.code = cs.code or c.name = cs.name limit 1),
    0
  );

  select * into v_existing_remit_ledger
  from public.universal_wallet_ledger
  where tenant_id = v_order.tenant_id
    and entity_type = 'courier'
    and source_type = 'shop_order'
    and source_id = p_order_id::text
    and metadata->>'purpose' = 'courier_remittance'
  limit 1;

  if v_existing_remit_ledger.id is null and v_cod > 0 then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => v_cod,
      p_currency_code => coalesce(v_order.currency_code, 'BDT'),
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'courier_remittance',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', v_net_remitted
      )
    );

    -- 2. Tenant Credit (tenant received net remitted cash)
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'credit',
      p_amount => v_net_remitted,
      p_currency_code => coalesce(v_order.currency_code, 'BDT'),
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'tenant_remittance_received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge
      )
    );

    -- 3. Calculate Dropship Profit and Credit Middleman Wallet (Payable profit opens NOW on remittance)
    v_billing_profile_id := v_order.billing_profile_id;
    if v_billing_profile_id is null and v_order.customer_group_id is not null then
      select id into v_billing_profile_id
      from public.billing_profiles
      where tenant_id = v_order.tenant_id
        and customer_group_id = v_order.customer_group_id
      order by created_at asc
      limit 1;
    end if;

    select
      coalesce(sum(coalesce(customer_sell_price_amount, 0) * quantity), 0),
      coalesce(sum(coalesce(unit_sell_price_amount, unit_list_price_amount, 0) * quantity), 0)
    into v_recipient_subtotal, v_accounting_subtotal
    from public.shop_order_items
    where order_id = p_order_id;

    v_middleman_cost := v_accounting_subtotal
      + coalesce(v_order.print_charge_amount, 0)
      + coalesce(v_order.packing_charge_amount, 0)
      + case when coalesce(v_order.deduct_delivery_from_margin, false) then coalesce(v_order.delivery_charge_amount, 0) else 0 end
      + case when coalesce(v_order.deduct_cod_from_margin, false) then coalesce(v_order.cod_charge_amount, 0) else 0 end;

    v_profit := v_recipient_subtotal - coalesce(v_order.discount_amount, 0) - v_middleman_cost;

    if v_billing_profile_id is not null and v_profit > 0 then
      perform public.record_ledger_transaction(
        p_tenant_id => v_order.tenant_id,
        p_entity_type => 'middleman',
        p_entity_id => v_billing_profile_id,
        p_type => 'credit',
        p_amount => v_profit,
        p_currency_code => coalesce(v_order.currency_code, 'BDT'),
        p_exchange_rate => 1.000000,
        p_source_type => 'shop_order',
        p_source_id => p_order_id::text,
        p_metadata => jsonb_build_object(
          'purpose', 'middleman_dropship_profit',
          'order_no', v_order.order_no,
          'billing_profile_id', v_billing_profile_id
        )
      );

      -- Dual write to legacy billing_profile_wallet_ledger for backwards compatibility
      if not exists (
        select 1 from public.billing_profile_wallet_ledger
        where shop_order_id = p_order_id and transaction_type = 'dropship_profit'
      ) then
        perform public.record_wallet_ledger_entry(
          p_tenant_id => v_order.tenant_id,
          p_billing_profile_id => v_billing_profile_id,
          p_transaction_type => 'dropship_profit',
          p_amount => v_profit,
          p_reference_id => v_order.order_no,
          p_shop_order_id => v_order.id,
          p_global_invoice_id => v_order.global_invoice_id,
          p_reference_notes => 'Dropship profit from order #' || v_order.order_no
        );
      end if;
    end if;
  end if;

  -- Update order status to payment_received
  update public.shop_orders
  set
    status = 'payment_received',
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'message', format('Order #%s successfully remitted and status updated to payment_received', v_order.order_no),
    'order_id', p_order_id,
    'net_remitted', v_net_remitted,
    'profit', v_profit
  );
end;
$$;

grant execute on function public.confirm_courier_remittance_to_tenant(bigint, numeric, text, text) to authenticated;
grant execute on function public.confirm_courier_remittance_to_tenant(bigint, numeric, text, text) to service_role;


-- 3. RPC: dispense_middleman_payout_from_tenant
-- Debits tenant wallet and debits middleman payable wallet for payout amount.
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

  -- Authorization check
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

  v_payout_id := 'PO-' || gen_random_uuid()::text;

  -- 1. Tenant Debit (tenant cash decreased by payout amount)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'purpose', 'middleman_payout_tenant_debit',
      'billing_profile_id', p_billing_profile_id,
      'billing_profile_name', v_profile.name,
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  -- 2. Middleman Debit (middleman payable profit reduced by payout amount)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'middleman',
    p_entity_id => p_billing_profile_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_payout_id,
    p_metadata => jsonb_build_object(
      'purpose', 'middleman_payout_debit',
      'payout_method', p_payout_method,
      'notes', p_reference_notes
    )
  );

  -- Dual write to legacy billing_profile_wallet_ledger for backwards compatibility
  perform public.record_wallet_ledger_entry(
    p_tenant_id => p_tenant_id,
    p_billing_profile_id => p_billing_profile_id,
    p_transaction_type => 'payout',
    p_amount => p_amount,
    p_reference_id => v_payout_id,
    p_reference_notes => coalesce(p_reference_notes, 'Payout via ' || p_payout_method)
  );

  return jsonb_build_object(
    'success', true,
    'message', format('Dispensed payout of %s to merchant %s', p_amount, v_profile.name),
    'payout_id', v_payout_id,
    'amount', p_amount
  );
end;
$$;

grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to authenticated;
grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to service_role;


-- 4. Update advance_dropship_order_status to NOT book dropship_profit on delivered/ready_for_pickup
create or replace function public.advance_dropship_order_status(
  p_order_id bigint,
  p_target_status public.shop_order_status,
  p_remittance_ref text default null,
  p_bank_trx_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_current_status public.shop_order_status;
  v_is_valid boolean := false;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;

  if v_current_status = p_target_status then
    return jsonb_build_object('success', true, 'message', 'Status unchanged', 'new_status', p_target_status);
  end if;

  -- Status transition rules
  if v_current_status in ('submitted', 'draft', 'placed', 'confirmed') and p_target_status in ('processing', 'cancelled') then
    v_is_valid := true;
  elsif v_current_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received') then
    if p_target_status in ('processing', 'ready_for_pickup', 'shipped', 'delivered', 'returned', 'payment_received', 'cancelled') then
      v_is_valid := true;
    end if;
  end if;

  if not v_is_valid then
    return jsonb_build_object(
      'success', false,
      'error', format('Invalid status transition for dropship order from %s to %s', v_current_status, p_target_status)
    );
  end if;

  update public.shop_orders
  set
    status = p_target_status,
    delivered_at = case when p_target_status = 'delivered' then now() else delivered_at end,
    courier_remittance_ref = coalesce(p_remittance_ref, courier_remittance_ref),
    courier_bank_trx_id = coalesce(p_bank_trx_id, courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  select * into v_order from public.shop_orders where id = p_order_id;

  if p_target_status in ('ready_for_pickup', 'shipped', 'delivered', 'payment_received') then
    if v_order.global_invoice_id is null then
      perform public.create_dual_invoice_from_dropship_order(p_order_id);
    else
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'draft'::public.global_invoice_status then
        perform public.post_global_invoice(v_order.global_invoice_id);
      end if;
    end if;

    -- NOTE: Dropship profit booking on middleman wallet is NO LONGER executed here.
    -- Dropship profit is strictly booked when courier remittance is confirmed via confirm_courier_remittance_to_tenant.

  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      -- Remove wallet profit entry if order is rolled back to processing
      delete from public.billing_profile_wallet_ledger
      where shop_order_id = p_order_id and transaction_type = 'dropship_profit';

      delete from public.universal_wallet_ledger
      where source_type = 'shop_order' and source_id = p_order_id::text and metadata->>'purpose' = 'middleman_dropship_profit';

      -- Disconnect from order
      update public.shop_orders 
      set global_invoice_id = null 
      where id = p_order_id;

      -- Hard delete draft invoice and lines
      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

grant execute on function public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) to authenticated;

commit;
