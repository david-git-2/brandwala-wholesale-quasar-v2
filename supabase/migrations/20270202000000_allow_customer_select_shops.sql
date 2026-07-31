-- Allow customers to select shops that their customer group has browse access to,
-- enabling PostgREST nested joins from shop_orders -> shops.

create policy "shops_select_customer_group"
  on public.shops for select
  using (
    exists (
      select 1
      from public.shop_customer_group_access access
      join public.customer_groups cg on cg.id = access.customer_group_id
      join public.customer_group_members cgm on cgm.customer_group_id = cg.id
      left join public.customer_group_shop_profiles profile
        on profile.customer_group_id = cg.id and profile.tenant_id = shops.tenant_id
      where access.shop_id = shops.id
        and shops.is_active = true
        and cg.is_active = true
        and cgm.is_active = true
        and lower(trim(cgm.email)) = public.current_user_email()
        and access.status = true
        and coalesce(profile.is_active, true) = true
        and coalesce(access.can_browse, profile.default_can_browse, false) = true
    )
  );
