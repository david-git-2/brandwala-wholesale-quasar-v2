begin;

-- =========================================================
-- 1. customer_group_shop_profiles Table
-- Defines default shop capabilities per customer group.
-- =========================================================
create table if not exists public.customer_group_shop_profiles (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  customer_group_id bigint not null references public.customer_groups(id) on delete cascade,
  is_active boolean not null default true,
  default_can_browse boolean not null default true,
  default_see_price boolean not null default false,
  default_can_add_to_cart boolean not null default true,
  default_can_place_order boolean not null default true,
  default_can_negotiate boolean not null default false,
  default_can_view_quantity boolean not null default true,
  default_can_set_dropship_price boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint customer_group_shop_profiles_unique_tenant_group unique (tenant_id, customer_group_id)
);

create or replace function public.set_customer_group_shop_profiles_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_customer_group_shop_profiles_updated_at on public.customer_group_shop_profiles;
create trigger trg_customer_group_shop_profiles_updated_at
  before update on public.customer_group_shop_profiles
  for each row execute function public.set_customer_group_shop_profiles_updated_at();

-- =========================================================
-- 2. shop_customer_group_access Table
-- Overrides defaults per shop.
-- =========================================================
create table if not exists public.shop_customer_group_access (
  id bigint generated always as identity primary key,
  shop_id bigint not null references public.shops(id) on delete cascade,
  customer_group_id bigint not null references public.customer_groups(id) on delete cascade,
  status boolean not null default true,
  can_browse boolean default null,
  see_price boolean default null,
  can_add_to_cart boolean default null,
  can_place_order boolean default null,
  can_negotiate boolean default null,
  can_view_quantity boolean default null,
  can_set_dropship_price boolean default null,
  price_tier_code text default null,
  credit_limit_amount numeric(12,4) default null,
  credit_limit_currency_id bigint references public.global_currencies(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint shop_customer_group_access_unique_shop_group unique (shop_id, customer_group_id),
  constraint shop_customer_group_access_credit_limit_currency check (
    (credit_limit_amount is null) = (credit_limit_currency_id is null)
  )
);

create or replace function public.set_shop_customer_group_access_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shop_customer_group_access_updated_at on public.shop_customer_group_access;
create trigger trg_shop_customer_group_access_updated_at
  before update on public.shop_customer_group_access
  for each row execute function public.set_shop_customer_group_access_updated_at();

-- =========================================================
-- 3. RLS Enablement
-- =========================================================
alter table public.customer_group_shop_profiles enable row level security;
alter table public.shop_customer_group_access enable row level security;

-- customer_group_shop_profiles policies
create policy "cg_profiles_select_tenant_member"
  on public.customer_group_shop_profiles for select
  using (
    tenant_id in (
      select tm.tenant_id
      from public.memberships tm
      where lower(trim(tm.email)) = public.current_user_email()
        and tm.is_active = true
    )
  );

create policy "cg_profiles_write_tenant_admin_staff"
  on public.customer_group_shop_profiles for all
  using (
    tenant_id in (
      select m.tenant_id
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  );

create policy "cg_profiles_superadmin_all"
  on public.customer_group_shop_profiles for all
  using (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role = 'superadmin'
        and m.is_active = true
    )
  );

-- shop_customer_group_access policies
create policy "shop_cg_access_select_tenant_member"
  on public.shop_customer_group_access for select
  using (
    exists (
      select 1 from public.shops s
      join public.memberships tm on tm.tenant_id = s.tenant_id
      where s.id = shop_id
        and lower(trim(tm.email)) = public.current_user_email()
        and tm.is_active = true
    )
  );

create policy "shop_cg_access_write_tenant_admin_staff"
  on public.shop_customer_group_access for all
  using (
    exists (
      select 1 from public.shops s
      join public.memberships m on m.tenant_id = s.tenant_id
      where s.id = shop_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  );

create policy "shop_cg_access_superadmin_all"
  on public.shop_customer_group_access for all
  using (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role = 'superadmin'
        and m.is_active = true
    )
  );

-- =========================================================
-- 4. RPC: get_shop_permissions_for_customer
-- Resolves all effective flags for the customer's groups.
-- =========================================================
create or replace function public.get_shop_permissions_for_customer(p_shop_id bigint)
returns table (
  can_browse boolean,
  see_price boolean,
  can_add_to_cart boolean,
  can_place_order boolean,
  can_negotiate boolean,
  can_view_quantity boolean,
  can_set_dropship_price boolean
)
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_shop_active boolean;
  v_tenant_id bigint;
  v_is_negotiable boolean;
begin
  select is_active, tenant_id, is_negotiable
  into v_shop_active, v_tenant_id, v_is_negotiable
  from public.shops
  where id = p_shop_id;

  if v_shop_active is not true then
    return query select false, false, false, false, false, false, false;
    return;
  end if;

  return query
  select
    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_browse, profile.default_can_browse, false)
      end
    ), false) as can_browse,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.see_price, profile.default_see_price, false)
      end
    ), false) as see_price,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_add_to_cart, profile.default_can_add_to_cart, false)
      end
    ), false) as can_add_to_cart,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_place_order, profile.default_can_place_order, false)
      end
    ), false) as can_place_order,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_negotiate, profile.default_can_negotiate, false)
      end
    ) and v_is_negotiable, false) as can_negotiate,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_view_quantity, profile.default_can_view_quantity, false)
      end
    ), false) as can_view_quantity,

    coalesce(bool_or(
      case when access.status = false or profile.is_active = false then false
      else coalesce(access.can_set_dropship_price, profile.default_can_set_dropship_price, false)
      end
    ), false) as can_set_dropship_price
  from public.customer_group_members cgm
  join public.customer_groups cg on cg.id = cgm.customer_group_id
  join public.shop_customer_group_access access on access.customer_group_id = cg.id
  left join public.customer_group_shop_profiles profile
    on profile.customer_group_id = cg.id and profile.tenant_id = v_tenant_id
  where access.shop_id = p_shop_id
    and cg.tenant_id = v_tenant_id
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email();
end;
$$;

grant execute on function public.get_shop_permissions_for_customer(bigint) to authenticated;

-- =========================================================
-- 5. RPC: can_customer_access_shop
-- =========================================================
create or replace function public.can_customer_access_shop(p_shop_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select can_browse from public.get_shop_permissions_for_customer(p_shop_id)), false);
$$;

grant execute on function public.can_customer_access_shop(bigint) to authenticated;

-- =========================================================
-- 6. RPC: can_customer_see_shop_price
-- =========================================================
create or replace function public.can_customer_see_shop_price(p_shop_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select see_price from public.get_shop_permissions_for_customer(p_shop_id)), false);
$$;

grant execute on function public.can_customer_see_shop_price(bigint) to authenticated;

-- =========================================================
-- 7. RPC: can_customer_negotiate_on_shop
-- =========================================================
create or replace function public.can_customer_negotiate_on_shop(p_shop_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select coalesce((select can_negotiate from public.get_shop_permissions_for_customer(p_shop_id)), false);
$$;

grant execute on function public.can_customer_negotiate_on_shop(bigint) to authenticated;

-- =========================================================
-- 8. RPC: upsert_customer_group_shop_profile
-- =========================================================
create or replace function public.upsert_customer_group_shop_profile(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_is_active boolean,
  p_default_can_browse boolean,
  p_default_see_price boolean,
  p_default_can_add_to_cart boolean,
  p_default_can_place_order boolean,
  p_default_can_negotiate boolean,
  p_default_can_view_quantity boolean,
  p_default_can_set_dropship_price boolean
)
returns setof public.customer_group_shop_profiles
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.user_can_manage_shop_tenant(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  return query
  insert into public.customer_group_shop_profiles (
    tenant_id,
    customer_group_id,
    is_active,
    default_can_browse,
    default_see_price,
    default_can_add_to_cart,
    default_can_place_order,
    default_can_negotiate,
    default_can_view_quantity,
    default_can_set_dropship_price
  )
  values (
    p_tenant_id,
    p_customer_group_id,
    p_is_active,
    p_default_can_browse,
    p_default_see_price,
    p_default_can_add_to_cart,
    p_default_can_place_order,
    p_default_can_negotiate,
    p_default_can_view_quantity,
    p_default_can_set_dropship_price
  )
  on conflict (tenant_id, customer_group_id) do update set
    is_active = excluded.is_active,
    default_can_browse = excluded.default_can_browse,
    default_see_price = excluded.default_see_price,
    default_can_add_to_cart = excluded.default_can_add_to_cart,
    default_can_place_order = excluded.default_can_place_order,
    default_can_negotiate = excluded.default_can_negotiate,
    default_can_view_quantity = excluded.default_can_view_quantity,
    default_can_set_dropship_price = excluded.default_can_set_dropship_price,
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_customer_group_shop_profile(bigint, bigint, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean) to authenticated;

-- =========================================================
-- 9. RPC: upsert_shop_customer_group_access
-- =========================================================
create or replace function public.upsert_shop_customer_group_access(
  p_shop_id bigint,
  p_customer_group_id bigint,
  p_status boolean,
  p_can_browse boolean default null,
  p_see_price boolean default null,
  p_can_add_to_cart boolean default null,
  p_can_place_order boolean default null,
  p_can_negotiate boolean default null,
  p_can_view_quantity boolean default null,
  p_can_set_dropship_price boolean default null,
  p_price_tier_code text default null,
  p_credit_limit_amount numeric(12,4) default null,
  p_credit_limit_currency_id bigint default null
)
returns setof public.shop_customer_group_access
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shops
  where id = p_shop_id;

  if v_tenant_id is null then
    raise exception 'shop not found';
  end if;

  if not public.user_can_manage_shop_tenant(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  if (p_credit_limit_amount is null) <> (p_credit_limit_currency_id is null) then
    raise exception 'both credit_limit_amount and credit_limit_currency_id must be provided together or be null';
  end if;

  return query
  insert into public.shop_customer_group_access (
    shop_id,
    customer_group_id,
    status,
    can_browse,
    see_price,
    can_add_to_cart,
    can_place_order,
    can_negotiate,
    can_view_quantity,
    can_set_dropship_price,
    price_tier_code,
    credit_limit_amount,
    credit_limit_currency_id
  )
  values (
    p_shop_id,
    p_customer_group_id,
    p_status,
    p_can_browse,
    p_see_price,
    p_can_add_to_cart,
    p_can_place_order,
    p_can_negotiate,
    p_can_view_quantity,
    p_can_set_dropship_price,
    p_price_tier_code,
    p_credit_limit_amount,
    p_credit_limit_currency_id
  )
  on conflict (shop_id, customer_group_id) do update set
    status = excluded.status,
    can_browse = excluded.can_browse,
    see_price = excluded.see_price,
    can_add_to_cart = excluded.can_add_to_cart,
    can_place_order = excluded.can_place_order,
    can_negotiate = excluded.can_negotiate,
    can_view_quantity = excluded.can_view_quantity,
    can_set_dropship_price = excluded.can_set_dropship_price,
    price_tier_code = excluded.price_tier_code,
    credit_limit_amount = excluded.credit_limit_amount,
    credit_limit_currency_id = excluded.credit_limit_currency_id,
    updated_at = now()
  returning *;
end;
$$;

grant execute on function public.upsert_shop_customer_group_access(bigint, bigint, boolean, boolean, boolean, boolean, boolean, boolean, boolean, boolean, text, numeric, bigint) to authenticated;

commit;
