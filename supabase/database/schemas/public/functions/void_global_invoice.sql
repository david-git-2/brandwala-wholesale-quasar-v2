CREATE FUNCTION public.void_global_invoice (
  p_invoice_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public.void_sales_invoice(p_invoice_id);
end;
$function$;

GRANT ALL ON FUNCTION public.void_global_invoice(bigint) TO anon;

GRANT ALL ON FUNCTION public.void_global_invoice(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.void_global_invoice(bigint) TO service_role;