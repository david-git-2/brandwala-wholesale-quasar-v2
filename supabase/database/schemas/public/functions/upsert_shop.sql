CREATE FUNCTION public.upsert_shop (
  p_tenant_id                     bigint,
  p_name                          text,
  p_slug                          text,
  p_order_mode                    public.shop_order_mode_enum,
  p_is_negotiable                 boolean,
  p_show_stock_quantity           boolean,
  p_is_active                     boolean,
  p_shop_type                     public.shop_type_enum       DEFAULT NULL::public.shop_type_enum,
  p_vendor_code                   text                        DEFAULT NULL::text,
  p_id                            bigint                      DEFAULT NULL::bigint,
  p_default_currency_id           bigint                      DEFAULT NULL::bigint,
  p_global_stock_type_id          bigint                      DEFAULT NULL::bigint,
  p_allow_delivery                boolean                     DEFAULT false,
  p_buy_currency_id               bigint                      DEFAULT NULL::bigint,
  p_sell_currency_id              bigint                      DEFAULT NULL::bigint,
  p_pricing_method                text                        DEFAULT NULL::text,
  p_markup_percentage             numeric                     DEFAULT 0,
  p_quantity_display_mode         text                        DEFAULT NULL::text,
  p_default_print_charge_amount   numeric                     DEFAULT 0,
  p_default_packing_charge_amount numeric                     DEFAULT 0,
  p_deduct_charges_from_margin    boolean                     DEFAULT false,
  p_vendor_filters                jsonb                       DEFAULT NULL::jsonb,
  p_deduct_print_from_margin      boolean                     DEFAULT false,
  p_deduct_packing_from_margin    boolean                     DEFAULT false,
  p_description                   text                        DEFAULT NULL::text,
  p_category_ids                  bigint[]                    DEFAULT '{}'::bigint[],
  p_min_available_units           integer                     DEFAULT 0,
  p_display_quantity_add          integer                     DEFAULT 6
)
  RETURNS SETOF public.shops
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop_type public.shop_type_enum;
  v_result    public.shops;
  v_vendor_code text;
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
  if coalesce(p_min_available_units, 0) < 0 then
    raise exception 'min_available_units must be non-negative';
  end if;
  if coalesce(p_display_quantity_add, 6) < 0 then
    raise exception 'display_quantity_add must be non-negative';
  end if;

  v_vendor_code := nullif(trim(coalesce(p_vendor_code, '')), '');
  if v_vendor_code is null
     and p_vendor_filters is not null
     and jsonb_typeof(p_vendor_filters) = 'array'
     and jsonb_array_length(p_vendor_filters) > 0 then
    v_vendor_code := nullif(trim(coalesce(p_vendor_filters->0->>'vendor_code', '')), '');
  end if;

  if p_id is null then
    if p_shop_type is null then
      raise exception 'shop_type is required when creating a shop';
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
      display_quantity_add,
      default_print_charge_amount,
      default_packing_charge_amount,
      deduct_charges_from_margin,
      vendor_filters,
      deduct_print_from_margin,
      deduct_packing_from_margin,
      description,
      category_ids,
      min_available_units
    )
    values (
      p_tenant_id,
      trim(p_name),
      lower(trim(p_slug)),
      p_shop_type,
      v_vendor_code,
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
      coalesce(p_display_quantity_add, 6),
      coalesce(p_default_print_charge_amount, 0),
      coalesce(p_default_packing_charge_amount, 0),
      coalesce(p_deduct_charges_from_margin, false),
      p_vendor_filters,
      coalesce(p_deduct_print_from_margin, false),
      coalesce(p_deduct_packing_from_margin, false),
      trim(p_description),
      coalesce(p_category_ids, '{}'),
      coalesce(p_min_available_units, 0)
    )
    returning * into v_result;
  else
    select shop_type into v_shop_type
    from public.shops
    where id = p_id and tenant_id = p_tenant_id
      and deleted_at is null;

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
      display_quantity_add            = coalesce(p_display_quantity_add, display_quantity_add),
      default_print_charge_amount     = coalesce(p_default_print_charge_amount, default_print_charge_amount),
      default_packing_charge_amount   = coalesce(p_default_packing_charge_amount, default_packing_charge_amount),
      deduct_charges_from_margin      = coalesce(p_deduct_charges_from_margin, deduct_charges_from_margin),
      vendor_code                     = case
                                          when p_vendor_code is not null or p_vendor_filters is not null
                                            then v_vendor_code
                                          else vendor_code
                                        end,
      vendor_filters                  = coalesce(p_vendor_filters, vendor_filters),
      deduct_print_from_margin        = coalesce(p_deduct_print_from_margin, deduct_print_from_margin),
      deduct_packing_from_margin      = coalesce(p_deduct_packing_from_margin, deduct_packing_from_margin),
      description                     = trim(p_description),
      category_ids                    = coalesce(p_category_ids, '{}'),
      min_available_units             = coalesce(p_min_available_units, min_available_units),
      updated_at                      = now()
    where id = p_id
      and tenant_id = p_tenant_id
      and deleted_at is null
    returning * into v_result;

    if v_result is null then
      raise exception 'shop not found or update failed';
    end if;
  end if;

  return next v_result;
end;
$function$;

CREATE FUNCTION public.upsert_shop (
  p_tenant_id                      bigint,
  p_name                           text,
  p_slug                           text,
  p_order_mode                     public.shop_order_mode_enum,
  p_is_negotiable                  boolean,
  p_show_stock_quantity            boolean,
  p_is_active                      boolean,
  p_shop_type                      public.shop_type_enum       DEFAULT NULL::public.shop_type_enum,
  p_vendor_code                    text                        DEFAULT NULL::text,
  p_id                             bigint                      DEFAULT NULL::bigint,
  p_default_currency_id            bigint                      DEFAULT NULL::bigint,
  p_global_stock_type_id           bigint                      DEFAULT NULL::bigint,
  p_allow_delivery                 boolean                     DEFAULT false,
  p_buy_currency_id                bigint                      DEFAULT NULL::bigint,
  p_sell_currency_id               bigint                      DEFAULT NULL::bigint,
  p_pricing_method                 text                        DEFAULT NULL::text,
  p_markup_percentage              numeric                     DEFAULT 0,
  p_quantity_display_mode          text                        DEFAULT NULL::text,
  p_default_cod_charge_pct         numeric                     DEFAULT 0,
  p_default_delivery_charge_amount numeric                     DEFAULT 0,
  p_default_print_charge_amount    numeric                     DEFAULT 0,
  p_default_packing_charge_amount  numeric                     DEFAULT 0,
  p_deduct_charges_from_margin     boolean                     DEFAULT false,
  p_vendor_filters                 jsonb                       DEFAULT NULL::jsonb,
  p_deduct_cod_from_margin         boolean                     DEFAULT false,
  p_deduct_delivery_from_margin    boolean                     DEFAULT false,
  p_deduct_print_from_margin       boolean                     DEFAULT false,
  p_deduct_packing_from_margin     boolean                     DEFAULT false
)
  RETURNS SETOF public.shops
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_shop_type public.shop_type_enum;
  v_result    public.shops;
begin
  -- Permission: admin or staff of this tenant
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  -- Constraints checking
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
    -- -------------------------------------------------------
    -- CREATE
    -- -------------------------------------------------------
    if p_shop_type is null then
      raise exception 'shop_type is required when creating a shop';
    end if;

    -- vendor_code or vendor_filters required for vendor_catalog
    if p_shop_type = 'vendor_catalog' and (p_vendor_code is null or trim(p_vendor_code) = '') and (p_vendor_filters is null or jsonb_array_length(p_vendor_filters) = 0) then
      raise exception 'vendor_code or vendor_filters is required for vendor_catalog shops';
    end if;

    -- dropship cannot be negotiable
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
      default_cod_charge_pct,
      default_delivery_charge_amount,
      default_print_charge_amount,
      default_packing_charge_amount,
      deduct_charges_from_margin,
      vendor_filters,
      deduct_cod_from_margin,
      deduct_delivery_from_margin,
      deduct_print_from_margin,
      deduct_packing_from_margin
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
      coalesce(p_default_cod_charge_pct, 0),
      coalesce(p_default_delivery_charge_amount, 0),
      coalesce(p_default_print_charge_amount, 0),
      coalesce(p_default_packing_charge_amount, 0),
      coalesce(p_deduct_charges_from_margin, false),
      p_vendor_filters,
      coalesce(p_deduct_cod_from_margin, false),
      coalesce(p_deduct_delivery_from_margin, false),
      coalesce(p_deduct_print_from_margin, false),
      coalesce(p_deduct_packing_from_margin, false)
    )
    returning * into v_result;

  else
    -- -------------------------------------------------------
    -- UPDATE — shop_type and vendor_code are immutable, but vendor_filters can be updated
    -- -------------------------------------------------------
    select shop_type into v_shop_type
    from public.shops
    where id = p_id and tenant_id = p_tenant_id;

    if v_shop_type is null then
      raise exception 'shop not found';
    end if;

    -- dropship cannot be negotiable (guard even on updates)
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
      default_cod_charge_pct          = coalesce(p_default_cod_charge_pct, default_cod_charge_pct),
      default_delivery_charge_amount  = coalesce(p_default_delivery_charge_amount, default_delivery_charge_amount),
      default_print_charge_amount     = coalesce(p_default_print_charge_amount, default_print_charge_amount),
      default_packing_charge_amount   = coalesce(p_default_packing_charge_amount, default_packing_charge_amount),
      deduct_charges_from_margin      = coalesce(p_deduct_charges_from_margin, deduct_charges_from_margin),
      vendor_filters                  = coalesce(p_vendor_filters, vendor_filters),
      deduct_cod_from_margin          = coalesce(p_deduct_cod_from_margin, deduct_cod_from_margin),
      deduct_delivery_from_margin     = coalesce(p_deduct_delivery_from_margin, deduct_delivery_from_margin),
      deduct_print_from_margin        = coalesce(p_deduct_print_from_margin, deduct_print_from_margin),
      deduct_packing_from_margin      = coalesce(p_deduct_packing_from_margin, deduct_packing_from_margin),
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
$function$;

GRANT ALL ON FUNCTION
  public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean, bigint, bigint, text,
  numeric, text, numeric, numeric, boolean, jsonb, boolean, boolean, text, bigint[], integer, integer) TO anon;

GRANT ALL ON FUNCTION
  public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean, bigint, bigint, text,
  numeric, text, numeric, numeric, boolean, jsonb, boolean, boolean, text, bigint[], integer, integer) TO authenticated;

GRANT ALL ON FUNCTION
  public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean, bigint, bigint, text,
  numeric, text, numeric, numeric, boolean, jsonb, boolean, boolean, text, bigint[], integer, integer) TO service_role;

GRANT ALL ON FUNCTION
  public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean, bigint, bigint, text,
  numeric, text, numeric, numeric, numeric, numeric, boolean, jsonb, boolean, boolean, boolean, boolean) TO anon;

GRANT ALL ON FUNCTION
  public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean, bigint, bigint, text,
  numeric, text, numeric, numeric, numeric, numeric, boolean, jsonb, boolean, boolean, boolean, boolean) TO authenticated;

GRANT ALL ON FUNCTION
  public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint, boolean, bigint, bigint, text,
  numeric, text, numeric, numeric, numeric, numeric, boolean, jsonb, boolean, boolean, boolean, boolean) TO service_role;