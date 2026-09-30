-- Deferred from 20260928230000_dropship_remittance_closes_settlement.sql (needs UWL parent_tenant_id).

begin;

update public.dropship_order_settlements s
set
  remittance_at = coalesce(
    s.remittance_at,
    (
      select min(u.created_at)
      from public.universal_wallet_ledger u
      join public.shop_orders o on o.id = s.shop_order_id
      where u.source_type = 'shop_order'
        and u.source_id = s.shop_order_id::text
        and u.metadata->>'purpose' = 'tenant_remittance_received'
        and u.parent_tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
    )
  ),
  reseller_profit = coalesce(
    (
      select u.amount
      from public.universal_wallet_ledger u
      join public.shop_orders o on o.id = s.shop_order_id
      where u.source_type = 'shop_order'
        and u.source_id = s.shop_order_id::text
        and u.type = 'credit'
        and coalesce(u.metadata->>'transaction_type', '') = 'dropship_profit'
        and u.parent_tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
      order by u.created_at desc
      limit 1
    ),
    s.reseller_profit
  ),
  updated_at = now()
where s.remittance_at is null
  and exists (
    select 1
    from public.shop_orders o
    join public.universal_wallet_ledger u
      on u.source_type = 'shop_order'
     and u.source_id = o.id::text
     and u.metadata->>'purpose' = 'tenant_remittance_received'
     and u.parent_tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
    where o.id = s.shop_order_id
  );

update public.shop_orders o
set
  payout_settlement_status = 'unpaid',
  updated_at = now()
where o.shop_type_snapshot = 'dropship'
  and coalesce(o.payout_settlement_status, 'unpaid') = 'paid'
  and not exists (
    select 1
    from public.dropship_order_settlements s
    where s.shop_order_id = o.id
      and s.merchant_payout_at is not null
  )
  and not exists (
    select 1
    from public.universal_wallet_ledger u
    where u.source_type = 'shop_order'
      and u.source_id = o.id::text
      and u.type = 'debit'
      and coalesce(u.metadata->>'transaction_type', '') = 'profit_paid_out'
      and u.parent_tenant_id = public.resolve_parent_tenant_id(o.tenant_id)
  );

commit;
