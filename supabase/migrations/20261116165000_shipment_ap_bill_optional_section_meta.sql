-- Shipment AP bills: section on create/update is optional.

CREATE OR REPLACE FUNCTION public._shipment_ap_bill_require_section_meta(
  p_shipment_id bigint,
  p_meta jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_section_id bigint;
  v_title text;
BEGIN
  v_section_id := NULLIF(btrim(COALESCE(p_meta->>'section_id', '')), '')::bigint;
  IF v_section_id IS NULL THEN
    RETURN jsonb_build_object('section_id', null, 'section_title', null);
  END IF;

  SELECT gss.title INTO v_title
  FROM public.global_shipment_sections gss
  WHERE gss.id = v_section_id
    AND gss.shipment_id = p_shipment_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_arguments: section % does not belong to shipment %',
      v_section_id, p_shipment_id;
  END IF;

  RETURN jsonb_build_object(
    'section_id', v_section_id,
    'section_title', COALESCE(NULLIF(btrim(p_meta->>'section_title'), ''), v_title)
  );
END;
$$;