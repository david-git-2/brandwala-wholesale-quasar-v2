-- Shipment cost entries: bucket × component axes + is_capitalizable stamp flag.

create type public.global_shipment_cost_bucket as enum (
  'material', 'freight', 'customs', 'handling', 'finance', 'other'
);

create type public.global_shipment_cost_component as enum (
  'subtotal', 'carriage', 'vat_tax', 'misc'
);

alter table public.global_shipment_cost_entries
  add column if not exists cost_bucket public.global_shipment_cost_bucket,
  add column if not exists cost_component public.global_shipment_cost_component,
  add column if not exists is_capitalizable boolean,
  add column if not exists description text,
  add column if not exists item_sku text;

update public.global_shipment_cost_entries e
set
  cost_bucket = case e.cost_type
    when 'product' then 'material'::public.global_shipment_cost_bucket
    when 'cargo' then 'freight'::public.global_shipment_cost_bucket
    when 'duty' then 'customs'::public.global_shipment_cost_bucket
    when 'insurance' then 'finance'::public.global_shipment_cost_bucket
    when 'handling' then 'handling'::public.global_shipment_cost_bucket
    when 'transport' then 'handling'::public.global_shipment_cost_bucket
    when 'labor' then 'handling'::public.global_shipment_cost_bucket
    when 'washing' then 'other'::public.global_shipment_cost_bucket
    when 'local' then 'other'::public.global_shipment_cost_bucket
  end,
  cost_component = case e.cost_type
    when 'product' then 'subtotal'::public.global_shipment_cost_component
    when 'cargo' then 'subtotal'::public.global_shipment_cost_component
    when 'duty' then 'vat_tax'::public.global_shipment_cost_component
    when 'insurance' then 'subtotal'::public.global_shipment_cost_component
    when 'handling' then 'subtotal'::public.global_shipment_cost_component
    when 'transport' then 'carriage'::public.global_shipment_cost_component
    when 'labor' then 'misc'::public.global_shipment_cost_component
    when 'washing' then 'misc'::public.global_shipment_cost_component
    when 'local' then 'misc'::public.global_shipment_cost_component
  end,
  is_capitalizable = case e.cost_type
    when 'local' then false
    when 'washing' then false
    when 'duty' then false
    else true
  end,
  description = coalesce(
    nullif(trim(e.metadata->>'description'), ''),
    e.description
  )
where e.cost_bucket is null;

alter table public.global_shipment_cost_entries
  alter column cost_bucket set not null,
  alter column cost_component set not null,
  alter column is_capitalizable set not null,
  alter column is_capitalizable set default true;

comment on column public.global_shipment_cost_entries.cost_bucket is
  'Operational category: material, freight, customs, handling, finance, other.';
comment on column public.global_shipment_cost_entries.cost_component is
  'Voucher line axis: subtotal, carriage, vat_tax, misc.';
comment on column public.global_shipment_cost_entries.is_capitalizable is
  'When true, amount flows into landed unit cost (BDT stamp). When false, P&L / local opex only.';
comment on column public.global_shipment_cost_entries.item_sku is
  'Product SKU when cost is line-specific; null or ALL for shared shipment overhead.';

CREATE OR REPLACE FUNCTION "public"."trg_fn_global_shipment_cost_entry_axes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.cost_bucket is null and new.cost_type is not null then
    new.cost_bucket := case new.cost_type
      when 'product' then 'material'::public.global_shipment_cost_bucket
      when 'cargo' then 'freight'::public.global_shipment_cost_bucket
      when 'duty' then 'customs'::public.global_shipment_cost_bucket
      when 'insurance' then 'finance'::public.global_shipment_cost_bucket
      when 'handling' then 'handling'::public.global_shipment_cost_bucket
      when 'transport' then 'handling'::public.global_shipment_cost_bucket
      when 'labor' then 'handling'::public.global_shipment_cost_bucket
      when 'washing' then 'other'::public.global_shipment_cost_bucket
      when 'local' then 'other'::public.global_shipment_cost_bucket
    end;
    new.cost_component := case new.cost_type
      when 'product' then 'subtotal'::public.global_shipment_cost_component
      when 'cargo' then 'subtotal'::public.global_shipment_cost_component
      when 'duty' then 'vat_tax'::public.global_shipment_cost_component
      when 'insurance' then 'subtotal'::public.global_shipment_cost_component
      when 'handling' then 'subtotal'::public.global_shipment_cost_component
      when 'transport' then 'carriage'::public.global_shipment_cost_component
      when 'labor' then 'misc'::public.global_shipment_cost_component
      when 'washing' then 'misc'::public.global_shipment_cost_component
      when 'local' then 'misc'::public.global_shipment_cost_component
    end;
    new.is_capitalizable := case new.cost_type
      when 'local' then false
      when 'washing' then false
      when 'duty' then false
      else true
    end;
  end if;

  if new.cost_bucket is not null then
    new.cost_type := case new.cost_bucket
      when 'material' then 'product'::public.global_shipment_cost_type
      when 'freight' then 'cargo'::public.global_shipment_cost_type
      when 'customs' then 'duty'::public.global_shipment_cost_type
      when 'handling' then
        case
          when new.cost_component = 'carriage'::public.global_shipment_cost_component then 'transport'::public.global_shipment_cost_type
          when new.cost_component = 'misc'::public.global_shipment_cost_component then 'labor'::public.global_shipment_cost_type
          else 'handling'::public.global_shipment_cost_type
        end
      when 'finance' then 'insurance'::public.global_shipment_cost_type
      when 'other' then 'local'::public.global_shipment_cost_type
    end;
  end if;

  if new.description is null and new.metadata ? 'description' then
    new.description := nullif(trim(new.metadata->>'description'), '');
  end if;

  if new.item_sku is not null and upper(trim(new.item_sku)) = 'ALL' then
    new.item_sku := null;
  end if;

  return new;
end;
$$;
ALTER FUNCTION "public"."trg_fn_global_shipment_cost_entry_axes"() OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."ensure_global_shipment_cost_entries_from_header"("p_shipment_id" bigint) RETURNS "void"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    parent_tenant_id,
    shipment_id,
    cost_type,
    cost_bucket,
    cost_component,
    is_capitalizable,
    amount,
    currency_id,
    exchange_rate,
    metadata
  ) values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    'product',
    'material',
    'subtotal',
    true,
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    1.0,
    jsonb_build_object('source', 'header_backfill')
  );

  if v_cargo_amt > 0 then
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_type,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      exchange_rate,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      'cargo',
      'freight',
      'subtotal',
      true,
      v_cargo_amt,
      v_ship.shipment_cost_currency_id,
      1.0,
      jsonb_build_object('source', 'header_backfill')
    );
  end if;
end;
$$;
ALTER FUNCTION "public"."ensure_global_shipment_cost_entries_from_header"("p_shipment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."stamp_global_shipment_landed_costs"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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
    coalesce(sum(amount) filter (where is_capitalizable and cost_bucket = 'material'), 0),
    coalesce(sum(amount * exchange_rate) filter (where is_capitalizable and cost_bucket = 'material'), 0),
    coalesce(sum(amount) filter (where is_capitalizable and cost_bucket <> 'material'), 0),
    coalesce(sum(amount * exchange_rate) filter (where is_capitalizable and cost_bucket <> 'material'), 0)
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

  perform public._stamp_global_shipment_outcome_costs(p_shipment_id);

  return v_updated;
end;
$$;
ALTER FUNCTION "public"."stamp_global_shipment_landed_costs"("p_shipment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."save_global_shipment_cost_entries"("p_shipment_id" bigint, "p_entries" "jsonb", "p_delete_ids" bigint[] DEFAULT '{}'::bigint[], "p_received_weight" numeric DEFAULT NULL::numeric, "p_total_weight_kg" numeric DEFAULT NULL::numeric) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_row public.global_shipment_cost_entries%rowtype;
  v_id bigint;
  v_amount numeric;
  v_rate numeric;
  v_stamped integer := 0;
  v_cost_entries jsonb;
  v_items jsonb;
  v_cost_type public.global_shipment_cost_type;
  v_cost_bucket public.global_shipment_cost_bucket;
  v_cost_component public.global_shipment_cost_component;
  v_is_capitalizable boolean;
  v_description text;
  v_item_sku text;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '1', true);

  if p_received_weight is not null or p_total_weight_kg is not null then
    update public.global_shipments
    set
      received_weight = coalesce(p_received_weight, received_weight),
      total_weight_kg = coalesce(p_total_weight_kg, total_weight_kg),
      updated_at = now()
    where id = p_shipment_id
    returning * into v_ship;
  end if;

  if p_delete_ids is not null and cardinality(p_delete_ids) > 0 then
    delete from public.global_shipment_cost_entries e
    where e.shipment_id = p_shipment_id
      and e.id = any(p_delete_ids);
  end if;

  if p_entries is not null and jsonb_typeof(p_entries) = 'array' then
    for v_entry in select value from jsonb_array_elements(p_entries)
    loop
      v_amount := nullif(v_entry->>'amount', '')::numeric;
      v_rate := coalesce(nullif(v_entry->>'exchange_rate', '')::numeric, 1.0);
      v_id := nullif(v_entry->>'id', '')::bigint;

      if v_amount is null or v_amount < 0 then
        raise exception 'amount must be >= 0';
      end if;

      if v_rate is null or v_rate <= 0 then
        raise exception 'exchange_rate must be > 0';
      end if;

      v_cost_type := (v_entry->>'cost_type')::public.global_shipment_cost_type;
      v_cost_bucket := nullif(v_entry->>'cost_bucket', '')::public.global_shipment_cost_bucket;
      v_cost_component := nullif(v_entry->>'cost_component', '')::public.global_shipment_cost_component;
      v_is_capitalizable := case
        when v_entry ? 'is_capitalizable' then (v_entry->>'is_capitalizable')::boolean
        else null
      end;
      v_description := nullif(trim(v_entry->>'description'), '');
      v_item_sku := nullif(trim(v_entry->>'item_sku'), '');

      if v_id is not null then
        update public.global_shipment_cost_entries e
        set
          cost_type = v_cost_type,
          cost_bucket = coalesce(v_cost_bucket, e.cost_bucket),
          cost_component = coalesce(v_cost_component, e.cost_component),
          is_capitalizable = coalesce(v_is_capitalizable, e.is_capitalizable),
          description = coalesce(v_description, e.description),
          item_sku = coalesce(v_item_sku, e.item_sku),
          amount = v_amount,
          exchange_rate = v_rate,
          currency_id = nullif(v_entry->>'currency_id', '')::bigint,
          payment_source = nullif(v_entry->>'payment_source', ''),
          entity_type = nullif(v_entry->>'entity_type', ''),
          entity_id = nullif(v_entry->>'entity_id', '')::bigint,
          allocation = nullif(v_entry->>'allocation', ''),
          metadata = coalesce(v_entry->'metadata', '{}'::jsonb),
          section_id = nullif(v_entry->>'section_id', '')::bigint,
          updated_at = now()
        where e.id = v_id
          and e.shipment_id = p_shipment_id
        returning * into v_row;

        if not found then
          raise exception 'cost entry % not found on shipment %', v_id, p_shipment_id;
        end if;
      else
        insert into public.global_shipment_cost_entries (
          parent_tenant_id,
          shipment_id,
          cost_type,
          cost_bucket,
          cost_component,
          is_capitalizable,
          description,
          item_sku,
          amount,
          currency_id,
          exchange_rate,
          payment_source,
          entity_type,
          entity_id,
          allocation,
          metadata,
          section_id
        ) values (
          v_ship.parent_tenant_id,
          p_shipment_id,
          v_cost_type,
          v_cost_bucket,
          v_cost_component,
          coalesce(v_is_capitalizable, true),
          v_description,
          v_item_sku,
          v_amount,
          nullif(v_entry->>'currency_id', '')::bigint,
          v_rate,
          nullif(v_entry->>'payment_source', ''),
          nullif(v_entry->>'entity_type', ''),
          nullif(v_entry->>'entity_id', '')::bigint,
          nullif(v_entry->>'allocation', ''),
          coalesce(v_entry->'metadata', '{}'::jsonb),
          nullif(v_entry->>'section_id', '')::bigint
        )
        returning * into v_row;
      end if;
    end loop;
  end if;

  perform set_config('app.skip_shipment_landed_restamp', '0', true);

  if exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  select coalesce(jsonb_agg(to_jsonb(e) order by e.id), '[]'::jsonb)
  into v_cost_entries
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  select coalesce(jsonb_agg(to_jsonb(i) order by i.sort_order, i.id), '[]'::jsonb)
  into v_items
  from public.global_shipment_items i
  where i.shipment_id = p_shipment_id;

  return jsonb_build_object(
    'cost_entries', v_cost_entries,
    'items', v_items,
    'items_stamped', v_stamped,
    'shipment', jsonb_build_object(
      'id', v_ship.id,
      'received_weight', v_ship.received_weight,
      'total_weight_kg', v_ship.total_weight_kg,
      'updated_at', v_ship.updated_at
    )
  );
end;
$$;
ALTER FUNCTION "public"."save_global_shipment_cost_entries"("p_shipment_id" bigint, "p_entries" "jsonb", "p_delete_ids" bigint[], "p_received_weight" numeric, "p_total_weight_kg" numeric) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."_stamp_global_shipment_outcome_costs"("p_shipment_id" bigint) RETURNS integer
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_product_amount numeric := 0;
  v_cargo_amount numeric := 0;
  v_goods_bdt numeric := 0;
  v_cargo_bdt numeric := 0;
  v_blended numeric := 1;
  v_pack_kg numeric := 0;
  v_updated integer := 0;
  r_out record;
  r_line record;
  v_line_gross numeric;
  v_line_cargo_share numeric;
  v_unit_base numeric;
  v_landed numeric;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if not found then
    return 0;
  end if;

  select
    coalesce(sum(amount) filter (where is_capitalizable and cost_bucket = 'material'), 0),
    coalesce(sum(amount * exchange_rate) filter (where is_capitalizable and cost_bucket = 'material'), 0),
    coalesce(sum(amount) filter (where is_capitalizable and cost_bucket <> 'material'), 0),
    coalesce(sum(amount * exchange_rate) filter (where is_capitalizable and cost_bucket <> 'material'), 0)
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

  for r_out in
    select o.*
    from public.global_shipment_item_outcomes o
    inner join public.global_shipment_items gsi on gsi.id = o.shipment_item_id
    where gsi.shipment_id = p_shipment_id
      and o.reason <> 'ordered'::public.global_shipment_outcome_reason
  loop
    select * into r_line from public.global_shipment_items where id = r_out.shipment_item_id;

    v_line_gross := (
      (coalesce(r_line.product_weight, 0) + coalesce(r_line.package_weight, 0)) * r_line.ordered_quantity
    ) / 1000.0;

    if v_pack_kg > 0 then
      v_line_cargo_share := (v_line_gross / v_pack_kg) * v_cargo_amount;
    elsif (select coalesce(sum(ordered_quantity), 0) from public.global_shipment_items where shipment_id = p_shipment_id) > 0 then
      v_line_cargo_share := (r_line.ordered_quantity::numeric
        / (select sum(ordered_quantity) from public.global_shipment_items where shipment_id = p_shipment_id)
      ) * v_cargo_amount;
    else
      v_line_cargo_share := 0;
    end if;

    if r_line.ordered_quantity > 0 then
      v_unit_base := coalesce(r_out.purchase_price, 0) + (v_line_cargo_share / r_line.ordered_quantity);
    else
      v_unit_base := coalesce(r_out.purchase_price, 0);
    end if;

    if v_ship.type::text in ('local', 'domestic') then
      v_landed := v_unit_base;
    else
      v_landed := v_unit_base * v_blended;
    end if;

    update public.global_shipment_item_outcomes
    set cost = round(v_landed::numeric, 4)
    where id = r_out.id;

    v_updated := v_updated + 1;
  end loop;

  return v_updated;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."calculate_landed_unit_cost"("p_shipment_item_id" bigint) RETURNS numeric
    LANGUAGE "plpgsql" STABLE SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
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

  if v_stamp is not null then
    return round(v_stamp::numeric, 4);
  end if;

  select type
  into v_shipment_type
  from public.global_shipments
  where id = v_shipment_id;

  select
    coalesce(sum(amount) filter (where is_capitalizable and cost_bucket = 'material'), 0),
    coalesce(sum(amount * exchange_rate) filter (where is_capitalizable and cost_bucket = 'material'), 0),
    coalesce(sum(amount) filter (where is_capitalizable and cost_bucket <> 'material'), 0),
    coalesce(sum(amount * exchange_rate) filter (where is_capitalizable and cost_bucket <> 'material'), 0)
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
ALTER FUNCTION "public"."calculate_landed_unit_cost"("p_shipment_item_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments;
  v_parent bigint;
  v_issued_by bigint;
  v_vendor_profile bigint;
  v_cargo_profile bigint;
  v_local_profile bigint;
  v_vendor_amt numeric(12, 2) := 0;
  v_cargo_amt numeric(12, 2) := 0;
  v_local_amt numeric(12, 2) := 0;
  v_tenant_name text;
  v_vendor_foreign numeric(12, 2) := 0;
  v_cargo_foreign numeric(12, 2) := 0;
  v_vendor_rate numeric(12, 4) := 1;
  v_cargo_rate numeric(12, 4) := 1;
  v_weight_kg numeric(12, 3);
  v_vendor_paper jsonb;
  v_cargo_paper jsonb;
  v_local_paper jsonb;
  v_local_lines jsonb;
begin
  if p_shipment_id is null then
    raise exception 'shipment_id is required';
  end if;

  select * into v_ship from public.global_shipments where id = p_shipment_id;
  if v_ship.id is null then
    raise exception 'Shipment % not found', p_shipment_id;
  end if;

  v_parent := v_ship.parent_tenant_id;
  v_issued_by := coalesce(v_ship.assigned_child_tenant_id, v_parent);

  if not (
    coalesce(auth.role(), '') = 'service_role'
    or public.user_can_manage_parent_tenant(v_parent)
  ) then
    raise exception 'Permission denied';
  end if;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_vendor_amt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_bucket = 'material'::public.global_shipment_cost_bucket;

  if v_vendor_amt = 0 then
    v_vendor_amt := coalesce(round(v_ship.purchase_invoice_total, 2), 0);
  end if;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_cargo_amt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_bucket in (
      'freight'::public.global_shipment_cost_bucket,
      'customs'::public.global_shipment_cost_bucket
    );

  if v_cargo_amt = 0 then
    v_cargo_amt := coalesce(round(v_ship.cargo_invoice_total, 2), 0);
  end if;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_local_amt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.is_capitalizable = false;

  select coalesce(sum(round(e.amount, 2)), 0)
  into v_vendor_foreign
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_bucket = 'material'::public.global_shipment_cost_bucket;

  if v_vendor_foreign = 0 then
    v_vendor_foreign := coalesce(round(v_ship.purchase_invoice_total, 2), 0);
  end if;

  v_vendor_rate := case
    when v_vendor_foreign > 0 and v_vendor_amt > 0 then round(v_vendor_amt / v_vendor_foreign, 4)
    else 1
  end;

  v_vendor_paper := jsonb_build_object(
    'paper', 'vendor',
    'foreign_amount', v_vendor_foreign,
    'conversion_rate', v_vendor_rate,
    'bdt_amount', v_vendor_amt
  );

  select coalesce(sum(round(e.amount, 2)), 0)
  into v_cargo_foreign
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_bucket in (
      'freight'::public.global_shipment_cost_bucket,
      'customs'::public.global_shipment_cost_bucket
    );

  if v_cargo_foreign = 0 then
    v_cargo_foreign := coalesce(round(v_ship.cargo_invoice_total, 2), 0);
  end if;

  v_cargo_rate := case
    when v_cargo_foreign > 0 and v_cargo_amt > 0 then round(v_cargo_amt / v_cargo_foreign, 4)
    else 1
  end;

  v_weight_kg := coalesce(v_ship.total_weight_kg, v_ship.received_weight, 0);

  v_cargo_paper := jsonb_build_object(
    'paper', 'cargo',
    'weight_kg', v_weight_kg,
    'price', v_cargo_foreign,
    'conversion_rate', v_cargo_rate,
    'bdt_amount', v_cargo_amt
  );

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'description', coalesce(
            nullif(trim(e.description), ''),
            nullif(trim(e.metadata->>'description'), ''),
            initcap(replace(e.cost_bucket::text, '_', ' '))
          ),
          'amount', round(e.amount * coalesce(e.exchange_rate, 1), 2)
        )
        order by e.id
      )
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id
        and e.is_capitalizable = false
    ),
    '[]'::jsonb
  )
  into v_local_lines;

  v_local_paper := jsonb_build_object(
    'paper', 'local',
    'lines', coalesce(v_local_lines, '[]'::jsonb),
    'bdt_amount', v_local_amt
  );

  if v_ship.vendor_id is not null then
    select pr.id into v_vendor_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'vendor'::public.profile_party_type
      and pr.subject_id = v_ship.vendor_id;
  end if;

  if v_ship.cargo_company_id is not null then
    select pr.id into v_cargo_profile
    from public.profiles pr
    where pr.parent_tenant_id = v_parent
      and pr.profile_type = 'cargo'::public.profile_party_type
      and pr.subject_id = v_ship.cargo_company_id;
  end if;

  select t.name into v_tenant_name from public.tenants t where t.id = v_parent;

  v_local_profile := public.upsert_profile_for_party(
    v_parent,
    'company'::public.profile_party_type,
    v_parent,
    coalesce(v_tenant_name, 'Local opex'),
    null, null, '+880', null, false, null, true, null
  );

  if v_ship.status = 'cancelled' then
    update public.bills
    set invoice_status = 'voided'::public.global_invoice_status, updated_at = now()
    where parent_tenant_id = v_parent
      and ap_shipment_id = p_shipment_id
      and invoice_type = 'ap'::public.global_invoice_type
      and invoice_status = 'issued'::public.global_invoice_status
      and coalesce(paid_amount, 0) = 0;
    return jsonb_build_object('success', true, 'cancelled', true);
  end if;

  return jsonb_build_object(
    'success', true,
    'vendor_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'vendor', v_vendor_profile, v_vendor_amt, v_vendor_paper),
    'cargo_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'cargo', v_cargo_profile, v_cargo_amt, v_cargo_paper),
    'local_bill_id', public._upsert_shipment_ap_bill(v_parent, v_issued_by, p_shipment_id, v_ship.name, 'local', v_local_profile, v_local_amt, v_local_paper)
  );
end;
$$;
ALTER FUNCTION "public"."sync_shipment_ap_bills"("p_shipment_id" bigint) OWNER TO "postgres";

CREATE OR REPLACE FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_type" "public"."global_shipment_cost_type", "p_amount" numeric, "p_exchange_rate" numeric DEFAULT 1.0, "p_currency_id" bigint DEFAULT NULL::bigint, "p_payment_source" "text" DEFAULT NULL::"text", "p_entity_type" "text" DEFAULT NULL::"text", "p_entity_id" bigint DEFAULT NULL::bigint, "p_allocation" "text" DEFAULT NULL::"text", "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_section_id" bigint DEFAULT NULL::bigint, "p_id" bigint DEFAULT NULL::bigint) RETURNS "public"."global_shipment_cost_entries"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_row public.global_shipment_cost_entries%rowtype;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_amount is null or p_amount < 0 then
    raise exception 'amount must be >= 0';
  end if;

  if p_exchange_rate is null or p_exchange_rate <= 0 then
    raise exception 'exchange_rate must be > 0';
  end if;

  if p_id is not null then
    update public.global_shipment_cost_entries e
    set
      cost_type = p_cost_type,
      amount = p_amount,
      exchange_rate = p_exchange_rate,
      currency_id = p_currency_id,
      payment_source = p_payment_source,
      entity_type = p_entity_type,
      entity_id = p_entity_id,
      allocation = p_allocation,
      metadata = coalesce(p_metadata, '{}'::jsonb),
      section_id = p_section_id,
      updated_at = now()
    where e.id = p_id
      and e.shipment_id = p_shipment_id
    returning * into v_row;

    if not found then
      raise exception 'cost entry % not found on shipment %', p_id, p_shipment_id;
    end if;
  else
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_type,
      amount,
      currency_id,
      exchange_rate,
      payment_source,
      entity_type,
      entity_id,
      allocation,
      metadata,
      section_id
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      p_cost_type,
      p_amount,
      p_currency_id,
      p_exchange_rate,
      p_payment_source,
      p_entity_type,
      p_entity_id,
      p_allocation,
      coalesce(p_metadata, '{}'::jsonb),
      p_section_id
    )
    returning * into v_row;
  end if;

  if coalesce(v_row.is_capitalizable, p_cost_type is distinct from 'local'::public.global_shipment_cost_type)
     and exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  return v_row;
end;
$$;
ALTER FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_type" "public"."global_shipment_cost_type", "p_amount" numeric, "p_exchange_rate" numeric, "p_currency_id" bigint, "p_payment_source" "text", "p_entity_type" "text", "p_entity_id" bigint, "p_allocation" "text", "p_metadata" "jsonb", "p_section_id" bigint, "p_id" bigint) OWNER TO "postgres";

drop trigger if exists trg_global_shipment_cost_entry_axes on public.global_shipment_cost_entries;
create trigger trg_global_shipment_cost_entry_axes
  before insert or update on public.global_shipment_cost_entries
  for each row execute function public.trg_fn_global_shipment_cost_entry_axes();
