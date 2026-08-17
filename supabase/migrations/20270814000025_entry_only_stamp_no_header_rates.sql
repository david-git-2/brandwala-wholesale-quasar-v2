-- Companion migration for Phase 7 (must run before 20270814000030_drop_shipment_header_rate_columns.sql)
-- Rewrite functions to remove header rate column reads (product_conversion_rate, cargo_conversion_rate, cargo_rate, transaction_rate)

begin;

-- 1. ensure_global_shipment_cost_entries_from_header
create or replace function public.ensure_global_shipment_cost_entries_from_header(p_shipment_id bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_goods numeric;
  v_cargo_amt numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if exists (
    select 1 from public.global_shipment_cost_entries e where e.shipment_id = p_shipment_id
  ) then
    return;
  end if;

  select coalesce(sum(gsi.purchase_price * gsi.ordered_quantity), 0)
  into v_goods
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  if v_ship.purchase_invoice_total is not null and v_ship.purchase_invoice_total > 0 then
    v_goods := v_ship.purchase_invoice_total;
  end if;

  v_cargo_amt := coalesce(v_ship.cargo_invoice_total, 0);

  insert into public.global_shipment_cost_entries (
    parent_tenant_id, shipment_id, cost_type, amount, currency_id, exchange_rate, metadata
  ) values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    'product',
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    1.0,
    jsonb_build_object('source', 'header_backfill')
  );

  if v_cargo_amt > 0 then
    insert into public.global_shipment_cost_entries (
      parent_tenant_id, shipment_id, cost_type, amount, currency_id, exchange_rate, metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      'cargo',
      v_cargo_amt,
      v_ship.shipment_cost_currency_id,
      1.0,
      jsonb_build_object('source', 'header_backfill')
    );
  end if;
end;
$$;

revoke all on function public.ensure_global_shipment_cost_entries_from_header(bigint) from public;
grant execute on function public.ensure_global_shipment_cost_entries_from_header(bigint) to authenticated;

-- 2. stamp_global_shipment_landed_costs
create or replace function public.stamp_global_shipment_landed_costs(p_shipment_id bigint)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_ship public.global_shipments%rowtype;
  v_product_amount numeric := 0;
  v_cargo_amount numeric := 0;
  v_goods_bdt numeric := 0;
  v_cargo_bdt numeric := 0;
  v_blended numeric := 1;
  v_pack_kg numeric := 0;
  v_updated integer := 0;
  r record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_base numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  perform public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

  select
    coalesce(sum(amount) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount) filter (where cost_type != 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type != 'product'), 0)
  into v_product_amount, v_goods_bdt, v_cargo_amount, v_cargo_bdt
  from public.global_shipment_cost_entries
  where shipment_id = p_shipment_id;

  if (v_product_amount + v_cargo_amount) > 0 then
    v_blended := (v_goods_bdt + v_cargo_bdt) / (v_product_amount + v_cargo_amount);
  else
    v_blended := 1;
  end if;

  select coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
  into v_pack_kg
  from public.global_shipment_items gsi
  where gsi.shipment_id = p_shipment_id;

  perform set_config('app.allow_landed_cost_stamp', '1', true);

  for r in
    select *
    from public.global_shipment_items
    where shipment_id = p_shipment_id
  loop
    v_line_gross := (
      (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) * r.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_amount;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_amount;
    else
      v_line_cargo_share := 0;
    end if;

    if r.ordered_quantity > 0 then
      v_unit_base := coalesce(r.purchase_price, 0) + (v_line_cargo_share / r.ordered_quantity);
    else
      v_unit_base := coalesce(r.purchase_price, 0);
    end if;

    if v_ship.type::text in ('local', 'domestic') then
      v_landed := v_unit_base;
    else
      v_landed := v_unit_base * v_blended;
    end if;

    update public.global_shipment_items
    set landed_cost_bdt = round(v_landed::numeric, 4)
    where id = r.id;

    v_updated := v_updated + 1;
  end loop;

  return v_updated;
end;
$$;

revoke all on function public.stamp_global_shipment_landed_costs(bigint) from public;
grant execute on function public.stamp_global_shipment_landed_costs(bigint) to authenticated;

-- 3. calculate_landed_unit_cost
create or replace function public.calculate_landed_unit_cost(p_shipment_item_id bigint)
returns numeric
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_stamp numeric;
  v_shipment_id bigint;
  v_shipment_type public.global_shipment_type;

  v_purchase_price numeric;
  v_product_weight numeric;
  v_package_weight numeric;
  v_qty numeric;

  v_total_packaging_weight_kg numeric := 0;
  v_line_gross_weight_kg numeric;
  v_line_cargo_share numeric := 0;
  v_line_purchase_base numeric;
  v_effective_rate numeric := 1;
  v_landed_cost numeric;
  v_total_qty numeric;

  v_product_amount numeric := 0;
  v_cargo_amount numeric := 0;
  v_goods_bdt numeric := 0;
  v_cargo_bdt numeric := 0;
begin
  select
    shipment_id,
    purchase_price,
    product_weight,
    package_weight,
    ordered_quantity,
    landed_cost_bdt
  into
    v_shipment_id,
    v_purchase_price,
    v_product_weight,
    v_package_weight,
    v_qty,
    v_stamp
  from public.global_shipment_items
  where id = p_shipment_item_id;

  if v_shipment_id is null then
    return 0.00;
  end if;

  -- Authoritative after finalize / revise
  if v_stamp is not null then
    return round(v_stamp::numeric, 4);
  end if;

  select type
  into v_shipment_type
  from public.global_shipments
  where id = v_shipment_id;

  select
    coalesce(sum(amount) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount) filter (where cost_type != 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type != 'product'), 0)
  into v_product_amount, v_goods_bdt, v_cargo_amount, v_cargo_bdt
  from public.global_shipment_cost_entries
  where shipment_id = v_shipment_id;

  select coalesce(sum(((product_weight + package_weight) * ordered_quantity) / 1000.0), 0)
  into v_total_packaging_weight_kg
  from public.global_shipment_items
  where shipment_id = v_shipment_id;

  v_line_gross_weight_kg := ((coalesce(v_product_weight, 0) + coalesce(v_package_weight, 0)) * coalesce(v_qty, 0)) / 1000.0;

  if v_qty > 0 and v_cargo_amount > 0 then
    if v_total_packaging_weight_kg > 0 then
      v_line_cargo_share := ((v_line_gross_weight_kg / v_total_packaging_weight_kg) * v_cargo_amount) / v_qty;
    else
      select coalesce(sum(ordered_quantity), 0) into v_total_qty
      from public.global_shipment_items
      where shipment_id = v_shipment_id;
      if v_total_qty > 0 then
        v_line_cargo_share := ((v_qty / v_total_qty) * v_cargo_amount) / v_qty;
      end if;
    end if;
  end if;

  v_line_purchase_base := coalesce(v_purchase_price, 0) + coalesce(v_line_cargo_share, 0);

  if v_shipment_type::text in ('local', 'domestic') then
    return round(v_line_purchase_base::numeric, 4);
  end if;

  if (v_product_amount + v_cargo_amount) > 0 then
    v_effective_rate := (v_goods_bdt + v_cargo_bdt) / (v_product_amount + v_cargo_amount);
  else
    v_effective_rate := 1.0;
  end if;

  v_landed_cost := v_line_purchase_base * v_effective_rate;
  return round(v_landed_cost::numeric, 4);
end;
$$;

commit;
