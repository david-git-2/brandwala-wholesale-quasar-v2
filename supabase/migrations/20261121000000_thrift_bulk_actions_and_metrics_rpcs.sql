-- RPC 1: get_thrift_dashboard_metrics
CREATE OR REPLACE FUNCTION public.get_thrift_dashboard_metrics(p_tenant_id bigint)
RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER AS $$
DECLARE
  v_added_today bigint;
  v_total bigint;
  v_available bigint;
BEGIN
  SELECT COUNT(*) INTO v_added_today FROM thrift_stocks 
  WHERE tenant_id = p_tenant_id AND created_at >= date_trunc('day', now());
  
  SELECT COUNT(*) INTO v_total FROM thrift_stocks WHERE tenant_id = p_tenant_id;
  
  SELECT COUNT(*) INTO v_available FROM thrift_stocks 
  WHERE tenant_id = p_tenant_id AND status = 'AVAILABLE';
  
  RETURN jsonb_build_object(
    'items_added_today', v_added_today,
    'total_items', v_total,
    'available_items', v_available
  );
END; $$;

-- RPC 2: bulk_update_thrift_stock_locations
CREATE OR REPLACE FUNCTION public.bulk_update_thrift_stock_locations(
  p_tenant_id bigint,
  p_stock_ids bigint[],
  p_shelf_id bigint DEFAULT NULL,
  p_box_id bigint DEFAULT NULL
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER AS $$
BEGIN
  UPDATE thrift_stocks
  SET shelf_id = p_shelf_id, box_id = p_box_id, updated_at = now()
  WHERE tenant_id = p_tenant_id AND id = ANY(p_stock_ids);
END; $$;

-- RPC 3: bulk_update_thrift_stock_statuses
CREATE OR REPLACE FUNCTION public.bulk_update_thrift_stock_statuses(
  p_tenant_id bigint,
  p_stock_ids bigint[],
  p_status text
) RETURNS void LANGUAGE plpgsql VOLATILE SECURITY DEFINER AS $$
BEGIN
  UPDATE thrift_stocks
  SET status = p_status, updated_at = now()
  WHERE tenant_id = p_tenant_id AND id = ANY(p_stock_ids);
END; $$;

GRANT EXECUTE ON FUNCTION public.get_thrift_dashboard_metrics(bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bulk_update_thrift_stock_locations(bigint, bigint[], bigint, bigint) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.bulk_update_thrift_stock_statuses(bigint, bigint[], text) TO authenticated, service_role;
