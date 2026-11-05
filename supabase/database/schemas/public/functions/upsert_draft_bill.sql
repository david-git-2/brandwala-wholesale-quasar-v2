CREATE FUNCTION public.upsert_draft_bill (
  p_payload jsonb
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_tenant_id bigint;
  v_result jsonb;
  v_bill public.bills;
  v_bill_id bigint;
begin
  v_tenant_id := nullif(p_payload->>'tenant_id', '')::bigint;
  if v_tenant_id is null then
    raise exception 'tenant_id required';
  end if;

  if coalesce(p_payload->>'adapter', '') = 'shipment_cost' then
    v_bill_id := public._upsert_shipment_ap_bill(
      nullif(p_payload->>'parent_tenant_id', '')::bigint,
      nullif(p_payload->>'issued_by_tenant_id', '')::bigint,
      nullif(p_payload->>'shipment_id', '')::bigint,
      p_payload->>'shipment_name',
      p_payload->>'ap_kind',
      nullif(p_payload->>'profile_id', '')::bigint,
      nullif(p_payload->>'amount', '')::numeric,
      coalesce(p_payload->'ap_paper', '{}'::jsonb),
      coalesce((p_payload->>'keep_as_draft')::boolean, true),
      nullif(p_payload->>'source_key', '')
    );
    if v_bill_id is null then
      raise exception 'shipment AP upsert returned no bill';
    end if;
    select * into v_bill from public.bills where id = v_bill_id;
    return v_bill;
  end if;

  if coalesce(p_payload->>'adapter', '') = 'dropship_courier' then
    v_result := public._kernel_upsert_dropship_courier_ap(
      nullif(p_payload->>'order_id', '')::bigint,
      coalesce((p_payload->>'keep_as_draft')::boolean, false)
    );
    if coalesce(v_result->>'success', 'false') <> 'true' then
      raise exception '%', coalesce(v_result->>'error', 'dropship courier AP upsert failed');
    end if;
    select * into v_bill from public.bills where id = (v_result->>'bill_id')::bigint;
    if v_bill.id is null then
      raise exception 'dropship courier AP bill missing after upsert';
    end if;
    return v_bill;
  end if;

  if coalesce(p_payload->>'adapter', '') = 'shop_order'
    or nullif(p_payload->>'shop_order_id', '') is not null then
    return public._kernel_upsert_shop_order_draft(p_payload);
  end if;

  return public._kernel_upsert_compose_draft(p_payload);
end;
$function$;

GRANT ALL ON FUNCTION public.upsert_draft_bill(jsonb) TO anon;

GRANT ALL ON FUNCTION public.upsert_draft_bill(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public.upsert_draft_bill(jsonb) TO service_role;