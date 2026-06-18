-- B7: commerce global_stock_id prep, legacy cleanup, deprecate is_gbp
begin;

-- Commerce retarget column (F7)
alter table public.commerce_order_items
  add column if not exists global_stock_id bigint null references public.global_stocks(id) on delete set null;

alter table public.commerce_cart
  add column if not exists global_stock_id bigint null references public.global_stocks(id) on delete set null;

alter table public.store_product_prices
  add column if not exists global_stock_id bigint null references public.global_stocks(id) on delete set null;

create index if not exists commerce_order_items_global_stock_id_idx
  on public.commerce_order_items (global_stock_id);

-- Backfill global_stock_id from legacy inventory mapping where possible
update public.commerce_order_items coi
set global_stock_id = gs.id
from public.global_stocks gs
where coi.global_stock_id is null
  and coi.inventory_item_id is not null
  and gs.legacy_inventory_item_id = coi.inventory_item_id;

-- Run one-time stock migration for any remaining legacy rows
select public.migrate_legacy_inventory_to_global_stock(null);

-- Drop legacy views if exist
drop view if exists public.v_shipment_accounting_ledger;

-- Drop legacy accounting / invoice dependencies in safe order
drop table if exists public.invoice_accounting_payments cascade;
drop table if exists public.inventory_accounting_entries cascade;
drop table if exists public.invoice_items cascade;
drop table if exists public.invoices cascade;
drop table if exists public.shipment_inventory_accounting cascade;

-- Drop inventory layer (global is sole write target)
drop table if exists public.inventory_notes cascade;
drop table if exists public.inventory_movements cascade;
drop table if exists public.inventory_stocks cascade;
drop table if exists public.inventory_items cascade;

-- Retarget shipment triggers/functions from is_gbp -> shipment_type before column drop
drop trigger if exists trg_shipments_sync_shipment_type on public.shipments;
drop trigger if exists trg_shipments_recalc_transaction_rate on public.shipments;

create or replace function public.recalculate_shipment_transaction_rate(p_shipment_id bigint)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_product_conv numeric;
  v_cargo_conv numeric;
  v_cargo_rate numeric;
  v_received_weight numeric;
  v_shipment_type text;
  v_goods_cost_gbp numeric := 0;
  v_goods_cost_bdt numeric := 0;
  v_cargo_weight numeric := 0;
  v_cargo_cost_gbp numeric := 0;
  v_cargo_cost_bdt numeric := 0;
  v_total_cost_gbp numeric := 0;
  v_total_cost_bdt numeric := 0;
  v_transaction_rate numeric;
begin
  select
    product_conversion_rate,
    cargo_conversion_rate,
    cargo_rate,
    received_weight,
    shipment_type
  into
    v_product_conv,
    v_cargo_conv,
    v_cargo_rate,
    v_received_weight,
    v_shipment_type
  from public.shipments
  where id = p_shipment_id;

  if coalesce(v_shipment_type, 'international') <> 'international' then
    update public.shipments
    set transaction_rate = null
    where id = p_shipment_id;
    return null;
  end if;

  select coalesce(sum(price_gbp * quantity), 0)
  into v_goods_cost_gbp
  from public.shipment_items
  where shipment_id = p_shipment_id;

  v_goods_cost_bdt := coalesce(v_product_conv, 0) * v_goods_cost_gbp;
  v_cargo_weight := coalesce(v_received_weight, 0);
  v_cargo_cost_gbp := v_cargo_weight * coalesce(v_cargo_rate, 0);
  v_cargo_cost_bdt := v_cargo_cost_gbp * coalesce(v_cargo_conv, 0);
  v_total_cost_gbp := v_goods_cost_gbp + v_cargo_cost_gbp;
  v_total_cost_bdt := v_goods_cost_bdt + v_cargo_cost_bdt;

  if v_total_cost_gbp > 0 then
    v_transaction_rate := v_total_cost_bdt / v_total_cost_gbp;
  else
    v_transaction_rate := (coalesce(v_product_conv, 0) + coalesce(v_cargo_conv, 0)) / 2.0;
  end if;

  update public.shipments
  set transaction_rate = round(coalesce(v_transaction_rate, 1.0), 2)
  where id = p_shipment_id;

  return v_transaction_rate;
end;
$$;

create or replace function public.trg_shipments_recalc_transaction_rate()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.recalculate_shipment_transaction_rate(new.id);
  return new;
end;
$$;

create trigger trg_shipments_recalc_transaction_rate
after update of product_conversion_rate, cargo_conversion_rate, cargo_rate, received_weight, shipment_type
on public.shipments
for each row
execute function public.trg_shipments_recalc_transaction_rate();

-- update_shipment: remove is_gbp branch (shipment_type only)
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
  v_type text;
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
    update public.shipments set name = v_value where id = p_id returning * into v_row;
  elsif v_field = 'shipment_type' then
    v_type := lower(v_value);
    if v_type not in ('local', 'international') then
      raise exception 'invalid shipment_type: %', v_value;
    end if;
    update public.shipments set shipment_type = v_type where id = p_id returning * into v_row;
  elsif v_field = 'status' then
    update public.shipments set status = v_value where id = p_id returning * into v_row;
  elsif v_field = 'inventory_added' then
    update public.shipments
    set inventory_added = coalesce(nullif(v_value, '')::boolean, false)
    where id = p_id returning * into v_row;
  elsif v_field = 'product_conversion_rate' then
    update public.shipments
    set product_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'cargo_conversion_rate' then
    update public.shipments
    set cargo_conversion_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'cargo_rate' then
    update public.shipments
    set cargo_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'weight' then
    update public.shipments
    set weight = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'received_weight' then
    update public.shipments
    set received_weight = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  elsif v_field = 'transaction_rate' then
    update public.shipments
    set transaction_rate = nullif(v_value, '')::numeric
    where id = p_id returning * into v_row;
  else
    raise exception 'unsupported shipment field: %', p_field;
  end if;

  return v_row;
end;
$$;

-- create_shipment: write shipment_type only (no is_gbp column after drop)
create or replace function public.create_shipment(
  p_name text,
  p_tenant_id bigint,
  p_shipment_type text default 'international'
)
returns public.shipments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.shipments;
  v_type text;
begin
  if not public.can_manage_shipment(p_tenant_id) then
    raise exception 'not allowed';
  end if;

  v_type := lower(trim(coalesce(p_shipment_type, 'international')));
  if v_type not in ('local', 'international') then
    raise exception 'invalid shipment_type: %', p_shipment_type;
  end if;

  insert into public.shipments (name, tenant_id, shipment_type)
  values (trim(p_name), p_tenant_id, v_type)
  returning * into v_row;

  return v_row;
end;
$$;

-- Drop deprecated shipment flag (shipment_type is canonical)
alter table public.shipments drop column if exists is_gbp;

drop function if exists public.sync_shipment_type_and_is_gbp();

-- Drop boolean overload of create_shipment (keep text shipment_type overload)
drop function if exists public.create_shipment(text, bigint, boolean);

-- Grant execute on new global RPCs to authenticated (idempotent)
grant execute on function public.receive_shipment_to_global_stock(bigint) to authenticated;
grant execute on function public.list_global_stock_for_tenant(bigint, text, integer, integer) to authenticated;
grant execute on function public.list_child_procurement_lines(bigint, bigint, text, integer, integer) to authenticated;
grant execute on function public.add_child_line_to_parent_shipment(bigint, text, bigint) to authenticated;
grant execute on function public.create_global_invoice(bigint, text, public.global_invoice_type, public.global_source_module, bigint, bigint, bigint, text) to authenticated;
grant execute on function public.add_global_invoice_item(bigint, bigint, numeric, numeric, numeric) to authenticated;
grant execute on function public.get_parent_cash_circulation(bigint) to authenticated;
grant execute on function public.get_investor_bootstrap_context(bigint) to authenticated;
grant execute on function public.get_investor_portfolio_summary(bigint) to authenticated;

commit;
