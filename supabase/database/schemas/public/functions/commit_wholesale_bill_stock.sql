CREATE FUNCTION public.commit_wholesale_bill_stock (
  p_bill_id bigint
)
  RETURNS bigint
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public.commit_sales_bill_stock(p_bill_id);
end;
$function$;

GRANT ALL ON FUNCTION public.commit_wholesale_bill_stock(bigint) TO anon;

GRANT ALL ON FUNCTION public.commit_wholesale_bill_stock(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.commit_wholesale_bill_stock(bigint) TO service_role;