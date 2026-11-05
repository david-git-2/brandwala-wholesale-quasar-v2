CREATE FUNCTION public.bulk_update_thrift_stock_statuses (
  p_tenant_id bigint,
  p_stock_ids bigint[],
  p_status    text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  IF upper(trim(coalesce(p_status, ''))) = 'RESERVED' THEN
    RAISE EXCEPTION 'Use hold_thrift_stock to place holds (RESERVED)';
  END IF;

  UPDATE public.thrift_stocks
  SET status = p_status::public.thrift_stock_status,
      updated_at = now()
  WHERE tenant_id = p_tenant_id
    AND id = ANY(p_stock_ids);
END;
$function$;

GRANT ALL ON FUNCTION public.bulk_update_thrift_stock_statuses(bigint, bigint[], text) TO anon;

GRANT ALL ON FUNCTION public.bulk_update_thrift_stock_statuses(bigint, bigint[], text) TO authenticated;

GRANT ALL ON FUNCTION public.bulk_update_thrift_stock_statuses(bigint, bigint[], text) TO service_role;