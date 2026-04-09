begin;

create table if not exists public.products (
  id bigserial primary key,
  tenant_id bigint null references public.tenants(id) on delete cascade,

  product_code text null,
  barcode text null,
  name text null,
  price_gbp numeric(12,2) null,
  country_of_origin text null,
  brand text null,
  category text null,
  available_units integer null,
  tariff_code text null,
  languages text null,
  batch_code_manufacture_date date null,
  image_url text null,
  expire_date date null,
  minimum_order_quantity integer null,
  product_weight numeric(12,3) null,
  package_weight numeric(12,3) null,
  vendor_id bigint null references public.vendors(id) on delete set null,
  market_id bigint null references public.markets(id) on delete set null,
  is_available boolean null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists products_tenant_id_idx
  on public.products (tenant_id);

create index if not exists products_name_idx
  on public.products (name);

create index if not exists products_barcode_idx
  on public.products (barcode);

create index if not exists products_product_code_idx
  on public.products (product_code);

create index if not exists products_brand_idx
  on public.products (brand);

create index if not exists products_category_idx
  on public.products (category);

create index if not exists products_vendor_id_idx
  on public.products (vendor_id);

create index if not exists products_market_id_idx
  on public.products (market_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_products_set_updated_at on public.products;

create trigger trg_products_set_updated_at
before update on public.products
for each row
execute function public.set_updated_at();

grant select, insert, update, delete on public.products to authenticated;
grant usage, select on sequence public.products_id_seq to authenticated;

create or replace function public.can_manage_products(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff')
    )
$$;

create or replace function public.can_view_products_internal(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.is_superadmin()
    or exists (
      select 1
      from public.memberships m
      where m.tenant_id = p_tenant_id
        and lower(trim(m.email)) = public.current_user_email()
        and m.is_active = true
        and m.role in ('admin', 'staff', 'viewer')
    )
$$;

create or replace function public.can_view_products_customer(
  p_tenant_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.customer_group_members cgm
    join public.customer_groups cg
      on cg.id = cgm.customer_group_id
    where cg.tenant_id = p_tenant_id
      and lower(trim(cgm.email)) = public.current_user_email()
      and cgm.is_active = true
      and cg.is_active = true
  )
$$;

grant execute on function public.can_manage_products(bigint) to authenticated;
grant execute on function public.can_view_products_internal(bigint) to authenticated;
grant execute on function public.can_view_products_customer(bigint) to authenticated;

alter table public.products enable row level security;

drop policy if exists "products_select" on public.products;
create policy "products_select"
on public.products
for select
to authenticated
using (
  public.can_view_products_internal(tenant_id)
  or public.can_view_products_customer(tenant_id)
);

drop policy if exists "products_insert" on public.products;
create policy "products_insert"
on public.products
for insert
to authenticated
with check (
  public.can_manage_products(tenant_id)
);

drop policy if exists "products_update" on public.products;
create policy "products_update"
on public.products
for update
to authenticated
using (
  public.can_manage_products(tenant_id)
)
with check (
  public.can_manage_products(tenant_id)
);

drop policy if exists "products_delete" on public.products;
create policy "products_delete"
on public.products
for delete
to authenticated
using (
  public.can_manage_products(tenant_id)
);

commit;
