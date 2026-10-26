-- Migration: Add BDT-only Shipment Configuration and Direct BDT Cost Columns
begin;

-- 1. Alter shipments & shipment_items tables
alter table public.shipments
  add column if not exists is_gbp boolean not null default true;

alter table public.shipment_items
  add column if not exists cost_bdt numeric(12,2) null;

-- 2. Redefine create_shipment to accept is_gbp
drop function if exists public.create_shipment(text, bigint);

create or replace function public.create_shipment(
  p_name text,
  p_tenant_id bigint,
  p_is_gbp boolean default true
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

  insert into public.shipments (name, tenant_id, is_gbp)
  values (trim(p_name), p_tenant_id, p_is_gbp)
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.create_shipment(text, bigint, boolean) to authenticated;

-- 3. Redefine update_shipment to support is_gbp
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
  elsif v_field = 'is_gbp' then
    update public.shipments
    set is_gbp = coalesce(nullif(v_value, '')::boolean, true)
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

grant execute on function public.update_shipment(bigint, text, text) to authenticated;

-- 4. Redefine add_shipment_item_manual to support cost_bdt
drop function if exists public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, jsonb);

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
  p_receiving_splits jsonb default null,
  p_cost_bdt numeric default null
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
    receiving_splits,
    cost_bdt
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
    p_receiving_splits,
    p_cost_bdt
  )
  returning * into v_row;

  return v_row;
end;
$$;

grant execute on function public.add_shipment_item_manual(bigint, text, integer, text, text, bigint, text, numeric, numeric, numeric, jsonb, numeric) to authenticated;

commit;
