-- Group AP paper lines by currency with per-currency subtotals.

CREATE OR REPLACE FUNCTION public._build_shipment_ap_bucket_paper(
  p_shipment_id bigint,
  p_ship public.global_shipments,
  p_bucket public.global_shipment_cost_bucket
) RETURNS jsonb
    LANGUAGE plpgsql STABLE
    SET search_path TO public
    AS $$
declare
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
begin
  select coalesce(def_cur.code, 'BDT'), coalesce(def_cur.symbol, def_cur.code, '৳')
  into v_currency_code, v_currency_symbol
  from public.global_currencies def_cur
  where def_cur.id = coalesce(p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id);

  select coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'currency_code', g.currency_code,
          'currency_symbol', g.currency_symbol,
          'foreign_total', g.foreign_total,
          'lines', g.lines
        )
        order by g.currency_code
      )
      from (
        select
          coalesce(line_cur.code, v_currency_code) as currency_code,
          coalesce(line_cur.symbol, line_cur.code, v_currency_symbol) as currency_symbol,
          sum(round(e.amount, 2)) as foreign_total,
          jsonb_agg(
            jsonb_build_object(
              'description', coalesce(
                nullif(trim(e.description), ''),
                nullif(trim(e.metadata->>'description'), ''),
                initcap(replace(e.cost_component::text, '_', ' '))
              ),
              'amount', round(e.amount, 2),
              'currency_code', coalesce(line_cur.code, v_currency_code),
              'currency_symbol', coalesce(line_cur.symbol, line_cur.code, v_currency_symbol)
            )
            order by
              case e.cost_component
                when 'subtotal'::public.global_shipment_cost_component then 1
                when 'carriage'::public.global_shipment_cost_component then 2
                when 'vat_tax'::public.global_shipment_cost_component then 3
                when 'misc'::public.global_shipment_cost_component then 4
                else 5
              end,
              e.id desc
          ) as lines
        from public.global_shipment_cost_entries e
        left join public.global_currencies line_cur
          on line_cur.id = coalesce(e.currency_id, p_ship.shipment_cost_currency_id, p_ship.shipment_purchase_currency_id)
        where e.shipment_id = p_shipment_id
          and e.cost_bucket = p_bucket
          and coalesce(e.amount, 0) > 0
        group by
          coalesce(line_cur.code, v_currency_code),
          coalesce(line_cur.symbol, line_cur.code, v_currency_symbol)
      ) g
    ),
    '[]'::jsonb
  )
  into v_currency_groups;

  v_group_count := jsonb_array_length(coalesce(v_currency_groups, '[]'::jsonb));
  v_mixed_currencies := v_group_count > 1;

  select coalesce(
    (
      select jsonb_agg(line_elm order by (line_elm->>'currency_code'), (line_elm->>'description'))
      from (
        select jsonb_array_elements(g.elem->'lines') as line_elm
        from jsonb_array_elements(coalesce(v_currency_groups, '[]'::jsonb)) as g(elem)
      ) flat
    ),
    '[]'::jsonb
  )
  into v_lines;

  if v_group_count = 1 then
    v_foreign_total := (v_currency_groups->0->>'foreign_total')::numeric;
    v_currency_code := v_currency_groups->0->>'currency_code';
    v_currency_symbol := v_currency_groups->0->>'currency_symbol';
    v_bill_amount := coalesce(v_foreign_total, 0);
  elsif v_group_count > 1 then
    v_foreign_total := null;
    select coalesce(sum((g.elem->>'foreign_total')::numeric), 0)
    into v_bill_amount
    from jsonb_array_elements(v_currency_groups) as g(elem);
  else
    v_foreign_total := 0;
    v_bill_amount := 0;
  end if;

  if v_bill_amount = 0 and p_bucket = 'material'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.purchase_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
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
    end if;
  elsif v_bill_amount = 0 and p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_fallback_amount := coalesce(round(p_ship.cargo_invoice_total, 2), 0);
    if v_fallback_amount > 0 then
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
    end if;
  end if;

  v_result := jsonb_build_object(
    'paper', p_bucket::text,
    'lines', coalesce(v_lines, '[]'::jsonb),
    'currency_groups', coalesce(v_currency_groups, '[]'::jsonb),
    'mixed_currencies', v_mixed_currencies,
    'foreign_total', v_foreign_total,
    'currency_code', v_currency_code,
    'currency_symbol', v_currency_symbol,
    'bdt_amount', coalesce(v_foreign_total, v_bill_amount)
  );

  if p_bucket = 'freight'::public.global_shipment_cost_bucket then
    v_weight_kg := coalesce(p_ship.total_weight_kg, p_ship.received_weight, 0);
    v_result := v_result || jsonb_build_object('weight_kg', v_weight_kg);
  end if;

  return v_result;
end;
$$;

DO $$
DECLARE
  r record;
  v_paper jsonb;
  v_amt numeric(12, 2);
  v_due numeric(12, 2);
BEGIN
  FOR r IN
    SELECT b.id, b.ap_shipment_id, b.ap_kind, coalesce(b.paid_amount, 0) AS paid
    FROM public.bills b
    WHERE b.invoice_type = 'ap'::public.global_invoice_type
      AND b.ap_shipment_id IS NOT NULL
      AND coalesce(b.paid_amount, 0) = 0
      AND b.invoice_status IN (
        'draft'::public.global_invoice_status,
        'issued'::public.global_invoice_status
      )
      AND b.ap_kind IN ('material', 'freight', 'customs', 'handling', 'finance', 'other')
  LOOP
    SELECT public._build_shipment_ap_bucket_paper(
      r.ap_shipment_id,
      s,
      r.ap_kind::public.global_shipment_cost_bucket
    )
    INTO v_paper
    FROM public.global_shipments s
    WHERE s.id = r.ap_shipment_id;

    IF v_paper IS NULL THEN
      CONTINUE;
    END IF;

    v_amt := coalesce(
      (v_paper->>'foreign_total')::numeric,
      (v_paper->>'bdt_amount')::numeric,
      0
    );
    v_due := greatest(v_amt - r.paid, 0);

    UPDATE public.bills
    SET
      subtotal_amount = v_amt,
      total_amount = v_amt,
      due_amount = v_due,
      channel_meta = coalesce(channel_meta, '{}'::jsonb) || jsonb_build_object('ap_paper', v_paper),
      updated_at = now()
    WHERE id = r.id;
  END LOOP;
END $$;
