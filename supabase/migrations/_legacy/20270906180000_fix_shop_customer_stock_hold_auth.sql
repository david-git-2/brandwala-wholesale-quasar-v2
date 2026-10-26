-- Shop customers placing dropship/fixed-price orders need stock hold auth on parent pool.

CREATE OR REPLACE FUNCTION public.can_act_on_parent_tenant_stock(p_parent_tenant_id bigint)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    public.has_active_tenant_membership(p_parent_tenant_id)
    OR public.is_superadmin()
    OR EXISTS (
      SELECT 1
      FROM public.memberships m
      INNER JOIN public.tenants t ON t.id = m.tenant_id
      WHERE t.parent_id = p_parent_tenant_id
        AND lower(trim(m.email)) = public.current_user_email()
        AND m.is_active = TRUE
    )
    OR EXISTS (
      SELECT 1
      FROM public.customer_group_members cgm
      INNER JOIN public.customer_groups cg ON cg.id = cgm.customer_group_id
      INNER JOIN public.shop_customer_group_access scga ON scga.customer_group_id = cg.id
      INNER JOIN public.shops s ON s.id = scga.shop_id
      WHERE public.resolve_parent_tenant_id(s.tenant_id) = p_parent_tenant_id
        AND cg.tenant_id = s.tenant_id
        AND lower(trim(cgm.email)) = public.current_user_email()
        AND cgm.is_active = TRUE
        AND cg.is_active = TRUE
        AND scga.status = TRUE
        AND s.is_active = TRUE
        AND s.deleted_at IS NULL
    )
    OR EXISTS (
      SELECT 1
      FROM public.shops s
      JOIN LATERAL public.get_shop_permissions_for_customer(s.id) perms ON TRUE
      WHERE public.resolve_parent_tenant_id(s.tenant_id) = p_parent_tenant_id
        AND s.is_active = TRUE
        AND s.deleted_at IS NULL
        AND COALESCE(perms.can_place_order, FALSE)
    );
$$;

CREATE OR REPLACE FUNCTION public.create_and_post_stock_movement(
  p_tenant_id bigint,
  p_stock_id bigint,
  p_quantity integer,
  p_to_location_id bigint DEFAULT NULL,
  p_to_availability public.stock_availability DEFAULT NULL,
  p_to_grade_tag_id bigint DEFAULT NULL,
  p_movement_type public.stock_movement_type DEFAULT 'grade_change',
  p_notes text DEFAULT NULL,
  p_reference_type text DEFAULT NULL,
  p_reference_id text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_stock public.global_stocks%rowtype;
  v_mov_id bigint;
  v_mov_no text;
  v_is_customer_return boolean;
  v_shop_order_authorized boolean := FALSE;
BEGIN
  IF coalesce(p_reference_type, '') = 'shop_order'
     AND p_reference_id ~ '^[0-9]+$' THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.shop_orders o
      JOIN public.shops s ON s.id = o.shop_id
      WHERE o.id = p_reference_id::bigint
        AND public.resolve_parent_tenant_id(coalesce(s.tenant_id, o.tenant_id)) = p_tenant_id
        AND (
          public.is_cart_owner(o.customer_group_id, o.tenant_id)
          OR public.has_active_tenant_membership(o.tenant_id)
          OR public.has_active_tenant_membership(public.resolve_parent_tenant_id(o.tenant_id))
          OR public.is_superadmin()
        )
    ) INTO v_shop_order_authorized;
  END IF;

  IF NOT public.can_act_on_parent_tenant_stock(p_tenant_id)
     AND NOT v_shop_order_authorized THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT * INTO v_stock
  FROM public.global_stocks
  WHERE id = p_stock_id
    AND parent_tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT found THEN
    RAISE EXCEPTION 'stock % not found', p_stock_id;
  END IF;

  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'quantity must be > 0';
  END IF;

  v_is_customer_return := (
    p_movement_type = 'return_inbound'::public.stock_movement_type
    AND coalesce(p_reference_type, '') IS DISTINCT FROM 'shipment_return'
  );

  IF NOT v_is_customer_return AND v_stock.quantity < p_quantity THEN
    RAISE EXCEPTION 'insufficient stock quantity (requested %, available %)', p_quantity, v_stock.quantity;
  END IF;

  v_mov_no := 'MOV-' || to_char(now(), 'YYYYMMDD') || '-' || lpad(nextval('public.stock_movements_id_seq')::text, 6, '0');

  INSERT INTO public.stock_movements (
    tenant_id,
    movement_no,
    movement_type,
    reference_type,
    reference_id,
    notes,
    created_by_email,
    is_posted,
    posted_at
  ) VALUES (
    p_tenant_id,
    v_mov_no,
    p_movement_type,
    coalesce(p_reference_type, 'global_stock'),
    coalesce(p_reference_id, p_stock_id::text),
    p_notes,
    public.current_user_email(),
    FALSE,
    NULL
  )
  RETURNING id INTO v_mov_id;

  INSERT INTO public.stock_movement_lines (
    movement_id,
    stock_id,
    quantity,
    from_location_id,
    to_location_id,
    from_availability,
    to_availability,
    from_grade_tag_id,
    to_grade_tag_id
  ) VALUES (
    v_mov_id,
    p_stock_id,
    p_quantity,
    v_stock.location_id,
    CASE
      WHEN v_is_customer_return THEN coalesce(
        p_to_location_id,
        public.default_returns_stock_location_id(p_tenant_id)
      )
      ELSE coalesce(p_to_location_id, v_stock.location_id)
    END,
    v_stock.availability,
    CASE
      WHEN v_is_customer_return THEN coalesce(p_to_availability, 'held'::public.stock_availability)
      ELSE coalesce(p_to_availability, v_stock.availability)
    END,
    v_stock.grade_tag_id,
    coalesce(p_to_grade_tag_id, v_stock.grade_tag_id, public.default_stock_grade_tag_id())
  );

  PERFORM public.post_stock_movement(v_mov_id);

  RETURN jsonb_build_object(
    'success', TRUE,
    'movement_id', v_mov_id,
    'movement_no', v_mov_no
  );
END;
$$;
