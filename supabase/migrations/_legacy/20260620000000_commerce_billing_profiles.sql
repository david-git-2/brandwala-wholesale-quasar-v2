-- Migration: Add commerce_billing_profiles table and link to commerce invoices/accounting
begin;

-- 1. Create commerce_billing_profiles table
create table if not exists public.commerce_billing_profiles (
  id bigserial primary key,
  tenant_id bigint not null references public.tenants(id) on delete cascade,
  name text not null,
  email text null,
  customer_group_id bigint null references public.customer_groups(id) on delete set null,
  phone text null,
  address text null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists commerce_billing_profiles_tenant_id_idx
  on public.commerce_billing_profiles (tenant_id);

create index if not exists commerce_billing_profiles_customer_group_id_idx
  on public.commerce_billing_profiles (customer_group_id);

create index if not exists commerce_billing_profiles_name_idx
  on public.commerce_billing_profiles (name);

drop trigger if exists trg_commerce_billing_profiles_set_updated_at on public.commerce_billing_profiles;
create trigger trg_commerce_billing_profiles_set_updated_at
before update on public.commerce_billing_profiles
for each row execute function public.set_updated_at();

-- 2. RLS for commerce_billing_profiles
alter table public.commerce_billing_profiles enable row level security;

drop policy if exists commerce_billing_profiles_select on public.commerce_billing_profiles;
create policy commerce_billing_profiles_select
on public.commerce_billing_profiles for select to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
  )
);

drop policy if exists commerce_billing_profiles_insert on public.commerce_billing_profiles;
create policy commerce_billing_profiles_insert
on public.commerce_billing_profiles for insert to authenticated
with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists commerce_billing_profiles_update on public.commerce_billing_profiles;
create policy commerce_billing_profiles_update
on public.commerce_billing_profiles for update to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
)
with check (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

drop policy if exists commerce_billing_profiles_delete on public.commerce_billing_profiles;
create policy commerce_billing_profiles_delete
on public.commerce_billing_profiles for delete to authenticated
using (
  exists (
    select 1
    from public.memberships m
    where m.tenant_id = commerce_billing_profiles.tenant_id
      and lower(trim(m.email)) = public.current_user_email()
      and m.is_active = true
      and m.role in ('admin', 'staff')
  )
);

grant select, insert, update, delete on table public.commerce_billing_profiles to authenticated;
grant usage, select on sequence public.commerce_billing_profiles_id_seq to authenticated;


-- 3. Update commerce_invoices table to have billing_profile_id
alter table public.commerce_invoices
  add column if not exists billing_profile_id bigint null references public.commerce_billing_profiles(id) on delete set null;

create index if not exists commerce_invoices_billing_profile_idx on public.commerce_invoices(billing_profile_id);


-- 4. Update commerce_accounting table to have billing_profile_id and drop not null on customer_group_id
alter table public.commerce_accounting
  add column if not exists billing_profile_id bigint null references public.commerce_billing_profiles(id) on delete set null,
  alter column customer_group_id drop not null;

create index if not exists commerce_accounting_billing_profile_idx on public.commerce_accounting(billing_profile_id);


-- 5. Recreate create_commerce_invoice RPC function
drop function if exists public.create_commerce_invoice(bigint, bigint, numeric, numeric, numeric, numeric, numeric, text);
drop function if exists public.create_commerce_invoice(bigint, bigint, numeric, numeric, numeric, numeric, numeric, text, bigint);

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
  set invoice_id = v_invoice_id;
  -- wait! No where clause on update order items?
  -- In original it was: where order_id = p_order_id
  update public.commerce_order_items
  set invoice_id = v_invoice_id
  where order_id = p_order_id;

  for v_item in (
    select
      id,
      cost_bdt,
      sell_price_bdt,
      recipient_price_bdt,
      inventory_item_id,
      shipment_item_id
    from public.commerce_order_items
    where order_id = p_order_id
  ) loop
    insert into public.commerce_accounting (
      order_item_id,
      cost_bdt,
      inventory_item_id,
      shipment_item_id,
      sell_price_bdt,
      recipient_sell_price_bdt,
      customer_group_id,
      billing_profile_id,
      is_customer_group_paid,
      tenant_id
    )
    values (
      v_item.id,
      coalesce(v_item.cost_bdt, 0),
      v_item.inventory_item_id,
      v_item.shipment_item_id,
      coalesce(v_item.sell_price_bdt, 0),
      coalesce(v_item.recipient_price_bdt, 0),
      v_cust_group_id,
      p_billing_profile_id,
      v_is_paid,
      p_tenant_id
    )
    on conflict (order_item_id)
    do update set
      cost_bdt = excluded.cost_bdt,
      inventory_item_id = excluded.inventory_item_id,
      shipment_item_id = excluded.shipment_item_id,
      sell_price_bdt = excluded.sell_price_bdt,
      recipient_sell_price_bdt = excluded.recipient_sell_price_bdt,
      customer_group_id = excluded.customer_group_id,
      billing_profile_id = excluded.billing_profile_id,
      is_customer_group_paid = excluded.is_customer_group_paid,
      tenant_id = excluded.tenant_id,
      updated_at = now();
  end loop;

  return v_invoice_id;
end;
$$;

grant execute on function public.create_commerce_invoice(bigint, bigint, numeric, numeric, numeric, numeric, numeric, text, bigint) to authenticated;


-- 6. Update payment status sync trigger to also sync billing_profile_id
create or replace function public.trg_fn_sync_commerce_invoice_payment_status()
returns trigger
language plpgsql
security definer
as $$
begin
  update public.commerce_accounting
  set is_customer_group_paid = NEW.is_customer_group_paid,
      billing_profile_id = NEW.billing_profile_id,
      updated_at = now()
  where order_item_id in (
    select id from public.commerce_order_items
    where invoice_id = NEW.id
  );
  return NEW;
end;
$$;

commit;
