CREATE FUNCTION public.bulk_apply_shop_markup (
  p_shop_id           bigint,
  p_markup_percentage numeric  DEFAULT NULL::numeric,
  p_listing_ids       bigint[] DEFAULT NULL::bigint[]
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_markup numeric;
  v_count integer := 0;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Use provided markup or lookup from rule
  v_markup := p_markup_percentage;
  if v_markup is null then
    select markup_percentage into v_markup
    from public.shop_pricing_rules
    where shop_id = p_shop_id;
  end if;

  v_markup := coalesce(v_markup, 0.00);

  update public.shop_product_listings spl
  set
    sell_price_amount = round(
      coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) * (1 + (v_markup / 100.0)),
      2
    ),
    updated_at = now()
  where spl.shop_id = p_shop_id
    and (p_listing_ids is null or spl.id = any(p_listing_ids));

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

CREATE FUNCTION public.bulk_apply_shop_markup (
  p_shop_id       bigint,
  p_markup_amount numeric  DEFAULT NULL::numeric,
  p_markup_type   text     DEFAULT 'percentage'::text,
  p_target_price  text     DEFAULT 'sell_price'::text,
  p_listing_ids   bigint[] DEFAULT NULL::bigint[]
)
  RETURNS integer
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_amount numeric;
  v_count integer := 0;
begin
  select tenant_id into v_tenant_id from public.shops where id = p_shop_id;
  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_amount := p_markup_amount;
  if v_amount is null then
    select markup_percentage into v_amount
    from public.shop_pricing_rules
    where shop_id = p_shop_id;
  end if;

  v_amount := coalesce(v_amount, 0.00);

  if p_target_price = 'min_sell_price' then
    update public.shop_product_listings spl
    set
      minimum_sell_price_amount = case
        when p_markup_type = 'percentage' then
          round(coalesce(spl.minimum_sell_price_amount, 0.00) * (1 + (v_amount / 100.0)), 2)
        else
          round(coalesce(spl.minimum_sell_price_amount, 0.00) + v_amount, 2)
      end,
      updated_at = now()
    where spl.shop_id = p_shop_id
      and (p_listing_ids is null or spl.id = any(p_listing_ids))
      and spl.is_price_locked is false;
  else
    update public.shop_product_listings spl
    set
      sell_price_amount = case
        when p_markup_type = 'percentage' then
          round(coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) * (1 + (v_amount / 100.0)), 2)
        else
          round(coalesce(spl.minimum_sell_price_amount, spl.sell_price_amount) + v_amount, 2)
      end,
      updated_at = now()
    where spl.shop_id = p_shop_id
      and (p_listing_ids is null or spl.id = any(p_listing_ids))
      and spl.is_price_locked is false;
  end if;

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

GRANT ALL ON FUNCTION public.bulk_apply_shop_markup(bigint, numeric, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.bulk_apply_shop_markup(bigint, numeric, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_apply_shop_markup(bigint, numeric, bigint[]) TO service_role;

GRANT ALL ON FUNCTION public.bulk_apply_shop_markup(bigint, numeric, text, text, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.bulk_apply_shop_markup(bigint, numeric, text, text, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_apply_shop_markup(bigint, numeric, text, text, bigint[]) TO service_role;