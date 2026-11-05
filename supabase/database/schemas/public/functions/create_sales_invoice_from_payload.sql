CREATE FUNCTION public.create_sales_invoice_from_payload (
  p_tenant_id bigint,
  p_payload   jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public._kernel_upsert_compose_draft_json(
    coalesce(p_payload, '{}'::jsonb) || jsonb_build_object('tenant_id', p_tenant_id)
  );
end;
$function$;

GRANT ALL ON FUNCTION public.create_sales_invoice_from_payload(bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public.create_sales_invoice_from_payload(bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.create_sales_invoice_from_payload(bigint, jsonb) TO service_role;