CREATE FUNCTION public.upsert_shop_product_listing (
  p_tenant_id                      bigint,
  p_shop_id                        bigint,
  p_global_stock_allocation_id     bigint  DEFAULT NULL::bigint,
  p_sell_price_amount              numeric DEFAULT NULL::numeric,
  p_sell_price_currency_id         bigint  DEFAULT NULL::bigint,
  p_minimum_sell_price_amount      numeric DEFAULT NULL::numeric,
  p_minimum_sell_price_currency_id bigint  DEFAULT NULL::bigint,
  p_show_quantity                  boolean DEFAULT NULL::boolean,
  p_display_quantity_override      integer DEFAULT NULL::integer,
  p_is_active                      boolean DEFAULT NULL::boolean,
  p_id                             bigint  DEFAULT NULL::bigint,
  p_is_price_locked                boolean DEFAULT NULL::boolean,
  p_is_quantity_locked             boolean DEFAULT NULL::boolean,
  p_quantity_override_type         text    DEFAULT NULL::text,
  p_global_stock_id                bigint  DEFAULT NULL::bigint,
  p_product_id                     bigint  DEFAULT NULL::bigint
)
  RETURNS SETOF public.shop_product_listings
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_product_id bigint;
  v_target_stock_id bigint;
  v_grade_tag_id bigint;
  v_standard_grade_tag_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
  v_default_sell_amount numeric;
BEGIN
  v_standard_grade_tag_id := public.default_stock_grade_tag_id();

  IF NOT public.user_can_manage_shop_tenant(p_tenant_id)
     AND NOT public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     AND NOT public.is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;

    IF v_existing.id IS NULL THEN
      RAISE EXCEPTION 'listing not found';
    END IF;

    IF v_existing.global_stock_id IS NULL
       AND coalesce(v_existing.grade_tag_id, v_standard_grade_tag_id) = v_standard_grade_tag_id THEN
      v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
      v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
      v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

      RETURN QUERY
      UPDATE public.shop_product_listings
      SET
        grade_tag_id = coalesce(grade_tag_id, v_standard_grade_tag_id),
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        updated_at = now()
      WHERE id = v_existing.id
      RETURNING *;
      RETURN;
    END IF;
  END IF;

  v_target_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id, v_existing.global_stock_id);

  IF v_target_stock_id IS NOT NULL THEN
    SELECT gsi.product_id, coalesce(gs.grade_tag_id, v_standard_grade_tag_id)
    INTO v_product_id, v_grade_tag_id
    FROM public.global_stocks gs
    JOIN public.global_shipment_items gsi ON gsi.id = gs.shipment_item_id
    WHERE gs.id = v_target_stock_id;

    IF v_product_id IS NULL THEN
      RAISE EXCEPTION 'global stock not found';
    END IF;

    IF p_id IS NOT NULL THEN
      SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;
    ELSE
      SELECT * INTO v_existing
      FROM public.shop_product_listings
      WHERE shop_id = p_shop_id
        AND product_id = v_product_id
        AND grade_tag_id = v_grade_tag_id;
    END IF;

    v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
    v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
    v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

    IF v_existing.id IS NOT NULL THEN
      RETURN QUERY
      UPDATE public.shop_product_listings
      SET
        sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
        sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
        minimum_sell_price_amount = p_minimum_sell_price_amount,
        minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
        show_quantity = coalesce(p_show_quantity, show_quantity),
        display_quantity_override = p_display_quantity_override,
        is_active = coalesce(p_is_active, is_active),
        is_price_locked = v_price_locked,
        is_quantity_locked = v_qty_locked,
        quantity_override_type = v_override_type,
        grade_tag_id = coalesce(grade_tag_id, v_grade_tag_id),
        global_stock_allocation_id = NULL,
        updated_at = now()
      WHERE id = v_existing.id
      RETURNING *;
      RETURN;
    END IF;

    RETURN QUERY
    INSERT INTO public.shop_product_listings (
      tenant_id, shop_id, global_stock_allocation_id, global_stock_id, product_id,
      grade_tag_id, sell_price_amount, sell_price_currency_id,
      minimum_sell_price_amount, minimum_sell_price_currency_id,
      show_quantity, display_quantity_override, is_active,
      is_price_locked, is_quantity_locked, quantity_override_type
    ) VALUES (
      p_tenant_id, p_shop_id, NULL, NULL, v_product_id,
      v_grade_tag_id, p_sell_price_amount, p_sell_price_currency_id,
      p_minimum_sell_price_amount, p_minimum_sell_price_currency_id,
      p_show_quantity, p_display_quantity_override, coalesce(p_is_active, true),
      v_price_locked, v_qty_locked, v_override_type
    )
    RETURNING *;
    RETURN;
  END IF;

  v_product_id := coalesce(p_product_id, v_existing.product_id);
  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'product or stock required';
  END IF;

  v_grade_tag_id := v_standard_grade_tag_id;

  SELECT p.id, coalesce(p.list_price_amount, p.reference_cost_amount, 0)::numeric
  INTO v_product_id, v_default_sell_amount
  FROM public.products p
  WHERE p.id = v_product_id;

  IF v_product_id IS NULL THEN
    RAISE EXCEPTION 'product not found';
  END IF;

  IF p_id IS NOT NULL THEN
    SELECT * INTO v_existing FROM public.shop_product_listings WHERE id = p_id;
  ELSE
    SELECT * INTO v_existing
    FROM public.shop_product_listings
    WHERE shop_id = p_shop_id
      AND product_id = v_product_id
      AND coalesce(grade_tag_id, v_standard_grade_tag_id) = v_standard_grade_tag_id
      AND global_stock_id IS NULL;
  END IF;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  IF v_existing.id IS NOT NULL THEN
    RETURN QUERY
    UPDATE public.shop_product_listings
    SET
      grade_tag_id = coalesce(grade_tag_id, v_standard_grade_tag_id),
      sell_price_amount = coalesce(p_sell_price_amount, sell_price_amount),
      sell_price_currency_id = coalesce(p_sell_price_currency_id, sell_price_currency_id),
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = coalesce(p_show_quantity, show_quantity),
      display_quantity_override = p_display_quantity_override,
      is_active = coalesce(p_is_active, is_active),
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      updated_at = now()
    WHERE id = v_existing.id
    RETURNING *;
    RETURN;
  END IF;

  RETURN QUERY
  INSERT INTO public.shop_product_listings (
    tenant_id, shop_id, global_stock_allocation_id, global_stock_id, product_id,
    grade_tag_id, sell_price_amount, sell_price_currency_id,
    minimum_sell_price_amount, minimum_sell_price_currency_id,
    show_quantity, display_quantity_override, is_active,
    is_price_locked, is_quantity_locked, quantity_override_type
  ) VALUES (
    p_tenant_id, p_shop_id, NULL, NULL, v_product_id,
    v_standard_grade_tag_id, coalesce(p_sell_price_amount, v_default_sell_amount, 0), p_sell_price_currency_id,
    p_minimum_sell_price_amount, p_minimum_sell_price_currency_id,
    coalesce(p_show_quantity, true), p_display_quantity_override, coalesce(p_is_active, false),
    v_price_locked, v_qty_locked, v_override_type
  )
  RETURNING *;
END;
$function$;

CREATE FUNCTION public.upsert_shop_product_listing (
  p_tenant_id                      bigint,
  p_shop_id                        bigint,
  p_global_stock_allocation_id     bigint  DEFAULT NULL::bigint,
  p_sell_price_amount              numeric DEFAULT NULL::numeric,
  p_sell_price_currency_id         bigint  DEFAULT NULL::bigint,
  p_minimum_sell_price_amount      numeric DEFAULT NULL::numeric,
  p_minimum_sell_price_currency_id bigint  DEFAULT NULL::bigint,
  p_show_quantity                  boolean DEFAULT NULL::boolean,
  p_display_quantity_override      integer DEFAULT NULL::integer,
  p_is_active                      boolean DEFAULT true,
  p_id                             bigint  DEFAULT NULL::bigint,
  p_is_price_locked                boolean DEFAULT NULL::boolean,
  p_is_quantity_locked             boolean DEFAULT NULL::boolean,
  p_quantity_override_type         text    DEFAULT NULL::text,
  p_global_stock_id                bigint  DEFAULT NULL::bigint
)
  RETURNS SETOF public.shop_product_listings
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_product_id bigint;
  v_target_stock_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id)
     and not public.user_can_manage_shop_tenant(public.resolve_parent_tenant_id(p_tenant_id))
     and not public.is_superadmin() then
    raise exception 'not allowed';
  end if;

  v_target_stock_id := coalesce(p_global_stock_id, p_global_stock_allocation_id);

  if v_target_stock_id is null then
    raise exception 'global stock not found';
  end if;

  select gsi.product_id into v_product_id
  from public.global_stocks gs
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gs.id = v_target_stock_id;

  if v_product_id is null then
    raise exception 'global stock not found';
  end if;

  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;
  else
    select * into v_existing from public.shop_product_listings
    where shop_id = p_shop_id and global_stock_id = v_target_stock_id;
  end if;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  if v_existing.id is not null then
    return query
    update public.shop_product_listings
    set
      sell_price_amount = p_sell_price_amount,
      sell_price_currency_id = p_sell_price_currency_id,
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = coalesce(p_show_quantity, show_quantity),
      display_quantity_override = p_display_quantity_override,
      is_active = coalesce(p_is_active, true),
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      global_stock_allocation_id = null,
      updated_at = now()
    where id = v_existing.id
    returning *;
    return;
  end if;

  return query
  insert into public.shop_product_listings (
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active,
    is_price_locked,
    is_quantity_locked,
    quantity_override_type
  ) values (
    p_tenant_id,
    p_shop_id,
    null,
    v_target_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    coalesce(p_is_active, true),
    v_price_locked,
    v_qty_locked,
    v_override_type
  )
  returning *;
end;
$function$;

CREATE FUNCTION public.upsert_shop_product_listing (
  p_tenant_id                      bigint,
  p_shop_id                        bigint,
  p_global_stock_allocation_id     bigint,
  p_sell_price_amount              numeric,
  p_sell_price_currency_id         bigint,
  p_minimum_sell_price_amount      numeric DEFAULT NULL::numeric,
  p_minimum_sell_price_currency_id bigint  DEFAULT NULL::bigint,
  p_show_quantity                  boolean DEFAULT NULL::boolean,
  p_display_quantity_override      integer DEFAULT NULL::integer,
  p_is_active                      boolean DEFAULT true,
  p_id                             bigint  DEFAULT NULL::bigint,
  p_is_price_locked                boolean DEFAULT NULL::boolean,
  p_is_quantity_locked             boolean DEFAULT NULL::boolean,
  p_quantity_override_type         text    DEFAULT NULL::text
)
  RETURNS SETOF public.shop_product_listings
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_product_id bigint;
  v_global_stock_id bigint;
  v_existing record;
  v_price_locked boolean;
  v_qty_locked boolean;
  v_override_type text;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Resolve stock & product id from allocation by joining global_stocks and global_shipment_items
  select gsa.stock_id, gsi.product_id
  into v_global_stock_id, v_product_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gsa.id = p_global_stock_allocation_id;

  if v_global_stock_id is null then
    raise exception 'allocation not found';
  end if;

  if p_id is not null then
    select * into v_existing from public.shop_product_listings where id = p_id;
  else
    select * into v_existing from public.shop_product_listings
    where shop_id = p_shop_id and global_stock_allocation_id = p_global_stock_allocation_id;
  end if;

  v_price_locked := coalesce(p_is_price_locked, v_existing.is_price_locked, false);
  v_qty_locked := coalesce(p_is_quantity_locked, v_existing.is_quantity_locked, false);
  v_override_type := coalesce(p_quantity_override_type, v_existing.quantity_override_type, 'absolute');

  if v_existing.id is not null then
    return query
    update public.shop_product_listings
    set
      sell_price_amount = p_sell_price_amount,
      sell_price_currency_id = p_sell_price_currency_id,
      minimum_sell_price_amount = p_minimum_sell_price_amount,
      minimum_sell_price_currency_id = p_minimum_sell_price_currency_id,
      show_quantity = p_show_quantity,
      display_quantity_override = p_display_quantity_override,
      is_active = p_is_active,
      is_price_locked = v_price_locked,
      is_quantity_locked = v_qty_locked,
      quantity_override_type = v_override_type,
      updated_at = now()
    where id = v_existing.id
    returning *;
  else
    return query
    insert into public.shop_product_listings (
      tenant_id,
      shop_id,
      global_stock_allocation_id,
      global_stock_id,
      product_id,
      sell_price_amount,
      sell_price_currency_id,
      minimum_sell_price_amount,
      minimum_sell_price_currency_id,
      show_quantity,
      display_quantity_override,
      is_active,
      is_price_locked,
      is_quantity_locked,
      quantity_override_type
    )
    values (
      p_tenant_id,
      p_shop_id,
      p_global_stock_allocation_id,
      v_global_stock_id,
      v_product_id,
      p_sell_price_amount,
      p_sell_price_currency_id,
      p_minimum_sell_price_amount,
      p_minimum_sell_price_currency_id,
      p_show_quantity,
      p_display_quantity_override,
      p_is_active,
      v_price_locked,
      v_qty_locked,
      v_override_type
    )
    returning *;
  end if;
end;
$function$;

CREATE FUNCTION public.upsert_shop_product_listing (
  p_tenant_id                      bigint,
  p_shop_id                        bigint,
  p_global_stock_allocation_id     bigint,
  p_sell_price_amount              numeric,
  p_sell_price_currency_id         bigint,
  p_minimum_sell_price_amount      numeric DEFAULT NULL::numeric,
  p_minimum_sell_price_currency_id bigint  DEFAULT NULL::bigint,
  p_show_quantity                  boolean DEFAULT NULL::boolean,
  p_display_quantity_override      integer DEFAULT NULL::integer,
  p_is_active                      boolean DEFAULT true,
  p_id                             bigint  DEFAULT NULL::bigint
)
  RETURNS SETOF public.shop_product_listings
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_global_stock_id bigint;
  v_product_id bigint;
begin
  -- Caller must be admin/staff of this tenant
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Resolve denormalized IDs
  select gsa.stock_id, gsi.product_id
  into v_global_stock_id, v_product_id
  from public.global_stock_allocations gsa
  join public.global_stocks gs on gs.id = gsa.stock_id
  join public.global_shipment_items gsi on gsi.id = gs.shipment_item_id
  where gsa.id = p_global_stock_allocation_id;

  if v_global_stock_id is null or v_product_id is null then
    raise exception 'invalid global stock allocation';
  end if;

  -- Dropship dual money constraint
  if (p_minimum_sell_price_amount is null) <> (p_minimum_sell_price_currency_id is null) then
    raise exception 'both minimum_sell_price_amount and minimum_sell_price_currency_id must be provided together or be null';
  end if;

  return query
  insert into public.shop_product_listings (
    id,
    tenant_id,
    shop_id,
    global_stock_allocation_id,
    global_stock_id,
    product_id,
    sell_price_amount,
    sell_price_currency_id,
    minimum_sell_price_amount,
    minimum_sell_price_currency_id,
    show_quantity,
    display_quantity_override,
    is_active
  )
  overriding system value
  values (
    coalesce(p_id, nextval(pg_get_serial_sequence('public.shop_product_listings', 'id'))),
    p_tenant_id,
    p_shop_id,
    p_global_stock_allocation_id,
    v_global_stock_id,
    v_product_id,
    p_sell_price_amount,
    p_sell_price_currency_id,
    p_minimum_sell_price_amount,
    p_minimum_sell_price_currency_id,
    p_show_quantity,
    p_display_quantity_override,
    p_is_active
  )
  on conflict (shop_id, global_stock_allocation_id) do update set
    sell_price_amount = excluded.sell_price_amount,
    sell_price_currency_id = excluded.sell_price_currency_id,
    minimum_sell_price_amount = excluded.minimum_sell_price_amount,
    minimum_sell_price_currency_id = excluded.minimum_sell_price_currency_id,
    show_quantity = excluded.show_quantity,
    display_quantity_override = excluded.display_quantity_override,
    is_active = excluded.is_active,
    updated_at = now()
  returning *;
end;
$function$;

GRANT ALL ON FUNCTION
  public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION
  public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint, bigint) TO
  authenticated;

GRANT ALL ON FUNCTION
  public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint, bigint) TO
  service_role;

GRANT ALL ON FUNCTION
  public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint) TO anon;

GRANT ALL ON FUNCTION
  public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint) TO authenticated;

GRANT ALL ON FUNCTION
  public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text, bigint) TO service_role;

GRANT ALL ON FUNCTION public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text) TO
  anon;

GRANT ALL ON FUNCTION public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text) TO
  authenticated;

GRANT ALL ON FUNCTION public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint, boolean, boolean, text) TO
  service_role;

GRANT ALL ON FUNCTION public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint) TO anon;

GRANT ALL ON FUNCTION public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_shop_product_listing(bigint, bigint, bigint, numeric, bigint, numeric, bigint, boolean, integer, boolean, bigint) TO service_role;