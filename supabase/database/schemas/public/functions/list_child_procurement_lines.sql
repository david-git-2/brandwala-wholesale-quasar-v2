CREATE OR REPLACE FUNCTION public.list_child_procurement_lines(
  p_tenant_id bigint,
  p_child_tenant_id bigint DEFAULT NULL,
  p_search text DEFAULT NULL,
  p_limit integer DEFAULT 100,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  source_type text,
  source_id bigint,
  child_tenant_id bigint,
  child_tenant_name text,
  name text,
  product_id bigint,
  quantity integer,
  cost_bdt numeric,
  price_gbp numeric,
  image_url text,
  barcode text,
  product_code text,
  reference_label text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  RAISE EXCEPTION 'feature_retired: list_child_procurement_lines';
END;
$$;

GRANT ALL ON FUNCTION public.list_child_procurement_lines(bigint, bigint, text, integer, integer) TO anon;
GRANT ALL ON FUNCTION public.list_child_procurement_lines(bigint, bigint, text, integer, integer) TO authenticated;
GRANT ALL ON FUNCTION public.list_child_procurement_lines(bigint, bigint, text, integer, integer) TO service_role;