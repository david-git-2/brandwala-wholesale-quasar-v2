-- Migration: Add dropship recipient and consignment fields to shop_orders and shops
begin;

-- Add missing status enum values to shop_order_status
alter type public.shop_order_status add value if not exists 'ready_for_pickup';
alter type public.shop_order_status add value if not exists 'returned';

-- Add recipient block A columns to shop_orders
alter table public.shop_orders
  add column if not exists recipient_phone_secondary text,
  add column if not exists shipping_district text,
  add column if not exists shipping_thana text;

-- Add parcel block B and courier block E consignment columns to shop_orders
alter table public.shop_orders
  add column if not exists cod_collect_amount numeric(15,2),
  add column if not exists package_weight_kg numeric(8,2),
  add column if not exists sender_name text,
  add column if not exists pickup_phone text,
  add column if not exists pickup_address text,
  add column if not exists allow_open_box boolean default false,
  add column if not exists driver_notes text,
  add column if not exists courier_service_id bigint,
  add column if not exists courier_name text,
  add column if not exists courier_awb_number text,
  add column if not exists tracking_url text,
  add column if not exists delivered_at timestamptz,
  add column if not exists returned_at timestamptz;

-- Add merchant sender pickup defaults to shops table
alter table public.shop_orders
  add column if not exists default_sender_name text,
  add column if not exists default_pickup_phone text,
  add column if not exists default_pickup_address text,
  add column if not exists default_payout_account_type text,
  add column if not exists default_payout_account_info text;

alter table public.shops
  add column if not exists default_sender_name text,
  add column if not exists default_pickup_phone text,
  add column if not exists default_pickup_address text,
  add column if not exists default_payout_account_type text,
  add column if not exists default_payout_account_info text,
  add column if not exists deduct_return_charge_from_middle_man boolean default true;

commit;
