-- customer_groups.parent_tenant_id was dropped in 20261105215000.
-- trg_fn_assign_default_customer_role was never updated; later migrations reintroduced cg.parent_tenant_id in asserts.

CREATE OR REPLACE FUNCTION public.trg_fn_assign_default_customer_role()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_tenant_id bigint;
  v_role_slug text;
  v_role_id bigint;
BEGIN
  IF new.tenant_role_id IS NULL AND new.customer_group_id IS NOT NULL AND new.role IS NOT NULL THEN
    SELECT cg.tenant_id
    INTO v_tenant_id
    FROM public.customer_groups cg
    WHERE cg.id = new.customer_group_id;

    IF v_tenant_id IS NOT NULL THEN
      v_role_slug := CASE new.role
        WHEN 'admin' THEN 'customer-admin'
        WHEN 'manager' THEN 'manager'
        WHEN 'staff' THEN 'customer-staff'
        ELSE 'customer-staff'
      END;

      SELECT tr.id
      INTO v_role_id
      FROM public.tenant_roles tr
      WHERE tr.tenant_id = v_tenant_id
        AND tr.scope = 'shop'
        AND (tr.slug = v_role_slug OR (new.role = 'admin' AND tr.is_admin = true))
      ORDER BY tr.is_admin DESC, tr.id ASC
      LIMIT 1;

      new.tenant_role_id := v_role_id;
    END IF;
  END IF;

  RETURN new;
END;
$function$;

CREATE OR REPLACE FUNCTION public.can_manage_customer_group_member(p_customer_group_id bigint)
  RETURNS boolean
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.customer_groups cg
    WHERE cg.id = p_customer_group_id
      AND public.can_manage_customer_group(cg.tenant_id)
  );
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_cgm_permission_guardrails()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_role_scope text;
  v_role_books bigint;
  v_cg_books bigint;
BEGIN
  IF new.tenant_role_id IS NOT NULL THEN
    SELECT tr.scope, public.resolve_parent_tenant_id(tr.tenant_id)
    INTO v_role_scope, v_role_books
    FROM public.tenant_roles tr
    WHERE tr.id = new.tenant_role_id;

    SELECT public.resolve_parent_tenant_id(cg.tenant_id)
    INTO v_cg_books
    FROM public.customer_groups cg
    WHERE cg.id = new.customer_group_id;

    IF v_role_books IS DISTINCT FROM v_cg_books THEN
      RAISE EXCEPTION 'Cross-tenant role assignment is not allowed';
    END IF;

    IF v_role_scope IS DISTINCT FROM 'shop' THEN
      RAISE EXCEPTION 'Scope mismatch: customer group member cannot be assigned a % scoped role', v_role_scope;
    END IF;
  END IF;

  RETURN new;
END;
$function$;

CREATE OR REPLACE FUNCTION public.trg_fn_sync_cgm_tenant_role()
  RETURNS trigger
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_tenant_id bigint;
  v_target_slug text;
  v_role_id bigint;
  v_role_books bigint;
  v_cg_books bigint;
BEGIN
  IF new.tenant_role_id IS NOT NULL THEN
    SELECT public.resolve_parent_tenant_id(tr.tenant_id)
    INTO v_role_books
    FROM public.tenant_roles tr
    WHERE tr.id = new.tenant_role_id;

    SELECT public.resolve_parent_tenant_id(cg.tenant_id)
    INTO v_cg_books
    FROM public.customer_groups cg
    WHERE cg.id = new.customer_group_id;

    IF v_role_books IS NOT DISTINCT FROM v_cg_books
       AND NOT (tg_op = 'UPDATE' AND old.role IS DISTINCT FROM new.role) THEN
      RETURN new;
    END IF;
  END IF;

  IF new.tenant_role_id IS NULL OR (tg_op = 'UPDATE' AND old.role IS DISTINCT FROM new.role) THEN
    SELECT cg.tenant_id
    INTO v_tenant_id
    FROM public.customer_groups cg
    WHERE cg.id = new.customer_group_id;

    IF v_tenant_id IS NOT NULL THEN
      v_target_slug := CASE new.role
        WHEN 'admin' THEN 'customer-admin'
        WHEN 'manager' THEN 'manager'
        WHEN 'staff' THEN 'customer-staff'
        ELSE 'customer-staff'
      END;

      SELECT tr.id
      INTO v_role_id
      FROM public.tenant_roles tr
      WHERE tr.tenant_id = v_tenant_id
        AND tr.scope = 'shop'
        AND (tr.slug = v_target_slug OR (new.role = 'admin' AND tr.is_admin = true))
      ORDER BY tr.is_admin DESC, tr.id ASC
      LIMIT 1;

      IF v_role_id IS NOT NULL THEN
        new.tenant_role_id := v_role_id;
      END IF;
    END IF;
  END IF;

  RETURN new;
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_staff_can_place_catalog_order_on_behalf(
  p_shop_id bigint,
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
      AND cg.tenant_id = public.resolve_parent_tenant_id(v_shop.tenant_id)
  ) THEN
    RAISE EXCEPTION 'customer group not found';
  END IF;
END;
$function$;

CREATE OR REPLACE FUNCTION public.assert_staff_can_place_dropship_order_on_behalf(
  p_shop_id bigint,
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
      AND cg.tenant_id = public.resolve_parent_tenant_id(v_shop.tenant_id)
  ) THEN
    RAISE EXCEPTION 'customer group not found';
  END IF;
END;
$function$;