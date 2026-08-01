-- Migration: 20270204000003_wallet_p5_investor_capital.sql
-- Goal: Phase 5 Investor Capital Universal Wallet integration
-- 1. Drop old restrictive check constraints on universal_wallet_ledger if present.
-- 2. Update record_investor_capital_in to write UWL tenant credit (cash in) and investor credit (capital liability).
-- 3. Update record_investor_withdrawal_paid to write UWL investor debit (capital reduction) and tenant debit (cash payout).
-- 4. Update refresh_shipment_investor_profits to credit investor pending bucket for accrued profit.

begin;

-- ============================================================================
-- 1. Widen check constraints on universal_wallet_ledger
-- ============================================================================
do $$
begin
  alter table public.universal_wallet_ledger drop constraint if exists universal_wallet_ledger_entity_type_check;
  alter table public.universal_wallet_ledger drop constraint if exists universal_wallet_ledger_source_type_check;
exception
  when undefined_object then null;
end $$;


-- ============================================================================
-- 2. Redefine record_investor_capital_in
-- ============================================================================
create or replace function public.record_investor_capital_in(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns public.investor_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.investor_transactions;
begin
  if not public.user_can_manage_parent_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'capital_in'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  -- 1. Credit Tenant Cash Available (money received into platform)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_tenant_cash',
      'transaction_type', 'capital_in',
      'label', 'Capital In Deposit',
      'investor_id', p_investor_id,
      'notes', p_note
    )
  );

  -- 2. Credit Investor Available (capital liability owed to investor)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'credit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'adjustment',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'capital_in_investor_liability',
      'transaction_type', 'capital_in',
      'label', 'Capital Injected',
      'notes', p_note
    )
  );

  return v_row;
end;
$$;

grant execute on function public.record_investor_capital_in(bigint, bigint, numeric, date, public.investor_payment_method, text) to authenticated;
grant execute on function public.record_investor_capital_in(bigint, bigint, numeric, date, public.investor_payment_method, text) to service_role;


-- ============================================================================
-- 3. Redefine record_investor_withdrawal_paid
-- ============================================================================
create or replace function public.record_investor_withdrawal_paid(
  p_tenant_id bigint,
  p_investor_id bigint,
  p_amount numeric,
  p_date date,
  p_method public.investor_payment_method,
  p_note text
)
returns public.investor_transactions
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.investor_transactions;
begin
  if not public.user_can_manage_parent_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.investor_transactions (
    tenant_id, investor_id, amount, date, method, type, note
  ) values (
    p_tenant_id, p_investor_id, p_amount, p_date, p_method, 'withdrawal_paid'::public.investor_transaction_type, p_note
  )
  returning * into v_row;

  -- 1. Debit Investor Available (reduces capital liability)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'investor',
    p_entity_id => p_investor_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'investor_withdrawal_debit',
      'transaction_type', 'withdrawal_paid',
      'label', 'Capital Withdrawal Paid',
      'notes', p_note
    )
  );

  -- 2. Debit Tenant Cash (cash outflow from platform)
  perform public.record_ledger_transaction(
    p_tenant_id => p_tenant_id,
    p_entity_type => 'tenant',
    p_entity_id => p_tenant_id,
    p_type => 'debit',
    p_amount => p_amount,
    p_currency_code => 'BDT',
    p_exchange_rate => 1.000000,
    p_source_type => 'payout',
    p_source_id => v_row.id::text,
    p_metadata => jsonb_build_object(
      'section', 'investor_capital',
      'purpose', 'tenant_investor_cash_outflow',
      'transaction_type', 'withdrawal_paid',
      'label', 'Investor Withdrawal Outflow',
      'investor_id', p_investor_id,
      'notes', p_note
    )
  );

  return v_row;
end;
$$;

grant execute on function public.record_investor_withdrawal_paid(bigint, bigint, numeric, date, public.investor_payment_method, text) to authenticated;
grant execute on function public.record_investor_withdrawal_paid(bigint, bigint, numeric, date, public.investor_payment_method, text) to service_role;


-- ============================================================================
-- 4. Redefine refresh_shipment_investor_profits to update pending bucket
-- ============================================================================
create or replace function public.refresh_shipment_investor_profits(
  p_global_shipment_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment public.global_shipments;
  v_pnl jsonb;
  v_buy numeric(12,2);
  v_profit numeric(12,2);
  v_updated integer := 0;
  v_inv record;
  v_status text;
  v_sold_qty numeric;
  v_received_qty numeric;
  v_computed_profit numeric(12,2);
begin
  select * into v_shipment from public.global_shipments where id = p_global_shipment_id;
  if v_shipment.id is null then raise exception 'global shipment not found'; end if;

  if not public.user_can_manage_parent_tenant(v_shipment.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_pnl := public.get_shipment_pnl(v_shipment.parent_tenant_id, p_global_shipment_id);
  v_buy := coalesce((v_pnl -> 'totals' ->> 'landed_cost')::numeric, 0.00);
  v_profit := coalesce((v_pnl -> 'totals' ->> 'gross_profit')::numeric, 0.00);

  select
    coalesce(sum(ordered_quantity), 0),
    coalesce(sum(sold_qty), 0)
  into v_received_qty, v_sold_qty
  from (
    select
      si.ordered_quantity,
      coalesce(sum(ii.quantity - ii.return_quantity), 0) as sold_qty
    from public.global_shipment_items si
    left join public.global_invoice_items ii on ii.shipment_item_id = si.id
    left join public.global_invoices inv on inv.id = ii.invoice_id and inv.invoice_status = 'posted'::public.global_invoice_status
    where si.shipment_id = p_global_shipment_id
    group by si.id, si.ordered_quantity
  ) t;

  if v_received_qty = 0 then
    v_status := 'open';
  elsif v_sold_qty >= v_received_qty then
    v_status := 'realized';
  elsif v_sold_qty > 0 then
    v_status := 'partial';
  else
    v_status := 'open';
  end if;

  for v_inv in
    select * from public.shipment_investments
    where global_shipment_id = p_global_shipment_id
      and status = 'active'
      and cost_share_pct is not null
  loop
    v_computed_profit := round(v_profit * v_inv.cost_share_pct / 100.0, 2);

    update public.shipment_investments
    set
      allocated_cost = round(v_buy * v_inv.cost_share_pct / 100.0, 2),
      computed_profit = v_computed_profit,
      profit_status = v_status
    where id = v_inv.id;

    -- Update investor pending profit bucket if profit is realized
    if v_computed_profit > 0 and v_status = 'realized' then
      if not exists (
        select 1 from public.universal_wallet_ledger
        where tenant_id = v_shipment.parent_tenant_id
          and entity_type = 'investor'
          and entity_id = v_inv.investor_id
          and source_type = 'vendor_purchase'
          and source_id = p_global_shipment_id::text
          and metadata->>'purpose' = 'shipment_investor_profit'
      ) then
        perform public.record_ledger_transaction(
          p_tenant_id => v_shipment.parent_tenant_id,
          p_entity_type => 'investor',
          p_entity_id => v_inv.investor_id,
          p_type => 'credit',
          p_amount => v_computed_profit,
          p_currency_code => 'BDT',
          p_exchange_rate => 1.000000,
          p_source_type => 'vendor_purchase',
          p_source_id => p_global_shipment_id::text,
          p_metadata => jsonb_build_object(
            'section', 'investor_capital',
            'purpose', 'shipment_investor_profit',
            'transaction_type', 'profit_accrued',
            'label', 'Shipment Profit Distribution',
            'shipment_id', p_global_shipment_id
          ),
          p_target_bucket => 'pending'
        );
      end if;
    end if;

    v_updated := v_updated + 1;
  end loop;

  return jsonb_build_object(
    'global_shipment_id', p_global_shipment_id,
    'updated_count', v_updated,
    'buy_cost_total', v_buy,
    'profit_total', v_profit,
    'profit_status', v_status
  );
end;
$$;

grant execute on function public.refresh_shipment_investor_profits(bigint) to authenticated;
grant execute on function public.refresh_shipment_investor_profits(bigint) to service_role;

commit;
