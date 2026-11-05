CREATE FUNCTION public.allocate_payment_to_global_invoice (
  p_tenant_id         bigint,
  p_payment_id        bigint,
  p_global_invoice_id bigint,
  p_amount            numeric
)
  RETURNS public.pay_allocations
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public._kernel_apply_pay_leftover_to_bill(
    p_tenant_id,
    p_payment_id,
    p_global_invoice_id,
    p_amount,
    false
  );
end;
$function$;

GRANT ALL ON FUNCTION public.allocate_payment_to_global_invoice(bigint, bigint, bigint, numeric) TO anon;

GRANT ALL ON FUNCTION public.allocate_payment_to_global_invoice(bigint, bigint, bigint, numeric) TO authenticated;

GRANT ALL ON FUNCTION public.allocate_payment_to_global_invoice(bigint, bigint, bigint, numeric) TO service_role;