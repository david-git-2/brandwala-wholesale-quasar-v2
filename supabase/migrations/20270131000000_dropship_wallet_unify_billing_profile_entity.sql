-- ============================================================================
-- Dropship Wallet Phase A: One billing-profile wallet (customer entity)
-- - Profit / payout / clawback write entity_type = 'customer' (same id as invoice_billed)
-- - Backfill middleman → customer and recalc balance_after
-- ============================================================================

begin;

-- ---------------------------------------------------------------------------
-- 1. advance_dropship_order_status — profit credit → customer
-- ---------------------------------------------------------------------------
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

    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      perform public.ensure_dropship_invoice_billed_entry(v_order.global_invoice_id);
    end if;

    v_billing_profile_id := v_order.billing_profile_id;
    if v_billing_profile_id is null and v_order.customer_group_id is not null then
      select id into v_billing_profile_id
      from public.billing_profiles
      where tenant_id = v_order.tenant_id
        and customer_group_id = v_order.customer_group_id
      order by created_at asc
      limit 1;
    end if;

    select * into v_order from public.shop_orders where id = p_order_id;
    if v_order.global_invoice_id is not null then
      select * into v_invoice from public.global_invoices where id = v_order.global_invoice_id;
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

    v_tenant_revenue := v_accounting_subtotal
      + coalesce(v_order.print_charge_amount, 0)
      + coalesce(v_order.packing_charge_amount, 0);

    -- Billing profile wallet: dropship_profit on customer entity (same as invoice_billed)
    if v_billing_profile_id is not null and v_profit > 0 then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where source_type = 'shop_order'
          and source_id = p_order_id::text
          and entity_type in ('customer', 'middleman')
          and entity_id = v_billing_profile_id
          and metadata->>'transaction_type' = 'dropship_profit'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_order.tenant_id,
          p_entity_type => 'customer',
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

      delete from public.universal_wallet_ledger
      where source_type = 'shop_order'
        and (source_id = p_order_id::text or source_id = v_order.order_no)
        and tenant_id = v_order.tenant_id;

      update public.shop_orders
      set global_invoice_id = null
      where id = p_order_id;

      delete from public.global_return_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoice_items where invoice_id = v_order.global_invoice_id;
      delete from public.global_invoices where id = v_order.global_invoice_id;
    end if;
  end if;

  return jsonb_build_object('success', true, 'new_status', p_target_status);
end;
$$;

grant execute on function public.advance_dropship_order_status(bigint, public.shop_order_status, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. dispense_middleman_payout_from_tenant — debit customer + payout_earned section
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

  v_payout_id := 'PO-' || gen_random_uuid()::text;

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
    p_tenant_id => p_tenant_id,
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

grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to authenticated;
grant execute on function public.dispense_middleman_payout_from_tenant(bigint, bigint, numeric, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 3. Backfill middleman → customer + recalc balance_after
-- ---------------------------------------------------------------------------
do $$
declare
  r record;
  e record;
  bal numeric(15,4);
begin
  update public.universal_wallet_ledger
  set entity_type = 'customer'
  where entity_type = 'middleman';

  for r in (
    select distinct tenant_id, entity_id
    from public.universal_wallet_ledger
    where entity_type = 'customer'
  ) loop
    bal := 0;
    for e in (
      select id, type, base_amount
      from public.universal_wallet_ledger
      where tenant_id = r.tenant_id
        and entity_type = 'customer'
        and entity_id = r.entity_id
      order by created_at asc, id asc
    ) loop
      if e.type = 'credit' then
        bal := bal + e.base_amount;
      else
        bal := bal - e.base_amount;
      end if;
      update public.universal_wallet_ledger
      set balance_after = bal
      where id = e.id;
    end loop;
  end loop;
end $$;

commit;
