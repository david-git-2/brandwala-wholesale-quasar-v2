begin;

-- =========================================================
-- Helper: check caller is admin or staff of a tenant
-- (child or standalone — used by shop_order RPCs)
-- =========================================================
create or replace function public.user_can_manage_shop_tenant(p_tenant_id bigint)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  );
$$;

grant execute on function public.user_can_manage_shop_tenant(bigint) to authenticated;

-- =========================================================
-- 1. list_shops
-- Returns all shops for a tenant the caller is a member of.
-- =========================================================
create or replace function public.list_shops(
  p_tenant_id bigint,
  p_limit     int     default 200,
  p_offset    int     default 0,
  p_search    text    default null,
  p_active    boolean default null
)
returns table (
  id                   bigint,
  tenant_id            bigint,
  name                 text,
  slug                 text,
  shop_type            public.shop_type_enum,
  vendor_code          text,
  order_mode           public.shop_order_mode_enum,
  is_negotiable        boolean,
  show_stock_quantity  boolean,
  default_currency_id  bigint,
  global_stock_type_id bigint,
  is_active            boolean,
  created_at           timestamptz,
  updated_at           timestamptz,
  total_count          bigint
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

-- =========================================================
-- 2. upsert_shop
-- Creates (p_id = null) or updates (p_id not null) a shop.
-- shop_type is immutable on update.
-- vendor_code is required when shop_type = 'vendor_catalog'.
-- =========================================================
create or replace function public.upsert_shop(
  p_tenant_id            bigint,
  p_name                 text,
  p_slug                 text,
  p_order_mode           public.shop_order_mode_enum,
  p_is_negotiable        boolean,
  p_show_stock_quantity  boolean,
  p_is_active            boolean,
  -- create-only fields (ignored on update)
  p_shop_type            public.shop_type_enum default null,
  p_vendor_code          text                 default null,
  -- optional fields
  p_id                   bigint               default null,
  p_default_currency_id  bigint               default null,
  p_global_stock_type_id bigint               default null
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
  -- Permission: admin or staff of this tenant
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_id is null then
    -- -------------------------------------------------------
    -- CREATE
    -- -------------------------------------------------------
    if p_shop_type is null then
      raise exception 'shop_type is required when creating a shop';
    end if;

    -- vendor_code required for vendor_catalog
    if p_shop_type = 'vendor_catalog' and (p_vendor_code is null or trim(p_vendor_code) = '') then
      raise exception 'vendor_code is required for vendor_catalog shops';
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
      is_active
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
      p_default_currency_id,
      p_global_stock_type_id,
      p_is_active
    )
    returning * into v_result;

  else
    -- -------------------------------------------------------
    -- UPDATE — shop_type and vendor_code are immutable
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
      name                 = trim(p_name),
      slug                 = lower(trim(p_slug)),
      order_mode           = p_order_mode,
      is_negotiable        = p_is_negotiable,
      show_stock_quantity  = p_show_stock_quantity,
      default_currency_id  = p_default_currency_id,
      global_stock_type_id = p_global_stock_type_id,
      is_active            = p_is_active,
      updated_at           = now()
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

grant execute on function public.upsert_shop(bigint, text, text, public.shop_order_mode_enum, boolean, boolean, boolean, public.shop_type_enum, text, bigint, bigint, bigint) to authenticated;

commit;
