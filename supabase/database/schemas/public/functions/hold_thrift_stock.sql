CREATE FUNCTION public.hold_thrift_stock (
  p_tenant_id       bigint,
  p_stock_id        bigint,
  p_held_for_phone  text,
  p_held_for_name   text                     DEFAULT NULL::text,
  p_hold_note       text                     DEFAULT NULL::text,
  p_held_by         text                     DEFAULT NULL::text,
  p_hold_expires_at timestamp with time zone DEFAULT NULL::timestamp WITH time zone
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_stock public.thrift_stocks%ROWTYPE;
  v_phone_normalized TEXT;
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

  v_phone_normalized := public.normalize_thrift_phone(p_held_for_phone);
  IF v_phone_normalized = '' THEN
    RAISE EXCEPTION 'Hold requires a customer phone';
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

  IF v_stock.status IS DISTINCT FROM 'AVAILABLE'::public.thrift_stock_status THEN
    RAISE EXCEPTION
      'Stock item % cannot be held (status=%); only AVAILABLE units can be held',
      p_stock_id,
      v_stock.status;
  END IF;

  UPDATE public.thrift_stocks
  SET
    status = 'RESERVED'::public.thrift_stock_status,
    held_for_name = NULLIF(trim(p_held_for_name), ''),
    held_for_phone = COALESCE(NULLIF(trim(p_held_for_phone), ''), v_phone_normalized),
    held_for_phone_normalized = v_phone_normalized,
    hold_note = NULLIF(trim(p_hold_note), ''),
    held_by = COALESCE(NULLIF(trim(p_held_by), ''), public.current_user_email()),
    held_at = NOW(),
    hold_expires_at = p_hold_expires_at,
    updated_at = NOW()
  WHERE id = p_stock_id
    AND tenant_id = p_tenant_id
    AND status = 'AVAILABLE'::public.thrift_stock_status;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated = 0 THEN
    RAISE EXCEPTION 'Stock item % became unavailable during hold', p_stock_id;
  END IF;

  RETURN jsonb_build_object(
    'id', p_stock_id,
    'status', 'RESERVED',
    'held_for_phone_normalized', v_phone_normalized
  );
END;
$function$;

COMMENT ON FUNCTION public.hold_thrift_stock(bigint,bigint,text,text,text,text,timestamp with time zone) IS 'Place AVAILABLE thrift stock on RESERVED hold for a customer phone (FB/online).';

GRANT ALL ON FUNCTION public.hold_thrift_stock(bigint, bigint, text, text, text, text, timestamp WITH time zone) TO anon;

GRANT ALL ON FUNCTION public.hold_thrift_stock(bigint, bigint, text, text, text, text, timestamp WITH time zone) TO authenticated;

GRANT ALL ON FUNCTION public.hold_thrift_stock(bigint, bigint, text, text, text, text, timestamp WITH time zone) TO service_role;