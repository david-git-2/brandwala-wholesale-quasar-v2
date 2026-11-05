CREATE FUNCTION public.void_bill (
  p_bill_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public.void_sales_invoice(p_bill_id);
end;
$function$;

GRANT ALL ON FUNCTION public.void_bill(bigint) TO anon;

GRANT ALL ON FUNCTION public.void_bill(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.void_bill(bigint) TO service_role;