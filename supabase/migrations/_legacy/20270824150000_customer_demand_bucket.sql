-- Customer demand bucket — see doc/shop_order/DEMAND_BUCKET.md
begin;

-- 1. Types
do $$ begin
  create type public.demand_bucket_status as enum ('open', 'popped', 'cancelled');
exception
  when duplicate_object then null;
end $$;

do $$ begin
  create type public.demand_bucket_source_type as enum (
    'shop_order_item',
    'pbc_costing_item',
    'manual'
  );
exception
  when duplicate_object then null;
end $$;

-- 2. Table
create table if not exists public.customer_demand_bucket_items (
  id bigint generated always as identity primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  billing_profile_id bigint not null references public.billing_profiles(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  source_type public.demand_bucket_source_type not null,
  source_id bigint,
  name text not null,
  image_url text,
  barcode text,
  product_code text,
  note text,
  quantity integer not null default 1,
  status public.demand_bucket_status not null default 'open',
  popped_at timestamptz,
  popped_into_type text,
  popped_into_id bigint,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_demand_bucket_items_quantity_check check (quantity > 0)
);

create index if not exists idx_demand_bucket_open_profile
  on public.customer_demand_bucket_items (tenant_id, billing_profile_id)
  where status = 'open';

create index if not exists idx_demand_bucket_popped_purge
  on public.customer_demand_bucket_items (popped_at)
  where status = 'popped';

create index if not exists idx_demand_bucket_source
  on public.customer_demand_bucket_items (source_type, source_id)
  where source_id is not null;

drop trigger if exists trg_customer_demand_bucket_items_set_updated_at
  on public.customer_demand_bucket_items;

create trigger trg_customer_demand_bucket_items_set_updated_at
  before update on public.customer_demand_bucket_items
  for each row execute function public.set_updated_at();

alter table public.customer_demand_bucket_items enable row level security;

drop policy if exists customer_demand_bucket_items_tenant_isolation
  on public.customer_demand_bucket_items;

create policy customer_demand_bucket_items_tenant_isolation
  on public.customer_demand_bucket_items
  using (
    tenant_id = nullif(current_setting('app.current_tenant_id', true), '')::bigint
  );

grant select, insert, update, delete on table public.customer_demand_bucket_items to authenticated;
grant all on table public.customer_demand_bucket_items to service_role;
grant usage, select on sequence public.customer_demand_bucket_items_id_seq to authenticated;
grant all on sequence public.customer_demand_bucket_items_id_seq to service_role;

-- 3. Access helper
create or replace function public.can_access_demand_bucket_profile(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_staff_only boolean default false
)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_profile record;
  v_is_parent boolean;
begin
  if p_tenant_id is null or p_billing_profile_id is null then
    return false;
  end if;

  select bp.id, bp.tenant_id, bp.customer_group_id
  into v_profile
  from public.billing_profiles bp
  where bp.id = p_billing_profile_id;

  if not found then
    return false;
  end if;

  if v_profile.tenant_id <> p_tenant_id then
    if not exists (
      select 1
      from public.tenants t
      where t.id = v_profile.tenant_id
        and t.parent_id = p_tenant_id
    ) then
      return false;
    end if;
  end if;

  select (t.parent_id is null) into v_is_parent
  from public.tenants t
  where t.id = p_tenant_id;

  if coalesce(v_is_parent, false) then
    if public.user_can_manage_parent_tenant(p_tenant_id) then
      return true;
    end if;
  elsif public.is_tenant_staff(p_tenant_id)
     or public.is_tenant_staff(v_profile.tenant_id) then
    return true;
  end if;

  if p_staff_only then
    return false;
  end if;

  if v_profile.customer_group_id is not null
     and public.is_customer_group_member(v_profile.customer_group_id) then
    return exists (
      select 1
      from public.customer_groups cg
      where cg.id = v_profile.customer_group_id
        and cg.tenant_id = p_tenant_id
        and cg.is_active = true
    );
  end if;

  return false;
end;
$$;

-- 4. Internal add (no auth — callers must validate)
create or replace function public.add_demand_bucket_item_internal(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_product_id bigint,
  p_source_type public.demand_bucket_source_type,
  p_source_id bigint default null,
  p_snapshot jsonb default '{}'::jsonb,
  p_quantity integer default 1
)
returns public.customer_demand_bucket_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.customer_demand_bucket_items;
  v_name text;
  v_image_url text;
  v_barcode text;
  v_product_code text;
  v_note text;
  v_quantity integer;
begin
  if p_tenant_id is null or p_billing_profile_id is null or p_product_id is null then
    raise exception 'tenant_id, billing_profile_id, and product_id are required';
  end if;

  v_quantity := greatest(coalesce(p_quantity, 1), 1);

  v_name := nullif(trim(coalesce(p_snapshot->>'name', '')), '');
  v_image_url := nullif(trim(coalesce(p_snapshot->>'image_url', '')), '');
  v_barcode := nullif(trim(coalesce(p_snapshot->>'barcode', '')), '');
  v_product_code := nullif(trim(coalesce(p_snapshot->>'product_code', '')), '');
  v_note := nullif(trim(coalesce(p_snapshot->>'note', '')), '');

  if v_name is null then
    select
      coalesce(p.name, 'Item'),
      p.image_url,
      p.barcode,
      p.product_code
    into v_name, v_image_url, v_barcode, v_product_code
    from public.products p
    where p.id = p_product_id;
  end if;

  insert into public.customer_demand_bucket_items (
    tenant_id,
    billing_profile_id,
    product_id,
    source_type,
    source_id,
    name,
    image_url,
    barcode,
    product_code,
    note,
    quantity,
    status
  ) values (
    p_tenant_id,
    p_billing_profile_id,
    p_product_id,
    p_source_type,
    p_source_id,
    coalesce(v_name, 'Item'),
    v_image_url,
    v_barcode,
    v_product_code,
    v_note,
    v_quantity,
    'open'
  )
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.add_demand_bucket_item(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_product_id bigint,
  p_source_type public.demand_bucket_source_type,
  p_source_id bigint default null,
  p_snapshot jsonb default '{}'::jsonb,
  p_quantity integer default 1
)
returns public.customer_demand_bucket_items
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.can_access_demand_bucket_profile(p_tenant_id, p_billing_profile_id, true) then
    raise exception 'access denied';
  end if;

  return public.add_demand_bucket_item_internal(
    p_tenant_id,
    p_billing_profile_id,
    p_product_id,
    p_source_type,
    p_source_id,
    p_snapshot,
    p_quantity
  );
end;
$$;

create or replace function public.list_demand_bucket_items(
  p_tenant_id bigint,
  p_billing_profile_id bigint,
  p_status public.demand_bucket_status default 'open',
  p_limit integer default 100,
  p_offset integer default 0
)
returns table (
  id bigint,
  tenant_id bigint,
  billing_profile_id bigint,
  product_id bigint,
  source_type public.demand_bucket_source_type,
  source_id bigint,
  name text,
  image_url text,
  barcode text,
  product_code text,
  note text,
  quantity integer,
  status public.demand_bucket_status,
  popped_at timestamptz,
  popped_into_type text,
  popped_into_id bigint,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_limit integer := greatest(coalesce(p_limit, 100), 1);
  v_offset integer := greatest(coalesce(p_offset, 0), 0);
begin
  if not public.can_access_demand_bucket_profile(p_tenant_id, p_billing_profile_id, false) then
    raise exception 'access denied';
  end if;

  return query
  select
    b.id,
    b.tenant_id,
    b.billing_profile_id,
    b.product_id,
    b.source_type,
    b.source_id,
    b.name,
    b.image_url,
    b.barcode,
    b.product_code,
    b.note,
    b.quantity,
    b.status,
    b.popped_at,
    b.popped_into_type,
    b.popped_into_id,
    b.created_at,
    b.updated_at
  from public.customer_demand_bucket_items b
  where b.billing_profile_id = p_billing_profile_id
    and (p_status is null or b.status = p_status)
  order by b.created_at desc, b.id desc
  limit v_limit
  offset v_offset;
end;
$$;

create or replace function public.pop_demand_bucket_item(
  p_bucket_item_id bigint,
  p_popped_into_type text,
  p_popped_into_id bigint
)
returns public.customer_demand_bucket_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.customer_demand_bucket_items;
begin
  if p_bucket_item_id is null then
    raise exception 'bucket_item_id is required';
  end if;
  if nullif(trim(coalesce(p_popped_into_type, '')), '') is null
     or p_popped_into_id is null then
    raise exception 'popped_into_type and popped_into_id are required';
  end if;

  select * into v_row
  from public.customer_demand_bucket_items
  where id = p_bucket_item_id;

  if not found then
    raise exception 'bucket item not found: %', p_bucket_item_id;
  end if;

  if v_row.status <> 'open' then
    raise exception 'bucket item % is not open', p_bucket_item_id;
  end if;

  if not public.can_access_demand_bucket_profile(v_row.tenant_id, v_row.billing_profile_id, false) then
    raise exception 'access denied';
  end if;

  update public.customer_demand_bucket_items
  set
    status = 'popped',
    popped_at = now(),
    popped_into_type = trim(p_popped_into_type),
    popped_into_id = p_popped_into_id,
    updated_at = now()
  where id = p_bucket_item_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.pop_demand_bucket_items(
  p_bucket_item_ids bigint[],
  p_popped_into_type text,
  p_popped_into_id bigint
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
  v_row public.customer_demand_bucket_items;
  v_items jsonb := '[]'::jsonb;
begin
  if p_bucket_item_ids is null or cardinality(p_bucket_item_ids) = 0 then
    return jsonb_build_object('items', '[]'::jsonb, 'count', 0);
  end if;

  foreach v_id in array p_bucket_item_ids loop
    v_row := public.pop_demand_bucket_item(v_id, p_popped_into_type, p_popped_into_id);
    v_items := v_items || jsonb_build_array(to_jsonb(v_row));
  end loop;

  return jsonb_build_object(
    'items', v_items,
    'count', jsonb_array_length(v_items)
  );
end;
$$;

create or replace function public.cancel_demand_bucket_item(
  p_bucket_item_id bigint
)
returns public.customer_demand_bucket_items
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.customer_demand_bucket_items;
begin
  select * into v_row
  from public.customer_demand_bucket_items
  where id = p_bucket_item_id;

  if not found then
    raise exception 'bucket item not found: %', p_bucket_item_id;
  end if;

  if v_row.status <> 'open' then
    raise exception 'bucket item % is not open', p_bucket_item_id;
  end if;

  if not public.can_access_demand_bucket_profile(v_row.tenant_id, v_row.billing_profile_id, true) then
    raise exception 'access denied';
  end if;

  update public.customer_demand_bucket_items
  set
    status = 'cancelled',
    updated_at = now()
  where id = p_bucket_item_id
  returning * into v_row;

  return v_row;
end;
$$;

create or replace function public.purge_popped_demand_bucket_items(
  p_tenant_id bigint,
  p_retention_days integer default 90
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_cutoff timestamptz;
  v_deleted integer;
  v_is_parent boolean;
begin
  if p_tenant_id is null then
    raise exception 'tenant_id is required';
  end if;

  select (t.parent_id is null) into v_is_parent
  from public.tenants t
  where t.id = p_tenant_id;

  if coalesce(v_is_parent, false) then
    if not public.user_can_manage_parent_tenant(p_tenant_id) then
      raise exception 'access denied';
    end if;
  elsif not public.is_tenant_staff(p_tenant_id) then
    raise exception 'access denied';
  end if;

  v_cutoff := now() - make_interval(days => greatest(coalesce(p_retention_days, 90), 1));

  delete from public.customer_demand_bucket_items b
  where b.status = 'popped'
    and b.popped_at is not null
    and b.popped_at < v_cutoff
    and (
      b.tenant_id = p_tenant_id
      or exists (
        select 1
        from public.tenants t
        where t.id = b.tenant_id
          and t.parent_id = p_tenant_id
      )
    );

  get diagnostics v_deleted = row_count;

  return jsonb_build_object(
    'tenant_id', p_tenant_id,
    'retention_days', greatest(coalesce(p_retention_days, 90), 1),
    'deleted_count', v_deleted
  );
end;
$$;

-- 5. Catalog shortfall → bucket (dual-write with legacy backlog)
create or replace function public.staff_set_catalog_ordered_qty(
  p_order_id bigint,
  p_items jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order record;
  v_elem jsonb;
  v_item_id bigint;
  v_ordered_qty integer;
  v_item_row record;
  v_target_qty integer;
  v_shortfall integer;
  v_product record;
begin
  select * into v_order from public.shop_orders where id = p_order_id;
  if not found then
    raise exception 'Order not found: %', p_order_id;
  end if;

  if not public.is_tenant_staff(v_order.tenant_id) then
    raise exception 'access denied';
  end if;

  if v_order.shop_type_snapshot <> 'vendor_catalog' then
    raise exception 'staff_set_catalog_ordered_qty is only valid for vendor_catalog orders.';
  end if;

  for v_elem in select * from jsonb_array_elements(p_items) loop
    v_item_id := (v_elem->>'id')::bigint;
    v_ordered_qty := (v_elem->>'ordered_quantity')::integer;

    select * into v_item_row from public.shop_order_items where id = v_item_id and order_id = p_order_id;

    if v_item_row.id is not null then
      update public.shop_order_items
      set
        ordered_quantity = coalesce(v_ordered_qty, 0),
        updated_at = now()
      where id = v_item_id;

      v_target_qty := coalesce(v_item_row.confirmed_quantity, v_item_row.quantity, 0);
      v_shortfall := v_target_qty - coalesce(v_ordered_qty, 0);

      if v_shortfall > 0 and v_order.billing_profile_id is not null then
        select p.barcode, p.product_code
        into v_product
        from public.products p
        where p.id = v_item_row.product_id;

        perform public.add_demand_bucket_item_internal(
          p_tenant_id => v_order.tenant_id,
          p_billing_profile_id => v_order.billing_profile_id,
          p_product_id => v_item_row.product_id,
          p_source_type => 'shop_order_item',
          p_source_id => v_item_id,
          p_snapshot => jsonb_build_object(
            'name', coalesce(v_item_row.name, ''),
            'image_url', v_item_row.image_url,
            'barcode', v_product.barcode,
            'product_code', v_product.product_code,
            'note', null
          ),
          p_quantity => v_shortfall
        );

        -- Legacy dual-write until UI migrates off customer_order_backlog_items
        insert into public.customer_order_backlog_items (
          tenant_id,
          billing_profile_id,
          product_id,
          order_id,
          order_item_id,
          requested_quantity,
          fulfilled_quantity,
          backlog_status
        ) values (
          v_order.tenant_id,
          v_order.billing_profile_id,
          v_item_row.product_id,
          p_order_id,
          v_item_id,
          v_shortfall,
          0,
          'open'
        )
        on conflict (tenant_id, billing_profile_id, product_id)
        do update set
          requested_quantity = customer_order_backlog_items.requested_quantity + excluded.requested_quantity,
          backlog_status = 'open',
          updated_at = now();
      end if;
    end if;
  end loop;

  update public.shop_orders
  set
    status = 'ready_for_shipment'::public.shop_order_status,
    placed_at = coalesce(placed_at, now()),
    updated_at = now()
  where id = p_order_id;

  return public.get_shop_order_for_staff(v_order.tenant_id, p_order_id);
end;
$$;

-- 6. Grants
grant execute on function public.can_access_demand_bucket_profile(bigint, bigint, boolean) to authenticated;
grant execute on function public.add_demand_bucket_item_internal(
  bigint, bigint, bigint, public.demand_bucket_source_type, bigint, jsonb, integer
) to service_role;
grant execute on function public.add_demand_bucket_item(
  bigint, bigint, bigint, public.demand_bucket_source_type, bigint, jsonb, integer
) to authenticated;
grant execute on function public.list_demand_bucket_items(
  bigint, bigint, public.demand_bucket_status, integer, integer
) to authenticated;
grant execute on function public.pop_demand_bucket_item(bigint, text, bigint) to authenticated;
grant execute on function public.pop_demand_bucket_items(bigint[], text, bigint) to authenticated;
grant execute on function public.cancel_demand_bucket_item(bigint) to authenticated;
grant execute on function public.purge_popped_demand_bucket_items(bigint, integer) to authenticated;

commit;
