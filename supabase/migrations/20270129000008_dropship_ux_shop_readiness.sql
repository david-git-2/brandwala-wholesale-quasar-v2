-- SQL Migration: 20270129000008_dropship_ux_shop_readiness.sql
-- Description: RPC get_dropship_shop_readiness checking 5 go-live dependencies for dropship shops

create or replace function public.get_dropship_shop_readiness(p_shop_id bigint)
returns table (
  shop_id bigint,
  has_access_group_with_price boolean,
  has_customer_group_with_members boolean,
  has_billing_profile_linked boolean,
  has_listing_with_floor boolean,
  has_active_courier boolean,
  ready boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;

  v_has_access_group_with_price boolean := false;
  v_has_customer_group_with_members boolean := false;
  v_has_billing_profile_linked boolean := false;
  v_has_listing_with_floor boolean := false;
  v_has_active_courier boolean := false;
  v_ready boolean := false;
begin
  select tenant_id, shop_type
  into v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id;

  if v_tenant_id is null then
    return;
  end if;

  -- 1. Access group with can_set_dropship_price
  select coalesce(bool_or(
    access.status = true and coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false) = true
  ), false)
  into v_has_access_group_with_price
  from public.shop_customer_group_access access
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = access.customer_group_id and profile.tenant_id = v_tenant_id
  where access.shop_id = p_shop_id;

  -- 2. Customer group with active members attached to shop access
  select exists (
    select 1
    from public.shop_customer_group_access access
    join public.customer_group_members cgm on cgm.customer_group_id = access.customer_group_id
    where access.shop_id = p_shop_id
      and access.status = true
  )
  into v_has_customer_group_with_members;

  -- 3. Billing profile linked (resolve_billing_profile_for_customer_group returns non-null for at least one linked group)
  select exists (
    select 1
    from public.shop_customer_group_access access
    where access.shop_id = p_shop_id
      and access.status = true
      and public.resolve_billing_profile_for_customer_group(v_tenant_id, access.customer_group_id) is not null
  )
  into v_has_billing_profile_linked;

  -- 4. Active listing with floor price set (minimum_sell_price_amount is not null and > 0)
  select exists (
    select 1
    from public.shop_product_listings
    where shop_id = p_shop_id
      and is_active = true
      and minimum_sell_price_amount is not null
      and minimum_sell_price_amount > 0
  )
  into v_has_listing_with_floor;

  -- 5. Active courier service available for tenant
  select exists (
    select 1
    from public.courier_services
    where tenant_id = v_tenant_id
      and is_active = true
  )
  into v_has_active_courier;

  v_ready := (
    v_has_access_group_with_price and
    v_has_customer_group_with_members and
    v_has_billing_profile_linked and
    v_has_listing_with_floor and
    v_has_active_courier
  );

  return query select
    p_shop_id,
    v_has_access_group_with_price,
    v_has_customer_group_with_members,
    v_has_billing_profile_linked,
    v_has_listing_with_floor,
    v_has_active_courier,
    v_ready;
end;
$$;

grant execute on function public.get_dropship_shop_readiness(bigint) to authenticated;
