begin;

-- =========================================================
-- Shipment module schema + RPC + RLS
-- Admin and staff operations for app scope
-- =========================================================

create table if not exists public.shipments (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  product_conversion_rate numeric(12, 4) null,
  cargo_conversion_rate numeric(12, 4) null,
  cargo_rate numeric(12, 4) null,
  weight numeric(12, 3) null,
  received_weight numeric(12, 3) null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shipments_name_not_blank check (length(trim(name)) > 0)
);

create table if not exists public.shipment_items (
  id bigserial primary key,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  name text null,
  quantity integer not null default 0,
  barcode text null,
  product_code text null,
  product_id bigint null references public.products(id) on delete set null,
  image_url text null,
  product_weight numeric(12, 3) null,
  package_weight numeric(12, 3) null,
  price_gbp numeric(12, 2) null,
  received_quantity integer not null default 0,
  damaged_quantity integer not null default 0,
  stolen_quantity integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shipment_items_quantity_check check (quantity >= 0),
  constraint shipment_items_received_quantity_check check (received_quantity >= 0),
  constraint shipment_items_damaged_quantity_check check (damaged_quantity >= 0),
  constraint shipment_items_stolen_quantity_check check (stolen_quantity >= 0)
);

create table if not exists public.shipment_orders (
  id bigserial primary key,
  shipment_id bigint not null references public.shipments(id) on delete cascade,
  order_id bigint not null references public.orders(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shipment_orders_unique unique (shipment_id, order_id)
);

create unique index if not exists shipment_items_shipment_product_unique
  on public.shipment_items (shipment_id, product_id)
  where product_id is not null;

create index if not exists shipments_tenant_id_idx
  on public.shipments (tenant_id);

create index if not exists shipment_items_shipment_id_idx
  on public.shipment_items (shipment_id);

create index if not exists shipment_items_product_id_idx
  on public.shipment_items (product_id);

create index if not exists shipment_orders_shipment_id_idx
  on public.shipment_orders (shipment_id);

create index if not exists shipment_orders_order_id_idx
  on public.shipment_orders (order_id);

drop trigger if exists trg_shipments_set_updated_at on public.shipments;
create trigger trg_shipments_set_updated_at
before update on public.shipments
for each row
execute function public.set_updated_at();

drop trigger if exists trg_shipment_items_set_updated_at on public.shipment_items;
create trigger trg_shipment_items_set_updated_at
before update on public.shipment_items
for each row
execute function public.set_updated_at();

drop trigger if exists trg_shipment_orders_set_updated_at on public.shipment_orders;
create trigger trg_shipment_orders_set_updated_at
before update on public.shipment_orders
for each row
execute function public.set_updated_at();

create or replace function public.can_manage_shipment(p_tenant_id bigint)
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

grant execute on function public.can_manage_shipment(bigint)
to authenticated;

create or replace function public.can_manage_shipment_by_id(p_shipment_id bigint)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1
    from public.shipments s
    where s.id = p_shipment_id
      and public.can_manage_shipment(s.tenant_id)
  )
$$;

grant execute on function public.can_manage_shipment_by_id(bigint)
to authenticated;

create or replace function public.create_shipment(
  p_name text,
  p_tenant_id bigint
)
returns public.shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipments;
begin
  if not public.can_manage_shipment(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.shipments (name, tenant_id)
  values (trim(p_name), p_tenant_id)
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_shipment(text, bigint)
to authenticated;

create or replace function public.update_shipment(
  p_id bigint,
  p_field text,
  p_value text
)
returns public.shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipments;
  v_field text;
  v_value text;
begin
  select *
  into v_row
  from public.shipments
  where id = p_id;

  if v_row.id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_row.tenant_id) then
    raise exception 'not allowed';
  end if;

  v_field := lower(trim(coalesce(p_field, '')));
  v_value := trim(coalesce(p_value, ''));

  if v_field = 'name' then
    update public.shipments
    set name = v_value
    where id = p_id
    returning * into v_row;
  elsif v_field = 'product_conversion_rate' then
    update public.shipments
    set product_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'cargo_conversion_rate' then
    update public.shipments
    set cargo_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'cargo_rate' then
    update public.shipments
    set cargo_rate = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'weight' then
    update public.shipments
    set weight = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  elsif v_field = 'received_weight' then
    update public.shipments
    set received_weight = nullif(v_value, '')::numeric
    where id = p_id
    returning * into v_row;
  else
    raise exception 'invalid field';
  end if;

  return v_row;
end;
$$;

grant execute on function public.update_shipment(bigint, text, text)
to authenticated;

create or replace function public.delete_shipment(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shipments where id = p_id;
end;
$$;

grant execute on function public.delete_shipment(bigint)
to authenticated;

create or replace function public.add_shipment_item_from_product(
  p_shipment_id bigint,
  p_product_id bigint,
  p_quantity integer
)
returns public.shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
  v_product record;
  v_quantity integer;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_quantity := coalesce(p_quantity, 0);
  if v_quantity <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  select
    p.id,
    p.name,
    p.barcode,
    p.product_code,
    p.image_url,
    p.product_weight,
    p.package_weight,
    p.price_gbp
  into v_product
  from public.products p
  where p.id = p_product_id
    and p.tenant_id = v_tenant_id;

  if v_product.id is null then
    raise exception 'product not found';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp
  )
  values (
    p_shipment_id,
    v_product.name,
    v_quantity,
    v_product.barcode,
    v_product.product_code,
    v_product.id,
    v_product.image_url,
    v_product.product_weight,
    v_product.package_weight,
    v_product.price_gbp
  )
  on conflict (shipment_id, product_id) where product_id is not null
  do update
  set
    quantity = public.shipment_items.quantity + excluded.quantity,
    name = excluded.name,
    barcode = excluded.barcode,
    product_code = excluded.product_code,
    image_url = excluded.image_url,
    product_weight = excluded.product_weight,
    package_weight = excluded.package_weight,
    price_gbp = excluded.price_gbp,
    updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.add_shipment_item_from_product(bigint, bigint, integer)
to authenticated;

create or replace function public.add_shipment_item_manual(
  p_shipment_id bigint,
  p_name text default null,
  p_quantity integer default null,
  p_barcode text default null,
  p_product_code text default null,
  p_product_id bigint default null,
  p_image_url text default null,
  p_product_weight numeric default null,
  p_package_weight numeric default null,
  p_price_gbp numeric default null,
  p_received_quantity integer default null,
  p_damaged_quantity integer default null,
  p_stolen_quantity integer default null
)
returns public.shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipment_items;
  v_tenant_id bigint;
begin
  select tenant_id into v_tenant_id
  from public.shipments
  where id = p_shipment_id;

  if v_tenant_id is null then
    raise exception 'shipment not found';
  end if;

  if not public.can_manage_shipment(v_tenant_id) then
    raise exception 'not allowed';
  end if;

  insert into public.shipment_items (
    shipment_id,
    name,
    quantity,
    barcode,
    product_code,
    product_id,
    image_url,
    product_weight,
    package_weight,
    price_gbp,
    received_quantity,
    damaged_quantity,
    stolen_quantity
  )
  values (
    p_shipment_id,
    nullif(trim(coalesce(p_name, '')), ''),
    greatest(coalesce(p_quantity, 0), 0),
    nullif(trim(coalesce(p_barcode, '')), ''),
    nullif(trim(coalesce(p_product_code, '')), ''),
    p_product_id,
    nullif(trim(coalesce(p_image_url, '')), ''),
    p_product_weight,
    p_package_weight,
    p_price_gbp,
    greatest(coalesce(p_received_quantity, 0), 0),
    greatest(coalesce(p_damaged_quantity, 0), 0),
    greatest(coalesce(p_stolen_quantity, 0), 0)
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.add_shipment_item_manual(
  bigint,
  text,
  integer,
  text,
  text,
  bigint,
  text,
  numeric,
  numeric,
  numeric,
  integer,
  integer,
  integer
)
to authenticated;

create or replace function public.bulk_add_shipment_items_from_product_ids(
  p_shipment_id bigint,
  p_items jsonb
)
returns setof public.shipment_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_row public.shipment_items;
begin
  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a json array';
  end if;

  for v_entry in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(trim(coalesce(v_entry ->> 'product_id', '')), '')::bigint;
    v_quantity := coalesce(nullif(trim(coalesce(v_entry ->> 'quantity', '')), '')::integer, 0);

    if v_product_id is null or v_quantity <= 0 then
      continue;
    end if;

    select * into v_row
    from public.add_shipment_item_from_product(
      p_shipment_id,
      v_product_id,
      v_quantity
    );

    return next v_row;
  end loop;

  return;
end;
$$;

grant execute on function public.bulk_add_shipment_items_from_product_ids(bigint, jsonb)
to authenticated;

create or replace function public.delete_shipment_item_quantity(
  p_id bigint,
  p_quantity integer
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.shipment_items;
  v_next_qty integer;
begin
  select * into v_item
  from public.shipment_items
  where id = p_id;

  if v_item.id is null then
    return false;
  end if;

  if not public.can_manage_shipment_by_id(v_item.shipment_id) then
    raise exception 'not allowed';
  end if;

  if coalesce(p_quantity, 0) <= 0 then
    raise exception 'quantity must be greater than 0';
  end if;

  v_next_qty := v_item.quantity - p_quantity;

  if v_next_qty <= 0 then
    delete from public.shipment_items where id = p_id;
    return true;
  end if;

  update public.shipment_items
  set quantity = v_next_qty
  where id = p_id;

  return true;
end;
$$;

grant execute on function public.delete_shipment_item_quantity(bigint, integer)
to authenticated;

create or replace function public.bulk_delete_shipment_items_by_product_id(
  p_shipment_id bigint,
  p_items jsonb
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_entry jsonb;
  v_product_id bigint;
  v_quantity integer;
  v_item_id bigint;
  v_deleted_count integer := 0;
begin
  if not public.can_manage_shipment_by_id(p_shipment_id) then
    raise exception 'not allowed';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' then
    raise exception 'p_items must be a json array';
  end if;

  for v_entry in
    select value
    from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(trim(coalesce(v_entry ->> 'product_id', '')), '')::bigint;
    v_quantity := coalesce(nullif(trim(coalesce(v_entry ->> 'quantity', '')), '')::integer, 0);

    if v_product_id is null or v_quantity <= 0 then
      continue;
    end if;

    select id into v_item_id
    from public.shipment_items
    where shipment_id = p_shipment_id
      and product_id = v_product_id;

    if v_item_id is null then
      continue;
    end if;

    perform public.delete_shipment_item_quantity(v_item_id, v_quantity);
    v_deleted_count := v_deleted_count + 1;
  end loop;

  return v_deleted_count;
end;
$$;

grant execute on function public.bulk_delete_shipment_items_by_product_id(bigint, jsonb)
to authenticated;

create or replace function public.create_shipment_order(
  p_shipment_id bigint,
  p_order_id bigint
)
returns public.shipment_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipment_orders;
begin
  if not public.can_manage_shipment_by_id(p_shipment_id) then
    raise exception 'not allowed';
  end if;

  insert into public.shipment_orders (shipment_id, order_id)
  values (p_shipment_id, p_order_id)
  on conflict (shipment_id, order_id)
  do update set updated_at = now()
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_shipment_order(bigint, bigint)
to authenticated;

create or replace function public.update_shipment_order(
  p_id bigint,
  p_shipment_id bigint,
  p_order_id bigint
)
returns public.shipment_orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipment_orders;
begin
  if not public.can_manage_shipment_by_id(p_shipment_id) then
    raise exception 'not allowed';
  end if;

  update public.shipment_orders
  set
    shipment_id = p_shipment_id,
    order_id = p_order_id
  where id = p_id
  returning * into v_row;

  if v_row.id is null then
    raise exception 'shipment_order not found';
  end if;

  return v_row;
end;
$$;

grant execute on function public.update_shipment_order(bigint, bigint, bigint)
to authenticated;

create or replace function public.delete_shipment_order(p_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shipment_id bigint;
begin
  select shipment_id into v_shipment_id
  from public.shipment_orders
  where id = p_id;

  if v_shipment_id is null then
    raise exception 'shipment_order not found';
  end if;

  if not public.can_manage_shipment_by_id(v_shipment_id) then
    raise exception 'not allowed';
  end if;

  delete from public.shipment_orders where id = p_id;
end;
$$;

grant execute on function public.delete_shipment_order(bigint)
to authenticated;

alter table public.shipments enable row level security;
alter table public.shipment_items enable row level security;
alter table public.shipment_orders enable row level security;

drop policy if exists shipments_select on public.shipments;
create policy shipments_select
on public.shipments
for select
to authenticated
using (public.can_manage_shipment(tenant_id));

drop policy if exists shipments_insert on public.shipments;
create policy shipments_insert
on public.shipments
for insert
to authenticated
with check (public.can_manage_shipment(tenant_id));

drop policy if exists shipments_update on public.shipments;
create policy shipments_update
on public.shipments
for update
to authenticated
using (public.can_manage_shipment(tenant_id))
with check (public.can_manage_shipment(tenant_id));

drop policy if exists shipments_delete on public.shipments;
create policy shipments_delete
on public.shipments
for delete
to authenticated
using (public.can_manage_shipment(tenant_id));

drop policy if exists shipment_items_select on public.shipment_items;
create policy shipment_items_select
on public.shipment_items
for select
to authenticated
using (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists shipment_items_insert on public.shipment_items;
create policy shipment_items_insert
on public.shipment_items
for insert
to authenticated
with check (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists shipment_items_update on public.shipment_items;
create policy shipment_items_update
on public.shipment_items
for update
to authenticated
using (public.can_manage_shipment_by_id(shipment_id))
with check (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists shipment_items_delete on public.shipment_items;
create policy shipment_items_delete
on public.shipment_items
for delete
to authenticated
using (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists shipment_orders_select on public.shipment_orders;
create policy shipment_orders_select
on public.shipment_orders
for select
to authenticated
using (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists shipment_orders_insert on public.shipment_orders;
create policy shipment_orders_insert
on public.shipment_orders
for insert
to authenticated
with check (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists shipment_orders_update on public.shipment_orders;
create policy shipment_orders_update
on public.shipment_orders
for update
to authenticated
using (public.can_manage_shipment_by_id(shipment_id))
with check (public.can_manage_shipment_by_id(shipment_id));

drop policy if exists shipment_orders_delete on public.shipment_orders;
create policy shipment_orders_delete
on public.shipment_orders
for delete
to authenticated
using (public.can_manage_shipment_by_id(shipment_id));

grant select, insert, update, delete on table public.shipments to authenticated;
grant select, insert, update, delete on table public.shipment_items to authenticated;
grant select, insert, update, delete on table public.shipment_orders to authenticated;

grant usage, select on sequence public.shipments_id_seq to authenticated;
grant usage, select on sequence public.shipment_items_id_seq to authenticated;
grant usage, select on sequence public.shipment_orders_id_seq to authenticated;

commit;
