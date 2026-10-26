-- Customer-facing shop list: shops the caller's group can browse.

create or replace function public.list_shops_for_customer(
  p_tenant_id bigint default null
)
returns table (
  id          bigint,
  tenant_id   bigint,
  name        text,
  slug        text,
  shop_type   public.shop_type_enum,
  order_mode  public.shop_order_mode_enum,
  is_negotiable boolean,
  see_price   boolean
)
language sql
security definer
set search_path = public
stable
as $$
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        else coalesce(access.see_price, profile.default_see_price, false)
      end
    ) as see_price
  from public.shops s
  join public.shop_customer_group_access access on access.shop_id = s.id
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
  where s.is_active = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
    and (p_tenant_id is null or s.tenant_id = p_tenant_id)
    and access.status = true
    and coalesce(profile.is_active, true) = true
    and coalesce(access.can_browse, profile.default_can_browse, false) = true
  group by
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable
  order by s.name asc;
$$;

grant execute on function public.list_shops_for_customer(bigint) to authenticated;
