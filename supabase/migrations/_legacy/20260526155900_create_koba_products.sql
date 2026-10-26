-- Create koba_brands, koba_categories, and koba_products tables to stage products
begin;

create table if not exists public.koba_brands (
    id bigserial primary key,
    tenant_id bigint not null references public.tenants(id) on delete cascade,
    name text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint uq_koba_brands_name unique (tenant_id, name)
);

create table if not exists public.koba_categories (
    id bigserial primary key,
    tenant_id bigint not null references public.tenants(id) on delete cascade,
    name text not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint uq_koba_categories_name unique (tenant_id, name)
);

create table if not exists public.koba_products (
    id uuid default gen_random_uuid() primary key,
    tenant_id bigint not null references public.tenants(id) on delete cascade,
    source_type text not null check (source_type in ('retail', 'wholesale')),
    source_id text not null,
    name text not null,
    sku text,
    barcode text,
    slug text,
    permalink text,
    description text,
    stock_quantity integer not null default 0,
    in_stock boolean not null default true,
    price numeric(12, 2) not null default 0.00,
    regular_price numeric(12, 2),
    sale_price numeric(12, 2),
    currency text default 'GBP',
    commission_percentage numeric(5, 2),
    commission numeric(12, 2),
    brand_id bigint references public.koba_brands(id) on delete set null,
    category_id bigint references public.koba_categories(id) on delete set null,
    image_url text,
    raw_data jsonb not null,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    constraint uq_koba_products_source unique (tenant_id, source_type, source_id)
);

create index if not exists koba_brands_tenant_idx on public.koba_brands(tenant_id);
create index if not exists koba_categories_tenant_idx on public.koba_categories(tenant_id);
create index if not exists koba_products_tenant_id_idx on public.koba_products(tenant_id);
create index if not exists koba_products_sku_idx on public.koba_products(sku);
create index if not exists koba_products_barcode_idx on public.koba_products(barcode);
create index if not exists koba_products_source_type_idx on public.koba_products(source_type);

-- Triggers for set_updated_at
drop trigger if exists trg_koba_brands_updated_at on public.koba_brands;
create trigger trg_koba_brands_updated_at
before update on public.koba_brands
for each row execute function public.set_updated_at();

drop trigger if exists trg_koba_categories_updated_at on public.koba_categories;
create trigger trg_koba_categories_updated_at
before update on public.koba_categories
for each row execute function public.set_updated_at();

drop trigger if exists trg_koba_products_updated_at on public.koba_products;
create trigger trg_koba_products_updated_at
before update on public.koba_products
for each row execute function public.set_updated_at();

-- RLS Configuration
alter table public.koba_brands enable row level security;
alter table public.koba_categories enable row level security;
alter table public.koba_products enable row level security;

-- Brand policies
drop policy if exists "koba_brands_admin_all" on public.koba_brands;
create policy "koba_brands_admin_all"
on public.koba_brands
for all
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
)
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

-- Category policies
drop policy if exists "koba_categories_admin_all" on public.koba_categories;
create policy "koba_categories_admin_all"
on public.koba_categories
for all
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
)
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

-- Products policies
drop policy if exists "koba_products_admin_all" on public.koba_products;
create policy "koba_products_admin_all"
on public.koba_products
for all
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
)
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

-- Grants
grant select, insert, update, delete on table public.koba_brands to service_role;
grant select, insert, update, delete on table public.koba_brands to authenticated;

grant select, insert, update, delete on table public.koba_categories to service_role;
grant select, insert, update, delete on table public.koba_categories to authenticated;

grant select, insert, update, delete on table public.koba_products to service_role;
grant select, insert, update, delete on table public.koba_products to authenticated;

commit;
