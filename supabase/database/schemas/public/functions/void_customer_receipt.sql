CREATE FUNCTION public.void_customer_receipt (
  p_tenant_id  bigint,
  p_payment_id bigint,
  p_reason     text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public._kernel_reverse_payment(p_tenant_id, p_payment_id, p_reason);
end;
$function$;

GRANT ALL ON FUNCTION public.void_customer_receipt(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.void_customer_receipt(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.void_customer_receipt(bigint, bigint, text) TO service_role;