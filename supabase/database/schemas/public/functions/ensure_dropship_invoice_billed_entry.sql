CREATE FUNCTION public.ensure_dropship_invoice_billed_entry (
  p_invoice_id bigint
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  -- Intentionally no-op. Dropship B2B invoice does not debit the billing profile wallet.
  -- Courier COD is credited in confirm_dropship_delivered_costing at mark-delivered.
  return;
end;
$function$;

GRANT ALL ON FUNCTION public.ensure_dropship_invoice_billed_entry(bigint) TO anon;

GRANT ALL ON FUNCTION public.ensure_dropship_invoice_billed_entry(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.ensure_dropship_invoice_billed_entry(bigint) TO service_role;