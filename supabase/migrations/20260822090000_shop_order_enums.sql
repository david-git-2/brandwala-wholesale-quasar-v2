-- Fresh-reset ordering: shop_order enums must exist before Aug 20260822 RPC migrations.
begin;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_type_enum') then
    create type public.shop_type_enum as enum (
      'vendor_catalog',
      'fixed_price',
      'dropship'
    );
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_order_mode_enum') then
    create type public.shop_order_mode_enum as enum (
      'procurement_intent',
      'checkout_fixed',
      'checkout_wholesale'
    );
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_cart_status') then
    create type public.shop_cart_status as enum (
      'active',
      'converted',
      'abandoned'
    );
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_order_status') then
    create type public.shop_order_status as enum (
      'draft',
      'submitted',
      'cancelled',
      'priced',
      'negotiating',
      'confirmed',
      'placed',
      'fulfilled',
      'processing',
      'shipped',
      'delivered',
      'payment_received',
      'reseller_paid',
      'ready_for_pickup',
      'returned',
      'costing_pending',
      'countered',
      'final_offered',
      'procuring',
      'ready_for_shipment',
      'ordered'
    );
  end if;
end $$;

commit;
