CREATE OR REPLACE FUNCTION public.assign_shipment_to_child(
  p_tenant_id       bigint,
  p_child_tenant_id bigint,
  p_shipment_id     bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO public
AS $$
BEGIN
  RAISE EXCEPTION 'feature_retired: assign_shipment_to_child';
END;
$$;

GRANT ALL ON FUNCTION public.assign_shipment_to_child(bigint, bigint, bigint) TO anon;
GRANT ALL ON FUNCTION public.assign_shipment_to_child(bigint, bigint, bigint) TO authenticated;
GRANT ALL ON FUNCTION public.assign_shipment_to_child(bigint, bigint, bigint) TO service_role;