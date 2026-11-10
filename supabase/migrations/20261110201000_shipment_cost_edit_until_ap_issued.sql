-- Cost rows stay editable until that bucket’s AP bill is issued (not blocked by costs_locked alone).

CREATE OR REPLACE FUNCTION public._shipment_cost_bucket_has_issued_ap(
  p_shipment_id bigint,
  p_bucket public.global_shipment_cost_bucket
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.bills b
    WHERE b.invoice_type = 'ap'::public.global_invoice_type
      AND b.document_kind = 'standard'::public.bill_document_kind
      AND b.invoice_status = 'issued'::public.global_invoice_status
      AND (
        b.ap_shipment_id = p_shipment_id
        OR (
          b.source_type = 'shipment_cost'
          AND nullif(trim(b.source_id), '')::bigint = p_shipment_id
        )
      )
      AND (
        b.ap_kind = p_bucket::text
        OR b.source_key = p_bucket::text
        OR b.source_key LIKE p_bucket::text || ':%'
      )
  );
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_cost_bucket_mutable(
  p_shipment_id bigint,
  p_bucket public.global_shipment_cost_bucket
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
begin
  if public._shipment_cost_bucket_has_issued_ap(p_shipment_id, p_bucket) then
    raise exception 'Cannot change % costs after the payable invoice is issued', p_bucket;
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public._assert_shipment_cost_entry_mutable(p_entry_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_entry public.global_shipment_cost_entries%rowtype;
  v_bill_id bigint;
  v_status public.global_invoice_status;
begin
  if p_entry_id is null then
    raise exception 'cost_entry_id is required';
  end if;

  select * into v_entry from public.global_shipment_cost_entries where id = p_entry_id;
  if not found then
    raise exception 'cost entry not found';
  end if;

  v_bill_id := nullif(v_entry.metadata->>'ap_bill_id', '')::bigint;
  if v_bill_id is null then
    return;
  end if;

  select b.invoice_status into v_status from public.bills b where b.id = v_bill_id;
  if found and v_status = 'issued'::public.global_invoice_status then
    raise exception 'This cost line is locked because its payable invoice is already issued';
  end if;
end;
$$;

CREATE OR REPLACE FUNCTION public.delete_global_shipment_cost_entry(p_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_entry public.global_shipment_cost_entries%ROWTYPE;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  SELECT * INTO v_entry FROM public.global_shipment_cost_entries WHERE id = p_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'cost entry not found';
  END IF;

  SELECT * INTO v_ship FROM public.global_shipments WHERE id = v_entry.shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  PERFORM public._assert_shipment_cost_entry_mutable(p_id);

  DELETE FROM public.global_shipment_cost_entries WHERE id = p_id;

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = v_entry.shipment_id)
     AND NOT public.global_shipment_costs_are_locked(v_ship) THEN
    PERFORM public.stamp_global_shipment_landed_costs(v_entry.shipment_id);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.save_global_shipment_cost_entries(
  p_shipment_id bigint,
  p_entries jsonb,
  p_delete_ids bigint[] DEFAULT '{}'::bigint[],
  p_received_weight numeric DEFAULT NULL::numeric,
  p_total_weight_kg numeric DEFAULT NULL::numeric
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_entry jsonb;
  v_row public.global_shipment_cost_entries%rowtype;
  v_del public.global_shipment_cost_entries%rowtype;
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

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
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
    for v_del in
      select * from public.global_shipment_cost_entries e
      where e.shipment_id = p_shipment_id
        and e.id = any(p_delete_ids)
    loop
      perform public._assert_shipment_cost_entry_mutable(v_del.id);
    end loop;

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
        select * into v_row
        from public.global_shipment_cost_entries e
        where e.id = v_id
          and e.shipment_id = p_shipment_id;

        if not found then
          raise exception 'cost entry % not found on shipment %', v_id, p_shipment_id;
        end if;

        perform public._assert_shipment_cost_entry_mutable(v_id);

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
          tenant_id,
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
          v_ship.tenant_id,
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

  if exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id)
     and not public.global_shipment_costs_are_locked(v_ship) then
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

CREATE OR REPLACE FUNCTION public.upsert_global_shipment_cost_entry(
  p_shipment_id bigint,
  p_cost_bucket public.global_shipment_cost_bucket,
  p_cost_component public.global_shipment_cost_component,
  p_amount numeric,
  p_currency_id bigint DEFAULT NULL::bigint,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_section_id bigint DEFAULT NULL::bigint,
  p_id bigint DEFAULT NULL::bigint,
  p_description text DEFAULT NULL::text,
  p_is_capitalizable boolean DEFAULT true
)
RETURNS public.global_shipment_cost_entries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
declare
  v_ship public.global_shipments%rowtype;
  v_row public.global_shipment_cost_entries%rowtype;
begin
  select * into v_ship from public.global_shipments where id = p_shipment_id for update;
  if not found then
    raise exception 'shipment not found';
  end if;

  if not public.user_can_manage_parent_tenant(v_ship.tenant_id) then
    raise exception 'not allowed';
  end if;

  if p_id is not null then
    perform public._assert_shipment_cost_entry_mutable(p_id);
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
      tenant_id,
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
      v_ship.tenant_id,
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
     and exists (select 1 from public.global_shipment_items where shipment_id = p_shipment_id)
     and not public.global_shipment_costs_are_locked(v_ship) then
    perform public.stamp_global_shipment_landed_costs(p_shipment_id);
  end if;

  return v_row;
end;
$$;
