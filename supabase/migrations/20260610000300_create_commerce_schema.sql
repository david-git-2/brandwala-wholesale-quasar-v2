-- ====================================================================
-- COMMERCE SCHEMA MIGRATION
-- ====================================================================
begin;

-- 1. Order Status Enum
do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'commerce_order_status'
  ) then
    create type public.commerce_order_status as enum (
      'placed',
      'reviewing',
      'shipping',
      'delivered',
      'cancelled'
    );
  end if;
end
$$;

-- 2. Commerce Cart Table
create table if not exists public.commerce_cart (
  id bigserial primary key,
  product_id bigint not null,
  tenant_id bigint not null,
  customer_group_id bigint not null,
  quantity integer not null default 1,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint commerce_cart_product_id_fkey
    foreign key (product_id)
    references public.products (id)
    on delete cascade,

  constraint commerce_cart_tenant_id_fkey
    foreign key (tenant_id)
    references public.tenants (id)
    on delete cascade,

  constraint commerce_cart_customer_group_id_fkey
    foreign key (customer_group_id)
    references public.customer_groups (id)
    on delete cascade,

  constraint commerce_cart_quantity_check
    check (quantity > 0),

  constraint commerce_cart_customer_product_unique
    unique (tenant_id, customer_group_id, product_id)
);

create index if not exists commerce_cart_tenant_idx on public.commerce_cart (tenant_id);
create index if not exists commerce_cart_customer_group_idx on public.commerce_cart (customer_group_id);
create index if not exists commerce_cart_product_idx on public.commerce_cart (product_id);

drop trigger if exists trg_commerce_cart_updated_at on public.commerce_cart;
create trigger trg_commerce_cart_updated_at
before update on public.commerce_cart
for each row
execute function public.set_updated_at();


-- 3. Commerce Orders Table
create table if not exists public.commerce_orders (
  id bigserial primary key,
  recipient_name text not null,
  recipient_phone text not null,
  shipping_address text not null,
  shipment_payment numeric(12, 2) not null default 0.00,
  invoice_print_charge numeric(12, 2) not null default 0.00,
  wrapping_charge numeric(12, 2) not null default 0.00,
  cod numeric(12, 2) not null default 0.00,
  tenant_id bigint not null,
  order_placement_date timestamp with time zone not null default now(),
  shipment_date timestamp with time zone null,
  delivery_charge numeric(12, 2) not null default 0.00,
  status public.commerce_order_status not null default 'placed',
  invoice_ids bigint[] not null default '{}'::bigint[],
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint commerce_orders_tenant_id_fkey
    foreign key (tenant_id)
    references public.tenants (id)
    on delete cascade
);

create index if not exists commerce_orders_tenant_idx on public.commerce_orders (tenant_id);
create index if not exists commerce_orders_status_idx on public.commerce_orders (status);

drop trigger if exists trg_commerce_orders_updated_at on public.commerce_orders;
create trigger trg_commerce_orders_updated_at
before update on public.commerce_orders
for each row
execute function public.set_updated_at();


-- 4. Commerce Order Items Table
create table if not exists public.commerce_order_items (
  id bigserial primary key,
  order_id bigint not null,
  product_id bigint not null,
  image_url text null,
  cost_bdt numeric(12, 2) not null default 0.00,
  sell_price_bdt numeric(12, 2) not null default 0.00,
  recipient_price_bdt numeric(12, 2) not null default 0.00,
  quantity integer not null default 1,
  invoice_id bigint null,
  phone_invite_id text null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint commerce_order_items_order_id_fkey
    foreign key (order_id)
    references public.commerce_orders (id)
    on delete cascade,

  constraint commerce_order_items_product_id_fkey
    foreign key (product_id)
    references public.products (id)
    on delete cascade,

  constraint commerce_order_items_quantity_check
    check (quantity > 0)
);

create index if not exists commerce_order_items_order_idx on public.commerce_order_items (order_id);
create index if not exists commerce_order_items_product_idx on public.commerce_order_items (product_id);
create index if not exists commerce_order_items_invoice_idx on public.commerce_order_items (invoice_id);

drop trigger if exists trg_commerce_order_items_updated_at on public.commerce_order_items;
create trigger trg_commerce_order_items_updated_at
before update on public.commerce_order_items
for each row
execute function public.set_updated_at();


-- 5. Commerce Invoices Table
create table if not exists public.commerce_invoices (
  id bigserial primary key,
  order_id bigint not null,
  delivery_charge numeric(12, 2) not null default 0.00,
  total_amount numeric(12, 2) not null default 0.00,
  amount_paid numeric(12, 2) not null default 0.00,
  amount_due numeric(12, 2) not null default 0.00,
  is_customer_group_paid boolean not null default false,
  delivered_by text null,
  tenant_id bigint not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint commerce_invoices_order_id_fkey
    foreign key (order_id)
    references public.commerce_orders (id)
    on delete cascade,

  constraint commerce_invoices_tenant_id_fkey
    foreign key (tenant_id)
    references public.tenants (id)
    on delete cascade
);

create index if not exists commerce_invoices_order_idx on public.commerce_invoices (order_id);
create index if not exists commerce_invoices_tenant_idx on public.commerce_invoices (tenant_id);

drop trigger if exists trg_commerce_invoices_updated_at on public.commerce_invoices;
create trigger trg_commerce_invoices_updated_at
before update on public.commerce_invoices
for each row
execute function public.set_updated_at();


-- 6. Commerce Accounting Table
create table if not exists public.commerce_accounting (
  id bigserial primary key,
  order_item_id bigint not null,
  cost_bdt numeric(12, 2) not null default 0.00,
  shipment_item_id bigint null,
  sell_price_bdt numeric(12, 2) not null default 0.00,
  recipient_sell_price_bdt numeric(12, 2) not null default 0.00,
  customer_group_id bigint not null,
  is_customer_group_paid boolean not null default false,
  tenant_id bigint not null,
  created_at timestamp with time zone not null default now(),
  updated_at timestamp with time zone not null default now(),

  constraint commerce_accounting_order_item_id_fkey
    foreign key (order_item_id)
    references public.commerce_order_items (id)
    on delete cascade,

  constraint commerce_accounting_shipment_item_id_fkey
    foreign key (shipment_item_id)
    references public.shipment_items (id)
    on delete set null,

  constraint commerce_accounting_customer_group_id_fkey
    foreign key (customer_group_id)
    references public.customer_groups (id)
    on delete cascade,

  constraint commerce_accounting_tenant_id_fkey
    foreign key (tenant_id)
    references public.tenants (id)
    on delete cascade
);

create index if not exists commerce_accounting_order_item_idx on public.commerce_accounting (order_item_id);
create index if not exists commerce_accounting_customer_group_idx on public.commerce_accounting (customer_group_id);
create index if not exists commerce_accounting_tenant_idx on public.commerce_accounting (tenant_id);

drop trigger if exists trg_commerce_accounting_updated_at on public.commerce_accounting;
create trigger trg_commerce_accounting_updated_at
before update on public.commerce_accounting
for each row
execute function public.set_updated_at();


-- ====================================================================
-- RLS POLICIES (Accessible to authenticated users)
-- ====================================================================
alter table public.commerce_cart enable row level security;
alter table public.commerce_orders enable row level security;
alter table public.commerce_order_items enable row level security;
alter table public.commerce_invoices enable row level security;
alter table public.commerce_accounting enable row level security;

-- Commerce Cart policies
drop policy if exists commerce_cart_select on public.commerce_cart;
create policy commerce_cart_select on public.commerce_cart for select to authenticated using (true);
drop policy if exists commerce_cart_insert on public.commerce_cart;
create policy commerce_cart_insert on public.commerce_cart for insert to authenticated with check (true);
drop policy if exists commerce_cart_update on public.commerce_cart;
create policy commerce_cart_update on public.commerce_cart for update to authenticated using (true);
drop policy if exists commerce_cart_delete on public.commerce_cart;
create policy commerce_cart_delete on public.commerce_cart for delete to authenticated using (true);

-- Commerce Orders policies
drop policy if exists commerce_orders_select on public.commerce_orders;
create policy commerce_orders_select on public.commerce_orders for select to authenticated using (true);
drop policy if exists commerce_orders_insert on public.commerce_orders;
create policy commerce_orders_insert on public.commerce_orders for insert to authenticated with check (true);
drop policy if exists commerce_orders_update on public.commerce_orders;
create policy commerce_orders_update on public.commerce_orders for update to authenticated using (true);
drop policy if exists commerce_orders_delete on public.commerce_orders;
create policy commerce_orders_delete on public.commerce_orders for delete to authenticated using (true);

-- Commerce Order Items policies
drop policy if exists commerce_order_items_select on public.commerce_order_items;
create policy commerce_order_items_select on public.commerce_order_items for select to authenticated using (true);
drop policy if exists commerce_order_items_insert on public.commerce_order_items;
create policy commerce_order_items_insert on public.commerce_order_items for insert to authenticated with check (true);
drop policy if exists commerce_order_items_update on public.commerce_order_items;
create policy commerce_order_items_update on public.commerce_order_items for update to authenticated using (true);
drop policy if exists commerce_order_items_delete on public.commerce_order_items;
create policy commerce_order_items_delete on public.commerce_order_items for delete to authenticated using (true);

-- Commerce Invoices policies
drop policy if exists commerce_invoices_select on public.commerce_invoices;
create policy commerce_invoices_select on public.commerce_invoices for select to authenticated using (true);
drop policy if exists commerce_invoices_insert on public.commerce_invoices;
create policy commerce_invoices_insert on public.commerce_invoices for insert to authenticated with check (true);
drop policy if exists commerce_invoices_update on public.commerce_invoices;
create policy commerce_invoices_update on public.commerce_invoices for update to authenticated using (true);
drop policy if exists commerce_invoices_delete on public.commerce_invoices;
create policy commerce_invoices_delete on public.commerce_invoices for delete to authenticated using (true);

-- Commerce Accounting policies
drop policy if exists commerce_accounting_select on public.commerce_accounting;
create policy commerce_accounting_select on public.commerce_accounting for select to authenticated using (true);
drop policy if exists commerce_accounting_insert on public.commerce_accounting;
create policy commerce_accounting_insert on public.commerce_accounting for insert to authenticated with check (true);
drop policy if exists commerce_accounting_update on public.commerce_accounting;
create policy commerce_accounting_update on public.commerce_accounting for update to authenticated using (true);
drop policy if exists commerce_accounting_delete on public.commerce_accounting;
create policy commerce_accounting_delete on public.commerce_accounting for delete to authenticated using (true);


-- ====================================================================
-- RPC FUNCTIONS
-- ====================================================================

-- place_commerce_order
create or replace function public.place_commerce_order(
  p_tenant_id bigint,
  p_customer_group_id bigint,
  p_recipient_name text,
  p_recipient_phone text,
  p_shipping_address text,
  p_shipment_payment numeric,
  p_invoice_print_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_delivery_charge numeric,
  p_items jsonb
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order_id bigint;
  v_item jsonb;
begin
  -- 1. Insert Commerce Order
  insert into public.commerce_orders (
    recipient_name,
    recipient_phone,
    shipping_address,
    shipment_payment,
    invoice_print_charge,
    wrapping_charge,
    cod,
    tenant_id,
    order_placement_date,
    delivery_charge,
    status
  )
  values (
    p_recipient_name,
    p_recipient_phone,
    p_shipping_address,
    p_shipment_payment,
    p_invoice_print_charge,
    p_wrapping_charge,
    p_cod,
    p_tenant_id,
    now(),
    p_delivery_charge,
    'placed'::public.commerce_order_status
  )
  returning id into v_order_id;

  -- 2. Insert Order Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.commerce_order_items (
      order_id,
      product_id,
      image_url,
      cost_bdt,
      sell_price_bdt,
      recipient_price_bdt,
      quantity,
      phone_invite_id
    )
    values (
      v_order_id,
      (v_item->>'product_id')::bigint,
      v_item->>'image_url',
      (v_item->>'cost_bdt')::numeric,
      (v_item->>'sell_price_bdt')::numeric,
      (v_item->>'recipient_price_bdt')::numeric,
      (v_item->>'quantity')::integer,
      v_item->>'phone_invite_id'
    );

    -- 3. Delete from commerce_cart
    delete from public.commerce_cart
    where tenant_id = p_tenant_id
      and customer_group_id = p_customer_group_id
      and product_id = (v_item->>'product_id')::bigint;
  end loop;

  return v_order_id;
end;
$$;


-- create_commerce_invoice
create or replace function public.create_commerce_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_delivery_charge numeric,
  p_total_amount numeric,
  p_amount_paid numeric,
  p_delivered_by text
)
returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_invoice_id bigint;
  v_cust_group_id bigint;
  v_item record;
begin
  -- Get customer group id from the order
  select tenant_id into p_tenant_id
  from public.commerce_orders
  where id = p_order_id;

  select customer_group_id into v_cust_group_id
  from public.commerce_cart
  where tenant_id = p_tenant_id
  limit 1; -- Fallback logic or fetch from metadata

  -- 1. Insert Invoice
  insert into public.commerce_invoices (
    order_id,
    delivery_charge,
    total_amount,
    amount_paid,
    amount_due,
    is_customer_group_paid,
    delivered_by,
    tenant_id
  )
  values (
    p_order_id,
    p_delivery_charge,
    p_total_amount,
    p_amount_paid,
    p_total_amount - p_amount_paid,
    case when p_amount_paid >= p_total_amount then true else false end,
    p_delivered_by,
    p_tenant_id
  )
  returning id into v_invoice_id;

  -- 2. Update order status to 'reviewing' and append to invoice_ids
  update public.commerce_orders
  set
    status = 'reviewing'::public.commerce_order_status,
    invoice_ids = array_append(coalesce(invoice_ids, '{}'::bigint[]), v_invoice_id)
  where id = p_order_id;

  -- 3. Update order items to set invoice_id
  update public.commerce_order_items
  set invoice_id = v_invoice_id
  where order_id = p_order_id;

  -- 4. Create accounting entries for each order item
  for v_item in (
    select id, product_id, cost_bdt, sell_price_bdt, recipient_price_bdt
    from public.commerce_order_items
    where order_id = p_order_id
  ) loop
    insert into public.commerce_accounting (
      order_item_id,
      cost_bdt,
      shipment_item_id,
      sell_price_bdt,
      recipient_sell_price_bdt,
      customer_group_id,
      is_customer_group_paid,
      tenant_id
    )
    values (
      v_item.id,
      v_item.cost_bdt,
      null,
      v_item.sell_price_bdt,
      v_item.recipient_price_bdt,
      coalesce(v_cust_group_id, 0), -- fallback to 0 if not resolved
      false,
      p_tenant_id
    );
  end loop;

  return v_invoice_id;
end;
$$;


-- ====================================================================
-- GRANTS & SEQUENCES
-- ====================================================================
grant select, insert, update, delete on table public.commerce_cart to authenticated;
grant select, insert, update, delete on table public.commerce_orders to authenticated;
grant select, insert, update, delete on table public.commerce_order_items to authenticated;
grant select, insert, update, delete on table public.commerce_invoices to authenticated;
grant select, insert, update, delete on table public.commerce_accounting to authenticated;

grant usage, select on sequence public.commerce_cart_id_seq to authenticated;
grant usage, select on sequence public.commerce_orders_id_seq to authenticated;
grant usage, select on sequence public.commerce_order_items_id_seq to authenticated;
grant usage, select on sequence public.commerce_invoices_id_seq to authenticated;
grant usage, select on sequence public.commerce_accounting_id_seq to authenticated;

grant execute on function public.place_commerce_order(bigint, bigint, text, text, text, numeric, numeric, numeric, numeric, numeric, jsonb) to authenticated;
grant execute on function public.create_commerce_invoice(bigint, bigint, numeric, numeric, numeric, text) to authenticated;

commit;
