-- shops.parent_tenant_id was removed in 20261105214000; manual catalog assert still referenced v_shop.parent_tenant_id.

CREATE OR REPLACE FUNCTION public.assert_staff_can_place_catalog_order_on_behalf (
  p_shop_id           bigint,
  p_customer_group_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_shop public.shops%rowtype;
BEGIN
  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = p_shop_id
    AND is_active = true
    AND deleted_at IS NULL;

  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  IF v_shop.shop_type <> 'vendor_catalog' THEN
    RAISE EXCEPTION 'shop is not vendor catalog';
  END IF;

  IF NOT public.membership_has_module_action(v_shop.tenant_id, 'shop_order_mgmt', 'edit')
     AND NOT public.membership_has_module_action(
       public.resolve_parent_tenant_id(v_shop.tenant_id), 'shop_order_mgmt', 'edit'
     )
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.customer_groups cg
    WHERE cg.id = p_customer_group_id
      AND cg.is_active = true
      AND cg.deleted_at IS NULL
      AND coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_shop.tenant_id)
  ) THEN
    RAISE EXCEPTION 'customer group not found';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_staff_can_place_dropship_order_on_behalf (
  p_shop_id           bigint,
  p_customer_group_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_shop public.shops%rowtype;
BEGIN
  SELECT * INTO v_shop
  FROM public.shops
  WHERE id = p_shop_id
    AND is_active = true
    AND deleted_at IS NULL;

  IF v_shop.id IS NULL THEN
    RAISE EXCEPTION 'shop not found or inactive';
  END IF;

  IF v_shop.shop_type <> 'dropship' THEN
    RAISE EXCEPTION 'shop is not dropship';
  END IF;

  IF NOT public.membership_has_module_action(v_shop.tenant_id, 'shop_order_mgmt', 'edit')
     AND NOT public.membership_has_module_action(
       public.resolve_parent_tenant_id(v_shop.tenant_id), 'shop_order_mgmt', 'edit'
     )
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.customer_groups cg
    WHERE cg.id = p_customer_group_id
      AND cg.is_active = true
      AND cg.deleted_at IS NULL
      AND coalesce(cg.parent_tenant_id, cg.tenant_id) = public.resolve_parent_tenant_id(v_shop.tenant_id)
  ) THEN
    RAISE EXCEPTION 'customer group not found';
  END IF;
END;
$function$;
