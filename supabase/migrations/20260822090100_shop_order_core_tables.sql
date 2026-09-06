-- Fresh-reset ordering: core shop_order tables/helpers before Aug 20260822 RPC migrations.
-- Later 20260902_shop_order_p* migrations use IF NOT EXISTS / CREATE OR REPLACE safely.
begin;

create table if not exists public.shops (
  id                    bigint generated always as identity primary key,
  tenant_id             bigint not null references public.tenants(id) on delete cascade,
  name                  text not null,
  slug                  text not null,
  shop_type             public.shop_type_enum not null,
  vendor_code           text,
  order_mode            public.shop_order_mode_enum not null,
  is_negotiable         boolean not null default false,
  show_stock_quantity   boolean not null default true,
  default_currency_id   bigint references public.global_currencies(id),
  global_stock_type_id  bigint,
  is_active             boolean not null default true,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  constraint shops_unique_slug unique (tenant_id, slug),
  constraint shops_vendor_catalog_requires_vendor_code check (
    shop_type <> 'vendor_catalog' or vendor_code is not null
  ),
  constraint shops_dropship_not_negotiable check (
    shop_type <> 'dropship' or is_negotiable = false
  )
);

alter table public.shops add column if not exists buy_currency_id bigint references public.global_currencies(id);
alter table public.shops add column if not exists sell_currency_id bigint references public.global_currencies(id);
alter table public.shops add column if not exists pricing_method text;
alter table public.shops add column if not exists markup_percentage numeric(5,2);
alter table public.shops add column if not exists quantity_display_mode text;
alter table public.shops add column if not exists vendor_filters jsonb;
alter table public.shops add column if not exists deleted_at timestamptz;
alter table public.shops add column if not exists deleted_by text;

create or replace function public.set_shops_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_shops_updated_at on public.shops;
create trigger trg_shops_updated_at
  before update on public.shops
  for each row execute function public.set_shops_updated_at();

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

create table if not exists public.shop_product_listings (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  shop_id bigint not null references public.shops(id) on delete cascade,
  global_stock_allocation_id bigint not null references public.global_stock_allocations(id) on delete cascade,
  global_stock_id bigint not null references public.global_stocks(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  sell_price_amount numeric(12,4) not null,
  sell_price_currency_id bigint not null references public.global_currencies(id),
  minimum_sell_price_amount numeric(12,4) default null,
  minimum_sell_price_currency_id bigint references public.global_currencies(id) default null,
  show_quantity boolean default null,
  display_quantity_override integer default null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shop_product_listings_unique_shop_alloc unique (shop_id, global_stock_allocation_id),
  constraint shop_product_listings_min_sell_currency check (
    (minimum_sell_price_amount is null) = (minimum_sell_price_currency_id is null)
  )
);

create table if not exists public.shop_carts (
  id                  bigint generated always as identity primary key,
  tenant_id           bigint not null references public.tenants(id) on delete cascade,
  shop_id             bigint not null references public.shops(id) on delete cascade,
  customer_group_id   bigint not null references public.customer_groups(id) on delete cascade,
  see_price_snapshot  boolean not null default false,
  status              public.shop_cart_status not null default 'active',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create unique index if not exists shop_carts_active_unique_idx
  on public.shop_carts(tenant_id, shop_id, customer_group_id)
  where status = 'active';

create table if not exists public.shop_cart_items (
  id                                  bigint generated always as identity primary key,
  cart_id                             bigint not null references public.shop_carts(id) on delete cascade,
  product_id                          bigint not null references public.products(id) on delete cascade,
  global_stock_id                     bigint references public.global_stocks(id) on delete set null,
  global_stock_allocation_id          bigint references public.global_stock_allocations(id) on delete set null,
  quantity                            integer not null constraint shop_cart_items_qty_positive check (quantity > 0),
  minimum_quantity                    integer not null default 1 constraint shop_cart_items_min_qty_positive check (minimum_quantity > 0),
  unit_list_price_amount              numeric(12,4),
  unit_list_price_currency_id         bigint references public.global_currencies(id),
  unit_sell_price_amount              numeric(12,4),
  unit_sell_price_currency_id         bigint references public.global_currencies(id),
  unit_minimum_sell_price_amount      numeric(12,4),
  unit_minimum_sell_price_currency_id bigint references public.global_currencies(id),
  customer_sell_price_amount          numeric(12,4),
  customer_sell_price_currency_id     bigint references public.global_currencies(id),
  name                                text not null,
  image_url                           text,
  created_at                          timestamptz not null default now(),
  updated_at                          timestamptz not null default now()
);

create table if not exists public.shop_stock_reservations (
  cart_item_id                bigint primary key references public.shop_cart_items(id) on delete cascade,
  global_stock_allocation_id  bigint not null references public.global_stock_allocations(id) on delete cascade,
  quantity                    integer not null constraint shop_stock_reservations_qty_non_negative check (quantity >= 0),
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create table if not exists public.shop_orders (
  id                      bigint generated always as identity primary key,
  tenant_id               bigint not null references public.tenants(id) on delete cascade,
  shop_id                 bigint not null references public.shops(id) on delete cascade,
  customer_group_id       bigint not null references public.customer_groups(id) on delete cascade,
  cart_id                 bigint references public.shop_carts(id) on delete set null,
  order_no                text not null,
  name                    text not null,
  shop_type_snapshot      public.shop_type_enum not null,
  order_mode_snapshot     public.shop_order_mode_enum not null,
  is_negotiable_snapshot  boolean not null default false,
  status                  public.shop_order_status not null default 'submitted',
  negotiate_round         integer not null default 0,
  cargo_rate              numeric(12,4),
  conversion_rate         numeric(12,4),
  profit_rate             numeric(12,4),
  recipient_name          text,
  recipient_phone         text,
  shipping_address        text,
  billing_profile_id      bigint references public.billing_profiles(id) on delete set null,
  placed_at               timestamptz,
  fulfilled_at            timestamptz,
  global_invoice_id       bigint references public.global_invoices(id) on delete set null,
  created_by_email        text not null,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now()
);

alter table public.shop_orders add column if not exists delivered_at timestamptz;
alter table public.shop_orders add column if not exists courier_remittance_ref text;
alter table public.shop_orders add column if not exists courier_bank_trx_id text;

create unique index if not exists shop_orders_order_no_unique_idx on public.shop_orders(tenant_id, order_no);

create table if not exists public.shop_order_items (
  id                                  bigint generated always as identity primary key,
  order_id                            bigint not null references public.shop_orders(id) on delete cascade,
  product_id                          bigint not null references public.products(id) on delete cascade,
  global_stock_id                     bigint references public.global_stocks(id) on delete set null,
  global_stock_allocation_id          bigint references public.global_stock_allocations(id) on delete set null,
  name                                text not null,
  image_url                           text,
  quantity                            integer not null constraint shop_order_items_qty_positive check (quantity > 0),
  unit_list_price_amount              numeric(12,4),
  unit_list_price_currency_id         bigint references public.global_currencies(id),
  unit_sell_price_amount              numeric(12,4),
  unit_sell_price_currency_id         bigint references public.global_currencies(id),
  unit_minimum_sell_price_amount      numeric(12,4),
  unit_minimum_sell_price_currency_id bigint references public.global_currencies(id),
  customer_sell_price_amount          numeric(12,4),
  customer_sell_price_currency_id     bigint references public.global_currencies(id),
  customer_offer_amount               numeric(12,4),
  customer_offer_currency_id          bigint references public.global_currencies(id),
  staff_offer_amount                  numeric(12,4),
  staff_offer_currency_id             bigint references public.global_currencies(id),
  final_price_amount                  numeric(12,4),
  final_price_currency_id             bigint references public.global_currencies(id),
  ordered_quantity                    integer not null,
  delivered_quantity                  integer not null default 0,
  returned_quantity                   integer not null default 0,
  procurement_pulled                  boolean not null default false,
  created_at                          timestamptz not null default now(),
  updated_at                          timestamptz not null default now()
);

create or replace function public.set_shop_order_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.current_customer_group_id(p_tenant_id bigint)
returns bigint
language sql
security definer
set search_path = public
stable
as $$
  select cg.id
  from public.customer_groups cg
  join public.customer_group_members cgm on cgm.customer_group_id = cg.id
  where p_tenant_id is not null
    and cg.tenant_id = p_tenant_id
    and cg.is_active = true
    and cgm.is_active = true
    and lower(trim(cgm.email)) = public.current_user_email()
  order by cg.id
  limit 1;
$$;

revoke all on function public.current_customer_group_id(bigint) from public;
revoke all on function public.current_customer_group_id(bigint) from anon;
grant execute on function public.current_customer_group_id(bigint) to authenticated;

create or replace function public.is_cart_owner(p_customer_group_id bigint, p_tenant_id bigint)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg on cg.id = cgm.customer_group_id
    where cg.id = p_customer_group_id
      and cg.tenant_id = p_tenant_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  );
$$;

create or replace function public.is_tenant_staff(p_tenant_id bigint)
returns boolean language sql security definer set search_path = public stable as $$
  select exists (
    select 1
    from public.memberships m
    where m.tenant_id = p_tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.role in ('admin', 'staff', 'superadmin')
      and m.is_active = true
  );
$$;

-- Only on fresh reset (function absent). Prod already has buy/sell split OUT columns from 20270831000290+.
do $do$
begin
  if to_regprocedure('public.get_shop_permissions_for_customer(bigint)') is null then
    execute $fn$
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
as $body$
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
$body$;
    $fn$;
    grant execute on function public.get_shop_permissions_for_customer(bigint) to authenticated;
  else
    raise notice 'skipped get_shop_permissions_for_customer (already exists; prod uses split price columns)';
  end if;
end $do$;

commit;
