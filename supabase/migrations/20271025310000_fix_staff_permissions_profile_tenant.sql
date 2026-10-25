-- Fix customer_group_shop_profiles join: tenant_id not operating_tenant_id
CREATE OR REPLACE FUNCTION public.get_shop_permissions_for_customer_group(
  p_shop_id bigint,
  p_customer_group_id bigint
) RETURNS TABLE(
  can_browse boolean,
  can_see_buy_price boolean,
  can_see_sell_price boolean,
  can_see_resell_minimum_price boolean,
  can_add_to_cart boolean,
  can_place_order boolean,
  can_negotiate boolean,
  can_view_quantity boolean,
  can_set_dropship_price boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_shop_active boolean;
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;
  v_shop_allows_negotiate boolean;
BEGIN
  SELECT is_active, tenant_id, shop_type
  INTO v_shop_active, v_tenant_id, v_shop_type
  FROM public.shops
  WHERE id = p_shop_id;

  IF v_shop_active IS NOT true THEN
    RETURN QUERY SELECT false, false, false, false, false, false, false, false, false;
    RETURN;
  END IF;

  v_shop_allows_negotiate := v_shop_type = 'vendor_catalog';

  RETURN QUERY
  SELECT
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_browse, profile.default_can_browse, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE public.resolve_shop_can_see_buy_price(
          v_shop_type,
          access.can_see_buy_price,
          access.can_see_sell_price,
          profile.default_can_see_buy_price,
          profile.default_can_see_sell_price
        )
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE CASE
          WHEN v_shop_type = 'dropship' THEN true
          ELSE coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, true)
        END
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_see_resell_minimum_price, profile.default_can_see_resell_minimum_price, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_place_order, profile.default_can_place_order, true)
      END,
      true
    ),
    coalesce(
      (
        CASE
          WHEN access.id IS NOT NULL AND access.status = false THEN false
          WHEN coalesce(profile.is_active, true) = false THEN false
          ELSE coalesce(access.can_negotiate, profile.default_can_negotiate, false)
        END
      ) AND v_shop_allows_negotiate,
      false
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE coalesce(access.can_view_quantity, profile.default_can_view_quantity, true)
      END,
      true
    ),
    coalesce(
      CASE
        WHEN access.id IS NOT NULL AND access.status = false THEN false
        WHEN coalesce(profile.is_active, true) = false THEN false
        ELSE CASE
          WHEN v_shop_type = 'dropship' THEN true
          ELSE coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, true)
        END
      END,
      true
    )
  FROM public.customer_groups cg
  LEFT JOIN public.shop_customer_group_access access
    ON access.customer_group_id = cg.id
   AND access.shop_id = p_shop_id
  LEFT JOIN public.customer_group_shop_profiles profile
    ON profile.customer_group_id = cg.id
   AND profile.tenant_id = v_tenant_id
  WHERE cg.id = p_customer_group_id
    AND cg.is_active = true
    AND cg.deleted_at IS NULL
    AND coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_tenant_id);
END;
$$;

ALTER FUNCTION public.get_shop_permissions_for_customer_group(bigint, bigint) OWNER TO postgres;
