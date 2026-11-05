CREATE FUNCTION public.list_procurement_fulfill_group_items (
  p_tenant_id        bigint,
  p_document_type    text,
  p_document_id      bigint,
  p_search           text    DEFAULT NULL::text,
  p_limit            integer DEFAULT 50,
  p_cursor_source_id bigint  DEFAULT NULL::bigint
)
  RETURNS jsonb
  LANGUAGE sql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
  select public.list_procurement_demand_group_items(
    p_tenant_id,
    p_document_type,
    p_document_id,
    p_search,
    p_limit,
    p_cursor_source_id
  );
$function$;

GRANT ALL ON FUNCTION public.list_procurement_fulfill_group_items(bigint, text, bigint, text, integer, bigint) TO anon;

GRANT ALL ON FUNCTION public.list_procurement_fulfill_group_items(bigint, text, bigint, text, integer, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.list_procurement_fulfill_group_items(bigint, text, bigint, text, integer, bigint) TO service_role;