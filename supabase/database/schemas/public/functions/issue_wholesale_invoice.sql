CREATE FUNCTION public.issue_wholesale_invoice (
  p_invoice_id bigint,
  p_items      jsonb  DEFAULT NULL::jsonb
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public.issue_wholesale_bill(p_invoice_id, p_items);
end;
$function$;

GRANT ALL ON FUNCTION public.issue_wholesale_invoice(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.issue_wholesale_invoice(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.issue_wholesale_invoice(bigint, jsonb) TO service_role;