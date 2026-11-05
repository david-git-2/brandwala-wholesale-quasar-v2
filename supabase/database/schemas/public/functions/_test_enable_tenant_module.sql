CREATE FUNCTION public._test_enable_tenant_module (
  p_tenant_id  bigint,
  p_module_key text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.modules m WHERE m.key = p_module_key) THEN
    INSERT INTO public.modules (key, name, is_active)
    VALUES (p_module_key, initcap(replace(p_module_key, '_', ' ')), true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.module_actions ma
    WHERE ma.module_key = p_module_key
      AND ma.action = 'view'
      AND ma.scope = 'app'
  ) THEN
    INSERT INTO public.module_actions (module_key, action, scope, is_active)
    VALUES (p_module_key, 'view', 'app', true);
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.module_actions ma
    WHERE ma.module_key = p_module_key
      AND ma.action = 'edit'
      AND ma.scope = 'app'
  ) THEN
    INSERT INTO public.module_actions (module_key, action, scope, is_active)
    VALUES (p_module_key, 'edit', 'app', true);
  END IF;

  INSERT INTO public.tenant_modules (tenant_id, module_key, is_active)
  VALUES (p_tenant_id, p_module_key, true)
  ON CONFLICT (tenant_id, module_key)
  DO UPDATE SET is_active = true, updated_at = now();
END;
$function$;

GRANT ALL ON FUNCTION public._test_enable_tenant_module(bigint, text) TO anon;

GRANT ALL ON FUNCTION public._test_enable_tenant_module(bigint, text) TO authenticated;

GRANT ALL ON FUNCTION public._test_enable_tenant_module(bigint, text) TO service_role;