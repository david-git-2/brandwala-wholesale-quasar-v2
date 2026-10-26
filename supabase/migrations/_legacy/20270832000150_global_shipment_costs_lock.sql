-- Split shipment logistics (received/stock_ready) from books freeze (costs_locked).

ALTER TABLE public.global_shipments
  ADD COLUMN IF NOT EXISTS costs_locked boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS costs_locked_at timestamptz NULL,
  ADD COLUMN IF NOT EXISTS costs_locked_by uuid NULL REFERENCES auth.users(id) ON DELETE SET NULL;

COMMENT ON COLUMN public.global_shipments.costs_locked IS 'When true, cost entries and cost-affecting line edits are frozen.';
COMMENT ON COLUMN public.global_shipments.costs_locked_at IS 'Timestamp when shipment costs were locked for books.';
COMMENT ON COLUMN public.global_shipments.costs_locked_by IS 'User who locked shipment costs.';

CREATE OR REPLACE FUNCTION public.global_shipment_stock_is_posted(p_ship public.global_shipments)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT coalesce(p_ship.stock_ready, false) OR p_ship.status = 'received';
$$;

CREATE OR REPLACE FUNCTION public.global_shipment_costs_are_locked(p_ship public.global_shipments)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT coalesce(p_ship.costs_locked, false);
$$;

CREATE OR REPLACE FUNCTION public.lock_global_shipment_costs(p_shipment_id bigint)
RETURNS public.global_shipments
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
BEGIN
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

  IF NOT public.global_shipment_stock_is_posted(v_ship) THEN
    RAISE EXCEPTION 'shipment stock is not posted; receive before locking costs';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are already locked';
  END IF;

  PERFORM set_config('app.allow_costs_lock', '1', true);

  UPDATE public.global_shipments
  SET costs_locked = true,
      costs_locked_at = now(),
      costs_locked_by = auth.uid(),
      updated_at = now()
  WHERE id = p_shipment_id
  RETURNING * INTO v_ship;

  RETURN v_ship;
END;
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

  IF NOT public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  DELETE FROM public.global_shipment_cost_entries WHERE id = p_id;

  IF public.global_shipment_stock_is_posted(v_ship) THEN
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

  IF public.global_shipment_stock_is_posted(v_ship) THEN
    PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);
  END IF;

  RETURN QUERY
  SELECT *
  FROM public.global_shipment_items
  WHERE shipment_id = p_shipment_id
  ORDER BY sort_order ASC, id ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.revise_global_shipment_costs(p_shipment_id bigint, p_entries jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
DECLARE
  v_ship public.global_shipments%ROWTYPE;
  v_entry jsonb;
  v_stamped integer;
  v_old_costs jsonb;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  IF NOT public.user_can_manage_parent_tenant(v_ship.parent_tenant_id) THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF NOT public.global_shipment_stock_is_posted(v_ship) THEN
    RAISE EXCEPTION 'shipment not finalized; use upsert_global_shipment_cost_entry';
  END IF;

  IF public.global_shipment_costs_are_locked(v_ship) THEN
    RAISE EXCEPTION 'shipment costs are locked';
  END IF;

  IF p_entries IS NULL OR jsonb_typeof(p_entries) <> 'array' OR jsonb_array_length(p_entries) = 0 THEN
    RAISE EXCEPTION 'p_entries must be a non-empty array';
  END IF;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', e.id,
    'cost_type', e.cost_type,
    'amount', e.amount,
    'exchange_rate', e.exchange_rate,
    'landed_snapshot', (
      SELECT coalesce(jsonb_agg(jsonb_build_object(
        'item_id', i.id,
        'landed_cost_bdt', i.landed_cost_bdt
      )), '[]'::jsonb)
      FROM public.global_shipment_items i
      WHERE i.shipment_id = p_shipment_id
    )
  )), '[]'::jsonb)
  INTO v_old_costs
  FROM public.global_shipment_cost_entries e
  WHERE e.shipment_id = p_shipment_id;

  DELETE FROM public.global_shipment_cost_entries WHERE shipment_id = p_shipment_id;

  FOR v_entry IN SELECT value FROM jsonb_array_elements(p_entries)
  LOOP
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
      (v_entry->>'cost_type')::public.global_shipment_cost_type,
      (v_entry->>'amount')::numeric,
      nullif(v_entry->>'currency_id', '')::bigint,
      coalesce(nullif(v_entry->>'exchange_rate', '')::numeric, 1.0),
      nullif(v_entry->>'payment_source', ''),
      nullif(v_entry->>'entity_type', ''),
      nullif(v_entry->>'entity_id', '')::bigint,
      nullif(v_entry->>'allocation', ''),
      coalesce(v_entry->'metadata', '{}'::jsonb)
    );
  END LOOP;

  v_stamped := public.stamp_global_shipment_landed_costs(p_shipment_id);

  RETURN jsonb_build_object(
    'shipment_id', p_shipment_id,
    'items_stamped', v_stamped,
    'prior_entries', v_old_costs,
    'wallet_posted', false
  );
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

  IF public.global_shipment_stock_is_posted(v_ship) THEN
    PERFORM public.stamp_global_shipment_landed_costs(p_shipment_id);
  END IF;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public._guard_global_shipment_costs_locked()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF tg_op = 'UPDATE' THEN
    IF NEW.costs_locked IS DISTINCT FROM OLD.costs_locked
       AND current_setting('app.allow_costs_lock', true) IS DISTINCT FROM '1' THEN
      RAISE EXCEPTION 'use lock_global_shipment_costs to lock shipment costs';
    END IF;

    IF OLD.costs_locked THEN
      IF NEW.received_weight IS DISTINCT FROM OLD.received_weight
         OR NEW.total_weight_kg IS DISTINCT FROM OLD.total_weight_kg THEN
        RAISE EXCEPTION 'shipment costs are locked';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public._restamp_global_shipment_on_weight_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF tg_op = 'UPDATE'
     AND NOT public.global_shipment_costs_are_locked(NEW)
     AND public.global_shipment_stock_is_posted(NEW)
     AND (
       NEW.received_weight IS DISTINCT FROM OLD.received_weight
       OR NEW.total_weight_kg IS DISTINCT FROM OLD.total_weight_kg
     ) THEN
    PERFORM public.stamp_global_shipment_landed_costs(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_global_shipments_guard_costs_locked ON public.global_shipments;
CREATE TRIGGER trg_global_shipments_guard_costs_locked
  BEFORE UPDATE ON public.global_shipments
  FOR EACH ROW
  EXECUTE FUNCTION public._guard_global_shipment_costs_locked();

DROP TRIGGER IF EXISTS trg_global_shipments_restamp_weight ON public.global_shipments;
CREATE TRIGGER trg_global_shipments_restamp_weight
  AFTER UPDATE ON public.global_shipments
  FOR EACH ROW
  EXECUTE FUNCTION public._restamp_global_shipment_on_weight_change();

REVOKE ALL ON FUNCTION public.lock_global_shipment_costs(bigint) FROM PUBLIC;
GRANT ALL ON FUNCTION public.lock_global_shipment_costs(bigint) TO authenticated;
