-- Refresh cached due_amount / paid_amount from bill_settlements after BP18 cutover

DO $$
DECLARE
  v_id bigint;
BEGIN
  FOR v_id IN
    SELECT b.id FROM public.bills b
    WHERE b.invoice_status = 'issued'::public.global_invoice_status
  LOOP
    PERFORM public.recompute_global_invoice_payment_status(v_id);
  END LOOP;
END;
$$;
