-- Set delivery paper header status (staff workflow).

CREATE OR REPLACE FUNCTION public.update_delivery_paper_status(
  p_tenant_id bigint,
  p_delivery_paper_id bigint,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_new public.delivery_paper_status;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  IF p_delivery_paper_id IS NULL THEN
    RAISE EXCEPTION 'delivery_paper_id is required';
  END IF;

  BEGIN
    v_new := lower(trim(coalesce(p_status, '')))::public.delivery_paper_status;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'invalid delivery paper status: %', p_status;
  END;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status = v_new THEN
    RETURN jsonb_build_object('success', true, 'status', v_new);
  END IF;

  UPDATE public.delivery_paper dp
  SET status = v_new, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'status', v_new);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO authenticated;
