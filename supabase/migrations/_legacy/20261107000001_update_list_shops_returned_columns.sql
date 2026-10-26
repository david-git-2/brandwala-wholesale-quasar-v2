-- Migration: Update list_shops return columns to include dropship default charges, deduct_charges_from_margin and vendor_filters
begin;

drop function if exists public.list_shops(bigint, int, int, text, boolean) cascade;

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
  default_cod_charge_pct          numeric,
  default_delivery_charge_amount  numeric,
  default_print_charge_amount     numeric,
  default_packing_charge_amount   numeric,
  deduct_charges_from_margin      boolean,
  vendor_filters                  jsonb,
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
  -- Caller must be a member of this tenant (any active role)
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
    s.default_cod_charge_pct,
    s.default_delivery_charge_amount,
    s.default_print_charge_amount,
    s.default_packing_charge_amount,
    s.deduct_charges_from_margin,
    s.vendor_filters,
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

commit;
