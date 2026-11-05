CREATE FUNCTION public.issue_retail_bill (
  p_bill_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public.post_sales_invoice(p_bill_id);
end;
$function$;

GRANT ALL ON FUNCTION public.issue_retail_bill(bigint) TO anon;

GRANT ALL ON FUNCTION public.issue_retail_bill(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.issue_retail_bill(bigint) TO service_role;