begin;

-- ============================================================
-- 1. Drop old RPCs first because they depend on old columns
-- ============================================================

drop function if exists public.place_koba_order(bigint, text, text, text, text, text, text, boolean);
drop function if exists public.get_koba_cart(bigint, text);
drop function if exists public.list_koba_orders(bigint, text, integer, integer, text);

-- ============================================================
-- 2. Drop old RLS policies first because they depend on user_email
-- ============================================================

drop policy if exists koba_carts_select on public.koba_carts;
drop policy if exists koba_carts_insert on public.koba_carts;
drop policy if exists koba_carts_update on public.koba_carts;
drop policy if exists koba_carts_delete on public.koba_carts;

drop policy if exists koba_cart_items_select on public.koba_cart_items;
drop policy if exists koba_cart_items_insert on public.koba_cart_items;
drop policy if exists koba_cart_items_update on public.koba_cart_items;
drop policy if exists koba_cart_items_delete on public.koba_cart_items;

drop policy if exists koba_orders_select on public.koba_orders;
drop policy if exists koba_orders_insert on public.koba_orders;
drop policy if exists koba_orders_update on public.koba_orders;
drop policy if exists koba_orders_delete on public.koba_orders;

drop policy if exists koba_order_items_select on public.koba_order_items;
drop policy if exists koba_order_items_insert on public.koba_order_items;
drop policy if exists koba_order_items_update on public.koba_order_items;
drop policy if exists koba_order_items_delete on public.koba_order_items;

-- ============================================================
-- 3. Drop old helper functions
-- ============================================================

drop function if exists public.koba_cart_owner(bigint);
drop function if exists public.koba_order_owner(bigint);

-- ============================================================
-- 4. Update koba_carts
-- ============================================================

alter table public.koba_carts
  drop constraint if exists uq_koba_carts_user_market;

alter table public.koba_carts
  drop constraint if exists koba_carts_status_check;

drop index if exists public.koba_carts_user_email_idx;
drop index if exists public.koba_carts_market_id_idx;

alter table public.koba_carts
  drop column if exists user_email,
  drop column if exists market_id,
  drop column if exists status,
  add column if not exists customer_group_id bigint null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'koba_carts_customer_group_id_fkey'
  ) then
    alter table public.koba_carts
      add constraint koba_carts_customer_group_id_fkey
      foreign key (customer_group_id)
      references public.customer_groups(id)
      on delete set null;
  end if;
end $$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'uq_koba_carts_customer_group'
  ) then
    alter table public.koba_carts
      add constraint uq_koba_carts_customer_group
      unique (tenant_id, customer_group_id);
  end if;
end $$;

create index if not exists koba_carts_customer_group_id_idx
on public.koba_carts(customer_group_id);

-- ============================================================
-- 5. Update koba_orders
-- ============================================================

drop index if exists public.koba_orders_user_email_idx;
drop index if exists public.koba_orders_market_id_idx;

alter table public.koba_orders
  drop column if exists user_email,
  drop column if exists market_id,
  add column if not exists customer_group_id bigint null;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'koba_orders_customer_group_id_fkey'
  ) then
    alter table public.koba_orders
      add constraint koba_orders_customer_group_id_fkey
      foreign key (customer_group_id)
      references public.customer_groups(id)
      on delete set null;
  end if;
end $$;

create index if not exists koba_orders_customer_group_id_idx
on public.koba_orders(customer_group_id);

-- ============================================================
-- 6. New helper functions
-- ============================================================

create or replace function public.koba_cart_allowed(p_cart_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.koba_carts c
    where c.id = p_cart_id
      and (
        public.is_superadmin()
        or public.is_tenant_admin(c.tenant_id)
      )
  );
$$;

create or replace function public.koba_order_allowed(p_order_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.koba_orders o
    where o.id = p_order_id
      and (
        public.is_superadmin()
        or public.is_tenant_admin(o.tenant_id)
      )
  );
$$;

-- ============================================================
-- 7. Recreate simplified RLS
-- ============================================================

alter table public.koba_carts enable row level security;
alter table public.koba_cart_items enable row level security;
alter table public.koba_orders enable row level security;
alter table public.koba_order_items enable row level security;

create policy koba_carts_select
on public.koba_carts
for select
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_carts_insert
on public.koba_carts
for insert
to authenticated
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_carts_update
on public.koba_carts
for update
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
)
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_carts_delete
on public.koba_carts
for delete
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_cart_items_select
on public.koba_cart_items
for select
to authenticated
using (public.koba_cart_allowed(cart_id));

create policy koba_cart_items_insert
on public.koba_cart_items
for insert
to authenticated
with check (public.koba_cart_allowed(cart_id));

create policy koba_cart_items_update
on public.koba_cart_items
for update
to authenticated
using (public.koba_cart_allowed(cart_id))
with check (public.koba_cart_allowed(cart_id));

create policy koba_cart_items_delete
on public.koba_cart_items
for delete
to authenticated
using (public.koba_cart_allowed(cart_id));

create policy koba_orders_select
on public.koba_orders
for select
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_orders_insert
on public.koba_orders
for insert
to authenticated
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_orders_update
on public.koba_orders
for update
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
)
with check (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_orders_delete
on public.koba_orders
for delete
to authenticated
using (
  public.is_superadmin()
  or public.is_tenant_admin(tenant_id)
);

create policy koba_order_items_select
on public.koba_order_items
for select
to authenticated
using (public.koba_order_allowed(order_id));

create policy koba_order_items_insert
on public.koba_order_items
for insert
to authenticated
with check (public.koba_order_allowed(order_id));

create policy koba_order_items_update
on public.koba_order_items
for update
to authenticated
using (public.koba_order_allowed(order_id))
with check (public.koba_order_allowed(order_id));

create policy koba_order_items_delete
on public.koba_order_items
for delete
to authenticated
using (public.koba_order_allowed(order_id));

-- ============================================================
-- 8. New RPC: get_koba_cart
-- ============================================================

create function public.get_koba_cart(
  p_tenant_id bigint,
  p_customer_group_id bigint default null
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'cart',
    to_jsonb(c),
    'items',
    coalesce(
      (
        select jsonb_agg(to_jsonb(ci) order by ci.id)
        from public.koba_cart_items ci
        where ci.cart_id = c.id
      ),
      '[]'::jsonb
    )
  )
  from public.koba_carts c
  where c.tenant_id = p_tenant_id
    and c.customer_group_id is not distinct from p_customer_group_id
  limit 1;
$$;

grant execute on function public.get_koba_cart(bigint, bigint)
to authenticated, service_role;

-- ============================================================
-- 9. New RPC: place_koba_order
-- ============================================================

create function public.place_koba_order(
  p_tenant_id bigint,
  p_customer_group_id bigint default null,
  p_shipping_name text default null,
  p_shipping_phone text default null,
  p_shipping_district text default null,
  p_shipping_thana text default null,
  p_shipping_address text default null,
  p_free_delivery boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cart_id bigint;
  v_order_id bigint;
  v_subtotal numeric(12,2) := 0;
  v_commission numeric(12,2) := 0;
  v_count integer := 0;
begin
  if not (
    public.is_superadmin()
    or public.is_tenant_admin(p_tenant_id)
  ) then
    raise exception 'not allowed';
  end if;

  select id into v_cart_id
  from public.koba_carts
  where tenant_id = p_tenant_id
    and customer_group_id is not distinct from p_customer_group_id
  limit 1;

  if v_cart_id is null then
    raise exception 'no cart found for this customer group';
  end if;

  select count(*) into v_count
  from public.koba_cart_items
  where cart_id = v_cart_id;

  if v_count = 0 then
    raise exception 'cart is empty';
  end if;

  select
    coalesce(sum(coalesce(unit_price_gbp, 0) * quantity), 0),
    coalesce(sum(coalesce(commission, 0) * quantity), 0),
    count(*)
  into v_subtotal, v_commission, v_count
  from public.koba_cart_items
  where cart_id = v_cart_id;

  insert into public.koba_orders (
    tenant_id,
    customer_group_id,
    shipping_name,
    shipping_phone,
    shipping_district,
    shipping_thana,
    shipping_address,
    free_delivery,
    subtotal_gbp,
    total_commission,
    item_count,
    status
  ) values (
    p_tenant_id,
    p_customer_group_id,
    p_shipping_name,
    p_shipping_phone,
    p_shipping_district,
    p_shipping_thana,
    p_shipping_address,
    p_free_delivery,
    v_subtotal,
    v_commission,
    v_count,
    'pending'
  )
  returning id into v_order_id;

  insert into public.koba_order_items (
    order_id,
    product_id,
    product_code,
    barcode,
    name,
    brand,
    image_url,
    case_size,
    unit_price_gbp,
    commission,
    commission_percentage,
    quantity
  )
  select
    v_order_id,
    product_id,
    product_code,
    barcode,
    name,
    brand,
    image_url,
    case_size,
    unit_price_gbp,
    commission,
    commission_percentage,
    quantity
  from public.koba_cart_items
  where cart_id = v_cart_id;

  delete from public.koba_cart_items
  where cart_id = v_cart_id;

  return jsonb_build_object(
    'order_id', v_order_id,
    'customer_group_id', p_customer_group_id,
    'item_count', v_count,
    'subtotal_gbp', v_subtotal,
    'total_commission', v_commission,
    'status', 'pending'
  );
end;
$$;

grant execute on function public.place_koba_order(
  bigint, bigint, text, text, text, text, text, boolean
)
to authenticated, service_role;

-- ============================================================
-- 10. New RPC: list_koba_orders
-- ============================================================

create function public.list_koba_orders(
  p_tenant_id bigint,
  p_customer_group_id bigint default null,
  p_page integer default 1,
  p_page_size integer default 20,
  p_status text default null
)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  with filtered as (
    select
      o.*,
      count(*) over() as total_count
    from public.koba_orders o
    where o.tenant_id = p_tenant_id
      and (
        public.is_superadmin()
        or public.is_tenant_admin(p_tenant_id)
      )
      and (
        p_customer_group_id is null
        or o.customer_group_id = p_customer_group_id
      )
      and (
        p_status is null
        or o.status::text = p_status
      )
  ),
  paged as (
    select *
    from filtered
    order by created_at desc, id desc
    offset (greatest(coalesce(p_page, 1), 1) - 1) * greatest(coalesce(p_page_size, 20), 1)
    limit greatest(coalesce(p_page_size, 20), 1)
  )
  select jsonb_build_object(
    'data',
    coalesce(jsonb_agg(to_jsonb(paged) - 'total_count'), '[]'::jsonb),
    'meta',
    jsonb_build_object(
      'total', coalesce(max(paged.total_count), 0),
      'page', greatest(coalesce(p_page, 1), 1),
      'page_size', greatest(coalesce(p_page_size, 20), 1),
      'total_pages',
        case
          when coalesce(max(paged.total_count), 0) = 0 then 1
          else ceil(
            coalesce(max(paged.total_count), 0)::numeric
            / greatest(coalesce(p_page_size, 20), 1)
          )::int
        end
    )
  )
  from paged;
$$;

grant execute on function public.list_koba_orders(
  bigint, bigint, integer, integer, text
)
to authenticated, service_role;

-- ============================================================
-- 11. Comments
-- ============================================================

comment on table public.koba_carts is
'Koba carts scoped by tenant and customer group.';

comment on table public.koba_orders is
'Koba orders scoped by tenant and customer group.';

commit;