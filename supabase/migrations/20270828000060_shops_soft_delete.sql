-- Soft-delete shops: hide from lists, keep row and children. Unique slug only among live shops.

alter table public.shops
  add column if not exists deleted_at timestamptz null,
  add column if not exists deleted_by text null;

create index if not exists shops_tenant_live_idx
  on public.shops (tenant_id)
  where deleted_at is null;

alter table public.shops drop constraint if exists shops_unique_slug;

drop index if exists shops_unique_live_slug;
create unique index shops_unique_live_slug
  on public.shops (tenant_id, slug)
  where deleted_at is null;

create or replace function public.delete_shop(
  p_shop_id bigint,
  p_tenant_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  update public.shops
  set
    deleted_at = now(),
    deleted_by = public.current_user_email(),
    is_active = false
  where id = p_shop_id
    and tenant_id = p_tenant_id
    and deleted_at is null;

  if not found then
    raise exception 'shop not found or already deleted';
  end if;
end;
$$;

grant execute on function public.delete_shop(bigint, bigint) to authenticated;

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
    and s.deleted_at is null
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
    and s.deleted_at is null
    and (p_active  is null or s.is_active = p_active)
    and (p_search  is null or s.name ilike '%' || p_search || '%' or s.slug ilike '%' || p_search || '%')
  order by s.name asc
  limit  p_limit
  offset p_offset;
end;
$$;

grant execute on function public.list_shops(bigint, int, int, text, boolean) to authenticated;

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
    and s.deleted_at is null
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
