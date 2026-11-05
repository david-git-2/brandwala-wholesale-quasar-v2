CREATE FUNCTION public.trg_notification_recipients_dispatch()
  RETURNS TRIGGER
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path TO 'public', 'net'
  AS $function$
DECLARE
  v_functions_url text;
  v_service_role_key text;
  v_url text;
BEGIN
  SELECT s.functions_url, s.service_role_key
  INTO v_functions_url, v_service_role_key
  FROM public.notification_dispatch_settings s
  WHERE s.id = 1;

  v_functions_url := coalesce(nullif(trim(v_functions_url), ''), 'http://kong:8000');
  v_service_role_key := nullif(trim(v_service_role_key), '');

  IF v_service_role_key IS NULL THEN
    RETURN NEW;
  END IF;

  v_url := rtrim(v_functions_url, '/') || '/functions/v1/dispatch-notification';

  BEGIN
    PERFORM net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_service_role_key
      ),
      body := jsonb_build_object(
        'notification_id', NEW.notification_id,
        'user_id', NEW.user_id
      )
    );
  EXCEPTION
    WHEN OTHERS THEN
      RAISE LOG 'dispatch-notification enqueue failed: %', SQLERRM;
  END;

  RETURN NEW;
END;
$function$;

GRANT ALL ON FUNCTION public.trg_notification_recipients_dispatch() TO anon;

GRANT ALL ON FUNCTION public.trg_notification_recipients_dispatch() TO authenticated;

GRANT ALL ON FUNCTION public.trg_notification_recipients_dispatch() TO service_role;