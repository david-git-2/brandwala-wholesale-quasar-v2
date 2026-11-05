CREATE FUNCTION public._kernel_upsert_shop_order_draft (
  p_payload jsonb
)
  RETURNS public.bills
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
begin
  if nullif(p_payload->>'shop_order_id', '') is null then
    raise exception 'shop_order_id required for shop_order adapter';
  end if;
  return public._kernel_upsert_compose_draft(p_payload);
end;
$function$;

GRANT ALL ON FUNCTION public._kernel_upsert_shop_order_draft(jsonb) TO anon;

GRANT ALL ON FUNCTION public._kernel_upsert_shop_order_draft(jsonb) TO authenticated;

GRANT ALL ON FUNCTION public._kernel_upsert_shop_order_draft(jsonb) TO service_role;