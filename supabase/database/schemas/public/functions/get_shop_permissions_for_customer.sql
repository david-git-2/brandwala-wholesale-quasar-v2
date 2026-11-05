CREATE FUNCTION public.get_shop_permissions_for_customer (
  p_shop_id bigint
)
  RETURNS TABLE (
    can_browse                   boolean,
    can_see_buy_price            boolean,
    can_see_sell_price           boolean,
    can_see_resell_minimum_price boolean,
    can_add_to_cart              boolean,
    can_place_order              boolean,
    can_negotiate                boolean,
    can_view_quantity            boolean,
    can_set_dropship_price       boolean
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop_active boolean;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_shop_allows_negotiate boolean;
begin
  select is_active, tenant_id, shop_type
  into v_shop_active, v_tenant_id, v_shop_type
  from public.shops
  where id = p_shop_id;

  if v_shop_active is not true then
    return query select false, false, false, false, false, false, false, false, false;
    return;
  end if;
  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  return query
  select
    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_browse, profile.default_can_browse, false)
      end
    ), false) as can_browse,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else public.resolve_shop_can_see_buy_price(
        v_shop_type,
        access.can_see_buy_price,
        access.can_see_sell_price,
        profile.default_can_see_buy_price,
        profile.default_can_see_sell_price
      )
      end
    ), false) as can_see_buy_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else
        case when v_shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
        end
      end
    ), false) as can_see_sell_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_see_resell_minimum_price, profile.default_can_see_resell_minimum_price, false)
      end
    ), false) as can_see_resell_minimum_price,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, false)
      end
    ), false) as can_add_to_cart,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_place_order, profile.default_can_place_order, false)
      end
    ), false) as can_place_order,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_negotiate, profile.default_can_negotiate, false)
      end
    ) and v_shop_allows_negotiate, false) as can_negotiate,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
      else coalesce(access.can_view_quantity, profile.default_can_view_quantity, false)
      end
    ), false) as can_view_quantity,

    coalesce(bool_or(
      case when access.status = false or coalesce(profile.is_active, true) = false then false
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
    and cg.id = public.current_customer_group_id(v_tenant_id)
    and cg.is_active = true
    and cg.deleted_at is null
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
    and coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_tenant_id);
end;
$function$;

GRANT ALL ON FUNCTION public.get_shop_permissions_for_customer(bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shop_permissions_for_customer(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shop_permissions_for_customer(bigint) TO service_role;