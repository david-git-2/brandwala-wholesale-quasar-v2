-- Refresh unpaid shipment AP bill snapshots to per-component lines (post 20271011203000).

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
