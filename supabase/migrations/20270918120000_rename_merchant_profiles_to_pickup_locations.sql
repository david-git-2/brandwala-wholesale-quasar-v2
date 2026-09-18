-- Pickup catalog is warehouse / courier sender address, not the reseller.
-- Reseller payouts stay on billing profiles.

begin;

alter table if exists public.merchant_profiles rename to pickup_locations;

alter table public.pickup_locations rename column merchant_name to location_name;

alter index if exists public.idx_merchant_profiles_tenant
  rename to idx_pickup_locations_tenant;

alter table public.pickup_locations
  rename constraint merchant_profiles_pkey to pickup_locations_pkey;

alter table public.pickup_locations
  rename constraint merchant_profiles_tenant_id_fkey to pickup_locations_tenant_id_fkey;

alter policy "Authenticated users can select tenant merchant profiles"
  on public.pickup_locations
  rename to "Authenticated users can select tenant pickup locations";

alter policy "Members can delete merchant profiles"
  on public.pickup_locations
  rename to "Members can delete pickup locations";

alter policy "Members can insert merchant profiles"
  on public.pickup_locations
  rename to "Members can insert pickup locations";

alter policy "Members can update merchant profiles"
  on public.pickup_locations
  rename to "Members can update pickup locations";

commit;
