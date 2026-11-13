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
    coalesce(sum(round(bs.allocated_amount, 2)), 0),
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
  v_prod_rate numeric := 1;
  v_cargo_fx numeric := 1;
  v_product_foreign numeric := 0;
  v_cargo_foreign numeric := 0;
  v_goods_bdt numeric := 0;
  v_freight_bdt numeric := 0;
  v_blended numeric := 1;
  v_kg numeric := 0;
  v_cargo_per_kg numeric := 0;
  v_mat_count integer := 0;
  v_fre_count integer := 0;
  v_entry_material numeric := 0;
  v_entry_freight numeric := 0;
BEGIN
  v_mat := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'material');
  v_fre := public.shipment_ap_bucket_paid_totals(p_shipment_id, 'freight');

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

  v_goods_bdt := round(v_product_foreign * v_prod_rate, 2);
  v_freight_bdt := round(v_cargo_foreign * v_cargo_fx, 2);

  IF (v_product_foreign + v_cargo_foreign) > 0 THEN
    v_blended := round((v_goods_bdt + v_freight_bdt) / (v_product_foreign + v_cargo_foreign), 6);
  ELSE
    v_blended := 1;
  END IF;

  SELECT coalesce(gs.total_weight_kg, gs.received_weight, 0)
    INTO v_kg
    FROM public.global_shipments gs
   WHERE gs.id = p_shipment_id;

  IF coalesce(v_kg, 0) > 0 AND v_cargo_foreign > 0 THEN
    v_cargo_per_kg := round(v_cargo_foreign / v_kg, 6);
  END IF;

  RETURN jsonb_build_object(
    'material', v_mat,
    'freight', v_fre,
    'goods_bdt', v_goods_bdt,
    'freight_bdt', v_freight_bdt,
    'product_foreign', v_product_foreign,
    'cargo_foreign', v_cargo_foreign,
    'product_conversion_rate', v_prod_rate,
    'cargo_conversion_rate', v_cargo_fx,
    'cargo_rate', v_cargo_per_kg,
    'transaction_rate', v_blended,
    'blended_rate', v_blended
  );
END;
$$;
