begin;

-- =========================================================
-- TABLES
-- =========================================================

create table if not exists public.carts (
  id bigserial primary key,
  tenant_id bigint not null,
  store_id bigint null,
  customer_group_id bigint null,
  can_see_price boolean not null default false,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint carts_tenant_id_fkey
    foreign key (tenant_id)
    references public.tenants (id)
    on delete cascade,

  constraint carts_customer_group_id_fkey
    foreign key (customer_group_id)
    references public.customer_groups (id)
    on delete set null
);

create table if not exists public.cart_items (
  id bigserial primary key,
  cart_id bigint not null,
  product_id bigint null,

  name text not null,
  image_url text null,
  price_gbp numeric(12, 2) null,

  quantity integer not null default 1,
  minimum_quantity integer not null default 1,

  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint cart_items_cart_id_fkey
    foreign key (cart_id)
    references public.carts (id)
    on delete cascade,

  constraint cart_items_product_id_fkey
    foreign key (product_id)
    references public.products (id)
    on delete set null,

  constraint cart_items_quantity_check
    check (quantity > 0),

  constraint cart_items_minimum_quantity_check
    check (minimum_quantity > 0),

  constraint cart_items_cart_product_unique
    unique (cart_id, product_id)
);

-- =========================================================
-- INDEXES
-- =========================================================

create index if not exists carts_tenant_id_idx
  on public.carts using btree (tenant_id);

create index if not exists carts_customer_group_id_idx
  on public.carts using btree (customer_group_id);

create index if not exists carts_store_id_idx
  on public.carts using btree (store_id);

create index if not exists cart_items_cart_id_idx
  on public.cart_items using btree (cart_id);

create index if not exists cart_items_product_id_idx
  on public.cart_items using btree (product_id);

create index if not exists cart_items_name_idx
  on public.cart_items using btree (name);

-- =========================================================
-- UPDATED_AT TRIGGERS
-- =========================================================

drop trigger if exists trg_carts_set_updated_at on public.carts;
create trigger trg_carts_set_updated_at
before update on public.carts
for each row
execute function public.set_updated_at();

drop trigger if exists trg_cart_items_set_updated_at on public.cart_items;
create trigger trg_cart_items_set_updated_at
before update on public.cart_items
for each row
execute function public.set_updated_at();

-- =========================================================
-- AUTHORIZATION HELPERS
-- =========================================================

create or replace function public.has_active_tenant_membership(
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
    from public.memberships m
    where lower(trim(m.email)) = public.current_user_email()
      and m.tenant_id = p_tenant_id
      and m.is_active = true
  )
  or public.is_superadmin();
$$;

create or replace function public.can_access_cart(
  p_cart_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.carts c
    where c.id = p_cart_id
      and (
        public.has_active_tenant_membership(c.tenant_id)
        or (
          c.store_id is not null
          and public.can_customer_access_store(c.store_id)
        )
        or (
          c.customer_group_id is not null
          and exists (
            select 1
            from public.customer_group_members cgm
            where cgm.customer_group_id = c.customer_group_id
              and lower(trim(cgm.email)) = public.current_user_email()
              and cgm.is_active = true
          )
        )
      )
  );
$$;

create or replace function public.can_insert_cart(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_store_id bigint default null
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select
    public.has_active_tenant_membership(p_tenant_id)
    or (
      p_store_id is not null
      and exists (
        select 1
        from public.stores s
        where s.id = p_store_id
          and s.tenant_id = p_tenant_id
          and public.can_customer_access_store(s.id)
      )
    )
    or (
      p_customer_group_id is not null
      and exists (
        select 1
        from public.customer_groups cg
        join public.customer_group_members cgm
          on cgm.customer_group_id = cg.id
        where cg.id = p_customer_group_id
          and cg.tenant_id = p_tenant_id
          and lower(trim(cgm.email)) = public.current_user_email()
          and cgm.is_active = true
      )
    );
$$;

create or replace function public.can_access_cart_item(
  p_cart_item_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.cart_items ci
    join public.carts c on c.id = ci.cart_id
    where ci.id = p_cart_item_id
      and (
        public.has_active_tenant_membership(c.tenant_id)
        or (
          c.store_id is not null
          and public.can_customer_access_store(c.store_id)
        )
        or (
          c.customer_group_id is not null
          and exists (
            select 1
            from public.customer_group_members cgm
            where cgm.customer_group_id = c.customer_group_id
              and lower(trim(cgm.email)) = public.current_user_email()
              and cgm.is_active = true
          )
        )
      )
  );
$$;

create or replace function public.can_insert_cart_item(
  p_cart_id bigint
)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select public.can_access_cart(p_cart_id);
$$;

-- =========================================================
-- RLS
-- =========================================================

alter table public.carts enable row level security;
alter table public.cart_items enable row level security;

drop policy if exists carts_select on public.carts;
create policy carts_select
on public.carts
for select
to authenticated
using (
  public.can_access_cart(id)
);

drop policy if exists carts_insert on public.carts;
create policy carts_insert
on public.carts
for insert
to authenticated
with check (
  public.can_insert_cart(tenant_id, customer_group_id, store_id)
);

drop policy if exists carts_update on public.carts;
create policy carts_update
on public.carts
for update
to authenticated
using (
  public.can_access_cart(id)
)
with check (
  public.can_insert_cart(tenant_id, customer_group_id, store_id)
);

drop policy if exists carts_delete on public.carts;
create policy carts_delete
on public.carts
for delete
to authenticated
using (
  public.can_access_cart(id)
);

drop policy if exists cart_items_select on public.cart_items;
create policy cart_items_select
on public.cart_items
for select
to authenticated
using (
  public.can_access_cart_item(id)
);

drop policy if exists cart_items_insert on public.cart_items;
create policy cart_items_insert
on public.cart_items
for insert
to authenticated
with check (
  public.can_insert_cart_item(cart_id)
);

drop policy if exists cart_items_update on public.cart_items;
create policy cart_items_update
on public.cart_items
for update
to authenticated
using (
  public.can_access_cart_item(id)
)
with check (
  public.can_insert_cart_item(cart_id)
);

drop policy if exists cart_items_delete on public.cart_items;
create policy cart_items_delete
on public.cart_items
for delete
to authenticated
using (
  public.can_access_cart_item(id)
);

-- =========================================================
-- RPC: BASIC GET BY ID
-- =========================================================

create or replace function public.get_cart(
  p_cart_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.can_access_cart(p_cart_id) then
    raise exception 'not authorized to access this cart';
  end if;

  select jsonb_build_object(
    'cart',
    jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'store_id', c.store_id,
      'customer_group_id', c.customer_group_id,
      'can_see_price', c.can_see_price,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'name', ci.name,
            'image_url', ci.image_url,
            'price_gbp', ci.price_gbp,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'created_at', ci.created_at,
            'updated_at', ci.updated_at
          )
          order by ci.id
        )
        from public.cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.carts c
  where c.id = p_cart_id;

  if v_result is null then
    raise exception 'cart not found';
  end if;

  return v_result;
end;
$$;

-- =========================================================
-- RPC: DETAILED GET BY ID
-- =========================================================

create or replace function public.get_cart_details(
  p_cart_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if not public.can_access_cart(p_cart_id) then
    raise exception 'not authorized to access this cart';
  end if;

  select jsonb_build_object(
    'cart',
    jsonb_build_object(
      'id', c.id,
      'tenant_id', c.tenant_id,
      'store_id', c.store_id,
      'customer_group_id', c.customer_group_id,
      'can_see_price', c.can_see_price,
      'created_at', c.created_at,
      'updated_at', c.updated_at
    ),
    'items',
    coalesce(
      (
        select jsonb_agg(
          jsonb_build_object(
            'id', ci.id,
            'cart_id', ci.cart_id,
            'product_id', ci.product_id,
            'name', ci.name,
            'image_url', ci.image_url,
            'price_gbp', ci.price_gbp,
            'quantity', ci.quantity,
            'minimum_quantity', ci.minimum_quantity,
            'created_at', ci.created_at,
            'updated_at', ci.updated_at,
            'product',
            case
              when p.id is null then null
              else jsonb_build_object(
                'id', p.id,
                'tenant_id', p.tenant_id,
                'product_code', p.product_code,
                'barcode', p.barcode,
                'name', p.name,
                'price_gbp', p.price_gbp,
                'country_of_origin', p.country_of_origin,
                'brand', p.brand,
                'category', p.category,
                'available_units', p.available_units,
                'tariff_code', p.tariff_code,
                'languages', p.languages,
                'batch_code_manufacture_date', p.batch_code_manufacture_date,
                'image_url', p.image_url,
                'expire_date', p.expire_date,
                'minimum_order_quantity', p.minimum_order_quantity,
                'product_weight', p.product_weight,
                'package_weight', p.package_weight,
                'is_available', p.is_available,
                'vendor_code', p.vendor_code,
                'market_code', p.market_code,
                'created_at', p.created_at,
                'updated_at', p.updated_at
              )
            end
          )
          order by ci.id
        )
        from public.cart_items ci
        left join public.products p
          on p.id = ci.product_id
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  into v_result
  from public.carts c
  where c.id = p_cart_id;

  if v_result is null then
    raise exception 'cart not found';
  end if;

  return v_result;
end;
$$;

comment on table public.carts is
'Shopping cart header table. Stores tenant, store, customer group and visibility settings.';

comment on table public.cart_items is
'Shopping cart line items. Stores snapshot values plus optional product reference.';

comment on function public.get_cart(bigint) is
'Returns a cart and its cart items without product join.';

comment on function public.get_cart_details(bigint) is
'Returns a cart and its cart items with nested product details.';

commit;
