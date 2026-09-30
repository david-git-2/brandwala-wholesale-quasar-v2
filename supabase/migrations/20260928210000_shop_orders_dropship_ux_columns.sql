-- Denormalized dropship finance columns (before remittance collection_source migration).

begin;

alter table public.shop_orders
  add column if not exists collection_source public.collection_source_type null;

alter table public.shop_orders
  add column if not exists payout_settlement_status text null
    check (
      payout_settlement_status is null
      or payout_settlement_status in ('unpaid', 'partial', 'paid')
    );

comment on column public.shop_orders.collection_source is
  'Dropship: recipient = courier COD remittance; billing_profile = merchant prepaid. Not the merchant invoice collection_source.';
comment on column public.shop_orders.payout_settlement_status is
  'Merchant profit settlement: unpaid | partial | paid (order-level)';

commit;
