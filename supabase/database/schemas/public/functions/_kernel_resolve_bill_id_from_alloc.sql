CREATE FUNCTION public._kernel_resolve_bill_id_from_alloc (
  p_invoice_id        bigint,
  p_global_invoice_id bigint,
  p_bill_id           bigint
)
  RETURNS bigint
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT COALESCE(p_bill_id, p_global_invoice_id, p_invoice_id);
$function$;

GRANT ALL ON FUNCTION public._kernel_resolve_bill_id_from_alloc(bigint, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public._kernel_resolve_bill_id_from_alloc(bigint, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_resolve_bill_id_from_alloc(bigint, bigint, bigint) TO service_role;