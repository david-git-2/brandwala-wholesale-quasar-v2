CREATE FUNCTION public.count_search_stock_network (
  p_context_tenant_id bigint,
  p_mode              text    DEFAULT 'search'::text,
  p_search            text    DEFAULT NULL::text,
  p_search_field      text    DEFAULT NULL::text,
  p_product_id        bigint  DEFAULT NULL::bigint,
  p_status            text    DEFAULT 'excellent'::text,
  p_shipment_id       bigint  DEFAULT NULL::bigint,
  p_exclude_zero_qty  boolean DEFAULT true
)
  RETURNS bigint
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
declare
  v_count bigint;
begin
  select count(*)::bigint into v_count
  from public.search_stock_network(
    p_context_tenant_id := p_context_tenant_id,
    p_mode := p_mode,
    p_search := p_search,
    p_search_field := p_search_field,
    p_product_id := p_product_id,
    p_status := p_status,
    p_shipment_id := p_shipment_id,
    p_exclude_zero_qty := p_exclude_zero_qty,
    p_limit := 100000,
    p_offset := 0
  );
  return coalesce(v_count, 0);
end;
$function$;

GRANT ALL ON FUNCTION public.count_search_stock_network(bigint, text, text, text, bigint, text, bigint, boolean) TO anon;

GRANT ALL ON FUNCTION public.count_search_stock_network(bigint, text, text, text, bigint, text, bigint, boolean) TO authenticated;

GRANT ALL ON FUNCTION public.count_search_stock_network(bigint, text, text, text, bigint, text, bigint, boolean) TO service_role;