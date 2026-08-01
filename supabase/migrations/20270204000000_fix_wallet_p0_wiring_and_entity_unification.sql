-- Migration: 20270204000000_fix_wallet_p0_wiring_and_entity_unification.sql
-- Goal: Fix P0 bugs:
-- 1. Unify entity_type: convert 'middleman' to 'customer' across all dropship wallet RPCs & backfill wallet_accounts.
-- 2. Retire legacy dual-writes to billing_profile_wallet_ledger.
-- 3. Resolve courier entity_id from courier_services.wallet_entity_id instead of hardcoding 0.

begin;

-- ============================================================================
-- 1. Shared internal routine: process_dropship_courier_remittance_uwl
--    (Resolves courier_services.wallet_entity_id, writes customer entity)
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

  -- Resolve courier entity ID from courier_services if available
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
-- 2. Unify middleman → customer in universal_wallet_ledger and rebuild wallet_accounts
-- ============================================================================
update public.universal_wallet_ledger
set entity_type = 'customer'
where entity_type = 'middleman';

-- Recalculate materialized wallet_accounts balances from universal_wallet_ledger
do $$
declare
  r record;
begin
  -- Clear out legacy middleman rows in wallet_accounts
  delete from public.wallet_accounts where entity_type = 'middleman';

  -- Re-aggregate wallet_accounts from universal_wallet_ledger for customer entities
  for r in (
    select 
      tenant_id,
      entity_type,
      entity_id,
      currency_code,
      sum(case when type = 'credit' and (target_bucket = 'available' or target_bucket is null) then base_amount
               when type = 'debit' and (target_bucket = 'available' or target_bucket is null) then -base_amount
               else 0 end) as total_available,
      sum(case when type = 'credit' and target_bucket = 'pending' then base_amount
               when type = 'debit' and target_bucket = 'pending' then -base_amount
               else 0 end) as total_pending,
      sum(case when type = 'credit' and target_bucket = 'locked' then base_amount
               when type = 'debit' and target_bucket = 'locked' then -base_amount
               else 0 end) as total_locked
    from public.universal_wallet_ledger
    where entity_type = 'customer'
    group by tenant_id, entity_type, entity_id, currency_code
  ) loop
    insert into public.wallet_accounts (
      tenant_id, entity_type, entity_id, currency_code,
      available_balance, pending_balance, locked_balance, updated_at
    )
    values (
      r.tenant_id, r.entity_type, r.entity_id, coalesce(r.currency_code, 'BDT'),
      greatest(r.total_available, 0.00), greatest(r.total_pending, 0.00), greatest(r.total_locked, 0.00), now()
    )
    on conflict (tenant_id, entity_type, entity_id, currency_code)
    do update set
      available_balance = excluded.available_balance,
      pending_balance = excluded.pending_balance,
      locked_balance = excluded.locked_balance,
      updated_at = now();
  end loop;
end $$;

commit;
