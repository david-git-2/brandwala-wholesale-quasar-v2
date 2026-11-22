-- BP3 dropped resolve_billing_profile_for_customer_group; these RPCs still referenced it.

CREATE OR REPLACE FUNCTION public.get_dropship_shop_readiness(p_shop_id bigint)
RETURNS TABLE (
  shop_id bigint,
  has_access_group_with_price boolean,
  has_customer_group_with_members boolean,
  has_billing_profile_linked boolean,
  has_listing_with_floor boolean,
  has_active_courier boolean,
  ready boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id bigint;
  v_shop_type public.shop_type_enum;

  v_has_access_group_with_price boolean := false;
  v_has_customer_group_with_members boolean := false;
  v_has_billing_profile_linked boolean := false;
  v_has_listing_with_floor boolean := false;
  v_has_active_courier boolean := false;
  v_ready boolean := false;
BEGIN
  SELECT s.tenant_id, s.shop_type
  INTO v_tenant_id, v_shop_type
  FROM public.shops s
  WHERE s.id = p_shop_id;

  IF v_tenant_id IS NULL THEN
    RETURN;
  END IF;

  SELECT coalesce(bool_or(
    access.status = true
    AND coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false) = true
  ), false)
  INTO v_has_access_group_with_price
  FROM public.shop_customer_group_access access
  LEFT JOIN public.customer_group_shop_profiles profile
    ON profile.customer_group_id = access.customer_group_id
   AND profile.tenant_id = v_tenant_id
  WHERE access.shop_id = p_shop_id;

  SELECT exists (
    SELECT 1
    FROM public.shop_customer_group_access access
    JOIN public.customer_group_members cgm ON cgm.customer_group_id = access.customer_group_id
    WHERE access.shop_id = p_shop_id
      AND access.status = true
  )
  INTO v_has_customer_group_with_members;

  SELECT exists (
    SELECT 1
    FROM public.shop_customer_group_access access
    WHERE access.shop_id = p_shop_id
      AND access.status = true
      AND public.resolve_customer_profile_for_group(v_tenant_id, access.customer_group_id) IS NOT NULL
  )
  INTO v_has_billing_profile_linked;

  SELECT exists (
    SELECT 1
    FROM public.shop_product_listings spl
    WHERE spl.shop_id = p_shop_id
      AND spl.is_active = true
      AND spl.minimum_sell_price_amount IS NOT NULL
      AND spl.minimum_sell_price_amount > 0
  )
  INTO v_has_listing_with_floor;

  SELECT exists (
    SELECT 1
    FROM public.courier_services cs
    WHERE cs.tenant_id = v_tenant_id
      AND cs.is_active = true
  )
  INTO v_has_active_courier;

  v_ready := (
    v_has_access_group_with_price
    AND v_has_customer_group_with_members
    AND v_has_billing_profile_linked
    AND v_has_listing_with_floor
    AND v_has_active_courier
  );

  RETURN QUERY
  SELECT
    p_shop_id,
    v_has_access_group_with_price,
    v_has_customer_group_with_members,
    v_has_billing_profile_linked,
    v_has_listing_with_floor,
    v_has_active_courier,
    v_ready;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_my_dropship_wallet_ledger(
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  id text,
  created_at timestamp with time zone,
  transaction_type text,
  amount numeric,
  balance_after numeric,
  source_id text,
  order_id bigint,
  note text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $_$
DECLARE
  v_email text := public.current_user_email();
  v_tenant_id bigint;
  v_group_id bigint;
  v_profile_id bigint;
BEGIN
  IF v_email IS NULL OR length(trim(v_email)) = 0 THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  SELECT cg.tenant_id, cgm.customer_group_id
  INTO v_tenant_id, v_group_id
  FROM public.customer_group_members cgm
  JOIN public.customer_groups cg ON cg.id = cgm.customer_group_id
  WHERE lower(trim(cgm.email)) = lower(trim(v_email))
    AND cgm.is_active = true
    AND cg.is_active = true
  ORDER BY cgm.id
  LIMIT 1;

  IF v_tenant_id IS NULL THEN
    RAISE EXCEPTION 'No active customer group membership';
  END IF;

  v_profile_id := public.resolve_customer_profile_for_group(v_tenant_id, v_group_id);
  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'No customer profile linked for your customer group';
  END IF;

  RETURN QUERY
  SELECT
    u.id::text,
    u.created_at,
    coalesce(u.metadata->>'transaction_type', u.metadata->>'purpose', u.type)::text AS transaction_type,
    CASE WHEN u.type = 'debit' THEN -u.amount ELSE u.amount END,
    u.balance_after,
    u.source_id,
    CASE
      WHEN u.source_type = 'shop_order' AND u.source_id ~ '^[0-9]+$' THEN u.source_id::bigint
      ELSE NULL
    END AS order_id,
    coalesce(u.metadata->>'notes', u.metadata->>'note', '')::text AS note
  FROM public.cashbook_entries u
  WHERE u.tenant_id = v_tenant_id
    AND u.entity_id = v_profile_id
    AND u.entity_type IN ('middleman', 'customer')
  ORDER BY u.created_at DESC, u.id DESC
  LIMIT greatest(coalesce(p_limit, 50), 1)
  OFFSET greatest(coalesce(p_offset, 0), 0);
END;
$_$;