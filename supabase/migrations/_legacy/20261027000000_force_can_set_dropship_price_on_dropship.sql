-- Force can_set_dropship_price to true for dropship shops if access status and profile are active

create or replace function public.get_shop_permissions_for_customer(p_shop_id bigint)
returns table (
  can_browse boolean,
  see_price boolean,
  can_add_to_cart boolean,
  can_place_order boolean,
  can_negotiate boolean,
  can_view_quantity boolean,
  can_set_dropship_price boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shop_active boolean;
  v_tenant_id bigint;
  v_is_negotiable boolean;
  v_shop_type public.shop_type_enum;
begin
  select is_active, tenant_id, is_negotiable, shop_type
  into v_shop_active, v_tenant_id, v_is_negotiable, v_shop_type
  from public.shops
  where id = p_shop_id;

  if v_shop_active is not true then
    return query select false, false, false, false, false, false, false;
    return;
  end if;

  return query
  select
    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_browse, profile.default_can_browse, false)
      end
    ), false) as can_browse,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else 
        case when v_shop_type = 'dropship' then true
        else coalesce(access.see_price, profile.default_see_price, false)
        end
      end
    ), false) as see_price,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, false)
      end
    ), false) as can_add_to_cart,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_place_order, profile.default_can_place_order, false)
      end
    ), false) as can_place_order,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_negotiate, profile.default_can_negotiate, false)
      end
    ) and v_is_negotiable, false) as can_negotiate,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_view_quantity, profile.default_can_view_quantity, false)
      end
    ), false) as can_view_quantity,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else 
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false)
        end
      end
    ), false) as can_set_dropship_price
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  join public.shop_customer_group_access access on access.customer_group_id = cg.id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = v_tenant_id
  where access.shop_id = p_shop_id
    and cg.tenant_id = v_tenant_id
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email();
end;
$$;
