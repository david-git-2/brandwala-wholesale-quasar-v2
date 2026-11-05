CREATE FUNCTION public.delete_thrift_stocks (
  p_tenant_id bigint,
  p_stock_ids bigint[]
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_blocked BIGINT;
  v_deleted INT;
  v_actor TEXT;
BEGIN
  IF p_stock_ids IS NULL OR cardinality(p_stock_ids) = 0 THEN
    RETURN jsonb_build_object('deleted', 0);
  END IF;

  SELECT si.stock_id
  INTO v_blocked
  FROM public.thrift_sales_invoice_items si
  INNER JOIN public.thrift_sales_invoices inv
    ON inv.id = si.invoice_id
   AND inv.tenant_id = si.tenant_id
  WHERE si.tenant_id = p_tenant_id
    AND si.stock_id = ANY (p_stock_ids)
    AND coalesce(inv.status, 'ACTIVE') = 'ACTIVE'
  LIMIT 1;

  IF v_blocked IS NOT NULL THEN
    RAISE EXCEPTION
      'Cannot delete stock %: it is on an active sales invoice. Return or mark staff mistake first.',
      v_blocked;
  END IF;

  v_actor := COALESCE(NULLIF(trim(public.current_user_email()), ''), 'system');

  UPDATE public.thrift_stocks
  SET
    deleted_at = NOW(),
    deleted_by = v_actor,
    updated_at = NOW()
  WHERE tenant_id = p_tenant_id
    AND id = ANY (p_stock_ids)
    AND deleted_at IS NULL;

  GET DIAGNOSTICS v_deleted = ROW_COUNT;

  RETURN jsonb_build_object('deleted', v_deleted);
END;
$function$;

GRANT ALL ON FUNCTION public.delete_thrift_stocks(bigint, bigint[]) TO anon;

GRANT ALL ON FUNCTION public.delete_thrift_stocks(bigint, bigint[]) TO authenticated;

GRANT ALL ON FUNCTION public.delete_thrift_stocks(bigint, bigint[]) TO service_role;