-- Re-stamp landed costs whenever cost entries or line cost fields change (not only after receive).

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

  IF NOT public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  DELETE FROM public.global_shipment_cost_entries WHERE id = p_id;

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = v_entry.shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(v_entry.shipment_id);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.bulk_update_global_shipment_items(p_shipment_id bigint, p_updates jsonb)
RETURNS SETOF public.global_shipment_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_update jsonb;
  v_id bigint;
  v_ship public.global_shipments%ROWTYPE;
BEGIN
  IF p_shipment_id IS NULL THEN
    RAISE EXCEPTION 'shipment_id is required';
  END IF;

  SELECT * INTO v_ship
  FROM public.global_shipments
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  FOR v_update IN SELECT * FROM jsonb_array_elements(p_updates)
  LOOP
    v_id := (v_update->>'id')::bigint;
    IF v_id IS NOT NULL THEN
      UPDATE public.global_shipment_items
      SET
        section_id = CASE
          WHEN v_update ? 'section_id' THEN nullif((v_update->>'section_id'), '')::bigint
          ELSE section_id
        END,
        vendor_id = CASE
          WHEN v_update ? 'vendor_id' THEN nullif((v_update->>'vendor_id'), '')::bigint
          ELSE vendor_id
        END,
        ordered_quantity = CASE
          WHEN v_update ? 'ordered_quantity' AND (v_update->>'ordered_quantity') IS NOT NULL THEN greatest(1, (v_update->>'ordered_quantity')::integer)
          ELSE ordered_quantity
        END,
        purchase_price = CASE
          WHEN v_update ? 'purchase_price' AND (v_update->>'purchase_price') IS NOT NULL THEN greatest(0, (v_update->>'purchase_price')::numeric)
          ELSE purchase_price
        END,
        product_weight = CASE
          WHEN v_update ? 'product_weight' AND (v_update->>'product_weight') IS NOT NULL THEN greatest(0, (v_update->>'product_weight')::numeric)
          ELSE product_weight
        END,
        package_weight = CASE
          WHEN v_update ? 'package_weight' AND (v_update->>'package_weight') IS NOT NULL THEN greatest(0, (v_update->>'package_weight')::numeric)
          ELSE package_weight
        END,
        barcode = CASE
          WHEN v_update ? 'barcode' THEN v_update->>'barcode'
          ELSE barcode
        END,
        product_code = CASE
          WHEN v_update ? 'product_code' THEN v_update->>'product_code'
          ELSE product_code
        END,
        name = CASE
          WHEN v_update ? 'name' AND (v_update->>'name') IS NOT NULL THEN v_update->>'name'
          ELSE name
        END,
        updated_at = now()
      WHERE id = v_id AND shipment_id = p_shipment_id;
    END IF;
  END LOOP;

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = p_shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.global_shipment_items
  WHERE shipment_id = p_shipment_id
  ORDER BY sort_order ASC, id ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.upsert_global_shipment_cost_entry(
  p_shipment_id bigint,
  p_cost_type public.global_shipment_cost_type,
  p_amount numeric,
  p_exchange_rate numeric DEFAULT 1.0,
  p_currency_id bigint DEFAULT NULL,
  p_payment_source text DEFAULT NULL,
  p_entity_type text DEFAULT NULL,
  p_entity_id bigint DEFAULT NULL,
  p_allocation text DEFAULT NULL,
  p_metadata jsonb DEFAULT '{}'::jsonb,
  p_id bigint DEFAULT NULL
)
RETURNS public.global_shipment_cost_entries
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_row public.global_shipment_cost_entries%ROWTYPE;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  IF p_amount IS NULL OR p_amount < 0 THEN
    RAISE EXCEPTION 'amount must be >= 0';
  END IF;

  IF p_exchange_rate IS NULL OR p_exchange_rate <= 0 THEN
    RAISE EXCEPTION 'exchange_rate must be > 0';
  END IF;

  IF p_id IS NOT NULL THEN
    UPDATE public.global_shipment_cost_entries e
    SET
      cost_type = p_cost_type,
      amount = p_amount,
      exchange_rate = p_exchange_rate,
      currency_id = p_currency_id,
      payment_source = p_payment_source,
      entity_type = p_entity_type,
      entity_id = p_entity_id,
      allocation = p_allocation,
      metadata = coalesce(p_metadata, '{}'::jsonb),
      updated_at = now()
    WHERE e.id = p_id
      AND e.shipment_id = p_shipment_id
    RETURNING * INTO v_row;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'cost entry % not found on shipment %', p_id, p_shipment_id;
    END IF;
  ELSE
    INSERT INTO public.global_shipment_cost_entries (
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
      metadata
    ) VALUES (
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
      coalesce(p_metadata, '{}'::jsonb)
    )
    RETURNING * INTO v_row;
  END IF;

  IF EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = p_shipment_id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public._restamp_global_shipment_on_weight_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF tg_op = 'UPDATE'
     AND NOT public.global_shipment_costs_are_locked(NEW)
     AND (
       NEW.received_weight IS DISTINCT FROM OLD.received_weight
       OR NEW.total_weight_kg IS DISTINCT FROM OLD.total_weight_kg
     )
     AND EXISTS (SELECT 1 FROM public.global_shipment_items WHERE shipment_id = NEW.id) THEN
    PERFORM public.stamp_global_shipment_landed_costs(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;
