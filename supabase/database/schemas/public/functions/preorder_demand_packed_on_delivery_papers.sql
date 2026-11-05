CREATE FUNCTION public.preorder_demand_packed_on_delivery_papers (
  p_preorder_demand_id        bigint,
  p_document_source_type      public.delivery_paper_source_type,
  p_document_source_id        bigint,
  p_exclude_delivery_paper_id bigint                            DEFAULT NULL::bigint
)
  RETURNS integer
  LANGUAGE sql
  STABLE
  AS $function$
  SELECT coalesce(sum(public.delivery_paper_line_packed_qty(dpl.splits)), 0)::integer
  FROM public.delivery_paper_line dpl
  INNER JOIN public.delivery_paper dp ON dp.id = dpl.delivery_paper_id
  WHERE dpl.preorder_demand_id = p_preorder_demand_id
    AND dp.source_type = p_document_source_type
    AND dp.source_id = p_document_source_id
    AND dp.status <> 'cancelled'::public.delivery_paper_status
    AND (p_exclude_delivery_paper_id IS NULL OR dp.id <> p_exclude_delivery_paper_id);
$function$;

GRANT ALL ON FUNCTION public.preorder_demand_packed_on_delivery_papers(bigint, public.delivery_paper_source_type, bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.preorder_demand_packed_on_delivery_papers(bigint, public.delivery_paper_source_type, bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.preorder_demand_packed_on_delivery_papers(bigint, public.delivery_paper_source_type, bigint, bigint) TO service_role;