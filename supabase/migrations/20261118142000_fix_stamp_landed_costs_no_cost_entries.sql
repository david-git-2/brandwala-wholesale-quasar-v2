-- stamp_global_shipment_landed_costs must not call ensure_global_shipment_cost_entries_from_header (dropped in Option A P3/P4).

CREATE OR REPLACE FUNCTION public.stamp_global_shipment_landed_costs(p_shipment_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public, money_kernel, pg_temp
AS $$
DECLARE
  v_ship public.global_shipments%rowtype;
  v_fx jsonb;
  v_material_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_customs_bdt numeric := 0;
  v_handling_bdt numeric := 0;
  v_finance_bdt numeric := 0;
  v_other_bdt numeric := 0;
  v_prod_rate numeric := 1;
  v_freight_per_kg numeric := 0;
  v_kg_basis numeric := 0;
  v_pack_kg numeric := 0;
  v_total_line_goods numeric := 0;
  v_surplus numeric := 0;
  v_total_goods_bdt numeric := 0;
  v_total_cif numeric := 0;
  v_total_qty numeric := 0;
  v_freight_assigned numeric := 0;
  v_freight_remainder numeric := 0;
  v_zero_weight_qty numeric := 0;
  v_updated integer := 0;
  r record;
  v_unit_kg numeric;
  v_goods_per_unit numeric;
  v_line_goods numeric;
  v_surplus_per_unit numeric;
  v_freight_per_unit numeric;
  v_line_freight numeric;
  v_unit_cif numeric;
  v_landed numeric;
  v_customs_unit numeric;
  v_handling_unit numeric;
  v_other_unit numeric;
  v_finance_unit numeric;
  v_goods_incl_surplus numeric;
BEGIN
  SELECT * INTO v_ship FROM public.global_shipments WHERE id = p_shipment_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'shipment not found';
  END IF;

  v_fx := public._global_shipment_landed_fx_inputs(p_shipment_id);
  v_prod_rate := coalesce((v_fx ->> 'product_conversion_rate')::numeric, 1);
  v_freight_per_kg := coalesce((v_fx ->> 'freight_bdt_per_kg')::numeric, 0);
  v_kg_basis := coalesce((v_fx ->> 'kg_basis')::numeric, 0);
  v_material_bdt := coalesce((v_fx #>> '{material,bdt_paid}')::numeric, 0);
  v_freight_bdt := coalesce((v_fx ->> 'freight_bdt')::numeric, 0);
  v_customs_bdt := coalesce((v_fx #>> '{customs,bdt_paid}')::numeric, 0);
  v_handling_bdt := coalesce((v_fx #>> '{handling,bdt_paid}')::numeric, 0);
  v_finance_bdt := coalesce((v_fx #>> '{finance,bdt_paid}')::numeric, 0);
  v_other_bdt := coalesce((v_fx #>> '{other,bdt_paid}')::numeric, 0);

  SELECT coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
    INTO v_pack_kg
    FROM public.global_shipment_items gsi
   WHERE gsi.shipment_id = p_shipment_id;

  IF v_kg_basis <= 0 THEN
    v_kg_basis := v_pack_kg;
  END IF;

  IF v_kg_basis > 0 AND v_freight_per_kg <= 0 AND v_freight_bdt > 0 THEN
    v_freight_per_kg := v_freight_bdt / v_kg_basis;
  END IF;

  SELECT coalesce(sum(gsi.ordered_quantity), 0)
    INTO v_total_qty
    FROM public.global_shipment_items gsi
   WHERE gsi.shipment_id = p_shipment_id;

  CREATE TEMP TABLE _landed_wip ON COMMIT DROP AS
  SELECT
    gsi.id,
    gsi.purchase_price,
    gsi.ordered_quantity,
    gsi.product_weight,
    gsi.package_weight,
    0::numeric AS goods_per_unit,
    0::numeric AS line_goods_bdt,
    0::numeric AS surplus_per_unit,
    0::numeric AS freight_per_unit,
    0::numeric AS unit_cif,
    0::numeric AS landed
  FROM public.global_shipment_items gsi
  WHERE gsi.shipment_id = p_shipment_id;

  IF v_ship.type::text IN ('local', 'domestic') THEN
    PERFORM set_config('app.allow_landed_cost_stamp', '1', true);
    FOR r IN SELECT * FROM _landed_wip LOOP
      v_unit_kg := (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) / 1000.0;
      v_line_freight := 0;
      IF v_pack_kg > 0 OR v_kg_basis > 0 THEN
        v_line_freight := CASE
          WHEN coalesce(v_kg_basis, 0) > 0 AND v_unit_kg > 0
            THEN (v_unit_kg * r.ordered_quantity / v_kg_basis) * v_freight_bdt
          ELSE 0
        END;
      END IF;
      v_landed := coalesce(r.purchase_price, 0)
        + CASE WHEN r.ordered_quantity > 0 THEN v_line_freight / r.ordered_quantity ELSE 0 END;
      UPDATE public.global_shipment_items
      SET landed_cost_bdt = round(v_landed::numeric, 4)
      WHERE id = r.id;
      v_updated := v_updated + 1;
    END LOOP;
    PERFORM public._stamp_global_shipment_outcome_costs(p_shipment_id);
    RETURN v_updated;
  END IF;

  FOR r IN SELECT * FROM _landed_wip LOOP
    v_goods_per_unit := coalesce(r.purchase_price, 0) * v_prod_rate;
    v_line_goods := v_goods_per_unit * coalesce(r.ordered_quantity, 0);
    v_total_line_goods := v_total_line_goods + v_line_goods;
    UPDATE _landed_wip
    SET goods_per_unit = v_goods_per_unit,
        line_goods_bdt = v_line_goods
    WHERE id = r.id;
  END LOOP;

  v_surplus := greatest(0, v_material_bdt - v_total_line_goods);

  FOR r IN SELECT * FROM _landed_wip LOOP
    v_surplus_per_unit := 0;
    IF v_total_line_goods > 0 AND v_surplus > 0 AND r.ordered_quantity > 0 THEN
      v_surplus_per_unit := (r.line_goods_bdt / v_total_line_goods) * v_surplus / r.ordered_quantity;
    END IF;
    UPDATE _landed_wip SET surplus_per_unit = v_surplus_per_unit WHERE id = r.id;
  END LOOP;

  FOR r IN SELECT * FROM _landed_wip LOOP
    v_unit_kg := (coalesce(r.product_weight, 0) + coalesce(r.package_weight, 0)) / 1000.0;
    v_freight_per_unit := 0;
    IF v_unit_kg > 0 AND r.ordered_quantity > 0 THEN
      v_line_freight := round(v_unit_kg * v_freight_per_kg * r.ordered_quantity, 2);
      v_freight_assigned := v_freight_assigned + v_line_freight;
      v_freight_per_unit := v_line_freight / r.ordered_quantity;
    ELSIF v_unit_kg <= 0 THEN
      v_zero_weight_qty := v_zero_weight_qty + coalesce(r.ordered_quantity, 0);
    END IF;
    UPDATE _landed_wip SET freight_per_unit = v_freight_per_unit WHERE id = r.id;
  END LOOP;

  v_freight_remainder := greatest(0, v_freight_bdt - v_freight_assigned);
  IF v_freight_remainder > 0 AND v_zero_weight_qty > 0 THEN
    FOR r IN SELECT * FROM _landed_wip
      WHERE (coalesce(product_weight, 0) + coalesce(package_weight, 0)) <= 0
        AND ordered_quantity > 0
    LOOP
      v_freight_per_unit := coalesce(r.freight_per_unit, 0)
        + (r.ordered_quantity / v_zero_weight_qty) * v_freight_remainder / r.ordered_quantity;
      UPDATE _landed_wip SET freight_per_unit = v_freight_per_unit WHERE id = r.id;
    END LOOP;
  END IF;

  FOR r IN SELECT * FROM _landed_wip LOOP
    v_goods_incl_surplus := r.goods_per_unit + r.surplus_per_unit;
    v_unit_cif := v_goods_incl_surplus + r.freight_per_unit;
    v_total_goods_bdt := v_total_goods_bdt + v_goods_incl_surplus * r.ordered_quantity;
    v_total_cif := v_total_cif + v_unit_cif * r.ordered_quantity;
    UPDATE _landed_wip SET unit_cif = v_unit_cif WHERE id = r.id;
  END LOOP;

  PERFORM set_config('app.allow_landed_cost_stamp', '1', true);

  FOR r IN SELECT * FROM _landed_wip LOOP
    v_goods_incl_surplus := r.goods_per_unit + r.surplus_per_unit;
    v_customs_unit := CASE
      WHEN v_total_cif > 0 THEN round((r.unit_cif / v_total_cif) * v_customs_bdt, 4)
      ELSE 0
    END;
    v_handling_unit := CASE WHEN v_total_qty > 0 THEN round(v_handling_bdt / v_total_qty, 4) ELSE 0 END;
    v_other_unit := CASE WHEN v_total_qty > 0 THEN round(v_other_bdt / v_total_qty, 4) ELSE 0 END;
    v_finance_unit := CASE
      WHEN v_total_goods_bdt > 0 AND r.ordered_quantity > 0 THEN
        round(((v_goods_incl_surplus * r.ordered_quantity) / v_total_goods_bdt) * v_finance_bdt / r.ordered_quantity, 4)
      ELSE 0
    END;
    v_landed := v_goods_incl_surplus + r.freight_per_unit + v_customs_unit + v_handling_unit + v_finance_unit + v_other_unit;

    UPDATE public.global_shipment_items
    SET landed_cost_bdt = round(v_landed::numeric, 4)
    WHERE id = r.id;
    v_updated := v_updated + 1;
  END LOOP;

  PERFORM public._stamp_global_shipment_outcome_costs(p_shipment_id);

  RETURN v_updated;
END;
$$;