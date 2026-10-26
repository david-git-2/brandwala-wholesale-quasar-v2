-- Migration: Streamlined Courier Remittance & Middleman Dispense Workflow RPCs
-- Phase 1 of Courier and Middleman Financial Master Plan

begin;

-- 1. Aggregated Courier Unremitted Financial Summary RPC
create or replace function public.get_courier_unremitted_financial_summary(
  p_tenant_id bigint
)
returns table (
  courier_service_id uuid,
  courier_name text,
  gross_cod_total numeric(12,2),
  company_wholesale_total numeric(12,2),
  middleman_margin_total numeric(12,2),
  order_count bigint
)
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_tenant_id is null then
    raise exception 'Tenant ID is required';
  end if;

  return query
  select
    so.courier_service_id,
    coalesce(cs.name, so.courier_name, 'Unassigned') as courier_name,
    coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00)::numeric(12,2) as gross_cod_total,
    (
      coalesce(sum(coalesce(so.cod_collect_amount, gi.total_amount, 0)), 0.00) -
      coalesce(sum(coalesce(wl.amount, 0)), 0.00)
    )::numeric(12,2) as company_wholesale_total,
    coalesce(sum(coalesce(wl.amount, 0)), 0.00)::numeric(12,2) as middleman_margin_total,
    count(so.id)::bigint as order_count
  from public.shop_orders so
  left join public.courier_services cs on cs.id = so.courier_service_id
  left join public.global_invoices gi on gi.id = so.global_invoice_id
  left join public.billing_profile_wallet_ledger wl
    on wl.shop_order_id = so.id and wl.transaction_type = 'dropship_profit'
  where so.tenant_id = p_tenant_id
    and so.status = 'delivered'
  group by so.courier_service_id, coalesce(cs.name, so.courier_name, 'Unassigned');
end;
$$;

grant execute on function public.get_courier_unremitted_financial_summary(bigint) to authenticated;
grant execute on function public.get_courier_unremitted_financial_summary(bigint) to service_role;

-- 2. Single-Order Inline Remittance Reconciliation RPC
create or replace function public.reconcile_single_order_remittance(
  p_order_id bigint,
  p_courier_charge numeric default 0.00
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.shop_orders;
  v_invoice public.global_invoices;
  v_payment_id bigint;
  v_cod numeric(12,2) := 0.00;
  v_charge numeric(12,2) := 0.00;
  v_net_remitted numeric(12,2) := 0.00;
begin
  select * into v_order
  from public.shop_orders
  where id = p_order_id for update;

  if v_order.id is null then
    raise exception 'Shop order #% not found', p_order_id;
  end if;

  if v_order.status <> 'delivered' then
    raise exception 'Order #% cannot be remitted because current status is "%" (must be "delivered")', v_order.order_no, v_order.status;
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
    raise exception 'Permission denied: Staff or Admin role required for tenant %', v_order.tenant_id;
  end if;

  -- Ensure global invoice exists or create it
  if v_order.global_invoice_id is null then
    perform public.create_dual_invoice_from_dropship_order(p_order_id);
    select * into v_order from public.shop_orders where id = p_order_id for update;
  end if;

  if v_order.global_invoice_id is null then
    raise exception 'Failed to resolve accounting invoice for order #%', v_order.order_no;
  end if;

  select * into v_invoice
  from public.global_invoices
  where id = v_order.global_invoice_id for update;

  v_cod := coalesce(v_order.cod_collect_amount, v_invoice.total_amount, 0.00);
  v_charge := coalesce(p_courier_charge, 0.00);
  v_net_remitted := greatest(v_cod - v_charge, 0.00);

  -- Record global payment
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
    v_order.tenant_id,
    v_invoice.billing_profile_id,
    coalesce(v_invoice.collection_source, 'recipient'),
    v_net_remitted,
    0.00,
    current_date,
    'bank',
    coalesce(v_order.courier_awb_number, v_order.order_no),
    'Single-order inline remittance for order #' || v_order.order_no
  )
  returning id into v_payment_id;

  -- Allocate invoice payment
  insert into public.invoice_payments (tenant_id, payment_id, global_invoice_id, amount)
  values (v_order.tenant_id, v_payment_id, v_order.global_invoice_id, v_net_remitted);

  -- Update global invoice paid amount & status
  update public.global_invoices
  set
    paid_amount = coalesce(paid_amount, 0.00) + v_net_remitted,
    updated_at = now()
  where id = v_order.global_invoice_id;

  perform public.recompute_global_invoice_payment_status(v_order.global_invoice_id);

  -- Update shop order status to payment_received
  update public.shop_orders
  set
    status = 'payment_received'::public.shop_order_status,
    courier_remittance_ref = coalesce(courier_remittance_ref, 'SINGLE-REMIT-' || v_order.order_no),
    updated_at = now()
  where id = v_order.id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'new_status', 'payment_received',
    'net_remitted', v_net_remitted
  );
end;
$$;

grant execute on function public.reconcile_single_order_remittance(bigint, numeric) to authenticated;
grant execute on function public.reconcile_single_order_remittance(bigint, numeric) to service_role;

-- 3. Dispense Middleman Payout RPC
create or replace function public.dispense_middleman_payout(
  p_billing_profile_id bigint,
  p_amount numeric,
  p_method text default 'bkash',
  p_trx_id text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_profile public.billing_profiles;
  v_avail_balance numeric(12,2) := 0.00;
  v_entry public.billing_profile_wallet_ledger;
begin
  if p_billing_profile_id is null then
    raise exception 'Billing Profile ID is required';
  end if;

  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Payout amount must be greater than zero';
  end if;

  select * into v_profile
  from public.billing_profiles
  where id = p_billing_profile_id;

  if v_profile.id is null then
    raise exception 'Billing profile #% not found', p_billing_profile_id;
  end if;

  -- Check available balance in ledger
  select balance_after into v_avail_balance
  from public.billing_profile_wallet_ledger
  where tenant_id = v_profile.tenant_id
    and billing_profile_id = p_billing_profile_id
  order by created_at desc, id desc
  limit 1
  for update;

  v_avail_balance := coalesce(v_avail_balance, 0.00);

  if v_avail_balance < p_amount then
    raise exception 'Insufficient wallet balance. Available balance: %, requested payout: %', v_avail_balance, p_amount;
  end if;

  -- Record payout_paid entry in ledger
  v_entry := public.record_wallet_ledger_entry(
    p_tenant_id => v_profile.tenant_id,
    p_billing_profile_id => p_billing_profile_id,
    p_transaction_type => 'payout_paid',
    p_amount => p_amount,
    p_reference_id => p_trx_id,
    p_reference_notes => format('Dispensed payout via %s (TRX: %s)', coalesce(p_method, 'transfer'), coalesce(p_trx_id, 'N/A')),
    p_created_by => auth.uid()
  );

  return jsonb_build_object(
    'success', true,
    'billing_profile_id', p_billing_profile_id,
    'amount', p_amount,
    'new_balance', v_entry.balance_after
  );
end;
$$;

grant execute on function public.dispense_middleman_payout(bigint, numeric, text, text) to authenticated;
grant execute on function public.dispense_middleman_payout(bigint, numeric, text, text) to service_role;

commit;
