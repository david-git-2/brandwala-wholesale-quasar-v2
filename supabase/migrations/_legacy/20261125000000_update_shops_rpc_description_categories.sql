-- =========================================================
-- Update upsert_shop, list_shops, and list_shops_for_customer
-- to support description and category_ids attributes.
-- =========================================================

begin;

-- 1. Drop existing functions cleanly
drop function if exists public.upsert_shop cascade;
drop function if exists public.list_shops cascade;
drop function if exists public.list_shops_for_customer cascade;

-- Relax SELECT policy on shop_categories so all authenticated users can read active categories
drop policy if exists shop_categories_select_policy on public.shop_categories;
create policy shop_categories_select_policy on public.shop_categories
  for select
  to authenticated
  using (
    is_active = true
    or public.is_superadmin()
    or exists (
      select 1 from public.memberships m 
      where m.tenant_id = public.shop_categories.tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
    )
  );

-- 2. Create updated upsert_shop function
create or replace function public.upsert_shop(
  p_tenant_id                     bigint,
  p_name                          text,
  p_slug                          text,
  p_order_mode                    public.shop_order_mode_enum,
  p_is_negotiable                 boolean,
  p_show_stock_quantity           boolean,
  p_is_active                     boolean,
  p_shop_type                     public.shop_type_enum default null,
  p_vendor_code                   text                 default null,
  p_id                            bigint               default null,
  p_default_currency_id           bigint               default null,
  p_global_stock_type_id          bigint               default null,
  p_allow_delivery                boolean              default false,
  p_buy_currency_id               bigint               default null,
  p_sell_currency_id              bigint               default null,
  p_pricing_method                text                 default null,
  p_markup_percentage             numeric              default 0,
  p_quantity_display_mode         text                 default null,
  p_default_print_charge_amount   numeric              default 0,
  p_default_packing_charge_amount numeric              default 0,
  p_deduct_charges_from_margin    boolean              default false,
  p_vendor_filters                jsonb                default null,
  p_deduct_print_from_margin      boolean              default false,
  p_deduct_packing_from_margin    boolean              default false,
  p_description                   text                 default null,
  p_category_ids                  bigint[]             default '{}'
)
returns setof public.shops
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shop_type public.shop_type_enum;
  v_result    public.shops;
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_pricing_method is not null and p_pricing_method not in ('direct_cost', 'markup') then
    raise exception 'invalid pricing method';
  end if;
  if p_quantity_display_mode is not null and p_quantity_display_mode not in ('original', 'custom_override') then
    raise exception 'invalid quantity display mode';
  end if;
  if p_markup_percentage < 0 then
    raise exception 'markup percentage must be non-negative';
  end if;

  if p_id is null then
    if p_shop_type is null then
      raise exception 'shop_type is required when creating a shop';
    end if;

    if p_shop_type = 'vendor_catalog' and (p_vendor_code is null or trim(p_vendor_code) = '') and (p_vendor_filters is null or jsonb_array_length(p_vendor_filters) = 0) then
      raise exception 'vendor_code or vendor_filters is required for vendor_catalog shops';
    end if;

    if p_shop_type = 'dropship' and p_is_negotiable then
      raise exception 'dropship shops cannot be negotiable';
    end if;

    insert into public.shops (
      tenant_id,
      name,
      slug,
      shop_type,
      vendor_code,
      order_mode,
      is_negotiable,
      show_stock_quantity,
      default_currency_id,
      global_stock_type_id,
      is_active,
      allow_delivery,
      buy_currency_id,
      sell_currency_id,
      pricing_method,
      markup_percentage,
      quantity_display_mode,
      default_print_charge_amount,
      default_packing_charge_amount,
      deduct_charges_from_margin,
      vendor_filters,
      deduct_print_from_margin,
      deduct_packing_from_margin,
      description,
      category_ids
    )
    values (
      p_tenant_id,
      trim(p_name),
      lower(trim(p_slug)),
      p_shop_type,
      case when p_vendor_code is not null then trim(p_vendor_code) else null end,
      p_order_mode,
      p_is_negotiable,
      p_show_stock_quantity,
      coalesce(p_default_currency_id, p_sell_currency_id),
      p_global_stock_type_id,
      p_is_active,
      p_allow_delivery,
      coalesce(p_buy_currency_id, p_default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
      coalesce(p_sell_currency_id, p_default_currency_id, (select id from public.global_currencies where code = 'BDT' limit 1)),
      coalesce(p_pricing_method, 'direct_cost'),
      coalesce(p_markup_percentage, 0),
      coalesce(p_quantity_display_mode, 'original'),
      coalesce(p_default_print_charge_amount, 0),
      coalesce(p_default_packing_charge_amount, 0),
      coalesce(p_deduct_charges_from_margin, false),
      p_vendor_filters,
      coalesce(p_deduct_print_from_margin, false),
      coalesce(p_deduct_packing_from_margin, false),
      trim(p_description),
      coalesce(p_category_ids, '{}')
    )
    returning * into v_result;

  else
    select shop_type into v_shop_type
    from public.shops
    where id = p_id and tenant_id = p_tenant_id;

    if v_shop_type is null then
      raise exception 'shop not found';
    end if;

    if v_shop_type = 'dropship' and p_is_negotiable then
      raise exception 'dropship shops cannot be negotiable';
    end if;

    update public.shops
    set
      name                            = trim(p_name),
      slug                            = lower(trim(p_slug)),
      order_mode                      = p_order_mode,
      is_negotiable                   = p_is_negotiable,
      show_stock_quantity             = p_show_stock_quantity,
      default_currency_id             = coalesce(p_default_currency_id, p_sell_currency_id, default_currency_id),
      global_stock_type_id            = p_global_stock_type_id,
      is_active                       = p_is_active,
      allow_delivery                  = p_allow_delivery,
      buy_currency_id                 = coalesce(p_buy_currency_id, buy_currency_id),
      sell_currency_id                = coalesce(p_sell_currency_id, p_default_currency_id, sell_currency_id),
      pricing_method                  = coalesce(p_pricing_method, pricing_method),
      markup_percentage               = coalesce(p_markup_percentage, markup_percentage),
      quantity_display_mode           = coalesce(p_quantity_display_mode, quantity_display_mode),
      default_print_charge_amount     = coalesce(p_default_print_charge_amount, default_print_charge_amount),
      default_packing_charge_amount   = coalesce(p_default_packing_charge_amount, default_packing_charge_amount),
      deduct_charges_from_margin      = coalesce(p_deduct_charges_from_margin, deduct_charges_from_margin),
      vendor_filters                  = coalesce(p_vendor_filters, vendor_filters),
      deduct_print_from_margin        = coalesce(p_deduct_print_from_margin, deduct_print_from_margin),
      deduct_packing_from_margin      = coalesce(p_deduct_packing_from_margin, deduct_packing_from_margin),
      description                     = trim(p_description),
      category_ids                    = coalesce(p_category_ids, '{}'),
      updated_at                      = now()
    where id = p_id
      and tenant_id = p_tenant_id
    returning * into v_result;

    if v_result is null then
      raise exception 'shop not found or update failed';
    end if;
  end if;

  return next v_result;
end;
$$;

grant execute on function public.upsert_shop(
  bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean,
  public.shop_type_enum, text, bigint, bigint, bigint, boolean,
  bigint, bigint, text, numeric, text, numeric, numeric, boolean, jsonb,
  boolean, boolean, text, bigint[]
) to authenticated;

-- 3. Create updated list_shops function
create or replace function public.list_shops(
  p_tenant_id bigint,
  p_limit     int     default 200,
  p_offset    int     default 0,
  p_search    text    default null,
  p_active    boolean default null
)
returns table (
  id                              bigint,
  tenant_id                       bigint,
  name                            text,
  slug                            text,
  shop_type                       public.shop_type_enum,
  vendor_code                     text,
  order_mode                      public.shop_order_mode_enum,
  is_negotiable                   boolean,
  show_stock_quantity             boolean,
  default_currency_id             bigint,
  global_stock_type_id            bigint,
  is_active                       boolean,
  allow_delivery                  boolean,
  buy_currency_id                 bigint,
  sell_currency_id                bigint,
  pricing_method                  text,
  markup_percentage               numeric,
  quantity_display_mode           text,
  default_print_charge_amount     numeric,
  default_packing_charge_amount   numeric,
  deduct_charges_from_margin      boolean,
  vendor_filters                  jsonb,
  deduct_print_from_margin        boolean,
  deduct_packing_from_margin      boolean,
  description                     text,
  category_ids                    bigint[],
  created_at                      timestamptz,
  updated_at                      timestamptz,
  total_count                     bigint
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_total bigint;
begin
  if not exists (
    select 1 from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  ) then
    raise exception 'not allowed';
  end if;

  select count(*)
  into v_total
  from public.shops s
  where s.tenant_id = p_tenant_id
    and (p_active  is null or s.is_active = p_active)
    and (p_search  is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%');

  return query
  select
    s.id,
    s.tenant_id,
    s.name,
    s.slug,
    s.shop_type,
    s.vendor_code,
    s.order_mode,
    s.is_negotiable,
    s.show_stock_quantity,
    s.default_currency_id,
    s.global_stock_type_id,
    s.is_active,
    s.allow_delivery,
    s.buy_currency_id,
    s.sell_currency_id,
    s.pricing_method,
    s.markup_percentage,
    s.quantity_display_mode,
    s.default_print_charge_amount,
    s.default_packing_charge_amount,
    s.deduct_charges_from_margin,
    s.vendor_filters,
    s.deduct_print_from_margin,
    s.deduct_packing_from_margin,
    s.description,
    s.category_ids,
    s.created_at,
    s.updated_at,
    v_total
  from public.shops s
  where s.tenant_id = p_tenant_id
    and (p_active  is null or s.is_active = p_active)
    and (p_search  is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%')
  order by s.name asc
  limit  p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_shops(bigint, int, int, text, boolean) to authenticated;

-- 4. Create updated list_shops_for_customer function
create or replace function public.list_shops_for_customer(
  p_tenant_id bigint default null
)
returns table (
  id            bigint,
  tenant_id     bigint,
  name          text,
  slug          text,
  shop_type     public.shop_type_enum,
  order_mode    public.shop_order_mode_enum,
  is_negotiable boolean,
  see_price     boolean,
  description   text,
  category_ids  bigint[],
  categories    jsonb
)
language sql
security definer
set search_path = public
stable
as $$
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
        else coalesce(access.see_price, profile.default_see_price, false)
      end
    ) as see_price,
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
    ) as categories
  from public.shops s
  join public.shop_customer_group_access access on access.shop_id = s.id
  join public.customer_groups cg on cg.id = access.customer_group_id
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = s.tenant_id
  where s.is_active = true
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
    and (p_tenant_id is null or s.tenant_id = p_tenant_id)
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
    s.category_ids
  order by s.name asc;
$$;

grant execute on function public.list_shops_for_customer(bigint) to authenticated;

commit;
