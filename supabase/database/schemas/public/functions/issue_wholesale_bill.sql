CREATE FUNCTION public.issue_wholesale_bill (
  p_bill_id bigint,
  p_items   jsonb  DEFAULT NULL::jsonb
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  perform public.commit_wholesale_bill_stock(p_bill_id);
  return public._kernel_issue_wholesale_stock(p_bill_id, p_items);
end;
$function$;

GRANT ALL ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.issue_wholesale_bill(bigint, jsonb) TO service_role;