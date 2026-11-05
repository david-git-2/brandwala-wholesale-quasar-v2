CREATE FUNCTION public._kernel_update_compose_draft (
  p_tenant_id bigint,
  p_bill_id   bigint,
  p_payload   jsonb
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  return public._kernel_update_compose_draft_json(p_tenant_id, p_bill_id, p_payload);
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_update_compose_draft(bigint, bigint, jsonb) TO anon;

GRANT ALL ON FUNCTION public._kernel_update_compose_draft(bigint, bigint, jsonb) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_update_compose_draft(bigint, bigint, jsonb) TO service_role;