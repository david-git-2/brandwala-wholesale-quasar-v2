CREATE FUNCTION public.release_thrift_stock_hold (
  p_tenant_id bigint,
  p_stock_id  bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_updated INT;
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.memberships m
    WHERE m.tenant_id = p_tenant_id
      AND lower(trim(m.email)) = public.current_user_email()
      AND m.is_active = true
  ) THEN
    RAISE EXCEPTION 'Not authorized for this tenant';
  END IF;

  SELECT *
  INTO v_stock
  FROM public.thrift_stocks
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Stock item % not found for tenant %', p_stock_id, p_tenant_id;
  END IF;

  IF v_stock.status IS DISTINCT FROM 'RESERVED'::public.thrift_stock_status THEN
    RAISE EXCEPTION
      'Stock item % is not on hold (status=%)',
      p_stock_id,
      v_stock.status;
  END IF;

  UPDATE public.thrift_stocks
  SET
    status = 'AVAILABLE'::public.thrift_stock_status,
    updated_at = NOW()
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
    AND status = 'RESERVED'::public.thrift_stock_status;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'Stock item % hold could not be released', p_stock_id;
  END IF;

  RETURN jsonb_build_object(
    'id', p_stock_id,
    'status', 'AVAILABLE'
  );
END;
$function$;

COMMENT ON FUNCTION public.release_thrift_stock_hold(bigint,bigint) IS 'Release RESERVED thrift stock back to AVAILABLE; clears hold metadata via trigger.';

GRANT ALL ON FUNCTION public.release_thrift_stock_hold(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.release_thrift_stock_hold(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.release_thrift_stock_hold(bigint, bigint) TO service_role;