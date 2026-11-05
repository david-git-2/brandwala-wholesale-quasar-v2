CREATE FUNCTION public.list_bill_adjustments (
  p_parent_bill_id bigint
)
  RETURNS SETOF public.bills
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select b.*
  from public.bills b
  where b.parent_bill_id = p_parent_bill_id
  order by b.id;
$function$;

GRANT ALL ON FUNCTION public.list_bill_adjustments(bigint) TO anon;

GRANT ALL ON FUNCTION public.list_bill_adjustments(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_bill_adjustments(bigint) TO service_role;