-- Merge global_shipment_local_costs into global_shipment_cost_entries (cost_type = local).
-- Requires 20271010155000_add_local_shipment_cost_type.sql (enum label committed first).

insert into public.global_shipment_cost_entries (
  parent_tenant_id,
  shipment_id,
  cost_type,
  amount,
  currency_id,
  exchange_rate,
  metadata,
  section_id,
  created_at,
  updated_at
)
select
  lc.parent_tenant_id,
  lc.shipment_id,
  'local'::public.global_shipment_cost_type,
  lc.amount,
  lc.currency_id,
  1.0,
  jsonb_build_object(
    'description', lc.description,
    'legacy_local_cost_id', lc.id
  ),
  lc.section_id,
  lc.created_at,
  lc.updated_at
from public.global_shipment_local_costs lc
where not exists (
  select 1
  from public.global_shipment_cost_entries e
  where e.shipment_id = lc.shipment_id
    and e.cost_type = 'local'::public.global_shipment_cost_type
    and e.metadata->>'legacy_local_cost_id' = lc.id::text
);

drop function if exists public.upsert_global_shipment_cost_entry(
  bigint,
  public.global_shipment_cost_type,
  numeric,
  numeric,
  bigint,
  text,
  text,
  bigint,
  text,
  jsonb,
  bigint
);

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
    coalesce(sum(amount) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type = 'product'), 0),
    coalesce(sum(amount) filter (where cost_type in ('cargo', 'duty')), 0),
    coalesce(sum(amount * exchange_rate) filter (where cost_type in ('cargo', 'duty')), 0)
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

      if v_id is not null then
        update public.global_shipment_cost_entries e
        set
          cost_type = (v_entry->>'cost_type')::public.global_shipment_cost_type,
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
          (v_entry->>'cost_type')::public.global_shipment_cost_type,
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

  if p_cost_type is distinct from 'local'::public.global_shipment_cost_type
     and exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  return v_row;
end;
$$;

ALTER FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_type" "public"."global_shipment_cost_type", "p_amount" numeric, "p_exchange_rate" numeric, "p_currency_id" bigint, "p_payment_source" "text", "p_entity_type" "text", "p_entity_id" bigint, "p_allocation" "text", "p_metadata" "jsonb", "p_section_id" bigint, "p_id" bigint) OWNER TO "postgres";

grant execute on function public.upsert_global_shipment_cost_entry(
  bigint,
  public.global_shipment_cost_type,
  numeric,
  numeric,
  bigint,
  text,
  text,
  bigint,
  text,
  jsonb,
  bigint,
  bigint
) to authenticated;

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
    and e.cost_type = 'product'::public.global_shipment_cost_type;

  if v_vendor_amt = 0 then
    v_vendor_amt := coalesce(round(v_ship.purchase_invoice_total, 2), 0);
  end if;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_cargo_amt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type in ('cargo'::public.global_shipment_cost_type, 'duty'::public.global_shipment_cost_type);

  if v_cargo_amt = 0 then
    v_cargo_amt := coalesce(round(v_ship.cargo_invoice_total, 2), 0);
  end if;

  select coalesce(sum(round(e.amount * coalesce(e.exchange_rate, 1), 2)), 0)
  into v_local_amt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type in (
      'local'::public.global_shipment_cost_type,
      'insurance'::public.global_shipment_cost_type,
      'labor'::public.global_shipment_cost_type,
      'washing'::public.global_shipment_cost_type,
      'transport'::public.global_shipment_cost_type,
      'handling'::public.global_shipment_cost_type
    );

  select coalesce(sum(round(e.amount, 2)), 0)
  into v_vendor_foreign
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_type = 'product'::public.global_shipment_cost_type;

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
    and e.cost_type in ('cargo'::public.global_shipment_cost_type, 'duty'::public.global_shipment_cost_type);

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
            nullif(trim(e.metadata->>'description'), ''),
            initcap(replace(e.cost_type::text, '_', ' '))
          ),
          'amount', round(e.amount * coalesce(e.exchange_rate, 1), 2)
        )
        order by e.id
      )
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id
        and e.cost_type in (
          'local'::public.global_shipment_cost_type,
          'insurance'::public.global_shipment_cost_type,
          'labor'::public.global_shipment_cost_type,
          'washing'::public.global_shipment_cost_type,
          'transport'::public.global_shipment_cost_type,
          'handling'::public.global_shipment_cost_type
        )
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

drop table if exists public.global_shipment_local_costs cascade;
