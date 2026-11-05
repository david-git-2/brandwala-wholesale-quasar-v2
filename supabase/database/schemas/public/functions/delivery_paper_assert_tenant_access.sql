CREATE FUNCTION public.delivery_paper_assert_tenant_access (
  p_tenant_id bigint
)
  RETURNS boolean
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_is_parent boolean;
  v_allowed boolean := false;
BEGIN
  IF p_tenant_id IS NULL THEN
    RAISE EXCEPTION 'tenant_id is required';
  END IF;
  SELECT (t.parent_id IS NULL) INTO v_is_parent FROM public.tenants t WHERE t.id = p_tenant_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'tenant not found: %', p_tenant_id; END IF;
  IF v_is_parent THEN
    v_allowed := public.user_can_manage_parent_tenant(p_tenant_id);
  ELSE
    v_allowed := public.is_tenant_staff(p_tenant_id);
  END IF;
  IF NOT coalesce(v_allowed, false) THEN RAISE EXCEPTION 'access denied'; END IF;
  RETURN true;
END;
$function$;

GRANT ALL ON FUNCTION public.delivery_paper_assert_tenant_access(bigint) TO anon;

GRANT ALL ON FUNCTION public.delivery_paper_assert_tenant_access(bigint) TO authenticated;

GRANT ALL ON FUNCTION public.delivery_paper_assert_tenant_access(bigint) TO service_role;