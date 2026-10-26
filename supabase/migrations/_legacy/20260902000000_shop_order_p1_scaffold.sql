begin;

-- =========================================================
-- 1. Enums
-- =========================================================
do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_type_enum') then
    create type public.shop_type_enum as enum (
      'vendor_catalog',
      'fixed_price',
      'dropship'
    );
  end if;
end $$;

do $$ begin
  if not exists (select 1 from pg_type where typname = 'shop_order_mode_enum') then
    create type public.shop_order_mode_enum as enum (
      'procurement_intent',
      'checkout_fixed',
      'checkout_wholesale'
    );
  end if;
end $$;

-- =========================================================
-- 2. shops table
-- =========================================================
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

  -- vendor_catalog shops must have a vendor_code
  constraint shops_vendor_catalog_requires_vendor_code check (
    shop_type <> 'vendor_catalog' or vendor_code is not null
  ),

  -- dropship shops cannot be negotiable
  constraint shops_dropship_not_negotiable check (
    shop_type <> 'dropship' or is_negotiable = false
  )
);

-- updated_at trigger
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

-- =========================================================
-- 3. RLS
-- =========================================================
alter table public.shops enable row level security;

-- Tenant members can read their own tenant's shops
create policy "shops_select_tenant_member"
  on public.shops for select
  using (
    tenant_id in (
      select tm.tenant_id
      from public.memberships tm
      where lower(trim(tm.email)) = public.current_user_email()
        and tm.is_active = true
    )
  );

-- Tenant admin/staff can insert shops for their tenant
create policy "shops_insert_tenant_admin_staff"
  on public.shops for insert
  with check (
    tenant_id in (
      select m.tenant_id
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  );

-- Tenant admin/staff can update their tenant's shops
create policy "shops_update_tenant_admin_staff"
  on public.shops for update
  using (
    tenant_id in (
      select m.tenant_id
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role in ('admin', 'staff')
        and m.is_active = true
    )
  );

-- Only admin can delete shops
create policy "shops_delete_tenant_admin"
  on public.shops for delete
  using (
    tenant_id in (
      select m.tenant_id
      from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role = 'admin'
        and m.is_active = true
    )
  );

-- Superadmin full access
create policy "shops_superadmin_all"
  on public.shops
  using (
    exists (
      select 1 from public.memberships m
      where lower(trim(m.email)) = public.current_user_email()
        and m.role = 'superadmin'
        and m.is_active = true
    )
  );

-- =========================================================
-- 4. Seed parent module: shop_order
-- =========================================================
insert into public.modules (key, name, description, is_active, parent_module_key)
values (
  'shop_order',
  'Shop & Order',
  'Parent module for shop configuration, customer group permissions, product listings, storefront, carts, orders, and fulfillment.',
  true,
  null
)
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

-- =========================================================
-- 5. Seed submodules
-- =========================================================
insert into public.modules (key, name, description, is_active, parent_module_key)
values
  (
    'shop_config',
    'Shops',
    'Create and manage shops — type, order mode, stock display defaults, and vendor link.',
    true,
    'shop_order'
  ),
  (
    'shop_permissions',
    'Customer Access',
    'Define default shop capabilities per customer group and override them per shop.',
    true,
    'shop_order'
  ),
  (
    'shop_pricing',
    'Shop Pricing',
    'Manage product listings per shop, sell prices, minimum sell prices, and display quantity overrides.',
    true,
    'shop_order'
  ),
  (
    'shop_storefront',
    'Storefront',
    'Customer-facing browse surface — shows shops, products, and prices per group permission.',
    true,
    'shop_order'
  ),
  (
    'shop_cart',
    'Cart',
    'Per-shop cart with soft stock reservation against global_stock_allocations.',
    true,
    'shop_order'
  ),
  (
    'shop_order_mgmt',
    'Orders',
    'Place, negotiate, approve, price, confirm, and cancel shop orders.',
    true,
    'shop_order'
  ),
  (
    'shop_fulfillment',
    'Fulfillment',
    'Convert placed vendor-catalog orders to procurement lines or stock-backed orders to global invoices.',
    true,
    'shop_order'
  )
on conflict (key) do update set
  name = excluded.name,
  description = excluded.description,
  is_active = excluded.is_active,
  parent_module_key = excluded.parent_module_key;

commit;
