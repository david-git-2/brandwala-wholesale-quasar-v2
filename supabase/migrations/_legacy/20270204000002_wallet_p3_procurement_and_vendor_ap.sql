-- Migration: 20270204000002_wallet_p3_procurement_and_vendor_ap.sql
-- Goal: Phase 3 Procurement & Vendor Accounts Payable integration
-- 1. Create record_vendor_grn_payable RPC to log vendor AP upon inbound shipment receipt.
-- 2. Create record_vendor_payment_outflow RPC to settle vendor AP and record tenant cash outflow.

begin;

-- ============================================================================
-- 1. record_vendor_grn_payable
-- ============================================================================
create or replace function public.record_vendor_grn_payable(
  p_tenant_id bigint,
  p_vendor_id bigint,
  p_amount numeric,
  p_source_id text,
  p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_res jsonb;
begin
  if p_tenant_id is null or p_vendor_id is null then
    raise exception 'Tenant ID and Vendor ID are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'GRN payable amount must be positive.';
  end if;

  v_res := public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'vendor',
    p_entity_id => p_vendor_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => p_source_id,
    p_metadata => jsonb_build_object(
      'section', 'procurement',
      'purpose', 'vendor_grn_payable',
      'transaction_type', 'vendor_payable',
      'label', 'Vendor Payable (GRN Received)'
    ) || coalesce(p_metadata, '{}'::jsonb)
  );

  return jsonb_build_object('success', true, 'entry', v_res);
end;
$$;

grant execute on function public.record_vendor_grn_payable(bigint, bigint, numeric, text, jsonb) to authenticated;
grant execute on function public.record_vendor_grn_payable(bigint, bigint, numeric, text, jsonb) to service_role;


-- ============================================================================
-- 2. record_vendor_payment_outflow
-- ============================================================================
create or replace function public.record_vendor_payment_outflow(
  p_tenant_id bigint,
  p_vendor_id bigint,
  p_amount numeric,
  p_payment_method text default 'bank_transfer',
  p_reference text default null,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_payment_id text;
  v_vendor_res jsonb;
  v_tenant_res jsonb;
begin
  if p_tenant_id is null or p_vendor_id is null then
    raise exception 'Tenant ID and Vendor ID are required.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Vendor payment amount must be positive.';
  end if;

  v_payment_id := 'VP-' || gen_random_uuid()::text;

  -- Leg 1: Debit Vendor AP (reduces vendor payable balance)
  v_vendor_res := public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'vendor',
    p_entity_id => p_vendor_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => v_payment_id,
    p_metadata => jsonb_build_object(
      'section', 'vendor_payments',
      'purpose', 'vendor_ap_settlement',
      'transaction_type', 'vendor_payment_paid',
      'label', 'Vendor Payment Settled',
      'payment_method', p_payment_method,
      'reference', p_reference,
      'notes', p_note
    )
  );

  -- Leg 2: Debit Tenant Cash (cash outflow from bank/cash account)
  v_tenant_res := public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'vendor_purchase',
    p_source_id => v_payment_id,
    p_metadata => jsonb_build_object(
      'section', 'vendor_payments',
      'purpose', 'tenant_vendor_cash_outflow',
      'transaction_type', 'vendor_payment_paid',
      'label', 'Cash Outflow (Vendor Payment)',
      'vendor_id', p_vendor_id,
      'payment_method', p_payment_method,
      'reference', p_reference,
      'notes', p_note
    )
  );

  return jsonb_build_object(
    'success', true,
    'payment_id', v_payment_id,
    'vendor_entry', v_vendor_res,
    'tenant_entry', v_tenant_res
  );
end;
$$;

grant execute on function public.record_vendor_payment_outflow(bigint, bigint, numeric, text, text, text) to authenticated;
grant execute on function public.record_vendor_payment_outflow(bigint, bigint, numeric, text, text, text) to service_role;

commit;
