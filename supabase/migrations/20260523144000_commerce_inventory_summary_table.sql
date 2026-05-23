create table if not exists public.commerce_inventory_product_summaries (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  available_quantity integer not null default 0,
  reserved_quantity integer not null default 0,
  damaged_quantity integer not null default 0,
  stolen_quantity integer not null default 0,
  expired_quantity integer not null default 0,
  open_box_quantity integer not null default 0,
  usable_quantity integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (tenant_id, product_id)
);

create index if not exists commerce_inventory_product_summaries_tenant_idx
  on public.commerce_inventory_product_summaries(tenant_id);

create index if not exists commerce_inventory_product_summaries_product_idx
  on public.commerce_inventory_product_summaries(product_id);

create or replace function public.refresh_commerce_inventory_product_summary_single(
  p_tenant_id bigint,
  p_product_id bigint
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_available integer := 0;
  v_reserved integer := 0;
  v_damaged integer := 0;
  v_stolen integer := 0;
  v_expired integer := 0;
  v_open_box integer := 0;
  v_usable integer := 0;
  v_exists boolean := false;
begin
  if p_tenant_id is null or p_product_id is null then
    return;
  end if;

  select
    count(*) > 0,
    coalesce(sum(coalesce(st.available_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.reserved_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.damaged_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.stolen_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.expired_quantity, 0)), 0)::int,
    coalesce(sum(coalesce(st.open_box_quantity, 0)), 0)::int
  into
    v_exists,
    v_available,
    v_reserved,
    v_damaged,
    v_stolen,
    v_expired,
    v_open_box
  from public.inventory_items ii
  left join public.inventory_stocks st
    on st.inventory_item_id = ii.id
  where ii.tenant_id = p_tenant_id
    and ii.product_id = p_product_id
    and ii.status = 'active';

  if not v_exists then
    delete from public.commerce_inventory_product_summaries
    where tenant_id = p_tenant_id
      and product_id = p_product_id;
    return;
  end if;

  v_usable := greatest(0, v_available - v_reserved - v_damaged - v_stolen - v_expired - v_open_box);

  insert into public.commerce_inventory_product_summaries (
    tenant_id,
    product_id,
    available_quantity,
    reserved_quantity,
    damaged_quantity,
    stolen_quantity,
    expired_quantity,
    open_box_quantity,
    usable_quantity,
    updated_at
  )
  values (
    p_tenant_id,
    p_product_id,
    v_available,
    v_reserved,
    v_damaged,
    v_stolen,
    v_expired,
    v_open_box,
    v_usable,
    now()
  )
  on conflict (tenant_id, product_id)
  do update set
    available_quantity = excluded.available_quantity,
    reserved_quantity = excluded.reserved_quantity,
    damaged_quantity = excluded.damaged_quantity,
    stolen_quantity = excluded.stolen_quantity,
    expired_quantity = excluded.expired_quantity,
    open_box_quantity = excluded.open_box_quantity,
    usable_quantity = excluded.usable_quantity,
    updated_at = now();
end;
$$;

create or replace function public.refresh_commerce_inventory_product_summaries(
  p_tenant_id bigint default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row record;
begin
  for v_row in
    select distinct ii.tenant_id, ii.product_id
    from public.inventory_items ii
    where ii.product_id is not null
      and (p_tenant_id is null or ii.tenant_id = p_tenant_id)
  loop
    perform public.refresh_commerce_inventory_product_summary_single(v_row.tenant_id, v_row.product_id);
  end loop;
end;
$$;

create or replace function public.sync_commerce_summary_from_inventory_items()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.refresh_commerce_inventory_product_summary_single(old.tenant_id, old.product_id);
    return old;
  end if;

  perform public.refresh_commerce_inventory_product_summary_single(new.tenant_id, new.product_id);

  if tg_op = 'UPDATE' and (old.product_id is distinct from new.product_id) then
    perform public.refresh_commerce_inventory_product_summary_single(old.tenant_id, old.product_id);
  end if;

  return new;
end;
$$;

drop trigger if exists trg_inventory_items_commerce_summary_sync on public.inventory_items;
create trigger trg_inventory_items_commerce_summary_sync
after insert or update of tenant_id, product_id, status or delete
on public.inventory_items
for each row
execute function public.sync_commerce_summary_from_inventory_items();

create or replace function public.sync_commerce_summary_from_inventory_stocks()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inventory_item_id bigint;
  v_tenant_id bigint;
  v_product_id bigint;
begin
  v_inventory_item_id := coalesce(new.inventory_item_id, old.inventory_item_id);

  select ii.tenant_id, ii.product_id
  into v_tenant_id, v_product_id
  from public.inventory_items ii
  where ii.id = v_inventory_item_id;

  perform public.refresh_commerce_inventory_product_summary_single(v_tenant_id, v_product_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists trg_inventory_stocks_commerce_summary_sync on public.inventory_stocks;
create trigger trg_inventory_stocks_commerce_summary_sync
after insert or update of available_quantity, reserved_quantity, damaged_quantity, stolen_quantity, expired_quantity, open_box_quantity or delete
on public.inventory_stocks
for each row
execute function public.sync_commerce_summary_from_inventory_stocks();

alter table public.commerce_inventory_product_summaries enable row level security;

drop policy if exists commerce_inventory_product_summaries_select on public.commerce_inventory_product_summaries;
create policy commerce_inventory_product_summaries_select
on public.commerce_inventory_product_summaries
for select
to authenticated
using (
  public.has_active_tenant_membership(tenant_id)
  or exists (
    select 1
    from public.stores s
    where s.tenant_id = commerce_inventory_product_summaries.tenant_id
      and public.can_customer_access_store(s.id)
  )
);

grant execute on function public.refresh_commerce_inventory_product_summary_single(bigint, bigint)
to authenticated;

grant execute on function public.refresh_commerce_inventory_product_summaries(bigint)
to authenticated;

select public.refresh_commerce_inventory_product_summaries(null);
