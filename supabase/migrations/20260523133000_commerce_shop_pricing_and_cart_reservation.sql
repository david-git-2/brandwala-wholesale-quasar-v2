create table if not exists public.store_product_prices (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  store_id bigint not null references public.stores(id) on delete cascade,
  product_id bigint not null references public.products(id) on delete cascade,
  price_bdt numeric(12, 2) not null,
  minimum_sell_price_bdt numeric(12, 2) not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint store_product_prices_positive_price_chk check (price_bdt >= 0),
  constraint store_product_prices_positive_min_price_chk check (minimum_sell_price_bdt >= 0),
  constraint store_product_prices_min_lte_price_chk check (minimum_sell_price_bdt <= price_bdt),
  constraint store_product_prices_unique_store_product unique (tenant_id, store_id, product_id)
);

create index if not exists store_product_prices_store_id_idx
  on public.store_product_prices(store_id);

create index if not exists store_product_prices_product_id_idx
  on public.store_product_prices(product_id);

drop trigger if exists trg_store_product_prices_set_updated_at on public.store_product_prices;
create trigger trg_store_product_prices_set_updated_at
before update on public.store_product_prices
for each row
execute function public.set_updated_at();

alter table public.store_product_prices enable row level security;

drop policy if exists store_product_prices_select on public.store_product_prices;
create policy store_product_prices_select
on public.store_product_prices
for select
to authenticated
using (
  public.has_active_tenant_membership(tenant_id)
  or public.can_customer_access_store(store_id)
);

drop policy if exists store_product_prices_insert on public.store_product_prices;
create policy store_product_prices_insert
on public.store_product_prices
for insert
to authenticated
with check (
  public.has_active_tenant_membership(tenant_id)
);

drop policy if exists store_product_prices_update on public.store_product_prices;
create policy store_product_prices_update
on public.store_product_prices
for update
to authenticated
using (
  public.has_active_tenant_membership(tenant_id)
)
with check (
  public.has_active_tenant_membership(tenant_id)
);

drop policy if exists store_product_prices_delete on public.store_product_prices;
create policy store_product_prices_delete
on public.store_product_prices
for delete
to authenticated
using (
  public.has_active_tenant_membership(tenant_id)
);

alter table public.cart_items
  add column if not exists price_bdt numeric(12, 2),
  add column if not exists minimum_sell_price_bdt numeric(12, 2);

create or replace function public.adjust_inventory_reserved_for_product(
  p_tenant_id bigint,
  p_product_id bigint,
  p_delta integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_remaining integer := coalesce(p_delta, 0);
  v_rec record;
  v_take integer;
  v_slack integer;
begin
  if v_remaining = 0 or p_product_id is null then
    return;
  end if;

  if v_remaining > 0 then
    for v_rec in
      select
        st.id,
        st.available_quantity,
        st.reserved_quantity,
        st.damaged_quantity,
        st.stolen_quantity,
        st.expired_quantity,
        st.open_box_quantity
      from public.inventory_stocks st
      join public.inventory_items ii on ii.id = st.inventory_item_id
      where ii.tenant_id = p_tenant_id
        and ii.product_id = p_product_id
        and ii.status = 'active'
      order by st.id asc
      for update of st
    loop
      v_slack := greatest(
        0,
        coalesce(v_rec.available_quantity, 0)
        - coalesce(v_rec.reserved_quantity, 0)
        - coalesce(v_rec.damaged_quantity, 0)
        - coalesce(v_rec.stolen_quantity, 0)
        - coalesce(v_rec.expired_quantity, 0)
        - coalesce(v_rec.open_box_quantity, 0)
      );

      if v_slack <= 0 then
        continue;
      end if;

      v_take := least(v_remaining, v_slack);

      update public.inventory_stocks
      set reserved_quantity = coalesce(reserved_quantity, 0) + v_take
      where id = v_rec.id;

      v_remaining := v_remaining - v_take;
      exit when v_remaining = 0;
    end loop;

    if v_remaining > 0 then
      raise exception 'Not enough stock to reserve for product %.', p_product_id;
    end if;
  else
    v_remaining := abs(v_remaining);

    for v_rec in
      select
        st.id,
        st.reserved_quantity
      from public.inventory_stocks st
      join public.inventory_items ii on ii.id = st.inventory_item_id
      where ii.tenant_id = p_tenant_id
        and ii.product_id = p_product_id
        and ii.status = 'active'
        and coalesce(st.reserved_quantity, 0) > 0
      order by st.id desc
      for update of st
    loop
      v_take := least(v_remaining, coalesce(v_rec.reserved_quantity, 0));

      update public.inventory_stocks
      set reserved_quantity = greatest(0, coalesce(reserved_quantity, 0) - v_take)
      where id = v_rec.id;

      v_remaining := v_remaining - v_take;
      exit when v_remaining = 0;
    end loop;
  end if;
end;
$$;

create or replace function public.apply_cart_item_inventory_reservation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tenant_id bigint;
begin
  if tg_op = 'INSERT' then
    if new.product_id is null then
      return new;
    end if;

    select tenant_id into v_tenant_id from public.carts where id = new.cart_id;
    perform public.adjust_inventory_reserved_for_product(v_tenant_id, new.product_id, new.quantity);
    return new;
  end if;

  if tg_op = 'UPDATE' then
    select tenant_id into v_tenant_id from public.carts where id = new.cart_id;

    if old.product_id is not null then
      perform public.adjust_inventory_reserved_for_product(v_tenant_id, old.product_id, -old.quantity);
    end if;

    if new.product_id is not null then
      perform public.adjust_inventory_reserved_for_product(v_tenant_id, new.product_id, new.quantity);
    end if;

    return new;
  end if;

  if tg_op = 'DELETE' then
    if old.product_id is null then
      return old;
    end if;

    select tenant_id into v_tenant_id from public.carts where id = old.cart_id;
    perform public.adjust_inventory_reserved_for_product(v_tenant_id, old.product_id, -old.quantity);
    return old;
  end if;

  return null;
end;
$$;

drop trigger if exists trg_cart_items_inventory_reservation on public.cart_items;
create trigger trg_cart_items_inventory_reservation
before insert or update of product_id, quantity or delete
on public.cart_items
for each row
execute function public.apply_cart_item_inventory_reservation();
