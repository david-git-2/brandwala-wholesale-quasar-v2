CREATE FUNCTION public.normalize_pbc_procurement_status (
  p_status text
)
  RETURNS text
  LANGUAGE sql
  IMMUTABLE
  AS $function$
  SELECT CASE lower(trim(coalesce(p_status, '')))
    WHEN 'placing_order' THEN 'procuring'
    WHEN 'ready_for_shipment' THEN 'dispatch'
    WHEN 'packed' THEN 'dispatch'
    WHEN 'invoicing' THEN 'delivered'
    WHEN 'completed' THEN 'closed'
    ELSE lower(trim(coalesce(p_status, '')))
  END;
$function$;

GRANT ALL ON FUNCTION public.normalize_pbc_procurement_status(text) TO anon;

GRANT ALL ON FUNCTION public.normalize_pbc_procurement_status(text) TO authenticated;

GRANT ALL ON FUNCTION public.normalize_pbc_procurement_status(text) TO service_role;