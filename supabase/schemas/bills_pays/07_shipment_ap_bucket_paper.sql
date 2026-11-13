-- Option A: AP bucket paper from money_kernel shipment_cost_ap bill lines (no cost_entries table).

CREATE OR REPLACE FUNCTION public._build_shipment_ap_bucket_paper(
  p_shipment_id bigint,
  p_ship        public.global_shipments,
  p_bucket      public.global_shipment_cost_bucket
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = money_kernel, public, pg_temp
AS $$
DECLARE
  v_lines jsonb := '[]'::jsonb;
  v_currency_groups jsonb := '[]'::jsonb;
  v_group_count integer := 0;
  v_foreign_total numeric(12, 2);
  v_currency_code text := 'BDT';
  v_currency_symbol text := '৳';
  v_weight_kg numeric(12, 3);
  v_fallback_amount numeric(12, 2);
  v_mixed_currencies boolean := false;
  v_bill_amount numeric(12, 2) := 0;
  v_result jsonb;
  v_parent bigint;
  v_bucket_text text := p_bucket::text;
BEGIN
  v_parent := p_ship.tenant_id;

  SELECT coalesce(def_cur.code, 'BDT'), coalesce(def_cur.symbol, def_cur.code, '৳')
    INTO v_currency_code, v_currency_symbol
    FROM public.global_currencies def_cur
   WHERE def_cur.id = coalesce(p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id);

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'currency_code', g.currency_code,
        'currency_symbol', g.currency_symbol,
        'foreign_total', g.foreign_total,
        'lines', g.lines
      )
      ORDER BY g.currency_code
    ),
    '[]'::jsonb
  )
  INTO v_currency_groups
  FROM (
    SELECT
      upper(coalesce(b.currency_code, v_currency_code)) AS currency_code,
      coalesce(cur.symbol, cur.code, v_currency_symbol) AS currency_symbol,
      sum(round(bl.line_total, 2)) AS foreign_total,
      jsonb_agg(
        jsonb_build_object(
          'description', coalesce(
            nullif(trim(bl.description), ''),
            initcap(replace(coalesce(bl.meta->>'cost_component', 'misc'), '_', ' '))
          ),
          'amount', round(bl.line_total, 2),
          'currency_code', upper(coalesce(b.currency_code, v_currency_code)),
          'currency_symbol', coalesce(cur.symbol, cur.code, v_currency_symbol)
        )
        ORDER BY bl.line_no
      ) AS lines
    FROM money_kernel.bills b
    JOIN money_kernel.bill_lines bl
      ON bl.bill_id = b.id AND bl.tenant_id = b.tenant_id
    LEFT JOIN public.global_currencies cur
      ON upper(cur.code) = upper(b.currency_code)
    WHERE b.tenant_id = v_parent
      AND b.kind = 'shipment_cost_ap'
      AND b.source_type = 'shipment_cost'
      AND b.source_id = p_shipment_id::text
      AND b.status <> 'voided'
      AND coalesce(
        nullif(btrim(b.meta->>'ap_kind'), ''),
        split_part(coalesce(b.source_key, ''), ':', 1)
      ) = v_bucket_text
      AND coalesce(bl.line_total, 0) > 0
    GROUP BY
      upper(coalesce(b.currency_code, v_currency_code)),
      coalesce(cur.symbol, cur.code, v_currency_symbol)
  ) g;

  v_group_count := jsonb_array_length(coalesce(v_currency_groups, '[]'::jsonb));
  v_mixed_currencies := v_group_count > 1;

  SELECT coalesce(
    (
      SELECT jsonb_agg(line_elm ORDER BY (line_elm->>'currency_code'), (line_elm->>'description'))
      FROM (
        SELECT jsonb_array_elements(g.elem->'lines') AS line_elm
        FROM jsonb_array_elements(coalesce(v_currency_groups, '[]'::jsonb)) AS g(elem)
      ) flat
    ),
    '[]'::jsonb
  )
  INTO v_lines;

  IF v_group_count = 1 THEN
    v_foreign_total := (v_currency_groups->0->>'foreign_total')::numeric;
    v_currency_code := v_currency_groups->0->>'currency_code';
    v_currency_symbol := v_currency_groups->0->>'currency_symbol';
    v_bill_amount := coalesce(v_foreign_total, 0);
  ELSIF v_group_count > 1 THEN
    v_foreign_total := NULL;
    SELECT coalesce(sum((g.elem->>'foreign_total')::numeric), 0)
      INTO v_bill_amount
      FROM jsonb_array_elements(v_currency_groups) AS g(elem);
  ELSE
    v_foreign_total := 0;
    v_bill_amount := 0;
  END IF;

  IF v_bill_amount = 0 AND p_bucket = 'material'::public.global_shipment_cost_bucket THEN
    v_fallback_amount := coalesce(round(p_ship.purchase_invoice_total, 2), 0);
    IF v_fallback_amount > 0 THEN
      v_foreign_total := v_fallback_amount;
      v_bill_amount := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Product subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
      v_currency_groups := jsonb_build_array(
        jsonb_build_object(
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol,
          'foreign_total', v_fallback_amount,
          'lines', v_lines
        )
      );
      v_group_count := 1;
      v_mixed_currencies := false;
    END IF;
  ELSIF v_bill_amount = 0 AND p_bucket = 'freight'::public.global_shipment_cost_bucket THEN
    v_fallback_amount := coalesce(round(p_ship.cargo_invoice_total, 2), 0);
    IF v_fallback_amount > 0 THEN
      v_foreign_total := v_fallback_amount;
      v_bill_amount := v_fallback_amount;
      v_lines := jsonb_build_array(
        jsonb_build_object(
          'description', 'Freight subtotal',
          'amount', v_fallback_amount,
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol
        )
      );
      v_currency_groups := jsonb_build_array(
        jsonb_build_object(
          'currency_code', v_currency_code,
          'currency_symbol', v_currency_symbol,
          'foreign_total', v_fallback_amount,
          'lines', v_lines
        )
      );
      v_group_count := 1;
      v_mixed_currencies := false;
    END IF;
  END IF;

  v_result := jsonb_build_object(
    'paper', p_bucket::text,
    'lines', coalesce(v_lines, '[]'::jsonb),
    'currency_groups', coalesce(v_currency_groups, '[]'::jsonb),
    'mixed_currencies', v_mixed_currencies,
    'foreign_total', v_foreign_total,
    'currency_code', v_currency_code,
    'currency_symbol', v_currency_symbol,
    'bdt_amount', CASE
      WHEN upper(coalesce(v_currency_code, 'BDT')) IN ('', 'BDT') THEN coalesce(v_foreign_total, v_bill_amount)
      ELSE NULL
    END
  );

  IF p_bucket = 'freight'::public.global_shipment_cost_bucket THEN
    v_weight_kg := coalesce(p_ship.total_weight_kg, p_ship.received_weight, 0);
    v_result := v_result || jsonb_build_object('weight_kg', v_weight_kg);
  END IF;

  RETURN v_result;
END;
$$;
