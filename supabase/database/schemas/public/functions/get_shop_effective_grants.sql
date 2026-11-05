CREATE FUNCTION public.get_shop_effective_grants (
  p_tenant_id                bigint,
  p_customer_group_member_id bigint
)
  RETURNS TABLE (
    module_key text,
    action     text
  )
  LANGUAGE plpgsql
  STABLE
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
DECLARE
  v_tenant_role_id bigint;
  v_role_is_admin boolean;
  v_cgm_role public.customer_group_role;
BEGIN
  SELECT cgm.tenant_role_id, tr.is_admin, cgm.role
  INTO v_tenant_role_id, v_role_is_admin, v_cgm_role
  FROM public.customer_group_members cgm
  LEFT JOIN public.tenant_roles tr ON tr.id = cgm.tenant_role_id
  WHERE cgm.id = p_customer_group_member_id
    AND cgm.is_active = true;

  IF coalesce(v_role_is_admin, v_cgm_role = 'admin', false) = true THEN
    RETURN QUERY
    SELECT ma.module_key, ma.action
    FROM public.module_actions ma
    JOIN public.tenant_modules tm ON tm.module_key = ma.module_key OR tm.module_key = (
      SELECT mo.parent_module_key FROM public.modules mo WHERE mo.key = ma.module_key LIMIT 1
    )
    WHERE tm.tenant_id = p_tenant_id
      AND tm.is_active = true
      AND ma.is_active = true
      AND ma.scope = 'shop';
    RETURN;
  END IF;

  RETURN QUERY
  WITH role_allowed AS (
    SELECT rg.module_key, rg.action
    FROM public.tenant_role_grants rg
    WHERE rg.tenant_role_id = v_tenant_role_id
      AND rg.allowed = true
  ),
  with_overrides AS (
    SELECT ra.module_key, ra.action FROM role_allowed ra
    UNION
    SELECT g.module_key, g.action
    FROM public.customer_group_member_grants g
    WHERE g.customer_group_member_id = p_customer_group_member_id
      AND g.effect = 'allow'
  ),
  effective AS (
    SELECT wo.module_key, wo.action FROM role_allowed wo
    EXCEPT
    SELECT g.module_key, g.action
    FROM public.customer_group_member_grants g
    WHERE g.customer_group_member_id = p_customer_group_member_id
      AND g.effect = 'deny'
  )
  SELECT e.module_key, e.action
  FROM effective e
  JOIN public.module_actions ma ON ma.module_key = e.module_key AND ma.action = e.action
  JOIN public.tenant_modules tm ON tm.module_key = e.module_key OR tm.module_key = (
    SELECT mo.parent_module_key FROM public.modules mo WHERE mo.key = e.module_key LIMIT 1
  )
  WHERE tm.tenant_id = p_tenant_id
    AND tm.is_active = true
    AND ma.is_active = true
    AND ma.scope = 'shop';
END;
$function$;

GRANT ALL ON FUNCTION public.get_shop_effective_grants(bigint, bigint) TO anon;

GRANT ALL ON FUNCTION public.get_shop_effective_grants(bigint, bigint) TO authenticated;

GRANT ALL ON FUNCTION public.get_shop_effective_grants(bigint, bigint) TO service_role;