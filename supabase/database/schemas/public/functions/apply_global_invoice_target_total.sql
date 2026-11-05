CREATE FUNCTION public.apply_global_invoice_target_total (
  p_invoice_id   bigint,
  p_target_total numeric,
  p_dry_run      boolean DEFAULT false
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  raise exception 'apply_global_invoice_target_total is retired; use credit_note or debit_note on the bill';
end;
$function$;

GRANT ALL ON FUNCTION public.apply_global_invoice_target_total(bigint, numeric, boolean) TO anon;

GRANT ALL ON FUNCTION public.apply_global_invoice_target_total(bigint, numeric, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.apply_global_invoice_target_total(bigint, numeric, boolean) TO service_role;