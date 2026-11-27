-- Unified staff fulfillment: lifecycle values on placement_status; status derived server-side.

ALTER TABLE public.pp_order_lines
    DROP CONSTRAINT IF EXISTS pp_order_lines_placement_status_check;

UPDATE public.pp_order_lines
SET placement_status = 'draft'
WHERE placement_status = 'none' AND status = 'draft';

UPDATE public.pp_order_lines
SET placement_status = 'requested'
WHERE placement_status = 'none' AND status = 'requested';

UPDATE public.pp_order_lines
SET placement_status = 'processing'
WHERE placement_status = 'none' AND status = 'processing';

UPDATE public.pp_order_lines
SET placement_status = 'delivered'
WHERE placement_status = 'none' AND status = 'done';

UPDATE public.pp_order_lines
SET placement_status = 'cancelled'
WHERE placement_status = 'none' AND status = 'cancelled';

UPDATE public.pp_order_lines
SET placement_status = 'requested'
WHERE placement_status = 'none';

ALTER TABLE public.pp_order_lines
    ADD CONSTRAINT pp_order_lines_placement_status_check CHECK (
        placement_status = ANY (
            ARRAY[
                'none'::text,
                'draft'::text,
                'requested'::text,
                'processing'::text,
                'cancelled'::text,
                'added_to_cart'::text,
                'order_placed'::text,
                'cargo_warehouse'::text,
                'in_flight'::text,
                'local_warehouse'::text,
                'delivered'::text,
                'lost'::text
            ]
        )
    );

CREATE OR REPLACE FUNCTION public.pp_derive_order_line_status_from_placement(p_placement text)
RETURNS text
    LANGUAGE sql
    IMMUTABLE
    AS $$
  SELECT CASE lower(trim(coalesce(p_placement, '')))
    WHEN 'draft' THEN 'draft'
    WHEN 'requested' THEN 'requested'
    WHEN 'none' THEN 'requested'
    WHEN 'processing' THEN 'processing'
    WHEN 'cancelled' THEN 'cancelled'
    WHEN 'delivered' THEN 'done'
    WHEN 'added_to_cart' THEN 'processing'
    WHEN 'order_placed' THEN 'processing'
    WHEN 'cargo_warehouse' THEN 'processing'
    WHEN 'in_flight' THEN 'processing'
    WHEN 'local_warehouse' THEN 'processing'
    WHEN 'lost' THEN 'processing'
    ELSE 'requested'
  END;
$$;

UPDATE public.pp_order_lines l
SET status = public.pp_derive_order_line_status_from_placement(l.placement_status);

DROP FUNCTION IF EXISTS public.update_pp_order_line_staff(
    bigint, bigint, text, numeric, text, text, text, numeric, bigint, bigint, boolean, text, numeric, text
);

CREATE OR REPLACE FUNCTION public.update_pp_order_line_staff(
    p_tenant_id bigint,
    p_line_id bigint,
    p_url text,
    p_needed_qty numeric,
    p_description text DEFAULT NULL::text,
    p_product_name text DEFAULT NULL::text,
    p_image_url text DEFAULT NULL::text,
    p_unit_price numeric DEFAULT NULL::numeric,
    p_pp_supplier_group_id bigint DEFAULT NULL::bigint,
    p_shipment_id bigint DEFAULT NULL::bigint,
    p_is_added_to_cart boolean DEFAULT NULL::boolean,
    p_placement_status text DEFAULT NULL::text,
    p_placed_qty numeric DEFAULT NULL::numeric
) RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path TO public
AS $$
DECLARE
  v_url text := trim(coalesce(p_url, ''));
  v_desc text := nullif(trim(coalesce(p_description, '')), '');
  v_product_name text := nullif(trim(coalesce(p_product_name, '')), '');
  v_image_url text := nullif(trim(coalesce(p_image_url, '')), '');
  v_qty numeric := p_needed_qty;
  v_row public.pp_order_lines%ROWTYPE;
  v_shipment_status text;
  v_placement text := lower(trim(coalesce(p_placement_status, '')));
  v_final_placement text;
  v_not_in_cart boolean;
BEGIN
  IF NOT public.has_active_tenant_membership(p_tenant_id) THEN
    RAISE EXCEPTION 'Not allowed for tenant %', p_tenant_id USING ERRCODE = '42501';
  END IF;

  IF length(v_url) = 0 THEN
    RAISE EXCEPTION 'URL is required' USING ERRCODE = '22023';
  END IF;

  IF v_qty IS NULL OR v_qty <= 0 THEN
    RAISE EXCEPTION 'Quantity must be positive' USING ERRCODE = '22023';
  END IF;

  IF v_placement <> '' AND v_placement NOT IN (
    'none', 'draft', 'requested', 'processing', 'cancelled',
    'added_to_cart', 'order_placed', 'cargo_warehouse',
    'in_flight', 'local_warehouse', 'delivered', 'lost'
  ) THEN
    RAISE EXCEPTION 'Invalid placement status: %', p_placement_status USING ERRCODE = '22023';
  END IF;

  IF p_pp_supplier_group_id IS NOT NULL THEN
    PERFORM 1
    FROM public.pp_people_group g
    WHERE g.id = p_pp_supplier_group_id
      AND g.tenant_id = p_tenant_id
      AND g.type = 'supplier'
      AND g.deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid supplier group' USING ERRCODE = '22023';
    END IF;
  END IF;

  IF p_shipment_id IS NOT NULL THEN
    PERFORM 1
    FROM public.pp_shipment sh
    WHERE sh.id = p_shipment_id
      AND sh.tenant_id = p_tenant_id
      AND sh.deleted_at IS NULL;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'Invalid shipment' USING ERRCODE = '22023';
    END IF;
  END IF;

  SELECT CASE WHEN v_placement = '' THEN l.placement_status ELSE v_placement END
  INTO v_final_placement
  FROM public.pp_order_lines l
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.deleted_at IS NULL;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  v_not_in_cart := v_final_placement IN ('none', 'draft', 'requested', 'processing', 'cancelled');

  UPDATE public.pp_order_lines l
  SET url = v_url,
      needed_qty = v_qty,
      description = v_desc,
      product_name = v_product_name,
      image_url = v_image_url,
      unit_price = p_unit_price,
      pp_supplier_group_id = p_pp_supplier_group_id,
      shipment_id = p_shipment_id,
      placement_status = v_final_placement,
      is_added_to_cart = CASE
        WHEN v_placement <> '' THEN NOT v_not_in_cart
        ELSE coalesce(p_is_added_to_cart, l.is_added_to_cart)
      END,
      added_to_cart_at = CASE
        WHEN v_not_in_cart THEN NULL
        WHEN v_placement <> '' AND NOT v_not_in_cart AND NOT l.is_added_to_cart THEN now()
        WHEN v_placement <> '' AND NOT v_not_in_cart THEN l.added_to_cart_at
        WHEN p_is_added_to_cart IS TRUE AND NOT l.is_added_to_cart THEN now()
        WHEN p_is_added_to_cart IS FALSE THEN NULL
        ELSE l.added_to_cart_at
      END,
      placed_qty = p_placed_qty,
      status = public.pp_derive_order_line_status_from_placement(v_final_placement),
      updated_at = now()
  WHERE l.id = p_line_id
    AND l.tenant_id = p_tenant_id
    AND l.deleted_at IS NULL
  RETURNING * INTO v_row;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order line not found' USING ERRCODE = 'P0002';
  END IF;

  SELECT s.status INTO v_shipment_status
  FROM public.pp_shipment s
  WHERE s.id = v_row.shipment_id
    AND s.deleted_at IS NULL;

  RETURN public._pp_order_line_to_json(v_row, v_shipment_status);
END;
$$;

GRANT ALL ON FUNCTION public.update_pp_order_line_staff(
    bigint, bigint, text, numeric, text, text, text, numeric, bigint, bigint, boolean, text, numeric
) TO anon, authenticated, service_role;