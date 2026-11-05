CREATE FUNCTION public.list_customer_shops (
  p_tenant_id bigint
)
  RETURNS TABLE (
    id                   bigint,
    tenant_id            bigint,
    name                 text,
    slug                 text,
    shop_type            public.shop_type_enum,
    order_mode           public.shop_order_mode_enum,
    is_negotiable        boolean,
    can_see_buy_price    boolean,
    can_see_sell_price   boolean,
    description          text,
    category_ids         bigint[],
    categories           jsonb,
    sell_currency_id     bigint,
    sell_currency_code   text,
    sell_currency_symbol text
  )
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        when s.shop_type = 'dropship' then true
        else coalesce(access.can_see_buy_price, profile.default_can_see_buy_price, false)
      end
    ) as can_see_buy_price,
    bool_or(
      case
        when access.status = false or coalesce(profile.is_active, true) = false then false
        when s.shop_type = 'dropship' then true
        else coalesce(access.can_see_sell_price, profile.default_can_see_sell_price, false)
      end
    ) as can_see_sell_price,
    s.description,
    s.category_ids,
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', c.id,
            'name', c.name,
            'slug', c.slug,
            'icon', c.icon
          )
        )
        from public.shop_categories c
        where c.id = any(s.category_ids)
          and c.is_active = true
      ),
      '[]'::jsonb
    ) as categories,
    s.sell_currency_id,
    gc.code as sell_currency_code,
    gc.symbol as sell_currency_symbol
  from public.shops s
  join public.shop_customer_group_access access on access.shop_id = s.id
  join public.customer_groups cg on cg.id = access.customer_group_id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
  left join public.global_currencies gc on gc.id = s.sell_currency_id
  where p_tenant_id is not null
    and s.is_active = true
    and s.deleted_at is null
    and s.tenant_id = p_tenant_id
    and cg.id = public.current_customer_group_id(p_tenant_id)
    and cg.is_active = true
    and access.status = true
    and coalesce(profile.is_active, true) = true
    and coalesce(access.can_browse, profile.default_can_browse, false) = true
  group by
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.order_mode,
    s.is_negotiable,
    s.description,
    s.category_ids,
    s.sell_currency_id,
    gc.code,
    gc.symbol
  order by s.name asc;
$function$;

GRANT ALL ON FUNCTION public.list_customer_shops(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_customer_shops(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_customer_shops(bigint) TO service_role;