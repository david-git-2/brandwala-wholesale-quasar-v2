CREATE OR REPLACE FUNCTION public.add_child_line_to_parent_shipment(
  p_parent_shipment_id bigint,
  p_source_type        text,
  p_source_id          bigint
)
RETURNS public.global_shipment_items
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  RAISE EXCEPTION 'feature_retired: add_child_line_to_parent_shipment';
END;
$$;

GRANT ALL ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO anon;
GRANT ALL ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO authenticated;
GRANT ALL ON FUNCTION public.add_child_line_to_parent_shipment(bigint, text, bigint) TO service_role;