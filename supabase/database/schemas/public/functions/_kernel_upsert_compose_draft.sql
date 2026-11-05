CREATE FUNCTION public._kernel_upsert_compose_draft (
  p_payload jsonb
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_result jsonb;
  v_bill public.bills;
begin
  v_result := public._kernel_upsert_compose_draft_json(p_payload);
  if coalesce(v_result->>'success', 'false') <> 'true' then
    raise exception '%', coalesce(v_result->>'error', 'compose upsert failed');
  end if;
  select * into v_bill from public.bills where id = (v_result->>'invoice_id')::bigint;
  if v_bill.id is null then
    raise exception 'compose upsert returned no bill';
  end if;
  return v_bill;
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_upsert_compose_draft(jsonb) TO anon;

GRANT ALL ON FUNCTION public._kernel_upsert_compose_draft(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_upsert_compose_draft(jsonb) TO service_role;