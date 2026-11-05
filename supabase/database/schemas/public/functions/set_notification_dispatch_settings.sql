CREATE FUNCTION public.set_notification_dispatch_settings (
  p_functions_url    text,
  p_service_role_key text
)
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public'
  AS $function$
BEGIN
  INSERT INTO public.notification_dispatch_settings (id, functions_url, service_role_key)
  VALUES (
    1,
    coalesce(nullif(trim(p_functions_url), ''), 'http://kong:8000'),
    nullif(trim(p_service_role_key), '')
  )
  ON CONFLICT (id) DO UPDATE SET
    functions_url = EXCLUDED.functions_url,
    service_role_key = EXCLUDED.service_role_key;
END;
$function$;

GRANT ALL ON FUNCTION public.set_notification_dispatch_settings(text, text) TO anon;

GRANT ALL ON FUNCTION public.set_notification_dispatch_settings(text, text) TO authenticated;

GRANT ALL ON FUNCTION public.set_notification_dispatch_settings(text, text) TO service_role;