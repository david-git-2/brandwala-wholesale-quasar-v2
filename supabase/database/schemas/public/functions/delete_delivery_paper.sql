CREATE FUNCTION public.delete_delivery_paper (
  p_tenant_id         bigint,
  p_delivery_paper_id bigint
)
  RETURNS jsonb
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_paper public.delivery_paper%rowtype;
BEGIN
  PERFORM public.delivery_paper_assert_tenant_access(p_tenant_id);

  SELECT * INTO v_paper FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'delivery paper not found';
  END IF;

  IF v_paper.status <> 'draft'::public.delivery_paper_status THEN
    RAISE EXCEPTION 'only draft delivery papers can be deleted';
  END IF;

  DELETE FROM public.delivery_paper dp WHERE dp.id = p_delivery_paper_id;

  RETURN jsonb_build_object('success', true, 'id', p_delivery_paper_id);
END;
$function$;

GRANT ALL ON FUNCTION public.delete_delivery_paper(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.delete_delivery_paper(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delete_delivery_paper(bigint, bigint) TO service_role;