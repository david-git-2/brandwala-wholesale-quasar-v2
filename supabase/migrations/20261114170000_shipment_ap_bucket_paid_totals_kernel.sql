-- shipment_ap_bucket_paid_totals: include money_kernel bill_settlements/pays (Option A AP).

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
