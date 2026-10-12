DROP FUNCTION IF EXISTS public.upsert_global_shipment_cost_entry(
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
);

CREATE OR REPLACE FUNCTION "public"."trg_fn_global_shipment_cost_entry_axes"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  if new.cost_bucket is null then
    raise exception 'cost_bucket is required';
  end if;

  if new.cost_component is null then
    raise exception 'cost_component is required';
  end if;

  if new.description is null and new.metadata ? 'description' then
    new.description := nullif(trim(new.metadata->>'description'), '');
  end if;

  return new;
end;
$$;

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
    cost_bucket,
    cost_component,
    is_capitalizable,
    amount,
    currency_id,
    metadata
  ) values (
    v_ship.parent_tenant_id,
    p_shipment_id,
    'material',
    'subtotal',
    true,
    greatest(v_goods, 0),
    v_ship.shipment_purchase_currency_id,
    jsonb_build_object('source', 'header_backfill')
  );

  if v_cargo_amt > 0 then
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      'freight',
      'subtotal',
      true,
      v_cargo_amt,
      v_ship.shipment_cost_currency_id,
      jsonb_build_object('source', 'header_backfill')
    );
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."pay_settle_shipment_costs"("p_shipment_id" bigint, "p_cost_entry_ids" bigint[] DEFAULT NULL::bigint[]) RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
begin
  raise exception 'pay_settle_shipment_costs is retired; use sync_shipment_ap_bills and post_ap_payout_with_allocations';
end;
$$;

CREATE OR REPLACE FUNCTION "public"."revise_global_shipment_costs"("p_shipment_id" bigint, "p_entries" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'public'
    AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_stamped integer;
  v_old_costs jsonb;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) then
    raise exception 'not allowed';
  end if;

  if not public.global_shipment_stock_is_posted(v_ship) then
    raise exception 'shipment not finalized; use upsert_global_shipment_cost_entry';
  end if;

  if public.global_shipment_costs_are_locked(v_ship) then
    raise exception 'shipment costs are locked';
  end if;

  if p_entries is null or jsonb_typeof(p_entries) <> 'array' or jsonb_array_length(p_entries) = 0 then
    raise exception 'p_entries must be a non-empty array';
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'cost_bucket', e.cost_bucket,
    'cost_component', e.cost_component,
    'amount', e.amount,
    'landed_snapshot', (
      select coalesce(jsonb_agg(jsonb_build_object(
        'item_id', i.id,
        'landed_cost_bdt', i.landed_cost_bdt
      )), '[]'::jsonb)
      from public.global_shipment_items i
      where i.shipment_id = p_shipment_id
    )
  )), '[]'::jsonb)
  into v_old_costs
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id;

  -- Replace all entries for this shipment with the provided set
  delete from public.global_shipment_cost_entries where shipment_id = p_shipment_id;

  for v_entry in select value from jsonb_array_elements(p_entries)
  loop
    insert into public.global_shipment_cost_entries (
      parent_tenant_id,
      shipment_id,
      cost_bucket,
      cost_component,
      is_capitalizable,
      amount,
      currency_id,
      metadata
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      (v_entry->>'cost_bucket')::public.global_shipment_cost_bucket,
      (v_entry->>'cost_component')::public.global_shipment_cost_component,
      coalesce((v_entry->>'is_capitalizable')::boolean, true),
      (v_entry->>'amount')::numeric,
      nullif(v_entry->>'currency_id', '')::bigint,
      coalesce(v_entry->'metadata', '{}'::jsonb)
    );
  end loop;

  -- Re-stamp only — no wallet delta, no invoice line rewrite
  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  return jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'prior_entries', v_old_costs,
    'wallet_posted', false
  );
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
  v_stamped integer := 0;
  v_cost_entries jsonb;
  v_items jsonb;
  v_cost_bucket public.global_shipment_cost_bucket;
  v_cost_component public.global_shipment_cost_component;
  v_is_capitalizable boolean;
  v_description text;
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
      v_id := nullif(v_entry->>'id', '')::bigint;

      if v_amount is null or v_amount < 0 then
        raise exception 'amount must be >= 0';
      end if;

      v_cost_bucket := nullif(v_entry->>'cost_bucket', '')::public.global_shipment_cost_bucket;
      v_cost_component := nullif(v_entry->>'cost_component', '')::public.global_shipment_cost_component;
      if v_cost_bucket is null or v_cost_component is null then
        raise exception 'cost_bucket and cost_component are required';
      end if;

      v_is_capitalizable := case
        when v_entry ? 'is_capitalizable' then (v_entry->>'is_capitalizable')::boolean
        else null
      end;
      v_description := nullif(trim(v_entry->>'description'), '');

      if v_id is not null then
        update public.global_shipment_cost_entries e
        set
          cost_bucket = v_cost_bucket,
          cost_component = v_cost_component,
          is_capitalizable = coalesce(v_is_capitalizable, e.is_capitalizable),
          description = coalesce(v_description, e.description),
          amount = v_amount,
          currency_id = nullif(v_entry->>'currency_id', '')::bigint,
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
          cost_bucket,
          cost_component,
          is_capitalizable,
          description,
          amount,
          currency_id,
          metadata,
          section_id
        ) values (
          v_ship.parent_tenant_id,
          p_shipment_id,
          v_cost_bucket,
          v_cost_component,
          coalesce(v_is_capitalizable, true),
          v_description,
          v_amount,
          nullif(v_entry->>'currency_id', '')::bigint,
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

CREATE OR REPLACE FUNCTION "public"."upsert_global_shipment_cost_entry"("p_shipment_id" bigint, "p_cost_bucket" "public"."global_shipment_cost_bucket", "p_cost_component" "public"."global_shipment_cost_component", "p_amount" numeric, "p_currency_id" bigint DEFAULT NULL::bigint, "p_metadata" "jsonb" DEFAULT '{}'::"jsonb", "p_section_id" bigint DEFAULT NULL::bigint, "p_id" bigint DEFAULT NULL::bigint, "p_description" "text" DEFAULT NULL::"text", "p_is_capitalizable" boolean DEFAULT true) RETURNS "public"."global_shipment_cost_entries"
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

  if p_id is not null then
    update public.global_shipment_cost_entries e
    set
      cost_bucket = p_cost_bucket,
      cost_component = p_cost_component,
      is_capitalizable = coalesce(p_is_capitalizable, e.is_capitalizable),
      description = coalesce(p_description, e.description),
      amount = p_amount,
      currency_id = p_currency_id,
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
      cost_bucket,
      cost_component,
      is_capitalizable,
      description,
      amount,
      currency_id,
      metadata,
      section_id
    ) values (
      v_ship.parent_tenant_id,
      p_shipment_id,
      p_cost_bucket,
      p_cost_component,
      coalesce(p_is_capitalizable, true),
      p_description,
      p_amount,
      p_currency_id,
      coalesce(p_metadata, '{}'::jsonb),
      p_section_id
    )
    returning * into v_row;
  end if;

  if coalesce(v_row.is_capitalizable, true)
     and exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id) then
    perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  return v_row;
end;
$$;

CREATE OR REPLACE FUNCTION "public"."_build_shipment_ap_bucket_paper"("p_shipment_id" bigint, "p_ship" "public"."global_shipments", "p_bucket" "public"."global_shipment_cost_bucket") RETURNS "jsonb"
    LANGUAGE "plpgsql" STABLE
    SET "search_path" TO 'public'
    AS $$
declare
  v_bdt numeric(12, 2) := 0;
  v_foreign numeric(12, 2) := 0;
  v_rate numeric(12, 4) := 1;
  v_lines jsonb;
  v_weight_kg numeric(12, 3);
begin
  select coalesce(sum(round(e.amount, 2)), 0)
  into v_bdt
  from public.global_shipment_cost_entries e
  where e.shipment_id = p_shipment_id
    and e.cost_bucket = p_bucket;

  v_foreign := v_bdt;

  if p_bucket = 'material'::public.global_shipment_cost_bucket then
    if v_bdt = 0 then
      v_bdt := coalesce(round(p_ship.purchase_invoice_total, 2), 0);
      v_foreign := v_bdt;
    end if;
    v_rate := case
      when v_foreign > 0 and v_bdt > 0 then round(v_bdt / v_foreign, 4)
      else 1
    end;
    return jsonb_build_object(
      'paper', 'material',
      'foreign_amount', v_foreign,
      'conversion_rate', v_rate,
      'bdt_amount', v_bdt
    );
  end if;

  if p_bucket = 'freight'::public.global_shipment_cost_bucket then
    if v_bdt = 0 then
      v_bdt := coalesce(round(p_ship.cargo_invoice_total, 2), 0);
      v_foreign := v_bdt;
    end if;
    v_rate := case
      when v_foreign > 0 and v_bdt > 0 then round(v_bdt / v_foreign, 4)
      else 1
    end;
    v_weight_kg := coalesce(p_ship.total_weight_kg, p_ship.received_weight, 0);
    return jsonb_build_object(
      'paper', 'freight',
      'weight_kg', v_weight_kg,
      'price', v_foreign,
      'conversion_rate', v_rate,
      'bdt_amount', v_bdt
    );
  end if;

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'description', coalesce(
            nullif(trim(e.description), ''),
            nullif(trim(e.metadata->>'description'), ''),
            initcap(replace(e.cost_component::text, '_', ' '))
          ),
          'amount', round(e.amount, 2)
        )
        order by e.id
      )
      from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id
        and e.cost_bucket = p_bucket
    ),
    '[]'::jsonb
  )
  into v_lines;

  return jsonb_build_object(
    'paper', p_bucket::text,
    'lines', coalesce(v_lines, '[]'::jsonb),
    'bdt_amount', v_bdt
  );
end;
$$;


alter table public.global_shipment_cost_entries
  drop constraint if exists global_shipment_cost_entries_exchange_rate_check,
  drop constraint if exists global_shipment_cost_entries_payment_source_check;

drop index if exists public.global_shipment_cost_entries_type_idx;
drop index if exists public.global_shipment_cost_entries_settled_idx;

alter table public.global_shipment_cost_entries
  drop column if exists cost_type,
  drop column if exists item_sku,
  drop column if exists exchange_rate,
  drop column if exists payment_source,
  drop column if exists entity_type,
  drop column if exists entity_id,
  drop column if exists allocation,
  drop column if exists settled_at,
  drop column if exists settlement_ledger_id;

create index if not exists global_shipment_cost_entries_bucket_idx
  on public.global_shipment_cost_entries (shipment_id, cost_bucket);
