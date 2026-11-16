-- BDT pool landed cost: FX kernel + stamp
-- Landed FX: capitalizable totals from kernel shipment AP bill lines (Option A).

CREATE OR REPLACE FUNCTION public.shipment_ap_bucket_paid_totals(
  p_shipment_id bigint,
  p_ap_kind text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_bdt numeric := 0;
  v_foreign numeric := 0;
  v_count integer := 0;
  v_rate numeric := 1;
  v_bdt_kernel numeric := 0;
  v_foreign_kernel numeric := 0;
  v_count_kernel integer := 0;
  v_bdt_legacy numeric := 0;
  v_foreign_legacy numeric := 0;
  v_count_legacy integer := 0;
  v_kind text := lower(btrim(coalesce(p_ap_kind, '')));
BEGIN
  IF p_shipment_id IS NULL OR v_kind = '' THEN
    RETURN jsonb_build_object(
      'bdt_paid', 0,
      'foreign_paid', 0,
      'conversion_rate', 1,
      'payment_count', 0
    );
  END IF;

  SELECT
    coalesce(
      sum(
        round(
          coalesce(
            bs.allocated_books_amount,
            bs.allocated_amount
              * coalesce(nullif(p.books_rate, 0), nullif(p.exchange_rate, 0), 1)
          ),
          2
        )
      ),
      0
    ),
    coalesce(
      sum(round(bs.allocated_amount, 2)) filter (
        where upper(coalesce(b.currency_code, 'BDT')) <> 'BDT'
      ),
      0
    ),
    count(DISTINCT p.id)::integer
  INTO v_bdt_kernel, v_foreign_kernel, v_count_kernel
  FROM money_kernel.bills b
  INNER JOIN money_kernel.bill_settlements bs
    ON bs.tenant_id = b.tenant_id
   AND bs.bill_id = b.id
   AND bs.settlement_kind = 'pay'
  INNER JOIN money_kernel.pays p
    ON p.tenant_id = b.tenant_id
   AND p.id = bs.pays_id
  WHERE b.kind = 'shipment_cost_ap'
    AND b.source_type = 'shipment_cost'
    AND b.source_id = p_shipment_id::text
    AND b.status <> 'voided'
    AND coalesce(
      nullif(btrim(b.meta->>'ap_kind'), ''),
      split_part(coalesce(b.source_key, ''), ':', 1)
    ) = v_kind
    AND p.voided_at IS NULL
    AND p.status <> 'voided';

  SELECT
    coalesce(sum(round(pa.amount, 2)), 0),
    coalesce(
      sum(
        round(
          case
            when coalesce(p.exchange_rate, 0) > 0
                 and upper(coalesce(p.settlement_currency_code, 'BDT')) <> 'BDT' then
              pa.amount / p.exchange_rate
            else pa.amount
          end,
          2
        )
      ),
      0
    ),
    count(distinct p.id)::integer
  INTO v_bdt_legacy, v_foreign_legacy, v_count_legacy
  FROM public.bills b
  INNER JOIN public.pay_allocations pa ON pa.global_invoice_id = b.id
  INNER JOIN public.pays p ON p.id = pa.payment_id
  WHERE b.ap_shipment_id = p_shipment_id
    AND b.invoice_type = 'ap'::public.global_invoice_type
    AND b.document_kind = 'standard'::public.bill_document_kind
    AND b.ap_kind = v_kind
    AND p.voided_at IS null;

  v_bdt := v_bdt_kernel + v_bdt_legacy;
  v_foreign := v_foreign_kernel + v_foreign_legacy;
  v_count := v_count_kernel + v_count_legacy;

  IF v_foreign > 0 THEN
    v_rate := round(v_bdt / v_foreign, 6);
  END IF;

  RETURN jsonb_build_object(
    'bdt_paid', v_bdt,
    'foreign_paid', v_foreign,
    'conversion_rate', v_rate,
    'payment_count', v_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public._global_shipment_landed_fx_inputs(p_shipment_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_mat jsonb;
  v_fre jsonb;
  v_customs jsonb;
  v_handling jsonb;
  v_finance jsonb;
  v_other jsonb;
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_product_foreign numeric := 0;
  v_cargo_foreign numeric := 0;
  v_goods_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_blended numeric := 1;
  v_kg numeric := 0;
  v_pack_kg numeric := 0;
  v_kg_basis numeric := 0;
  v_cargo_per_kg numeric := 0;
  v_freight_bdt_per_kg numeric := 0;
  v_mat_count integer := 0;
  v_fre_count integer := 0;
  v_entry_material numeric := 0;
  v_entry_freight numeric := 0;
BEGIN
  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');
  v_customs := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'customs');
  v_handling := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'handling');
  v_finance := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'finance');
  v_other := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'other');

  v_mat_count := coalesce((v_mat ->> 'payment_count')::integer, 0);
  v_fre_count := coalesce((v_fre ->> 'payment_count')::integer, 0);

  IF v_mat_count > 0 THEN
    v_prod_rate := coalesce((v_mat ->> 'conversion_rate')::numeric, 1);
  END IF;
  IF v_fre_count > 0 THEN
    v_cargo_fx := coalesce((v_fre ->> 'conversion_rate')::numeric, 1);
  END IF;

  v_entry_material := public._shipment_kernel_capitalizable_bucket_total(p_shipment_id, 'material');
  v_entry_freight := public._shipment_kernel_capitalizable_bucket_total(p_shipment_id, 'freight');

  IF v_entry_material <= 0 AND to_regclass('public.global_shipment_cost_entries') IS NOT NULL THEN
    SELECT coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'material'), 0)
      INTO v_entry_material
      FROM public.global_shipment_cost_entries gce
     WHERE gce.shipment_id = p_shipment_id;
  END IF;

  IF v_entry_freight <= 0 AND to_regclass('public.global_shipment_cost_entries') IS NOT NULL THEN
    SELECT coalesce(sum(gce.amount) filter (where gce.is_capitalizable and gce.cost_bucket = 'freight'), 0)
      INTO v_entry_freight
      FROM public.global_shipment_cost_entries gce
     WHERE gce.shipment_id = p_shipment_id;
  END IF;

  v_product_foreign := coalesce((v_mat ->> 'foreign_paid')::numeric, 0);
  IF v_product_foreign <= 0 THEN
    v_product_foreign := v_entry_material;
  END IF;

  v_cargo_foreign := coalesce((v_fre ->> 'foreign_paid')::numeric, 0);
  IF v_cargo_foreign <= 0 THEN
    v_cargo_foreign := v_entry_freight;
  END IF;

  v_goods_bdt := coalesce((v_mat ->> 'bdt_paid')::numeric, round(v_product_foreign * v_prod_rate, 2));
  v_freight_bdt := coalesce((v_fre ->> 'bdt_paid')::numeric, 0);

  IF (v_product_foreign + v_cargo_foreign) > 0 THEN
    v_blended := round((v_goods_bdt + v_freight_bdt) / (v_product_foreign + v_cargo_foreign), 6);
  ELSE
    v_blended := 1;
  END IF;

  SELECT coalesce(sum(
    ((coalesce(gsi.product_weight, 0) + coalesce(gsi.package_weight, 0)) * gsi.ordered_quantity) / 1000.0
  ), 0)
    INTO v_pack_kg
    FROM public.global_shipment_items gsi
   WHERE gsi.shipment_id = p_shipment_id;

  SELECT coalesce(gs.total_weight_kg, gs.received_weight, 0)
    INTO v_kg
    FROM public.global_shipments gs
   WHERE gs.id = p_shipment_id;

  v_kg_basis := CASE WHEN v_pack_kg > 0 THEN v_pack_kg ELSE coalesce(v_kg, 0) END;

  IF coalesce(v_kg_basis, 0) > 0 AND v_cargo_foreign > 0 THEN
    v_cargo_per_kg := round(v_cargo_foreign / v_kg_basis, 6);
  END IF;

  IF coalesce(v_kg_basis, 0) > 0 AND v_freight_bdt > 0 THEN
    v_freight_bdt_per_kg := round(v_freight_bdt / v_kg_basis, 6);
  END IF;

  RETURN jsonb_build_object(
    'material', v_mat,
    'freight', v_fre,
    'customs', v_customs,
    'handling', v_handling,
    'finance', v_finance,
    'other', v_other,
    'goods_bdt', v_goods_bdt,
    'freight_bdt', v_freight_bdt,
    'product_foreign', v_product_foreign,
    'cargo_foreign', v_cargo_foreign,
    'product_conversion_rate', v_prod_rate,
    'cargo_conversion_rate', v_cargo_fx,
    'cargo_rate', v_cargo_per_kg,
    'freight_bdt_per_kg', v_freight_bdt_per_kg,
    'kg_basis', v_kg_basis,
    'transaction_rate', v_blended,
    'blended_rate', v_blended
  );
END;
$$;

-- Landed unit cost stamp — algorithm in docs/features/procurement_stock/shipment-rate-calculations.md

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

  PERFORM public.ensure_global_shipment_cost_entries_from_header(p_shipment_id);

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