-- Migration: Dropship Wallet P0B — Remittance unify + merchant entity
-- Goal: Unified remittance ledger routine, middleman profit credit entity, canonical source_id, courier resolution, over-remittance protection.

begin;

-- ============================================================================
-- 1. Shared internal routine: process_dropship_courier_remittance_uwl
-- ============================================================================
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
  v_courier_id bigint := 0;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  v_currency := 'BDT';
  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);

  -- courier_services.id is uuid; UWL entity_id is bigint — use 0 + metadata for service id
  v_courier_id := 0;

  -- Leg 1: Courier Debit (reduces courier liability)
  if not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'courier'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'courier_remittance'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'courier',
      p_entity_id => v_courier_id,
      p_type => 'debit',
      p_amount => greatest(v_cod, p_net_amount + v_charge),
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'courier_remittance',
        'order_no', v_order.order_no,
        'courier_charge', v_charge,
        'net_remitted', p_net_amount,
        'remittance_ref', p_remittance_ref,
        'courier_service_id', v_order.courier_service_id
      )
    );
  end if;

  -- Leg 2: Tenant Credit (tenant received net remitted cash)
  if not exists (
    select 1 from public.universal_wallet_ledger
    where tenant_id = v_order.tenant_id
      and entity_type = 'tenant'
      and source_type = 'shop_order'
      and source_id = p_order_id::text
      and metadata->>'purpose' = 'tenant_remittance_received'
  ) then
    perform public.record_ledger_transaction(
      p_tenant_id => v_order.tenant_id,
      p_entity_type => 'tenant',
      p_entity_id => v_order.tenant_id,
      p_type => 'credit',
      p_amount => p_net_amount,
      p_currency_code => v_currency,
      p_exchange_rate => 1.000000,
      p_source_type => 'shop_order',
      p_source_id => p_order_id::text,
      p_metadata => jsonb_build_object(
        'purpose', 'tenant_remittance_received',
        'order_no', v_order.order_no,
        'gross_cod', v_cod,
        'courier_charge', v_charge,
        'remittance_ref', p_remittance_ref
      )
    );
  end if;
end;
$$;

grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to authenticated;
grant execute on function public.process_dropship_courier_remittance_uwl(bigint, numeric, numeric, text) to service_role;


-- ============================================================================
-- 2. Authoritative function: record_dropship_courier_remittance
-- ============================================================================
create or replace function public.record_dropship_courier_remittance(
  p_order_id bigint,
  p_net_amount numeric,
  p_remittance_ref text,
  p_bank_trx_id text default null,
  p_payment_date date default null,
  p_method text default 'cash',
  p_note text default null,
  p_courier_charge numeric default 0.00
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_invoice public.global_invoices;
  v_parent_tenant_id bigint;
  v_payment_id bigint;
  v_ref text;
  v_outstanding numeric(12,2);
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    raise exception 'Order not found';
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    raise exception 'Order is not a dropship order';
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'Courier remittance requires order status delivered (current: %)', v_order.status;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Accounting invoice is required before recording courier remittance';
  end if;

  v_ref := nullif(trim(coalesce(p_remittance_ref, '')), '');
  if v_ref is null then
    raise exception 'Remittance reference is required';
  end if;

  if coalesce(p_net_amount, 0.00) <= 0.00 then
    raise exception 'Net remittance amount must be positive';
  end if;

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

  select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id for update;
  if v_invoice.id is null then
    raise exception 'Invoice not found';
  end if;
  if v_invoice.collection_source <> 'recipient'::public.collection_source_type then
    raise exception 'This invoice does not collect from recipient.';
  end if;

  -- Over-remittance cap check against outstanding invoice balance
  v_outstanding := greatest(coalesce(v_invoice.total_amount, 0.00) - coalesce(v_invoice.paid_amount, 0.00), 0.00);
  if v_outstanding > 0 and p_net_amount > v_outstanding then
    raise exception 'Remittance amount (%) exceeds outstanding collectible invoice balance (%)', p_net_amount, v_outstanding;
  end if;

  -- 1. Execute shared UWL ledger transaction
  perform public.process_dropship_courier_remittance_uwl(
    p_order_id => p_order_id,
    p_net_amount => p_net_amount,
    p_courier_charge => coalesce(p_courier_charge, 0.00),
    p_remittance_ref => v_ref
  );

  -- 2. Post global payment (recipient collection)
  insert into public.global_payments (
    tenant_id,
    billing_profile_id,
    collection_source,
    amount,
    unallocated_amount,
    payment_date,
    method,
    reference,
    note
  )
  values (
    v_invoice.tenant_id,
    null,
    'recipient'::public.collection_source_type,
    p_net_amount,
    0.00,
    coalesce(p_payment_date, current_date),
    coalesce(nullif(trim(p_method), ''), 'cash'),
    v_ref,
    coalesce(
      nullif(trim(p_note), ''),
      'Courier remittance order #' || v_order.order_no
        || coalesce(' bank:' || nullif(trim(p_bank_trx_id), ''), '')
    )
  )
  returning id into v_payment_id;

  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_invoice.tenant_id, v_payment_id, v_order.global_invoice_id, p_net_amount);

  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + p_net_amount,
    note = coalesce(nullif(trim(p_note), ''), note),
    updated_at = now()
  where id = v_order.global_invoice_id;

  perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = v_ref,
    courier_bank_trx_id = coalesce(nullif(trim(p_bank_trx_id), ''), courier_bank_trx_id),
    updated_at = now()
  where id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'invoice_id', v_order.global_invoice_id,
    'payment_id', v_payment_id,
    'order_id', p_order_id,
    'status', 'payment_received'
  );
end;
$$;

grant execute on function public.record_dropship_courier_remittance(
  bigint, numeric, text, text, date, text, text, numeric
) to authenticated;


-- ============================================================================
-- 3. Thin wrapper: confirm_courier_remittance_to_tenant (Legacy Drop R1)
-- ============================================================================
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
  v_order record;
  v_invoice record;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
  v_ref text;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', format('Shop order #%s not found', p_order_id));
  end if;

  if v_order.status <> 'delivered' then
    return jsonb_build_object(
      'success', false,
      'error', format('Order #%s status is "%s" (must be "delivered" to remit)', v_order.order_no, v_order.status)
    );
  end if;

  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id;
  end if;

  if v_order.global_invoice_id is not null then
    select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    if v_invoice.id is not null and v_invoice.invoice_status = 'draft'::public.global_invoice_status then
      perform public.post_global_invoice(v_order.global_invoice_id);
    end if;
  end if;

  v_cod := coalesce(v_order.cod_collect_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);
  v_ref := coalesce(nullif(trim(p_remittance_ref), ''), 'REMIT-' || v_order.order_no);

  return public.record_dropship_courier_remittance(
    p_order_id => p_order_id,
    p_net_amount => v_net_remitted,
    p_remittance_ref => v_ref,
    p_bank_trx_id => p_bank_trx_id,
    p_payment_date => current_date,
    p_method => 'cash',
    p_note => null,
    p_courier_charge => v_charge
  );
end;
$$;

grant execute on function public.confirm_courier_remittance_to_tenant(bigint, numeric, text, text) to authenticated;
grant execute on function public.confirm_courier_remittance_to_tenant(bigint, numeric, text, text) to service_role;


-- ============================================================================
-- 4. Update advance_dropship_order_status (middleman entity & canonical source_id)
-- ============================================================================
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
  v_billing_profile_id bigint;
  v_profit numeric(12,2) := 0.00;

  v_recipient_subtotal numeric(12,2) := 0;
  v_accounting_subtotal numeric(12,2) := 0;
  v_middleman_cost numeric(12,2) := 0;
  v_tenant_revenue numeric(12,2) := 0;
  v_currency text;
begin
  select * into v_order from public.shop_orders where id = p_order_id for update;
  if v_order.id is null then
    return jsonb_build_object('success', false, 'error', 'Order not found');
  end if;

  if v_order.shop_type_snapshot <> 'dropship' then
    return jsonb_build_object('success', false, 'error', 'Order is not a dropship order');
  end if;

  v_current_status := v_order.status;
  v_currency := 'BDT';

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

    -- Ensure invoice_billed UWL debit entry is created/confirmed
    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      perform public.ensure_dropship_invoice_billed_entry(v_order.global_invoice_id);
    end if;

    -- Resolve billing profile
    v_billing_profile_id := v_order.billing_profile_id;
    if v_billing_profile_id is null and v_order.customer_group_id is not null then
      select id into v_billing_profile_id
      from public.billing_profiles
      where tenant_id = v_order.tenant_id
        and customer_group_id = v_order.customer_group_id
      order by created_at asc
      limit 1;
    end if;

    -- Refresh order + invoice after invoice creation
    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
    end if;

    -- Calculate profit using dynamic item query
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

    -- Tenant net revenue = total invoiced minus reseller profit payout
    v_tenant_revenue := coalesce(v_invoice.total_amount, 0) - greatest(v_profit, 0);

    -- Universal wallet: reseller dropship_profit credit (entity_type='middleman', source_id=order.id::text)
    if v_billing_profile_id is not null and v_profit > 0 then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order'
          and source_id = p_order_id::text
          and entity_type = 'middleman'
          and entity_id = v_billing_profile_id
          and metadata->>'transaction_type' = 'dropship_profit'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'middleman',
          p_entity_id => v_billing_profile_id,
          p_type => 'credit',
          p_amount => v_profit,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'payout_earned',
            'transaction_type', 'dropship_profit',
            'label', 'Profit Earned',
            'order_no', v_order.order_no,
            'invoice_id', v_order.global_invoice_id
          )
        );
      end if;
    end if;

    -- Universal wallet: tenant revenue credit
    if v_tenant_revenue > 0 then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order'
          and source_id = p_order_id::text
          and entity_type = 'tenant'
          and entity_id = v_order.tenant_id
          and metadata->>'transaction_type' = 'revenue'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'tenant',
          p_entity_id => v_order.tenant_id,
          p_type => 'credit',
          p_amount => v_tenant_revenue,
          p_currency_code => v_currency,
          p_exchange_rate => 1.000000,
          p_source_type => 'shop_order',
          p_source_id => p_order_id::text,
          p_metadata => jsonb_build_object(
            'section', 'revenue',
            'transaction_type', 'revenue',
            'label', 'Revenue',
            'order_no', v_order.order_no,
            'invoice_id', v_order.global_invoice_id
          )
        );
      end if;
    end if;

  elsif p_target_status = 'processing' then
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
      if v_invoice.invoice_status = 'posted'::public.global_invoice_status then
        perform public.unpost_global_invoice(v_order.global_invoice_id);
      end if;

      -- Remove universal_wallet_ledger entries for this order on rollback
      delete from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and (source_id = p_order_id::text or source_id = v_order.order_no)
        and tenant_id = v_order.tenant_id;

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
