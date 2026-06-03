-- Migration: Ensure inspected and receiving_splits columns exist, drop deprecated columns and update add_shipment_item_manual RPC
begin;

-- 1. Drop constraints if exist
alter table public.shipment_items drop constraint if exists shipment_items_received_quantity_check;
alter table public.shipment_items drop constraint if exists shipment_items_damaged_quantity_check;
alter table public.shipment_items drop constraint if exists shipment_items_stolen_quantity_check;

-- 2. Drop columns from shipment_items table
alter table public.shipment_items drop column if exists received_quantity;
alter table public.shipment_items drop column if exists damaged_quantity;
alter table public.shipment_items drop column if exists stolen_quantity;

-- 3. Add new columns
alter table public.shipment_items add column if not exists inspected boolean not null default false;
alter table public.shipment_items add column if not exists receiving_splits jsonb null;

-- 4. Redefine add_shipment_item_manual function to accept p_receiving_splits argument
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
  p_receiving_splits jsonb default null
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
    receiving_splits
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
    p_receiving_splits
  )
  returning * into v_row;

  return v_row;
end;
$$;

commit;
