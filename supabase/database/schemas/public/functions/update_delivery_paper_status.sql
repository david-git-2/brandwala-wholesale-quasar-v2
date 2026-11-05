CREATE FUNCTION public.update_delivery_paper_status (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint,
  p_status            text
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
  v_new public.delivery_paper_status;
  v_dispatch jsonb;
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

  IF v_new = 'packed'::public.delivery_paper_status THEN
    RETURN public.mark_delivery_paper_packed(p_tenant_id, p_delivery_paper_id);
  END IF;

  IF v_new = 'dispatched'::public.delivery_paper_status THEN
    RETURN public.dispatch_delivery_paper(p_tenant_id, p_delivery_paper_id);
  END IF;

  SELECT * INTO v_paper
  FROM public.delivery_paper dp
  WHERE dp.id = p_delivery_paper_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status
     AND v_new = 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'delivery paper cannot return to draft after it has left draft';
  END IF;

  IF v_paper.status = v_new THEN
    RETURN jsonb_build_object('success', true, 'status', v_new);
  END IF;

  UPDATE public.delivery_paper dp
  SET status = v_new, updated_at = now()
  WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'status', v_new);
END;
$function$;

GRANT ALL ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO anon;

GRANT ALL ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public.update_delivery_paper_status(bigint, bigint, text) TO service_role;