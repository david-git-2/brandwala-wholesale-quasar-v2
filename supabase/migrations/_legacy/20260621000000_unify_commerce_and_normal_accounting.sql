-- Migration: Unify commerce_accounting and inventory_accounting_entries tables
begin;

-- 1. Add commerce columns to public.inventory_accounting_entries if they don't exist
alter table public.inventory_accounting_entries
  add column if not exists type text not null default 'normal' check (type in ('normal', 'commerce')),
  add column if not exists commerce_order_item_id bigint null references public.commerce_order_items(id) on delete cascade,
  add column if not exists commerce_invoice_id bigint null references public.commerce_invoices(id) on delete set null,
  add column if not exists recipient_sell_price_amount numeric(12,2) null check (recipient_sell_price_amount is null or recipient_sell_price_amount >= 0),
  add column if not exists billing_profile_id bigint null references public.commerce_billing_profiles(id) on delete set null,
  add column if not exists customer_group_id bigint null references public.customer_groups(id) on delete set null;

-- Make invoice_id optional since commerce accounting records use commerce_invoice_id
alter table public.inventory_accounting_entries
  alter column invoice_id drop not null;

-- 2. Create indexes for commerce columns in the unified ledger
create index if not exists inventory_accounting_entries_type_idx
  on public.inventory_accounting_entries (type);

create unique index if not exists inventory_accounting_entries_commerce_order_item_unique_idx
  on public.inventory_accounting_entries (commerce_order_item_id)
  where (type = 'commerce');

create index if not exists inventory_accounting_entries_commerce_invoice_idx
  on public.inventory_accounting_entries (commerce_invoice_id);

create index if not exists inventory_accounting_entries_billing_profile_idx
  on public.inventory_accounting_entries (billing_profile_id);

create index if not exists inventory_accounting_entries_customer_group_idx
  on public.inventory_accounting_entries (customer_group_id);

-- 3. Migrate data from commerce_accounting table to inventory_accounting_entries (if table exists)
do $$
begin
  if exists (
    select 1
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where c.relname = 'commerce_accounting'
      and c.relkind = 'r' -- physical table
      and n.nspname = 'public'
  ) then
    insert into public.inventory_accounting_entries (
      type,
      tenant_id,
      commerce_order_item_id,
      cost_amount,
      shipment_item_id,
      sell_price_amount,
      recipient_sell_price_amount,
      customer_group_id,
      billing_profile_id,
      status,
      inventory_item_id,
      quantity,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount,
      created_at,
      updated_at
    )
    select
      'commerce',
      coalesce(ii.tenant_id, ca.tenant_id), -- Resolve owner/supplier tenant ID
      ca.order_item_id,
      ca.cost_bdt,
      ca.shipment_item_id,
      ca.sell_price_bdt,
      ca.recipient_sell_price_bdt,
      ca.customer_group_id,
      ca.billing_profile_id,
      case when ca.is_customer_group_paid then 'paid'::text else 'due'::text end,
      ca.inventory_item_id,
      coalesce(coi.quantity, 1),
      (ca.cost_bdt * coalesce(coi.quantity, 1)) as total_cost_amount,
      (ca.sell_price_bdt * coalesce(coi.quantity, 1)) as total_sell_amount,
      ((ca.sell_price_bdt - ca.cost_bdt) * coalesce(coi.quantity, 1)) as gross_profit_amount,
      ca.created_at,
      ca.updated_at
    from public.commerce_accounting ca
    left join public.commerce_order_items coi on coi.id = ca.order_item_id
    left join public.inventory_items ii on ii.id = ca.inventory_item_id;

    -- Drop the physical table and its indexes
    drop table public.commerce_accounting cascade;
  end if;
end
$$;

-- 4. Recreate commerce_accounting view mapping unified entries to old schema schema
create or replace view public.commerce_accounting as
select
  id,
  commerce_order_item_id as order_item_id,
  cost_amount as cost_bdt,
  shipment_item_id,
  sell_price_amount as sell_price_bdt,
  recipient_sell_price_amount as recipient_sell_price_bdt,
  customer_group_id,
  billing_profile_id,
  (status = 'paid') as is_customer_group_paid,
  tenant_id,
  inventory_item_id,
  created_at,
  updated_at
from public.inventory_accounting_entries
where type = 'commerce';

-- 5. Define INSTEAD OF trigger function on the commerce_accounting view
create or replace function public.trg_fn_commerce_accounting_instead_of()
returns trigger
language plpgsql
security definer
as $$
declare
  v_quantity integer;
  v_product_id bigint;
begin
  if tg_op = 'INSERT' then
    -- Resolve quantity and parent product id for total cost/sell price calculations
    select quantity into v_quantity
    from public.commerce_order_items
    where id = new.order_item_id;

    v_quantity := coalesce(v_quantity, 1);

    select product_id into v_product_id
    from public.inventory_items
    where id = new.inventory_item_id;

    insert into public.inventory_accounting_entries (
      type,
      commerce_order_item_id,
      cost_amount,
      shipment_item_id,
      sell_price_amount,
      recipient_sell_price_amount,
      customer_group_id,
      billing_profile_id,
      status,
      tenant_id,
      inventory_item_id,
      product_id,
      quantity,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount,
      created_at,
      updated_at
    )
    values (
      'commerce',
      new.order_item_id,
      new.cost_bdt,
      new.shipment_item_id,
      new.sell_price_bdt,
      new.recipient_sell_price_bdt,
      new.customer_group_id,
      new.billing_profile_id,
      case when new.is_customer_group_paid then 'paid'::text else 'due'::text end,
      new.tenant_id,
      new.inventory_item_id,
      v_product_id,
      v_quantity,
      (new.cost_bdt * v_quantity),
      (new.sell_price_bdt * v_quantity),
      ((new.sell_price_bdt - new.cost_bdt) * v_quantity),
      coalesce(new.created_at, now()),
      coalesce(new.updated_at, now())
    )
    returning id into new.id;
    return new;

  elsif tg_op = 'UPDATE' then
    select quantity into v_quantity
    from public.commerce_order_items
    where id = new.order_item_id;

    v_quantity := coalesce(v_quantity, 1);

    select product_id into v_product_id
    from public.inventory_items
    where id = new.inventory_item_id;

    update public.inventory_accounting_entries
    set
      commerce_order_item_id = new.order_item_id,
      cost_amount = new.cost_bdt,
      shipment_item_id = new.shipment_item_id,
      sell_price_amount = new.sell_price_bdt,
      recipient_sell_price_amount = new.recipient_sell_price_bdt,
      customer_group_id = new.customer_group_id,
      billing_profile_id = new.billing_profile_id,
      status = case when new.is_customer_group_paid then 'paid'::text else 'due'::text end,
      tenant_id = new.tenant_id,
      inventory_item_id = new.inventory_item_id,
      product_id = v_product_id,
      quantity = v_quantity,
      total_cost_amount = (new.cost_bdt * v_quantity),
      total_sell_amount = (new.sell_price_bdt * v_quantity),
      gross_profit_amount = ((new.sell_price_bdt - new.cost_bdt) * v_quantity),
      updated_at = now()
    where id = old.id;
    return new;

  elsif tg_op = 'DELETE' then
    delete from public.inventory_accounting_entries
    where id = old.id;
    return old;
  end if;
end;
$$;

create trigger trg_commerce_accounting_instead_of
instead of insert or update or delete
on public.commerce_accounting
for each row
execute function public.trg_fn_commerce_accounting_instead_of();

-- 6. Redefine create_commerce_invoice RPC to resolve tenant_id to supplier tenant and write directly to inventory_accounting_entries (bypassing view ON CONFLICT limitation)
create or replace function public.create_commerce_invoice(
  p_tenant_id bigint,
  p_order_id bigint,
  p_delivery_charge numeric,
  p_wrapping_charge numeric,
  p_cod numeric,
  p_total_amount numeric,
  p_amount_paid numeric,
  p_delivered_by text,
  p_billing_profile_id bigint default null
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
  v_is_paid boolean;
  v_product_id bigint;
  v_quantity integer;
begin
  select tenant_id, customer_group_id into p_tenant_id, v_cust_group_id
  from public.commerce_orders
  where id = p_order_id;

  if p_tenant_id is null then
    raise exception 'Commerce order % not found.', p_order_id;
  end if;

  v_is_paid := coalesce(p_amount_paid, 0) >= coalesce(p_total_amount, 0);

  insert into public.commerce_invoices (
    order_id,
    delivery_charge,
    wrapping_charge,
    cod,
    total_amount,
    amount_paid,
    amount_due,
    is_customer_group_paid,
    delivered_by,
    tenant_id,
    billing_profile_id
  )
  values (
    p_order_id,
    coalesce(p_delivery_charge, 0),
    coalesce(p_wrapping_charge, 0),
    coalesce(p_cod, 0),
    coalesce(p_total_amount, 0),
    coalesce(p_amount_paid, 0),
    greatest(coalesce(p_total_amount, 0) - coalesce(p_amount_paid, 0), 0),
    v_is_paid,
    p_delivered_by,
    p_tenant_id,
    p_billing_profile_id
  )
  returning id into v_invoice_id;

  update public.commerce_orders
  set
    status = 'reviewing'::public.commerce_order_status,
    invoice_ids = array_append(coalesce(invoice_ids, '{}'::bigint[]), v_invoice_id)
  where id = p_order_id;

  update public.commerce_order_items
  set invoice_id = v_invoice_id
  where order_id = p_order_id;

  for v_item in (
    select
      coi.id,
      coi.cost_bdt,
      coi.sell_price_bdt,
      coi.recipient_price_bdt,
      coi.inventory_item_id,
      coi.shipment_item_id,
      coi.quantity,
      ii.tenant_id as inventory_tenant_id -- Resolve the actual supplier/owner tenant ID
    from public.commerce_order_items coi
    left join public.inventory_items ii on ii.id = coi.inventory_item_id
    where coi.order_id = p_order_id
  ) loop
    -- Resolve actual parent product ID
    select product_id into v_product_id
    from public.inventory_items
    where id = v_item.inventory_item_id;

    v_quantity := coalesce(v_item.quantity, 1);

    insert into public.inventory_accounting_entries (
      type,
      commerce_order_item_id,
      cost_amount,
      shipment_item_id,
      sell_price_amount,
      recipient_sell_price_amount,
      customer_group_id,
      billing_profile_id,
      status,
      tenant_id,
      inventory_item_id,
      product_id,
      quantity,
      total_cost_amount,
      total_sell_amount,
      gross_profit_amount
    )
    values (
      'commerce',
      v_item.id,
      coalesce(v_item.cost_bdt, 0),
      v_item.shipment_item_id,
      coalesce(v_item.sell_price_bdt, 0),
      coalesce(v_item.recipient_price_bdt, 0),
      v_cust_group_id,
      p_billing_profile_id,
      case when v_is_paid then 'paid'::text else 'due'::text end,
      coalesce(v_item.inventory_tenant_id, p_tenant_id), -- Map to supplier tenant
      v_item.inventory_item_id,
      v_product_id,
      v_quantity,
      (coalesce(v_item.cost_bdt, 0) * v_quantity),
      (coalesce(v_item.sell_price_bdt, 0) * v_quantity),
      ((coalesce(v_item.sell_price_bdt, 0) - coalesce(v_item.cost_bdt, 0)) * v_quantity)
    )
    on conflict (commerce_order_item_id) where (type = 'commerce')
    do update set
      cost_amount = excluded.cost_amount,
      inventory_item_id = excluded.inventory_item_id,
      shipment_item_id = excluded.shipment_item_id,
      sell_price_amount = excluded.sell_price_amount,
      recipient_sell_price_amount = excluded.recipient_sell_price_amount,
      customer_group_id = excluded.customer_group_id,
      billing_profile_id = excluded.billing_profile_id,
      status = excluded.status,
      tenant_id = excluded.tenant_id,
      product_id = excluded.product_id,
      quantity = excluded.quantity,
      total_cost_amount = excluded.total_cost_amount,
      total_sell_amount = excluded.total_sell_amount,
      gross_profit_amount = excluded.gross_profit_amount,
      updated_at = now();
  end loop;

  return v_invoice_id;
end;
$$;

-- 7. Redefine trg_fn_sync_commerce_invoice_payment_status to update the unified inventory_accounting_entries directly
create or replace function public.trg_fn_sync_commerce_invoice_payment_status()
returns trigger
language plpgsql
security definer
as $$
begin
  update public.inventory_accounting_entries
  set status = case when NEW.is_customer_group_paid then 'paid'::text else 'due'::text end,
      billing_profile_id = NEW.billing_profile_id,
      updated_at = now()
  where commerce_order_item_id in (
    select id from public.commerce_order_items
    where invoice_id = NEW.id
  );
  return NEW;
end;
$$;

-- 8. Recreate the unified v_shipment_accounting_ledger view (now simplified to query unified entries)
drop view if exists public.v_shipment_accounting_ledger;
create or replace view public.v_shipment_accounting_ledger
with (security_invoker = true) as
select
  type,
  id,
  tenant_id,
  coalesce(invoice_id, commerce_invoice_id) as invoice_id,
  invoice_item_id,
  inventory_item_id,
  product_id,
  quantity,
  cost_amount,
  sell_price_amount,
  total_cost_amount,
  total_sell_amount,
  gross_profit_amount,
  status,
  shipment_id,
  shipment_item_id,
  entry_date,
  note,
  created_at
from public.inventory_accounting_entries;

-- 9. Grant permissions to view and ledger functions
grant select, insert, update, delete on table public.commerce_accounting to authenticated;
grant select on table public.v_shipment_accounting_ledger to authenticated;

commit;
